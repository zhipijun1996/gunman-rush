#!/usr/bin/env python3
"""Finite audio-feedback regression through the original strict native runner."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CASES = [
    ('feedback', 'audio_feedback_05.gd', 'AUDIO_FEEDBACK_05', 90),
    ('rewards', 'audio_feedback_rewards.gd', 'AUDIO_FEEDBACK_REWARDS', 120),
    ('selected', 'selected_sfx_runtime.gd', 'SELECTED_SFX_RUNTIME', 90),
    ('previous-fix', 'audio_fix_03.gd', 'AUDIO_FIX_03', 90),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.output is None:
        args.output = Path('build/audio_feedback_05') / ('regression-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ'))
    args.output.mkdir(parents=True, exist_ok=False)
    rows = []
    for name, script, marker, timeout in CASES:
        output = args.output / name
        cmd = [sys.executable, 'tools/run_audio_lifecycle_tests.py', '--script', 'res://tests/' + script,
               '--marker', '^' + marker + r' checks=\d+ failures=0$', '--timeout', str(timeout), '--output', str(output)]
        result = subprocess.run(cmd, cwd=ROOT)
        report = json.loads((output / 'report.json').read_text()) if (output / 'report.json').exists() else {'status': 'missing'}
        rows.append({'case': name, 'exit_code': result.returncode, 'report': report})
        (args.output / 'report.json').write_text(json.dumps({'cases': rows, 'status': 'passed' if all(x['exit_code'] == 0 and x['report']['status'] == 'passed' for x in rows) else 'failed'}, indent=2) + '\n')
        if result.returncode or report['status'] != 'passed':
            return 1
    print('AUDIO FEEDBACK CHECK: four actual native consumers completed with 0 failures')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
