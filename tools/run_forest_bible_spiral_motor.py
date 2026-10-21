"""One F08 HRHHR -> real Reader item -> other-mouth camp journey."""
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
    parser.add_argument('--mode', choices=['local', 'full'], default='full')
    parser.add_argument('--seed', default='forest-depth-hollow-00')
    args = parser.parse_args()
    output = args.output.resolve()
    if not output.is_relative_to(ROOT / 'build') or output.exists():
        parser.error('Fresh output below repository build required')
    output.mkdir(parents=True)
    report = output / 'trace.json'
    scope = ('LOCAL_initial_basin_fixture_F08_not_fullspawn' if args.mode == 'local'
             else 'full_formal_spawn_F08_reader_and_other_exit')
    cap = 90 if args.mode == 'local' else 240
    started = time.monotonic()
    receipt = {'scope': scope, 'sources_before': inventory(), 'import_cap_seconds': 90,
               'native_cap_seconds': cap, 'exit_code': 1}
    try:
        run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
        text = run_engine(['--headless', '--path', '.', '--script', 'tests/forest_bible_spiral_motor_runner.gd', '--',
                           '--output=res://' + report.relative_to(ROOT).as_posix(),
                           '--seed=' + args.seed, '--mode=' + args.mode], cap)
        data = json.loads(report.read_text())
        if ('FOREST BIBLE F08 MOTOR: PASS' not in text or data.get('failures')
                or data.get('scope') != scope or data.get('resource_or_health_override') is not False
                or data.get('direct_claim_or_grant') is not False
                or data.get('initial_fixture_spawn_override') is not (args.mode == 'local')
                or not data.get('core_evidence') or not data.get('frames')
                or len(data.get('completed', [])) != data.get('itinerary_count')):
            raise RuntimeError('Incomplete or failed exact F08 journey')
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
        raise RuntimeError(receipt.get('error', 'Failed F08 run or source closure'))
    print('PASS: ' + scope + '; no H-only exclusivity or broader route acceptance')

if __name__ == '__main__':
    main()
