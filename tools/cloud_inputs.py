#!/usr/bin/env python3
"""Plan and explicitly hydrate selected Harness inputs using its existing preflight.

This is an availability plan, not a new dependency scanner or a test PASS.
Only absent skip-worktree files from the exact HEAD/index can be restored.
"""
import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

import harness
import production_loop as production

ROOT = Path(__file__).resolve().parents[1]


class InputError(ValueError):
    def __init__(self, message, details=None):
        super().__init__(message)
        self.details = details or {}


def git(root, *args, lazy=False, input=None):
    command = ['git', *([] if lazy else ['--no-lazy-fetch']), '-C', str(root), *args]
    return subprocess.check_output(command, input=input, stderr=subprocess.PIPE, timeout=60)


@contextmanager
def preflight_root(root):
    # The existing preflight reads these same worktree globals. No check runs.
    previous = (production.ROOT, harness.ROOT, harness.MANIFEST, production.quality.ROOT)
    try:
        production.ROOT = harness.ROOT = production.quality.ROOT = root
        harness.MANIFEST = root / 'tools/harness/profiles.json'
        yield
    finally:
        production.ROOT, harness.ROOT, harness.MANIFEST, production.quality.ROOT = previous


def safe_path(root, name):
    if (not isinstance(name, str) or not name or '\\' in name or ':' in name
            or any(ord(c) < 32 for c in name) or Path(name).is_absolute()
            or any(part in ('', '.', '..', '.git') for part in name.split('/'))):
        raise InputError('Unsafe required input path: ' + repr(name))
    path = root / name
    for parent in (path, *path.parents):
        if parent == root.parent:
            break
        if parent.is_symlink():
            raise InputError('Symlink input or ancestor: ' + name)
    return path


def selected_checks(manifest, checks, profiles):
    if not checks and not profiles:
        raise InputError('Select at least one explicit --check or --profile')
    if any(name not in manifest['checks'] for name in checks):
        raise InputError('Unknown Harness check')
    if any(name not in manifest['profiles'] for name in profiles):
        raise InputError('Unknown Harness profile; auto is not an explicit input contract')
    return list(dict.fromkeys([*harness.resolve_checks(manifest, profiles), *checks]))


def repository_state(root, commit, paths=()):
    actual = git(root, 'rev-parse', '--show-toplevel').decode().strip()
    if Path(actual).resolve() != root:
        raise InputError('--root must name the Git worktree root')
    head = git(root, 'rev-parse', '--verify', 'HEAD^{commit}').decode().strip()
    requested = git(root, 'rev-parse', '--verify', commit + '^{commit}').decode().strip()
    if head != requested or not re.fullmatch(r'[0-9a-f]{40}', head):
        raise InputError('Requested commit must be the exact current SHA-1 HEAD')
    tree = {}
    tree_paths = ['--', *paths] if paths else []
    index_paths = ['--', *(':(literal)' + name for name in paths)] if paths else []
    for entry in git(root, 'ls-tree', '-r', '-z', '--full-tree', head, *tree_paths).split(b'\0'):
        if entry:
            metadata, name = entry.split(b'\t', 1)
            mode, kind, oid = metadata.decode().split()
            tree[name.decode()] = {'mode': mode, 'type': kind, 'blob': oid}
    index = {}
    for entry in git(root, 'ls-files', '--stage', '-z', *index_paths).split(b'\0'):
        if entry:
            metadata, name = entry.split(b'\t', 1)
            mode, oid, stage = metadata.decode().split()
            index.setdefault(name.decode(), []).append((mode, oid, stage))
    flags = {entry[2:].decode(): chr(entry[0]) for entry in git(root, 'ls-files', '-v', '-z', *index_paths).split(b'\0') if entry}
    return head, tree, index, flags


def blob_sizes(root, oids):
    oids = sorted(set(oids))
    if not oids:
        return {}
    # Metadata only for selected objects. --no-lazy-fetch prevents this plan
    # from implicitly downloading evidence bytes from a promisor remote.
    raw = git(root, 'cat-file', '--batch-check=%(objectname) %(objecttype) %(objectsize)', input=('\n'.join(oids) + '\n').encode())
    result = {}
    for line in raw.decode().splitlines():
        parts = line.split()
        if len(parts) == 3 and parts[1] == 'blob':
            result[parts[0]] = int(parts[2])
        elif len(parts) == 2 and parts[1] == 'missing':
            result[parts[0]] = None
        else:
            raise InputError('Required input object is not a readable Git blob: ' + line)
    return result


def sparse_enabled(root):
    try:
        return git(root, 'config', '--bool', '--get', 'core.sparseCheckout').strip() == b'true'
    except subprocess.CalledProcessError as error:
        if error.returncode == 1:
            return False
        raise


