"""Verify exact CI artifact bytes with the existing real browser input scripts."""
import argparse, hashlib, json, os, pathlib, re, stat, subprocess, sys, time, zipfile
from functools import partial
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from threading import Thread
ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import publish_playtest
import harness

def require(ok, message):
    if not ok:
        raise ValueError(message)

def sha(p):
    h = hashlib.sha256()
    with p.open('rb') as f:
        while (b := f.read(1024 * 1024)):
            h.update(b)
    return h.hexdigest()

def inventory(root):
    return {str(p.relative_to(root)): sha(p) for p in sorted(root.rglob('*')) if p.is_file()}

# One reviewed consumer-tool revision, not a general tools/tests exemption.
# These bytes fix title recognition; the three business consumers stay unchanged.
REVIEWED_PRODUCTION_COMMIT = '37950e0896a91c6b812a11c323ec3d5fd1800bb0'
REVIEWED_TOOL_FILES = {
    'tools/studio_gui_pointer.py': 'a4b14d5d9b06889592b70cd91cfa9c19265c2a9b93d9caf61dcff6222dc024c6',
    'tools/verify_four_line_browser.py': 'ea641b56e1d2e6020211273157c3f6a6f51a3c0724d3e44241ad80c46cc2f29f',
    'tools/test_studio_gui_pointer.py': '259cd1ab5fb02fb9b336a780e0440b69b14760e999e2edbe5d8a2285eaf39a1c',
    'tests/fixtures/studio_gui_pointer/title_37950_current.png': 'cc90b463b98b79e66e703a720fbd644c5de277e52ee2d4d5601894cccb321ff9',
    'tests/fixtures/studio_gui_pointer/title_37950_current.json': '570a8e2eb2a63dac2cc4785d44df0b0ae6ca4517e6d7d6d560e23eafc38fc5fa',
}
COORDINATOR_FILES = {'tools/verify_ci_artifact_browser.py', 'tools/test_verify_ci_artifact_browser.py'}
CONSUMERS = ('verify_action_budget_browser', 'verify_studio_click_browser', 'verify_all_weapon_browser')


def git(root, *args):
    return subprocess.check_output(['git', *args], cwd=root, timeout=30)


def tree(root, commit):
    result = {}
    for row in git(root, 'ls-tree', '-rz', '--full-tree', commit).split(b'\0'):
        if row:
            metadata, name = row.split(b'\t', 1)
            mode, kind, oid = metadata.decode().split()
            require(kind == 'blob' and mode in ('100644', '100755'), 'Unsupported source entry')
            result[name.decode()] = (mode, oid)
    return result


def file_identity(path, oid, object_format, mode):
    # Verify actual bytes against Git even when skip-worktree hides a local edit.
    require(not path.is_symlink(), f'Symlink source: {path}')
    if not path.exists():
        return 'deleted'
    before = path.stat()
    key = harness.SourceHashCache._key
    require(bool(before.st_mode & 0o111) == (mode == '100755'), f'Source mode differs from Git: {path}')
    require(stat.S_ISREG(before.st_mode), f'Non-regular source: {path}')
    for parent in path.parents:
        require(not parent.is_symlink(), f'Symlink source parent: {parent}')
    sha256 = hashlib.sha256()
    blob = hashlib.new(object_format)
    blob.update(f'blob {before.st_size}\0'.encode())
    with path.open('rb') as source:
        require(key(os.fstat(source.fileno())) == key(before), f'Source replaced: {path}')
        while chunk := source.read(1024 * 1024):
            sha256.update(chunk)
            blob.update(chunk)
        require(key(os.fstat(source.fileno())) == key(before), f'Source changed: {path}')
    require(key(path.stat()) == key(before), f'Source replaced: {path}')
    require(blob.hexdigest() == oid, f'Actual source differs from Git blob: {path}')
    return sha256.hexdigest()


class SourceRoot:
    def __init__(self, path, commit):
        self.path = pathlib.Path(path).absolute()
        self.resolved = self.path.resolve(strict=True)
        self.commit = commit
        require(len(commit) in (40, 64) and all(c in '0123456789abcdef' for c in commit), 'Exact commit required')
        self.location = self._location()

    def _location(self):
        root = self.path.resolve(strict=True)
        common = pathlib.Path(git(root, 'rev-parse', '--path-format=absolute', '--git-common-dir').decode().strip())
        git_dir = pathlib.Path(git(root, 'rev-parse', '--absolute-git-dir').decode().strip())
        return (str(root), root.stat().st_dev, root.stat().st_ino,
                str(common), common.stat().st_dev, common.stat().st_ino,
                str(git_dir), git_dir.stat().st_dev, git_dir.stat().st_ino)

    def snapshot(self):
        require(self._location() == self.location, 'Source root replaced')
        require(git(self.resolved, 'rev-parse', 'HEAD').decode().strip() == self.commit, 'Source HEAD differs from expected commit')
        require(not git(self.resolved, 'status', '--porcelain').strip(), 'source worktree changed')
        entries = tree(self.resolved, self.commit)
        require(set(harness.source_files(self.resolved)) == set(entries), 'Source index/working input list differs from commit')
        object_format = git(self.resolved, 'rev-parse', '--show-object-format').decode().strip()
        files = {name: file_identity(self.resolved / name, entry[1], object_format, entry[0])
                 for name, entry in entries.items()}
        return {'root': str(self.resolved), 'commit': self.commit, 'location': self.location,
                'git_entries': entries, 'source_sha256': files}


