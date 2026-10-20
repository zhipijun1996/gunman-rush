"""Finite single-target ablations in the actual v13 App and strict route reader.

Each omitted target is the sole deliberate test-world mutation, before the first
route tick. Results describe these strategies; they do not prove no player can
ever use a target or replace the final exact-v14 fixed80 and recovery review.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import time

import run_forest_depth_region as strict

ROOT = Path(__file__).resolve().parents[1]
CANDIDATES = ('thorn_mouth__rest_ring', 'upper_spiral__rest_ring',
              'broken_arch__return_catch_ring')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--seed', default='forest-depth-00')
    parser.add_argument('--map', type=int, choices=(1, 2), default=1)
    parser.add_argument('--route', choices=strict.ROUTES[:4] + ('borer',), default='high_return')
    parser.add_argument('--omit', nargs='+', choices=('none',) + CANDIDATES,
                        default=['none', *CANDIDATES])
    args = parser.parse_args()
    output = args.output.resolve()
    if not output.is_relative_to(ROOT / 'build') or output.exists() or len(args.omit) != len(set(args.omit)):
        parser.error('Fresh output below build and unique ablations required')
    output.mkdir(parents=True)
    report = {'scope': 'finite_actual_single_target_ablations_not_universal_redundancy',
              'seed': args.seed, 'map': args.map, 'route': args.route,
              'source_before': strict.inventory(), 'runs': [], 'status': 'running'}
    def save():
        (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    save()
    for index, omitted in enumerate(args.omit):
        folder = output / f'{index:02d}-{omitted}'
        folder.mkdir()
        capture = folder / 'capture.json'
        log = folder / 'native.log'
        argv = ['bash', 'tools/godot.sh', '--headless', '--fixed-fps', '60',
                '--path', '.', '--script', 'tests/forest_fruit_ablation_runner.gd',
                '--', '--seed=' + args.seed, '--map=' + str(args.map),
                '--route=' + args.route, '--omit=' + omitted,
                '--output=' + str(capture)]
        start = time.monotonic()
        row = {'omitted_anchor': omitted, 'argv': argv}
        try:
            env = {**os.environ, 'GUNMAN_DATA_HOME': str(folder / 'user-data'),
                   'XDG_CONFIG_HOME': str(folder / 'config'),
                   'XDG_CACHE_HOME': str(folder / 'cache'), 'LP_NUM_THREADS': '1'}
            with log.open('w') as stream:
                result = subprocess.run(argv, cwd=ROOT, env=env, stdout=stream,
                                        stderr=subprocess.STDOUT, timeout=240)
            data = json.loads(capture.read_text()) if capture.exists() else {}
            errors = strict.validate(data) if capture.exists() else ['capture_absent']
            ablation = data.get('actual_target_ablation', {})
            if (ablation.get('omitted_anchor') != omitted
                    or ablation.get('route_ticks_before_removal') != 0
                    or ablation.get('manifest_unchanged') is not True):
                errors.append('ablation_pre_route_identity_missing')
            if omitted != 'none' and ablation.get('actual_target_absent') is not True:
                errors.append('actual_target_not_removed')
            accepted_omitted = [event for event in data.get('events', [])
                                if event.get('target') == omitted
                                and event.get('kind') in ('hook_pull', 'hook_hang', 'hook_kick')]
            if accepted_omitted:
                errors.append('omitted_target_still_accepted')
            if result.returncode != 0:
                errors.append('native_nonzero')
            text = log.read_text()
            if strict.ERRORS.search(text):
                errors.append('native_script_error_or_leak')
            if not re.search(r'^FOREST FRUIT ABLATION: .* / 0 failures$', text, re.M):
                errors.append('native_completion_missing')
            row.update(exit_code=result.returncode, errors=errors,
                       status='passed' if not errors else 'failed',
                       completed_legs=len(data.get('completed_legs', [])),
                       log_sha256=strict.sha(log),
                       capture_sha256=strict.sha(capture) if capture.exists() else None)
        except subprocess.TimeoutExpired:
            row.update(status='failed', errors=['original_240s_native_cap'])
        except (OSError, ValueError, KeyError, TypeError) as error:
            row.update(status='failed', errors=[type(error).__name__ + ': ' + str(error)])
        row['seconds'] = time.monotonic() - start
        report['runs'].append(row)
        save()
        print(omitted, row['status'], flush=True)
        if row['status'] != 'passed':
            break
    after = strict.inventory()
    report['source_after'] = after
    report['source_stable'] = after == report['source_before']
    report['status'] = ('passed' if report['source_stable'] and len(report['runs']) == len(args.omit)
                        and all(row['status'] == 'passed' for row in report['runs']) else 'failed')
    save()
    return int(report['status'] != 'passed')


if __name__ == '__main__':
    raise SystemExit(main())
