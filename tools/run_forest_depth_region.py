"""Fresh actual DemoApp v2 routes. No Boss fight or historical-v1 substitution.

Start with one seed/map and three individually recorded routes. --matrix merely
requests actual runs; it never manufactures a pass for an absent/blocked map.
--corpus requests the fixed ten roots x two maps x four original routes, with
the original matrix16 first. Every requested case still enters the actual App.
"""
import argparse
import contextlib
from concurrent.futures import ThreadPoolExecutor, wait, FIRST_COMPLETED
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import selectors
import shutil
import subprocess
import sys
import time
ROOT=Path(__file__).resolve().parents[1]
VERSION='thorn-forest-region-v2'
ERRORS=re.compile(r'(?m)SCRIPT ERROR:|Parse Error:|SHADER ERROR:|^ERROR:|ObjectDB.*leaked|resources? still in use at exit')
ROUTES=('fast','growth','high_return','change_mind','upper_noH','borer')
def corpus_cases():
    first=[(seed,index,r) for seed,index in [('forest-depth-hollow-00',1),('forest-depth-hollow-02',1),('forest-depth-hollow-00',2),('forest-depth-hollow-02',2)] for r in ROUTES[:4]]
    rest=[(f'forest-depth-hollow-{n:02d}',index,r) for n in range(10) if n not in (0,2) for index in (1,2) for r in ROUTES[:4]]
    return first+rest
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
@contextlib.contextmanager
def movie_display(env,folder,enabled):
    if not enabled:
        yield env;return
    movie_env={**env,'LIBGL_ALWAYS_SOFTWARE':'1','OMP_NUM_THREADS':'1'}
    display=None
    with (folder/'display.log').open('wb') as stream:
        try:
            if not movie_env.get('DISPLAY'):
                candidate=Path(os.environ.get('GUNMAN_TOOLCHAIN_ROOT',str(ROOT.parent/'toolchains')))/'xvfb/usr/bin/Xvfb'
                binary=shutil.which('Xvfb') or (str(candidate) if candidate.is_file() else None)
                if not binary:raise RuntimeError('movie_requires_actual_Xvfb_or_DISPLAY')
                display=subprocess.Popen([binary,'-displayfd','1','-screen','0','1280x720x24','-nolisten','tcp','-ac'],stdout=subprocess.PIPE,stderr=stream)
                with selectors.DefaultSelector() as ready:
                    ready.register(display.stdout,selectors.EVENT_READ)
                    if not ready.select(20):raise RuntimeError('movie_display_readiness_timeout')
                    number=display.stdout.readline().decode().strip()
                    if not number.isdigit():raise RuntimeError('movie_display_number_invalid')
                movie_env['DISPLAY']=':'+number
            yield movie_env
        finally:
            if display is not None:
                display.terminate();display.wait(timeout=5);display.stdout.close()
def validate_movie_timeline(data,video_frames):
    errors=[];frames=data.get('frames',[])
    for group in ('frames','events','requests','modal_frames','pointer_events'):
        rows=data.get(group,[])
        indices=[r.get('presentation_frame') for r in rows]
        if any(type(n)is not int or not 0<=n<video_frames for n in indices):errors.append('movie_'+group+'_draw_index_missing_or_outside_film')
        if all(type(n)is int for n in indices) and any(b<a for a,b in zip(indices,indices[1:])):errors.append('movie_'+group+'_draw_index_reversed')
    if not frames or len({r.get('presentation_frame') for r in frames})!=len(frames):errors.append('movie_physics_samples_not_unique_draws')
    by_tick={r.get('tick'):r.get('presentation_frame') for r in frames}
    for group in ('events','requests'):
        if any(r.get('tick')not in by_tick or r.get('presentation_frame')!=by_tick[r['tick']] for r in data.get(group,[])):errors.append('movie_'+group+'_not_aligned_to_actual_physics_draw')
    return errors
def inspect_movie(path,data):
    if not path.is_file():return {'errors':['movie_file_missing']}
    argv=['ffprobe','-v','error','-count_frames','-show_streams','-show_format','-of','json',str(path)]
    try:
        probe=json.loads(subprocess.check_output(argv,timeout=30))
        video=next(s for s in probe['streams'] if s['codec_type']=='video')
        numerator,denominator=map(int,video['avg_frame_rate'].split('/'))
        count=int(video['nb_read_frames']);errors=validate_movie_timeline(data,count)
        if denominator==0 or numerator/denominator!=60 or count<=0:errors.append('movie_not_actual_60fps_complete_frames')
        return {'errors':errors,'argv':argv,'ffprobe':probe,'frames':count,'seconds':count/60,'sha256':sha(path),'bytes':path.stat().st_size,'timeline_scope':'presentation_frame is Engine.get_frames_drawn before the current render; actual frame index bounded by independently decoded AVI; physics ticks are not movie times'}
    except (OSError,ValueError,KeyError,StopIteration,subprocess.SubprocessError) as error:
        return {'errors':['movie_probe_failed/'+type(error).__name__+': '+str(error)],'argv':argv,'sha256':sha(path),'bytes':path.stat().st_size}
