"""Run actual candidate place compilation; does not certify art or Motor traversal."""
import fcntl
import hashlib
import json
import re
import subprocess
import time
from pathlib import Path

from level_formal import source_files
from run_root_bell_ecology import godot_lock_path
from run_tests import run_engine

ROOT = Path(__file__).resolve().parents[1]


def main():
    folder = ROOT / 'build/plains_places/contract' / time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())
    folder.mkdir(parents=True, exist_ok=False)
    report = {'status': 'failed', 'scope': 'Actual bounded place compilation/replay/refusals; not art, live traversal, release or device admission', 'runs': []}
    started = time.monotonic()
    try:
        lock_path = godot_lock_path(ROOT)
        lock_path.parent.mkdir(parents=True, exist_ok=True)
        with lock_path.open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            report['engine_lock_wait_seconds'] = time.monotonic() - started
            args = ['--headless', '--path', '.', '--editor', '--quit']
            output = run_engine(args, 120)
            (folder / 'import.log').write_text(output)
            if re.search(r'(^|\n)ERROR:', output):
                raise RuntimeError('Native import emitted an error')
            before = source_files()
            args = ['--headless', '--path', '.', '--script', 'tests/plains_places_plan_runner.gd', '--', '--output=' + str(folder / 'actual.json')]
            output = run_engine(args, 120)
            (folder / 'contract.log').write_text(output)
            report['runs'].append({'argv': ['bash', 'tools/godot.sh', *args], 'exit_code': 0, 'log': str((folder / 'contract.log').relative_to(ROOT)), 'log_sha256': hashlib.sha256(output.encode()).hexdigest()})
            if not re.search(r'^PLAINS PLACES CONTRACT: [1-9]\d* assertions, 0 failures$', output, re.M) or re.search(r'(^|\n)ERROR:', output):
                raise RuntimeError('Missing complete contract success or native error')
            report['source_before'] = before
            report['source_after'] = source_files()
            if report['source_after'] != before:
                raise RuntimeError('Source changed during frozen contract check')
            report['status'] = 'passed'
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        report['error'] = str(error)
    report['elapsed_seconds'] = time.monotonic() - started
    (folder / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('PLAINS PLACES SUITE: ' + report['status'] + ' ' + str(folder.relative_to(ROOT)))
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
