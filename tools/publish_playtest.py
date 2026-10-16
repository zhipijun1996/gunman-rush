"""Publish the selected ref through CI, with durable, identity-bound recovery.

--resume polls the recorded run; it never dispatches or reruns failed tests.
Interrupted dispatches are discovered conservatively. Artifacts and public
metadata must agree on the exact source and build before reporting success.
"""
import argparse
from datetime import datetime, timezone
import fcntl
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
import zlib

WORKFLOW = 'environment.yml'
ARTIFACT = 'gunman-rush-web-playtest'


class PublishError(RuntimeError):
    def __init__(self, kind, message):
        super().__init__(message)
        self.kind = kind


def classify(message):
    if re.search(r'(?i)HTTP\s*401|authentication|not logged|gh auth login|bad credentials', message): return 'authentication'
    if re.search(r'(?i)HTTP\s*403|forbidden|permission|resource not accessible', message): return 'permission_or_policy'
    if re.search(r'(?i)HTTP\s*(?:429|5\d\d)|timeout|timed out|connection|TLS handshake|unexpected EOF|network|no such host', message): return 'network_or_service'
    return 'command_failure'


def gh(*args, read_only=True, retry=True, timeout=30, events=None):
    # Dispatch is deliberately attempted once: an HTTP response can be lost
    # after GitHub accepted it. Recovery must discover, never blindly redispatch.
    for attempt in range(1, 4 if read_only and retry else 2):
        started = time.monotonic()
        try:
            result = subprocess.run(['gh', *args], capture_output=True, text=True, timeout=timeout)
            message = result.stderr.strip()[-2000:]
            kind = classify(message) if result.returncode else None
            output = result.stdout.strip()
        except subprocess.TimeoutExpired:
            result, output, message, kind = None, '', 'gh subprocess timeout', 'network_or_service'
        except OSError as exc:
            raise PublishError('missing_cli', str(exc)) from exc
        if events is not None:
            events.append({'phase': 'github_read' if read_only else 'dispatch', 'attempt': attempt,
                           'seconds': time.monotonic() - started, 'failure_kind': kind,
                           'exit_code': result.returncode if result else None})
        if kind is None: return output
        if not read_only or not retry or kind != 'network_or_service' or attempt == 3:
            raise PublishError(kind, message)
        time.sleep(attempt)
    raise PublishError('command_failure', 'Unreachable CLI state')


def api(repo, route, events):
    return json.loads(gh('api', f'repos/{repo}/{route}', events=events))


def save(path, state):
    state['updated_at'] = datetime.now(timezone.utc).isoformat()
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(state, ensure_ascii=False, indent=2) + '\n')
    temporary.replace(path)


def check_run(run, state):
    expected = {'head_sha': state['commit'], 'head_branch': state['ref'], 'event': 'workflow_dispatch'}
    for key, value in expected.items():
        if run.get(key) != value:
            raise PublishError('identity_mismatch', f'Run {key} mismatch: expected {value}, got {run.get(key)}')
    if str(run.get('path', '')).split('@')[0] != '.github/workflows/' + WORKFLOW:
        raise PublishError('identity_mismatch', 'Run belongs to another workflow')
    if state.get('run_id') is not None and run.get('id') != state['run_id']:
        raise PublishError('identity_mismatch', 'Run ID mismatch')
    if state.get('attempt') is not None and run.get('run_attempt') != state['attempt']:
        raise PublishError('identity_mismatch', 'Run attempt changed; explicitly adopt the intended attempt in a new checkpoint')


def runs(repo, ref, events):
    query = urllib.parse.urlencode({'branch': ref, 'event': 'workflow_dispatch', 'per_page': 50})
    return api(repo, f'actions/workflows/{WORKFLOW}/runs?{query}', events)['workflow_runs']


