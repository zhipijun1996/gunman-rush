"""Actual pinned-v2 App route -> Guardian full fight -> Viewport-pointer reward -> map2.

Use a fresh guarded runtime snapshot and the host's global engine lock.
This is a consumer check, not Queen whole-Boss, device, audio or player acceptance.
"""
import argparse
import contextlib
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import time
import level_formal
from run_tests import run_engine

ROOT=Path(__file__).resolve().parents[1]
ERRORS=re.compile(r'(?m)SCRIPT ERROR:|Parse Error:|SHADER ERROR:|^ERROR:|ObjectDB.*leaked|resources? still in use at exit')
def require(ok, reason):
    if not ok:
        raise ValueError(reason)

def finite(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)

def vector(value):
    return isinstance(value, list) and len(value)==2 and all(finite(v) for v in value)

def close(first, second):
    return finite(first) and finite(second) and math.isclose(first, second, abs_tol=0.00001, rel_tol=0.000001)

def same_aim(first, second):
    return vector(first) and vector(second) and all(close(a,b) for a,b in zip(first,second))

def validate_inputs_and_health(fight):
    events=fight['events'];requests=fight.get('requests');frames=fight['frames']
    require(isinstance(requests,list) and bool(requests),'Actual combat Router request ledger required')
    for request in requests:
        require(request.get('kind') in {'grapple','shoot_release'} and type(request.get('queued')) is bool and finite(request.get('tick')) and vector(request.get('aim')),'Typed real combat request fields required')
        require(close(sum(v*v for v in request['aim']),1),'Combat input directions must be finite unit vectors')
    shots=[e for e in events if e.get('event')=='actual_shot']
    require(bool(shots),'Accepted real ordinary shots required')
    shot_ids=set()
    for shot in shots:
        shot_id=shot.get('shot_id')
        require(type(shot_id) is int and shot_id>0 and shot_id not in shot_ids,'Accepted shot serials must be unique positive integers')
        shot_ids.add(shot_id)
        require(any(r['kind']=='shoot_release' and r['queued'] is True and r['tick']==shot.get('tick') and same_aim(r['aim'],shot.get('aim')) for r in requests),'Every accepted ordinary shot needs its actual same-tick queued direction')
    casts=[e for e in events if e.get('event')=='actual_traversal' and e.get('state')=='hook_cast']
    require(bool(casts),'Actual accepted H cast required')
    for cast in casts:
        require(any(r['kind']=='grapple' and r['queued'] is True and r['tick']==cast.get('tick') for r in requests),'Accepted H cast needs a same-tick queued grapple request')
    for arrival in (e for e in events if e.get('event')=='bell_player_arrived'):
        target=arrival.get('bell_id');at=arrival.get('tick',-1)
        contact=[e for e in events if e.get('event')=='actual_traversal' and e.get('state')=='hook_contact_kick' and e.get('bell_target') is True and e.get('target_id')==target and e.get('tick')==at]
        require(len(contact)==1 and any(c.get('tick',-1)<=at for c in casts),'Physical Bell arrival must match actual accepted target-specific Motor contact after H input')
        require(any(e.get('event')=='actual_traversal' and e.get('state')=='hook_pull' and e.get('target_id')==target and e.get('tick',-1)<at for e in events),'Bell arrival requires its actual preceding target pull')
    results=[e for e in events if e.get('event')=='policy_result' and e.get('target') in {'boss','player'}]
    require(bool(results),'Actual Policy result ledger required')
    ids=set();by_frame={}
    for result in results:
        ident=result.get('event_id');frame=result.get('physics_frame')
        require(isinstance(ident,str) and ident and ident==result.get('id') and ident not in ids,'Policy damage event ids must be exact and unique')
        ids.add(ident)
        require(type(frame) is int and frame>=frames[0]['physics_frame'] and frame<=frames[-1]['physics_frame'] and finite(result.get('amount')) and result['amount']>0 and finite(result.get('hp')),'Policy result must belong to a real captured physics frame with finite damage/HP')
        by_frame.setdefault(frame,[]).append(result)
        if result.get('target')=='boss' and str(result.get('source','')).startswith('player_projectile:'):
            parts=ident.split(':')
            require(len(parts)==3 and all(p.isdigit() for p in parts),'Ordinary projectile event identity required')
            require(parts[0]==result['source'].split(':')[-1] and int(parts[1])==fight['initial']['session_id'] and int(parts[2]) in shot_ids,'Boss projectile damage must resolve an actually accepted shot in this actor session')
    hp={'boss':fight['initial']['boss_hp'],'player':fight['initial']['player_hp']}
    require(all(finite(v) and v>0 for v in hp.values()),'Live initial health ledger required')
    for frame in frames:
        for result in by_frame.get(frame['physics_frame'],[]):
            target=result['target'];hp[target]=max(0,hp[target]-result['amount'])
            require(close(result['hp'],hp[target]) and result.get('lethal') is (hp[target]==0),'Each Policy result HP/lethal must reconcile to preceding actual damage')
        require(close(frame.get('boss_hp'),hp['boss']) and close(frame.get('player_hp'),hp['player']),'Every captured end-physics HP must reconcile to complete Policy ledger')
        require(frame['player_hp']>0,'This successful consumer requires a living player throughout combat')
    require(close(fight['final']['boss_hp'],hp['boss']) and close(fight['final']['player_hp'],hp['player']),'Final health must agree with the same full frame/damage ledger')
    require(sum(r.get('lethal') is True for r in results if r['target']=='boss')==1,'Exactly one actual lethal Boss Policy result required')
    for counter in (e for e in events if e.get('event')=='bell_counter_committed'):
        require(any(r['event_id']==counter.get('event_id') and r['target']=='boss' and r.get('tick')==counter.get('tick') and close(r['hp'],counter.get('hp')) and close(r['amount'],counter.get('amount')) for r in results),'Counter summary must match its exact committed Policy health/amount')