def inventory():
    files=[ROOT/'project.godot']
    for directory in ('scripts','scenes','resources','config','shaders','assets','tests','tools'):
        files.extend(p for p in (ROOT/directory).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc')
    return {p.relative_to(ROOT).as_posix():sha(p) for p in sorted(files)}
def import_inventory_guard(before,after):
    changed=[p for p,h in before.items() if after.get(p)!=h]
    additions=sorted(set(after)-set(before));unexpected=[]
    for name in additions:
        p=ROOT/name
        try:text=p.read_text()
        except (OSError,UnicodeError):unexpected.append(name);continue
        if name.endswith('.uid') and name[:-4] in before and re.fullmatch(r'uid://[a-z0-9]+',text.strip()):continue
        if name.endswith('.import') and name[:-7] in before:
            if '[remap]' in text and '[deps]' in text and f'source_file="res://{name[:-7]}"' in text:continue
        unexpected.append(name)
    return {'original_source_changed_or_deleted':changed,'new_paths':additions,'generated_import_metadata':[n for n in additions if n not in unexpected],'unexpected_new_source':unexpected,'passed':not changed and not unexpected}

def expected_itinerary(manifest,route):
    edges={x['id']:x for x in manifest['connections']};result=[]
    for id in manifest['routes'][route]:
        edge=edges[id]
        if edge['kind']=='ordinary_sequence':
            for i,step in enumerate(edge['steps']):
                row={**step,'edge_id':id,'step_index':i}
                if i==0:row.update({k:edge[k] for k in ('claim_before_edge','claim_area','claim_id') if k in edge})
                result.append(row)
            result.append({'kind':'walk','edge_id':id,'landing':edge['path'][-1],'step_index':len(edge['steps'])})
            if manifest.get('layout_version') in ('forest-expedition-airborne-v11','forest-woven-trunk-v12'):result[-1]['b']=edge['b']
        else:
            result.append({**edge,'edge_id':id,'landing':edge.get('landing',edge['path'][-1])})
            for i,step in enumerate(edge.get('post_landing_steps',[])):result.append({**step,'edge_id':id,'step_index':i,'post_landing':True})
            if edge['kind']=='hollow_recovery':result.append({'kind':'walk','edge_id':id,'landing':edge['path'][-1],'post_recovery_align':True})
    return result

def validate_upper_noH(data):
    errors=list(data.get('failures',[]));frames=data.get('frames',[]);events=data.get('events',[]);requests=data.get('requests',[]);manifest=data.get('manifest',{})
    def check(ok,reason):
        if not ok:errors.append(reason)
    check(data.get('actual_stage_map')==1 and manifest.get('map_index')==1 and data.get('actual_stage_version')==VERSION and manifest.get('version')==VERSION,'control_actual_map_version')
    check(manifest.get('seed')==data.get('seed','')+'/thorn_forest/map_1','control_actual_seed')
    check(not any(r.get('kind')=='grapple' for r in requests) and not any(e.get('kind','').startswith('hook_') for e in events),'control_must_have_zero_H_requests_or_accepts')
    check(data.get('manual_motor_step') is False and data.get('position_or_resource_injection') is False,'control_privileged_motion')
    check(bool(frames) and all(f.get('tick')==i+1 and f.get('motor_steps')==1 for i,f in enumerate(frames)),'control_continuous_normal_motor')
    initial=data.get('initial_snapshot',{});final=data.get('final_snapshot',{})
    check(initial.get('hook_enabled') is True and initial.get('double_enabled') is False and initial.get('wall_enabled') is False and initial.get('weapon')=='pulse_gun' and initial.get('tier')==1,'control_normal_H_build_no_grants')
    check(final.get('health',0)>0 and data.get('audio_released') is True,'control_alive_strict_cleanup')
    check(initial.get('config')==final.get('config'),'control_configs_changed')
    shots=[e for e in events if e.get('kind')=='shot_fired'];inputs=[r for r in requests if r.get('kind')=='shoot_release']
    check(len(shots)==1 and len(inputs)==1 and shots[0].get('aim')==[-1,0] and inputs[0].get('queued') is True and shots[0]['tick']==inputs[0]['tick'],'control_actual_single_R')
    jumps=[e for e in events if e.get('kind')=='jumped'];release=[e for e in events if e.get('kind')=='upper_noH_release_and_R'];takeoff=[e for e in events if e.get('kind')=='upper_noH_actual_takeoff']
    check(len(jumps)==1 and len(release)==1 and len(takeoff)==1 and release[0]['tick']==jumps[0]['tick']+6 and release[0].get('held_ticks')==6,'control_exact_single_six_tick_jump')
    if shots:
        tick=shots[0]['tick'];by={f['tick']:f for f in frames}
        cost_source=(ROOT/'resources/player/plains_shot_energy.tres').read_text()
        override=re.search(r'(?m)^shot_energy_cost\s*=\s*([\d.]+)',cost_source)
        declared=re.search(r'path="res://([^"]*shot_energy_definition\.gd)"',cost_source)
        if override:cost=float(override.group(1))
        elif declared:
            definition=(ROOT/declared.group(1)).read_text()
            default=re.search(r'@export var shot_energy_cost\s*:?=\s*([\d.]+)',definition)
            if default is None:return errors+['control_unresolved_real_shot_cost']
            cost=float(default.group(1))
        else:return errors+['control_unresolved_real_shot_definition']
        check(tick in by and tick-1 in by and abs(by[tick-1]['energy']-by[tick]['energy']-cost)<.001 and by[tick]['shots']==by[tick-1]['shots']-1,'control_actual_R_resource_cost')
    completions=data.get('completed_legs',[])
    check(len(completions)==2 and [r.get('edge_id') for r in completions]==['arrival_reading','upper_out'],'control_actual_original_edges_not_complete')
    instances=[g for g in manifest.get('geometry_instances',[]) if g.get('id')=='hollow']
    if len(instances)!=1:return errors+['control_actual_hollow_instance_missing']
    row=instances[0];support=row['platform_id_map']['outer_crown'];platforms={p['id']:p['rect'] for p in manifest['platforms']};rect=platforms[support];goal=[a+b for a,b in zip(row['local_geometry']['nodes']['E']['position'],row['translation'])]
    check(len(frames)>=12 and all(f.get('grounded') is True and support in f.get('supports',[]) and f['position'][0]-12>=rect[0]-.1 and f['position'][0]+12<=rect[0]+rect[2]+.1 and abs(f['position'][1]+18-rect[1])<1 and math.dist(f['position'],goal)<8 for f in frames[-12:]),'control_actual_E_twelve_full_body_support_missing')
    return errors

def actual_projectile_energy_credits(data,frame,previous,events,dt,target_gain):
    """Require independent emitted-entity, Policy, HP, and both resource ledgers.

    Historical no-hit captures need no new vocabulary. A hit capture without
    these actual observations fails closed; a claimed credit alone adds nothing.
    Air-round grants remain subject to the original separate charges replay.
    """
    tick=frame['tick'];credits=[e for e in events if e.get('tick')==tick and e.get('kind')=='actual_shot_energy_credit']
    hits=[e for e in events if e.get('tick')==tick and e.get('kind')=='committed_damage' and str(e.get('source','')).startswith('player_projectile:')]
    if not credits and not hits:return [],[]
    errors=[]
    def need(ok):
        if not ok:errors.append('cavity_actual_projectile_credit_evidence')
        return ok
    before=previous.get('shot_economy',{});after=frame.get('shot_economy',{})
    if not need(all(isinstance(v,dict) and all(k in v for k in ('owner_id','session_id','weapon_epoch','hits','combat_packets')) for v in (before,after))):return [],errors
    if not need(all(type(after[k]) is int and after[k]>0 and before[k]==after[k] for k in ('owner_id','session_id'))):return [],errors
    if not need(all(type(v['weapon_epoch']) is int and v['weapon_epoch']>=0 for v in (before,after))):return [],errors
    if not need(all(isinstance(v.get(k),dict) for v in (before,after) for k in ('hits','combat_packets'))):return [],errors
    if not need(all(after[k].get(key)==value for k in ('hits','combat_packets') for key,value in before[k].items())):return [],errors
    owner,session=after['owner_id'],after['session_id'];seen=set(before['hits']);rows=[];matched=set();credited_keys=set()
    signal_hits=dict(before['hits'])
    for credit in credits:
        observed=credit.get('hits',{})
        if not need(isinstance(observed,dict) and set(observed)-seen and all(v is True for v in observed.values())):continue
        if not need(all(observed.get(k)==v for k,v in signal_hits.items())):continue
        added=set(observed)-seen
        if not need(len(added)==1):continue
        key=next(iter(added));seen=set(observed);signal_hits=dict(observed)
        if not need(all(after['hits'].get(k) is True for k in observed) and credit.get('owner_id')==owner and credit.get('session_id')==session):continue
        spawns=[e for e in events if e.get('kind')=='actual_projectile_spawned' and str(e.get('session_id'))+'/'+str(e.get('packet'))==key and e.get('owner_id')==owner]
        if not need(len(spawns)==1):continue
        spawn=spawns[0];serial=spawn.get('serial')
        fired=[e for e in events if e.get('kind')=='shot_fired' and e.get('serial')==serial and e.get('tick')==spawn.get('tick')]
        policy=[e for e in hits if e.get('event_id')==f'{owner}:{session}:{serial}' and e.get('source')==f'player_projectile:{owner}']
        if not need(len(fired)==len(policy)==1 and spawn['tick']<=tick and 0<=(tick-spawn['tick'])*dt<spawn.get('lifetime',0) and type(spawn.get('fired_airborne')) is bool and credit.get('fired_airborne') is spawn['fired_airborne']):continue
        spawn_frames=[f for f in data['frames'] if f['tick']==spawn['tick']]
        if not need(type(spawn.get('weapon_epoch')) is int and spawn['weapon_epoch']>=0 and spawn.get('direction')==fired[0].get('aim') and len(spawn_frames)==1 and all(spawn_frames[0].get('shot_economy',{}).get(k)==spawn.get(k) for k in ('owner_id','session_id','weapon_epoch')) and after['weapon_epoch']==spawn['weapon_epoch']):continue
        hit=policy[0];target=hit.get('target');old=[e for e in previous.get('enemies',[]) if e.get('id')==target];new=[e for e in frame.get('enemies',[]) if e.get('id')==target]
        if not need(len(old)==len(new)==1 and hit.get('damage_kind')==0 and type(hit.get('amount')) in (int,float) and hit['amount']>0 and abs(old[0]['health']-new[0]['health']-hit['amount'])<.001 and abs(new[0]['health']-hit.get('health_after',-1))<.001 and bool(hit.get('lethal'))==(new[0]['health']<=0)):continue
        if not need(key not in before['combat_packets'] and abs(after['combat_packets'].get(key,-1)-target_gain)<.001 and type(credit.get('amount')) in (int,float) and math.isfinite(credit['amount']) and credit['amount']>=0):continue
        matched.add(hit['event_id']);credited_keys.add(key);rows.append(credit)
    need(set(after['hits'])-set(before['hits'])==credited_keys and set(after['combat_packets'])-set(before['combat_packets'])==credited_keys)
    need(len(rows)==len(credits) and len(matched)==len(hits))
    return rows,list(dict.fromkeys(errors))

def validate_cavity_leg(data,leg,completion,frames,events,requests,platforms,full):
    errors=[]
    def need(ok,reason):
        if not ok:errors.append(reason)
    instances=[r for r in data['manifest'].get('geometry_instances',[]) if r.get('id')==leg.get('geometry_instance')]
    if len(instances)!=1:return ['cavity_actual_instance_missing']
    instance=instances[0];raw=instance.get('local_geometry',{});nodes=raw.get('nodes',{});translation=instance.get('translation',[])
    if not all(n in nodes for n in ('S','B','C')) or len(translation)!=2:return ['cavity_actual_ports_missing']
    need((leg.get('from_port'),leg.get('to_port'))==('S','C') and instance.get('facing')==1,'cavity_actual_port_pair')
    def world(p):return [p[0]+translation[0],p[1]+translation[1]]
    ids=instance.get('platform_id_map',{});anchors=instance.get('anchor_id_map',{})
    ss,bs,cs=[ids.get(nodes[k]['support_id']) for k in ('S','B','C')]
    need(leg.get('landing')==world(nodes['C']['position']) and leg.get('landing_support_id')==cs,'cavity_actual_C_contract')
    for p in raw.get('platforms',[]):
        need(platforms.get(ids.get(p['id']))==world(p['rect'][:2])+p['rect'][2:],'cavity_translated_body_not_actual')
    start,end=completion['start_tick'],completion['tick'];by={f['tick']:f for f in frames};actual=[e for e in events if start<=e.get('tick',-1)<=end];path=[f for f in frames if start<=f['tick']<=end]
    departure=[e for e in actual if e.get('kind')=='hollow_port_departure' and e.get('port')=='S' and e.get('geometry_instance')==instance['id'] and e.get('support_id')==ss]
    arrival=[e for e in actual if e.get('kind')=='hollow_port_arrival' and e.get('port')=='C' and e.get('geometry_instance')==instance['id'] and e.get('support_id')==cs]
    bays=[e for e in actual if e.get('kind')=='cavity_bay_support' and e.get('geometry_instance')==instance['id'] and e.get('support_id')==bs]
    need(len(departure)==len(arrival)==len(bays)==1,'cavity_actual_S_B_C_observations')
    if departure:
        w=[by.get(t) for t in range(departure[0]['tick']-12,departure[0]['tick'])]
        need(all(f and full(f,ss) for f in w),'cavity_standing_S_fullsupport12')
    if bays:
        w=[by.get(t) for t in range(bays[0]['tick']-11,bays[0]['tick']+1)]
        need(all(f and full(f,bs) for f in w),'cavity_actual_B_fullsupport12')
        need(bays[0].get('standing_destination')==world(nodes['B']['position']),'cavity_B_actual_position')
    need(all(by.get(t) and full(by[t],cs) for t in range(end-11,end+1)),'cavity_actual_C_fullsupport12')
    need(not any(e.get('kind')=='jumped' for e in actual),'cavity_must_use_grounded_H_choreography')
    need(not any(e.get('kind')=='committed_damage' and e.get('target')=='player' and e.get('damage_kind')==1 for e in actual),'cavity_environment_failure_not_direct_success')
    shots=[e for e in actual if e.get('kind')=='shot_fired'];casts=[e for e in actual if e.get('kind')=='hook_cast']
    need(len(shots)==2 and all(e.get('aim')==[-1,0] for e in shots),'cavity_actual_two_horizontal_R')
    need(len(casts)==2,'cavity_actual_two_H')
    tuning=json.loads((ROOT/'config/player_tuning.json').read_text());resource=(ROOT/'resources/player/traversal.tres').read_text();definition=(ROOT/'scripts/player/traversal_definition.gd').read_text()
    def number(name,source=resource,defaults=definition):
        m=re.search(r'(?m)^'+name+r'\s*=\s*([\d.]+)',source) or re.search(r'var '+name+r'\s*:?=\s*([\d.]+)',defaults)
        if m is None:raise ValueError('missing authoritative '+name)
        return float(m.group(1))
    if len(casts)==2 and len(shots)==2:
        for j,local in enumerate(('cavity_ring_a','cavity_ring_b')):
            after=casts[j+1]['tick'] if j==0 else end+1
            group=[e for e in actual if casts[j]['tick']<=e.get('tick',-1)<after]
            chain=[]
            for kind in ('hook_cast','hook_fly','hook_pull','hook_contact_kick','hook_kick','free'):
                ee=[e for e in group if e.get('kind')==kind];need(len(ee)==1,'cavity_cell_'+str(j)+'_actual_'+kind)
                if len(ee)==1:chain.append(ee[0])
            if len(chain)==6:
                need([e['tick'] for e in chain]==sorted(set(e['tick'] for e in chain)),'cavity_cell_H_order')
                need(all(e.get('target')==anchors.get(local) for e in chain[2:]),'cavity_actual_anchor_target')
                need(chain[-1]['tick']<shots[j]['tick']<after,'cavity_actual_free_before_R')
            cast=casts[j];origin=[cast['position'][0],cast['position'][1]-6]
            anchor=next((a['position'] for a in raw['hook_anchors'] if a['id']==local),None)
            need(anchor is not None and math.dist(origin,world(anchor))<=number('hook_range')+.01,'cavity_fixed_origin_within_real_range')
            candidates=[by.get(cast['tick']-1),by.get(cast['tick'])]
            need(any(f and math.dist(f.get('hook_start',[]),origin)<.01 for f in candidates if f and len(f.get('hook_start',[]))==2),'cavity_fixed_hook_start_not_observed')
            f=by.get(shots[j]['tick']);previous=by.get(shots[j]['tick']-1)
            need(bool(f and previous and f.get('burst_remaining',0)>0 and abs(f['velocity'][0]-tuning['shot_burst_speed'])<.1 and abs(f['position'][0]-previous['position'][0]-tuning['shot_burst_speed']/tuning['physics_hz'])<.2),'cavity_R_not_actual_forward_body_burst')
    dangers=[world(r[:2])+r[2:] for r in raw.get('dangers',[])]
    for f in path:
        x,y=f['position'];body=[x-12,y-18,24,36]
        need(isinstance(f.get('body'),list) and len(f['body'])==4 and all(abs(a-b)<.001 for a,b in zip(f['body'],body)),'cavity_actual_full_body_missing')
        for px,py,w,h in dangers:
            need(min(x+12,px+w)-max(x-12,px)<=.01 or min(y+18,py+h)-max(y-18,py)<=.01,'cavity_body_inside_real_danger')
    # Replay actual shot economy from the preceding real frame, never assume E100.
    previous=by.get(start-1)
    if not previous or 'shot_energy_delay' not in previous:return errors+['cavity_actual_initial_resource_phase_missing']
    src=(ROOT/'resources/player/plains_shot_energy.tres').read_text();defs=(ROOT/'scripts/resources/definitions/shot_energy_definition.gd').read_text()
    capacity=number('capacity',src,defs);cost=number('shot_energy_cost',src,defs);recover=number('ground_recovery',src,defs);delay_limit=number('recovery_delay',src,defs)
    hit_recovery=number('hit_energy_recovery',src,defs)
    target_gain=number('target_gain',(ROOT/'resources/player/combat_energy.tres').read_text(),(ROOT/'scripts/resources/definitions/combat_energy_definition.gd').read_text())
    energy=previous['energy'];delay=previous['shot_energy_delay'];charges=previous['shots'];grounded=previous['grounded'];dt=1/tuning['physics_hz']
    for f in path:
        step_recovery=max(0,dt-delay);delay=max(0,delay-dt)
        if grounded:energy=min(capacity,energy+recover*step_recovery)
        accepted=[e for e in shots if e['tick']==f['tick']]
        for e in accepted:energy-=cost;delay=delay_limit;charges-=1
        credits,credit_errors=actual_projectile_energy_credits(data,f,by.get(f['tick']-1,{}),events,dt,target_gain)
        errors.extend(credit_errors)
        for credit in credits:
            applied=min(hit_recovery,max(0,capacity-energy))
            need(abs(credit['amount']-applied)<.001 and abs(credit.get('energy',-1)-(energy+applied))<.001,'cavity_actual_projectile_credit_amount_and_cap')
            energy+=applied
        if f['grounded']:charges=tuning['max_air_shots']
        need(0<=f['energy']<=capacity and abs(f['energy']-energy)<.001,'cavity_actual_energy_cost_and_ground_recovery')
        need(f['shots']==charges,'cavity_actual_air_shot_cost_and_landing_reset')
        grounded=f['grounded']
    return list(dict.fromkeys(errors))

def validate_cavity_elbow_leg(data,leg,completion,frames,events,requests,platforms,full):
    # All original level body, S/B/C support, H/R chain and economy guards apply.
    # The original validator itself remains byte-for-byte unchanged.
    errors=validate_cavity_leg(data,leg,completion,frames,events,requests,platforms,full)
    def need(ok,reason):
        if not ok:errors.append(reason)
    instances=[r for r in data['manifest'].get('geometry_instances',[]) if r.get('id')==leg.get('geometry_instance')]
    if len(instances)!=1:return errors+['elbow_actual_instance_missing']
    instance=instances[0];raw=instance.get('local_geometry',{});nodes=raw.get('nodes',{});offset=instance.get('translation',[])
    if not all(k in nodes for k in ('S','B','C')) or len(offset)!=2:return errors+['elbow_actual_nodes_missing']
    def world(p):return [p[0]+offset[0],p[1]+offset[1]]
    contract=raw.get('cavity_contract',{});ids=instance.get('platform_id_map',{});anchors=instance.get('anchor_id_map',{})
    need(leg.get('motion')=='descending_elbow' and contract.get('variant')=='horizontal_then_airborne_descending_elbow' and instance.get('factory_entry')=='build_cavity_elbow','elbow_actual_shape_motion_identity')
    need(data['manifest'].get('map_index')==2 and data['manifest'].get('choices',{}).get('cavity_direction')==1,'elbow_actual_topology_choice')
    bodies={p['id']:p['rect'] for p in raw.get('platforms',[])};local_anchors={a['id']:a['position'] for a in raw.get('hook_anchors',[])}
    bay=bodies.get(nodes['B']['support_id']);receiver=bodies.get(nodes['C']['support_id'])
    if not bay or not receiver or 'cavity_ring_b'not in local_anchors:return errors+['elbow_actual_bay_receiver_anchor_missing']
    bay_world=world(bay[:2])+bay[2:];target=world(local_anchors['cavity_ring_b']);goal=world(nodes['C']['position'])
    need(nodes['C']['position'][1]>nodes['B']['position'][1] and abs(nodes['C']['position'][1]+18-receiver[1])<.01,'elbow_receiver_not_actual_lower_body_surface')
    need(local_anchors['cavity_ring_b'][1]>nodes['B']['position'][1]-6,'elbow_second_anchor_not_below_bay_hook_origin')
    need(contract.get('exit_top')==receiver[1] and contract.get('airborne_after_bay_required')is True,'elbow_physical_contract_not_lower_receiver')
    actual_anchors={a['id']:a['position'] for a in data['manifest'].get('hook_anchors',[])}
    for name in ('cavity_ring_a','cavity_ring_b'):
        need(actual_anchors.get(anchors.get(name))==world(local_anchors[name]),'elbow_actual_translated_anchor')
    danger_indices=instance.get('danger_indices',[]);all_dangers=data['manifest'].get('dangers',[])
    need(len(danger_indices)==len(raw.get('dangers',[])) and all(type(i)is int and 0<=i<len(all_dangers) and all_dangers[i]==world(r[:2])+r[2:] for i,r in zip(danger_indices,raw.get('dangers',[]))),'elbow_actual_translated_thorns')
    start,end=completion['start_tick'],completion['tick'];by={f['tick']:f for f in frames};path=[f for f in frames if start<=f['tick']<=end];actual=[e for e in events if start<=e.get('tick',-1)<=end]
    casts=[e for e in actual if e.get('kind')=='hook_cast'];hr=[r for r in requests if start<=r.get('tick',-1)<=end and r.get('kind')=='grapple']
    need(len(hr)==2 and len(casts)==2 and [r['tick']for r in hr]==[e['tick']for e in casts],'elbow_actual_two_pre_motor_H_requests')
    if len(hr)==len(casts)==2:
        for i,(request,cast) in enumerate(zip(hr,casts)):
            prev=by.get(request['tick']-1);body=request.get('body_before',[]);origin=request.get('hook_origin_before',[]);velocity=request.get('velocity_before',[])
            need(bool(prev and len(body)==2 and math.dist(body,prev['position'])<.001 and len(velocity)==2 and math.dist(velocity,prev['velocity'])<.001 and request.get('grounded_before')is prev.get('grounded')),'elbow_request_not_actual_previous_motor_frame')
            need(len(body)==2 and len(origin)==2 and math.dist(origin,[body[0],body[1]-6])<.001 and math.dist(body,cast['position'])<.001,'elbow_cast_not_fixed_actual_request_origin')
            name=('cavity_ring_a','cavity_ring_b')[i];at=world(local_anchors[name])
            if len(origin)==2:
                v=[at[0]-origin[0],at[1]-origin[1]];length=math.hypot(*v)
                need(length>0 and len(request.get('aim',[]))==2 and math.dist(request['aim'],[v[0]/length,v[1]/length])<.0001 and request.get('queued')is True,'elbow_request_not_actual_target_aim')
            if i==0:need(bool(prev and full(prev,ids[nodes['S']['support_id']])) and request.get('grounded_before')is True,'elbow_first_H_not_supported_S')
        second=hr[1];prev=by.get(second['tick']-1);departures=[e for e in actual if e.get('kind')=='cavity_airborne_departure'];bays=[e for e in actual if e.get('kind')=='cavity_bay_support']
        need(len(departures)==1 and len(bays)==1 and bays[0]['tick']<second['tick'],'elbow_missing_supported_B_then_airborne_departure')
        need(bool(prev and prev.get('grounded')is False and prev['position'][0]-12>=bay_world[0]+bay_world[2]-.001 and second.get('grounded_before')is False),'elbow_second_H_not_real_full_body_beyond_bay')
        if len(departures)==1:
            e=departures[0];need(bool(prev and e['tick']==second['tick'] and e.get('grounded')is False and e.get('bay_rect')==bay_world and math.dist(e.get('position',[]),prev['position'])<.001),'elbow_departure_not_same_real_request_state')
        pulls=[e for e in actual if e.get('kind')=='hook_pull'and e.get('target')==anchors.get('cavity_ring_b')];contacts=[e for e in actual if e.get('kind')=='hook_contact_kick'and e.get('target')==anchors.get('cavity_ring_b')]
        if len(pulls)==len(contacts)==1 and prev:
            before_pull=by.get(pulls[0]['tick']-1)
            need(bool(before_pull and before_pull['position'][1]>prev['position'][1]+1),'elbow_actual_windup_fall_missing')
            need(all(f.get('grounded')is False for f in path if second['tick']<=f['tick']<contacts[0]['tick']),'elbow_landed_before_second_contact')
            resource=(ROOT/'resources/player/traversal.tres').read_text();definition=(ROOT/'scripts/player/traversal_definition.gd').read_text();match=re.search(r'(?m)^hook_stop_distance\s*=\s*([\d.]+)',resource)or re.search(r'var hook_stop_distance\s*:?=\s*([\d.]+)',definition)
            contact_frame=by.get(contacts[0]['tick']);tip=contact_frame.get('hook_tip',[]) if contact_frame else []
            anchor_source=(ROOT/'scripts/world/grapple_anchor.gd').read_text();radius_match=re.search(r'circle.radius\s*=\s*([\d.]+)',anchor_source)
            need(bool(contact_frame and len(tip)==2 and match is not None and math.dist(contacts[0]['position'],contact_frame['position'])<.001 and math.dist(contact_frame['position'],tip)<=float(match.group(1))+.051),'elbow_second_contact_not_actual_motor_arrival_at_sampled_tip')
            need(len(tip)==2 and radius_match is not None and abs(math.dist(tip,target)-float(radius_match.group(1)))<.15,'elbow_sampled_tip_not_on_actual_target_ring')
    for f in path:
        x,y=f['position']
        for row in data['manifest']['platforms']:
            if row.get('one_way',False):continue
            px,py,w,h=row['rect']
            need(min(x+12,px+w)-max(x-12,px)<=.15 or min(y+18,py+h)-max(y-18,py)<=.15,'elbow_full_body_inside_real_solid')
    need(all(by.get(t) and full(by[t],ids[nodes['C']['support_id']]) and abs(by[t]['position'][0]-goal[0])<=8 and abs(by[t]['position'][1]-goal[1])<=2 for t in range(end-11,end+1)),'elbow_actual_C_node_position_full12')
    return list(dict.fromkeys(errors))

def _air_chain_authoritative_factory(layout,regional=False):
    """Read this data-only factory's current literal geometry, fail on unknown edits.

    No runtime source execution, defaults, or captured self-reported geometry.
    The old arch geometry remains the original literal authoritative factory.
    """
    if layout=='thorn_mouth':
        source=(ROOT/'scripts/generation/forest_thorn_mouth_geometry.gd').read_text()
        version=re.search(r'const VERSION := "([^"]+)"',source).group(1)
        spec=__import__('importlib.util',fromlist=['']).spec_from_file_location('narrow_factory_reader',ROOT/'tools/run_forest_directional_golden.py')
        reader=__import__('importlib.util',fromlist=['']).module_from_spec(spec);spec.loader.exec_module(reader)
        data=reader._narrow_manifest()
        for line in source.split('static func build() -> Dictionary:',1)[1].splitlines():
            line=line.strip()
            if not line or line.startswith('#') or line in ['var data:=BASE.build_narrow().duplicate(true)','return data']:continue
            match=re.fullmatch(r'data\.([a-z_]+)(?:\[(\d+)\]\.rect)?=(.+)',line)
            if match is None:raise ValueError('unknown thorn mouth factory statement')
            field,index,value=match.groups();parsed=version if value=='VERSION' else json.loads(value)
            if index is None:data[field]=parsed
            else:data[field][int(index)]['rect']=parsed
        return data
    if layout=='hollow_spiral':
        source=(ROOT/'scripts/generation/forest_vertical_chain_geometry.gd').read_text()
        version=re.search(r'const VERSION := "([^"]+)"',source).group(1)
        literal=source.split('static func build() -> Dictionary:',1)[1].strip().removeprefix('return ')
        return json.JSONDecoder().raw_decode(literal.replace('"version":VERSION','"version":'+json.dumps(version)))[0]
    source=(ROOT/'scripts/generation/forest_air_chain_geometry.gd').read_text()
    version=re.search(r'const VERSION := "([^"]+)"',source).group(1)
    decoder=json.JSONDecoder()
    if layout=='bridge_five':
        literal=source.split('static func _build_bridge_five() -> Dictionary:',1)[1].strip().removeprefix('return ')
        return_data=decoder.raw_decode(literal.replace('"version":VERSION','"version":'+json.dumps(version)))[0]
        data=return_data
    elif layout=='arch_four':
        old=(ROOT/'scripts/generation/forest_directional_geometry.gd').read_text()
        old_version=re.search(r'const VERSION := "([^"]+)"',old).group(1)
        literal=old.split('static func build() -> Dictionary:',1)[1].split('\nstatic func ',1)[0].strip().removeprefix('return ')
        data=decoder.raw_decode(literal.replace('"version":VERSION','"version":'+json.dumps(old_version)))[0]
        block=source.split('if layout == "arch_four":',1)[1].split('\n\telse:',1)[0]
        value=block.split('data["action_program"] = ',1)[1]
        data['action_program']=decoder.raw_decode(value)[0]
    elif layout in ('hook_hook','recoil_hook','recoil_hook_recoil'):
        literal=source.split('\n\telse:',1)[1].split('data = ',1)[1]
        data=decoder.raw_decode(literal)[0]
        start={'recoil_hook':'if layout == "recoil_hook":', 'recoil_hook_recoil':'elif layout == "recoil_hook_recoil":', 'hook_hook':'elif layout == "hook_hook":'}[layout]
        block=source.split(start,1)[1].split('\n\t\telif ',1)[0].split('\n\t\telse:',1)[0]
        for line in block.splitlines():
            line=line.strip()
            if not line or line.startswith('#'):continue
            match=re.fullmatch(r'data\.([a-z_]+)(?:\[(\d+)\])? = (.+)',line)
            if match is None:raise ValueError('unknown air chain data statement')
            field,index,value=match.groups();parsed=decoder.decode(value)
            if index is None:data[field]=parsed
            else:data[field][int(index)]=parsed
    else:raise ValueError('unknown air chain factory layout')
    data['version']=version;data['id']=layout
    for field in (() if layout=='bridge_five' else ('scene_language','chain_contract')):
        literal=source.split('data["'+field+'"] = ',1)[1]
        data[field]=decoder.raw_decode(literal)[0]
    if regional and layout in ('hook_hook','recoil_hook','recoil_hook_recoil','bridge_five'):
        omitted=decoder.decode(re.search(r'(?m)^const REGIONAL_OMITTED_SUPPORTS := (.+)$',source).group(1))
        contract=decoder.decode(re.search(r'(?m)^const REGIONAL_RECOVERY := (.+)$',source).group(1))
        if omitted!=['recovery','recovery_step'] or contract!='shared-regional-roots-v1':
            raise ValueError('unrecognized regional recovery derivation')
        data['platforms']=[p for p in data['platforms'] if p['id'] not in omitted]
        data['regional_recovery']=contract
    return data

def validate_airborne_chain_leg(data,leg,completion,frames,events,requests,platforms,full):
    """All accepted actions and body/resource transitions in one real air phrase."""
    errors=[]
    def need(ok,reason):
        if not ok and reason not in errors:errors.append(reason)
        return bool(ok)
    def xy(value):return isinstance(value,list) and len(value)==2 and all(type(v) in (int,float) and math.isfinite(v) for v in value)
    def near(a,b,tolerance=.2):return xy(a) and xy(b) and math.dist(a,b)<=tolerance
    def intersects(body,rect,tolerance=.1):
        return min(body[0]+body[2],rect[0]+rect[2])-max(body[0],rect[0])>tolerance and min(body[1]+body[3],rect[1]+rect[3])-max(body[1],rect[1])>tolerance
    tuning=json.loads((ROOT/'config/player_tuning.json').read_text());resource=(ROOT/'resources/player/traversal.tres').read_text();definition=(ROOT/'scripts/player/traversal_definition.gd').read_text()
    def number(name,source=resource,defaults=definition):
        match=re.search(r'(?m)^'+name+r'\s*=\s*([-\d.]+)',source) or re.search(r'var '+name+r'\s*:?=\s*([-\d.]+)',defaults)
        if match is None:raise ValueError('missing real '+name)
        return float(match.group(1))
    manifest=data['manifest'];instances=[g for g in manifest.get('geometry_instances',[]) if g.get('id')==leg.get('geometry_instance')]
    if len(instances)!=1:return ['air_chain_actual_instance_missing']
    instance=instances[0];raw=instance.get('local_geometry',{});translation=instance.get('translation');ids=instance.get('platform_id_map',{});anchors=instance.get('anchor_id_map',{})
    if not isinstance(raw,dict) or not xy(translation) or not isinstance(ids,dict) or not isinstance(anchors,dict):return ['air_chain_actual_geometry_malformed']
    try:factory=_air_chain_authoritative_factory(raw.get('id'),regional=True)
    except (OSError,KeyError,IndexError,TypeError,ValueError,AttributeError):return ['air_chain_authoritative_factory_unreadable']
    if manifest.get('layout_version')=='forest-woven-trunk-v12' and instance.get('id') in ['broken_arch','upper_spiral']:
        need(instance.get('regional_derivation')=='omit_isolated_catch_above_previous_ascent','air_chain_exact_regional_arch_derivation')
        factory['platforms']=[p for p in factory['platforms'] if p['id'] not in ['recovery','recovery_step']]
        factory['regional_recovery']='previous-woven-hollow-catch-v1'
    if manifest.get('layout_version')=='forest-woven-trunk-v12' and 'entry_derivation' in instance:
        derivation=instance.get('entry_derivation',{})
        prior=[g for g in manifest.get('geometry_instances',[]) if g.get('id')==derivation.get('previous_instance')]
        need(derivation.get('rule')=='intersection_with_previous_crown' and len(prior)==1,'air_chain_exact_entry_derivation')
        if len(prior)==1:
            prior_factory=_air_chain_authoritative_factory(prior[0]['local_geometry']['id'],regional=True)
            receiving=next(p['rect'] for p in prior_factory['platforms'] if p['id']=='crown')
            original=next(p for p in factory['platforms'] if p['id']=='entry')
            r=original['rect']; pt=prior[0]['translation']
            left=max(r[0]+translation[0],receiving[0]+pt[0]);right=min(r[0]+r[2]+translation[0],receiving[0]+receiving[2]+pt[0])
            need(right-left>=48 and abs(r[1]+translation[1]-receiving[1]-pt[1])<.01,'air_chain_entry_intersection_has_real_support')
            original['rect']=[left-translation[0],r[1],right-left,r[3]]
            original['one_way']=next(p['one_way'] for p in prior_factory['platforms'] if p['id']=='crown')
    if manifest.get('layout_version')=='forest-woven-trunk-v12' and instance.get('id')=='upper_spiral':
        source=(ROOT/'scripts/generation/forest_vertical_expedition.gd').read_text()
        exit_position=json.loads(re.search(r'(?m)^const UPPER_EXIT_RING := (.+)$',source).group(1))
        need(instance.get('anchor_derivation')=={'rule':'upper_exit_below_legacy_far_bough','anchor':'spiral_crown','position':exit_position},'air_chain_exact_upper_anchor_clearance')
        next(a for a in factory['hook_anchors'] if a['id']=='spiral_crown')['position']=exit_position
        if manifest.get('choices',{}).get('west_reward') is True:
            aperture=json.loads(re.search(r'(?m)^const RETURN_APERTURE := (.+)$',source).group(1))
            need(instance.get('aperture_derivation')=={'rule':'tree_return_hollow','aperture':aperture,'scene_kind':'hollow_tree_return_opening'},'air_chain_exact_return_aperture_derivation')
            bark=next(p for p in factory['platforms'] if p['id']==aperture['support'])
            rect=bark['rect'];old_bottom=rect[1]+rect[3]
            bark['rect']=[rect[0],rect[1],rect[2],aperture['top']-translation[1]-rect[1]]
            factory['platforms'].append({'id':aperture['lower_support'],'rect':[rect[0],aperture['bottom']-translation[1],rect[2],old_bottom-(aperture['bottom']-translation[1])],'one_way':False})
        else:need('aperture_derivation' not in instance,'air_chain_unexpected_return_aperture')
    elif 'aperture_derivation' in instance:need(False,'air_chain_unexpected_return_aperture')
    if manifest.get('layout_version')=='forest-woven-trunk-v12' and instance.get('id')=='thorn_mouth':
        source=(ROOT/'scripts/generation/forest_vertical_expedition.gd').read_text()
        rect=json.loads(re.search(r'(?m)^const THORN_CATCH_RECT := (.+)$',source).group(1))
        bounds=json.loads(re.search(r'(?m)^const THORN_CATCH_BOUNDS := (.+)$',source).group(1))
        need(instance.get('recovery_derivation')=={'rule':'deep_catch_with_hanging_return','rect':rect,'bounds':bounds,'return_area':'thorn_mouth_mouth'},'air_chain_exact_deep_catch_derivation')
        next(p for p in factory['platforms'] if p['id']=='recovery')['rect']=rect
        factory['world_bounds']=bounds
    if manifest.get('layout_version')=='forest-woven-trunk-v12' and instance.get('id')=='canopy_fork' and manifest.get('choices',{}).get('west_reward') is True:
        source=(ROOT/'scripts/generation/forest_vertical_expedition.gd').read_text()
        left=float(re.search(r'(?m)^const CANOPY_RETURN_LEFT := ([-\d.]+)$',source).group(1))
        goal_x=float(re.search(r'(?m)^const CANOPY_RETURN_GOAL_X := ([-\d.]+)$',source).group(1))
        need(instance.get('receiver_derivation')=={'rule':'canopy_leave_migrant_return_gap','world_left':left,'world_goal_x':goal_x},'air_chain_exact_migrant_return_derivation')
        receiving=next(p for p in factory['platforms'] if p['id']=='crown')
        rect=receiving['rect'];right=rect[0]+rect[2]+translation[0]
        receiving['rect']=[left-translation[0],rect[1],right-left,rect[3]]
        factory['goal'][0]=goal_x-translation[0]
        need(actual_log:=next((p for p in manifest.get('platforms',[]) if p.get('id')=='east_descent_log'),None),'air_chain_migrant_return_log_missing')
        if actual_log is not None:need(actual_log.get('rect')==[left,372.0,170.0-left,24.0],'air_chain_exact_migrant_return_log')
        descent=next((e for e in manifest.get('connections',[]) if e.get('id')=='woven_descent'),{})
        need(descent.get('path',[None])[0]==[goal_x,354.0],'air_chain_exact_migrant_return_descent')
    else:
        need('receiver_derivation' not in instance,'air_chain_unexpected_receiver_derivation')
    need(raw==factory,'air_chain_local_geometry_not_current_factory')
    expected_factory={'hollow_spiral':'res://scripts/generation/forest_vertical_chain_geometry.gd','thorn_mouth':'res://scripts/generation/forest_thorn_mouth_geometry.gd'}.get(raw.get('id'),'res://scripts/generation/forest_air_chain_geometry.gd')
    need(instance.get('factory')==expected_factory and instance.get('geometry_version')==factory['version'],'air_chain_actual_factory_identity')
    def world(point):return [point[0]+translation[0],point[1]+translation[1]]
    actual_platforms={p['id']:p for p in manifest.get('platforms',[])};actual_anchors={a['id']:a for a in manifest.get('hook_anchors',[])}
    need(set(ids)=={p['id'] for p in factory['platforms']} and len(set(ids.values()))==len(ids),'air_chain_exact_platform_mapping')
    need(set(anchors)=={a['id'] for a in factory['hook_anchors']} and len(set(anchors.values()))==len(anchors),'air_chain_exact_anchor_mapping')
    for p in factory['platforms']:
        expected=world(p['rect'][:2])+p['rect'][2:];actual=actual_platforms.get(ids.get(p['id']),{})
        need(actual.get('rect')==expected and actual.get('one_way') is p['one_way'],'air_chain_translated_actual_platform')
    for a in factory['hook_anchors']:
        need(actual_anchors.get(anchors.get(a['id']),{}).get('position')==world(a['position']),'air_chain_translated_actual_anchor')
    danger_indices=instance.get('danger_indices',[])
    need(isinstance(danger_indices,list) and len(danger_indices)==len(factory['dangers']),'air_chain_actual_danger_indices')
    for index,danger in zip(danger_indices,factory['dangers']):
        need(type(index) is int and 0<=index<len(manifest.get('dangers',[])) and manifest['dangers'][index]==world(danger[:2])+danger[2:],'air_chain_translated_actual_danger')
    hanging=leg.get('kind')=='hanging_chain'
    expected_program=factory['action_program']
    rest_target=None
    if hanging:
        need(manifest.get('layout_version')=='forest-woven-trunk-v12' and instance.get('id')=='root_spiral' and leg.get('id')=='root_spiral_rest_flight','hang_chain_explicit_current_identity')
        expected_program=factory.get('rest_program',[])
        rest_target=leg.get('rest_anchor_id')
        rest=actual_anchors.get(rest_target,{})
        need(rest_target=='root_spiral__rest_ring' and rest.get('position')==world([-120.0,-170.0]) and rest.get('hang_enabled') is True,'hang_chain_actual_environment_ring')
        need(leg.get('hang_observation_frames')==18,'hang_chain_explicit_observation_contract')
    program=leg.get('action_program',raw.get('action_program'))
    if not need(program==expected_program,'air_chain_program_not_factory'):return errors
    entry=ids.get('entry');exit=ids.get('crown');start,end=completion['start_tick'],completion['tick'];leg_index=completion.get('leg')
    need(leg.get('landing')==world(factory['goal']) and leg.get('landing_support_id')==exit and leg.get('from_support_id',entry)==entry,'air_chain_actual_port_contract')
    by={f['tick']:f for f in frames};path=[f for f in frames if start<=f['tick']<=end];actual=[e for e in events if start<=e.get('tick',-1)<=end and e.get('leg')==leg_index];inputs=[r for r in requests if start<=r.get('tick',-1)<=end and r.get('leg')==leg_index]
    if not path:return errors+['air_chain_actual_frames_missing']
    need([f['tick'] for f in path]==list(range(start,end+1)),'air_chain_leg_frames_noncontinuous')
    departures=[e for e in actual if e.get('kind')=='air_chain_departure' and e.get('geometry_instance')==instance['id']]
    arrivals=[e for e in actual if e.get('kind')=='air_chain_arrival' and e.get('geometry_instance')==instance['id']]
    jumps=[e for e in actual if e.get('kind')=='jumped']
    need(len(departures)==len(arrivals)==len(jumps)==1,'air_chain_unique_departure_jump_arrival')
    if departures:
        d=departures[0];need(d.get('entry_support')==entry and d.get('program')==program,'air_chain_actual_departure_identity')
        need(all(by.get(t) and full(by[t],entry) for t in range(d['tick']-12,d['tick'])),'air_chain_observation_entry_fullsupport12')
        need(near(d.get('position'),world(factory['spawn']),.2),'air_chain_actual_takeoff_position')
    need(all(by.get(t) and full(by[t],exit) for t in range(end-11,end+1)),'air_chain_exit_fullsupport12')
    if arrivals:need(arrivals[0]['tick']==end and arrivals[0].get('exit_support')==exit and arrivals[0].get('program_steps')==len(program),'air_chain_actual_arrival_identity')
    first_floor=None;takeoff=None
    if jumps:
        jump=jumps[0];takeoff=jump['tick'];previous=by.get(takeoff-1,{})
        need(full(previous,entry) and by.get(takeoff,{}).get('grounded') is False,'air_chain_actual_grounded_takeoff')
        need(any(r.get('kind')=='jump_held' and r.get('held') is True and r.get('tick')==takeoff for r in inputs),'air_chain_actual_jump_intent')
        first_floor=next((f['tick'] for f in path if f['tick']>takeoff and f.get('grounded')),None)
        # A physical edge reception is legal before the player walks fully in.
        # Require the actual receiver collision and descending feet, then keep
        # the unchanged final twelve full-foot frames above as stable arrival.
        landed=by.get(first_floor,{}) if first_floor is not None else {}
        prior=by.get(first_floor-1,{}) if first_floor is not None else {}
        receiver=actual_platforms.get(exit,{}).get('rect',[])
        position=landed.get('position',[]);previous_position=prior.get('position',[])
        contact=(len(receiver)==4 and xy(position) and xy(previous_position)
                 and landed.get('grounded') is True and exit in landed.get('supports',[])
                 and min(position[0]+12,receiver[0]+receiver[2])-max(position[0]-12,receiver[0])>0
                 and abs(position[1]+18-receiver[1])<1
                 and prior.get('grounded') is False and xy(prior.get('velocity')) and prior['velocity'][1]>=0
                 and previous_position[1]+18<=receiver[1]+.1)
        need(first_floor is not None and contact,'air_chain_first_landing_not_exit')
        if first_floor:
            air=[by[t] for t in range(takeoff,first_floor) if t in by]
            need(len(air)==first_floor-takeoff and all(f.get('grounded') is False for f in air),'air_chain_midair_landing')
    # Actual body must remain outside every real solid and environment region,
    # including neighboring structures, rather than just this factory's drawing.
    for f in path:
        if not xy(f.get('position')) or not xy(f.get('velocity')):need(False,'air_chain_frame_body_malformed');continue
        x,y=f['position'];body=[x-12,y-18,24,36]
        need(isinstance(f.get('body'),list) and len(f['body'])==4 and all(type(v) in (int,float) for v in f['body']) and all(abs(a-b)<.001 for a,b in zip(f['body'],body)),'air_chain_real_body_volume_missing')
        for p in actual_platforms.values():
            if p.get('one_way') is False:need(not intersects(body,p['rect'],.2),'air_chain_body_inside_actual_solid')
        for danger in manifest.get('dangers',[]):need(not intersects(body,danger,.01),'air_chain_body_inside_actual_thorn')
        previous=by.get(f['tick']-1)
        if previous and xy(previous.get('position')):need(math.dist(f['position'],previous['position'])<=max(number('hook_pull_speed'),tuning['shot_burst_speed'],math.hypot(tuning['ground_speed'],tuning['max_normal_fall_speed']))/tuning['physics_hz']+.3,'air_chain_unexplained_displacement')
    need(not any(e.get('kind')=='committed_damage' and e.get('target')=='player' for e in actual),'air_chain_player_damaged_or_returned')
    # A direct success requires the entire ordered H/R sequence before the first
    # real landing. Phase labels and self-reported step counters are not proof.
    accepted=[e for e in actual if e.get('kind') in (('hook_contact_kick','shot_fired','hook_hang') if hanging else ('hook_contact_kick','shot_fired'))]
    need([('H' if e['kind']=='hook_contact_kick' else 'HANG' if e['kind']=='hook_hang' else 'R') for e in accepted]==[p['action'] for p in program],'air_chain_accepted_action_sequence')
    if takeoff and first_floor:need(all(takeoff<=e['tick']<first_floor for e in accepted),'air_chain_action_outside_air_window')
    casts=[e for e in actual if e.get('kind')=='hook_cast'];shots=[e for e in actual if e.get('kind')=='shot_fired'];need(len(casts)==sum(p['action'] in ('H','HANG') for p in program),'air_chain_actual_H_count')
    states=('hook_cast','hook_fly','hook_pull','hook_contact_kick','hook_kick','free')
    last_end=takeoff-1 if takeoff else start-1;h_index=0
    for action,accepted_event in zip(program,accepted):
        if action['action']=='HANG':
            if h_index>=len(casts):need(False,'hang_chain_cast_missing');continue
            cast=casts[h_index];next_cast=casts[h_index+1]['tick'] if h_index+1<len(casts) else end+1;h_index+=1
            group=actual[actual.index(cast):]
            group=[e for e in group if e.get('tick',-1)<next_cast]
            hang_states=('hook_cast','hook_fly','hook_pull','hook_hang');chain=[]
            for state in hang_states:
                found=[e for e in group if e.get('kind')==state];need(len(found)==1,'hang_chain_unique_'+state)
                if len(found)==1:chain.append(found[0])
            if len(chain)!=4:continue
            c,fly,pull,held=chain;anchor=actual_anchors.get(rest_target,{}).get('position')
            need(held is accepted_event and [e['tick'] for e in chain]==sorted(set(e['tick'] for e in chain)) and c['tick']>last_end,'hang_chain_actual_state_order')
            need(all(e.get('target')==rest_target for e in chain[2:]),'hang_chain_actual_target')
            origin=[c['position'][0],c['position'][1]-6];length=math.dist(origin,anchor) if xy(anchor) else math.inf
            need(length<=number('hook_range')+12.01,'hang_chain_real_range')
            aim=[(anchor[k]-origin[k])/length for k in (0,1)] if xy(anchor) and 0<length<math.inf else [0,0]
            need(len([r for r in inputs if r.get('kind')=='grapple' and r.get('tick')==c['tick'] and r.get('queued') is True and near(r.get('aim'),aim,.002)])==1,'hang_chain_real_router_request')
            need(near(by.get(c['tick'],{}).get('hook_start'),origin,.05),'hang_chain_real_hook_origin')
            for a,b,state in zip(chain,chain[1:],hang_states):
                need(all(by.get(t,{}).get('hook_state')==state for t in range(a['tick'],b['tick'])),'hang_chain_actual_flight_interval')
            need(xy(held.get('hook_tip')) and xy(anchor) and math.dist(held['hook_tip'],anchor)<=12.1 and math.dist(held['position'],held['hook_tip'])<=number('hook_stop_distance')+.1,'hang_chain_real_body_contact')
            dwell=[by[t] for t in range(held['tick']+1,next_cast) if t in by]
            need(len(dwell)>=18 and all(f.get('hook_state')=='hook_hang' and f.get('grounded') is False and f.get('hook_used') is False and near(f.get('position'),held['position'],.1) for f in dwell),'hang_chain_real_stable_airborne_observation')
            need(held.get('hook_used_at_event') is False,'hang_chain_actual_token_restore')
            departures=[e for e in group if e.get('kind')=='rest_branch_departure' and e.get('target')==rest_target]
            # The departure request and its accepted next cast share a tick.
            departures += [e for e in actual if e.get('kind')=='rest_branch_departure' and e.get('tick')==next_cast and e.get('target')==rest_target and e not in departures]
            need(len(departures)==1 and departures[0].get('held_frames',0)>=18 and departures[0].get('grounded') is False,'hang_chain_actual_departure_intent')
            last_end=held['tick']+17
        elif action['action']=='R':
            shot=accepted_event;tick=shot['tick'];aim=action['direction'];length=math.hypot(*aim);aim=[n/length for n in aim]
            need(shot.get('kind')=='shot_fired' and near(shot.get('aim'),aim,.001) and tick>last_end,'air_chain_R_actual_order_direction')
            matching=[r for r in inputs if r.get('kind')=='shoot_release' and r.get('tick')==tick and r.get('queued') is True and r.get('aim')==shot.get('aim')]
            need(len(matching)==1,'air_chain_R_actual_router_packet')
            # Full unobstructed burst, including fractional last tick. Ordinary
            # input cannot secretly supply the claimed recoil displacement.
            previous=by.get(tick-1);burst=math.ceil(tuning['shot_burst_duration']*tuning['physics_hz'])
            if not previous:need(False,'air_chain_R_previous_body_missing');continue
            for j in range(burst):
                f=by.get(tick+j,{});seconds=min((j+1)/tuning['physics_hz'],tuning['shot_burst_duration']);position=[previous['position'][k]-aim[k]*tuning['shot_burst_speed']*seconds for k in (0,1)]
                need(near(f.get('position'),position,.25),'air_chain_R_real_full_burst')
            last_end=tick+burst-1
        else:
            if h_index>=len(casts):need(False,'air_chain_H_cast_missing');continue
            cast=casts[h_index];next_cast=casts[h_index+1]['tick'] if h_index+1<len(casts) else end+1;h_index+=1
            group=[e for e in actual[actual.index(cast):] if e.get('tick',-1)<next_cast];chain=[]
            for state in states:
                found=[e for e in group if e.get('kind')==state];need(len(found)==1,'air_chain_H_unique_'+state)
                if len(found)==1:chain.append(found[0])
            target=anchors.get(action['anchor']);anchor=actual_anchors.get(target,{}).get('position')
            if len(chain)!=6:continue
            c,fly,pull,contact,kick,free=chain;need([e['tick'] for e in chain]==sorted(set(e['tick'] for e in chain)) and c['tick']>last_end,'air_chain_H_state_order')
            need(contact is accepted_event and all(e.get('target')==target for e in chain[2:]),'air_chain_H_actual_mapped_target')
            origin=[c['position'][0],c['position'][1]-6]
            need(xy(anchor) and math.dist(origin,anchor)<=number('hook_range')+12.01,'air_chain_H_real_origin_range')
            aim=[anchor[k]-origin[k] for k in (0,1)] if xy(anchor) else [0,0];length=math.hypot(*aim);aim=[v/length for v in aim] if length else [0,0]
            matching=[r for r in inputs if r.get('kind')=='grapple' and r.get('tick')==c['tick'] and r.get('queued') is True and near(r.get('aim'),aim,.002)]
            need(len(matching)==1 and near(by.get(c['tick'],{}).get('hook_start'),origin,.05),'air_chain_H_actual_router_origin_direction')
            for a,b,state in zip(chain,chain[1:],states):
                need(all(by.get(t,{}).get('hook_state')==state for t in range(a['tick'],b['tick'])),'air_chain_H_live_state_interval')
            need(near(contact.get('hook_tip'),by.get(contact['tick'],{}).get('hook_tip'),.05) and xy(contact.get('hook_tip')) and math.dist(contact['position'],contact['hook_tip'])<=number('hook_stop_distance')+.1,'air_chain_H_actual_body_stop')
            need(xy(contact.get('hook_tip')) and xy(anchor) and math.dist(contact['hook_tip'],anchor)<=12.1,'air_chain_H_tip_actual_anchor_surface')
            expected_used=True
            if contact.get('hook_used_at_event') is False:
                # Existing airborne projectile-hit receipts can restore H while
                # its head is in flight. Verify the same concrete receipt/target
                # ledger, rather than treating an arbitrary boolean as a reset.
                gain=number('target_gain',(ROOT/'resources/player/combat_energy.tres').read_text(),(ROOT/'scripts/resources/definitions/combat_energy_definition.gd').read_text())
                for t in range(c['tick'],contact['tick']+1):
                    credits,credit_errors=actual_projectile_energy_credits(data,by.get(t,{}),by.get(t-1,{}),events,1/tuning['physics_hz'],gain)
                    errors.extend(credit_errors)
                    if any(credit.get('fired_airborne') is True for credit in credits):expected_used=False
            need(contact.get('hook_used_at_event') is expected_used and kick.get('hook_used_at_event') is False and by.get(kick['tick'],{}).get('hook_used') is False,'air_chain_H_actual_contact_restoration')
            if takeoff is not None and c['tick']>takeoff:need(by.get(c['tick']-1,{}).get('hook_used') is False,'air_chain_H_requires_restored_token')
            need((kick['tick']-contact['tick'])/tuning['physics_hz']>=number('hook_contact_seconds')-1e-8,'air_chain_H_actual_contact_duration')
            for e in chain:
                candidates=[by.get(e['tick'],{}).get('position'),by.get(e['tick']-1,{}).get('position')]
                need(any(near(e.get('position'),p,.25) for p in candidates),'air_chain_H_event_actual_body')
            last_end=free['tick']
    # Real per-tick shot/energy ledger. The observation shore gives a genuine
    # resource phase; a previous leg need not have this new optional vocabulary.
    previous=by.get(start-1)
    if not previous or 'shot_energy_delay' not in previous:
        previous=path[0];replay=path[1:]
        need(full(previous,entry) and not any(e['tick']==previous['tick'] and e.get('kind') in ('shot_fired','hook_cast') for e in actual),'air_chain_initial_resource_observation')
    else:replay=path
    if 'shot_energy_delay' not in previous:return errors+['air_chain_initial_resource_phase_missing']
    src=(ROOT/'resources/player/plains_shot_energy.tres').read_text();defs=(ROOT/'scripts/resources/definitions/shot_energy_definition.gd').read_text()
    capacity=number('capacity',src,defs);cost=number('shot_energy_cost',src,defs);recover=number('ground_recovery',src,defs);delay_limit=number('recovery_delay',src,defs);hit_recovery=number('hit_energy_recovery',src,defs)
    target_gain=number('target_gain',(ROOT/'resources/player/combat_energy.tres').read_text(),(ROOT/'scripts/resources/definitions/combat_energy_definition.gd').read_text())
    energy=previous['energy'];delay=previous['shot_energy_delay'];charges=previous['shots'];grounded=previous['grounded'];hook_used=previous['hook_used'];dt=1/tuning['physics_hz']
    if previous is path[0]:
        first_credits,credit_errors=actual_projectile_energy_credits(data,previous,by.get(previous['tick']-1,{}),events,dt,target_gain);errors.extend(credit_errors)
        need(previous.get('pending_air_grants')==[{'amount':1,'session_id':previous.get('shot_economy',{}).get('session_id')} for c in first_credits if c.get('fired_airborne') is True],'air_chain_initial_pending_grant_receipts')
    for f in replay:
        tick=f['tick'];recovery=max(0,dt-delay);delay=max(0,delay-dt)
        if grounded:energy=min(capacity,energy+recover*recovery)
        old=by.get(tick-1,{})
        pending=old.get('pending_air_grants',[])
        need(isinstance(pending,list) and all(isinstance(g,dict) and g.get('amount')==1 and g.get('session_id')==old.get('shot_economy',{}).get('session_id') for g in pending),'air_chain_actual_pending_round_grant')
        charges=min(tuning['max_air_shots'],charges+len(pending))
        fired=[e for e in shots if e['tick']==tick]
        for e in fired:energy-=cost;delay=delay_limit;charges-=1
        credits,credit_errors=actual_projectile_energy_credits(data,f,by.get(tick-1,{}),events,dt,target_gain);errors.extend(credit_errors)
        for credit in credits:
            applied=min(hit_recovery,max(0,capacity-energy));need(abs(credit['amount']-applied)<.001 and abs(credit.get('energy',-1)-(energy+applied))<.001,'air_chain_real_projectile_credit_amount');energy+=applied
        # Projectile callbacks run after the normal Controller in this consumer.
        # They queue an air-round credit, consumed at next tick's grant phase.
        expected_pending=[{'amount':1,'session_id':f.get('shot_economy',{}).get('session_id')} for c in credits if c.get('fired_airborne') is True]
        need(f.get('pending_air_grants')==expected_pending,'air_chain_real_queued_round_grant_phase')
        if f['grounded']:charges=tuning['max_air_shots']
        for e in actual:
            if e['tick']!=tick:continue
            if e.get('kind')=='hook_cast':hook_used=True
            elif e.get('kind')=='hook_kick' or (hanging and e.get('kind')=='hook_hang' and e.get('target')==rest_target):hook_used=False
            elif e.get('kind')=='actual_shot_energy_credit' and any(c is e and c.get('fired_airborne') is True for c in credits):hook_used=False
        if f['grounded']:hook_used=False
        need(f.get('hook_used') is hook_used,'air_chain_H_token_without_real_cause')
        need(0<=f['energy']<=capacity and abs(f['energy']-energy)<.001 and abs(f.get('shot_energy_delay',-1)-delay)<.001,'air_chain_real_energy_cost_delay_and_recovery')
        need(f['shots']==charges,'air_chain_real_air_shot_charge_ledger')
        grounded=f['grounded']
    return errors


def completed_forest_encounter_jump_ticks(data):
    """Classify only proven, fully returned v11 combat jumps, never route jumps.

    Incomplete/malformed encounters return no exclusions. Original callers keep
    their independent route jump count, timing, held-input and clearance checks.
    """
    if not isinstance(data, dict):
        return set()
    manifest = data.get('manifest', {})
    if not isinstance(manifest, dict):
        return set()
    if manifest.get('version') != VERSION or manifest.get('layout_version') not in ('forest-expedition-airborne-v11','forest-woven-trunk-v12') or data.get('manual_motor_step') is not False or data.get('position_or_resource_injection') is not False:
        return set()
    events, frames, requests = data.get('events', []), data.get('frames', []), data.get('requests', [])
    if not all(isinstance(rows, list) and all(isinstance(row, dict) for row in rows) for rows in (events, frames, requests)):
        return set()
    def vector(value):
        return isinstance(value, list) and len(value) == 2 and all(type(n) in (int, float) and math.isfinite(n) for n in value)
    by = {f.get('tick'): f for f in frames if isinstance(f, dict) and type(f.get('tick')) is int}
    if len(by) != len(frames):
        return set()
    platforms = {p.get('id'): p.get('rect') for p in manifest.get('platforms', [])}
    enemies = {e.get('id') for e in manifest.get('enemies', [])}
    def full(frame, support):
        rect, pos = platforms.get(support), frame.get('position')
        return isinstance(rect, list) and len(rect) == 4 and vector(pos) and frame.get('grounded') is True and support in frame.get('supports', []) and pos[0]-12 >= rect[0]-.1 and pos[0]+12 <= rect[0]+rect[2]+.1 and abs(pos[1]+18-rect[1]) < 1
    def actor(frame, enemy):
        matches = [row for row in frame.get('enemies', []) if row.get('id') == enemy]
        return matches[0] if len(matches) == 1 else {}
    def same(row, start):
        return all(row.get(key) == start.get(key) for key in ('enemy_id', 'leg', 'saved_leg', 'saved_phase', 'origin'))
    result = set()
    starts = [e for e in events if e.get('kind') == 'forest_encounter_start']
    for start in starts:
        try:
            begin, leg, enemy, origin = start['tick'], start['leg'], start['enemy_id'], start['origin']
            if type(begin) is not int or begin < 1 or type(leg) is not int or type(start.get('saved_leg')) is not int or leg != start.get('saved_leg') or not isinstance(start.get('saved_phase'), str) or not start['saved_phase'] or enemy not in enemies or not vector(origin):
                continue
            if not 0 <= leg < len(data.get('itinerary', [])) or data['itinerary'][leg].get('kind') not in ('walk', 'drop', 'drop_through', 'jump_gap', 'jump_rise', 'jump_rise_through_gap'):
                continue
            ends = [e for e in events if e.get('kind') == 'forest_encounter_return' and same(e, start) and type(e.get('tick')) is int and begin <= e['tick'] <= begin+600]
            if len(ends) != 1:
                continue
            end, finish = ends[0], ends[0]['tick']
            terminal = [e for e in events if e.get('kind') == 'forest_encounter_terminal' and same(e, start) and begin <= e.get('tick', -1) <= finish]
            overlapping = [e for e in starts if begin <= e.get('tick', -1) <= finish]
            if len(terminal) != 1 or len(overlapping) != 1 or end.get('enemy_hp') != 0 or terminal[0].get('enemy_hp') != 0 or end.get('full_foot_frames') != 12:
                continue
            if not all(vector(e.get('position')) and any(t in by and vector(by[t].get('position')) and math.dist(e['position'], by[t]['position']) < .2 for t in (e['tick']-1, e['tick'])) for e in (start, terminal[0], end)):
                continue
            support = end.get('support')
            entry = [by[t] for t in (begin-1, begin) if t in by and vector(by[t].get('position')) and math.dist(by[t]['position'], origin) < .2 and full(by[t], support)]
            window = [by.get(t, {}) for t in range(finish-11, finish+1)]
            if not entry or not all(full(f, support) and math.dist(f['position'], origin) < 8 and type(actor(f, enemy).get('health')) in (int, float) and actor(f, enemy).get('health') == 0 and actor(f, enemy).get('terminal') is True for f in window):
                continue
            initial = actor(entry[0], enemy)
            if type(initial.get('health')) not in (int, float) or initial['health'] <= 0 or initial.get('terminal') is not False or start.get('enemy_hp') != initial['health']:
                continue
            interval = [by.get(t, {}) for t in range(begin, finish+1)]
            if not all(f.get('leg') == leg and f.get('phase') == start.get('saved_phase') and f.get('actor_epoch') == entry[0].get('actor_epoch') for f in interval):
                continue
            observed = [e for e in events if begin <= e.get('tick', -1) <= finish and e.get('leg') == leg]
            hits = [e for e in observed if e.get('kind') == 'committed_damage' and e.get('target') == enemy]
            if not hits or len({e.get('event_id') for e in hits}) != len(hits) or not any(e.get('lethal') is True and e.get('health_after') == 0 for e in hits):
                continue
            tuning = json.loads((ROOT/'config/player_tuning.json').read_text())
            resource = (ROOT/'resources/player/combat_energy.tres').read_text()
            definition = (ROOT/'scripts/resources/definitions/combat_energy_definition.gd').read_text()
            gain = re.search(r'(?m)^target_gain\s*=\s*([\d.]+)', resource) or re.search(r'var target_gain\s*:?=\s*([\d.]+)', definition)
            if not gain:
                continue
            causal = True
            for hit in hits:
                tick = hit.get('tick')
                if hit.get('damage_kind') != 0 or not str(hit.get('source', '')).startswith('player_projectile:') or tick > terminal[0]['tick'] or tick not in by or tick-1 not in by:
                    causal = False; break
                credits, errors = actual_projectile_energy_credits(data, by[tick], by[tick-1], events, 1/tuning['physics_hz'], float(gain.group(1)))
                if errors or not credits:
                    causal = False; break
            if not causal or not any(e.get('lethal') is True and actor(by[terminal[0]['tick']], enemy).get('terminal') is True for e in hits):
                continue
            jumps = [e for e in observed if e.get('kind') == 'jumped']
            actual_ticks = set()
            for jump in jumps:
                tick = jump.get('tick')
                held = [r for r in requests if r.get('tick') == tick and r.get('leg') == leg and r.get('kind') == 'jump_held' and r.get('held') is True]
                before, after = by.get(tick-1, {}), by.get(tick, {})
                if len(held) != 1 or before.get('grounded') is not True or after.get('grounded') is not False or not vector(jump.get('position')) or not vector(after.get('velocity')) or after['velocity'][1] >= 0 or math.dist(jump['position'], before.get('position', [])) > .2:
                    actual_ticks = set(); break
                actual_ticks.add(tick)
            result.update(actual_ticks)
        except (KeyError, TypeError, ValueError, ZeroDivisionError):
            # Invalid evidence cannot turn a route's extra jump into an exemption.
            continue
    return result


def validate(data):
    if data.get('route')=='upper_noH':return validate_upper_noH(data)
    errors=list(data.get('failures',[]));frames=data.get('frames',[]);manifest=data.get('manifest',{});events=data.get('events',[]);requests=data.get('requests',[])
    def fail(reason):
        if reason not in errors:errors.append(reason)
    if data.get('scope')!='formal_DemoApp_forest_v2_continuous_route_not_boss_fight' or data.get('boss_fight_covered') is not False:fail('scope_or_boss_claim')
    if data.get('manual_motor_step') is not False or data.get('position_or_resource_injection') is not False:fail('privileged_motion')
    if manifest.get('version')!=VERSION or data.get('actual_stage_version')!=VERSION or data.get('actual_stage_map')!=data.get('map_index') or manifest.get('map_index')!=data.get('map_index'):fail('actual_map_version_identity')
    if manifest.get('seed')!=f"{data.get('seed')}/thorn_forest/map_{data.get('map_index')}":fail('actual_seed_identity')
    if not frames or any(f.get('tick')!=i+1 or f.get('motor_steps')!=1 for i,f in enumerate(frames)):fail('continuous_single_motor_frames')
    initial=data.get('initial_snapshot',{});final=data.get('final_snapshot',{})
    if initial.get('hook_enabled') is not True or initial.get('double_enabled') is not False or initial.get('wall_enabled') is not False or initial.get('weapon')!='pulse_gun' or initial.get('tier')!=1:fail('actual_H_only_single_Pulse_Lv1')
    if initial.get('config')!=final.get('config') or final.get('health',0)<=0:fail('changed_runtime_or_player_dead')
    if any(final.get(k)!=initial.get(k) for k in ('hook_enabled','double_enabled','wall_enabled','weapon','tier')):fail('capability_or_single_weapon_changed')
    if data.get('audio_released') is not True:fail('strict_audio_release')
    try:
        expected=expected_itinerary(manifest,data['route'])
        if not expected or data.get('itinerary')!=expected:fail('itinerary_not_actual_manifest')
    except (KeyError,TypeError):return errors+['malformed_manifest_route']
    completed=data.get('completed_legs',[])
    if len(completed)!=len(expected):fail('incomplete_actual_route')
    platforms={p['id']:p['rect'] for p in manifest['platforms']}
    def full(f,id):
        r=platforms.get(id);p=f.get('position',[])
        return r and len(p)==2 and f.get('grounded') is True and id in f.get('supports',[]) and p[0]-12>=r[0]-.1 and p[0]+12<=r[0]+r[2]+.1 and abs(p[1]+18-r[1])<1
    for i,leg in enumerate(expected):
        matches=[r for r in completed if r.get('leg')==i]
        if len(matches)!=1:fail(f'leg_{i}_unique_completion');continue
        row=matches[0];window=[f for f in frames if row['tick']-11<=f['tick']<=row['tick']]
        if len(window)!=12 or any(not any(full(f,id) for id in f.get('supports',[])) for f in window):fail(f'leg_{i}_full_body_support_window')
        target=leg.get('landing')
        if not target or any(abs(f['position'][0]-target[0])>8 or abs(f['position'][1]-target[1])>2 for f in window):fail(f'leg_{i}_actual_destination')
        actual=[e for e in events if row['start_tick']<=e.get('tick',-1)<=row['tick']]
        if leg['kind'] in ('airborne_chain','hanging_chain'):
            for reason in validate_airborne_chain_leg(data,leg,row,frames,events,requests,platforms,full):fail(f'leg_{i}_'+reason)
        if leg['kind']=='hollow_cavity':
            is_elbow=leg.get('motion')=='descending_elbow' or any(g.get('id')==leg.get('geometry_instance') and g.get('local_geometry',{}).get('cavity_contract',{}).get('variant')=='horizontal_then_airborne_descending_elbow' for g in manifest.get('geometry_instances',[]))
            checker=validate_cavity_elbow_leg if is_elbow else validate_cavity_leg
            for reason in checker(data,leg,row,frames,events,requests,platforms,full):fail(f'leg_{i}_'+reason)
        if leg['kind'] in ('hollow_upper','hollow_lower','hollow_recovery','hollow_drop','hollow_outer_recovery'):
            instances=[g for g in manifest.get('geometry_instances',[]) if g.get('id')==leg.get('geometry_instance')]
            if len(instances)!=1:fail(f'leg_{i}_hollow_instance_identity');continue
            instance=instances[0];raw=instance.get('local_geometry',{});nodes=raw.get('nodes',{})
            pair=(leg.get('from_port','R' if leg['kind']=='hollow_outer_recovery' else None),leg.get('to_port','D' if leg['kind']=='hollow_outer_recovery' else None))
            contracts={'hollow_upper':('M','E'),'hollow_lower':('E','D'),'hollow_recovery':('D','M'),'hollow_drop':('E','R'),'hollow_outer_recovery':('R','D')}
            if pair!=contracts[leg['kind']] or pair[0] not in nodes or pair[1] not in nodes:fail(f'leg_{i}_hollow_port_pair');continue
            support=leg.get('landing_support_id',instance.get('platform_id_map',{}).get(nodes[pair[1]]['support_id']))
            destination=leg['landing'] if leg['kind']=='hollow_recovery' else [a+b for a,b in zip(nodes[pair[1]]['position'],instance['translation'])]
            if leg.get('landing')!=destination or not all(full(f,support) for f in window):fail(f'leg_{i}_hollow_actual_port_support')
            for kind,port in [('hollow_port_departure',pair[0]),('hollow_port_arrival',pair[1])]:
                records=[e for e in actual if e.get('kind')==kind and e.get('geometry_instance')==instance['id'] and e.get('port')==port]
                if len(records)!=1:fail(f'leg_{i}_{kind}_missing')
            if leg['kind'] in ('hollow_upper','hollow_lower','hollow_outer_recovery'):
                local_anchor='upper_window_ring' if leg['kind']=='hollow_upper' else 'lower_window_ring'
                anchor=instance.get('anchor_id_map',{}).get(local_anchor)
                chain=[]
                for kind in ('hook_cast','hook_fly','hook_pull','hook_contact_kick','hook_kick','free'):
                    rows=[e for e in actual if e.get('kind')==kind]
                    if len(rows)!=1:fail(f'leg_{i}_hollow_{kind}_unique')
                    else:chain.append(rows[0])
                if len(chain)==6:
                    if [e['tick'] for e in chain]!=sorted(set(e['tick'] for e in chain)):fail(f'leg_{i}_hollow_H_order')
                    if any(e.get('target')!=anchor for e in chain[2:]):fail(f'leg_{i}_hollow_actual_target')
                shots=[e for e in actual if e.get('kind')=='shot_fired']
                if leg['kind'] in ('hollow_upper','hollow_outer_recovery'):
                    desired=[-1,0] if leg['kind']=='hollow_upper' else [1,0]
                    if len(shots)!=1 or shots[0].get('aim')!=desired or len(chain)!=6 or shots[0]['tick']<=chain[-1]['tick']:fail(f'leg_{i}_hollow_actual_H_then_R')
                elif shots:fail(f'leg_{i}_hollow_deep_return_must_use_zero_R')
                if leg['kind']=='hollow_lower' and not any(r.get('kind')=='drop_through' and row['start_tick']<=r.get('tick',-1)<=row['tick'] and r.get('queued') is True for r in requests):fail(f'leg_{i}_hollow_real_departure_drop_missing')
            elif leg['kind']=='hollow_recovery':
                for local in ('inner_recovery_step','belly_entry'):
                    id=support if local=='belly_entry' else instance.get('platform_id_map',{}).get(local)
                    if len([e for e in actual if e.get('kind')=='jump_clearance_release' and e.get('support_id')==id])!=1:fail(f'leg_{i}_hollow_recovery_clearance_{local}')
        if leg['kind']=='candidate_hook_relay':
            methods=[e for e in actual if e.get('kind')=='candidate_relay_method' and e.get('edge_id')==leg['edge_id']]
            method='jump_H' if leg['edge_id']=='west_north' else 'normal_descent' if leg['edge_id']=='north_reward' else None
            if method is None or len(methods)!=1 or methods[0].get('method')!=method:fail(f'leg_{i}_candidate_relay_method')
            support='north_court' if method=='jump_H' else 'inner_reward_branch'
            if not all(full(f,support) for f in window):fail(f'leg_{i}_candidate_relay_destination_support')
            hook_events=[e for e in actual if e.get('kind','').startswith('hook_')]
            if method=='jump_H':
                if len(methods)==1:
                    method_event=methods[0];origin=method_event.get('hook_origin',[]);position=method_event.get('position',[])
                    court=platforms.get('north_court');anchors={a['id']:a['position'] for a in manifest.get('hook_anchors',[])}
                    definition=(ROOT/'scripts/player/traversal_definition.gd').read_text();resource=(ROOT/'resources/player/traversal.tres').read_text()
                    radius_match=re.search(r'(?m)^hook_capture_radius\s*=\s*([\d.]+)',resource) or re.search(r'@export var hook_capture_radius\s*:?=\s*([\d.]+)',definition)
                    radius=float(radius_match.group(1)) if radius_match else None
                    if not court or len(origin)!=2 or len(position)!=2 or radius is None or method_event.get('hook_capture_radius')!=radius or method_event.get('cleared_support_id')!='north_court' or method_event.get('cleared_rect')!=court or method_event.get('anchor_id')!=leg.get('anchor_id') or method_event.get('anchor_position')!=anchors.get(leg.get('anchor_id')):
                        fail(f'leg_{i}_relay_actual_cast_geometry')
                    elif math.dist(origin,[position[0],position[1]-6])>1e-6 or origin[1]+radius>court[1]-1:
                        fail(f'leg_{i}_relay_cast_circle_not_clear')
                    before=[f for f in frames if f['tick'] in (method_event['tick']-1,method_event['tick'])]
                    if not any(math.dist(f['position'],position)<.2 for f in before):fail(f'leg_{i}_relay_cast_position_not_raw')
                chain=[]
                for kind in ('hook_cast','hook_fly','hook_pull','hook_contact_kick','hook_kick','free'):
                    accepted=[e for e in actual if e.get('kind')==kind]
                    if len(accepted)!=1:fail(f'leg_{i}_relay_actual_{kind}')
                    else:chain.append(accepted[0])
                if len(chain)==6 and ([e['tick'] for e in chain]!=sorted(set(e['tick'] for e in chain)) or any(e.get('target')!=leg.get('anchor_id') for e in chain[2:])):fail(f'leg_{i}_relay_target_order')
                if len([e for e in actual if e.get('kind')=='jumped'])!=1:fail(f'leg_{i}_relay_actual_jump')
                if not any(q.get('kind')=='grapple' and q.get('queued') is True and row['start_tick']<=q.get('tick',-1)<=row['tick'] for q in requests):fail(f'leg_{i}_relay_actual_H_request')
            elif hook_events or any(e.get('kind')=='shot_fired' for e in actual):fail(f'leg_{i}_normal_descent_has_extra_ability')
        if (leg['kind'] in ('drop','drop_through') or (leg['kind']=='candidate_hook_relay' and leg['edge_id']=='north_reward')) and len(leg['path'])>2:
            for index,point in enumerate(leg['path'][1:-1],1):
                kind='drop_mouth_reached' if index==1 else 'drop_supported_waypoint'
                matches=[e for e in actual if e['kind']==kind and e.get('path_index')==index and e.get('planned')==point]
                if len(matches)!=1:fail(f'leg_{i}_drop_waypoint_{index}_missing')
                elif abs(matches[0]['position'][0]-point[0])>7 or (index>1 and (abs(matches[0]['position'][1]-point[1])>2 or not matches[0].get('supports'))):fail(f'leg_{i}_drop_waypoint_{index}_not_actual')
        if leg['kind'] in ('jump_gap','jump_rise','jump_rise_through_gap'):
            if not any(e['kind']=='jumped' for e in actual):fail(f'leg_{i}_actual_jump')
            if leg['kind']=='jump_rise_through_gap':
                gap=[e for e in actual if e.get('kind')=='actual_gap_body_clearance']
                if len(gap)!=1 or gap[0].get('clear_feet_y')!=leg.get('clear_feet_y') or gap[0].get('clearance_x')!=leg.get('clearance_x'):fail(f'leg_{i}_actual_gap_clearance_missing')
                elif gap[0]['position'][1]+18>leg['clear_feet_y']-1 or gap[0]['position'][0]-12<leg['clearance_x'][0] or gap[0]['position'][0]+12>leg['clearance_x'][1]:fail(f'leg_{i}_actual_gap_body_did_not_fit')
            release_kinds={'jump_clearance_release','jump_gap_release_before_ceiling','jump_gap_vertical_clearance_release'} if leg['kind']=='jump_gap' else {'jump_clearance_release'}
            if len([e for e in actual if e['kind'] in release_kinds and e.get('support_id')==leg['support_id']])!=1:fail(f'leg_{i}_actual_foot_clearance_release')
        if leg['kind']=='narrow_return':
            instance=next((g for g in manifest['geometry_instances'] if g['id']==leg['geometry_instance']),{})
            for local in ('recovery_step','entry'):
                id=instance.get('platform_id_map',{}).get(local)
                if len([e for e in actual if e['kind']=='jump_clearance_release' and e.get('support_id')==id])!=1:fail(f'leg_{i}_actual_recovery_{local}_clearance')
        if leg['kind'] in ('crossbranch_crossing','crossbranch_return'):
            contract=manifest.get('crossbranch_contract',{})
            actor_id=contract.get('enemy_id')
            actors=[r for r in manifest.get('enemies',[]) if r.get('id')==actor_id and r.get('behavior_id')=='forest_crossbranch']
            if contract.get('version')!=1 or len(actors)!=1 or actors[0].get('shore_rows')!=contract.get('shore_rows'):fail(f'leg_{i}_crossbranch_recorded_actor')
            ids=contract.get('support_ids',{})
            destination=ids.get('prize' if leg['kind']=='crossbranch_crossing' else 'west')
            if not all(full(f,destination) for f in window):fail(f'leg_{i}_crossbranch_full_receiving_shore')
            if leg['kind']=='crossbranch_crossing':
                if leg.get('edge_id')!=contract.get('outbound_edge') or leg.get('enemy_id')!=actor_id:fail(f'leg_{i}_crossbranch_outbound_identity')
                heads=[e for e in actual if e.get('kind')=='candidate_migrant_H_request']
                if heads:
                    body=[e for e in actual if e.get('kind')=='candidate_actual_migrant_body_contact']
                    recoil=[e for e in actual if e.get('kind')=='candidate_first_actual_free_R']
                    if len(heads)!=1 or len(body)!=1 or len(recoil)!=1 or heads[0].get('target_id')!=actor_id or body[0].get('target_id')!=actor_id or not heads[0]['tick']<body[0]['tick']<recoil[0]['tick']:fail(f'leg_{i}_crossbranch_live_contact_R_order')
                    if not any(e.get('kind')=='committed_damage' and e.get('target')==actor_id and e.get('damage_kind')==0 and str(e.get('event_id','')).startswith('hook/') for e in actual):fail(f'leg_{i}_crossbranch_actual_body_Policy')
                else:
                    air=[e for e in actual if e.get('kind')=='candidate_actual_ordinary_apex_R']
                    if len(air)!=2 or any(e.get('velocity',[0,-1])[1]<0 for e in air) or any(e.get('kind')=='hook_cast' for e in actual):fail(f'leg_{i}_crossbranch_ordinary_two_real_R')
            else:
                if leg.get('edge_id') not in (contract.get('return_edge'),contract.get('decline_edge')):fail(f'leg_{i}_crossbranch_return_identity')
                if manifest.get('layout_version')=='forest-woven-trunk-v12' and manifest.get('choices',{}).get('west_reward') is True:
                    source=(ROOT/'scripts/generation/forest_vertical_expedition.gd').read_text()
                    via=json.loads(re.search(r'(?m)^const RETURN_VIA := (.+)$',source).group(1))
                    if leg.get('return_via')!=via or leg.get('path',[])[2:4]!=[via['position'],via['next']]:fail(f'leg_{i}_crossbranch_exact_return_via')
                    arrivals=[e for e in actual if e.get('kind')=='candidate_return_via_arrival']
                    drops=[e for e in actual if e.get('kind')=='candidate_return_via_drop_requested']
                    lower=[e for e in actual if e.get('kind')=='phase' and e.get('to')=='candidate_return_lower_gap']
                    if len(arrivals)!=1 or len(drops)!=1 or len(lower)!=1:fail(f'leg_{i}_crossbranch_return_via_events')
                    else:
                        arrival=arrivals[0];drop=drops[0];end=lower[0]['tick']
                        held=[f for f in frames if arrival['tick']-12<=f['tick']<arrival['tick']]
                        if arrival.get('via')!=via or len(held)!=12 or not all(full(f,via['support_id']) and math.dist(f['position'],via['position'])<=2 for f in held):fail(f'leg_{i}_crossbranch_return_via_twelve_support')
                        accepted=[r for r in requests if r.get('leg')==i and r.get('kind')=='drop_through' and r.get('tick')==drop['tick'] and r.get('queued') is True and r.get('router_type')=='drop_through']
                        if drop.get('support_id')!=via['support_id'] or drop['tick']!=arrival['tick'] or len(accepted)!=1:fail(f'leg_{i}_crossbranch_return_actual_drop_request')
                        falling=[f for f in frames if drop['tick']<f['tick']<end and not f['grounded'] and via['position'][1]+60<f['position'][1]<via['next'][1]-20 and f['velocity'][1]>0]
                        if len(falling)<3 or any(e.get('kind') in ('jumped','hook_cast','shot_fired') and drop['tick']<e['tick']<end for e in actual):fail(f'leg_{i}_crossbranch_return_real_oneway_descent')
                    aperture=json.loads(re.search(r'(?m)^const RETURN_APERTURE := (.+)$',source).group(1))
                    bark=platforms.get('upper_spiral__'+aperture['support']);lower_bark=platforms.get('upper_spiral__'+aperture['lower_support'])
                    walk=[e for e in actual if e.get('kind')=='phase' and e.get('to')=='candidate_same_reward_return_to_W']
                    if not bark or not lower_bark or bark[1]+bark[3]!=aperture['top'] or lower_bark[1]!=aperture['bottom'] or len(walk)!=1:fail(f'leg_{i}_crossbranch_return_aperture_identity')
                    else:
                        through=[f for f in frames if walk[0]['tick']<=f['tick']<=row['tick'] and f['position'][0]+12>bark[0] and f['position'][0]-12<bark[0]+bark[2]]
                        if len(through)<3 or any(f['position'][1]-18<aperture['top'] or f['position'][1]+18>aperture['bottom'] for f in through):fail(f'leg_{i}_crossbranch_return_full_body_through_hollow')
                        if any(e.get('kind') in ('jumped','hook_cast','shot_fired') and walk[0]['tick']<e['tick']<=row['tick'] for e in actual):fail(f'leg_{i}_crossbranch_return_hollow_walk_no_extra_actions')
                elif 'return_via' in leg:fail(f'leg_{i}_crossbranch_unexpected_return_via')
                for phase_name,support_key in [('candidate_return_lower_gap','lower'),('candidate_same_reward_return_to_W','step1')]:
                    arrivals=[e for e in actual if e.get('kind')=='phase' and e.get('to')==phase_name]
                    if len(arrivals)!=1 or not all(full(f,ids.get(support_key)) for f in frames if arrivals[0]['tick']-12<=f['tick']<arrivals[0]['tick']) or len([f for f in frames if arrivals[0]['tick']-12<=f['tick']<arrivals[0]['tick']])!=12:fail(f'leg_{i}_crossbranch_actual_{support_key}_twelve_support')
        if leg['kind'] in ('directional_phrase','directional_return','narrow_reward','ecology_choice','gate_hook'):
            for kind in ('hook_cast','hook_fly','hook_pull','hook_contact_kick','hook_kick','free'):
                if not any(e['kind']==kind for e in actual):fail(f'leg_{i}_actual_{kind}')
        if leg['kind'] in ('directional_phrase','directional_return','narrow_reward','ecology_choice') and not any(e['kind']=='shot_fired' for e in actual):fail(f'leg_{i}_actual_R')
    by_tick={f['tick']:f for f in frames}
    encounter_jumps=completed_forest_encounter_jump_ticks(data) if manifest.get('layout_version') in ('forest-expedition-airborne-v11','forest-woven-trunk-v12') else set()
    for e in events:
        if e.get('kind')=='jump_gap_vertical_clearance_release':
            rect=platforms.get(e.get('support_id'));position=e.get('position',[]);foot=e.get('foot',[]);velocity=e.get('velocity',[])
            leg_index=e.get('leg',-1)
            expected_hold=math.ceil(json.loads((ROOT/'config/player_tuning.json').read_text())['jump_hold_duration']*json.loads((ROOT/'config/player_tuning.json').read_text())['physics_hz'])
            actual_leg=expected[leg_index] if isinstance(leg_index,int) and 0<=leg_index<len(expected) else {}
            jump_events=[j for j in events if j.get('kind')=='jumped' and j.get('leg')==leg_index and j.get('tick',0)<=e.get('tick',-1)]
            if manifest.get('layout_version') in ('forest-expedition-airborne-v11','forest-woven-trunk-v12'):jump_events=[j for j in jump_events if j.get('tick') not in encounter_jumps]
            if not rect or actual_leg.get('kind')!='jump_gap' or actual_leg.get('support_id')!=e.get('support_id') or e.get('target_rect')!=rect or len(position)!=2 or len(foot)!=2 or len(velocity)!=2:
                fail('gap_vertical_release_missing_actual_geometry')
            elif math.dist(foot,[position[0],position[1]+18])>1e-6 or foot[1]>rect[1]-1 or velocity[1]>=0 or e.get('minimum_hold_ticks')!=expected_hold or e.get('held_ticks',0)<expected_hold or len(jump_events)!=1 or e['tick']-jump_events[0]['tick']!=e['held_ticks']:
                fail('gap_vertical_release_without_real_held_jump_clearance')
            candidates=[by_tick[t] for t in (e['tick']-1,e['tick']) if t in by_tick]
            if not any(math.dist(position,f['position'])<.2 and math.dist(velocity,f['velocity'])<.2 for f in candidates):fail('gap_vertical_release_state_not_raw_frame')
            if not any(r.get('kind')=='jump_held' and r.get('held') is False and r.get('tick')==e['tick'] for r in requests):fail('gap_vertical_release_missing_actual_input')
        if e.get('kind')=='jump_gap_release_before_ceiling':
            rect=platforms.get(e.get('support_id'));ceiling=platforms.get(e.get('ceiling_id'));position=e.get('position',[]);foot=e.get('foot',[]);velocity=e.get('velocity',[])
            if not rect or not ceiling or e.get('target_rect')!=rect or e.get('ceiling_rect')!=ceiling or len(position)!=2 or len(foot)!=2 or len(velocity)!=2:fail('gap_release_missing_real_geometry')
            else:
                space=position[1]-18-(ceiling[1]+ceiling[3])
                if math.dist(foot,[position[0],position[1]+18])>1e-6 or foot[1]>rect[1]-1 or velocity[1]>=0 or space<0 or space>abs(velocity[1])/json.loads((ROOT/'config/player_tuning.json').read_text())['physics_hz']+1 or abs(space-e.get('head_clearance',-100))>1e-5 or position[0]+12<=ceiling[0] or position[0]-12>=ceiling[0]+ceiling[2]:fail('gap_release_not_actual_imminent_ceiling')
                candidates=[by_tick[t] for t in (e['tick']-1,e['tick']) if t in by_tick]
                if not any(math.dist(position,f['position'])<.2 and math.dist(velocity,f['velocity'])<.2 for f in candidates):fail('gap_release_body_velocity_not_raw_frame')
            if not any(r.get('kind')=='jump_held' and r.get('held') is False and r.get('tick')==e['tick'] for r in requests):fail('gap_release_missing_actual_input')
        if e.get('kind')=='jump_clearance_release':
            rect=platforms.get(e.get('support_id'));position=e.get('position',[]);foot=e.get('foot',[])
            if not rect or e.get('target_rect')!=rect or e.get('target_top')!=rect[1] or len(position)!=2 or (len(foot)!=2 or math.dist(foot,[position[0],position[1]+18])>1e-6) or foot[1]>rect[1]-1 or position[0]-12<rect[0]-.1 or position[0]+12>rect[0]+rect[2]+.1:fail('jump_release_without_actual_target_clearance')
            candidates=[by_tick[t]['position'] for t in (e['tick']-1,e['tick']) if t in by_tick]
            if not candidates or min(math.dist(position,p) for p in candidates)>.2:fail('jump_release_position_not_body_frame')
            if not any(r.get('kind')=='jump_held' and r.get('held') is False and r.get('tick')==e['tick'] for r in requests):fail('jump_clearance_without_actual_release_input')
        if e.get('kind')=='jumped' and not any(r.get('kind')=='jump_held' and r.get('held') is True and r.get('tick')==e['tick'] for r in requests):fail('jump_not_actual_held_input')
        if e.get('kind')=='shot_fired' and not any(r.get('kind')=='shoot_release' and r.get('tick')==e['tick'] and r.get('queued') is True and r.get('aim')==e.get('aim') for r in requests):fail('shot_not_actual_router_request')
        if e.get('kind')=='hook_cast' and not any(r.get('kind')=='grapple' and r.get('tick')==e['tick'] and r.get('queued') is True for r in requests):fail('H_not_actual_router_request')
    if data.get('route') in ('fast','growth','borer'):
        if data.get('gate_saved_open') is not True or data.get('gate_shape_disabled') is not True:fail('gate_not_real_persistent_open')
        if not any(e.get('kind')=='hook_contact_kick' and e.get('target')==manifest['vine_gate']['key_anchor'] for e in events):fail('gate_missing_real_key_contact')
    if data.get('route')=='growth' and data.get('visited_areas',{}).get(manifest.get('camp_area')) is not True:fail('actual_camp_not_visited')
    if data.get('route')=='change_mind':
        changes=[e for e in events if e.get('kind')=='actual_route_goal_changed']
        contract=manifest.get('change_mind_contract',{})
        if len(changes)!=1:fail('actual_change_mind_missing')
        else:
            e=changes[0];leg=e.get('leg',-1)
            if not 0<=leg<len(expected)-1:fail('change_mind_invalid_leg')
            else:
                fast=manifest.get('routes',{}).get('fast',[]);edge=expected[leg]['edge_id'];at=fast.index(edge) if edge in fast else -1
                if at<0 or at+1>=len(fast) or e.get('original_next_edge')!=fast[at+1] or e.get('actual_next_edge')!=expected[leg+1]['edge_id'] or e.get('actual_next_edge')==e.get('original_next_edge') or e.get('decision_node')!=contract.get('decision_node') or e.get('planned_goal')!='gate_ready' or e.get('chosen_goal')!='camp':fail('change_mind_not_actual_manifest_branch')
                row=next((r for r in completed if r.get('leg')==leg),{})
                if e.get('tick')!=row.get('tick') or not e.get('supports'):fail('change_mind_not_at_supported_decision')
        if data.get('visited_areas',{}).get(manifest.get('camp_area')) is not True:fail('change_mind_did_not_reach_camp')
    if data.get('route')=='high_return' or any(leg.get('claim_before_edge') for leg in expected):
        claim_ids={leg.get('claim_id') for leg in expected if leg.get('claim_before_edge')}
        local_id=next(iter(claim_ids)) if len(claim_ids)==1 else 'crown_cache'
        id=f"thorn_forest/map_{data['map_index']}/{local_id}"
        if data.get('cache_claimed') is not True or id not in data.get('claimed_ids',[]) or id in data.get('claim_before',{}):fail('cache_not_new_real_claim')
        if data.get('duplicate_checked') is not True or data.get('duplicate_before')!=data.get('duplicate_after'):fail('actual_duplicate_interact_not_idempotent')
        if [r.get('kind') for r in data.get('pointer_events',[])]!=['mouse_button_press','mouse_button_release']:fail('actual_reward_pointer_missing')
        modal=data.get('modal_frames',[])
        if len(modal)<5 or any(f.get('paused') is not True or not f.get('supports') or f['position']!=modal[0]['position'] or f['motion_steps']!=modal[0]['motion_steps'] for f in modal):fail('modal_not_actual_frozen_world')
    return errors

def run_region_case(i, case, output, layout="", movie=False):
    """One original native process with its own capture, log and user/cache roots."""
    seed,index,route=case
    path=output/f'{i:02d}-map{index}-{route}';path.mkdir();capture=path/'capture.json';log=path/'native.log'
    argv=['bash','tools/godot.sh','--headless','--fixed-fps','60','--path','.','--script','tests/forest_depth_region_runner.gd','--',f'--seed={seed}',f'--map={index}',f'--route={route}',f'--output={capture}']
    if layout:argv.append('--layout='+layout)
    if movie:
        argv=['bash','tools/godot.sh','--rendering-method','gl_compatibility','--audio-driver','Dummy','--write-movie',str(path/'gameplay.avi')]+argv[3:]+['--capture-movie']
    start=time.monotonic();row={'seed':seed,'map':index,'route':route,'argv':argv}
    if movie:row['mode']='actual_GL_60fps_original_route_movie'
    try:
        env={**os.environ,'GUNMAN_DATA_HOME':str(path/'user-data'),'XDG_CONFIG_HOME':str(path/'config'),'XDG_CACHE_HOME':str(path/'cache'),'LP_NUM_THREADS':'1'}
        with movie_display(env,path,movie) as native_env:
            with log.open('w') as stream:result=subprocess.run(argv,cwd=ROOT,env=native_env,stdout=stream,stderr=subprocess.STDOUT,timeout=240)
        text=log.read_text();data=json.loads(capture.read_text()) if capture.exists() else {};errors=validate(data) if capture.exists() else ['capture_absent']
        if layout and data.get('manifest',{}).get('layout_version')!=layout:errors.append('actual_layout_does_not_match_explicit_request')
        if movie:
            row['movie']=inspect_movie(path/'gameplay.avi',data);errors.extend(row['movie']['errors'])
            if 'OpenGL API' not in text:errors.append('movie_actual_GL_context_missing')
        if result.returncode!=0:errors.append('native_nonzero')
        if ERRORS.search(text):errors.append('native_script_error_or_leak')
        if not re.search(r'^FOREST DEPTH ROUTE: .* / 0 failures$',text,re.M):errors.append('native_completion_missing')
        row.update(status='passed' if not errors else 'failed',errors=errors,exit_code=result.returncode,log_sha256=sha(log),capture_sha256=sha(capture) if capture.exists() else None)
    except subprocess.TimeoutExpired:row.update(status='timeout',errors=['original_240s_native_cap'])
    except (OSError,ValueError,TypeError,KeyError,RuntimeError) as error:row.update(status='failed',errors=[type(error).__name__+': '+str(error)])
    row['seconds']=time.monotonic()-start
    return row


def schedule_cases(cases, run_case, on_result, workers=1):
    """Bound in-flight cases; the caller alone writes ordered receipts.

    On the first observed failure no further cases are submitted. Already active
    original processes finish under their own unchanged timeout and teardown.
    No future cancellation can leave an unobserved native process behind.
    """
    if workers not in (1,2):raise ValueError('case workers must be1or2')
    completed={}
    def record(i,row):
        completed[i]=row
        on_result(i,row,[(j,completed[j]) for j in sorted(completed)])
    if workers==1:
        for i,case in enumerate(cases):
            row=run_case(i,case);record(i,row)
            if row['status']!='passed':break
        return completed
    with ThreadPoolExecutor(max_workers=2) as pool:
        active={};next_index=0;failed=False
        def submit():
            nonlocal next_index
            i=next_index;next_index+=1
            active[pool.submit(run_case,i,cases[i])]=i
        while next_index<len(cases) and len(active)<2:submit()
        while active:
            done,_=wait(active,return_when=FIRST_COMPLETED)
            # Observe the entire completed batch before deciding to launch more.
            for future in sorted(done,key=lambda f:active[f]):
                i=active.pop(future)
                try:row=future.result()
                except Exception as error:
                    seed,index,route=cases[i]
                    row={'seed':seed,'map':index,'route':route,'status':'failed',
                         'errors':['case_worker_exception/'+type(error).__name__+': '+str(error)]}
                failed=failed or row['status']!='passed'
                record(i,row)
            while not failed and next_index<len(cases) and len(active)<2:submit()
    return completed


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--seed',default='forest-depth-00');parser.add_argument('--map',type=int,choices=(1,2),default=1);parser.add_argument('--route',choices=ROUTES+('all',),default='all');parser.add_argument('--routes',nargs='+',choices=ROUTES[:4]+('borer',),help='Finite explicit unique route group, sharing one import');parser.add_argument('--matrix',action='store_true',help='Explicit finite4representatives (two seeds x two maps) x4routes; requires actual map2 entry contract');parser.add_argument('--corpus',action='store_true',help='Fixed10roots00..09 x2maps x4originalroutes; original matrix16 first; one import90/native240 each, stop on first failure');parser.add_argument('--validate-only',type=Path);parser.add_argument('--movie',action='store_true',help='One explicit original route, real GL 60fps AVI; same import90/native240 and validation');parser.add_argument("--layout",choices=("shared-tree-directional-cavities-v7","shared-tree-living-detour-v9","shared-tree-canopy-hunt-v10","forest-expedition-airborne-v11","forest-woven-trunk-v12"),default="",help="Explicit registered layout for exact historical replay or new candidate validation");args=parser.parse_args()
    if args.validate_only:
        errors=validate(json.loads(args.validate_only.read_text()));print(json.dumps({'errors':errors}));return int(bool(errors))
    if args.corpus and (args.matrix or args.routes or args.route!='all'):parser.error('--corpus is the fixed80 requests and cannot combine with --matrix/--routes/a specific --route')
    if args.routes and (args.matrix or args.route!='all' or len(args.routes)!=len(set(args.routes))):parser.error('--routes must be unique and cannot combine with --matrix or a specific --route')
    if args.movie and (args.matrix or args.corpus or args.routes or args.route=='all'):parser.error('--movie requires one explicit --route and cannot combine with --matrix/--corpus/--routes')
    output=args.output.resolve()
    if not output.is_relative_to(ROOT/'build') or output.exists():parser.error('fresh output below repository build required')
    output.mkdir(parents=True)
    report={'scope':'actual_v2_routes_not_boss_or_fullrelease','source_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'source_before':inventory(),'runs':[],'status':'running'}
    def save():(output/'receipt.json').write_text(json.dumps(report,indent=2)+'\n')
    save();cases=[(args.seed,args.map,r) for r in (args.routes if args.routes else ROUTES[:3] if args.route=='all' else [args.route])]
    if args.matrix:cases=[(seed,index,r) for seed,index in [('forest-depth-hollow-00',1),('forest-depth-hollow-02',1),('forest-depth-hollow-00',2),('forest-depth-hollow-02',2)] for r in ROUTES[:4]]
    if args.corpus:
        cases=corpus_cases();report['finite_fixed_root_corpus']=True;report['requested_root_seeds']=[f'forest-depth-hollow-{n:02d}' for n in range(10)]
    report['requested_cases']=[{'seed':s,'map':i,'route':r} for s,i,r in cases];report['finite_representative_matrix']=bool(args.matrix);save()
    lock=ROOT/'build/verification/engine.lock';lock.parent.mkdir(parents=True,exist_ok=True)
    with lock.open('a') as handle:
        fcntl.flock(handle,fcntl.LOCK_EX)
        import_log=output/'import.log';import_argv=['bash','tools/godot.sh','--headless','--path','.','--editor','--quit'];start=time.monotonic()
        import_row={'argv':import_argv,'timeout_seconds':90}
        try:
            env={**os.environ,'GUNMAN_DATA_HOME':str(output/'import-user'),'XDG_CONFIG_HOME':str(output/'import-config'),'XDG_CACHE_HOME':str(output/'import-cache'),'LP_NUM_THREADS':'1'}
            with import_log.open('w') as stream:import_result=subprocess.run(import_argv,cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=90)
            errors=[]
            if import_result.returncode!=0:errors.append('import_nonzero')
            if ERRORS.search(import_log.read_text()):errors.append('import_script_error_or_leak')
            import_row.update(exit_code=import_result.returncode,errors=errors)
        except subprocess.TimeoutExpired:import_row.update(exit_code=None,errors=['original_90s_import_cap'])
        except OSError as error:import_row.update(exit_code=None,errors=['import_'+str(error)])
        import_row.update(seconds=time.monotonic()-start,log_sha256=sha(import_log) if import_log.exists() else None)
        report['source_after_import']=inventory();report['import_source_guard']=import_inventory_guard(report['source_before'],report['source_after_import']);report['import']=import_row;save()
        if import_row['errors'] or not report['import_source_guard']['passed']:
            report['source_after']=report['source_after_import'];report['source_stable']=report['import_source_guard']['passed'];report['status']='failed';save();print('FOREST DEPTH REGION: failed import',output);return 1
        workers=2 if args.corpus else 1
        report['case_workers']=workers
        report['completed_case_indices']=[]
        def record_case(i,row,ordered):
            report['runs']=[result for _,result in ordered]
            report['completed_case_indices']=[index for index,_ in ordered]
            save()
            print(json.dumps(row),flush=True)
        completed=schedule_cases(cases,lambda i,case:run_region_case(i,case,output,args.layout,args.movie),record_case,workers)
        report['not_executed_case_indices']=[i for i in range(len(cases)) if i not in completed]
        save()
    report['source_after']=inventory();report['source_stable']=report['import_source_guard']['passed'] and report['source_after_import']==report['source_after'];report['status']='passed' if len(report['runs'])==len(cases) and all(r['status']=='passed' for r in report['runs']) and report['source_stable'] else 'failed';save()
    print('FOREST DEPTH REGION:',report['status'],output)
    return 0 if report['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