def make_plan(root=ROOT, checks=(), profiles=(), commit='HEAD'):
    root = Path(root).resolve()
    head, tree, index, flags = repository_state(root, commit)
    structure = sorted(set(tree) ^ set(index))
    if structure or any(len(entries) != 1 or entries[0][2] != '0' for entries in index.values()):
        raise InputError('HEAD/index path structure changed or has unmerged entries; commit or resolve it before input hydration: ' + ', '.join(structure[:20]))
    sparse = sparse_enabled(root)
    with preflight_root(root):
        manifest = production.check_manifest_metadata()
        selected = selected_checks(manifest, checks, profiles)
        preflight = production.required_input_preflight({'checks': selected, 'read_only': True, 'allowed_paths': []})
    rows, blockers = [], []
    for item in preflight['missing_tracked_inputs']:
        name = item['path']
        path = safe_path(root, name)
        record = tree.get(name)
        if not record or record['type'] != 'blob' or record['mode'] not in ('100644', '100755'):
            raise InputError('Required input is not a regular file in exact HEAD: ' + name)
        if index.get(name) != [(record['mode'], record['blob'], '0')]:
            raise InputError('Required input index differs from exact HEAD: ' + name)
        eligible = (sparse and item['reason'] == 'sparse_unmaterialized' and flags.get(name, '').upper() == 'S'
                    and not path.exists() and not path.is_symlink())
        row = {'commit': head, 'path': name, 'blob': record['blob'], 'mode': record['mode'],
               'git_index_state': flags.get(name), 'required_by': item['required_by'],
               'reason': item['reason'], 'materializable': eligible}
        rows.append(row)
        if not eligible:
            blockers.append({'path': name, 'reason': 'not_an_absent_sparse_input', 'detail': item['reason']})
    sizes = blob_sizes(root, [row['blob'] for row in rows])
    for row in rows:
        row['size'] = sizes[row['blob']]
        row['object_available'] = row['size'] is not None
    blockers.extend(preflight['uncertain_inputs'])
    blockers.extend(preflight['import_metadata_risks'])
    return {'status': 'blocked' if blockers else ('needs_materialization' if rows else 'ready'),
            'approval_scope': 'input_availability_only', 'tests_executed': False, 'commit': head, 'checks': selected,
            'inputs': rows, 'known_bytes': sum(row['size'] or 0 for row in rows),
            'unknown_size_objects': sorted({row['blob'] for row in rows if row['size'] is None}),
            'blockers': blockers, 'preflight': preflight,
            'limits': 'Missing-input plan from the existing preflight, not a complete static dependency graph. No checks ran. Unknown object sizes stay explicit until --materialize obtains only those selected blobs.'}


def restore_input(root, row):
    root = Path(root).resolve()
    name, commit = row['path'], row['commit']
    path = safe_path(root, name)
    head, tree, index, flags = repository_state(root, commit, (name,))
    expected = (row['mode'], row['blob'], '0')
    if (not sparse_enabled(root) or head != commit or index.get(name) != [expected] or tree.get(name, {}).get('blob') != row['blob']
            or flags.get(name, '').upper() != 'S' or path.exists() or path.is_symlink()):
        raise InputError('Input changed, is locally present, or is no longer an absent sparse file: ' + name)
    path.parent.mkdir(parents=True, exist_ok=True)
    safe_path(root, name)
    descriptor, temporary = tempfile.mkstemp(prefix='.cloud-input-', dir=path.parent)
    temporary = Path(temporary)
    try:
        with os.fdopen(descriptor, 'wb') as target:
            # Explicit materialization is the only operation permitting lazy
            # object retrieval. Git is asked for one exact committed blob.
            result = subprocess.run(['git', '-C', str(root), 'cat-file', 'blob', row['blob']], stdout=target, stderr=subprocess.PIPE, timeout=300)
        if result.returncode:
            raise InputError('Required blob retrieval failed: ' + name + ': ' + result.stderr.decode(errors='replace')[-1000:])
        amount = temporary.stat().st_size
        digest = hashlib.sha1(('blob ' + str(amount) + '\0').encode())
        with temporary.open('rb') as stream:
            while block := stream.read(1024 * 1024):
                digest.update(block)
        if digest.hexdigest() != row['blob'] or (row['size'] is not None and amount != row['size']):
            raise InputError('Retrieved input blob SHA/size differs from the plan: ' + name)
        # Recheck after the download, then publish with a no-overwrite primitive.
        head, tree, index, flags = repository_state(root, commit, (name,))
        safe_path(root, name)
        if not sparse_enabled(root) or index.get(name) != [expected] or flags.get(name, '').upper() != 'S':
            raise InputError('Input index changed during retrieval: ' + name)
        temporary.chmod(0o755 if row['mode'] == '100755' else 0o644)
        os.link(temporary, path)
        return {**row, 'size': amount, 'status': 'materialized'}
    finally:
        temporary.unlink(missing_ok=True)


