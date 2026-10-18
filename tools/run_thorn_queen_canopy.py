"""Actual-input canopy Queen v3; old v2 CLI and194 remain separate legacy consumers."""
import argparse,contextlib,hashlib,json,re,time,math
from pathlib import Path
from run_tests import run_engine
import level_formal
ROOT=Path(__file__).resolve().parent.parent

def validate(data, selected):
    if data.get('failures') or data.get('assertions',0)<12 or data.get('selected')!=selected:
        raise ValueError('Real assertions/selection failed; preserve original capture')
    if data.get('manual_motor_step') is not False or data.get('midroute_player_position_or_resource_writes') is not False:
        raise ValueError('Only normal real Player inputs permitted')
    if data.get('content_version')!='forest-queen-canopy-v3':raise ValueError('New exact content version required')
    frames=data['frames']; events=data['events']; rows=data['cases']
    for prev,f in zip(frames,frames[1:]):
        if prev['case']!=f['case']:continue
        if f['tick']!=prev['tick']+1 or f['motor_steps']!=prev['motor_steps']+1:raise ValueError('Sole Motor frame discontinuity')
        if math.dist(prev['boss_position'],f['boss_position'])>data['migration_speed']/60+.001:raise ValueError('Boss teleported')
        if f['actual_time_scale']!=1 or f['actual_focus']:raise ValueError('No unintended focus/time-scale mutation')
    by={(f['case'],f['tick']):f for f in frames}
    for e in events:
        if e.get('event')!='actual_queen_motor_motion':continue
        f=by.get((e['case'],e['tick']))
        if f is None or e['source_id']!=f['queen_motor_id'] or e['physics_frame']!=f['physics_frame']:raise ValueError('Motor actor/frame mismatch')
        if math.dist(e['after'],f['boss_position'])>.001:raise ValueError('Motor body telemetry mismatch')
        if math.dist([e['before'][i]+e['actual'][i] for i in range(2)],e['after'])>.001:raise ValueError('Actual travel mismatch')
        if math.hypot(*e['requested'])>data['migration_speed']/60+.001:raise ValueError('Motion speed changed')
    for row in rows:
        if (row['initial_player_hp'],row['initial_boss_hp'],row['initial_energy'])!=(5,24,100):raise ValueError('Unequal starting resources')
        if row['boss_hp']!=0 or row['player_hp']<=0 or row['support12']<12:raise ValueError('Full24HP natural fight and recovery required')
        own=[e for e in events if e.get('case')==row['id']]
        hits=[e for e in own if e.get('event')=='policy_result' and e.get('target')=='boss']
        if len(hits)!=24 or len({e['id'] for e in hits})!=24:raise ValueError('24 distinct actual Policy commits required')
        phases=[e for e in own if e.get('event')=='canopy_phase_started']
        if {e['phase'] for e in phases}!={2,3}:raise ValueError('Both new mechanisms must naturally start')
        if row['id']!='purpose' and any(e.get('event')=='actual_queued_input' and e.get('action')=='grapple' for e in own):raise ValueError('Ordinary used H')
        for e in phases:
            if e.get('body_flight_unchanged') is not True:raise ValueError('Field threshold must not rewrite committed body route')