def check_deployment_receipts(state, events):
    route = f"actions/runs/{state['run_id']}/attempts/{state['attempt']}/jobs?per_page=100"
    data = api(state['repo'], route, events)
    if data.get('total_count', len(data.get('jobs', []))) > 100:
        raise PublishError('deployment_receipt', 'Deployment job inventory exceeds the bounded page; cannot assert completeness')
    receipts = {}
    for name in ('deploy_web', 'verify_public'):
        matches = [job for job in data.get('jobs', []) if job.get('name') == name]
        if len(matches) != 1 or matches[0].get('status') != 'completed' or matches[0].get('conclusion') != 'success':
            raise PublishError('deployment_receipt', f'Attempt lacks successful {name}; a nondeploying green CI is not a publication')
        receipts[name] = matches[0]['id']
    state['deployment_jobs'] = receipts


def validate_export_info(info, commit):
    if not isinstance(info, dict) or info.get('source_commit') != commit or not re.fullmatch(r'[a-f0-9]{12}', str(info.get('build_id', ''))):
        raise PublishError('artifact_identity', 'Tested artifact source/build metadata mismatch')
    pack = info.get('pack')
    if not isinstance(pack, str) or not pack or '/' in pack or "\\" in pack or pack in ('.', '..'):
        raise PublishError('artifact_identity', 'Tested artifact pack must be a safe relative filename')
    if type(info.get('pack_bytes')) is not int or not 0 < info['pack_bytes'] <= 1024 ** 3:
        raise PublishError('artifact_identity', 'Tested artifact pack size is absent or exceeds the 1 GiB validation bound')


def verify_artifact_zip(path, artifact, commit, events):
    """Verify the API-bound archive and stream only metadata and its real pack.

    This explicitly supplied archive may come from another authenticated download
    route. Its API digest is mandatory; arbitrary metadata is never a substitute.
    No ZIP paths are extracted to disk.
    """
    started = time.monotonic()
    try:
        digest = artifact.get('digest', '')
        if not re.fullmatch(r'sha256:[a-f0-9]{64}', str(digest)):
            raise PublishError('archive_integrity', 'Artifact API lacks a supported exact SHA256 digest')
        size = path.stat().st_size
        if not 0 < size <= 2 * 1024 ** 3:
            raise PublishError('archive_integrity', 'Local artifact ZIP is empty or exceeds the 2 GiB bound')
        if artifact.get('size_in_bytes') is not None and artifact['size_in_bytes'] != size:
            raise PublishError('archive_integrity', 'Local ZIP size differs from the API artifact size')
        archive_hash = hashlib.sha256()
        with path.open('rb') as stream:
            archive_bytes = 0
            while block := stream.read(1024 * 1024):
                archive_bytes += len(block)
                if archive_bytes > 2 * 1024 ** 3:
                    raise PublishError('archive_integrity', 'ZIP stream grew beyond the 2 GiB validation bound')
                archive_hash.update(block)
        if archive_bytes != size:
            raise PublishError('archive_integrity', 'Local ZIP size changed during validation')
        if archive_hash.hexdigest() != digest.removeprefix('sha256:'):
            raise PublishError('archive_integrity', 'Local ZIP SHA256 differs from the exact API artifact digest')
        with zipfile.ZipFile(path) as source:
            members = source.infolist()
            if len(members) > 4096:
                raise PublishError('archive_integrity', 'Artifact ZIP exceeds the bounded member inventory')
            names = [member.filename for member in members]
            if len(names) != len(set(names)):
                raise PublishError('archive_integrity', 'Artifact ZIP contains duplicate member names')
            for name in names:
                parts = PurePosixPath(name)
                if not name or "\\" in name or parts.is_absolute() or '..' in parts.parts or parts.as_posix() != name.rstrip('/'):
                    raise PublishError('archive_integrity', 'Artifact ZIP contains a noncanonical or unsafe member path')
            metadata = [member for member in members if not member.is_dir() and PurePosixPath(member.filename).name == 'build-info.json']
            if len(metadata) != 1 or metadata[0].file_size > 65536:
                raise PublishError('archive_integrity', 'Artifact ZIP lacks unique bounded build-info.json')
            info = json.loads(source.read(metadata[0]))
            validate_export_info(info, commit)
            expected_name = str(PurePosixPath(metadata[0].filename).parent / info['pack'])
            packs = [member for member in members if not member.is_dir() and member.filename == expected_name]
            if len(packs) != 1 or packs[0].file_size != info['pack_bytes']:
                raise PublishError('archive_integrity', 'Artifact pack is absent, duplicated, or has the wrong size')
            pack_hash, read_bytes = hashlib.sha256(), 0
            with source.open(packs[0]) as stream:
                while block := stream.read(1024 * 1024):
                    read_bytes += len(block)
                    if read_bytes > info['pack_bytes']:
                        raise PublishError('archive_integrity', 'Artifact pack stream exceeds its declared bound')
                    pack_hash.update(block)
            if read_bytes != info['pack_bytes'] or pack_hash.hexdigest()[:12] != info['build_id']:
                raise PublishError('archive_integrity', 'Actual artifact pack bytes/hash do not match build identity')
        return info, {'path': str(path.resolve()), 'zip_sha256': archive_hash.hexdigest(),
                      'zip_bytes': size, 'pack_sha256': pack_hash.hexdigest(), 'pack_bytes': read_bytes,
                      'digest_source': 'unique run artifact API digest', 'artifact_id': artifact['id']}
    except PublishError:
        raise
    except (OSError, ValueError, RuntimeError, zipfile.BadZipFile, zlib.error) as exc:
        raise PublishError('archive_integrity', 'Cannot safely validate artifact ZIP: ' + str(exc)) from exc
    finally:
        events.append({'phase': 'local_artifact_validation', 'seconds': time.monotonic()-started})


