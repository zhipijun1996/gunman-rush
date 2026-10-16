"""Source-bound real formal Root Bell evidence. No content or subjective acceptance."""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import selectors
import subprocess
import time
import zipfile
import visual_director

ROOT=Path(visual_director.ROOT)
LOCK='/workspace/gunman-rush/build/region_production_v3/engine.lock'
REQUIRED={'formal_approach','real_projectile_interrupt_0','real_projectile_interrupt_1','real_projectile_death','dead_walk_through_and_return','full_connection_and_gear_return'}|{f'{kind}_phase_{phase}' for kind in ('walk_mark_escape','jump_forward','jump_return') for phase in (0,30,60)}

def require(ok,reason):
    if not ok:raise ValueError(reason)
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def validate_admission_audit(data):
    rows=data.get('rows',[])
    require(isinstance(rows,list) and len(rows)==40 and data.get('failures')==[],'Formal admission map audit failed/incomplete')
    expected_rows={(f'v3-root-bell-pilot-{i}',map_index) for i in range(20) for map_index in (1,2)}
    require({(row.get('root_seed'),row.get('map_index')) for row in rows}==expected_rows and all(row.get('legacy_default_byte_equal') is True for row in rows),'Formal map/legacy-byte inventory incomplete')
    for row in rows:
        require(type(row.get('map_index')) is int and row['map_index'] in (1,2),'Invalid actual campaign map index type')
        candidate=row.get('candidate',{})
        replaced=candidate.get('replaced')
        require(type(replaced) is int and replaced in (0,1) and row.get('default_gate') is True,'Invalid actual replacement/default admission gate')
        require(candidate.get('version')=='root-bell-encounter-v2' and row.get('content_version')=='plains-region-v11-root-bell-v2','Wrong actual admission content version')
        expected_seed=row['root_seed']+('/plains/map_2' if row['map_index']==2 else '')
        require(row.get('actual_seed')==expected_seed and re.fullmatch(r'[0-9a-f]{64}',str(row.get('legacy_hash',''))),'Invalid campaign seed/legacy hash')
        require(candidate.get('status')==('one_candidate' if replaced else 'no_physically_qualified_lane'),'Replacement/status contradiction')
    require(sum(row['candidate']['replaced'] for row in rows)==1,'Unexpected actual admission count')
    physical=data.get('physical_negatives',{})
    refused=physical.get('refused',[])
    expected_physical={'width400','width440','one_way','ferry_recipe','thorn_recipe','low_arch_recipe','non_bidirectional','own_low_ceiling','adjacent_gear_sweep','camp_endpoint'}
    require(isinstance(refused,list) and len(refused)==10 and physical.get('failures')==[] and {r.get('mutation') for r in refused}==expected_physical,'Physical admission counterexample inventory missing/duplicate')
    require(all(isinstance(r.get('reasons'),list) and r['reasons'] and all(isinstance(reason,str) and reason.strip() for reason in r['reasons']) for r in refused),'Physical admission refusal reasons missing')
    loader=data.get('legacy_live_loader_compatibility',{})
    require(loader.get('passed') is True and re.fullmatch(r'[0-9a-f]{64}',str(loader.get('old_hash',''))) and loader.get('old_hash')==loader.get('actual_new_loader_hash'),'Historical loader compatibility hash failed')
    require(loader.get('old_version')==loader.get('actual_version')=='plains-region-v10','Historical loader content version changed')
    require(type(loader.get('old_actor_count')) is int and loader['old_actor_count']>0 and type(loader.get('actual_actor_count')) is int and loader['old_actor_count']==loader['actual_actor_count'] and type(loader.get('actual_root_count')) is int and loader['actual_root_count']==0,'Historical loader actor inventory changed')
    replay=data.get('run_manifest_replay',{})
    require(replay.get('passed') is True and replay.get('failures')==[],'Current versioned RunManifest replay missing/failed')
    expected={(mode,case) for mode in ('legacy_v10','v2') for case in ('first_map_native_json_exact','two_maps_native_json_modifier_and_exact_regeneration')}|{('', 'default_enable_api_keeps_v10')}
    cases=replay.get('cases',[])
    require(len(cases)==len(expected) and {(c.get('mode',''),c.get('case')) for c in cases}==expected and all(c.get('passed') is True for c in cases),'Versioned replay positive inventory incomplete')
    expected_bad={'unknown_root_version','mixed_root_versions','mixed_stage_generator','mixed_manifest_version','mixed_enemy_version','rehashed_enemy_position','rehashed_root_bell_behavior','unearned_resource_tuning','unknown_enable_version_is_atomic'}
    bad=replay.get('negatives',[])
    require(len(bad)==len(expected_bad) and {c.get('mutation') for c in bad}==expected_bad and all(c.get('refused') is True for c in bad),'Versioned replay refusal inventory incomplete')
    return {'maps':40,'versioned_run_positive_cases':len(cases),'versioned_run_refusals':len(bad),'scope':replay['scope']}

def sources():
    result=visual_director.sources()
    for name in ('tools/run_root_bell_formal.py','tools/test_root_bell_formal_verifier.py','tools/root_bell_formal_capture.gd','tests/root_bell_formal_trace.gd','tools/run_root_bell_tests.py','docs/evidence/region_production_v3/enemy_encounter_v2/legacy_manifest_strings.json'):
        result[name]=sha(ROOT/name)
    return result

# Resource/event verification shared by native capture and explicitly offline
# revalidation. Running these Python predicates alone is not native execution.
import math

def _number(path,key,script=None):
    text=(ROOT/path).read_text()
    found=re.search(r'(?m)^'+re.escape(key)+r'\s*=\s*(-?[0-9.]+)\s*$',text)
    if found:return float(found.group(1))
    require(script is not None,'Missing authoritative numeric field '+key)
    found=re.search(r'(?m)^@export var '+re.escape(key)+r'\s*(?::=|=)\s*(-?[0-9.]+)\s*$',(ROOT/script).read_text())
    require(found is not None,'Missing actual Definition default '+key)
    return float(found.group(1))