def materialize(root=ROOT, checks=(), profiles=(), commit='HEAD'):
    root = Path(root).resolve()
    initial = make_plan(root, checks, profiles, commit)
    pinned = initial['commit']
    rounds, restored, fetches = [], [], []
    plan = initial
    # Each round only restores missing inputs discovered by the real preflight.
    # Newly readable indexes can expose further selected dependency edges.
    while plan['inputs'] and not plan['blockers']:
        rounds.append(plan)
        if plan['unknown_size_objects']:
            try:
                fetches.extend(prefetch_blobs(root, plan['unknown_size_objects']))
            except InputError as error:
                error.details.update(materialized=restored, rounds=rounds)
                raise
        restored.extend(restore_input(root, row) for row in plan['inputs'])
        plan = make_plan(root, checks, profiles, pinned)
    return {**plan, 'materialized': restored, 'rounds': rounds, 'prefetch': fetches,
            'materialized_bytes': sum(row['size'] for row in restored),
            'sparse_patterns_changed': False, 'tests_executed': False}


def prefetch_blobs(root, oids, batch_size=32):
    """Fetch only selected absent blobs, with bounded wants per Git request."""
    if not 1 <= batch_size <= 64 or any(not re.fullmatch(r'[0-9a-f]{40}', oid) for oid in oids):
        raise InputError('Invalid bounded blob prefetch request')
    try:
        configured = git(root, 'config', '--get-regexp', r'^remote\..*\.promisor$').decode().splitlines()
    except subprocess.CalledProcessError as error:
        if error.returncode != 1:
            raise
        configured = []
    remotes = [line.split()[0][len('remote.'):-len('.promisor')] for line in configured if line.split()[-1] == 'true']
    if len(remotes) != 1:
        raise InputError('Selected missing blobs require exactly one configured promisor remote; no full fetch is attempted')
    unknown = [oid for oid, size in blob_sizes(root, oids).items() if size is None]
    events = []
    for offset in range(0, len(unknown), batch_size):
        batch = unknown[offset:offset + batch_size]
        # Match Git's promisor lazy-fetch transport: ordinary negotiation may
        # declare a reachable missing blob unnecessary and then fail its
        # connectivity check. Noop requests precisely these explicit wants.
        command = ['git', '-c', 'fetch.negotiationAlgorithm=noop', '-c', 'fetch.bundleURI=',
                   '-C', str(root), 'fetch', '--no-tags', '--no-write-fetch-head',
                   '--recurse-submodules=no', '--filter=blob:none', '--stdin', remotes[0]]
        event = {'remote': remotes[0], 'objects': batch, 'status': 'running', 'argv': command}
        events.append(event)
        try:
            result = subprocess.run(command,
                                    input=('\n'.join(batch) + '\n').encode(), capture_output=True, timeout=300)
            event['exit_code'] = result.returncode
            if result.returncode:
                raise InputError('Bounded selected-blob fetch failed: ' + result.stderr.decode(errors='replace')[-1500:])
            if any(size is None for size in blob_sizes(root, batch).values()):
                raise InputError('Selected blob still absent after bounded prefetch')
            event['status'] = 'fetched'
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            event.update(status='failed', error=str(error))
            raise InputError(str(error), {'prefetch': events}) from error
    return events


def new_report_file(root, output):
    root, output = Path(root).resolve(), Path(output)
    if '..' in output.parts:
        raise InputError('Report path must not contain parent traversal')
    path = output if output.is_absolute() else root / output
    try:
        relative = path.relative_to(root).as_posix()
    except ValueError:
        raise InputError('Report output must be a new file under this worktree build/') from None
    if not relative.startswith('build/'):
        raise InputError('Report output must be a new file under this worktree build/')
    path = safe_path(root, relative)
    if path.exists():
        raise InputError('Report output already exists; refusing overwrite: ' + relative)
    path.parent.mkdir(parents=True, exist_ok=True)
    safe_path(root, relative)
    return path.open('x')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='append', default=[])
    parser.add_argument('--profile', action='append', default=[])
    parser.add_argument('--commit', default='HEAD')
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--materialize', action='store_true')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args(argv)
    started = time.monotonic()
    output = None
    try:
        if args.output:
            output = new_report_file(args.root, args.output)
        operation = materialize if args.materialize else make_plan
        report = operation(args.root, args.check, args.profile, args.commit)
        # A successful plan is not a claim that inputs or selected tests passed.
        code = 0 if report['status'] == 'ready' else (2 if report['status'] == 'needs_materialization' else 1)
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        report = {'status': 'blocked', 'approval_scope': 'input_availability_only', 'error': str(error), 'tests_executed': False,
                  **getattr(error, 'details', {})}
        code = 1
    report['seconds'] = round(time.monotonic() - started, 3)
    text = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
    if output is not None:
        try:
            with output:
                output.write(text)
        except OSError as error:
            report = {'status': 'blocked', 'error': 'Report write failed: ' + str(error), 'tests_executed': False}
            text, code = json.dumps(report, ensure_ascii=False, indent=2) + '\n', 1
    print(text, end='')
    return code


if __name__ == '__main__':
    raise SystemExit(main())
