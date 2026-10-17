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
    if data.get('failures') or data.get('assertions', 0) < 8:
        raise ValueError('Native mechanism assertions failed; preserve the original capture')
    if data.get('selected') != selected:
        raise ValueError('Unexpected selected native case')
    if data.get('manual_motor_step') is not False or data.get('midroute_player_position_or_resource_writes') is not False:
        raise ValueError('Real player input contract required')
    events = data.get('events', [])
    frames = data.get('frames', [])
    if not frames:
        raise ValueError('Actual continuous physics frames required')
    for previous, frame in zip(frames, frames[1:]):
        if frame.get('case') == previous.get('case') and (frame.get('tick') != previous.get('tick') + 1 or frame.get('motor_steps') != previous.get('motor_steps') + 1):
            raise ValueError('Each case must preserve contiguous sole-Motor observations')
    rows = {row['id']: row for row in data.get('cases', [])}
    if selected in ('all', 'intended'):
        row = rows.get('borrow_knot_H', {})
        if not row.get('upper_landed') or row.get('knot_health') != 1 or row.get('severed'):
            raise ValueError('Actual H-H-R receiving branch and weakened live knot required')
        own_events = [e for e in events if e.get('case') == 'borrow_knot_H']
        states = [e for e in own_events if e.get('event') == 'hook_state']
        pattern = ['hook_cast', 'hook_fly', 'hook_pull', 'hook_contact_kick', 'hook_kick', 'free']
        if [e.get('state') for e in states] != pattern * 2:
            raise ValueError('Both complete normally accepted H state chains required')
        if data.get('capture_schema') == 2:
            own_frames = {frame['tick']: frame for frame in frames if frame.get('case') == 'borrow_knot_H'}
            for event in states:
                if own_frames.get(event['tick'], {}).get('hook') != event['state']:
                    raise ValueError('Accepted H callback must bind to its actual normal physics frame')
        hits = [e for e in own_events if e.get('event') == 'policy_result']
        if not any(e.get('target') == 'queen/weave_knot' and e.get('hp') == 1 and str(e.get('id', '')).startswith('hook/') for e in hits):
            raise ValueError('Normal configured H damage must commit to knot Health')
        if not any(e.get('target') == 'boss' and str(e.get('source', '')).startswith('player_projectile:') for e in hits):
            raise ValueError('Actual projectile Queen damage required')
    if selected in ('all', 'cut'):
        if not any(e.get('event') == 'knot_health_severed' for e in events):
            raise ValueError('Real knot Health death must cause cut')
        if not any(e.get('event') == 'policy_result' and e.get('target') == 'queen/weave_knot'
                   and e.get('hp') == 0 and str(e.get('source', '')).startswith('player_projectile:') for e in events):
            raise ValueError('Normal bullets must cut the actual knot')
    if selected in ('all', 'hazard'):
        if not any(e.get('event') == 'policy_result' and e.get('target') == 'player'
                   and e.get('source') == 'queen_growing_weave' for e in events):
            raise ValueError('Actual whole-body hazard Policy damage required')
    if selected in ('all', 'ground'):
        if not {'ground_walk_shoot', 'no_H_ground'} <= set(rows):
            raise ValueError('Both same-content ground controls required')
        for row in (rows['ground_walk_shoot'], rows['no_H_ground']):
            if row.get('ticks', 0) <= 0 or 'boss_damage' not in row:
                raise ValueError('Actual cheap strategy observations missing')
    if selected == 'all':
        expected = {'borrow_knot_H', 'cut_knot_bullets', 'ground_walk_shoot', 'no_H_ground', 'explicit_initial_whole_body_hazard', 'no_H_two_R_upper', 'no_H_right_jump', 'explicit_initial_body_contact', 'state_persistence'}
        if set(rows) != expected:
            raise ValueError('Every golden and counterfactual must remain in the full matrix')
        normal = [rows[name] for name in ('borrow_knot_H', 'cut_knot_bullets', 'ground_walk_shoot', 'no_H_ground', 'no_H_two_R_upper', 'no_H_right_jump')]
        if len({(row.get('initial_player_hp'), row.get('initial_boss_hp'), row.get('initial_knot_hp'), row.get('initial_energy')) for row in normal}) != 1:
            raise ValueError('Normal strategy comparisons must use identical initial content and resources')
        for event in events:
            if event.get('case') in {'ground_walk_shoot', 'no_H_ground', 'cut_knot_bullets', 'no_H_two_R_upper', 'no_H_right_jump'} and event.get('event') == 'hook_state' and event.get('state') in {'hook_cast', 'hook_fly', 'hook_pull', 'hook_contact_kick', 'hook_kick'}:
                raise ValueError('Ground/cut control cannot silently use H')
    if selected in ('all', 'body'):
        if not any(e.get('event') == 'policy_result' and e.get('source') == 'queen_body_contact'
                   and e.get('target') == 'player' for e in events):
            raise ValueError('Actual normally configured Boss body contact required')
    if selected in ('all', 'persistence'):
        saved = rows.get('state_persistence', {})
        if not saved.get('completed') or saved.get('restored_partial', {}).get('knot_health') != 1:
            raise ValueError('Real partial-knot scene restoration required')
        cut = saved.get('restored_cut', {})
        if cut.get('knot_health') != 0 or not cut.get('weave', {}).get('severed'):
            raise ValueError('Real severed field must remain cut after reload')
    # Technical proof deliberately does not label this mechanism valuable or admit map2.


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output-dir', required=True)
    parser.add_argument('--case', choices=['all', 'intended', 'cut', 'ground', 'hazard', 'alternatives', 'body', 'persistence'], default='all')
    args = parser.parse_args()
    out = (ROOT / args.output_dir).resolve()
    if not out.is_relative_to((ROOT / 'build/forest_depth/queen').resolve()):
        parser.error('output must be beneath build/forest_depth/queen')
    if out.exists() and any(out.iterdir()):
        parser.error('fresh output directory required')
    out.mkdir(parents=True, exist_ok=True)
    before = level_formal.source_files()
    verifier = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in [Path(__file__).resolve(), ROOT / 'tests/thorn_queen_weave_runner.gd']}
    receipt = {'case': args.case, 'scope': 'Isolated Queen first mechanism, not full Boss or map2 admission',
               'source_before': before, 'verifier_before': verifier, 'passed': False}
    start = time.monotonic()
    try:
        with (out / 'native.log').open('w') as log, contextlib.redirect_stdout(log):
            text = run_engine(['--headless', '--fixed-fps', '60', '--path', '.', '--script',
                               'tests/thorn_queen_weave_runner.gd', '--',
                               f'--case={args.case}', f'--output-dir=res://{out.relative_to(ROOT)}'], 120)
        if not re.search(r'^QUEEN WEAVE GOLDEN: [1-9]\d* assertions, 0 failures$', text, re.M):
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
                                     for path in [Path(__file__).resolve(), ROOT / 'tests/thorn_queen_weave_runner.gd']}
        receipt['verifier_guard'] = receipt['verifier_sha256'] == verifier
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        if not receipt['source_guard'] or not receipt['verifier_guard']:
            raise RuntimeError('Source changed during capture')
    print('PASS: Queen isolated mechanism technical observations; value and map2 admission UNVERIFIED')


if __name__ == '__main__':
    main()
