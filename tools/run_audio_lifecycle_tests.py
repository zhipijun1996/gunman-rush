#!/usr/bin/env python3
"""Reject successful Godot exits with runtime/resource errors or absent receipts."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
ERROR = re.compile(r'(?m)^ERROR:|SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ObjectDB.*leaked')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--script', required=True)
    parser.add_argument('--marker', required=True)
    parser.add_argument('--timeout', type=float, default=180)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--prove-skip-drain', action='store_true')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    command = ['bash', 'tools/godot.sh', '--headless', '--verbose', '--fixed-fps', '60', '--path', '.', '--script', args.script]
    if args.prove_skip_drain:
        command += ['--', '--prove-skip-drain']
    started = time.monotonic()
    report = {'command': command, 'status': 'failed', 'failure_kind': None}
    with (args.output / 'native.log').open('w') as log:
        try:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=args.timeout)
            report['exit_code'] = result.returncode
        except subprocess.TimeoutExpired:
            report.update(exit_code=None, failure_kind='bounded_timeout')
    output = (args.output / 'native.log').read_text(errors='replace')
    if report['failure_kind'] is None:
        if report['exit_code'] != 0: report['failure_kind'] = 'nonzero_exit'
        elif ERROR.search(output): report['failure_kind'] = 'runtime_or_resource_error'
        elif not re.search(args.marker, output, re.M): report['failure_kind'] = 'missing_completion_receipt'
        else: report['status'] = 'passed'
    report.update(seconds=time.monotonic() - started, timing_scope='native process including audio teardown; not device acceptance')
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    if report['status'] != 'passed': print('\n'.join(output.splitlines()[-75:]))
    print(json.dumps(report))
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
