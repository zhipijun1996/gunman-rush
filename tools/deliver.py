"""One local release gate: fresh checks, build, actual browser inputs and bound evidence."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time
import harness
from functools import partial
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from threading import Thread

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--jobs', type=int, default=4, choices=range(1, 9))
    parser.add_argument('--plan', action='store_true')
    args = parser.parse_args()
    commands = [
        [sys.executable, 'tools/foundry.py', 'build', '--count', '24', '--promote'],
        ['bash', 'tools/godot.sh', '--headless', '--path', '.', '--script', 'tools/foundry_export_stamp.gd'],
        [sys.executable, 'tools/harness.py', '--profile', 'gameplay', '--profile', 'art', '--jobs', str(args.jobs), '--release'],
        [sys.executable, 'tools/build.py', 'windows'],
        [sys.executable, 'tools/harness.py', '--profile', 'web', '--release'],
        *[[sys.executable, 'tools/'+name+'.py', '{url}'] for name in ['verify_action_budget_browser', 'verify_studio_click_browser', 'verify_all_weapon_browser']],
        [sys.executable, 'tools/capture_actions.py'],
    ]
    patterns = [r'^Validated [1-9]\d* development phrases;', r'^FOUNDRY EXPORT BASIS:',
                r'^Evidence:',
                r'"export_exit_code": 0', r'^Evidence:', r'"failed": \[\]', r'"failed": 0', r'"failed": 0',
                r'^PASS: continuous actions movie']
    if args.plan:
        print(json.dumps(commands, indent=2)); return 0
    folder = ROOT / 'build/verification/delivery' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    folder.mkdir(parents=True)
    report = {'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'status': 'running', 'steps': [], 'device_acceptance': 'unverified', 'player_acceptance': 'unverified'}
    frozen_digest = None
    identity = harness.toolchain_identity()
    server = ThreadingHTTPServer(('127.0.0.1', 0), partial(SimpleHTTPRequestHandler, directory=str(ROOT / 'build/web')))
    thread = Thread(target=server.serve_forever, daemon=True); thread.start()
    url = f'http://127.0.0.1:{server.server_port}/'
    try:
        for index, command in enumerate(commands):
            command = [arg.replace('{url}', url) for arg in command]
            print('Running', command, flush=True)
            result = harness.run_check({'argv': command, 'timeout_seconds': 3000, 'success_pattern': patterns[index]}, folder / f'{index:02d}.log')
            report['steps'].append({'argv': command, **result, 'log': f'{index:02d}.log'})
            if result['status'] != 'passed':
                report['status'] = 'failed'; return 1
            if index == 1:
                frozen_digest = harness.input_digest({'argv': []}, harness.source_files(), identity)
                report['source_digest'] = frozen_digest
            elif index > 1 and harness.input_digest({'argv': []}, harness.source_files(), identity) != frozen_digest:
                raise RuntimeError('Source changed during release; refusing to bind mixed-version evidence')
            (folder / 'report.json').write_text(json.dumps(report, indent=2)+'\n')
        info = ROOT / 'build/web/build-info.json'
        report['build_info'] = json.loads(info.read_text())
        report['build_info_sha256'] = hashlib.sha256(info.read_bytes()).hexdigest()
        report['status'] = 'passed'
        report['scope'] = 'Local technical/GUI gate; CI deploy and public fingerprint verification remain required'
        return 0
    except BaseException:
        report['status'] = 'interrupted'; raise
    finally:
        server.shutdown(); server.server_close()
        (folder / 'report.json').write_text(json.dumps(report, indent=2)+'\n')
        print('Delivery evidence:', folder.relative_to(ROOT), flush=True)


if __name__ == '__main__':
    sys.exit(main())