def _vec(text,key):
    found=re.search(r'(?m)^'+re.escape(key)+r'\s*=\s*Vector2\(\s*(-?[0-9.]+),\s*(-?[0-9.]+)\)',text)
    require(found is not None,'Missing authoritative vector '+key)
    return [float(found.group(1)),float(found.group(2))]

def _near(a,b,tolerance=.001):
    return len(a)==len(b) and all(isinstance(v,(int,float)) and math.isfinite(v) and abs(v-w)<=tolerance for v,w in zip(a,b))

def strict_semantics(data):
    frames=data['frames'];events=data['events'];m=data['manifest'];identity=data['root_bell_identity'];admission=m['root_bell_admission']
    enemies=m['enemies'];ids=[e['id'] for e in enemies]
    require(len(ids)==len(set(ids)),'Duplicate actual Manifest actor identity')
    roots=[e for e in enemies if e.get('behavior_id')=='root_bell']
    require(len(roots)==1 and roots[0]['id']==identity==admission['id'],'Root identity absent/ambiguous in actual Manifest')
    root=roots[0];nodes={n['id']:n for n in m['nodes']}
    require(root['area']==admission['module'] and root['area'] in nodes,'Root has no actual module')
    node=nodes[root['area']];raw=node['geometry']['platforms'][0];offset=node['offset'];floor=[offset[0]+raw[0],offset[1]+raw[1],raw[2],raw[3]]
    rootdef=(ROOT/'resources/enemies/plains_root_bell.tres').read_text();body=_vec(rootdef,'collision_size');pulse=_vec(rootdef,'pulse_size');home=[floor[0]+floor[2]/2,floor[1]-body[1]/2]
    require(_near(admission['physical_facts']['floor_xywh'],floor) and _near(admission['physical_facts']['home'],home) and _near(root['position'],home),'Self-reported geometry/home differs from Manifest/Definition')
    initial_actors=data['initial_runtime']['enemies'];final_actors=data['final_runtime']['enemies']
    require({e['id'] for e in initial_actors}==set(ids)=={e['id'] for e in final_actors},'Runtime/Manifest actor inventories differ')
    observed=[e for e in initial_actors if e['id']==identity];require(len(observed)==1 and observed[0]['behavior']=='root_bell' and _near(observed[0]['home'],home) and _near(observed[0]['body_size'],body),'Actual actor Definition/home mismatch')
    require(observed[0]['health']==_number('resources/enemies/patrol_health.tres','max_health'),'Initial root HP not actual Definition')
    tuning=json.loads((ROOT/'config/player_tuning.json').read_text());cap=data['initial_capability'];final=data['final_capability'];energy_script='scripts/resources/definitions/shot_energy_definition.gd';energy_resource='resources/player/plains_shot_energy.tres'
    capacity=_number(energy_resource,'capacity');initial=_number(energy_resource,'initial_current');cost=_number(energy_resource,'shot_energy_cost',energy_script);hit_recovery=_number(energy_resource,'hit_energy_recovery',energy_script);rate=_number(energy_resource,'ground_recovery',energy_script);delay=_number(energy_resource,'recovery_delay',energy_script);max_hp=_number('resources/actors/prototype_health.tres','max_health')
    hz=tuning['physics_hz'];dt=1/hz;session=cap['session_id'];epoch=frames[0]['resource_epoch']
    for c in [cap,final]:
        require(c['active'] is True and c['effective_max_jumps']==tuning['max_jumps'] and c['air_shot_flight_cap']==tuning['max_air_shots'] and c['granted_actions']==['jump','shot_recoil'],'Not weakest formal capability')
        require(c['build']['items']==[] and c['build']['sources']=={},'Unrecorded build advantage')
        weapon=c['equipped_weapon'];require(weapon['id']=='pulse_gun' and weapon['tier']==1 and weapon['rounds']==1 and weapon['definition_path']=='res://resources/weapons/pulse_gun.tres' and weapon['definition_sha256']==sha(ROOT/'resources/weapons/pulse_gun.tres'),'Weakest actual weapon Definition mismatch')
        for key,value in [('capacity',capacity),('shot_energy_cost',cost),('hit_energy_recovery',hit_recovery),('ground_energy_recovery',rate),('shot_energy_delay',delay)]:require(abs(c['shot_energy'][key]-value)<1e-6,'Effective resource config differs from actual Definition')
        for key,value in tuning.items():
            if key in c['tuning'] and key!='physics_hz':require(c['tuning'][key]==value,'Actual tuning mismatch '+key)
        require(c['config_hashes']['player_tuning']==sha(ROOT/'config/player_tuning.json') and c['config_hashes']['shot_energy']==sha(ROOT/energy_resource),'Config identity not authoritative')
    require(data['physics_hz']==hz and cap['physics_hz']==hz and final['physics_hz']==hz,'Wrong physics observation rate')
    require(_near(cap['position'],frames[0]['position']) and _near(final['position'],frames[-1]['position']),'Capability terminal does not match actual frame')
    shot_events=[e for e in events if e['kind']=='shot_accepted'];shots={e['shot_id']:e for e in shot_events}
    require(len(shots)==len(shot_events) and list(shots)==list(range(1,len(shots)+1)),'Duplicate/gapped accepted projectile identity')
    receipts=data['resource_receipts'];by_tick={};seen=set();consumed=set();granted=set()
    for r in receipts:
        require((r['epoch'],r['event_id']) not in seen,'Duplicate resource transaction identity');seen.add((r['epoch'],r['event_id']));by_tick.setdefault(r['tick'],[]).append(r)
        require(1<=r['tick']<=len(frames) and r['epoch']==epoch and r['session_id']==session and r['status']==0 and r['capacity']==capacity and 0<=r['current']<=capacity,'Foreign resource epoch/session/capacity/status')
    player_hp=_number('resources/actors/prototype_health.tres','initial_current');root_hp=observed[0]['health']
    current=initial;remaining_delay=cap['shot_energy']['_delay'];grounded=cap['grounded'];jump_window=math.ceil(tuning['jump_buffer']*hz)+1
    for i,f in enumerate(frames):
        require(0<f['health']<=max_hp and math.isfinite(f['health']),'Player dead/invalid HP during claimed surviving route')
        for e in events:
            if e['tick']!=f['tick']:continue
            if e['kind']=='player_health':
                require(e['status']==0 and e['operation'] in ['damage','heal'],'Unknown player health transaction')
                player_hp=max(0,min(max_hp,player_hp+e['amount']));require(abs(e['current']-player_hp)<1e-6,'Player health event accounting inconsistent')
            if e['kind']=='damage_committed' and e.get('target')==identity:
                require(e['actor_epoch']==f['root_bell']['actor_epoch'] and e['amount']>0,'Stale/invalid actual root damage');root_hp=max(0,root_hp-e['amount']);require(abs(e['health_after']-root_hp)<1e-6,'Root damage health accounting inconsistent')
        require(abs(f['health']-player_hp)<1e-6 and abs(f['root_bell']['hp']-root_hp)<1e-6 and f['root_bell']['terminal']==(root_hp==0),'Observed HP/terminal not bound to committed health events')
        require(f['session_id']==session and f['resource_epoch']==epoch and f['root_bell']['active'] is True,'Stale/inactive native lifetime')
        require(0<=f['shot_energy']<=capacity and math.isfinite(f['shot_energy']) and 0<=f['shots']<=tuning['max_air_shots'] and 0<=f['used_jumps']<=tuning['max_jumps'] and -1<=f['axis']<=1,'Native budget/action capacity invalid')
        require(_near(f['root_bell']['body_size'],body) and _near(f['root_bell']['pulse_size'],pulse),'Root actual Definition envelope changed')
        if i:require(abs(math.dist(f['position'],frames[i-1]['position'])-f['displacement'])<.05,'Continuous native displacement inconsistent with positions')
        gain=max(0,dt-remaining_delay);remaining_delay=max(0,remaining_delay-dt)
        if grounded:current=min(capacity,current+rate*gain)
        for r in by_tick.get(f['tick'],[]):
            require(math.isfinite(r['amount_applied']) and math.isfinite(r['requested_amount']),'Nonfinite resource amount')
            kind,rsession,sid=r['event_id'].split('/');sid=int(sid);require(int(rsession)==session and sid in shots,'Receipt has no actual accepted projectile')
            shot=shots[sid];require(shot['session_id']==session and shot['resource_epoch']==epoch and shot['packet_id']==sid and shot['event_id']==f"{shot['owner_id']}:{session}:{sid}",'Accepted shot identity/session/packet mismatch')
            before=current
            if r['operation']=='consume':
                require(kind=='shot' and sid not in consumed and r['tick']==shot['tick'] and abs(r['requested_amount']-cost)<1e-6 and current+1e-6>=cost,'Consume not exact actual shot debit');consumed.add(sid);current-=cost;remaining_delay=delay
                require(any(a['type']=='shoot_release' and _near(a['direction'],shot['direction']) for a in f['input_requests']),'Accepted shot lacks same-frame real Router release')
                require(abs(shot['energy_after']-current)<1e-6,'Accepted shot energy_after differs from debit')
            else:
                require(r['operation']=='grant' and kind=='hit' and sid not in granted and shot['tick']<r['tick'] and abs(r['requested_amount']-hit_recovery)<1e-6,'Grant not actual unique projectile hit');granted.add(sid);current=min(capacity,current+hit_recovery)
                hit=[e for e in events if e['kind']=='damage_committed' and e['tick']==r['tick'] and e['event_id']==shot['event_id'] and e['source']=='player_projectile:'+str(shot['owner_id']) and e['target'] in ids]
                require(len(hit)==1,'Hit recovery lacks actual Manifest damage event')
                require(any(e['kind']=='energy_recovered' and e['tick']==r['tick'] and abs(e['amount']-(current-before))<1e-6 for e in events),'Hit grant lacks accepted recovered event')
            require(abs(r['amount_applied']-(current-before))<1e-6 and abs(r['current']-current)<1e-6,'Resource applied delta/before-after accounting mismatch')
        require(abs(f['shot_energy']-current)<1e-5,'Frame resource differs from actual debit/hit/continuous recovery replay')
        grounded=f['grounded']
    expected_hits={}
    by_event_id={shot['event_id']:sid for sid,shot in shots.items()}
    for event in events:
        if event['kind']!='damage_committed' or event.get('target') not in ids or event.get('event_id') not in by_event_id:continue
        sid=by_event_id[event['event_id']];shot=shots[sid]
        require(event['source']=='player_projectile:'+str(shot['owner_id']) and event['amount']>0 and event['tick']>shot['tick'],'Invalid committed projectile hit cause')
        expected_hits[sid]=min(expected_hits.get(sid,event['tick']),event['tick'])
    require(granted==set(expected_hits),'Actual committed projectile hit missing unique resource grant')
    expected_recovered=[]
    for sid,hit_tick in expected_hits.items():
        matches=[r for r in receipts if r['event_id']==f'hit/{session}/{sid}']
        require(len(matches)==1 and matches[0]['tick']==hit_tick,'Hit grant not bound to first actual hit callback')
        expected_recovered.append((hit_tick,matches[0]['amount_applied'],shots[sid]['fired_airborne']))
    # ActorResourceState records APPLIED grants even when capacity clamps them
    # to zero; ShotEnergyPolicy still emits recovered(0, airborne) in that case.
    actual_recovered=[(e['tick'],e['amount'],e['airborne']) for e in events if e['kind']=='energy_recovered']
    require(sorted(actual_recovered)==sorted(expected_recovered),'Accepted hit recovery events do not match unique grants, including legal zero grants')
    require(consumed==set(shots),'Accepted shot missing exact debit')
    require(abs(final['shot_energy']['current']-current)<1e-5,'Final resource does not match continuous ledger')
    for e in events:
        if e['kind'] not in ('shot_accepted','jump_accepted','damage_committed','root_pulse','root_interrupted'):continue
        require(1<=e['tick']<=len(frames) and e in frames[e['tick']-1]['accepted_events'],'Accepted event not observed in actual frame')
        if e['kind'] in ('root_pulse','root_interrupted'):require(e.get('enemy')==identity,'Root accepted event targets foreign actor')
        if e['kind']=='jump_accepted':require(any(a['type']=='jump' for f in frames[max(0,e['tick']-jump_window):e['tick']] for a in f['input_requests']),'Accepted jump lacks bounded real Router request')
    edge_id=admission['physical_facts']['edge'];edges=[e for e in m['connections'] if e['id']==edge_id];require(len(edges)==1,'No unique actual Manifest target connection');edge=edges[0];areas={a['id']:a for a in m['areas']};a=areas[edge['a']]['position'];b=areas[edge['b']]['position']
    require(edge['bidirectional'] is True and edge['condition']=='open' and edge['path']==[a,b],'Required target connection not actual open two-way area path')
    steps=[s for s in data['edges'] if s['id']==edge_id];require(len(steps)==2 and [s['forward'] for s in steps]==[True,False],'Missing actual directed connection intervals')
    player_size=_vec((ROOT/'scenes/player/player.tscn').read_text(),'size');tol=player_size[0]/2+1
    require(steps[0]['end_tick']+1==steps[1]['start_tick'] and steps[1]['end_tick']==len(frames),'Final native return interval incomplete')
    for step,start,end in [(steps[0],a,b),(steps[1],b,a)]:
        require(1<=step['start_tick']<step['end_tick']<=len(frames),'Invalid directed traversal range');fs=frames[step['start_tick']-1:step['end_tick']]
        require(_near(fs[0]['position'],start,tol) and _near(fs[-1]['position'],end,tol) and fs[-1]['grounded'] and fs[-1]['collisions'],'Actual interval does not reach Manifest supported source/destination')
        require(any(f['axis']*(end[0]-start[0])>0 for f in fs),'Traversal lacks actual directed Router movement')
        for index in edge['modules']:
            n=m['nodes'][index];definition=ROOT/('resources/generation/modules/'+n['module_id']+'.tres');require(data['runtime_source_hashes'].get('res://'+str(definition.relative_to(ROOT)))==sha(definition),'Required module Definition source mismatch');text=definition.read_text();ports=[]
            for name in ['Entry','Exit']:
                section=re.search(r'\[sub_resource[^\n]*id="'+name+r'"\](.*?)(?=\n\[)',text,re.S);require(section is not None,'Missing actual module port');p=_vec(section.group(1),'position');ports.append([p[0]+n['offset'][0],p[1]+n['offset'][1]])
            ordered=ports if step['forward'] else ports[::-1];last=-1
            for port in ordered:
                matches=[i for i,f in enumerate(fs) if i>last and _near(f['position'],port,tol) and f['grounded'] and f['collisions']];require(matches,'Required module port not physically crossed in direction');last=matches[0]
            require(any(not f['grounded'] and any(e['kind']=='jump_accepted' for e in f['accepted_events']) for f in fs),'Required actual gear traversal lacks accepted jump')
    case=data['root_bell_cases'][-1];require(case['id']=='full_connection_and_gear_return' and case['start_tick']<=steps[0]['end_tick']<steps[1]['end_tick']==case['end_tick'],'Final case does not contain true outward destination and complete return')
    for c in data['root_bell_cases']:
        f=frames[c['end_tick']-1];require(c['health']==f['health'] and c['enemy_hp']==f['root_bell']['hp'],'Case health summary inconsistent with actual endpoint')
    require(_near(final['position'],a,tol) and next(e for e in final_actors if e['id']==identity)['terminal'] is True,'Actual terminal/root snapshot does not match completed return')