def validate_mobile(data, selected):
    """Independent explicit case; never changes or projects into the old reader."""
    if selected not in ('mobile_anchor','mobile_ordinary','mobile_hook_only') or data.get('selected')!=selected:
        raise ValueError('Explicit mobile case identity required')
    if data.get('failures') or data.get('assertions',0)<12 or data.get('content_version')!='forest-queen-canopy-v3':
        raise ValueError('Actual complete mobile case assertions required')
    if data.get('manual_motor_step') is not False or data.get('midroute_player_position_or_resource_writes') is not False or data.get('migration_speed')!=360:
        raise ValueError('Unchanged actual Player and360 Boss motion required')
    frames,events,rows=data['frames'],data['events'],data['cases']
    if len(rows)!=1 or rows[0]['id']!=selected or not frames:raise ValueError('One explicit actual case required')
    row=rows[0];by={f['tick']:f for f in frames}
    if (row['initial_player_hp'],row['initial_boss_hp'],row['initial_energy'])!=(5,24,100) or row['boss_hp']!=0 or row['player_hp']<=0 or row['support12']<12:
        raise ValueError('Equal initial resources, full24HP fight and actual support12 required')
    for prev,f in zip(frames,frames[1:]):
        if f['case']!=selected or f['tick']!=prev['tick']+1 or f['motor_steps']!=prev['motor_steps']+1:raise ValueError('Actual sole Motor continuity required')
        if math.dist(prev['boss_position'],f['boss_position'])>360/60+.001:raise ValueError('Moving body teleported')
        if f['actual_time_scale']!=1 or f['actual_focus']:raise ValueError('No slowtime/focus mutation')
        if not (412<=f['player'][0]<=948 and 18<=f['player'][1]<=582):raise ValueError('Actual whole body left sealed arena')
        if f['queen_grapple_group'] is not f['mobile_anchor'] or (f['queen_grapple_group'] and (f['boss_hp']<=0 or f['motion_mode']=='intro')):raise ValueError('Mobile group must be derived from live nonintro Boss')
    for e in events:
        if e.get('event')!='actual_queen_motor_motion':continue
        f=by.get(e['tick'])
        if f is None or e['source_id']!=f['queen_motor_id'] or e['physics_frame']!=f['physics_frame']:raise ValueError('Actual Boss motor/frame mismatch')
        if math.dist(e['after'],f['boss_position'])>.001 or math.dist([e['before'][i]+e['actual'][i] for i in range(2)],e['after'])>.001:raise ValueError('Actual colliding Boss movement mismatch')
        if math.hypot(*e['requested'])>360/60+.001:raise ValueError('Boss speed changed')
    hits=[e for e in events if e.get('event')=='policy_result' and e.get('target')=='boss']
    if len(hits)!=24 or len({e['id'] for e in hits})!=24 or any(e['amount']!=1 or e['hp']!=23-i for i,e in enumerate(hits)):
        raise ValueError('24 distinct real oneHP Policy commits required')
    contexts=[e for e in events if e.get('event')=='mobile_actual_damage_context']
    if len(contexts)!=24 or {e['id'] for e in contexts}!={e['id'] for e in hits}:raise ValueError('Actual damage owner/context ledger missing')
    shots={e['serial']:e for e in events if e.get('event')=='accepted_shot'}
    for e in contexts:
        f=by.get(e['tick'])
        if e.get('submission_accepted') is not True or f is None or e['source_actor_id']!=f['player_instance'] or e['target_actor_id']!=f['queen_motor_id'] or e['session_id']!=f['session_id']:raise ValueError('Damage context actual owner/session mismatch')
        if e['damage_type']=='projectile' and e['shot_id'] not in shots:raise ValueError('Real projectile shot missing')
    if {e['phase'] for e in events if e.get('event')=='canopy_phase_started'}!={2,3}:raise ValueError('Both existing field phases required')
    departure=by.get(row['departure_tick'])
    if departure is None or departure['grounded'] or departure['player'][0]-12<=500:raise ValueError('Actual common departure from S missing')
    requests=[e for e in events if e.get('event')=='actual_queued_input' and e.get('action')=='grapple']
    if selected=='mobile_ordinary':
        if requests or any(e['damage_type']=='grapple' for e in contexts):raise ValueError('Ordinary control must use no H')
    else:
        if (len(requests)!=1 if selected=='mobile_anchor' else not requests) or not (row['departure_tick']<row['cast_tick']<row['target_contact_tick']<row['arrival_tick']<row['kick_tick']):raise ValueError('Real mobileH prefix sequence required')
        contact,arrival,kick=[by[t] for t in (row['target_contact_tick'],row['arrival_tick'],row['kick_tick'])]
        if contact['motion_mode']!='flight' or contact['hook']!='hook_pull' or contact['hook_target_id']!=contact['queen_motor_id']:raise ValueError('H must actually catch moving Queen body')
        if arrival['hook']!='hook_contact_kick' or arrival['hook_target_id']!=arrival['queen_motor_id'] or math.dist(arrival['player'],arrival['hook_tip'])>30.05:raise ValueError('Actual surface stop arrival required')
        if not arrival['queen_contact_protected'] or kick['hook']!='hook_kick':raise ValueError('Existing target contact grace/kick required')
        pulling=[f for f in frames if row['target_contact_tick']<=f['tick']<=row['arrival_tick']]
        if len(pulling)<2 or math.dist(pulling[0]['boss_position'],pulling[-1]['boss_position'])<1:raise ValueError('Target did not move during real pull')
        if selected=='mobile_anchor' and (row['follow_shot_tick']<=row['kick_tick'] or not any(e['tick']==row['follow_shot_tick'] for e in shots.values())):raise ValueError('Followup must be a real accepted shot')
        grapple=[e for e in contexts if e['damage_type']=='grapple']
        if (len(grapple)!=1 if selected=='mobile_anchor' else len(grapple)!=24) or any(not e['id'].startswith('hook/') for e in grapple):raise ValueError('Real existing grapple damage commits required')
        if selected=='mobile_hook_only' and (shots or any(e.get('event')=='actual_queued_input' and e.get('action')=='shoot_release' for e in events)):raise ValueError('PureH control must not shoot')
    if any(b['protected'] for f in frames for b in f['band_contact_protected']):raise ValueError('Queen target contact grace must not protect separate weave bands')
    tail=frames[-int(row['support12']):]
    if len(tail)<12 or not all(f['grounded'] and f['boss_hp']==0 for f in tail):raise ValueError('Final support12 is not actual')


