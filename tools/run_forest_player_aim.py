"""Run an observed real-adapter regional prefix, preserving strict engine exits.

Assisted target selection and deliberate grounded recovery are explicit test
strategies. This is not a blind human playtest or complete-region admission.
"""
import argparse
import fcntl
import json
from pathlib import Path
import re
import subprocess
import time

from run_tests import run_engine
from run_forest_depth_region import inventory, import_inventory_guard

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--layout', choices=('forest-woven-trunk-v12', 'forest-interwoven-canopy-v13'), default='forest-interwoven-canopy-v13')
    parser.add_argument('--seed', default='forest-depth-00')
    parser.add_argument('--map', type=int, choices=(1, 2), default=1)
    parser.add_argument('--route', choices=('fast', 'growth', 'high_return', 'change_mind', 'borer'), default='fast')
    parser.add_argument('--legs', type=int, default=6)
    parser.add_argument('--aim-seconds', type=float, default=0.6)
    args = parser.parse_args()
    if not 2 <= args.legs <= 40 or not .2 <= args.aim_seconds <= .8:
        parser.error('Finite prefix2..40 and aim0.2..0.8 required')
    output = args.output.resolve()
    if not output.is_relative_to(ROOT / 'build') or output.exists():
        parser.error('Fresh output below repository build required')
    output.mkdir(parents=True)
    report = {'status': 'running', 'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
              'scope': 'real adapter hold and normal grounded recovery; target assisted, no player approval',
              'args': vars(args) | {'output': str(output)}}

    def save():
        (output / 'receipt.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')

    lock = ROOT / 'build/verification/engine.lock'
    lock.parent.mkdir(parents=True, exist_ok=True)
    with lock.open('a') as lease:
        fcntl.flock(lease, fcntl.LOCK_EX)
        before = inventory()
        report['source_before'] = before
        save()
        started = time.monotonic()
        try:
            imported = run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
            (output / 'import.log').write_text(imported)
            after_import = inventory()
            report['import_guard'] = import_inventory_guard(before, after_import)
            if not report['import_guard']['passed']:
                raise RuntimeError('Import changed non-generated source')
            log = run_engine(['--headless', '--path', '.', '--max-fps', '60', '--script',
                              'tests/forest_player_aim_runner.gd', '--', '--layout=' + args.layout,
                              '--seed=' + args.seed, '--map=' + str(args.map), '--route=' + args.route,
                              '--legs=' + str(args.legs), '--aim-seconds=' + str(args.aim_seconds),
                              '--output=res://' + str((output / 'trace.json').relative_to(ROOT))], 120)
            (output / 'native.log').write_text(log)
            data = json.loads((output / 'trace.json').read_text())
            frames, holds = data['frames'], data['aim_samples']
            if not re.search(r'^FOREST PLAYER AIM: PASS / ' + str(args.legs) + r' legs / [1-9]\d* aim holds / 0 failures$', log, re.M):
                raise RuntimeError('Missing complete real-adapter prefix result')
            if (data['failures'] or len(data['completed']) != args.legs or not holds or not data['audio_released']
                    or data['manual_motor_step'] or data['midroute_position_or_resource_injection']
                    or data['manifest']['layout_version'] != args.layout):
                raise RuntimeError('Incomplete or wrong-source physical prefix')
            if any(f['tick'] != i + 1 or f['motor_steps'] != 1 or 'focus' not in f for i, f in enumerate(frames)):
                raise RuntimeError('Continuous real Motor/focus observation missing')
            if any(h['held_real_seconds'] < args.aim_seconds or h['focus_air_seconds_used'] > 2.000001 for h in holds):
                raise RuntimeError('Real hold/budget observation invalid')
            report.update(status='passed', legs=len(data['completed']), holds=len(holds), frames=len(frames))
        except BaseException as error:
            report.update(status='failed', error=repr(error))
            raise
        finally:
            after = inventory()
            report['source_after'] = after
            report['runtime_source_unchanged'] = import_inventory_guard(before, after)['passed']
            report['seconds'] = time.monotonic() - started
            if not report['runtime_source_unchanged']:
                report['status'] = 'failed'
            save()
        if report['status'] != 'passed':
            raise RuntimeError('Source guard failed')
    print('PASS: real-adapter forest prefix and observed grounded focus recovery')


if __name__ == '__main__':
    main()