def validate(data):
    require(data.get('artifact_kind')=='formal_level_capture' and data.get('capture_contract_version')==3,'Not original formal consumer')
    require(data.get('outcome')=='route_target_reached' and data.get('route_reached') is True and data.get('capture_errors')==[] and data.get('driver_diagnostics')==[],'Actual formal route/cases failed')
    require(data.get('root_bell_admission_scope','').startswith(('explicit encounter-v2 pilot','default admitted encounter-v2')),'Missing honest pilot/default admission scope')
    scope=data['captured_scope']
    require(all(scope.get(k) is True for k in ('enemies_instantiated','enemy_attacks_enabled','enemy_contacts_enabled','production_rewards_enabled','production_camera_enabled')),'Formal consumers disabled')
    require(all(scope.get(k) is False for k in ('controller_manual_step','actor_teleport_by_driver','resource_injection','enemy_disable')),'Formal runtime bypass')
    require(data['seed']==data['root_seed']+'/plains/map_2' and data['map_index']==2,'Campaign actual seed mismatch')
    require(data['manifest']['version']=='plains-region-v11-root-bell-v2','Enabled content lacks explicit version')
    admission=data['manifest']['root_bell_admission'];identity=data['root_bell_identity']
    require(admission['replaced']==1 and admission['id']==identity and admission['version']=='root-bell-encounter-v2','Wrong actual admission')
    floor=admission['physical_facts']['floor_xywh'];home=admission['physical_facts']['home']
    require(floor[2]>=560 and admission['physical_facts']['reasons']==[],'Physical admission invalid')
    frames=data['frames'];require(len(frames)==data['tick_count'] and len(frames)>100,'Missing true native trace')
    for i,frame in enumerate(frames):
        require(frame['tick']==i+1 and frame['root_bell'].get('id')==identity,'Missing/gapped actual root frame')
        require(frame['root_bell']['position']==home,'Rooted body moved')
        if i:
            require(frame['controller_tick']>frames[i-1]['controller_tick'],'Native controller clock did not advance')
            previous=frames[i-1]['root_bell'];current=frame['root_bell']
            if current['state'] in ('telegraph','attack') and previous['state'] in ('telegraph','attack'):
                require(current['goal']==previous['goal'],'Fixed ground mark followed player')
    cases=data['root_bell_cases'];ids=[c['id'] for c in cases]
    require(len(ids)==len(set(ids)) and set(ids)==REQUIRED and all(c['passed'] is True for c in cases),'Incomplete/duplicate essential formal cases')
    expected_order=['formal_approach']+[f'{kind}_phase_{phase}' for phase in (0,30,60) for kind in ('walk_mark_escape','jump_forward','jump_return')]+['real_projectile_interrupt_0','real_projectile_interrupt_1','real_projectile_death','dead_walk_through_and_return','full_connection_and_gear_return']
    require(ids==expected_order,'Formal case chronology/phase matrix differs from actual protocol')
    require(cases[0]['start_tick']==1 and cases[-1]['end_tick']==len(frames),'Formal approach/terminal trace incomplete')
    for a,b in zip(cases,cases[1:]):require(a['end_tick']+1==b['start_tick'],'Missing continuous formal case interval')
    events=data['events'];root_events=[e for e in events if e['kind']=='root_pulse'];require(root_events,'No actual pulse')
    for event in root_events:
        frame=frames[event['tick']-1]['root_bell'];require(frame['state']=='attack' and frame['goal']==event['point'] and event['event_id'].endswith(':root_pulse:'+str(frame['serial'])),'Pulse/state/serial cause mismatch')
    for case in cases:
        observed=frames[case['start_tick']-1:case['end_tick']];require(len(observed)>=2,'Empty native case')
        require(abs(observed[-1]['position'][0]-case['position'][0])<.01,'Case endpoint differs from trace')
        if case['id'].startswith(('walk_mark_escape','jump_')):
            require(all(f['health']==observed[0]['health'] and f['root_bell']['hp']==3 for f in observed),'Nonkill case has HP damage')
            require(observed[-1]['grounded'] and abs(observed[-1]['position'][1]+18-floor[1])<.2,'No actual supported endpoint')
            require(all(floor[0]+12<=f['position'][0]<=floor[0]+floor[2]-12 for f in observed),'Pilot left supported lane')
        if '_phase_' in case['id']:
            require(case.get('phase_wait')==int(case['id'].rsplit('_',1)[1]),'Declared phase does not match exact case identity')
        if case['id'].startswith('jump_'):
            direction=1 if 'forward' in case['id'] else -1
            require(case['direction']==direction and direction*(observed[-1]['position'][0]-observed[0]['position'][0])>250,'Missing physical directed traversal')
            require(any(e['kind']=='jump_accepted' and case['start_tick']<=e['tick']<=case['end_tick'] for e in events),'No real accepted jump')
            require(any(not f['grounded'] and abs(f['position'][0]-home[0])<30 and f['position'][1]+18<home[1]-20 for f in observed),'Jump lacks actual live-body vertical clearance')
        if case['id'].startswith('walk_mark_escape'):
            delay=case['phase_wait'];require(case['phase_ready_tick']==case['start_tick']-1+delay and all(f['axis']==0 and f['input_requests']==[] for f in observed[:delay]),'Phase wait lacks actual idle native samples')
            pulses=[e for e in root_events if case['start_tick']<=e['tick']<=case['end_tick']]
            require(pulses and any(f['root_bell']['state']=='telegraph' for f in observed),'Walk escape erased warning/pulse')
            require(abs(observed[-1]['position'][0]-pulses[0]['point'][0])>40,'Walk ended inside fixed pulse')
        if case['id'].startswith('real_projectile'):
            damage=[e for e in events if e['kind']=='damage_committed' and e.get('target')==identity and case['start_tick']<=e['tick']<=case['end_tick']]
            shots=[e for e in events if e['kind']=='shot_accepted' and case['start_tick']<=e['tick']<=case['end_tick']]
            require(len(damage)==1 and len(shots)==1 and shots[0]['tick']<damage[0]['tick'],'No actual projectile→committed HP chain')
            hit=damage[0];tick=hit['tick'];require(frames[tick-2]['root_bell']['hp']-frames[tick-1]['root_bell']['hp']==hit['amount'],'HP delta not actual committed hit')
            require(hit['event_id'].endswith(':'+str(shots[0]['shot_id'])),'Hit not bound to accepted projectile identity')
            require(any(r.get('amount_applied',0)<0 and r.get('operation')=='consume' and case['start_tick']<=r['tick']<=hit['tick'] for r in data['resource_receipts']),'Shot lacks actual resource spend receipt')
            require(any(f['root_bell']['state']=='telegraph' for f in observed),'No warning before shot')
            if 'interrupt' in case['id']:
                require(any(e['kind']=='root_interrupted' and e['tick']==hit['tick'] for e in events) and frames[hit['tick']-1]['root_bell']['state']=='recovery','No true HP interruption/recovery')
            else:require(hit['lethal'] and observed[-1]['root_bell']['terminal'],'No real terminal death')
    dead_case=next(c for c in cases if c['id']=='dead_walk_through_and_return')
    last=frames[dead_case['start_tick']-1:dead_case['end_tick']];require(all(f['root_bell']['terminal'] and f['health']==last[0]['health'] for f in last),'Dead actor still damages')
    require(any(f['position'][0]>home[0]+200 for f in last) and last[-1]['position'][0]<home[0]-200,'No real dead through-and-return')
    edge=admission['physical_facts']['edge'];steps=[e for e in data['edges'] if e['id']==edge]
    require(len(steps)==2 and [e['forward'] for e in steps]==[True,False] and all(e['reached'] for e in steps),'Missing full original edge out/gear return')
    strict_semantics(data)
    return {'cases':len(cases),'frames':len(frames),'root_pulses':len(root_events),'scope':'One actual formal map2 pilot; not full campaign/player/device/visual admission'}

