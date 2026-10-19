"""Narrow native shared-bank geometry/consumer contract; not art admission."""
import contextlib
import fcntl
import hashlib
import json
import re
import sys
import time
from pathlib import Path

from level_formal import source_files
from run_tests import run_engine
from run_root_bell_ecology import godot_lock_path

ROOT = Path(__file__).resolve().parents[1]


def logged_engine(arguments, timeout, path):
    """Preserve the shared runner's actual streamed output even on refusal."""
    class Tee:
        def __init__(self, original, log):
            self.original, self.log = original, log
        def write(self, data):
            self.original.write(data)
            self.log.write(data)
        def flush(self):
            self.original.flush()
            self.log.flush()
    with path.open('w') as log, contextlib.redirect_stdout(Tee(sys.stdout, log)):
        return run_engine(arguments, timeout)


def main():
    folder = ROOT / 'build/plains_joint_recoil/contracts' / time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())
    folder.mkdir(parents=True, exist_ok=False)
    started = time.monotonic()
    started_epoch = time.time()
    lock_path = godot_lock_path(ROOT)
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    lock = lock_path.open('a')
    fcntl.flock(lock, fcntl.LOCK_EX)
    before = source_files(("tools/run_plains_joint_recoil_tests.py", "tests/fixtures/root_bell/pre_focus_15_player_tuning.json"))
    report = {'status': 'failed', 'source_before': before,
              'scope': 'Environment-first ridge/paired-creek replay, actual source-derived solid bodies, unchanged mechanisms, player contact and no-shot/no-rescue-floor negatives; not complete playable route, art, device or production-pool admission'}
    args = ['--headless', '--path', '.', '--script', 'tests/plains_joint_recoil_runner.gd']
    try:
        imported = logged_engine(["--headless", "--path", ".", "--editor", "--quit"], 120, folder / "import.log")
        if re.search(r"(?m)^\s*(?:ERROR:|SCRIPT ERROR:|Parse Error:|SHADER ERROR:)", imported):
            raise RuntimeError("Actual native import error")
        output = logged_engine(args, 120, folder / 'native.log')
        if not re.search(r'^PLAINS JOINT RECOIL CONTRACT: [1-9]\d* assertions, 0 failures$', output, re.M):
            raise RuntimeError('Missing complete native contract')
        if re.search(r'(?m)^\s*(?:ERROR:|SCRIPT ERROR:|Parse Error:|SHADER ERROR:)', output):
            raise RuntimeError('Actual native error')
        actual = ROOT / 'build/plains_joint_recoil/contract.json'
        (folder / 'actual.json').write_bytes(actual.read_bytes())
        report['actual_sha256'] = hashlib.sha256(actual.read_bytes()).hexdigest()
        report['source_after'] = source_files(("tools/run_plains_joint_recoil_tests.py", "tests/fixtures/root_bell/pre_focus_15_player_tuning.json"))
        if report['source_after'] != before:
            raise RuntimeError('Source changed during native contract')
        report['status'] = 'passed'
    except Exception as exc:
        report['error'] = str(exc)
        raise
    finally:
        report['source_after'] = source_files(("tools/run_plains_joint_recoil_tests.py", "tests/fixtures/root_bell/pre_focus_15_player_tuning.json"))
        actual = ROOT / 'build/plains_joint_recoil/contract.json'
        if actual.is_file() and actual.stat().st_mtime >= started_epoch:
            (folder / 'actual.json').write_bytes(actual.read_bytes())
            report['actual_sha256'] = hashlib.sha256(actual.read_bytes()).hexdigest()
        report['elapsed_seconds'] = time.monotonic() - started
        report['command'] = ['bash', 'tools/godot.sh', *args]
        (folder / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
        print(folder / 'report.json')
        fcntl.flock(lock, fcntl.LOCK_UN)
        lock.close()


if __name__ == '__main__':
    main()