def validate_pointer_and_map2(data):
    pointer=data.get('pointer_events')
    require(isinstance(pointer,list) and len(pointer)==2 and [r.get('pressed') for r in pointer]==[True,False],'Actual reward pointer press/release pair required')
    for event in pointer:
        rect=event.get('actual_button_rect');point=event.get('point')
        require(event.get('text')=='ENTER / CLAIM REWARD' and vector(point) and isinstance(rect,list) and len(rect)==4 and all(finite(v) for v in rect) and rect[2]>0 and rect[3]>0,'Actual labelled Button and finite positive global rectangle required')
        require(rect[0]<=point[0]<rect[0]+rect[2] and rect[1]<=point[1]<rect[1]+rect[3],'Reward pointer must be inside its actual Button rectangle')
    require(pointer[0]['actual_button_rect']==pointer[1]['actual_button_rect'] and pointer[0]['point']==pointer[1]['point'],'Press/release must target the same actual reward button')
    after=data['map2_after_entry'];coast=data.get('map2_normal_frames')
    require(isinstance(coast,list) and len(coast)==30,'Thirty actual map2 coast observations required')
    # Old05 did not record per-frame coast motor steps or Policy events. Validate
    # the actual available alive/map/session/position fields without inventing them.
    for frame in coast:
        require(finite(frame.get('hp')) and 0<frame['hp']<=after['capacity'] and frame['hp']<=after['hp'],'Every map2 coast observation must be alive within captured entry health/capacity')
        require(frame.get('map')==after['map']==2 and frame.get('session')==after['session'] and vector(frame.get('position')) and type(frame.get('grounded')) is bool,'Every coast observation must belong to actual second-map actor with finite position')

CANOPY_LAYOUTS = frozenset({'shared-tree-canopy-hunt-v10', 'forest-expedition-airborne-v11', 'forest-woven-trunk-v12', 'forest-interwoven-canopy-v13', 'forest-fruit-routes-v14', 'forest-bible-world-v15'})
CANOPY_CONTENT = {'contract':'forest-queen-canopy-v3',
                  'scene':'res://scenes/bosses/thorn_queen_canopy.tscn',
                  'resource':'res://resources/bosses/thorn_queen_canopy.tres'}
LEGACY_QUEEN_LAYOUTS = frozenset({'hollow-clearing-upper-thorn-candidate-v2',
    'shared-tree-borer-final-approach-v4', 'shared-tree-directional-cavities-v7',
    'shared-tree-living-detour-v9'})

def validate_map2_boss_identity(manifest, *, allow_legacy=False):
    """Version-bound identity only; does not admit Queen content or replay geometry."""
    require(isinstance(manifest,dict), 'Typed map2 manifest required')
    require(manifest.get('version')=='thorn-forest-region-v2'
            and manifest.get('region')=='thorn_forest'
            and type(manifest.get('map_index')) is int and manifest['map_index']==2,
            'Exact forest version/region/map2 identity required')
    contract=manifest.get('boss_contract')
    require(isinstance(contract,dict) and contract.get('ok') is True,
            'Actual successful typed Boss contract required')
    if isinstance(manifest.get('layout_version'), str) and manifest['layout_version'] in CANOPY_LAYOUTS:
        require(manifest.get('boss_content')==CANOPY_CONTENT,
                'Exact current canopy contract/scene/resource declaration required')
        require(contract.get('version')==CANOPY_CONTENT['contract']
                and contract.get('boss_contract')==CANOPY_CONTENT['contract']
                and contract.get('admission')=='candidate_whole_boss_pending',
                'Exact canopy contract version and candidate admission required')
    else:
        require(allow_legacy and isinstance(manifest.get('layout_version'),str)
                and manifest['layout_version'] in LEGACY_QUEEN_LAYOUTS,
                'Unsupported Queen layout; no legacy fallback for unknown versions')
        require('boss_content' not in manifest
                and contract.get('version')=='forest-queen-weave-golden-v2'
                and contract.get('boss_contract')=='queen-weave-region-experimental'
                and contract.get('admission')=='experimental_whole_boss_pending',
                'Exact historical weave contract and experimental admission required')

def validate(data):
    assert data['scope']=='actual_DemoApp_v2_map1_route_Guardian_fullfight_pointer_reward_map2_entry'
    assert data['failures']==[] and len(data['checks'])>=20 and all(r['passed'] is True for r in data['checks'])
    assert data['initial_debug_entry_only'] is True and data['manual_motor_step'] is False and data['position_health_phase_resource_injection'] is False
    route=data['route'];fight=data['combat'];events=fight['events']
    validate_inputs_and_health(fight)
    validate_pointer_and_map2(data)
    assert not route['failures'] and len(route['completed'])==len(route['itinerary']) and route['frames'] and route['requests']
    assert fight['initial']['boss_hp']==32 and fight['initial']['boss_started'] is False
    assert fight['defeats']==1 and fight['final']['boss_hp']==0 and fight['final']['player_hp']>0
    assert fight['seal_seen'] and fight['eligible_seen'] and fight['actual_bell_arrival'] and fight['earned_counter_phase2']
    assert fight['frames'] and all(r['motor_steps']==1 for r in fight['frames'])
    actual=[r['physics_frame'] for r in fight['frames']]
    assert actual==list(range(actual[0],actual[0]+len(actual))) and len(actual)==fight['elapsed_actual_physics_frames']
    assert any(e.get('event')=='actual_traversal' and e.get('bell_target') and e.get('state')=='hook_contact_kick' for e in events)
    policy=[e for e in events if e.get('event')=='policy_result' and e.get('target')=='boss']
    assert any(e['source'].startswith('player_projectile:') for e in policy)
    assert any(e['source'].startswith('guardian_bell_counter:') for e in policy)
    assert sum(e['amount'] for e in policy)>=32
    from run_forest_boss_depth import validate_counter_causality
    validate_counter_causality(events)
    assert data['reward_modal_paused'] and [r['pressed'] for r in data['pointer_events']]==[True,False]
    before=data['map1_before_entry'];after=data['map2_after_entry']
    assert before['map']==1 and after['map']==2 and after['version']=='thorn-forest-region-v2'
    assert after['stage_index']>before['stage_index'] and after['actor_epoch']>before['actor_epoch'] and after['stage_epoch']>before['stage_epoch']
    assert after['wallet']==data['before_reward']['wallet']+data['reward_declaration']['coins'] and after['build']==data['before_reward']['build']
    assert after['hook'] and not after['double'] and not after['wall'] and after['weapon']=='pulse_gun' and after['tier']==1
    assert data['reward_declaration']['coins']>0 and data['reward_declaration']['heal']>0
    assert after['hp']==min(data['before_reward']['capacity'], data['before_reward']['hp']+data['reward_declaration']['heal'])
    manifest=data['map2_manifest']
    assert manifest['version']=='thorn-forest-region-v2' and manifest['map_index']==2 and manifest['seed']==data['seed']+'/thorn_forest/map_2'
    validate_map2_boss_identity(manifest, allow_legacy=True)
    assert data['queen_whole_boss_admission'] is False and len(data['map2_normal_frames'])==30
    run=data['run_manifest'];assert data['run_manifest_compatible'] is True and run['schema_version']==2 and len(run['stages'])==2
    assert [s['stage_index'] for s in run['stages']]==[1,2] and [s['outputs']['region_map']['map_index'] for s in run['stages']]==[1,2]
    assert all(s['biome_id']=='thorn_forest' and s['outputs']['region_map']['version']=='thorn-forest-region-v2' for s in run['stages'])
    assert run['stages'][0]['outputs']['mini_boss_reward']['coins']==data['reward_declaration']['coins']