def validate_mixed_chase(data, selected):
    """Independent explicit case; never changes or projects into the old reader."""
    if selected not in ('mobile_mixed_chase',) or data.get('selected')!=selected:
        raise ValueError('Explicit mobile case identity required')
    if data.get('failures') or data.get('assertions',0)<12 or data.get('content_version')!='forest-queen-canopy-v3':
        raise ValueError('Actual complete mobile case assertions required')
    if data.get('manual_motor_step') is not False or data.get('midroute_player_position_or_resource_writes') is not False or data.get('migration_speed')!=360:
        raise ValueError('Unchanged actual Player and360 Boss motion required')
    frames,events,rows=data['frames'],data['events'],data['cases']
    if len(rows)!=1 or rows[0]['id']!=selected or not frames:raise ValueError('One explicit actual case required')
    row=rows[0];by={f['tick']:f for f in frames}
    if (row['initial_player_hp'],row['initial_boss_hp'],row['initial_energy'])!=(5,24,100) or row['boss_hp']!=0 or row['player_hp']<=0 or row['support12']<12:
        raise ValueError('Equal initial resources, full24HP fight and actual support12 required')
    for prev,f in zip(frames,frames[1:]):
        if f['case']!=selected or f['tick']!=prev['tick']+1 or f['motor_steps']!=prev['motor_steps']+1:raise ValueError('Actual sole Motor continuity required')
        if math.dist(prev['boss_position'],f['boss_position'])>360/60+.001:raise ValueError('Moving body teleported')
        if f['actual_time_scale']!=1 or f['actual_focus']:raise ValueError('No slowtime/focus mutation')
        if not (412<=f['player'][0]<=948 and 18<=f['player'][1]<=582):raise ValueError('Actual whole body left sealed arena')
        if f['queen_grapple_group'] is not f['mobile_anchor'] or (f['queen_grapple_group'] and (f['boss_hp']<=0 or f['motion_mode']=='intro')):raise ValueError('Mobile group must be derived from live nonintro Boss')
    for e in events:
        if e.get('event')!='actual_queen_motor_motion':continue
        f=by.get(e['tick'])
        if f is None or e['source_id']!=f['queen_motor_id'] or e['physics_frame']!=f['physics_frame']:raise ValueError('Actual Boss motor/frame mismatch')
        if math.dist(e['after'],f['boss_position'])>.001 or math.dist([e['before'][i]+e['actual'][i] for i in range(2)],e['after'])>.001:raise ValueError('Actual colliding Boss movement mismatch')
        if math.hypot(*e['requested'])>360/60+.001:raise ValueError('Boss speed changed')
    hits=[e for e in events if e.get('event')=='policy_result' and e.get('target')=='boss']
    if len(hits)!=24 or len({e['id'] for e in hits})!=24 or any(e['amount']!=1 or e['hp']!=23-i for i,e in enumerate(hits)):
        raise ValueError('24 distinct real oneHP Policy commits required')
    contexts=[e for e in events if e.get('event')=='mobile_actual_damage_context']
    if len(contexts)!=24 or {e['id'] for e in contexts}!={e['id'] for e in hits}:raise ValueError('Actual damage owner/context ledger missing')
    shots={e['serial']:e for e in events if e.get('event')=='accepted_shot'}
    for e in contexts:
        f=by.get(e['tick'])
        if e.get('submission_accepted') is not True or f is None or e['source_actor_id']!=f['player_instance'] or e['target_actor_id']!=f['queen_motor_id'] or e['session_id']!=f['session_id']:raise ValueError('Damage context actual owner/session mismatch')
        if e['damage_type']=='projectile' and e['shot_id'] not in shots:raise ValueError('Real projectile shot missing')
    if {e['phase'] for e in events if e.get('event')=='canopy_phase_started'}!={2,3}:raise ValueError('Both existing field phases required')
    departure=by.get(row['departure_tick'])
    if departure is None or departure['grounded'] or departure['player'][0]-12<=500:raise ValueError('Actual common departure from S missing')
    requests=[e for e in events if e.get('event')=='actual_queued_input' and e.get('action')=='grapple']
    if selected=='mobile_ordinary':
        if requests or any(e['damage_type']=='grapple' for e in contexts):raise ValueError('Ordinary control must use no H')
    else:
        if not requests or not (row['departure_tick']<row['cast_tick']<row['target_contact_tick']<row['arrival_tick']<row['kick_tick']):raise ValueError('Real mobileH prefix sequence required')
        contact,arrival,kick=[by[t] for t in (row['target_contact_tick'],row['arrival_tick'],row['kick_tick'])]
        if contact['motion_mode']!='flight' or contact['hook']!='hook_pull' or contact['hook_target_id']!=contact['queen_motor_id']:raise ValueError('H must actually catch moving Queen body')
        if arrival['hook']!='hook_contact_kick' or arrival['hook_target_id']!=arrival['queen_motor_id'] or math.dist(arrival['player'],arrival['hook_tip'])>30.05:raise ValueError('Actual surface stop arrival required')
        if not arrival['queen_contact_protected'] or kick['hook']!='hook_kick':raise ValueError('Existing target contact grace/kick required')
        pulling=[f for f in frames if row['target_contact_tick']<=f['tick']<=row['arrival_tick']]
        if len(pulling)<2 or math.dist(pulling[0]['boss_position'],pulling[-1]['boss_position'])<1:raise ValueError('Target did not move during real pull')
        if selected=='mobile_mixed_chase' and (row['follow_shot_tick']<=row['kick_tick'] or not any(e['tick']==row['follow_shot_tick'] for e in shots.values())):raise ValueError('Followup must be a real accepted shot')
        grapple=[e for e in contexts if e['damage_type']=='grapple']
        if not grapple or any(not e['id'].startswith('hook/') for e in grapple):raise ValueError('Real existing grapple damage commits required')
        if selected=='mobile_hook_only' and (shots or any(e.get('event')=='actual_queued_input' and e.get('action')=='shoot_release' for e in events)):raise ValueError('PureH control must not shoot')
    if any(b['protected'] for f in frames for b in f['band_contact_protected']):raise ValueError('Queen target contact grace must not protect separate weave bands')
    tail=frames[-int(row['support12']):]
    if len(tail)<12 or not all(f['grounded'] and f['boss_hp']==0 for f in tail):raise ValueError('Final support12 is not actual')



