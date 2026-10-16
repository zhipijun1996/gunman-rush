"""Verify exact CI artifact bytes with the existing real browser input scripts."""
import argparse, hashlib, json, os, pathlib, subprocess, sys, time, zipfile
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

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--run-api', type=pathlib.Path, required=True)
    p.add_argument('--artifact-api', type=pathlib.Path, required=True)
    p.add_argument('--artifact-zip', type=pathlib.Path, required=True)
    p.add_argument('--commit', required=True)
    p.add_argument('--run-id', type=int, required=True)
    p.add_argument('--attempt', type=int, default=1)
    p.add_argument('--output', type=pathlib.Path, required=True)
    a = p.parse_args()
    a.output = a.output.resolve()
    require(a.output.is_relative_to(ROOT / 'build'), 'Use a new directory under build')
    require(a.attempt > 0, 'CI artifact/browser identity requirement failed')
    a.output.mkdir(parents=True, exist_ok=False)
    report = {'status': 'failed', 'source_commit': a.commit, 'run_id': a.run_id, 'started_at_unix': time.time(), 'browser_results': [], 'scope': 'Real desktop canvas and Chromium CDP touch against unchanged exact CI artifact bytes; not native movie or physical device approval'}
    server = None
    try:
        require(subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip() == a.commit, 'CI artifact/browser identity requirement failed')
        require(not subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip(), 'source worktree changed')
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
        for name in ('verify_action_budget_browser', 'verify_studio_click_browser', 'verify_all_weapon_browser'):
            script = ROOT / 'tools' / f'{name}.py'
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
        require(subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip() == a.commit, 'CI artifact/browser identity requirement failed')
        require(not subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip(), 'source worktree changed')
        report['status'] = 'passed'
        return 0
    except BaseException as e:
        report['error'] = str(e)
        raise
    finally:
        if server:
            server.shutdown()
            server.server_close()
        report['ended_at_unix'] = time.time()
        report['duration_seconds'] = report['ended_at_unix'] - report['started_at_unix']
        (a.output / 'receipt.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        print(json.dumps({k: report.get(k) for k in ['status', 'source_commit', 'run_id', 'duration_seconds', 'error']}, ensure_ascii=False), flush=True)
if __name__ == '__main__':
    sys.exit(main())
