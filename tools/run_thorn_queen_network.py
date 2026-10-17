"""Isolated Queen shelter/network full fights and finite strongest cheap controls."""
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
    if data.get('failures') or data.get('assertions',0)<8 or data.get('selected')!=selected:
        raise ValueError('Actual native assertions/selection failed; preserve raw capture')
    if data.get('manual_motor_step') is not False or data.get('midroute_player_position_or_resource_writes') is not False:
        raise ValueError('Only real Player inputs permitted')
    frames=data['frames'];events=data['events'];rows=data['cases']
    for prev,frame in zip(frames,frames[1:]):
        if prev['case']!=frame['case']:continue
        if frame['tick']!=prev['tick']+1 or frame['motor_steps']!=prev['motor_steps']+1:
            raise ValueError('Missing actual sole-Motor frames')
        import math
        if math.dist(prev['boss_position'],frame['boss_position'])>float(data['migration_speed'])/60+.001:
            raise ValueError('Queen teleported')
    fights=[r for r in rows if not r.get('explicit_initial_probe')]
    if selected=='all' and {r['id'] for r in fights}!={'borrow_then_change_layer','central_ground_shoot','outer_ground_wait','outer_right_wait','pillar_top_wait','gap_ground_wait','middle_top_wait','noH_two_R_middle'}:
        raise ValueError('Eight full-fight strategies required')
    if len({(r['initial_player_hp'],r['initial_boss_hp'],r['initial_energy'],tuple(r['initial_fields'])) for r in fights})>1:
        raise ValueError('Fight controls require identical actual initial resources')
    for row in fights:
        if not row['retained_in_arena']:raise ValueError('Falling below map is an actual failure')
        if row['id']=='borrow_then_change_layer':
            if not row.get('borrowed'):raise ValueError('Intended first knot H did not occur')
            contacts=[e for e in events if e['case']==row['id'] and e.get('event')=='actual_hook_target_contact']
            if not contacts or contacts[0]['target_position']!=data['geometry']['weave_fields'][0]['knot_position']:raise ValueError('Wrong nearest-target capture cannot count as intended H')
    if selected in ('all','mature'):
        own=[e for e in events if e['case']=='explicit_mature_band_landing']
        if not any(e.get('event')=='weave_sweep' and e.get('actual_physical_contact') for e in own):
            raise ValueError('Actual physical mature-band contact required')
        if not any(e.get('event')=='policy_result' and e.get('source')=='queen_growing_weave' and e.get('target')=='player' for e in own):
            raise ValueError('Actual mature-band damage must resolve through Policy')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output-dir', required=True)
    parser.add_argument('--case', choices=['all','mature','borrow_then_change_layer','central_ground_shoot','outer_ground_wait','outer_right_wait','pillar_top_wait','gap_ground_wait','middle_top_wait','noH_two_R_middle'], default='all')
    args = parser.parse_args()
    out = (ROOT / args.output_dir).resolve()
    if not out.is_relative_to((ROOT / 'build/forest_depth/queen').resolve()):
        parser.error('output must be beneath build/forest_depth/queen')
    if out.exists() and any(out.iterdir()):
        parser.error('fresh output directory required')
    out.mkdir(parents=True, exist_ok=True)
    before = level_formal.source_files()
    verifier = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in [Path(__file__).resolve(), ROOT / 'tests/thorn_queen_network_runner.gd', ROOT / 'tests/thorn_queen_migration_runner.gd', ROOT / 'tests/thorn_queen_weave_runner.gd']}
    receipt = {'case': args.case, 'scope': 'Isolated Queen shelter/network comparison, not Boss or map2 admission',
               'source_before': before, 'verifier_before': verifier, 'passed': False}
    start = time.monotonic()
    try:
        with (out / 'native.log').open('w') as log, contextlib.redirect_stdout(log):
            text = run_engine(['--headless', '--fixed-fps', '60', '--path', '.', '--script',
                               'tests/thorn_queen_network_runner.gd', '--',
                               f'--case={args.case}', f'--output-dir=res://{out.relative_to(ROOT)}'], 120)
        if not re.search(r'^QUEEN NETWORK GOLDEN: [1-9]\d* assertions, 0 failures$', text, re.M):
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
                                     for path in [Path(__file__).resolve(), ROOT / 'tests/thorn_queen_network_runner.gd', ROOT / 'tests/thorn_queen_migration_runner.gd', ROOT / 'tests/thorn_queen_weave_runner.gd']}
        receipt['verifier_guard'] = receipt['verifier_sha256'] == verifier
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        if not receipt['source_guard'] or not receipt['verifier_guard']:
            raise RuntimeError('Source changed during capture')
    print('PASS: Queen isolated mechanism technical observations; value and map2 admission UNVERIFIED')


if __name__ == '__main__':
    main()
