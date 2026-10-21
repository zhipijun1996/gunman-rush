"""LOCAL initial-App-spawn feedback only; never formal/fullspawn evidence."""
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
    parser.add_argument('--fixture', choices=['connection', 'backbranch'], default='connection')
    parser.add_argument('--return', dest='return_mode', choices=['long', 'short'], default='short')
    parser.add_argument('--seed', default='forest-depth-hollow-00')
    parser.add_argument('--map', type=int, choices=[1, 2], default=2)
    args = parser.parse_args()
    if args.fixture == 'connection' and args.return_mode != 'short':
        parser.error('Return comparison is only defined for the backbranch fixture')
    output = args.output.resolve()
    if not output.is_relative_to(ROOT / 'build') or output.exists():
        parser.error('Fresh output below repository build required')
    output.mkdir(parents=True)
    report = output / 'trace.json'
    started = time.monotonic()
    receipt = {'scope': 'LOCAL_initial_spawn_fixture_not_fullspawn_or_formal_admission', 'sources_before': inventory(),
               'import_cap_seconds': 90, 'native_cap_seconds': 90, 'exit_code': 1, 'return_mode': args.return_mode}
    try:
        run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
        text = run_engine(['--headless', '--path', '.', '--script', 'tests/forest_bible_world_fixture_runner.gd', '--',
                           '--output=res://' + report.relative_to(ROOT).as_posix(), '--fixture=' + args.fixture,
                           '--seed=' + args.seed, '--map=' + str(args.map), '--return=' + args.return_mode], 90)
        data = json.loads(report.read_text())
        if ('FOREST BIBLE LOCAL FIXTURE: PASS' not in text or data.get('failures')
                or data.get('scope') != 'LOCAL_initial_spawn_fixture_not_fullspawn_or_formal_admission'
                or data.get('initial_fixture_spawn_override') is not True
                or data.get('resource_or_health_override') is not False
                or data.get('return_mode') != args.return_mode
                or data.get('fixture', {}).get('motion_steps_before_override') != 0
                or not data.get('completed') or not data.get('frames')):
            raise RuntimeError('Incomplete/failed LOCAL fixture; cannot claim formal traversal')
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
    print('PASS: LOCAL initial spawn fixture only; formal fullspawn remains unverified')
if __name__ == '__main__':
    main()