def tamper(data):
    tests=[]
    for identity in sorted(REQUIRED):
        x=copy.deepcopy(data);x['root_bell_cases']=[c for c in x['root_bell_cases'] if c['id']!=identity];tests.append(('erase_case/'+identity,x))
    for kind in ('root_pulse','root_interrupted','shot_accepted','damage_committed','jump_accepted'):
        x=copy.deepcopy(data);x['events']=[e for e in x['events'] if e['kind']!=kind];tests.append(('erase_actual_'+kind,x))
    x=copy.deepcopy(data);x['resource_receipts']=[];tests.append(('erase_real_resource_ledger',x))
    x=copy.deepcopy(data);x['frames']=x['frames'][:-1];tests.append(('erase_actual_terminal_frame',x))
    x=copy.deepcopy(data);x['root_bell_cases'][-1]['position']=[0,0];tests.append(('forged_endpoint',x))
    x=copy.deepcopy(data);x['seed']='raw_fixture_seed';tests.append(('wrong_actual_campaign_seed',x))
    x=copy.deepcopy(data);x['manifest']['root_bell_admission']['physical_facts']['floor_xywh'][2]=400;tests.append(('narrow_physical_claim',x))
    x=copy.deepcopy(data);next(c for c in x['root_bell_cases'] if c['id']=='walk_mark_escape_phase_30')['phase_wait']=0;tests.append(('forge_phase_wait',x))
    x=copy.deepcopy(data);x['edges']=[e for e in x['edges'] if not (e['id']==x['manifest']['root_bell_admission']['physical_facts']['edge'] and e['forward'] is False)];tests.append(('erase_full_gear_return',x))
    refused=[]
    for name,x in tests:
        try:validate(x)
        except (ValueError,KeyError,IndexError,TypeError):refused.append(name)
        else:raise ValueError('Tampered formal evidence accepted:'+name)
    return refused