def validate_queen(data):
    require(data.get('scope')=='actual_DemoApp_v2_map2_Queen_route_reload_fullfight_pointer_rewards_boundary','Queen actual-App scenario scope required')
    require(data.get('failures')==[] and len(data.get('checks',[]))>=20 and all(c.get('passed') is True for c in data['checks']),'All Queen consumer runtime assertions required')
    require(data.get('initial_debug_entry_only') is True and data.get('manual_motor_step') is False and data.get('position_health_phase_resource_injection') is False and data.get('world_constructor_called') is False,'Queen scenario must use actual debug-pinned App and normal inputs without fixture world')
    require(data.get('queen_whole_boss_admission') is False,'Consumer success cannot sign Queen design admission')
    teardown=data['queen_teardown']
    require(teardown['shot_source_cleared'] is True and teardown['shot_callable_cleared'] is True and teardown['observed_actors_alive']==[],'Actually observed Queen/shot actors must release after App free and own observer references must clear')
    route=data['route'];manifest=route['manifest']
    require(not route['failures'] and route['frames'] and route['requests'] and len(route['completed'])==len(route['itinerary']),'Complete actual map2 route required')
    require(manifest['version']=='thorn-forest-region-v2' and manifest['map_index']==2 and manifest['seed']==data['seed']+'/thorn_forest/map_2','Actual second-map version/seed identity required')
    fight=data['queen_combat'];initial=fight['initial'];final=fight['final'];frames=fight['frames'];events=fight['events']
    require(initial['boss_hp']==data['definition']['health']>0 and initial['app_boss_started'] is False,'Unmodified Definition HP must precede natural activation')
    require(fight['defeats']==1 and final['boss_hp']==0 and final['player_hp']>0 and fight['reloaded'] is True,'Actual live-player unique Queen kill and mid-fight reload required')
    require(frames and all(r['motor_steps']==1 and vector(r['player']) and finite(r['player_hp']) and r['player_hp']>0 for r in frames),'Every recorded Queen gameplay observation must contain one real Motor step and live finite state')
    require({r['phase'] for r in frames}>={1,2,3} and any(r['seal'] for r in frames) and any(r['eligible']>0 for r in frames),'Actual three network phases, production seal and shot gate required')
    require({r['segment'] for r in frames}=={'before_reload','after_reload'},'Both real gameplay segments around reload required')
    inputs=[e for e in events if e.get('event')=='actual_queued_input']
    accepted=[e for e in events if e.get('event')=='accepted_shot']
    require(inputs and accepted,'Actual queued and accepted Queen combat inputs required')
    shot_keys=set()
    for shot in accepted:
        key=(shot['motor_id'],shot['session'],shot['serial'])
        require(key not in shot_keys,'Accepted Queen shot identities must be unique per actual actor session')
        shot_keys.add(key)
        require(any(r['action']=='shoot_release' and r['session']==shot['session'] and r['segment']==shot['segment'] and r['tick']==shot['tick'] and same_aim(r['direction'],shot['aim']) for r in inputs),'Accepted Queen shot requires matching actual queued aim/session')
    results=[e for e in events if e.get('event')=='policy_result' and e.get('target')=='boss']
    require(results and len({e['event_id'] for e in results})==len(results),'Unique actual Queen Boss Policy ledger required')
    remaining=initial['boss_hp']
    for result in results:
        require(str(result['source']).startswith('player_projectile:') and finite(result['amount']) and result['amount']>0,'Queen damage must come from normal actual projectiles')
        parts=result['event_id'].split(':')
        require(len(parts)==3 and all(p.isdigit() for p in parts) and tuple(map(int,parts)) in shot_keys and parts[0]==result['source'].split(':')[-1],'Queen Policy damage must resolve an accepted actual actor/session/shot')
        remaining=max(0,remaining-result['amount'])
        require(close(result['hp'],remaining) and result.get('lethal') is (remaining==0),'Queen Policy result health must reconcile throughout reload')
    require(remaining==0 and sum(e.get('lethal') is True for e in results)==1,'Exactly one actual Queen lethal damage result required')
    for frame in frames:
        expected=max(0,initial['boss_hp']-sum(e['amount'] for e in results if e['physics_frame']<=frame['physics_frame']))
        require(close(frame['boss_hp'],expected),'Recorded Queen frame HP must agree with full normal damage ledger')
    # Reconcile the actual player's same Policy ledger as well as the Boss.
    player_results=[e for e in events if e.get('event')=='policy_result' and e.get('target')=='player']
    require(len({e['event_id'] for e in player_results})==len(player_results),'Player damage identities must be unique throughout the actual fight')
    player_hp=initial['player_hp']
    for result in player_results:
        require(finite(result['amount']) and result['amount']>0,'Player Policy damage must have positive finite amount')
        player_hp=max(0,player_hp-result['amount'])
        require(close(result['hp'],player_hp) and result.get('lethal') is (player_hp==0),'Player Policy health/lethality must reconcile without reload heal injection')
    require(close(final['player_hp'],player_hp),'Final live Player health must match actual Policy damage')
    for frame in frames:
        expected_player=max(0,initial['player_hp']-sum(e['amount'] for e in player_results if e['physics_frame']<=frame['physics_frame']))
        require(close(frame['player_hp'],expected_player),'Each recorded Player HP must match real Policy damage, including both reload segments')
    reload=data['queen_reload'];saved=reload['saved'];bound=reload['after_bound'];active=reload['after_resume'];before=reload['before']
    previous_physics=None
    for segment,owner in [('before_reload',before),('after_reload',active)]:
        segment_frames=[frame for frame in frames if frame['segment']==segment]
        require(bool(segment_frames),'Both actual reload ownership segments must contain gameplay observations')
        require(all(frame['session']==owner['session'] and frame['actor_epoch']==owner['actor_epoch'] and frame['stage_epoch']==owner['stage_epoch'] for frame in segment_frames),'Every actual Motor observation must belong to its real reload session/actor/stage epoch')
        require(all(type(frame['physics_frame']) is int for frame in segment_frames),'Actual Engine physics observations must be integer frame identities')
        require(all(second['physics_frame']==first['physics_frame']+1 for first,second in zip(segment_frames,segment_frames[1:])),'Each uninterrupted gameplay segment must retain every real consecutive Engine physics frame')
        if previous_physics is not None: require(segment_frames[0]['physics_frame']>previous_physics,'New ownership segment must occur after the old actual physics observations')
        previous_physics=segment_frames[-1]['physics_frame']
    require(data['definition']['schema']==13 and saved['weave_schema']==13 and 0<saved['health']<initial['boss_hp'] and saved['stage_phase']>=2,'Current-schema nondefault Queen save must be naturally earned')
    require(bound['boss_instance']!=before['boss_instance'] and bound['stage_instance']!=before['stage_instance'] and bound['actor_epoch']>before['actor_epoch'] and reload['old_token_rejected'] is True,'Reload must replace actual actors and invalidate old token')
    require(bound['last_restore_accepted'] is True and bound['manifest_hash']==before['manifest_hash'] and bound['boss_hp']==saved['health'] and bound['boss']['fields']==saved['fields'] and all(bound['boss'][key]==saved[key] for key in ('weave_schema','stage_phase','route_phase','sampled_shore','sampled_player','perch_index','motion_leg','transition_from_phase')),'Bound App restore must preserve exact persistent field state and damaged health')
    require(active['active'] and active['app_boss_started'] and active['boss']['weave_schema']==13 and active['boss']['stage_phase']==saved['stage_phase'] and active['boss']['sampled_shore']==saved['sampled_shore'],'Normal resume must reactivate the saved current Queen phase/shore')
    pairs=data['pointer_events']
    require([e['phase'] for e in pairs]==sum(([name,name] for name in ['pause','resume','reward','gold','ability','finish']),[]),'Actual complete Queen pointer chain required')
    for index in range(0,len(pairs),2):
        first,second=pairs[index:index+2]
        require(first['pressed'] is True and second['pressed'] is False and first['point']==second['point'] and first['actual_button_rect']==second['actual_button_rect'],'Queen pointer phase must contain one matching press/release')
        rect=first['actual_button_rect'];point=first['point']
        require(vector(point) and len(rect)==4 and all(finite(v) for v in rect) and rect[2]>0 and rect[3]>0 and rect[0]<=point[0]<rect[0]+rect[2] and rect[1]<=point[1]<rect[1]+rect[3],'Each Queen pointer must lie within the actual finite Button rectangle')
    require(data['gold_definition']['id']=='forest_heart_gold' and data['before_gold']['count']==0 and data['after_gold']['count']==1 and data['after_gold']['hp']==data['before_gold']['hp'],'Independent combat-earned GOLD must be claimed once without free healing')
    declaration=json.loads(data['gold_definition']['fingerprint'])
    additions=[effect[2] for effect in declaration[-1] if effect[0]=='max_health' and effect[1]==1]
    require(len(additions)==1 and close(data['after_gold']['capacity'],data['before_gold']['capacity']+additions[0]),'Gold capacity delta must match the actual item modifier declaration')
    boundary=data['before_boundary'];home=data['after_boundary']
    require(boundary['double'] is True and 'double_jump' in boundary['abilities'] and boundary['map']==2 and boundary['phase']==3,'Actual core choice must grant missing D before boundary')
    require(any('Next regions are in development' in text for text in data['boundary_ui_text']),'Actual boundary must visibly explain unavailable next regions')
    require(boundary['manifest_compatible'] is True,'Actual completed Queen manifest must remain compatible after reload and rewards')
    outputs=boundary['manifest']['stages'][-1]['outputs']
    require(outputs['reward_claim']['item']=='forest_heart_gold' and outputs['core_ability_reward']['ability']=='double_jump','Actual manifest must record independent GOLD and core reward receipts')
    require(home['state']==0 and home['wallet']==0 and home['items']==[] and home['abilities']==[],'Actual boundary must return HOME and clear this run')