def validate_early_crown(data, selected):
    validate_mobile(data, selected)
    expected=[[550,440],[550,110],[930,110],[426,110],[426,310],[550,310],[600,200],[740,200],[740,410]]
    config=data.get('candidate_config',{})
    if data.get('experiment')!='early_crown' or config.get('experiment')!='early_crown' or config.get('same_definition_instance') is not True:
        raise ValueError('Explicit opt-in candidate and actual shared Definition instance required')
    if data['geometry']['motion_paths'][0]!=expected or config.get('path_a')!=expected:
        raise ValueError('Exact opt-in early crown path required')
    if config.get('base_resource_sha256')!=hashlib.sha256((ROOT/'resources/bosses/thorn_queen_canopy.tres').read_bytes()).hexdigest():
        raise ValueError('Candidate base resource provenance mismatch')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output-dir', required=True)
    parser.add_argument('--case', choices=['all','purpose','ordinary_cut','ordinary_keep','lure','mobile_anchor','mobile_ordinary','mobile_hook_only','mobile_mixed_chase'], default='purpose')
    parser.add_argument('--experiment', choices=['none','early_crown'], default='none')
    args = parser.parse_args()
    if args.experiment!='none' and args.case not in ('mobile_anchor','mobile_ordinary','mobile_hook_only'):
        parser.error('experiment requires explicit new mobile case')
    out = (ROOT / args.output_dir).resolve()
    if not out.is_relative_to((ROOT / 'build/forest_depth/queen').resolve()):
        parser.error('output must be beneath build/forest_depth/queen')
    if out.exists() and any(out.iterdir()):
        parser.error('fresh output directory required')
    out.mkdir(parents=True, exist_ok=True)
    mobile = args.case in ('mobile_anchor','mobile_ordinary','mobile_hook_only','mobile_mixed_chase')
    runner = 'tests/thorn_queen_canopy_mobile_anchor_runner.gd' if mobile else 'tests/thorn_queen_canopy_runner.gd'
    verifier_paths = [Path(__file__).resolve(), ROOT / 'tests/thorn_queen_canopy_runner.gd', ROOT / 'tests/support/forest_queen_canopy_fixture.gd']
    if mobile: verifier_paths.append(ROOT / runner)
    before = level_formal.source_files()
    verifier = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in verifier_paths}
    receipt = {'case': args.case, 'scope': 'New canopy-v3 full-life prototype, legacy194 unchanged; no Boss admission',
               'source_before': before, 'verifier_before': verifier, 'passed': False}
    receipt['experiment'] = args.experiment
    start = time.monotonic()
    try:
        with (out / 'import.log').open('w') as log, contextlib.redirect_stdout(log):
            imported = run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
        receipt['editor_import_completed'] = True
        if re.search(r'(?m)^(?:SCRIPT )?ERROR:|Parse Error:', imported):
            raise RuntimeError('Editor import error')
        with (out / 'native.log').open('w') as log, contextlib.redirect_stdout(log):
            text = run_engine(['--headless', '--fixed-fps', '60', '--path', '.', '--script',
                               runner, '--',
                               f'--case={args.case}', f'--output-dir=res://{out.relative_to(ROOT)}',
                               *([f'--experiment={args.experiment}'] if args.experiment!='none' else [])], 120)
        if not re.search(r'^CANOPY QUEEN GOLDEN: [1-9]\d* assertions, 0 failures$', text, re.M):
            raise RuntimeError('Complete native success marker required')
        if re.search(r'(^|\n)(?:SCRIPT )?ERROR:', text):
            raise RuntimeError('Engine resource/parse/runtime error')
        (validate_mixed_chase if args.case=='mobile_mixed_chase' else validate_early_crown if args.experiment=='early_crown' else validate_mobile if mobile else validate)(json.loads((out / 'capture.json').read_text()), args.case)
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
                                     for path in verifier_paths}
        receipt['verifier_guard'] = receipt['verifier_sha256'] == verifier
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        if not receipt['source_guard'] or not receipt['verifier_guard']:
            raise RuntimeError('Source changed during capture')
    print('PASS: Queen isolated mechanism technical observations; value and map2 admission UNVERIFIED')


if __name__ == '__main__':
    main()