def validate_tool_pair(production, consumer, executing_file):
    require(production['commit'] == REVIEWED_PRODUCTION_COMMIT, 'Tool revision is not reviewed for this production commit')
    game_tree, tool_tree = production['git_entries'], consumer['git_entries']
    allowed = set(REVIEWED_TOOL_FILES) | COORDINATOR_FILES
    changed = {name for name in game_tree.keys() | tool_tree.keys() if game_tree.get(name) != tool_tree.get(name)}
    require(changed <= allowed, f'Unreviewed tool-root changes: {sorted(changed - allowed)}')
    tool_root = pathlib.Path(consumer['root'])
    require(pathlib.Path(executing_file).resolve() == tool_root / 'tools/verify_ci_artifact_browser.py',
            'Coordinator must execute from the frozen consumer tool root')
    for name, digest in REVIEWED_TOOL_FILES.items():
        require(consumer['source_sha256'].get(name) == digest, f'Unreviewed tool bytes: {name}')
    required = [f'tools/{name}.py' for name in CONSUMERS] + [
        'tools/harness.py', 'tools/publish_playtest.py', 'tools/verify_ci_artifact_browser.py',
        'resources/player/traversal.tres']
    traversal = tool_root / 'resources/player/traversal.tres'
    require(traversal.is_file(), 'Missing actual traversal Resource')
    if not re.search(r'^hook_vertical_kick_deadzone = ([\d.]+)$', traversal.read_text(), re.M):
        required.append('scripts/player/traversal_definition.gd')
    for name in required:
        require(consumer['source_sha256'].get(name) not in (None, 'deleted'), f'Missing consumer input: {name}')
        if name not in allowed:
            require(production['source_sha256'].get(name) == consumer['source_sha256'].get(name),
                    f'Prepared consumer inputs differ: {name}')
    # Other tracked files were compared by Git blob above; every materialized file
    # in either root was independently checked against that blob by snapshot().
    # Sparse absences are recorded, never claimed to be browser-read inputs.
    return sorted(changed)