def validate_canopy_policy_ledger(data):
    """Actual input/actor ownership and per-commit health; usable on failed lifecycle receipts too."""
    fight=data['combat'];frames=fight['frames'];events=fight['events'];initial=data['initial']
    by_frame={(row['segment'],row['physics_frame']):row for row in frames}
    require(len(by_frame)==len(frames),'Unique actual segment/physics observations required')
    shots=[row for row in events if row.get('event')=='accepted_shot'];keys=set()
    for shot in shots:
        key=(shot['motor_id'],shot['session'],shot['serial'])
        require(key not in keys,'Unique actual accepted shot owner/session/serial');keys.add(key)
        owner=by_frame.get((shot['segment'],shot['physics_frame']))
        require(owner is not None and shot['motor_id']==owner['player_instance'] and shot['session']==owner['session'],'Accepted gun must bind to the actual sampled actor/session at that Engine frame')
    results=[row for row in events if row.get('event')=='policy_result']
    for result in results:
        owner=by_frame.get((result['segment'],result['physics_frame']))
        require(owner is not None and result['actor_epoch']==owner['actor_epoch'],'Every Policy commit requires its actual segment/physics frame and actor epoch')
        require(finite(result['amount']) and result['amount']>0 and finite(result['hp']) and result['hp']>=0 and type(result['lethal']) is bool,'Finite positive Policy amounts and typed actual health/lethality required')
        health_key='boss_health_epoch' if result['target']=='boss' else 'player_health_epoch' if result['target']=='player' else None
        if health_key is not None and health_key in owner:
            require(result['health_epoch']==owner[health_key],'Policy result must bind to its actual target HealthState epoch')
        if result['target']=='boss':
            parts=result['event_id'].split(':')
            require(len(parts)==3 and all(part.isdigit() for part in parts) and tuple(map(int,parts)) in keys and result['source']=='player_projectile:'+parts[0],'Normal Boss commit source owner must exactly match its accepted projectile actor/session/serial')
            require(int(parts[0])==owner['player_instance'] and int(parts[1])==owner['session'],'Boss commit projectile must belong to its current sampled actor/session, never a cancelled pre-reload shot')
    for target,start,final_key in [('boss',24,'boss_hp'),('player',initial['player_hp'],'player_hp')]:
        rows=[row for row in results if row.get('target')==target]
        require(len({row['event_id'] for row in rows})==len(rows),'Unique actual target damage identities required')
        hp=start
        for row in rows:
            hp=max(0,hp-row['amount'])
            require(close(row['hp'],hp) and row['lethal'] is (hp==0),'Every '+target+' commit must reconcile actual ordered HP/lethality')
        require(close(fight['final'][final_key],hp),'Final '+target+' health must match each actual commit')
        for frame in frames:
            expected=max(0,start-sum(row['amount'] for row in rows if row['physics_frame']<=frame['physics_frame']))
            require(close(frame[final_key],expected),'Every '+target+' frame must reconcile actual commit time')