FROZEN_NATIVE_02_PINS = {'scope': 'Proposed explicit revalidation of actual immutable native02; no new native or same-source-fresh claim', 'native_dir': 'build/root_bell/formal_v2/formal_movie_02', 'old_receipt_sha256': 'dc23696e351aefa214d603db2aa3b41a13b28767fd5fb104d3697dd55b44d293', 'old_capture_sha256': 'f51bfaf0cdd27b22715e02923a1afd8b919e03eb44ce8b8189ea7d3b150a8a0f', 'old_runtime_log_sha256': 'af90b3f2ed68506faa1d2bcaff230bc79af4f5fd70fc3b91da0f4ff21989bf6b', 'old_movie_sha256': '3de8ee4d58d61ae7dad788b5331fe6ee632c2b8793a869398fa32caa39323b12', 'old_delta_zip_sha256': '77952849bd576ae9087cd37871277318215131a7bc661a83ce0ab52a6bc5c541', 'original_producer_verifier_sha256': '23f880b5554033e40952ab9201b2825257e4c08a9abdc66326d62f6fc1a6bb63', 'original_source_count': 972, 'allowed_changed_existing_sources': ['tools/run_root_bell_formal.py'], 'allowed_added_verifier_sources': ['tools/test_root_bell_formal_verifier.py'], 'hard_budget_start_epoch': 1792090199.040931, 'hard_budget_deadline_epoch': 1792097399.040931}

