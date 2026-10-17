"""Fresh actual DemoApp v2 routes. No Boss fight or historical-v1 substitution.

Start with one seed/map and three individually recorded routes. --matrix merely
requests actual runs; it never manufactures a pass for an absent/blocked map.
"""
import argparse
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import time
ROOT=Path(__file__).resolve().parents[1]
VERSION='thorn-forest-region-v2'
ERRORS=re.compile(r'(?m)SCRIPT ERROR:|Parse Error:|SHADER ERROR:|^ERROR:|ObjectDB.*leaked|resources? still in use at exit')
ROUTES=('fast','growth','high_return','change_mind','upper_noH')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def inventory():
    files=[ROOT/'project.godot']
    for directory in ('scripts','scenes','resources','config','shaders','assets','tests','tools'):
        files.extend(p for p in (ROOT/directory).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc')
    return {p.relative_to(ROOT).as_posix():sha(p) for p in sorted(files)}
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
        if leg['kind'] in ('drop','drop_through') and len(leg['path'])>2:
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
            release_kinds={'jump_clearance_release','jump_gap_release_before_ceiling'} if leg['kind']=='jump_gap' else {'jump_clearance_release'}
            if len([e for e in actual if e['kind'] in release_kinds and e.get('support_id')==leg['support_id']])!=1:fail(f'leg_{i}_actual_foot_clearance_release')
        if leg['kind']=='narrow_return':
            instance=next((g for g in manifest['geometry_instances'] if g['id']==leg['geometry_instance']),{})
            for local in ('recovery_step','entry'):
                id=instance.get('platform_id_map',{}).get(local)
                if len([e for e in actual if e['kind']=='jump_clearance_release' and e.get('support_id')==id])!=1:fail(f'leg_{i}_actual_recovery_{local}_clearance')
        if leg['kind'] in ('directional_phrase','directional_return','narrow_reward','ecology_choice','gate_hook'):
            for kind in ('hook_cast','hook_fly','hook_pull','hook_contact_kick','hook_kick','free'):
                if not any(e['kind']==kind for e in actual):fail(f'leg_{i}_actual_{kind}')
        if leg['kind'] in ('directional_phrase','directional_return','narrow_reward','ecology_choice') and not any(e['kind']=='shot_fired' for e in actual):fail(f'leg_{i}_actual_R')
    by_tick={f['tick']:f for f in frames}
    for e in events:
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
    if data.get('route') in ('fast','growth'):
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

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--seed',default='forest-depth-00');parser.add_argument('--map',type=int,choices=(1,2),default=1);parser.add_argument('--route',choices=ROUTES+('all',),default='all');parser.add_argument('--matrix',action='store_true');parser.add_argument('--validate-only',type=Path);args=parser.parse_args()
    if args.validate_only:
        errors=validate(json.loads(args.validate_only.read_text()));print(json.dumps({'errors':errors}));return int(bool(errors))
    output=args.output.resolve()
    if not output.is_relative_to(ROOT/'build') or output.exists():parser.error('fresh output below repository build required')
    output.mkdir(parents=True)
    report={'scope':'actual_v2_routes_not_boss_or_fullrelease','source_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'source_before':inventory(),'runs':[],'status':'running'}
    def save():(output/'receipt.json').write_text(json.dumps(report,indent=2)+'\n')
    save();cases=[(args.seed,args.map,r) for r in (ROUTES[:3] if args.route=='all' else [args.route])]
    if args.matrix:cases=[(f'forest-depth-{i:02d}',index,r) for i in range(10) for index in (1,2) for r in ROUTES[:3]]
    lock=ROOT/'build/verification/engine.lock';lock.parent.mkdir(parents=True,exist_ok=True)
    with lock.open('a') as handle:
        fcntl.flock(handle,fcntl.LOCK_EX)
        for i,(seed,index,route) in enumerate(cases):
            path=output/f'{i:02d}-map{index}-{route}';path.mkdir();capture=path/'capture.json';log=path/'native.log'
            argv=['bash','tools/godot.sh','--headless','--fixed-fps','60','--path','.','--script','tests/forest_depth_region_runner.gd','--',f'--seed={seed}',f'--map={index}',f'--route={route}',f'--output={capture}']
            start=time.monotonic();row={'seed':seed,'map':index,'route':route,'argv':argv}
            try:
                env={**os.environ,'GUNMAN_DATA_HOME':str(path/'user-data'),'XDG_CONFIG_HOME':str(path/'config'),'XDG_CACHE_HOME':str(path/'cache'),'LP_NUM_THREADS':'1'}
                with log.open('w') as stream:result=subprocess.run(argv,cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=240)
                text=log.read_text();errors=validate(json.loads(capture.read_text())) if capture.exists() else ['capture_absent']
                if result.returncode!=0:errors.append('native_nonzero')
                if ERRORS.search(text):errors.append('native_script_error_or_leak')
                if not re.search(r'^FOREST DEPTH ROUTE: .* / 0 failures$',text,re.M):errors.append('native_completion_missing')
                row.update(status='passed' if not errors else 'failed',errors=errors,exit_code=result.returncode,log_sha256=sha(log),capture_sha256=sha(capture) if capture.exists() else None)
            except subprocess.TimeoutExpired:row.update(status='timeout',errors=['original_240s_native_cap'])
            except (OSError,ValueError,TypeError,KeyError) as error:row.update(status='failed',errors=[type(error).__name__+': '+str(error)])
            row['seconds']=time.monotonic()-start;report['runs'].append(row);save()
            print(json.dumps(row),flush=True)
            if row['status']!='passed':break
    report['source_after']=inventory();report['source_stable']=report['source_before']==report['source_after'];report['status']='passed' if len(report['runs'])==len(cases) and all(r['status']=='passed' for r in report['runs']) and report['source_stable'] else 'failed';save()
    print('FOREST DEPTH REGION:',report['status'],output)
    return 0 if report['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