def require_unchanged_files(before):
    for name, digest in before.items():
        require(sha(pathlib.Path(name)) == digest, f'Artifact/API bytes changed: {name}')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--run-api', type=pathlib.Path, required=True)
    p.add_argument('--artifact-api', type=pathlib.Path, required=True)
    p.add_argument('--artifact-zip', type=pathlib.Path, required=True)
    p.add_argument('--commit', required=True)
    p.add_argument('--run-id', type=int, required=True)
    p.add_argument('--attempt', type=int, default=1)
    p.add_argument('--output', type=pathlib.Path, required=True)
    p.add_argument('--production-source-root', type=pathlib.Path)
    p.add_argument('--consumer-tool-root', type=pathlib.Path)
    p.add_argument('--consumer-tool-commit')
    a = p.parse_args()
    explicit = (a.production_source_root, a.consumer_tool_root, a.consumer_tool_commit)
    require(all(x is not None for x in explicit) or all(x is None for x in explicit), 'Supply all three explicit tool-version arguments together')
    dual = all(x is not None for x in explicit)
    production_root = (a.production_source_root if dual else ROOT).resolve(strict=True)
    consumer_root = (a.consumer_tool_root if dual else ROOT).resolve(strict=True)
    require(consumer_root == ROOT, 'Run the coordinator from the selected consumer tool root')
    if dual:
        require(not os.environ.get('PYTHONPATH'), 'Explicit tool roots do not use PYTHONPATH')
    a.output = a.output.resolve()
    require(a.output.is_relative_to(production_root / 'build'), 'Use a new directory under build')
    require(a.attempt > 0, 'CI artifact/browser identity requirement failed')
    a.output.mkdir(parents=True, exist_ok=False)
    report = {'status': 'failed', 'source_commit': a.commit, 'run_id': a.run_id, 'started_at_unix': time.time(), 'browser_results': [], 'scope': 'Real desktop canvas and Chromium CDP touch against unchanged exact CI artifact bytes; not native movie or physical device approval'}
    server = None
    guarded = []
    fixed_files = {}
    try:
        production = SourceRoot(a.production_source_root if dual else ROOT, a.commit)
        before_game = production.snapshot()
        guarded.append((production, before_game))
        if dual:
            consumer = SourceRoot(a.consumer_tool_root, a.consumer_tool_commit)
            before_tool = consumer.snapshot()
            guarded.append((consumer, before_tool))
            changes = validate_tool_pair(before_game, before_tool, __file__)
            for module in (harness, publish_playtest):
                require(pathlib.Path(module.__file__).resolve().parent == consumer_root / 'tools', 'Imported helper outside frozen tool root')
        else:
            before_tool, changes = before_game, []
        report.update(production_source=before_game, consumer_tools=before_tool, reviewed_tool_changes=changes,
                      consumer_tool_commit=before_tool['commit'], dual_root_mode=dual)
        fixed_files = {str(path.resolve()): sha(path) for path in (a.run_api, a.artifact_api, a.artifact_zip)}
        report['fixed_artifact_inputs'] = dict(fixed_files)
        if dual:
            prefix = os.environ.get('TESSDATA_PREFIX')
            require(bool(prefix), 'Explicit tool mode requires an attributable TESSDATA_PREFIX')
            tessdata = pathlib.Path(prefix).resolve(strict=True)
            models = {str(tessdata / (name + '.traineddata')): sha(tessdata / (name + '.traineddata'))
                      for name in ('eng', 'chi_sim', 'osd')}
            models[str(tessdata / 'configs/tsv')] = sha(tessdata / 'configs/tsv')
            fixed_files.update(models)
            report['ocr_environment'] = {'TESSDATA_PREFIX': prefix, 'resolved_root': str(tessdata), 'input_sha256': models}
        run = json.loads(a.run_api.read_text())
        require(run['id'] == a.run_id and run['head_sha'] == a.commit and (run['run_attempt'] == a.attempt), 'CI artifact/browser identity requirement failed')
        report.update(attempt=run['run_attempt'], run_api_sha256=sha(a.run_api), artifact_api_sha256=sha(a.artifact_api), coordinator_sha256=sha(pathlib.Path(__file__)))
        api = json.loads(a.artifact_api.read_text())
        require(api['workflow_run']['id'] == a.run_id and api['workflow_run']['head_sha'] == a.commit, 'CI artifact/browser identity requirement failed')
        events = []
        info, receipt = publish_playtest.verify_artifact_zip(a.artifact_zip.resolve(), api, a.commit, events)
        report.update(build_info=info, artifact_receipt=receipt, artifact_validation_events=events)
        web = a.output / 'web'
        web.mkdir()
        with zipfile.ZipFile(a.artifact_zip) as z:
            require(sum((i.file_size for i in z.infolist())) <= 2 * 1024 ** 3, 'CI artifact/browser identity requirement failed')
            for i in z.infolist():
                target = (web / i.filename).resolve()
                require(target.is_relative_to(web), 'CI artifact/browser identity requirement failed')
                if i.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                with z.open(i) as source, target.open('xb') as dest:
                    while (b := source.read(1024 * 1024)):
                        dest.write(b)
        roots = list(web.rglob('build-info.json'))
        require(len(roots) == 1, 'CI artifact/browser identity requirement failed')
        web = roots[0].parent
        report['served_directory'] = str(web)
        before = inventory(web)
        report['web_inventory_before'] = before
        require(sha(web / info['pack']) == receipt['pack_sha256'], 'CI artifact/browser identity requirement failed')

        class Quiet(SimpleHTTPRequestHandler):

            def log_message(self, *args):
                pass
        server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Quiet, directory=str(web)))
        Thread(target=server.serve_forever, daemon=True).start()
        url = f'http://127.0.0.1:{server.server_port}/'
        report['url'] = url
        cwd = a.output / 'browser-cwd'
        cwd.mkdir()
        for name in CONSUMERS:
            script = consumer_root / 'tools' / f'{name}.py'
            cmd = [sys.executable, str(script), url]
            started = time.time()
            log = a.output / f'{name}.log'
            pattern = '"failed": \\[\\]' if name == 'verify_action_budget_browser' else '"failed": 0'
            result = harness.run_check({'argv': cmd, 'timeout_seconds': 300, 'success_pattern': pattern}, log, root=cwd)
            item = {'command': cmd, 'cwd': str(cwd), 'script_sha256': sha(script), 'log': str(log), 'log_sha256': sha(log), **result}
            report['browser_results'].append(item)
            require(result['status'] == 'passed', f'{name} failed; original preserved')
        after = inventory(web)
        report['web_inventory_after'] = after
        require(after == before, 'served artifact changed during browser validation')
        report['status'] = 'passed'
        return 0
    except BaseException as e:
        report['error'] = str(e)
        raise
    finally:
        if server:
            server.shutdown()
            server.server_close()
        guard_errors = []
        try:
            require_unchanged_files(fixed_files)
            for guard, before_source in guarded:
                require(guard.snapshot() == before_source, 'Source changed during browser validation')
        except BaseException as error:
            guard_errors.append(str(error))
            report['status'] = 'failed'
            report['guard_errors'] = guard_errors
        report['ended_at_unix'] = time.time()
        report['duration_seconds'] = report['ended_at_unix'] - report['started_at_unix']
        (a.output / 'receipt.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        print(json.dumps({k: report.get(k) for k in ['status', 'source_commit', 'consumer_tool_commit', 'run_id', 'duration_seconds', 'error']}, ensure_ascii=False), flush=True)
        require(not guard_errors, '; '.join(guard_errors))
if __name__ == '__main__':
    sys.exit(main())
