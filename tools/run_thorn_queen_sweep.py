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
    if selected=='all' and {r['id'] for r in fights}!={'borrow_then_change_layer','ordinary_cut_route','keep_net_change_layer','central_ground_shoot','gap_ground_wait','edge_repeat_noH'}:
        raise ValueError('Purpose full fight and three strongest actual ground/edge controls required')
    if len({(r['initial_player_hp'],r['initial_boss_hp'],r['initial_energy'],tuple(r['initial_fields'])) for r in fights})>1:
        raise ValueError('Fight controls require identical actual initial resources')
    for row in fights:
        if not row['retained_in_arena']:raise ValueError('Falling outside map is an actual failure')
    if selected in ('all','mature'):
        own=[e for e in events if e['case']=='explicit_mature_band_landing']
        if not any(e.get('event')=='policy_result' and e.get('source')=='queen_growing_weave' and e.get('target')=='player' for e in own):
            raise ValueError('Actual non-solid mature-thread damage must resolve through Policy')
    if selected in ('all','observer'):
        own=[e for e in events if e['case']=='explicit_phase2_weave_observer']
        contacts=[e for e in own if e.get('event')=='actual_hook_target_contact']
        target=data['geometry']['weave_fields'][1]['knot_position']
        if len(contacts)!=1 or any(e['target_position']!=target for e in contacts):
            raise ValueError('Actual borrow must contact intended living sweep knot')
        probe=next(r for r in rows if r['id']=='explicit_phase2_weave_observer')
        if not probe['borrowed'] or not probe['cut'] or probe['boss_damage_during_borrow']<1:
            raise ValueError('Real borrow -> propulsion backshot cut -> body shot required')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output-dir', required=True)
    parser.add_argument('--case', choices=['all','mature','observer','borrow_then_change_layer','ordinary_cut_route','keep_net_change_layer','central_ground_shoot','gap_ground_wait','edge_repeat_noH'], default='all')
    args = parser.parse_args()
    out = (ROOT / args.output_dir).resolve()
    if not out.is_relative_to((ROOT / 'build/forest_depth/queen').resolve()):
        parser.error('output must be beneath build/forest_depth/queen')
    if out.exists() and any(out.iterdir()):
        parser.error('fresh output directory required')
    out.mkdir(parents=True, exist_ok=True)
    before = level_formal.source_files()
    verifier = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in [Path(__file__).resolve(), ROOT / 'tests/thorn_queen_sweep_runner.gd', ROOT / 'tests/thorn_queen_network_runner.gd', ROOT / 'tests/thorn_queen_migration_runner.gd', ROOT / 'tests/thorn_queen_weave_runner.gd']}
    receipt = {'case': args.case, 'scope': 'Isolated Queen shelter/network comparison, not Boss or map2 admission',
               'source_before': before, 'verifier_before': verifier, 'passed': False}
    start = time.monotonic()
    try:
        with (out / 'native.log').open('w') as log, contextlib.redirect_stdout(log):
            text = run_engine(['--headless', '--fixed-fps', '60', '--path', '.', '--script',
                               'tests/thorn_queen_sweep_runner.gd', '--',
                               f'--case={args.case}', f'--output-dir=res://{out.relative_to(ROOT)}'], 120)
        if not re.search(r'^QUEEN SWEEP GOLDEN: [1-9]\d* assertions, 0 failures$', text, re.M):
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
                                     for path in [Path(__file__).resolve(), ROOT / 'tests/thorn_queen_sweep_runner.gd', ROOT / 'tests/thorn_queen_network_runner.gd', ROOT / 'tests/thorn_queen_migration_runner.gd', ROOT / 'tests/thorn_queen_weave_runner.gd']}
        receipt['verifier_guard'] = receipt['verifier_sha256'] == verifier
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        if not receipt['source_guard'] or not receipt['verifier_guard']:
            raise RuntimeError('Source changed during capture')
    print('PASS: Queen isolated mechanism technical observations; value and map2 admission UNVERIFIED')


if __name__ == '__main__':
    main()
