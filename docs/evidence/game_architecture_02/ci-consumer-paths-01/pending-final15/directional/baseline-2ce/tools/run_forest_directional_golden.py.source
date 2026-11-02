"""Bounded real-Motor directional forest golden, not formal region admission."""
import argparse,fcntl,hashlib,json,math,os,pathlib,re,subprocess,time
ROOT=pathlib.Path(__file__).resolve().parents[1]
ERRORS=re.compile(r'(?m)SCRIPT ERROR:|Parse Error:|SHADER ERROR:|^ERROR:|ObjectDB.*leaked|resources? still in use at exit')
def inventory():
    paths=[ROOT/'project.godot']
    for directory in ('scripts','scenes','resources','config','shaders','assets','tests','tools'):
        paths += [p for p in (ROOT/directory).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc']
    return {p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}
# Source fragment for the existing golden wrapper, not another runtime.
def _xy(value):
    return isinstance(value,list) and len(value)==2 and all(isinstance(x,(int,float)) and not isinstance(x,bool) and math.isfinite(x) for x in value)
def _distance(a,b):return math.hypot(a[0]-b[0],a[1]-b[1])
def _near(a,b,tolerance=.2):return _xy(a) and _xy(b) and _distance(a,b)<=tolerance
def _factory_manifest():
    source=(ROOT/'scripts/generation/forest_directional_geometry.gd').read_text()
    version=re.search(r'const VERSION := "([^"]+)"',source).group(1)
    literal=source.split('static func build() -> Dictionary:',1)[1].split('\nstatic func ',1)[0].strip()
    return json.JSONDecoder().raw_decode(literal.removeprefix('return ').replace('"version":VERSION','"version":'+json.dumps(version)))[0]
def _runtime_numbers():
    tuning=json.loads((ROOT/'config/player_tuning.json').read_text())
    resource=(ROOT/'resources/player/traversal.tres').read_text()
    definition=(ROOT/'scripts/player/traversal_definition.gd').read_text()
    def number(name):
        found=re.search(r'(?m)^'+name+r'\s*=\s*([\d.]+)',resource) or re.search(r'var '+name+r'\s*:=\s*([\d.]+)',definition)
        return float(found.group(1))
    kick=re.search(r'hook_kick\s*=\s*Vector2\(([-\d.]+),\s*([-\d.]+)\)',resource)
    return tuning,{'range':number('hook_range'),'pull_speed':number('hook_pull_speed'),'stop':number('hook_stop_distance'),'contact':number('hook_contact_seconds'),'launch':number('hook_launch_seconds'),'kick':[float(kick[1]),float(kick[2])]}
def _support(frame,platform):
    x,y=frame['position'];px,py,w,_=platform['rect']
    return frame['grounded'] and x-12>=px-.1 and x+12<=px+w+.1 and abs(y+18-py)<=1

def _resource_errors(frames,events,tuning):
    """Replay the existing no-enemy golden's economy in controller tick order.

    This scene contains only static supports and GrappleAnchors, no Damageable
    enemy/committed-hit source. Future combat layouts must serialize genuine hit
    receipts before admitting hit refunds; an arbitrary positive delta is not one.
    """
    resource=(ROOT/'resources/player/plains_shot_energy.tres').read_text()
    definition=(ROOT/'scripts/resources/definitions/shot_energy_definition.gd').read_text()
    def number(name):
        found=re.search(r'(?m)^'+name+r'\s*=\s*([\d.]+)',resource) or re.search(r'var '+name+r'\s*:=\s*([\d.]+)',definition)
        return float(found.group(1))
    capacity=number('capacity');energy=number('initial_current');cost=number('shot_energy_cost');recovery=number('ground_recovery');delay_limit=number('recovery_delay')
    delay=0.;shots=tuning['max_air_shots'];previous_grounded=False;hook_used=False;errors=[];dt=1/tuning['physics_hz']
    for f in frames:
        accepted=[e for e in events if e['tick']==f['tick'] and e['kind']=='shot_fired']
        if any(e['tick']==f['tick'] and e['kind']=='hook_cast' for e in events):hook_used=True
        if f['grounded'] or any(e['tick']==f['tick'] and e['kind']=='hook_kick' for e in events):hook_used=False
        if f['hook_used']!=hook_used and 'H_token_not_actual_cast_contact_or_ground' not in errors:errors.append('H_token_not_actual_cast_contact_or_ground')
        jumped=any(e['tick']==f['tick'] and e['kind']=='jumped' for e in events)
        recovery_delta=max(0.,dt-delay);delay=max(0.,delay-dt)
        if previous_grounded:energy=min(capacity,energy+recovery*recovery_delta)
        started_grounded=previous_grounded and not jumped
        for _ in accepted:
            energy-=cost;delay=delay_limit
            if not started_grounded:shots-=1
        if f['grounded']:shots=tuning['max_air_shots']
        elif started_grounded:shots=max(0,shots-len(accepted))
        if not 0<=f['energy']<=capacity and 'energy_outside_real_capacity' not in errors:errors.append('energy_outside_real_capacity')
        if abs(f['energy']-energy)>.001 and 'energy_not_actual_shot_cost_delay_and_ground_recovery' not in errors:errors.append('energy_not_actual_shot_cost_delay_and_ground_recovery')
        if f['shots']!=shots and 'charges_not_actual_accepted_shot_and_ground_reset' not in errors:errors.append('charges_not_actual_accepted_shot_and_ground_reset')
        previous_grounded=f['grounded']
    return errors

def validate(data):
    """Recompute the physical phrase; summary booleans are consistency fields only.

    This is the fixed golden's contract, not an exhaustive controller search.
    Held-jump intent was not serialized by the frozen runner: its accepted signal
    and actual takeoff body state are checked, without inventing request records.
    """
    errors=[]
    fail=lambda reason:errors.append(reason) if reason not in errors else None
    if not isinstance(data,dict):return ['capture_not_object']
    if data.get('layout')=='narrow':return validate_narrow(data)
    try:manifest=_factory_manifest();tuning,h=_runtime_numbers()
    except (ValueError,AttributeError,IndexError):return ['authoritative_geometry_or_tuning_unreadable']
    if data.get('manifest')!=manifest:fail('manifest_not_frozen_factory_geometry')
    variant=data.get('variant')
    if variant not in ['intended','noH','naivejump','onlyR']:fail('variant_unknown')
    if data.get('audio_released') is not True or data.get('manual_motor_step') is not False or data.get('midroute_injection') is not False:fail('native_teardown_or_privileged_motion')
    frames=data.get('frames');events=data.get('events');requests=data.get('requests')
    if not isinstance(frames,list) or len(frames)<24:return errors+['continuous_body_frames_missing']
    if not isinstance(events,list) or not events:return errors+['accepted_event_stream_missing']
    if not isinstance(requests,list):return errors+['request_stream_missing']
    for i,f in enumerate(frames):
        if not isinstance(f,dict) or f.get('tick')!=i+1 or f.get('motor_steps')!=1 or not _xy(f.get('position')) or not _xy(f.get('velocity')) or type(f.get('grounded')) is not bool or type(f.get('hook_used')) is not bool or not isinstance(f.get('hook_state'),str) or type(f.get('shots')) is not int or not isinstance(f.get('energy'),(int,float)) or not math.isfinite(f['energy']):
            return errors+['frame_body_velocity_resource_or_tick_contract']
    by_tick={f['tick']:f for f in frames};hz=tuning['physics_hz'];dt=1/hz
    for stream,name in [(events,'events'),(requests,'requests')]:
        if any(not isinstance(e,dict) or type(e.get('tick')) is not int or e['tick'] not in by_tick or not isinstance(e.get('kind'),str) for e in stream):return errors+['malformed_'+name]
        if any(a['tick']>b['tick'] for a,b in zip(stream,stream[1:])):fail(name+'_not_temporal')
    for e in events:
        if e['kind'].startswith('hook_') or e['kind'] in ['free','phase']:
            if not _xy(e.get('position')):return errors+['event_body_position_missing']
        if e['kind']=='shot_fired' and (not _xy(e.get('direction')) or abs(math.hypot(*e['direction'])-1)>.002):return errors+['accepted_shot_direction_missing_or_not_normalized']
    for r in requests:
        if r['kind'] not in ['grapple','shoot_release'] or not _xy(r.get('direction')) or type(r.get('queued')) is not bool:return errors+['malformed_actual_request']
    platforms={p['id']:p for p in manifest['platforms']};anchors={p['id']:p['position'] for p in manifest['hook_anchors']}
    for f in frames:
        if not 0<=f['shots']<=tuning['max_air_shots'] or f['energy']<0:fail('resource_outside_real_capacity')
        for id,flag in [('crown','crown_support'),('entry','entry_support')]:
            px,py,w,_=platforms[id]['rect']
            poses=[f['position'],by_tick.get(f['tick']-1,f)['position']]
            if f.get(flag) is True and not (f['grounded'] and any(x+12>px and x-12<px+w and abs(y+18-py)<=1 for x,y in poses)):fail('reported_support_not_actual_body_contact')
        for p in manifest['platforms']:
            if p['one_way']:continue
            x,y=f['position'];px,py,w,height=p['rect']
            if min(x+12,px+w)-max(x-12,px)>.2 and min(y+18,py+height)-max(y-18,py)>.2:fail('body_inside_solid')
    for f in frames:
        if f['grounded']:
            poses=[f['position'],by_tick.get(f['tick']-1,f)['position']]
            if not any(any(x+12>p['rect'][0]-.2 and x-12<p['rect'][0]+p['rect'][2]+.2 and abs(y+18-p['rect'][1])<=1 for x,y in poses) for p in manifest['platforms']):fail('grounded_without_actual_support_surface')
    if not all(_support(f,platforms['entry']) and _near(f['position'],manifest['spawn'],1) for f in frames[:8]):fail('stable_initial_entry_missing')
    errors.extend(_resource_errors(frames,events,tuning))
    shot_events=[e for e in events if e['kind']=='shot_fired'];jump_events=[e for e in events if e['kind']=='jumped']
    shot_ticks={e['tick'] for e in shot_events};kick_ticks={e['tick'] for e in events if e['kind']=='hook_kick'}
    max_motion=max(h['pull_speed'],tuning['shot_burst_speed'],math.hypot(tuning['ground_speed'],tuning['max_normal_fall_speed']))*dt+.25
    for previous,f in zip(frames,frames[1:]):
        if _distance(previous['position'],f['position'])>max_motion:fail('unexplained_body_displacement_or_deleted_frames')
        x0,y0=previous['position'];x1,y1=f['position']
        near_solid=any(min(max(x0,x1)+12.3,p['rect'][0]+p['rect'][2])-max(min(x0,x1)-12.3,p['rect'][0])>0 and min(max(y0,y1)+18.3,p['rect'][1]+p['rect'][3])-max(min(y0,y1)-18.3,p['rect'][1])>0 for p in manifest['platforms'])
        actual=[x1-x0,y1-y0];expected=[v*dt for v in f['velocity']]
        if not near_solid and not _near(actual,expected,.2):fail('freeflight_velocity_not_actual_position_delta')
        delta=f['shots']-previous['shots']
        if delta<0 and (f['tick'] not in shot_ticks or delta!=-1):fail('shot_charge_spent_without_real_shot')
        if delta>0 and not (f['grounded'] or previous['grounded']):fail('air_shot_refill_without_recorded_cause')
        if previous['hook_used'] and not f['hook_used'] and not (f['grounded'] or previous['grounded'] or f['tick'] in kick_ticks):fail('H_restored_without_landing_or_kick')
    for e in events:
        if _xy(e.get('position')):
            f=by_tick[e['tick']];previous=by_tick.get(e['tick']-1,f)
            if min(_distance(e['position'],f['position']),_distance(e['position'],previous['position']))>.25:fail('event_position_not_actual_body_frame')
    for e in jump_events:
        f=by_tick[e['tick']];previous=by_tick.get(e['tick']-1)
        if previous is None or not previous['grounded'] or f['velocity'][1]>=-tuning['ground_speed']:fail('jump_event_without_grounded_takeoff')
    if not jump_events:fail('actual_takeoff_missing')
    for e in shot_events:
        matches=[r for r in requests if r['kind']=='shoot_release' and r['tick']==e['tick'] and _near(r.get('direction'),e.get('direction'),.001) and r.get('queued') is True]
        if len(matches)!=1:fail('accepted_shot_not_bound_to_request')
    for r in requests:
        if r['kind']=='shoot_release' and not any(e['tick']==r['tick'] for e in shot_events):fail('shoot_request_without_accepted_shot')
    expected_contacts=[]
    for f in frames:
        x,y=f['position']
        for danger in manifest['dangers']:
            px,py,w,height=danger
            if x-12<px+w and x+12>px and y-18<py+height and y+18>py:expected_contacts.append((f['tick'],danger,[x-12,y-18,24,36],f['position']))
    recorded=data.get('danger_contacts')
    if not isinstance(recorded,list) or len(recorded)!=len(expected_contacts):fail('danger_contact_stream_not_body_recomputed')
    else:
        for row,(tick,danger,body,position) in zip(recorded,expected_contacts):
            if not isinstance(row,dict) or row.get('tick')!=tick or row.get('danger')!=danger or not _near(row.get('position'),position,.001) or not isinstance(row.get('body'),list) or len(row['body'])!=4 or any(not isinstance(a,(int,float)) or not math.isfinite(a) or abs(a-b)>.001 for a,b in zip(row['body'],body)):fail('danger_contact_payload_not_actual_body')
    def support_runs(id,minimum=12,after=0,before=None):
        found=[];window=[]
        for f in frames:
            if f['tick']>after and (before is None or f['tick']<before) and _support(f,platforms[id]):window.append(f)
            else:
                if len(window)>=minimum:found.append(window)
                window=[]
        if len(window)>=minimum:found.append(window)
        return found
    final_entry=support_runs('entry')
    if not final_entry or final_entry[-1][-1]['tick']!=frames[-1]['tick']:fail('complete_final_entry_support_window_missing')
    if variant=='intended':
        if expected_contacts:fail('intended_body_entered_danger')
        if not requests or not shot_events:fail('intended_requests_and_shots_missing')
        steps=manifest['steps'];targets=[steps[0]['anchor_id'],steps[1]['then'],steps[2]['anchor_id'],manifest['return']['catch_anchor_id'],manifest['return']['anchor_id']]
        flies=[e for e in events if e['kind']=='hook_fly'];casts=[e for e in events if e['kind']=='hook_cast'];pulls=[e for e in events if e['kind']=='hook_pull'];contacts=[e for e in events if e['kind']=='hook_contact_kick'];kicks=[e for e in events if e['kind']=='hook_kick'];frees=[e for e in events if e['kind']=='free']
        if not all(len(stream)==len(targets) for stream in [casts,flies,pulls,contacts,kicks,frees]):return errors+['complete_actual_H_state_chains_missing']
        for i,target in enumerate(targets):
            cast,pull,contact,kick,end=[stream[i] for stream in [casts,pulls,contacts,kicks,frees]]
            fly=flies[i]
            ts=[x['tick'] for x in [cast,fly,pull,contact,kick,end]]
            if ts!=sorted(set(ts)) or (i and cast['tick']<=frees[i-1]['tick']) or any(e.get('target')!=target for e in [pull,contact,kick,end]):fail('H_state_order_or_target_causality')
            matches=[r for r in requests if r['kind']=='grapple' and r['tick']==cast['tick'] and r.get('queued') is True]
            origin=[cast['position'][0],cast['position'][1]-6]
            offset=[anchors[target][j]-origin[j] for j in [0,1]];length=math.hypot(*offset)
            if len(matches)!=1 or not _xy(matches[0].get('direction')) or not _near(matches[0]['direction'],[v/length for v in offset],.002) or length>h['range']+12:fail('H_cast_not_bound_to_real_direction_and_range')
            for state,e in [('hook_cast',cast),('hook_pull',pull),('hook_contact_kick',contact),('hook_kick',kick),('free',end)]:
                if by_tick[e['tick']]['hook_state']!=state:fail('H_event_without_matching_live_traversal_state')
            for begin,finish,allowed in [(cast['tick'],fly['tick'],{'hook_cast'}),(fly['tick'],pull['tick'],{'hook_fly'}),(pull['tick'],contact['tick'],{'hook_pull'}),(contact['tick'],kick['tick'],{'hook_contact_kick'}),(kick['tick'],end['tick'],{'hook_kick'})]:
                if any(by_tick[t]['hook_state'] not in allowed for t in range(begin,finish)):fail('H_state_interval_not_real_continuous_motion')
            pull_frames=[by_tick[t] for t in range(pull['tick'],contact['tick']+1)]
            if any(_distance(b['position'],anchors[target])>_distance(a['position'],anchors[target])+.2 for a,b in zip(pull_frames,pull_frames[1:])):fail('H_pull_does_not_approach_actual_target')
            if _distance(contact['position'],anchors[target])>h['stop']+12.3 or _distance(pull['position'],contact['position'])<4:fail('H_contact_without_actual_approach')
            hold=[by_tick[t] for t in range(contact['tick']+1,kick['tick'])]
            if len(hold)<max(1,math.floor(h['contact']*hz)-1) or not all(_near(f['position'],contact['position']) and math.hypot(*f['velocity'])<.3 for f in hold):fail('actual_H_contact_hold_missing')
            side=-1 if origin[0]<anchors[target][0] else 1
            expected=[side*h['kick'][0]*h['launch'],h['kick'][1]*h['launch']]
            delta=[end['position'][j]-kick['position'][j] for j in [0,1]]
            if not _near(delta,expected,.05):fail('away_side_kick_not_actual_displacement')
            for t in range(kick['tick'],end['tick']):
                elapsed=min((t-kick['tick']+1)*dt,h['launch'])
                predicted=[kick['position'][0]+side*h['kick'][0]*elapsed,kick['position'][1]+h['kick'][1]*elapsed]
                if not _near(by_tick[t]['position'],predicted,.15):fail('kick_path_not_full_actual_burst')
            if any(not by_tick[t]['hook_used'] for t in range(cast['tick'],kick['tick']) if not by_tick[t]['grounded'] and not any(by_tick.get(k,{}).get('grounded',False) for k in range(cast['tick'],t+1))):fail('H_token_not_spent_before_success')
            if by_tick[kick['tick']]['hook_used'] or by_tick[end['tick']]['hook_used']:fail('successful_H_did_not_restore_real_token')
        for i in [1,2,4]:
            if any(f['grounded'] for f in frames if kicks[i-1]['tick']<f['tick']<=casts[i]['tick']):fail('relay_H_depends_on_hidden_landing')
        if len(shot_events)!=2:return errors+['outward_and_return_actual_shots_missing']
        if not frees[0]['tick']<shot_events[0]['tick']<casts[1]['tick'] or shot_events[1]['tick']<=frees[-1]['tick']:fail('R_not_between_real_H_and_route_transition')
        for e in shot_events:
            t=e['tick'];previous=by_tick.get(t-1);end=by_tick.get(t+math.ceil(tuning['shot_burst_duration']*hz)-1)
            if previous is None or end is None or previous['grounded'] or not _xy(e.get('direction')):fail('airborne_R_window_missing');continue
            distance=tuning['shot_burst_speed']*tuning['shot_burst_duration'];actual=[end['position'][j]-previous['position'][j] for j in [0,1]]
            if not _near(actual,[-v*distance for v in e['direction']],.1):fail('shot_event_without_actual_full_recoil_burst')
            for k in range(t,end['tick']+1):
                elapsed=min((k-t+1)*dt,tuning['shot_burst_duration'])
                predicted=[previous['position'][j]-e['direction'][j]*tuning['shot_burst_speed']*elapsed for j in [0,1]]
                if not _near(by_tick[k]['position'],predicted,.15):fail('R_path_not_full_actual_burst')
        crown=support_runs('crown',after=frees[2]['tick'],before=casts[3]['tick'])
        if not crown:fail('twelve_actual_full_body_crown_support_frames_missing')
        near=3;cast=casts[near];pull=pulls[near];contact=contacts[near]
        before=by_tick[cast['tick']-1];after=by_tick[contact['tick']+1]
        if before['grounded'] or before['velocity'][1]<tuning['ground_speed'] or by_tick[pull['tick']]['velocity'][1]<=0 or after['velocity'][1]>.3 or after['position'][1]>=by_tick[pull['tick']]['position'][1]:fail('fallcatch_without_real_fall_arrest')
        if crown and not any(f['velocity'][1]>tuning['ground_speed'] and not f['grounded'] for f in frames if crown[-1][-1]['tick']<f['tick']<cast['tick']):fail('return_drop_actual_fall_missing')
        if data.get('reached') is not True or data.get('returned') is not True or data.get('passed') is not True:fail('native_summary_disagrees_with_recomputed_phrase')
    else:
        if not expected_contacts:fail('negative_has_no_actual_physical_danger_contact')
        first=expected_contacts[0][0] if expected_contacts else frames[-1]['tick']
        if support_runs('crown'):fail('comparison_is_real_alternative_not_failure')
        recovery=support_runs('recovery',after=first);step=support_runs('recovery_step',6,after=first)
        if not recovery or not step or not final_entry or not recovery[0][0]['tick']<step[0][0]['tick']<final_entry[-1][0]['tick']:fail('physical_recovery_support_chain_missing')
        if len([e for e in jump_events if e['tick']>first])<2:fail('recovery_real_takeoffs_missing')
        if any(e['kind'] in ['hook_pull','hook_contact_kick','hook_kick'] for e in events):fail('comparison_unexpected_actual_H')
        if variant=='noH' and not any(r['kind']=='grapple' for r in requests):fail('noH_ablation_has_no_matching_attempt')
        if variant=='onlyR' and len([e for e in shot_events if e['tick']<first])<2:fail('onlyR_real_two_shots_missing')
        if variant=='naivejump' and shot_events:fail('naive_jump_uses_recoil')
        if data.get('reached') is not False or data.get('recovered') is not True or data.get('passed') is not True:fail('native_summary_disagrees_with_physical_comparison')
    return errors

def _narrow_manifest():
    """Read this data-only factory's literal overrides; unknown statements fail closed."""
    import copy
    data=copy.deepcopy(_factory_manifest())
    source=(ROOT/'scripts/generation/forest_directional_geometry.gd').read_text().split('static func build_narrow()',1)[1].split('static func as_module',1)[0]
    for line in source.splitlines()[1:]:
        line=line.strip()
        if not line or line.startswith('#') or line in ['var data := build()','return data']:continue
        field,value=line.removeprefix('data.').split('=',1)
        if value=='[data.hook_anchors[0]]':value=[data['hook_anchors'][0]]
        elif value=='data.world_bounds.duplicate()':value=data['world_bounds'][:]
        else:value=json.loads(value)
        if field=='platforms[2]':data['platforms'][2]=value
        else:data[field]=value
    return data

def validate_narrow(data):
    errors=[]
    def require(condition,label):
        if not condition and label not in errors:errors.append(label)
    manifest=_narrow_manifest();tuning,h=_runtime_numbers()
    require(data.get('manifest')==manifest,'narrow_manifest_not_authoritative_factory')
    frames=data.get('frames');events=data.get('events');requests=data.get('requests')
    if not isinstance(frames,list) or len(frames)<24 or not isinstance(events,list) or not isinstance(requests,list):return errors+['narrow_continuous_streams_missing']
    for i,f in enumerate(frames):
        if not isinstance(f,dict) or f.get('tick')!=i+1 or f.get('motor_steps')!=1 or not _xy(f.get('position')) or not _xy(f.get('velocity')) or type(f.get('grounded')) is not bool or not isinstance(f.get('health'),(int,float)) or type(f.get('actor_epoch')) is not int:return errors+['narrow_frame_body_resource_contract']
    by={f['tick']:f for f in frames};platforms={p['id']:p for p in manifest['platforms']}
    require(all(_support(f,platforms['entry']) for f in frames[:8]),'narrow_initial_bank_missing')
    require(all(_support(f,platforms['entry']) for f in frames[-12:]),'narrow_final_full_body_entry_missing')
    for stream in [events,requests]:
        if any(not isinstance(e,dict) or e.get('tick') not in by or not isinstance(e.get('kind'),str) for e in stream):return errors+['narrow_malformed_action_stream']
    require(data.get('audio_released') is True and data.get('segment_ready') is True and data.get('manual_motor_step') is False and data.get('midroute_injection') is False,'narrow_production_setup_or_teardown')
    damage=data.get('damage_events');returns=data.get('policy_returns')
    if not isinstance(damage,list) or not isinstance(returns,list):return errors+['narrow_policy_facts_missing']
    initial=data.get('initial_health');final=data.get('final_health')
    # Default production player's configured health, with no test-time inflation.
    health_source=(ROOT/'resources/actors/prototype_health.tres').read_text()
    configured_health=float(re.search(r'(?m)^max_health\s*=\s*([\d.]+)',health_source).group(1))
    require(isinstance(initial,(int,float)) and initial==configured_health and data.get('max_health')==initial,'narrow_normal_initial_health_contract')
    reset_ticks={r['capture_tick']+1 for r in returns if isinstance(r,dict) and type(r.get('capture_tick')) is int}
    for a,b in zip(frames,frames[1:]):
        if b['tick'] in reset_ticks:continue
        require(_distance(a['position'],b['position'])<=h['pull_speed']/tuning['physics_hz']+.3,'narrow_unexplained_body_displacement')
        require(b['health']==a['health'],'narrow_health_changed_without_real_policy_return')
        require(b['actor_epoch']==a['actor_epoch'],'narrow_actor_epoch_changed_without_return')
    def runs(id,minimum,after=0):
        count=0;found=[]
        for f in frames:
            count=count+1 if f['tick']>after and _support(f,platforms[id]) else 0
            if count==minimum:found.append(f['tick'])
        return found
    contacts=[]
    for f in frames:
        x,y=f['position']
        for r in manifest['dangers']:
            if x-12<r[0]+r[2] and x+12>r[0] and y-18<r[1]+r[3] and y+18>r[1]:contacts.append((f['tick'],r))
    require([(c.get('tick'),c.get('danger')) for c in data.get('danger_contacts',[])]==contacts,'narrow_body_contacts_not_recomputed')
    shots=[e for e in events if e['kind']=='shot_fired']
    for e in shots:
        require(any(r['kind']=='shoot_release' and r['tick']==e['tick'] and r.get('queued') is True and _near(r.get('direction'),e.get('direction'),.001) for r in requests),'narrow_shot_without_actual_request')
    if data.get('variant')=='intended':
        errors.extend(_resource_errors(frames,events,tuning))
        require(not contacts and not damage and not returns and final==initial,'narrow_intended_actual_damage')
        states=['hook_cast','hook_fly','hook_pull','hook_contact_kick','hook_kick','free']
        chain=[]
        for state in states:
            found=[e for e in events if e['kind']==state]
            if len(found)!=1 or not _xy(found[0].get('position')):return errors+['narrow_actual_H_chain_missing']
            chain.append(found[0])
        require([e['tick'] for e in chain]==sorted(set(e['tick'] for e in chain)),'narrow_H_order')
        cast,fly,pull,contact,kick,end=chain
        require(all(e.get('target')=='side_ring' for e in chain[2:]),'narrow_actual_H_target')
        anchor=manifest['hook_anchors'][0]['position'];origin=[cast['position'][0],cast['position'][1]-6];length=_distance(origin,anchor)
        require(length<=h['range']+12 and any(r['kind']=='grapple' and r['tick']==cast['tick'] and r.get('queued') is True and _near(r.get('direction'),[(anchor[j]-origin[j])/length for j in [0,1]],.002) for r in requests),'narrow_actual_H_request_range_direction')
        for e in chain:
            require(by[e['tick']]['hook_state']==e['kind'],'narrow_live_H_state_missing')
            require(min(_distance(e['position'],by[e['tick']]['position']),_distance(e['position'],by.get(e['tick']-1,by[e['tick']])['position']))<.25,'narrow_H_event_body_mismatch')
        for start,finish,state in zip(chain,chain[1:],states):
            require(all(by[t]['hook_state']==state for t in range(start['tick'],finish['tick'])),'narrow_H_state_interval')
        require(_distance(pull['position'],contact['position'])>20 and _distance(contact['position'],anchor)<=h['stop']+12.3,'narrow_real_H_approach')
        require(_near([end['position'][j]-kick['position'][j] for j in [0,1]],[-h['kick'][0]*h['launch'],h['kick'][1]*h['launch']],.05),'narrow_actual_away_kick')
        require(len(shots)==1,'narrow_actual_single_R_missing')
        if shots:
            shot=shots[0];t=shot['tick'];n=math.ceil(tuning['shot_burst_duration']*tuning['physics_hz'])
            require(t>end['tick'] and _near(shot.get('direction'),[-1,0],.001),'narrow_R_order_or_aim')
            if t+n-1 not in by:return errors+['narrow_complete_R_window_missing']
            for k in range(n):
                predicted=[by[t-1]['position'][0]+min((k+1)/tuning['physics_hz'],tuning['shot_burst_duration'])*tuning['shot_burst_speed'],by[t-1]['position'][1]]
                require(_near(by[t+k]['position'],predicted,.15),'narrow_real_full_R_body_path')
        crown=runs('crown',12,end['tick']);require(bool(crown),'narrow_twelve_full_body_exit_support')
        floor=runs('recovery',12,crown[0] if crown else 0);step=runs('recovery_step',6,floor[0] if floor else len(frames))
        require(bool(floor) and bool(step) and len([e for e in events if e['kind']=='jumped' and e['tick']>(floor[0] if floor else len(frames))])>=2,'narrow_real_safe_lower_return_chain')
        require(data.get('reached') is True and data.get('returned') is True,'narrow_summary_not_physical_return')
    else:
        require(final==initial-sum(e.get('amount',0) for e in damage),'narrow_health_does_not_match_actual_damage')
        if data.get('variant')=='onlyR':
            require(bool(damage) and bool(returns),'narrow_onlyR_real_damage_and_segment_return_missing')
        else:
            require(data.get('variant') in ['noH','naivejump'] and not damage and not returns and final==initial,'narrow_clean_miss_policy_or_health_inconsistent')
            floor=runs('recovery',12);step=runs('recovery_step',6,floor[0] if floor else len(frames))
            require(bool(floor) and bool(step) and len([e for e in events if e['kind']=='jumped' and e['tick']>(floor[0] if floor else len(frames))])>=2,'narrow_clean_miss_complete_natural_recovery_missing')
            errors.extend(_resource_errors(frames,events,tuning))
        require(not runs('crown',12) and data.get('recovered') is True and data.get('reached') is False,'narrow_negative_must_recover_not_claim_exit')
        for e in damage:
            require(e.get('kind')==1 and e.get('amount')==1 and e.get('lethal') is False and e.get('source') in ['mouth_thorns_0','mouth_thorns_1'] and e.get('event_id') and e.get('token'),'narrow_wrong_actual_environment_result')
        for r in returns:
            require(r.get('accepted') is True and _near(r.get('to'),manifest['spawn'],.001) and r.get('actor_epoch_after')==r.get('actor_epoch_before',0)+1,'narrow_production_segment_return_invalid')
            require(any(e.get('capture_tick')==r.get('capture_tick') and e.get('health')==r.get('health') for e in damage),'narrow_return_without_same_frame_policy_damage')
    require(data.get('passed') is True,'narrow_native_summary_failed')
    return errors

def main():
    p=argparse.ArgumentParser();p.add_argument('--output-dir',type=pathlib.Path,required=True);p.add_argument('--layout',choices=['arch','narrow'],default='arch');p.add_argument('--variant',choices=['intended','noH','naivejump','onlyR','all'],default='all');a=p.parse_args()
    out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    report={'status':'running','source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'source_before':inventory(),'scope':'scheduled_InputRouter_development_golden_physical_danger_and_support_comparison','runs':[]}
    def save():(out/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
    save()
    with (ROOT/'build/verification/engine.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        for v in ['intended','noH','naivejump','onlyR'] if a.variant=='all' else [a.variant]:
            capture=out/(v+'.json');log=out/(v+'.log');argv=['bash','tools/godot.sh','--headless','--fixed-fps','60','--path','.','--script','tests/forest_directional_golden_runner.gd','--','--variant='+v,'--layout='+a.layout,'--output='+str(capture)]
            started=time.monotonic()
            try:
                with log.open('w') as stream:r=subprocess.run(argv,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=45,env={**os.environ,'LP_NUM_THREADS':'1'})
                data=json.loads(capture.read_text()) if capture.exists() else {}
                errors=validate(data) if data else ['capture_absent']
                text=log.read_text(errors='replace')
                ok=r.returncode==0 and not ERRORS.search(text) and not errors and bool(re.search(r'^FOREST DIRECTIONAL: .*passed=true',text,re.M))
                row={'variant':v,'argv':argv,'exit_code':r.returncode,'validation_errors':errors,'status':'passed' if ok else 'failed','seconds':time.monotonic()-started,'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest()}
            except subprocess.TimeoutExpired:row={'variant':v,'argv':argv,'status':'timeout','seconds':time.monotonic()-started}
            report['runs'].append(row);save();print(json.dumps(row),flush=True)
            if row['status']!='passed':break
    report['source_after']=inventory();report['source_stable']=report['source_before']==report['source_after'];report['status']='passed' if all(r['status']=='passed' for r in report['runs']) and report['source_stable'] else 'failed';save();print('FOREST DIRECTIONAL GOLDEN:',report['status'],str(out),flush=True)
    return 0 if report['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