def expected_export(state, events, artifact_zip=None):
    repo, run_id = state['repo'], state['run_id']
    inventory = api(repo, f'actions/runs/{run_id}/artifacts?per_page=100', events)
    if inventory.get('total_count', len(inventory.get('artifacts', []))) > 100:
        raise PublishError('artifact_identity', 'Artifact inventory exceeds the bounded page; uniqueness is unverified')
    artifacts = inventory['artifacts']
    matches = [a for a in artifacts if a['name'] == ARTIFACT and not a.get('expired')]
    if len(matches) != 1:
        raise PublishError('artifact_identity', 'Expected exactly one nonexpired tested Web artifact')
    artifact = matches[0]
    workflow_run = artifact.get('workflow_run', {})
    if workflow_run.get('id') != run_id or workflow_run.get('head_sha') != state['commit']:
        raise PublishError('artifact_identity', 'Artifact source/run differs from the recorded run')
    if state.get('artifact_id') is not None and artifact['id'] != state['artifact_id']:
        raise PublishError('artifact_identity', 'Recorded artifact ID changed')
    if artifact_zip is not None:
        info, receipt = verify_artifact_zip(artifact_zip, artifact, state['commit'], events)
        if state.get('expected_export') and any(info.get(k) != v for k, v in state['expected_export'].items()):
            raise PublishError('artifact_identity', 'Verified ZIP metadata differs from the checkpointed tested export')
        state['artifact_archive'] = receipt
    elif state.get('expected_export'):
        return state['expected_export']
    else:
        # gh extracts the exact uniquely named run artifact. It is downloaded
        # once; --artifact-zip is an explicit verified recovery route for 403.
        with tempfile.TemporaryDirectory(prefix='gunman-publish-') as directory:
            gh('run', 'download', str(run_id), '--repo', repo, '--name', ARTIFACT, '--dir', directory,
               timeout=180, retry=False, events=events)
            files = list(Path(directory).rglob('build-info.json'))
            if len(files) != 1:
                raise PublishError('artifact_identity', 'Tested Web artifact lacks unique build-info.json')
            info = json.loads(files[0].read_text())
        validate_export_info(info, state['commit'])
    state.update(artifact_id=artifact['id'], expected_export={k: info[k] for k in ('source_commit', 'build_id', 'pack', 'pack_bytes')})
    return state['expected_export']