def validate_canopy_gold(data):
    """Current V5 transaction/effect contract; legacy Queen +2 remains above."""
    gold=data['gold_definition'];before=data['before_gold'];after=data['after_gold']
    declaration=json.loads(gold['fingerprint'])
    require(isinstance(declaration,list) and len(declaration)==20 and declaration[0]==gold['id'] and declaration[2]==gold['rarity']==2 and declaration[15]==gold['catalog_version']==5 and gold['level']==1,'Actual selected canonical V5 GOLD identity/rarity/level required')
    parameters={key.removesuffix('_by_level'):(value[0] if key.endswith('_by_level') else value) for key,value in declaration[18].items()}
    require(gold['parameters']==parameters,'Lv1 parameters must resolve the actual selected definition fingerprint')
    modifiers=[{'stat':m[0],'operation':m[1],'value':m[2],'priority':m[3]} for m in declaration[14]]
    mappings={'max_hp_add':('max_health',1),'max_hp_multiplier':('max_health',2),'ground_recoil_multiplier':('ground_recoil_multiplier',2),'coyote_time_add_s':('coyote_time',1),'focus_stamina_drain_multiplier':('focus_stamina_drain',2),'focus_stamina_recovery_multiplier':('focus_stamina_recovery',2)}
    modifiers += [{'stat':stat,'operation':operation,'value':parameters[key],'priority':0} for key,(stat,operation) in mappings.items() if key in parameters]
    require(gold['modifiers']==modifiers,'Actual equipped modifiers must match all declared static components and Lv1 parameter mappings')
    expected=before['capacity'];priority=-2147483648
    for m in modifiers:
        require(m['operation'] in [0,1,2] and finite(m['value']) and type(m['priority']) is int,'Typed actual static modifier required')
        if m['stat']=='max_health' and m['operation']==0 and m['priority']>=priority: expected=m['value'];priority=m['priority']
    expected += sum(m['value'] for m in modifiers if m['stat']=='max_health' and m['operation']==1)
    for m in modifiers:
        if m['stat']=='max_health' and m['operation']==2: expected*=m['value']
    require(before['count']==0 and after['count']==1 and after['hp']==before['hp'] and after['wallet']==before['wallet'],'Actual GOLD claim unique, with no invented coin/heal settlement')
    require(close(after['capacity'],before['capacity']) and after['equipped']==before['equipped'],'Actual GOLD acquisition is backpack-only, with no automatic maxHP/equipment change')
    instances=after['instances'];fixture=data['gold_equipment_fixture'];equipped=fixture['after']
    require(len(instances)==1 and instances[0]['instance_id'] and instances[0]['definition_id']==gold['id'] and instances[0]['definition_version']==declaration[1] and instances[0]['level']==1 and instances[0]['fingerprint']==gold['fingerprint'] and instances[0]['source_id']==fixture['source_id'] and fixture['source_id'].startswith('reward:'),'Exactly one stable versioned Lv1 instance from the real selected reward source required')
    require(fixture['scope']=='Explicit paused EquipmentService fixture while real core-choice modal remains open; not natural menu operation' and fixture['accepted'] is True and fixture['before']==after and fixture['progression_open'] is True,'Explicit equipment-fixture identity must not be presented as natural menu evidence')
    require(close(fixture['expected_hp_capacity'],expected) and close(equipped['capacity'],expected) and equipped['hp']==before['hp'] and equipped['wallet']==before['wallet'] and equipped['count']==1 and equipped['instances']==instances and equipped['equipped'].count(gold['id'])==1,'Actual item-declared maxHP modifiers required after explicit equipment, without healing, payment or duplicate ownership')
    require(fixture['core_before']==fixture['core_after'],'Random-item equipment must not grant a core ability')
    require(data.get('position_health_phase_resource_injection_scope')=='Original route/combat/reload only; postcombat debit fixture separately disclosed','Original no-injection claim applies to untouched route/combat/reload; disclose separate postcombat resource fixture')
    probe=data['gold_effect_probe']
    require(gold['id']=='G07' and probe['supported'] is True and probe['kind']=='G07_idle_recovery' and probe['scope']=='Explicit real-frame passive probe with core-choice modal retained; optional CombatEnergyState debit is disclosed fixture, not a natural skill or resource grant','Current seeded G07 requires its bounded real passive consumer proof, not merely effect-source presence')
    require(probe['parameters']==parameters and all(finite(parameters.get(k)) and parameters[k]>0 for k in ['idle_delay_s','resonance_per_s','max_recovery_per_map']),'Actual G07 delay/rate/map budget must come from its declared parameters')
    start=probe['start'];end=probe['after'];debit=probe['debit_fixture'];rows=probe['frames']
    require(data.get('postcombat_resource_debit_fixture')==debit,'Postcombat debit must be disclosed in the outer capture, not hidden in the legacy no-injection flag')
    require(debit['accepted'] is True and debit['method']=='CombatEnergyState.consume; no direct assignment or grant' and finite(debit['amount']) and debit['amount']>=0 and close(debit['before']-debit['amount'],debit['after']) and close(debit['after'],start['resonance']),'Any full-bar headroom debit must be disclosed and reconcile through real consume')
    require(rows and end['paused'] is True and start['paused'] is True and end['core_modal_open'] is True and close(end['clock'],rows[-1]['clock']) and end['clock']-start['clock']>=parameters['idle_delay_s']+1.0,'Actual bounded normal-frame passive window and restored core-modal pause required')
    require({key:value for key,value in end.items() if key!='paused'}=={key:value for key,value in rows[-1].items() if key!='paused'},'Final passive snapshot must equal the last real observed frame except the restored pause flag')
    eligible_start=max(0,start['clock']-start['last_combat']-parameters['idle_delay_s'])
    budget=parameters['max_recovery_per_map']-start['recovered'];headroom=start['capacity']-start['resonance']
    previous=start
    for frame in rows:
        require(frame['physics_frame']==previous['physics_frame']+1 and frame['motor_steps']==previous['motor_steps']+1 and frame['clock']>previous['clock'],'Every passive observation requires one real Motor/physics step and advancing production runtime clock')
        require(frame['paused'] is False and frame['core_modal_open'] is True and frame['parameters']==parameters and frame['instance']==instances[0]['instance_id'] and frame['map']==start['map'] and all(frame[k]==start[k] for k in ['actor_instance','session','actor_epoch','capacity','last_combat','campaign_phase','abilities']),'Every passive frame must retain actual actor/map/source/parameters and no invented combat resets')
        eligible=max(0,frame['clock']-start['last_combat']-parameters['idle_delay_s'])-eligible_start
        gain=min(max(0,budget),max(0,headroom),parameters['resonance_per_s']*eligible)
        require(close(frame['resonance'],start['resonance']+gain) and close(frame['recovered'],start['recovered']+gain),'Every G07 frame must obey actual idle gate, configured rate, remaining per-map budget and real bar capacity')
        require(frame['hp']==before['hp'] and close(frame['hp_capacity'],expected),'Passive proof cannot invent healing or HP capacity changes')
        previous=frame
    gain=end['resonance']-start['resonance'];grants=probe['grants']
    require(gain>0 and close(end['recovered']-start['recovered'],gain) and grants and len(grants)==end['serial']-start['serial'],'G07 must actually grant resonance and commit the same positive map-ledger amount')
    require(close(sum(g['amount'] for g in grants),gain) and all(finite(g['amount']) and g['amount']>0 and g['receipt']=='item/G07/%s/%s/recovery/%s'%(instances[0]['instance_id'],start['map'],start['serial']+index+1) for index,g in enumerate(grants)),'Every G07 gain requires its unique instance/map/serial resource grant receipt')
    boundary=data['before_boundary']
    require(boundary['item_effect']==parameters and any(row['definition_id']==gold['id'] and row['instance_id']==instances[0]['instance_id'] and row['level']==1 and row['parameters']==parameters and row['source_id'] for row in boundary['item_sources']),'Real D/boundary flow must retain the same instance-bound runtime source and parameters')
    outputs=boundary['manifest']['stages'][-1]['outputs']
    require(outputs['reward_claim']['item']==gold['id'] and outputs['core_ability_reward']['ability']=='double_jump','Real selected reward/core manifest receipts required')

