"""Isolated Queen weaving: real H knot damage, bullets, growing collision/hazard, controls."""
import argparse
import contextlib
import hashlib
import json
from pathlib import Path
import re
import time
from run_tests import run_engine
import level_formal
ROOT = Path(__file__).resolve().parent.parent


def validate(data, selected):
    if data.get('failures') or data.get('assertions', 0) < 8 or data.get('selected') != selected:
        raise ValueError('Native mechanism assertions/selection failed')
    if data.get('manual_motor_step') is not False or data.get('midroute_player_position_or_resource_writes') is not False:
        raise ValueError('Real player inputs required')
    rows = data['cases']
    if not rows or not data['frames']:
        raise ValueError('No actual capture')
    for prev, frame in zip(data['frames'], data['frames'][1:]):
        if prev['case'] == frame['case'] and (frame['tick'] != prev['tick']+1 or frame['motor_steps'] != prev['motor_steps']+1):
            raise ValueError('Discontinuous sole-Motor chain')
    initial = {(r['initial_player_hp'], r['initial_boss_hp'], r['initial_energy'], tuple(r['initial_knots'])) for r in rows}
    if len(initial) != 1:
        raise ValueError('Same initial health/energy/knot resources required')
    if selected == 'all' and {r['id'] for r in rows} != {'observe_two_changes','H_pursuit','noH_upper_camp','noH_central_camp','noH_right_jump','cut_then_upper','cut_all_then_upper'}:
        raise ValueError('All seven strategies required')
    for row in rows:
        if not row['retained_in_arena']:
            raise ValueError('A fallen-out strategy is an actual failure')
        if row['id'] == 'observe_two_changes' and row['migrations'] < 2:
            raise ValueError('Two physical migrations required')
    config_speed = float(data["migration_speed"])
    for prev, frame in zip(data['frames'], data['frames'][1:]):
        if prev['case'] != frame['case']: continue
        import math
        displacement = math.dist(prev['boss_position'],frame['boss_position'])
        if displacement > config_speed/60+0.001:
            raise ValueError('Queen teleported beyond its real per-frame travel bound')
    events = data['events']
    observe = [e for e in events if e['case']=='observe_two_changes' and e.get('event')=='perch_arrived']
    if selected in ('all','observe_two_changes') and [e['perch'] for e in observe[:2]] != [1,0]:
        raise ValueError('Actual A-B-A arrivals required')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output-dir', required=True)
    parser.add_argument('--case', choices=['all','observe_two_changes','H_pursuit','noH_upper_camp','noH_central_camp','noH_right_jump','cut_then_upper','cut_all_then_upper'], default='all')
    args = parser.parse_args()
    out = (ROOT / args.output_dir).resolve()
    if not out.is_relative_to((ROOT / 'build/forest_depth/queen').resolve()):
        parser.error('output must be beneath build/forest_depth/queen')
    if out.exists() and any(out.iterdir()):
        parser.error('fresh output directory required')
    out.mkdir(parents=True, exist_ok=True)
    before = level_formal.source_files()
    verifier = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in [Path(__file__).resolve(), ROOT / 'tests/thorn_queen_migration_runner.gd', ROOT / 'tests/thorn_queen_weave_runner.gd']}
    receipt = {'case': args.case, 'scope': 'Isolated Queen first mechanism, not full Boss or map2 admission',
               'source_before': before, 'verifier_before': verifier, 'passed': False}
    start = time.monotonic()
    try:
        with (out / 'native.log').open('w') as log, contextlib.redirect_stdout(log):
            text = run_engine(['--headless', '--fixed-fps', '60', '--path', '.', '--script',
                               'tests/thorn_queen_migration_runner.gd', '--',
                               f'--case={args.case}', f'--output-dir=res://{out.relative_to(ROOT)}'], 120)
        if not re.search(r'^QUEEN MIGRATION GOLDEN: [1-9]\d* assertions, 0 failures$', text, re.M):
            raise RuntimeError('Complete native success marker required')
        if re.search(r'(^|\n)(?:SCRIPT )?ERROR:', text):
            raise RuntimeError('Engine resource/parse/runtime error')
        validate(json.loads((out / 'capture.json').read_text()), args.case)
        receipt['passed'] = True
    finally:
        receipt['source_after'] = level_formal.source_files()
        receipt['source_guard'] = before == receipt['source_after']
        receipt['elapsed_seconds'] = time.monotonic() - start
        receipt['verifier_sha256'] = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                                     for path in [Path(__file__).resolve(), ROOT / 'tests/thorn_queen_migration_runner.gd', ROOT / 'tests/thorn_queen_weave_runner.gd']}
        receipt['verifier_guard'] = receipt['verifier_sha256'] == verifier
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        if not receipt['source_guard'] or not receipt['verifier_guard']:
            raise RuntimeError('Source changed during capture')
    print('PASS: Queen isolated mechanism technical observations; value and map2 admission UNVERIFIED')


if __name__ == '__main__':
    main()