def live_info(url, events):
    started = time.monotonic()
    request = urllib.request.Request(url.rstrip('/') + '/build-info.json?check=' + str(time.time_ns()),
                                     headers={'Cache-Control': 'no-cache'})
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        kind = 'authentication' if exc.code == 401 else 'permission_or_policy' if exc.code == 403 else 'network_or_service' if exc.code == 429 or exc.code >= 500 else 'public_http_failure'
        raise PublishError(kind, f'Public metadata HTTP {exc.code}') from exc
    except (OSError, ValueError) as exc:
        raise PublishError('network_or_service', 'Public metadata unavailable: ' + str(exc)) from exc
    finally:
        events.append({'phase': 'public_metadata', 'seconds': time.monotonic() - started})


def execute(args, path):
    state = json.loads(path.read_text()) if args.resume and path.exists() else None
    if args.resume and state is None: raise PublishError('missing_checkpoint', '--resume requires an existing checkpoint')
    if not args.resume and path.exists(): raise PublishError('existing_checkpoint', 'Checkpoint already exists; use --resume or a new path')
    events = state.setdefault('events', []) if state else []
    repo = args.repo or json.loads(gh('repo', 'view', '--json', 'nameWithOwner', events=events))['nameWithOwner']
    resolved = gh('api', f'repos/{repo}/commits/{urllib.parse.quote(args.ref, safe="")}', '--jq', '.sha', events=events)
    if not re.fullmatch('[a-f0-9]{40}', resolved): raise PublishError('identity_mismatch', 'Ref did not resolve to a full commit SHA')
    if args.expected_commit and args.expected_commit != resolved: raise PublishError('identity_mismatch', 'Ref differs from --expected-commit')
    if state:
        if state.get('schema') != 1 or (state.get('repo'), state.get('ref'), state.get('commit')) != (repo, args.ref, resolved):
            raise PublishError('identity_mismatch', 'Checkpoint repository/ref/resolved SHA differs from this invocation')
        if args.run_id is not None and args.run_id != state.get('run_id'): raise PublishError('identity_mismatch', 'CLI run ID differs from checkpoint')
        if args.attempt is not None and args.attempt != state.get('attempt'): raise PublishError('identity_mismatch', 'CLI attempt differs from checkpoint')
    else:
        url = gh('api', f'repos/{repo}/pages', '--jq', '.html_url', events=events)
        state = {'schema': 1, 'repo': repo, 'ref': args.ref, 'commit': resolved, 'url': url,
                 'run_id': args.run_id, 'attempt': args.attempt if args.run_id else None,
                 'phase': 'adopting_run' if args.run_id else 'dispatch_pending', 'events': events,
                 'tokens': 'not_exposed', 'price': 'not_exposed'}
        if args.run_id:
            state['attempt'] = args.attempt or 1
        else:
            state['prior_run_ids'] = [r['id'] for r in runs(repo, args.ref, events)]
        save(path, state)
    started = time.monotonic()
    deadline = started + args.timeout
    try:
        if state['phase'] == 'dispatch_pending' and not args.resume:
            state['phase'] = 'dispatch_uncertain'
            save(path, state)  # Durable before the only mutating request.
            gh('workflow', 'run', WORKFLOW, '--repo', repo, '--ref', args.ref, '-f', 'deploy_playtest=true', read_only=False, events=events)
            state['phase'] = 'discovering_run'
            save(path, state)
        while time.monotonic() < deadline:
            if state['run_id'] is None:
                candidates = [r for r in runs(repo, args.ref, events) if r['id'] not in state.get('prior_run_ids', []) and r.get('head_sha') == state['commit'] and r.get('head_branch') == state['ref']]
                if len(candidates) > 1: raise PublishError('ambiguous_run', 'Multiple matching dispatches; explicitly adopt the intended run in a new checkpoint')
                if not candidates:
                    state['phase'] = 'discovering_run'; save(path, state)
                    time.sleep(min(args.poll_interval, max(0, deadline-time.monotonic()))); continue
                run = candidates[0]
                check_run(run, state)
                state.update(run_id=run['id'], attempt=run['run_attempt'])
                save(path, state)
            run = api(repo, f"actions/runs/{state['run_id']}", events)
            check_run(run, state)
            state.update(run_url=run['html_url'], ci_status=run['status'], ci_conclusion=run.get('conclusion'), phase='waiting_ci', live_verified=False)
            save(path, state)
            print(f"run={state['run_id']} attempt={state['attempt']} {run['status']} {run.get('conclusion')}", flush=True)
            if run['status'] == 'completed':
                if run.get('conclusion') != 'success':
                    state['phase'] = 'ci_failed'
                    raise PublishError('ci_failed', 'CI/deployment failed; no automatic rerun: ' + str(run.get('conclusion')))
                check_deployment_receipts(state, events)
                expected = expected_export(state, events, args.artifact_zip)
                state['phase'] = 'waiting_public'; save(path, state)
                try:
                    info = live_info(state['url'], events)
                except PublishError as exc:
                    if exc.kind != 'network_or_service': raise
                    state['last_public_error'] = {'kind': exc.kind, 'message': str(exc)}
                else:
                    if all(info.get(k) == value for k, value in expected.items()):
                        # Refuse a concurrent rerun/artifact replacement while
                        # the export was downloading or public metadata loading.
                        check_run(api(repo, f"actions/runs/{state['run_id']}", events), state)
                        expected_export(state, events, args.artifact_zip)
                        state.update(phase='verified', live_verified=True)
                        save(path, state)
                        print(json.dumps({'url': state['url'].rstrip('/') + '/?v=' + expected['build_id'], 'commit': state['commit'], 'build_id': expected['build_id'], 'run_url': state['run_url'], 'run_id': state['run_id'], 'attempt': state['attempt'], 'checkpoint': str(path), 'live_verified': True}), flush=True)
                        return 0
                    state['last_public_error'] = {'kind': 'stale_or_wrong_public_build', 'observed_source_commit': info.get('source_commit'), 'observed_build_id': info.get('build_id')}
            time.sleep(min(args.poll_interval, max(0, deadline-time.monotonic())))
        raise PublishError('poll_timeout', 'Bounded wait ended; resume this checkpoint without dispatching again')
    except PublishError as exc:
        state['last_error'] = {'kind': exc.kind, 'message': str(exc)}
        save(path, state)
        raise
    finally:
        events.append({'phase': 'publisher_invocation', 'seconds': time.monotonic()-started, 'includes_children': True})
        save(path, state)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ref', required=True)
    parser.add_argument('--repo')
    parser.add_argument('--expected-commit')
    parser.add_argument('--timeout', type=float, default=3600)
    parser.add_argument('--poll-interval', type=float, default=20)
    parser.add_argument('--checkpoint', type=Path, default=Path('build/verification/publish-playtest/checkpoint.json'))
    parser.add_argument('--resume', action='store_true')
    parser.add_argument('--artifact-zip', type=Path, help='Recover an authenticated artifact download using a local ZIP; exact API digest and actual pack are verified')
    parser.add_argument('--run-id', type=int, help='Explicitly adopt an existing run instead of dispatching')
    parser.add_argument('--attempt', type=int, help='Bind an explicit adopted run attempt (default 1)')
    args = parser.parse_args()
    if args.timeout <= 0 or args.poll_interval <= 0 or (args.attempt is not None and args.attempt < 1): parser.error('Timeout, interval and attempt must be positive')
    if args.attempt is not None and not args.run_id and not args.resume: parser.error('--attempt requires --run-id or --resume')
    args.checkpoint.parent.mkdir(parents=True, exist_ok=True)
    try:
        with args.checkpoint.with_suffix(args.checkpoint.suffix + '.lock').open('a') as lock:
            try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as exc: raise PublishError('checkpoint_busy', 'Another publisher owns this checkpoint') from exc
            return execute(args, args.checkpoint)
    except PublishError as exc:
        print(json.dumps({'status': 'blocked', 'failure_kind': exc.kind, 'error': str(exc), 'checkpoint': str(args.checkpoint)}), flush=True)
        return 1
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(json.dumps({'status': 'blocked', 'failure_kind': 'invalid_response_or_checkpoint', 'error': str(exc), 'checkpoint': str(args.checkpoint)}), flush=True)
        return 1


if __name__ == '__main__': raise SystemExit(main())