def validate_canopy(data):
    """Current default canopy only; independent of both frozen legacy consumers."""
    require(data.get('scope')=='actual_current_default_canopy_App_route_pause_freshload_fullfight_pointer_boundary','Actual default canopy App scope required')
    require(data.get('failures')==[] and data.get('checks') and all(row.get('passed') is True for row in data['checks']),'All actual canopy App assertions must pass')
    require(data.get('manual_motor_step') is False and data.get('position_health_phase_resource_injection') is False and data.get('world_constructor_called') is False,'No fixture construction, injection or manual Motor stepping')
    validate_canopy_policy_ledger(data)
    route=data['route'];manifest=route['manifest']
    require(route['failures']==[] and len(route['completed'])==len(route['itinerary'])>0 and route['frames'],'Complete real App fast route required')
    require(all(row['motor_steps']==1 for row in route['frames']),'Every actual route observation requires one Motor step')
    validate_map2_boss_identity(manifest)
    initial=data['initial'];entry=data['after_entry'];geometry=data['geometry']
    require(initial['boss_hp']==24 and initial['active'] is False and initial['app_boss_started'] is False and initial['boss']['canopy_schema']==1,'Natural untouched current-schema Boss before actual connector')
    require(entry['active'] is True and entry['app_boss_started'] is True and entry['seal_closed'] is True and entry['boss_hp']==24,'Actual connector must trigger physical seal before damage')
    fight=data['combat'];frames=fight['frames'];events=fight['events'];final=fight['final'];start=fight['initial']
    require(fight['reloaded'] is True and fight['defeats']==1 and final['boss_hp']==0 and final['player_hp']>0,'Real midfight reload and unique24HP defeat required')
    require(frames and all(row['motor_steps']==1 and row['actual_time_scale']==1 and vector(row['player']) and finite(row['player_hp']) and row['player_hp']>0 for row in frames),'Every actual observation requires live finite state, natural time and one Motor step')
    require({row['segment'] for row in frames}=={'before_reload','after_reload'} and {row['stage_phase'] for row in frames}>={1,2,3},'Both real reload segments and all earned network phases required')
    for segment in ['before_reload','after_reload']:
        rows=[row for row in frames if row['segment']==segment]
        require(rows and all(b['physics_frame']==a['physics_frame']+1 for a,b in zip(rows,rows[1:])),'No missing observed Motor frames inside each uninterrupted ownership segment')
    inputs=[row for row in events if row.get('event')=='actual_queued_input']
    shots=[row for row in events if row.get('event')=='accepted_shot']
    require(inputs and shots,'Actual Router and accepted shot ledgers required')
    keys=set()
    for shot in shots:
        key=(shot['motor_id'],shot['session'],shot['serial'])
        require(key not in keys,'Unique accepted actor/session/serial required');keys.add(key)
        require(any(row['action']=='shoot_release' and row['motor_id']==shot['motor_id'] and row['physics_frame']==shot['physics_frame'] and row['session']==shot['session'] and row['tick']==shot['tick'] and row['segment']==shot['segment'] and same_aim(row['direction'],shot['aim']) for row in inputs),'Each accepted gun requires its real same-session Router request and aim')
    require(any(row['action']=='grapple' for row in inputs) and any(row.get('event')=='actual_hook_target_contact' and row.get('target_id',0)>0 for row in events),'Actual H requests and real physical target contacts required')
    results=[row for row in events if row.get('event')=='policy_result']
    boss_results=[row for row in results if row.get('target')=='boss']
    require(len(boss_results)==24 and len({row['event_id'] for row in boss_results})==24,'Full actual24HP normal Policy ledger required')
    hp=24
    for result in boss_results:
        parts=result['event_id'].split(':')
        require(str(result['source']).startswith('player_projectile:') and len(parts)==3 and all(part.isdigit() for part in parts) and tuple(map(int,parts)) in keys,'Boss damage must resolve an actually accepted projectile identity')
        require(close(result['amount'],1),'Actual single Pulse Boss damage required')
        hp-=result['amount']
        require(close(result['hp'],hp) and result['lethal'] is (hp==0),'Actual Boss HP/lethal ledger must reconcile across reload')
    require(sum(row['lethal'] is True for row in boss_results)==1,'Exactly one real lethal commit')
    player_results=[row for row in results if row.get('target')=='player']
    require(len({row['event_id'] for row in player_results})==len(player_results),'Unique actual Player damage identities')
    for frame in frames:
        bhp=24-sum(row['amount'] for row in boss_results if row['physics_frame']<=frame['physics_frame'])
        php=initial['player_hp']-sum(row['amount'] for row in player_results if row['physics_frame']<=frame['physics_frame'])
        require(close(frame['boss_hp'],max(0,bhp)) and close(frame['player_hp'],max(0,php)),'Every actual HP observation reconciles without reload healing or synthetic damage')
    require(close(final['player_hp'],initial['player_hp']-sum(row['amount'] for row in player_results)),'Final Player HP equals real Policy ledger')
    arena=geometry['boss_arena'];ox,oy,w,h=arena
    sealed=[row for row in frames if row['tick']>=fight['fight_start_tick']]
    require(sealed and all(ox-0.001<=row['player'][0]-12 and row['player'][0]+12<=ox+w+0.001 and oy-0.001<=row['player'][1]-18 and row['player'][1]+18<=oy+h+0.001 for row in sealed),'Actual full24x36 body stays inside sealed arena during fight')
    require(fight['cases'] and fight['cases'][0]['support12']>=12,'Fight ends with real stable support12')
    reload=data['reload'];saved=reload['saved'];bound=reload['after_bound'];before=reload['before']
    require(saved['canopy_schema']==1 and 0<saved['health']<24 and saved['stage_phase']>=2 and saved['fields'][0]['spawned'] and saved['fields'][0]['health']>0 and saved['fields'][0]['weave']['age']>.15,'Actual nondefault aged live field save required')
    require(bound['last_restore_accepted'] is True and bound['boss_instance']!=before['boss_instance'] and bound['stage_instance']!=before['stage_instance'] and bound['actor_epoch']>before['actor_epoch'] and bound['manifest_hash']==before['manifest_hash'] and reload['old_token_rejected'] is True,'Fresh actor binding and actual stale-token rejection required')
    require(bound['boss_hp']==saved['health'] and bound['player_hp']==before['player_hp'] and close(bound['energy'],before['energy']) and close(bound['capacity'],before['capacity']),'Reload preserves actual damaged actors health')
    for key in ['body_position','mode','motion_clock','stage_phase','section','leg','cycles','last_receiver','locked_receiver','sampled_player','intro_seen','intro_duration','fields']:
        require(bound['boss'][key]==saved[key],'Fresh bind must preserve actual saved '+key)
    resumed=reload['after_resume']
    require(resumed['active'] is True and resumed['app_boss_started'] is True and resumed['seal_closed'] is True and resumed['boss']['canopy_schema']==1 and resumed['boss']['stage_phase']==saved['stage_phase'],'Actual resumed App must activate the restored current phase behind its real seal')
    require(close(resumed['boss_hp'],saved['health']) and close(resumed['player_hp'],before['player_hp']) and close(resumed['energy'],before['energy']) and close(resumed['capacity'],before['capacity']),'Resume preserves actual damaged HP/stamina/capacity under the checkpoint contract')
    require(all(resumed[key]==bound[key] for key in ['session','actor_epoch','stage_epoch','player_instance','boss_instance','stage_instance']),'Resume uses the actual fresh-bound ownership, not the retired actors')
    require(same_aim(bound['player'],geometry['safe_return']),'Actual reload returns Player to its declared S checkpoint, not saved airborne position')
    for segment,owner in [('before_reload',before),('after_reload',bound)]:
        rows=[row for row in frames if row['segment']==segment]
        require(all(row['session']==owner['session'] and row['actor_epoch']==owner['actor_epoch'] and row['stage_epoch']==owner['stage_epoch'] for row in rows),'Every frame must belong to the actual session/actor/stage ownership segment')
    expected={'unknown_schema','wrong_clock_type','nan_clock','off_path_body','invalid_leg','future_field','unknown_receiver','severed_hp','age_growth'}
    negatives=data['schema_negatives']
    require({row['id'] for row in negatives}==expected and len(negatives)==len(expected),'All real schema mutation probes required')
    require(all(row['valid_accepted'] is False and row['restore_accepted'] is False and row['atomic'] is True and row['before']==row['after'] and row['hp_before']==row['hp_after'] for row in negatives),'Both real validators must reject each mutation atomically')
    pairs=data['pointer_events'];phases=['pause','resume','reward','gold','ability','finish']
    require([row['phase'] for row in pairs]==[phase for phase in phases for _ in range(2)],'Full actual Viewport pointer transaction required')
    for a,b in zip(pairs[::2],pairs[1::2]):
        require(a['pressed'] is True and b['pressed'] is False and a['point']==b['point'] and a['actual_button_rect']==b['actual_button_rect'],'Matched actual pointer press/release required')
        r=a['actual_button_rect'];p=a['point']
        require(vector(p) and len(r)==4 and all(finite(v) for v in r) and r[2]>0 and r[3]>0 and r[0]<=p[0]<r[0]+r[2] and r[1]<=p[1]<r[1]+r[3],'Pointer must hit actual finite Button rectangle')
    validate_canopy_gold(data)
    after_equipment=data['gold_equipment_fixture']['after']
    boundary=data['before_boundary'];home=data['after_boundary']
    require(boundary['double'] is True and 'double_jump' in boundary['abilities'] and boundary['phase']==3 and boundary['map']==2 and boundary['manifest_compatible'] is True,'Real D ability/compatible run boundary required')
    require(boundary['loadout']==after_equipment,'Actual core D choice preserves the distinct random-item inventory and equipment')
    require(any(all(meaning in row for meaning in ('后续地区尚在制作','返回家园结束本局','清除本局能力、金币和道具','已存入的音符保留')) for row in data['boundary_ui_text']),'Truthful current development boundary text required')
    require(home['state']==0 and home['wallet']==0 and home['items']==[] and home['equipped']==[] and home['abilities']==[],'Actual HOME clears both owned/equipped items and core abilities')
    require(data['teardown']['observed_actors_alive']==[],'Actually observed actor/source WeakRefs must clear after teardown')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir',default='build/forest_depth/campaign/native')
    parser.add_argument('--seed',default='forest-depth-hollow-00')
    parser.add_argument('--boss',choices=['guardian','queen','canopy'],default='guardian')
    parser.add_argument('--verbose',action='store_true',help='Preserve real native leak owner/resource identities without changing checks or budgets')
    args=parser.parse_args();out=(ROOT/args.output_dir).resolve()
    if not out.is_relative_to(ROOT/'build/forest_depth/campaign') or out.exists(): parser.error('Fresh output below build/forest_depth/campaign required')
    out.mkdir(parents=True)
    before=level_formal.source_files()
    paths=[Path(__file__).resolve(),ROOT/'tests/forest_depth_campaign_boss_runner.gd',ROOT/'tests/forest_depth_guardian_pilot.gd',ROOT/'tests/forest_depth_guardian_campaign_case.gd',ROOT/'tests/support/forest_queen_gameplay_fixture.gd',ROOT/'tests/forest_depth_canopy_campaign_case.gd',ROOT/'tests/forest_depth_canopy_campaign_pilot.gd',ROOT/'tests/forest_depth_canopy_gold_probe.gd',ROOT/'tests/test_forest_canopy_gold_contract.py']
    verifier={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    receipt={'native_verbose':args.verbose,'scope':__doc__,'source_before':before,'verifier_before':verifier,'passed':False,'base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'native_budget_seconds':180,'import_budget_seconds':90,'boss_scenario':args.boss}
    snapshot=ROOT/'build/snapshot-receipt.json'
    if snapshot.is_file():receipt['runtime_snapshot_receipt_sha256']=hashlib.sha256(snapshot.read_bytes()).hexdigest()
    start=time.monotonic()
    try:
        if args.boss=='canopy':
            unit_start=time.monotonic()
            unit_log=out/'gold-contract-counterexamples.log'
            # Included in this check's original300s Harness budget, before the
            # unchanged90s editor and180s native budgets. No additional check ID.
            with unit_log.open('w') as log:
                unit=subprocess.run([sys.executable,str(ROOT/'tests/test_forest_canopy_gold_contract.py')],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=10)
            unit_text=unit_log.read_text()
            unit_count=re.search(r'^Ran ([1-9]\d*) tests? in ',unit_text,re.M)
            require(unit.returncode==0 and unit_count is not None and int(unit_count.group(1))>=8,'All current canopy GOLD reader counterexamples must execute successfully before native')
            receipt['gold_contract_counterexamples']={'tests':int(unit_count.group(1)),'exit_code':unit.returncode,'timeout_seconds':10,'elapsed_seconds':time.monotonic()-unit_start,'scope':'Pure synthetic reader refusals, not extra native combat evidence'}
        with (out/'import.log').open('w') as log,contextlib.redirect_stdout(log):
            text=run_engine(['--headless','--path','.','--editor','--quit'],90)
        if ERRORS.search(text):raise RuntimeError('Native import ERROR')
        with (out/'native.log').open('w') as log,contextlib.redirect_stdout(log):
            text=run_engine((['--verbose'] if args.verbose else [])+['--headless','--fixed-fps','60','--path','.','--script','tests/forest_depth_campaign_boss_runner.gd','--','--boss='+args.boss,'--seed='+args.seed,'--output=res://'+(out/'capture.json').relative_to(ROOT).as_posix()],180)
        if ERRORS.search(text):raise RuntimeError('Native runtime ERROR')
        if not re.search(r'^FOREST DEPTH CAMPAIGN: [1-9]\d* assertions / 0 failures$',text,re.M):raise RuntimeError('Complete native campaign marker required')
        ({'guardian':validate,'queen':validate_queen,'canopy':validate_canopy}[args.boss])(json.loads((out/'capture.json').read_text()));receipt['passed']=True
    finally:
        receipt['source_after']=level_formal.source_files()
        receipt['verifier_after']={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in verifier}
        receipt['source_guard']=before==receipt['source_after'] and verifier==receipt['verifier_after']
        receipt['elapsed_seconds']=time.monotonic()-start
        receipt['logs']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.is_file()}
        (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
        if not receipt['source_guard']:raise RuntimeError('Source changed during actual App campaign')
    if args.boss=='canopy':
        print('PASS: actual App current canopy natural route, schema1 reload, full24HP and pointer GOLD/D/boundary; design/device admission NOT covered')
        return
    print('PASS: actual App v2 natural Guardian full fight, pointer reward and experimental map2 entry; Queen admission NOT covered' if args.boss=='guardian' else 'PASS: actual App v2 natural Queen route, reload, full fight and pointer rewards/boundary; design and device admission NOT covered')
if __name__=='__main__':main()
