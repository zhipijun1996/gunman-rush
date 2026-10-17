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


def rising_damage_ids(events, case, prefix):
    """Only actual third-field sweep+Policy pairs count; body/other fields never do."""
    sweeps={e.get('id') for e in events if e.get('case')==case and e.get('event')=='weave_sweep' and e.get('field')==2 and e.get('accepted') is True}
    return [e['id'] for e in events if e.get('case')==case and e.get('event')=='policy_result' and e.get('target')=='player' and e.get('source')=='queen_growing_weave' and str(e.get('id','')).startswith(prefix) and e.get('id') in sweeps]


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
    by_frame={(f['case'],f['tick']):f for f in frames}
    for e in events:
        if e.get('event')!='actual_queen_motor_motion':continue
        f=by_frame.get((e['case'],e['tick']))
        if f is None or e['source_id']!=f['queen_motor_id'] or e['physics_frame']!=f['physics_frame']:
            raise ValueError('Actual Queen movement telemetry lost actor/frame ownership')
        if math.dist(e['after'],f['boss_position'])>.001 or math.dist([e['after'][i]-e['before'][i] for i in range(2)],[f['boss_position'][i]-e['before'][i] for i in range(2)])>.001:
            raise ValueError('Motor before/after does not match captured actual body')
        previous=by_frame.get((e['case'],e['tick']-1))
        if previous and math.dist(e['before'],previous['boss_position'])>.001:
            raise ValueError('Motor telemetry before-position differs from previous actual frame')
        if math.dist([e['before'][i]+e['actual'][i] for i in range(2)],e['after'])>.001:
            raise ValueError('Recorded actual physical displacement does not reconstruct body position')
        if math.hypot(*e['requested'])>float(data['migration_speed'])/60+.001:
            raise ValueError('Queen requested motion exceeded original speed bound')
        if e['collision'] and not all(k in e for k in ['travel','remainder','normal','collider_id','collider_name']):
            raise ValueError('Actual physical collision lacks real engine return telemetry')
    fights=[r for r in rows if not r.get('explicit_initial_probe')]
    if selected in ('all','full') and {r['id'] for r in fights}!={'full_H','full_cut','full_keep','full_wait','edge_repeat_noH'}:
        raise ValueError('Five actual equal-resource full-fight controls required')
    if len({(r['initial_player_hp'],r['initial_boss_hp'],r['initial_energy'],tuple(r['initial_fields'])) for r in fights})>1:
        raise ValueError('Fight controls require identical actual initial resources')
    for row in fights:
        if not row['retained_in_arena']:raise ValueError('Falling outside map is an actual failure')
        if selected in ('all','full') and row['id']!='full_wait' and not (row['boss_defeated'] or row['player_dead']):
            raise ValueError('Active whole fight did not actually end')
        if row['id']=='full_H' and not row['boss_defeated']:
            raise ValueError('Purpose whole fight did not defeat Queen')
        if row['id']=='full_wait' and not (row['boss_defeated'] or row['player_dead']):
            tail=[f for f in frames if f['case']=='full_wait' and f['tick']>3000]
            probes=[e for e in events if e.get('case')=='full_wait' and e.get('event')=='stationary_occlusion_probe']
            h_requests=[e for e in events if e.get('case')=='full_wait' and e.get('event')=='actual_queued_input' and e.get('action')=='grapple']
            if row.get('outcome')!='stable_occluded_stationary_ablation' or row['ticks']!=3600 or len(tail)!=600 or len(probes)<10 or h_requests:
                raise ValueError('Stationary strategy timeout lacks strict bounded-stall evidence')
            hp=tail[0]['boss_hp']
            for f in tail:
                if not (f['boss_hp']==hp and hp>0 and f['hp']>0 and f['grounded'] and abs(f['player'][1]-342)<1 and 312<=f['player'][0]<=588 and f['hook']=='free' and f['core_open'] and f['axis']==0):
                    raise ValueError('Stationary tail progressed, died, moved, lost support or used H')
            if max(f['player'][0] for f in tail)-min(f['player'][0] for f in tail)>3:
                raise ValueError('Stationary control left its actual waiting point')
            for e in probes:
                blocked=sum(t['overlap_count']>0 or (len(t['safe_fraction'])==2 and t['safe_fraction'][0]<.99999) for t in e['shape_traces'])
                if e['visible_body_sample'] or blocked<9:
                    raise ValueError('Nine actual muzzle/body shape traces do not prove sampled occlusion')

    if selected in ('all','rising'):
        row=next(r for r in rows if r['id']=='explicit_third_weave_cycle')
        own=[e for e in events if e.get('case')==row['id'] and e.get('event')=='policy_result' and e.get('target')=='player']
        actual=rising_damage_ids(events,row['id'],row['third_pressure_prefix'])
        if len(own)!=1 or len(actual)!=1 or actual!=row['third_pressure_event_ids'] or row['hp_before']!=row['initial_player_hp'] or row['hp_after']!=row['initial_player_hp']-1:
            raise ValueError('Sole rising pressure hit must pair actual third-band sweep and Policy from original fixture health')

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
    parser.add_argument('--case', choices=['all','full','full_H','full_cut','full_keep','full_wait','full_edge','collision','rising','mature','observer','fixed','shore_response','shore_H','adaptive_full'], default='all')
    args = parser.parse_args()
    out = (ROOT / args.output_dir).resolve()
    if not out.is_relative_to((ROOT / 'build/forest_depth/queen').resolve()):
        parser.error('output must be beneath build/forest_depth/queen')
    if out.exists() and any(out.iterdir()):
        parser.error('fresh output directory required')
    out.mkdir(parents=True, exist_ok=True)
    before = level_formal.source_files()
    verifier = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in [Path(__file__).resolve(), ROOT / 'tests/thorn_queen_sweep_runner.gd', ROOT / 'tests/support/forest_queen_gameplay_fixture.gd']}
    receipt = {'case': args.case, 'scope': 'Isolated Queen shelter/network comparison, not Boss or map2 admission',
               'source_before': before, 'verifier_before': verifier, 'passed': False}
    start = time.monotonic()
    try:
        with (out / 'import.log').open('w') as log, contextlib.redirect_stdout(log):
            imported = run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
        receipt['editor_import_completed'] = True
        if re.search(r'(?m)^(?:SCRIPT )?ERROR:|Parse Error:', imported):
            raise RuntimeError('Editor import error')
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
    except BaseException as error:
        receipt['error'] = repr(error)
        receipt['inner_logs'] = [str(out / name) for name in ('import.log', 'native.log') if (out / name).exists()]
        for name in ('import.log', 'native.log'):
            path = out / name
            if path.exists():
                print(f'Actual {name} tail:', flush=True)
                print('\n'.join(path.read_text(errors='replace').splitlines()[-80:]), flush=True)
        raise
    finally:
        receipt['source_after'] = level_formal.source_files()
        receipt['source_guard'] = before == receipt['source_after']
        receipt['elapsed_seconds'] = time.monotonic() - start
        receipt['verifier_sha256'] = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                                     for path in [Path(__file__).resolve(), ROOT / 'tests/thorn_queen_sweep_runner.gd', ROOT / 'tests/support/forest_queen_gameplay_fixture.gd']}
        receipt['verifier_guard'] = receipt['verifier_sha256'] == verifier
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        if not receipt['source_guard'] or not receipt['verifier_guard']:
            raise RuntimeError('Source changed during capture')
    print('PASS: Queen isolated mechanism technical observations; value and map2 admission UNVERIFIED')


if __name__ == '__main__':
    main()
