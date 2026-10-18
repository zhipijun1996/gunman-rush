"""Narrow native shared-bank geometry/consumer contract; not art admission."""
import fcntl
import hashlib
import json
import re
import time
from pathlib import Path

from level_formal import source_files
from run_tests import run_engine
from run_root_bell_ecology import godot_lock_path

ROOT = Path(__file__).resolve().parents[1]


def main():
    folder = ROOT / 'build/plains_joint_recoil/contracts' / time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())
    folder.mkdir(parents=True, exist_ok=False)
    started = time.monotonic()
    lock_path = godot_lock_path(ROOT)
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    lock = lock_path.open('a')
    fcntl.flock(lock, fcntl.LOCK_EX)
    before = source_files()
    report = {'status': 'failed', 'source_before': before,
              'scope': 'Actual formal replay, unchanged gameplay contracts, joint bank polygons and unsupported seam refusal; not playable route, visual, device or production-pool admission'}
    args = ['--headless', '--path', '.', '--script', 'tests/plains_joint_recoil_runner.gd']
    try:
        imported = run_engine(["--headless", "--path", ".", "--editor", "--quit"], 120)
        (folder / "import.log").write_text(imported)
        if re.search(r"(?m)^\s*(?:ERROR:|SCRIPT ERROR:|Parse Error:|SHADER ERROR:)", imported):
            raise RuntimeError("Actual native import error")
        output = run_engine(args, 120)
        (folder / 'native.log').write_text(output)
        if not re.search(r'^PLAINS JOINT RECOIL CONTRACT: [1-9]\d* assertions, 0 failures$', output, re.M):
            raise RuntimeError('Missing complete native contract')
        if re.search(r'(?m)^\s*(?:ERROR:|SCRIPT ERROR:|Parse Error:|SHADER ERROR:)', output):
            raise RuntimeError('Actual native error')
        actual = ROOT / 'build/plains_joint_recoil/contract.json'
        (folder / 'actual.json').write_bytes(actual.read_bytes())
        report['actual_sha256'] = hashlib.sha256(actual.read_bytes()).hexdigest()
        report['source_after'] = source_files()
        if report['source_after'] != before:
            raise RuntimeError('Source changed during native contract')
        report['status'] = 'passed'
    except Exception as exc:
        report['error'] = str(exc)
        raise
    finally:
        report['elapsed_seconds'] = time.monotonic() - started
        report['command'] = ['bash', 'tools/godot.sh', *args]
        (folder / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
        print(folder / 'report.json')
        fcntl.flock(lock, fcntl.LOCK_UN)
        lock.close()


if __name__ == '__main__':
    main()
