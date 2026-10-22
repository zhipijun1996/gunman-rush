"""Full formal v15 Motor journey; no initial/midroute position override."""
import argparse
import json
import subprocess
import time
from pathlib import Path
from run_tests import run_engine
from forest_bible_world_sources import inventory

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--route', choices=['bible_connection_journey', 'bible_backbranch_journey'], default='bible_connection_journey')
    parser.add_argument('--seed', default='forest-depth-hollow-00')
    parser.add_argument('--map', type=int, choices=[1, 2], default=2)
    args = parser.parse_args()
    output = args.output.resolve()
    if not output.is_relative_to(ROOT / 'build') or output.exists():
        parser.error('Fresh output below repository build required')
    output.mkdir(parents=True)
    report = output / 'trace.json'
    started = time.monotonic()
    receipt = {'scope': 'full_formal_spawn_Bible_world_Motor', 'sources_before': inventory(),
               'import_cap_seconds': 90, 'native_cap_seconds': 240, 'exit_code': 1}
    try:
        run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
        text = run_engine(['--headless', '--path', '.', '--script', 'tests/forest_bible_world_motor_runner.gd', '--',
                           '--output=res://' + report.relative_to(ROOT).as_posix(), '--route=' + args.route,
                           '--seed=' + args.seed, '--map=' + str(args.map)], 240)
        data = json.loads(report.read_text())
        if ('FOREST BIBLE WORLD MOTOR: PASS' not in text or data.get('failures')
                or data.get('scope') != 'full_formal_spawn_Bible_world_Motor'
                or data.get('position_or_resource_injection') is not False
                or not data.get('completed') or not data.get('frames')):
            raise RuntimeError('Incomplete or failed formal Bible world journey')
        receipt['exit_code'] = 0
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
        receipt['error'] = str(error)
    finally:
        try:
            receipt['sources_after'] = inventory()
            receipt['source_stable'] = receipt['sources_before'] == receipt['sources_after']
            if not receipt['source_stable']:
                receipt['exit_code'] = 1
                receipt['error'] = 'Runtime/test/tool source closure changed during execution'
        except OSError as error:
            receipt['source_stable'] = False
            receipt['exit_code'] = 1
            receipt['error'] = 'Source inventory failed: ' + str(error)
        receipt['elapsed_seconds'] = time.monotonic() - started
        (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    if receipt['exit_code']:
        raise RuntimeError(receipt.get('error', 'Failed native run or source closure'))
    print('PASS: exact formal v15 journey; no broader FUN or device acceptance')

if __name__ == '__main__':
    main()