# Bind a preserved native capture to its original producer and current verifier.
def revalidate_frozen(native_folder,output_folder):
    """Distinct offline scope: immutable old native + strict current verifier."""
    native_folder=Path(native_folder).resolve();output_folder=Path(output_folder).resolve()
    require(output_folder.is_relative_to(ROOT/'build/root_bell') and not output_folder.exists(),'Use NEW output; preserve prior results')
    output_folder.mkdir(parents=True)
    receipt={'status':'failed','scope':'OFFLINE REVALIDATION ONLY, not fresh native/movie','native_reexecuted':False,'movie_reexecuted':False,'started_epoch':time.time()}
    try:
        # These five SHA pins come from the real accepted producer outputs before
        # independent rejection of their evidence consumer, not reconstructed bytes.
        pins=FROZEN_NATIVE_02_PINS
        for filename,key in [('report.json','old_receipt_sha256'),('capture.json','old_capture_sha256'),('runtime.log','old_runtime_log_sha256'),('gameplay.mp4','old_movie_sha256'),('modified_source_bytes.zip','old_delta_zip_sha256')]:
            require(sha(native_folder/filename)==pins[key],'Original native artifact pin mismatch '+filename)
        original=json.loads((native_folder/'report.json').read_text());old_sources=original['source_before'];now=sources()
        require(original['status']=='passed' and old_sources==original['source_after'] and len(old_sources)==972,'Original native source receipt incomplete')
        changed={p for p in old_sources if now.get(p)!=old_sources[p]};added=set(now)-set(old_sources)
        require(changed=={'tools/run_root_bell_formal.py'} and added=={'tools/test_root_bell_formal_verifier.py'},'Runtime/driver/config/assets/original acceptance changed; only explicit verifier/test delta allowed')
        require(now['tools/run_root_bell_formal.py']==sha(Path(__file__)),'Executing verifier is not actual installed verifier')
        require(old_sources['tools/run_root_bell_formal.py']==pins['original_producer_verifier_sha256'],'Original producer identity mismatch')
        with zipfile.ZipFile(native_folder/'modified_source_bytes.zip') as archive:
            manifest=json.loads(archive.read('source_manifest.json'));require(manifest['full_source_sha256']==old_sources,'Frozen old full closure differs from original receipt')
            entries=set(archive.namelist())-{'source_manifest.json'};require(entries==set(manifest['changed_source_sha256']) and len(entries)==31,'Frozen source byte inventory incomplete')
            for name in entries:require(hashlib.sha256(archive.read(name)).hexdigest()==old_sources[name]==manifest['changed_source_sha256'][name],'Frozen old modified bytes mismatch '+name)
        data=json.loads((native_folder/'capture.json').read_text());observed=validate(data)
        # The added test is itself source-bound and runs the five coherent full-main
        # bad captures with explicitly synthetic process transport. Never native.
        command=['python3','tools/test_root_bell_formal_verifier.py','--output-dir',str(output_folder/'negative_tests')]
        with (output_folder/'negative_tests.log').open('w') as log:actual=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=180)
        test_report=json.loads((output_folder/'negative_tests/report.json').read_text())
        required_bad={'all_return_motion_erased','independent_original_return_motion_erased','all_real_resource_receipts_replaced_by_unbound_fake','frame_budget_above_actual_capacity','player_dead_during_complete_return','coherent_ghost_root_identity_not_in_manifest','legal_epoch_capacity_foreign_shot_identity','legal_identity_wrong_actual_debit','missing_real_hit_grant_coherent_replay'}
        require(test_report['status']=='passed' and len(test_report['original27_refusals'])==27 and set(test_report['coherent_fullmain_refusals'])==required_bad and all(r['refused'] is True for r in test_report['coherent_fullmain_refusals'].values()),'Required Python refusal inventory incomplete')
        require(test_report['original_capture_sha256']==pins['old_capture_sha256'] and test_report['current_verifier_sha256']==now['tools/run_root_bell_formal.py'] and test_report['current_test_sha256']==now['tools/test_root_bell_formal_verifier.py'],'Python test receipt source/native identity mismatch')
        refused=test_report['original27_refusals']
        after=sources();require(after==now,'Source drift during offline revalidation')
        receipt.update({'scope':'OFFLINE REVALIDATION: original native02 + new verifier, NOT fresh native/movie execution','status':'passed','native_reexecuted':False,'movie_reexecuted':False,'original_native_artifact_pins':pins,'original_producer_source_sha256':old_sources,'current_verifier_source_sha256':now,'explicit_changed_existing_sources':sorted(changed),'explicit_added_verifier_test_sources':sorted(added),'source_after':after,'observed_original_native':observed,'retained_original27_refusals':refused,'actual_python_negative_test_command':command,'actual_python_negative_test_exit':actual.returncode,'negative_test_report_sha256':sha(output_folder/'negative_tests/report.json')})
        return receipt
    except Exception as error:
        receipt['error']=type(error).__name__+': '+str(error)
        raise
    finally:
        receipt['finished_epoch']=time.time()
        (output_folder/'offline_revalidation.json').write_text(json.dumps(receipt,indent=2)+'\n')


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--revalidate-frozen',help='Explicit offline oldnative/newverifier revalidation; never a fresh native claim');parser.add_argument('--movie',action='store_true');parser.add_argument('--g1',action='store_true');parser.add_argument('--default',action='store_true',help='Do not request pilot; succeeds only after actual default admission');parser.add_argument('--output-dir');args=parser.parse_args()
    if args.revalidate_frozen:
        require(not (args.movie or args.g1 or args.default),'Offline scope cannot request fresh capture')
        result=revalidate_frozen(Path(args.revalidate_frozen),ROOT/(args.output_dir or 'build/root_bell/offline_revalidation/'+str(time.time_ns())))
        print('OFFLINE ROOT BELL REVALIDATION: original native unchanged; new verifier only; NO NATIVE/MOVIE execution')
        return result
    folder=(ROOT/(args.output_dir or 'build/root_bell/formal_v2/'+str(time.time_ns()))).resolve()
    require(folder.is_relative_to(ROOT/'build/root_bell') and not folder.exists(),'Use a NEW build/root_bell directory; old failures/success immutable')
    folder.mkdir(parents=True);before=sources();report={'status':'failed','scope':'Actual formal pilot, no independent/content acceptance','source_before':before,'started_epoch':time.time(),'movie_requested':args.movie,'default_requested':args.default}
    if args.g1:report['scope']='Actual original165 fixtures plus formal40/versioned RunManifest audit; not input-only campaign traversal, commercial or device acceptance'
    (folder/'invocation.json').write_text(json.dumps(report,indent=2)+'\n');display=None
    try:
        env=os.environ.copy();env['LP_NUM_THREADS']='1';env['LIBGL_ALWAYS_SOFTWARE']='1'
        if args.g1:
            command=['python3','tools/run_root_bell_tests.py','--output-dir',str((folder/'native165').relative_to(ROOT))]
        else:
            command=['bash','tools/godot.sh']+([] if args.movie else ['--headless'])+['--fixed-fps','60','--path','.','--script','tools/root_bell_formal_capture.gd','--','--source-commit='+subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'--seed=v3-root-bell-pilot-1','--map-index=2','--strategy=fast','--encounter-policy=kill_from_bank_v1','--phase-wait-ticks=0','--max-ticks=18000','--output=res://'+str((folder/'capture.json').relative_to(ROOT))]
            if args.default:command+=['--root-bell-default']
            if args.movie:
                display=subprocess.Popen(['/workspace/toolchains/xvfb/usr/bin/Xvfb','-displayfd','1','-screen','0','1280x720x24','-nolisten','tcp','-ac'],stdout=subprocess.PIPE,stderr=(folder/'display.log').open('wb'))
                with selectors.DefaultSelector() as ready:
                    ready.register(display.stdout,selectors.EVENT_READ);require(ready.select(20),'Xvfb readiness timeout');number=display.stdout.readline().decode().strip();require(number.isdigit(),'Invalid display');env['DISPLAY']=':'+number
                command[2:2]=['--rendering-method','gl_compatibility','--audio-driver','Dummy','--write-movie',str(folder/'gameplay.avi')]
                command+=['--capture-visible']
        report['command']=command
        with (folder/'runtime.log').open('w') as log:actual=subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=900 if args.movie else 300)
        require(actual.returncode==0 and 'SCRIPT ERROR:' not in (folder/'runtime.log').read_text(),'Actual producer failed; preserve log')
        if args.g1:
            native=json.loads((folder/'native165/report.json').read_text());require(native['status']=='passed' and native['assertions']==165,'Actual old165 suite failed');report['observed']={'native_assertions':165,'content_refusals':len(native['validator_erasure_rejections']),'receipt_refusals':len(native['receipt_mutation_refusals'])}
            audit_command=['bash','tools/godot.sh','--headless','--fixed-fps','60','--path','.','--script','tests/root_bell_formal_runner.gd','--','--output=res://'+str((folder/'admission_audit.json').relative_to(ROOT))]
            with (folder/'admission_audit.log').open('w') as log:audit_actual=subprocess.run(audit_command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=120)
            audit_log=(folder/'admission_audit.log').read_text()
            require(audit_actual.returncode==0 and not re.search(r'SCRIPT ERROR:|Parse Error:|SHADER ERROR:',audit_log) and 'ROOT BELL V2 AUDIT: rows=40 eligible=1 failures=0' in audit_log,'Actual formal admission audit failed/incomplete')
            audit=json.loads((folder/'admission_audit.json').read_text())
            report['formal_admission_audit']={'command':audit_command,'exit_code':audit_actual.returncode,'audit_sha256':sha(folder/'admission_audit.json'),'log_sha256':sha(folder/'admission_audit.log'),'observed':validate_admission_audit(audit),'exit_diagnostics':[line for line in audit_log.splitlines() if 'ObjectDB' in line or 'resources still in use' in line]}
            refusals=[]
            for label,key in [('missing_run_replay','run_manifest_replay'),('missing_physical_negatives','physical_negatives'),('missing_legacy_loader','legacy_live_loader_compatibility')]:
                bad=copy.deepcopy(audit);bad.pop(key)
                try:validate_admission_audit(bad)
                except ValueError:refusals.append(label)
                else:raise ValueError('Admission consumer accepted '+label)
            bad=copy.deepcopy(audit);bad['run_manifest_replay']['negatives'].pop()
            try:validate_admission_audit(bad)
            except ValueError:refusals.append('missing_version_refusal')
            else:raise ValueError('Admission consumer accepted missing version refusal')
            # Retain each independently observed false acceptance as a live G1
            # regression, using this run's actual audit rather than canned rows.
            mutations=[
                ('duplicate_physical',lambda value:value['physical_negatives']['refused'].__setitem__(1,copy.deepcopy(value['physical_negatives']['refused'][0]))),
                ('empty_physical_rows',lambda value:value['physical_negatives'].__setitem__('refused',[{} for _ in range(10)])),
                ('false_default_gate',lambda value:value['rows'][0].__setitem__('default_gate',False)),
                ('negative_replacement',lambda value:value['rows'][0]['candidate'].__setitem__('replaced',-1)),
                ('unequal_loader_hash',lambda value:value['legacy_live_loader_compatibility'].__setitem__('actual_new_loader_hash','wrong')),
                ('boolean_map_index',lambda value:value['rows'][0].__setitem__('map_index',True)),
                ('float_map_index',lambda value:value['rows'][0].__setitem__('map_index',1.0)),
            ]
            for label,mutate in mutations:
                bad=copy.deepcopy(audit);mutate(bad)
                try:validate_admission_audit(bad)
                except ValueError:refusals.append(label)
                else:raise ValueError('Admission consumer accepted '+label)
            report['formal_admission_mutation_refusals']={'scope':'Actual Python receipt mutations, not additional native runs','refused':refusals}
        else:
            data=json.loads((folder/'capture.json').read_text());require(data['root_bell_admission_scope'].startswith('default admitted') if args.default else data['root_bell_admission_scope'].startswith('explicit encounter-v2'),'Requested/default pilot scope mismatch');report['observed']=validate(data);report['tamper_refusals']=tamper(data);require(re.search(r'LEVEL FORMAL CAPTURE: [1-9]\d* frames, [1-9]\d* edges, outcome=route_target_reached, capture_errors=0',(folder/'runtime.log').read_text()),'Missing actual formal completion');report['capture_sha256']=sha(folder/'capture.json')
        report['source_after']=sources();require(report['source_after']==before,'Source drift during native proof')
        if args.movie:
            with (folder/'encode.log').open('w') as log:subprocess.run(['flock',LOCK,'ffmpeg','-n','-threads','1','-i',str(folder/'gameplay.avi'),'-c:v','libx264','-threads','1','-crf','21','-pix_fmt','yuv420p','-c:a','aac',str(folder/'gameplay.mp4')],env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=180)
            report['movie_sha256']=sha(folder/'gameplay.mp4')
            media=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(folder/'gameplay.mp4')],timeout=30))
            video=next(s for s in media['streams'] if s['codec_type']=='video');audio=next(s for s in media['streams'] if s['codec_type']=='audio')
            require((video['width'],video['height'],video['avg_frame_rate'],int(audio['sample_rate']),audio['channels'])==(1280,720,'60/1',48000,2),'Actual formal movie dimensions/audio differ')
            require(int(video['nb_frames'])>=data['tick_count'],'Movie lost native observation coverage')
            report['media_probe']=media
        report.update(status='passed',exit_code=0,runtime_log_sha256=sha(folder/'runtime.log'))
        print('ROOT BELL FORMAL VERIFIED:',json.dumps(report['observed']));print('OUTPUT:',folder.relative_to(ROOT))
    finally:
        if display is not None:display.terminate();display.wait(timeout=10)
        report['finished_epoch']=time.time();(folder/'report.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
