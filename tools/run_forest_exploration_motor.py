"""Independent v16 real-Motor acceptance; historical v15 readers stay unchanged.

One actual App case by default. --corpus requests the original fixed 80-case
order, with two workers and unchanged 90s import/240s native/600s whole caps.
This is technical traversal evidence, never a Boss, art or device approval.
"""
from __future__ import annotations
import argparse
import copy
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import selectors
import signal
import subprocess
import struct
import time

import run_forest_depth_region as original

ROOT = Path(__file__).resolve().parents[1]
LAYOUT = 'forest-branching-expedition-v16'
VERSION = 'thorn-forest-region-v2'
ROUTES = ('fast', 'growth', 'high_return', 'change_mind')
TRIAL_ROUTES = ('backlook_trial','l_hollow_trial','borrow_pod_fixed_trial','borrow_pod_live_trial','borrow_pod_kill_trial','crown_z_trial','crown_7_trial','crown_7_long_trial')
IMPORT_CAP = 90
NATIVE_CAP = 240
WHOLE_CAP = 600
KINDS = {'walk','drop','drop_through','jump_gap','jump_rise','jump_rise_through_gap','airborne_chain','hanging_chain','gate_hook','short_hook_crossing','live_hook_crossing','live_pod_defeat'}


FATAL_SCRIPT = re.compile(rb'(?:SCRIPT ERROR:\s*(?:Parse Error|Compile Error)|Failed to load script[^\n]*error)', re.I)


def run_engine_process(argv, log, env, timeout):
    """Keep original log bytes; stop only this child's group on fatal parse/init."""
    started = time.monotonic()
    fatal = False
    tail = b''
    with log.open('wb') as stream:
        process = subprocess.Popen(argv, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        def stop():
            try: os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError: pass
            try: process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                try: os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError: pass
                process.wait(timeout=2)
        try:
            with selectors.DefaultSelector() as selector:
                selector.register(process.stdout, selectors.EVENT_READ)
                while selector.get_map():
                    remaining = timeout - (time.monotonic()-started)
                    if remaining <= 0:
                        stop()
                        raise subprocess.TimeoutExpired(argv, timeout)
                    for key, _ in selector.select(min(.1, remaining)):
                        chunk = os.read(key.fileobj.fileno(), 65536)
                        if not chunk:
                            selector.unregister(key.fileobj)
                            continue
                        stream.write(chunk); stream.flush()
                        tail = (tail+chunk)[-65536:]
                        if not fatal and FATAL_SCRIPT.search(tail):
                            fatal = True
                            stop()
                process.wait(timeout=max(.01, timeout-(time.monotonic()-started)))
        except BaseException:
            stop()
            raise
        finally:
            process.stdout.close()
    return subprocess.CompletedProcess(argv, process.returncode), fatal


def expected_itinerary(manifest, route):
    result = []
    edges = {row['id']:row for row in manifest['connections']}
    for edge_id in manifest['routes'][route]:
        edge = edges[edge_id]
        if edge['kind'] == 'ordinary_sequence':
            for i, step in enumerate(edge['steps']):
                row = {**copy.deepcopy(step), 'edge_id':edge_id, 'step_index':i}
                if i == 0:
                    row.update({k:copy.deepcopy(edge[k]) for k in ('claim_before_edge','claim_area','claim_id') if k in edge})
                result.append(row)
            result.append({'kind':'walk','edge_id':edge_id,'landing':edge['path'][-1],'step_index':len(edge['steps']),'b':edge['b']})
        else:
            if edge['kind'] == 'airborne_chain':
                for i, step in enumerate(edge.get('approach_steps', [])):
                    result.append({**copy.deepcopy(step),'edge_id':edge_id,'step_index':i,'approach':True})
            result.append({**copy.deepcopy(edge),'edge_id':edge_id,'landing':edge.get('landing',edge['path'][-1])})
            for i, step in enumerate(edge.get('post_landing_steps', [])):
                result.append({**copy.deepcopy(step),'edge_id':edge_id,'step_index':i,'post_landing':True})
    return result


def number(name, resource, definition):
    for path, pattern in ((resource,rf'(?m)^{re.escape(name)}\s*=\s*([\d.]+)'),(definition,rf'\bvar {re.escape(name)}\s*:?=\s*([\d.]+)')):
        match = re.search(pattern,(ROOT/path).read_text())
        if match: return float(match.group(1))
    raise ValueError('actual_definition_number_missing/'+name)


def definition_vector(name, resource, definition):
    pattern=rf'(?m)^.*\b{re.escape(name)}\s*:?=\s*Vector2\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)'
    for path in (resource,definition):
        match=re.search(pattern,(ROOT/path).read_text())
        if match:return [float(v) for v in match.groups()]
    raise ValueError('actual_definition_vector_missing/'+name)


def vector(value, size=2):
    return isinstance(value,list) and len(value)==size and all(type(v) in (int,float) and math.isfinite(v) for v in value)


def actual_player_body(position, body):
    # Godot serializes each component to 15 significant decimal digits. The
    # independently serialized origin and position can differ after subtraction.
    return (vector(position) and vector(body,4) and body[2:] == [24,36]
            and abs(body[0]-(position[0]-12)) <= 1e-7
            and abs(body[1]-(position[1]-18)) <= 1e-7)


def actual_player_foot(position, foot):
    # Vector2 arithmetic rounds to float32 before Godot JSON serializes it.
    if not vector(position) or not vector(foot):return False
    source=struct.unpack('f',struct.pack('f',position[1]))[0]
    rounded=struct.unpack('f',struct.pack('f',source+18))[0]
    return abs(foot[0]-position[0])<=1e-7 and abs(foot[1]-rounded)<=1e-7


def same_support_landing_clearance(leg, release):
    if leg.get('kind')!='jump_gap' or leg.get('from_support_id')!=leg.get('support_id'):return True
    return vector(leg.get('landing')) and vector(release.get('position')) and abs(release['position'][0]-leg['landing'][0])<=12.0


def intersects(a,b,margin=.2):
    return a[0]+a[2] > b[0]+margin and a[0] < b[0]+b[2]-margin and a[1]+a[3] > b[1]+margin and a[1] < b[1]+b[3]-margin


def validate(data):
    errors = list(data.get('failures', []))
    def need(ok, reason):
        if not ok and reason not in errors: errors.append(reason)
    manifest = data.get('manifest', {})
    frames = data.get('frames', [])
    events = data.get('events', [])
    requests = data.get('requests', [])
    admission = data.get('bible_admission', {}) # Original runner's carrier; payload is explicitly v16.
    need(manifest.get('layout_version') == LAYOUT and admission.get('schema') == 'forest-exploration-runtime-v16', 'actual_v16_layout_and_strategy_required')
    need(admission.get('actual_layout') == LAYOUT and admission.get('actual_validated') is True and admission.get('legacy_reference_used') is False, 'actual_registry_validator_not_historical_reference')
    need(admission.get('requested_layout_pin') in ('',LAYOUT) and admission.get('actual_requested_layout_cleared') is True, 'actual_App_request_ownership')
    need(data.get('scope') == 'formal_DemoApp_forest_v2_continuous_route_not_boss_fight' and data.get('boss_fight_covered') is False, 'scope_not_boss_or_release')
    need(data.get('manual_motor_step') is False and data.get('position_or_resource_injection') is False, 'no_privileged_motion_or_resources')
    need(data.get('tick_budget') == 18000 and data.get('edge_tick_budget') == 1800, 'original_route_and_edge_budgets')
    need(manifest.get('version') == VERSION and data.get('actual_stage_version') == VERSION and data.get('actual_stage_map') == data.get('map_index') == manifest.get('map_index'), 'actual_map_version_identity')
    need(manifest.get('seed') == f"{data.get('seed')}/thorn_forest/map_{data.get('map_index')}", 'actual_seed_identity')
    for field,path in (('world_source_sha256','scripts/generation/forest_exploration_world.gd'),('module_source_sha256','scripts/generation/forest_exploration_modules.gd')):
        need(admission.get(field) == original.sha(ROOT/path), 'actual_v16_source_binding/'+field)
    need(admission.get('body_collision_before') == [24,36] and admission.get('body_collision_after') == [24,36], 'actual_body_collision_unchanged')
    initial,final = data.get('initial_snapshot',{}), data.get('final_snapshot',{})
    for snap in (initial,final):
        need(snap.get('hook_enabled') is True and snap.get('double_enabled') is False and snap.get('wall_enabled') is False and snap.get('weapon') == 'pulse_gun' and snap.get('tier') == 1, 'actual_H_only_single_Pulse_Lv1')
        need(snap.get('collision_size') == [24,36], 'snapshot_actual_player_collision')
    config = {'tuning':original.sha(ROOT/'config/player_tuning.json'),'traversal':original.sha(ROOT/'resources/player/traversal.tres')}
    need(initial.get('config') == final.get('config') == config, 'actual_runtime_configuration_changed')
    need(final.get('health',0)>0 and data.get('audio_released') is True, 'alive_and_strict_audio_release')
    need(isinstance(frames,list) and 0 < len(frames) <= 18000 and all(f.get('tick') == i+1 and f.get('motor_steps') == 1 for i,f in enumerate(frames)), 'continuous_single_Motor_frames')
    if not frames: return errors
    try:
        expected = expected_itinerary(manifest,data['route'])
    except (KeyError,TypeError,IndexError): return errors+['malformed_actual_manifest_route']
    need(bool(expected) and data.get('itinerary') == expected, 'itinerary_exact_actual_manifest')
    need(all(row.get('kind') in KINDS for row in expected), 'unsupported_v16_itinerary_kind')
    completed = data.get('completed_legs', [])
    need(len(completed) == len(expected), 'complete_actual_route')
    platforms = {p['id']:p['rect'] for p in manifest.get('platforms',[])}
    solid = [p['rect'] for p in manifest.get('platforms',[]) if p.get('one_way') is False]
    by = {f['tick']:f for f in frames}
    def full(frame,support):
        rect,pos = platforms.get(support),frame.get('position')
        return vector(rect,4) and vector(pos) and frame.get('grounded') is True and support in frame.get('supports',[]) and pos[0]-12 >= rect[0]-.1 and pos[0]+12 <= rect[0]+rect[2]+.1 and abs(pos[1]+18-rect[1])<1
    for i,leg in enumerate(expected):
        rows = [row for row in completed if row.get('leg') == i]
        if len(rows) != 1: need(False,f'leg_{i}_unique_completion'); continue
        row = rows[0]
        need(row.get('edge_id') == leg['edge_id'] and type(row.get('start_tick')) is int and type(row.get('tick')) is int, f'leg_{i}_identity')
        if type(row.get('tick')) is not int or type(row.get('start_tick')) is not int: continue
        need(1 <= row['start_tick'] <= row['tick'] <= len(frames) and row['tick']-row['start_tick'] <= 1800, f'leg_{i}_bounded_real_ticks')
        need(row['start_tick'] == (1 if i == 0 else completed[i-1]['tick']+1), f'leg_{i}_continuous_start')
        window = [by.get(t,{}) for t in range(row['tick']-11,row['tick']+1)]
        target = leg.get('landing')
        need(all(any(full(f,support) for support in f.get('supports',[])) for f in window), f'leg_{i}_twelve_full_body_support')
        need(vector(target) and all(vector(f.get('position')) and abs(f['position'][0]-target[0])<=8 and abs(f['position'][1]-target[1])<=2 for f in window), f'leg_{i}_actual_destination')
        support = leg.get('landing_support_id',leg.get('support_id'))
        if support: need(all(full(f,support) for f in window), f'leg_{i}_actual_authored_support')
        actual = [e for e in events if row['start_tick']<=e.get('tick',-1)<=row['tick']]
        if str(leg.get('kind','')).startswith('jump_'):
            need(any(e.get('kind') == 'jumped' for e in actual), f'leg_{i}_actual_jump_input')
            releases = [e for e in actual if e.get('kind') in ('jump_clearance_release','jump_gap_release_before_ceiling','jump_gap_vertical_clearance_release') and e.get('support_id') == leg.get('support_id')]
            need(len(releases) == 1, f'leg_{i}_actual_clearance_release')
            need(all(same_support_landing_clearance(leg,e) for e in releases),f'leg_{i}_same_support_real_landing_clearance')
            if leg.get('kind') == 'jump_gap' and leg.get('hold_to_receiver') is True:
                # This actual authored long-gap contract uses the unchanged
                # parent pilot's full receiver clearance, while preserving its
                # real ceiling safety and wrong-support failure conditions.
                need(len(releases)==1 and releases[0].get('kind')=='jump_clearance_release',f'leg_{i}_authored_hold_to_actual_receiver')
                if len(releases)==1:
                    rect,pos=platforms.get(leg.get('support_id')),releases[0].get('position')
                    need(vector(rect,4) and vector(pos) and pos[0]-12>=rect[0]-.1 and pos[0]+12<=rect[0]+rect[2]+.1,f'leg_{i}_full_horizontal_receiver_clearance')
        if leg.get('kind') in ('live_hook_crossing','live_pod_defeat') or leg.get('release_mode')=='hang_jump':
            _exchange_leg(data,leg,row,full,need)
        elif leg.get('kind') == 'short_hook_crossing':
            departure=[e for e in actual if e.get('kind')=='v16_short_hook_departure']
            intents=[e for e in actual if e.get('kind')=='v16_short_hook_intent']
            target=leg.get('anchor_id');anchors={a['id']:a['position'] for a in manifest.get('hook_anchors',[])}
            need(len(departure)==len(intents)==1,f'leg_{i}_real_single_short_H')
            if departure:
                held=[by.get(t,{}) for t in range(departure[0]['tick']-12,departure[0]['tick'])]
                need(all(full(f,leg['from_support_id']) for f in held),f'leg_{i}_short_H_supported_departure12')
            if intents:
                intent=intents[0];reach=number('hook_range','resources/player/traversal.tres','scripts/player/traversal_definition.gd')
                need(intent.get('target')==target and intent.get('target_position')==anchors.get(target) and vector(intent.get('origin')) and intent.get('actual_range')==reach and math.dist(intent['origin'],anchors[target])<=reach,f'leg_{i}_short_H_real_range_and_target')
            for state in ('hook_cast','hook_fly','hook_pull','hook_contact_kick','hook_kick','free'):
                accepted=[e for e in actual if e.get('kind')==state and (state in ('hook_cast','hook_fly','free') or e.get('target')==target)]
                need(len(accepted)==1,f'leg_{i}_short_H_actual_'+state)
            contact=[e for e in actual if e.get('kind')=='hook_contact_kick' and e.get('target')==target]
            stop=number('hook_stop_distance','resources/player/traversal.tres','scripts/player/traversal_definition.gd')
            need(len(contact)==1 and vector(contact[0].get('hook_tip')) and math.dist(contact[0]['position'],contact[0]['hook_tip'])<=stop+.1,f'leg_{i}_short_H_actual_body_contact')
            need(not any(e.get('kind')=='shot_fired' for e in actual),f'leg_{i}_short_H_not_extra_recoil_route')
        if leg.get('kind') in ('airborne_chain','hanging_chain'):
            _air_leg(data,leg,row,full,need)
        if leg.get('kind') in ('drop','drop_through') and len(leg.get('path',[]))>2:
            for j,point in enumerate(leg['path'][1:-1],1):
                name = 'drop_mouth_reached' if j == 1 else 'drop_supported_waypoint'
                observations = [e for e in actual if e.get('kind') == name and e.get('path_index') == j and e.get('planned') == point]
                need(len(observations)==1,f'leg_{i}_actual_drop_waypoint_{j}')
    tuning = json.loads((ROOT/'config/player_tuning.json').read_text())
    max_step = max(float(tuning['shot_burst_speed']),math.hypot(tuning['ground_speed'],tuning['max_normal_fall_speed']),number('hook_pull_speed','resources/player/traversal.tres','scripts/player/traversal_definition.gd'))/tuning['physics_hz']+1
    for i,f in enumerate(frames):
        pos,body = f.get('position'),f.get('body')
        if not vector(pos) or not vector(body,4): need(False,'finite_actual_body_samples'); continue
        need(actual_player_body(pos,body), 'body_rect_is_actual_player')
        need(not any(intersects(body,rect) for rect in solid),'body_inside_actual_solid')
        need(f.get('health',0)>0,'actual_player_dead')
        if i:
            previous = frames[i-1]
            need(math.dist(pos,previous['position'])<=max_step,'unexplained_position_displacement')
            need(f.get('actor_epoch')==previous.get('actor_epoch') and f.get('stage_epoch')==previous.get('stage_epoch'),'unexpected_actual_respawn_or_stage_switch')
    for e in events:
        tick = e.get('tick',-1)
        if e.get('kind') == 'jumped': need(any(q.get('kind')=='jump_held' and q.get('held') is True and q.get('tick')==tick for q in requests),'jump_without_actual_Router_hold')
        if e.get('kind') == 'shot_fired': need(any(q.get('kind')=='shoot_release' and q.get('queued') is True and q.get('tick')==tick and original.same_shot_direction(q.get('aim'),e.get('aim')) for q in requests),'shot_without_actual_same_tick_Router')
        if e.get('kind') == 'hook_cast': need(any(q.get('kind')=='grapple' and q.get('queued') is True and q.get('tick')==tick for q in requests),'hook_without_actual_same_tick_Router')
        if e.get('kind') in ('jump_clearance_release','jump_gap_vertical_clearance_release'):
            rect,foot,pos = platforms.get(e.get('support_id')),e.get('foot'),e.get('position')
            need(vector(rect,4) and e.get('target_rect') == rect and actual_player_foot(pos,foot) and foot[1]<=rect[1]-1, 'jump_release_without_actual_foot_clearance')
            need(any(q.get('kind')=='jump_held' and q.get('held') is False and q.get('tick')==tick for q in requests),'clearance_without_actual_release_input')
    _energy(data,need)
    if data.get('route') in ('fast','growth'):
        need(data.get('gate_saved_open') is True and data.get('gate_shape_disabled') is True,'gate_not_persistently_open')
        need(any(e.get('kind')=='hook_contact_kick' and e.get('target')==manifest.get('vine_gate',{}).get('key_anchor') for e in events),'gate_without_actual_key_contact')
    if data.get('route') in ('high_return','change_mind'):
        need(data.get('visited_areas',{}).get(manifest.get('camp_area')) is True,'actual_camp_return_missing')
    if data.get('route') == 'change_mind':
        changes = [e for e in events if e.get('kind')=='actual_route_goal_changed']
        need(len(changes)==1,'actual_change_of_mind_missing')
        if changes:
            e=changes[0];index=e.get('leg',-1);fast=manifest['routes']['fast'];contract=manifest.get('change_mind_contract',{})
            if type(index) is int and 0<=index<len(expected)-1 and expected[index]['edge_id'] in fast:
                at=fast.index(expected[index]['edge_id'])
                need(at+1<len(fast) and e.get('original_next_edge')==fast[at+1] and e.get('actual_next_edge')==expected[index+1]['edge_id'] and e.get('original_next_edge')!=e.get('actual_next_edge') and e.get('decision_node')==contract.get('decision_node') and e.get('chosen_goal')=='camp','change_of_mind_not_actual_manifest_fork')
            else: need(False,'invalid_change_mind_leg')
    if data.get('route') in TRIAL_ROUTES:
        goal=manifest.get('route_goals',{}).get(data.get('route'))
        need(bool(goal) and data.get('visited_areas',{}).get(goal) is True,'actual_trial_authored_goal_visited')
    for edge_id in dict.fromkeys(leg['edge_id'] for leg in expected):
        edge=next(e for e in manifest['connections'] if e['id']==edge_id)
        if not str(edge.get('condition','')).startswith('opened:'):continue
        key=edge['condition'].removeprefix('opened:');sid=edge.get('shortcut_id',key)
        shortcuts=[s for s in manifest.get('forest_shortcuts',[]) if s.get('id')==sid]
        entries=[e for e in events if e.get('kind')=='v16_actual_reward_shortcut_entry' and e.get('edge_id')==edge_id]
        need(len(shortcuts)==len(entries)==1,'actual_reward_shortcut_unique_entry')
        if len(shortcuts)==len(entries)==1:
            qualified=f"thorn_forest/map_{data['map_index']}/{shortcuts[0].get('unlock_reward_id')}";entry=entries[0]
            need(entry.get('opened_key')==key and entry.get('shape_disabled') is True and entry.get('opened') is True and entry.get('qualified_claim')==qualified and qualified in data.get('claimed_ids',[]) and any(t.get('claim_id')==shortcuts[0].get('unlock_reward_id') and t.get('tick',-1)<=entry.get('tick',-1) for t in admission.get('reward_transactions',[])),'actual_reward_opens_real_shortcut_shape')
    _rewards(data,expected,need)
    return errors


def ordered_exchange_states(events, target_instance, live):
    states=('hook_cast','hook_fly','hook_pull','hook_contact_kick','hook_kick','free') if live else ('hook_cast','hook_fly','hook_pull','hook_hang','hook_kick','free')
    rows=[]
    for state in states:
        found=[e for e in events if e.get('kind')==state and (state in ('hook_cast','hook_fly','free') or e.get('target_instance')==target_instance)]
        if len(found)!=1:return None
        rows.append(found[0])
    if [r.get('tick',-1) for r in rows]!=sorted(r.get('tick',-1) for r in rows):return None
    if any(e.get('kind') in ('hook_miss','hook_retract') for e in events):return None
    if any(e.get('kind')==('hook_hang' if live else 'hook_contact_kick') for e in events):return None
    return rows


def _exchange_leg(data,leg,completion,full,need):
    begin,end=completion['start_tick'],completion['tick']
    events=[e for e in data['events'] if begin<=e.get('tick',-1)<=end]
    by={f['tick']:f for f in data['frames']}
    live=leg.get('kind') in ('live_hook_crossing','live_pod_defeat')
    actor_id=leg.get('encounter_id')
    authored=[a for a in data['manifest'].get('enemies',[]) if a.get('id')==actor_id] if live else []
    if live:
        need(len(authored)==1 and authored[0].get('geometry_instance')==leg.get('geometry_instance') and authored[0].get('authored_slot_id')==leg.get('authored_slot_id') and authored[0].get('behavior_id')=='forest_swing_pod','exchange_actual_authored_live_identity')
    if leg.get('kind')=='live_pod_defeat':
        settlements=[e for e in events if e.get('kind')=='v16_live_pod_actual_defeat_settlement' and e.get('encounter_id')==actor_id]
        shots=[e for e in events if e.get('kind')=='shot_fired']
        intents=[e for e in events if e.get('kind')=='v16_live_pod_shot_intent' and e.get('encounter_id')==actor_id]
        need(len(settlements)==1 and bool(shots) and len(shots)==len(intents),'pod_defeat_actual_shots_and_single_settlement')
        need(not any(e.get('kind','').startswith('hook_') for e in events),'pod_defeat_not_live_hook_substitute')
        if settlements:
            receipt=settlements[0];pod=receipt.get('actual_pod',{});settled=receipt.get('settled_drop',{});expected=data['manifest'].get('enemy_drops',{}).get(actor_id,{})
            need(pod.get('terminal') is True and pod.get('health')==0 and pod.get('damageable_active') is False and pod.get('collision_layer')==0 and receipt.get('hook_unavailable') is True,'pod_defeat_real_terminal_collision_removed')
            need(bool(settled) and receipt.get('manifest_drop')==expected and all(settled.get(k)==v for k,v in expected.items()) and vector(settled.get('spawn_origin')) and vector(settled.get('position')),'pod_defeat_actual_seeded_drop_including_none')
            need(any(e.get('kind')=='committed_damage' and e.get('target')==actor_id and e.get('lethal') is True and str(e.get('source','')).startswith('player_projectile:') for e in events),'pod_defeat_actual_Policy_lethal_projectile')
        return
    departures=[e for e in events if e.get('kind')=='v16_exchange_departure']
    intents=[e for e in events if e.get('kind')=='v16_exchange_intent']
    need(len(departures)==len(intents)==1,'exchange_single_actual_departure_and_H')
    if len(departures)!=1 or len(intents)!=1:return
    departure,intent=departures[0],intents[0];instance=intent.get('target_instance')
    held=[by.get(t,{}) for t in range(departure['tick']-12,departure['tick'])]
    need(all(full(f,leg['from_support_id']) for f in held),'exchange_twelve_actual_supported_departure')
    reach=number('hook_range','resources/player/traversal.tres','scripts/player/traversal_definition.gd')
    need(type(instance) is int and instance>0 and intent.get('actual_range')==reach and vector(intent.get('origin')) and vector(intent.get('target_position')) and math.dist(intent['origin'],intent['target_position'])<=reach,'exchange_actual_target_within_real_range')
    chain=ordered_exchange_states(events,instance,live)
    need(chain is not None,'exchange_actual_identity_and_ordered_lifecycle')
    if chain is None:return
    contact=chain[3];stop=number('hook_stop_distance','resources/player/traversal.tres','scripts/player/traversal_definition.gd')
    need(vector(contact.get('hook_tip')) and vector(contact.get('position')) and math.dist(contact['position'],contact['hook_tip'])<=stop+.1,'exchange_actual_full_body_contact')
    need(not any(e.get('kind')=='shot_fired' for e in events),'exchange_not_recoil_replacement')
    if live:
        pod=intent.get('actual_pod',{});home=authored[0].get('position') if len(authored)==1 else None
        need(intent.get('encounter_id')==actor_id and pod.get('motor_instance')==instance and pod.get('terminal') is False and pod.get('behavior_id')=='forest_swing_pod','exchange_actual_live_motor_target')
        for event in chain[2:5]:
            need(event.get('target_actor_id')==actor_id and event.get('actual_pod',{}).get('motor_instance')==instance,'exchange_contact_identity_is_real_pod')
        if len(authored)==1:
            radius=number('patrol_half_width','resources/enemies/forest_swing_pod.tres','scripts/enemies/forest_enemy_definition.gd')
            rise=number('swing_rise','resources/enemies/forest_swing_pod.tres','scripts/enemies/forest_enemy_definition.gd')
            observed=departure.get('actual_pod',{})
            need(vector(home) and vector(observed.get('position')) and vector(observed.get('velocity')) and observed['position'][0]>=home[0]+radius*.9 and observed['position'][1]<=home[1]-rise*.8 and observed['velocity'][0]>=0,'exchange_observed_favorable_live_phase')
        side=chain[2].get('kick_side');need(side==1.0 and chain[4].get('kick_side')==side,'exchange_real_away_kick_to_right_receiver')
        kick=definition_vector('hook_kick','resources/player/traversal.tres','scripts/player/traversal_definition.gd')
        duration=number('hook_launch_seconds','resources/player/traversal.tres','scripts/player/traversal_definition.gd')
        modules=[i for i in data['manifest'].get('geometry_instances',[]) if i.get('id')==leg.get('geometry_instance')]
        declared=modules[0].get('local_geometry',{}).get('interaction_contract',{}).get('normal_kick_displacement') if len(modules)==1 else None
        need(vector(declared) and math.dist(declared,[v*duration for v in kick])<1e-7,'exchange_actual_authored_auto_kick_contract')
        burst=[f for f in data['frames'] if chain[4]['tick']<=f['tick']<=chain[5]['tick'] and f.get('burst_remaining',0)>0]
        need(bool(burst) and all(vector(f.get('burst_velocity')) and math.dist(f['burst_velocity'],[side*kick[0],kick[1]])<1e-7 for f in burst),'exchange_actual_auto_kick_not_anchor_jump')
        # Policy identity and the new combat ledger must independently bind the
        # same actual actor; Hook damage never becomes a shot-energy refund.
        policy=[e for e in events if e.get('kind')=='committed_damage' and e.get('target')==actor_id and str(e.get('event_id','')).startswith('hook/')]
        need(len(policy)==1 and policy[0].get('amount')==number('hook_damage','resources/player/traversal.tres','scripts/player/traversal_definition.gd'),'exchange_actual_live_H_Policy_damage')
    else:
        anchors=[a for a in data['manifest'].get('hook_anchors',[]) if a.get('id')==leg.get('anchor_id')]
        need(len(anchors)==1 and anchors[0].get('hang_enabled') is True and intent.get('target_position')==anchors[0].get('position'),'exchange_actual_fixed_hang_anchor')
        releases=[e for e in events if e.get('kind')=='v16_fixed_hang_jump_intent' and e.get('target_instance')==instance]
        need(len(releases)==1 and chain[3]['tick']<releases[0]['tick']<=chain[4]['tick'],'exchange_real_hang_then_jump_departure')
        if releases:
            t=releases[0]['tick'];requests=data['requests']
            need(any(q.get('kind')=='jump_held' and q.get('held') is False and chain[3]['tick']<=q.get('tick',-1)<t for q in requests) and any(q.get('kind')=='jump_held' and q.get('held') is True and q.get('tick')==t for q in requests) and any(e.get('kind')=='jumped' and e.get('tick')==t for e in events),'exchange_actual_Router_anchor_jump')


def _air_leg(data,leg,completion,full,need):
    begin,end=completion['start_tick'],completion['tick']
    events=[e for e in data['events'] if begin<=e.get('tick',-1)<=end]
    instances=[x for x in data['manifest']['geometry_instances'] if x.get('id')==leg.get('geometry_instance')]
    need(len(instances)==1,'air_actual_unique_module_instance')
    if len(instances)!=1:return
    instance=instances[0];program=instance['local_geometry'].get('action_program',[])
    need(bool(program) and leg.get('action_program')==program,'air_program_is_actual_module')
    actions=[e for e in events if e.get('kind')=='air_chain_action_requested']
    need(len(actions)==len(program) and [e.get('step') for e in actions]==list(range(len(program))) and [e.get('action') for e in actions]==[a['action'] for a in program],'air_actual_complete_program_order')
    need(len([e for e in events if e.get('kind')=='air_chain_arrival'])==1,'air_actual_receiver_arrival')
    for i,action in enumerate(program):
        if i>=len(actions):continue
        window=[e for e in events if actions[i]['tick']<=e.get('tick',-1)<(actions[i+1]['tick'] if i+1<len(actions) else end+1)]
        if action['action']=='H':
            target=instance['anchor_id_map'].get(action.get('anchor'))
            need(actions[i].get('mapped_target')==target,'air_actual_anchor_mapping')
            for state in ('hook_cast','hook_fly','hook_pull','hook_contact_kick','hook_kick','free'):
                need(any(e.get('kind')==state and (state in ('hook_cast','hook_fly','free') or e.get('target')==target) for e in window),'air_actual_H_chain/'+str(i)+'/'+state)
            contact=[e for e in window if e.get('kind')=='hook_contact_kick' and e.get('target')==target]
            stop=number('hook_stop_distance','resources/player/traversal.tres','scripts/player/traversal_definition.gd')
            need(len(contact)==1 and vector(contact[0].get('hook_tip')) and math.dist(contact[0]['position'],contact[0]['hook_tip'])<=stop+.1,'air_actual_full_body_contact/'+str(i))
        elif action['action']=='R':
            shots=[e for e in window if e.get('kind')=='shot_fired']
            desired=action.get('direction',[])
            length=math.hypot(*desired) if vector(desired) else 0
            need(len(shots)==1 and length>0 and original.same_shot_direction([v/length for v in desired],shots[0].get('aim')),'air_actual_R/'+str(i))
        else: need(False,'unsupported_actual_air_program_action')


def actual_hook_combat_packets(data,frame,previous,events,target_gain):
    """Prove accepted living H independently before using the projectile reader."""
    tick=frame['tick'];policy=[e for e in events if e.get('tick')==tick and e.get('kind')=='committed_damage' and str(e.get('event_id','')).startswith('hook/')]
    errors=[];keys=set()
    def need(ok):
        if not ok:errors.append('actual_living_hook_combat_evidence')
        return ok
    before=previous.get('shot_economy',{});after=frame.get('shot_economy',{})
    for hit in policy:
        match=re.fullmatch(r'hook/(\d+)/(\d+)/(\d+)',str(hit.get('event_id','')))
        if not need(match is not None):continue
        owner,session,serial=map(int,match.groups());key=f'{session}/hook/{serial}'
        target=hit.get('target');contact=[e for e in events if e.get('tick')==tick and e.get('kind')=='hook_contact_kick' and e.get('target_actor_id')==target]
        old=[e for e in previous.get('enemies',[]) if e.get('id')==target];new=[e for e in frame.get('enemies',[]) if e.get('id')==target]
        rows=[e for e in data['manifest'].get('enemies',[]) if e.get('id')==target]
        amount=number('hook_damage','resources/player/traversal.tres','scripts/player/traversal_definition.gd')
        if not need(len(contact)==len(old)==len(new)==len(rows)==1 and rows[0].get('behavior_id')=='forest_swing_pod'):continue
        actual=contact[0];stop=number('hook_stop_distance','resources/player/traversal.tres','scripts/player/traversal_definition.gd')
        if not need(all(before.get(k)==after.get(k)==v for k,v in (('owner_id',owner),('session_id',session))) and hit.get('source')==f'player_projectile:{owner}' and hit.get('damage_kind')==0 and hit.get('amount')==amount and abs(old[0]['health']-new[0]['health']-amount)<.001 and hit.get('health_after')==new[0]['health'] and bool(hit.get('lethal'))==(new[0]['health']<=0)):continue
        if not need(actual.get('target_instance')==new[0].get('motor_instance')==old[0].get('motor_instance') and vector(actual.get('hook_tip')) and vector(actual.get('position')) and math.dist(actual['hook_tip'],actual['position'])<=stop+.1):continue
        if not need(key not in before.get('combat_packets',{}) and after.get('combat_packets',{}).get(key)==target_gain and all(after.get('combat_packets',{}).get(k)==v for k,v in before.get('combat_packets',{}).items()) and after.get('hits')==before.get('hits')):continue
        keys.add(key)
    added=set(after.get('combat_packets',{}))-set(before.get('combat_packets',{}))
    need({k for k in added if '/hook/' in k}==keys)
    return keys,list(dict.fromkeys(errors))


def _energy(data,need):
    tuning=json.loads((ROOT/'config/player_tuning.json').read_text());dt=1/tuning['physics_hz']
    resource='game/player/resources/plains_shot_energy.tres';definition='game/combat/resources/definitions/shot_energy_definition.gd'
    capacity,cost,recover,delay_limit,hit_recovery=[number(k,resource,definition) for k in ('capacity','shot_energy_cost','ground_recovery','recovery_delay','hit_energy_recovery')]
    gain=number('target_gain','game/player/resources/combat_energy.tres','game/combat/resources/definitions/combat_energy_definition.gd')
    previous=data['initial_snapshot'];energy=previous['energy'];delay=previous['shot_energy_delay'];charges=previous['shots'];grounded=previous['grounded']
    events=data['events']
    for f in data['frames']:
        tick=f['tick'];recovery=max(0,dt-delay);delay=max(0,delay-dt)
        if grounded:energy=min(capacity,energy+recover*recovery)
        pending=previous.get('pending_air_grants',[])
        need(isinstance(pending,list) and all(g.get('amount')==1 and g.get('session_id')==previous.get('shot_economy',{}).get('session_id') for g in pending),'actual_pending_air_grants')
        charges=min(tuning['max_air_shots'],charges+len(pending))
        for event in events:
            if event.get('tick')==tick and event.get('kind')=='shot_fired':energy-=cost;delay=delay_limit;charges-=1
        hook_keys,hook_errors=actual_hook_combat_packets(data,f,previous,events,gain)
        for error in hook_errors:need(False,error)
        projectile_events=[e for e in events if not (e.get('kind')=='committed_damage' and e.get('tick')==tick and str(e.get('event_id','')).startswith('hook/'))]
        projectile_frame={**f,'shot_economy':{**f.get('shot_economy',{}),'combat_packets':{k:v for k,v in f.get('shot_economy',{}).get('combat_packets',{}).items() if k not in hook_keys}}}
        credits,errors=original.actual_projectile_energy_credits(data,projectile_frame,previous,projectile_events,dt,gain)
        for error in errors:need(False,error)
        for credit in credits:
            applied=min(hit_recovery,max(0,capacity-energy))
            need(abs(credit['amount']-applied)<.001 and abs(credit.get('energy',-1)-(energy+applied))<.001,'actual_projectile_credit_amount')
            energy+=applied
        expected_pending=[{'amount':1,'session_id':f.get('shot_economy',{}).get('session_id')} for c in credits if c.get('fired_airborne') is True]
        need(f.get('pending_air_grants')==expected_pending,'actual_queued_air_round_phase')
        if f['grounded']:charges=tuning['max_air_shots']
        need(0<=f['energy']<=capacity and abs(f['energy']-energy)<.001 and abs(f.get('shot_energy_delay',-1)-delay)<.001,'real_shot_energy_cost_delay_and_recovery')
        need(f['shots']==charges,'real_air_shot_charge_ledger')
        grounded=f['grounded'];previous=f


def _rewards(data,expected,need):
    admission=data.get('bible_admission',{});transactions=admission.get('reward_transactions',[])
    ids=[leg.get('claim_id') for leg in expected if leg.get('claim_before_edge')]
    need([row.get('claim_id') for row in transactions]==ids,'all_actual_route_rewards_claimed_once')
    if data.get('route')=='high_return':need(bool(ids),'high_reward_route_has_real_reward')
    source={r['id']:r for r in data['manifest'].get('rewards',[])}
    for row in transactions:
        local=row.get('claim_id');qualified=f"thorn_forest/map_{data['map_index']}/{local}";reward=source.get(local,{})
        before,after=row.get('before',{}),row.get('after',{})
        need(bool(reward) and qualified not in before.get('claimed',{}) and after.get('claimed',{}).get(qualified) is True and qualified in data.get('claimed_ids',[]),'actual_new_reward_claim')
        for key in ('claimed','items','coins','notes'):
            need(row.get('duplicate_before',{}).get(key)==row.get('duplicate_after',{}).get(key),'actual_duplicate_reward_idempotence/'+key)
        dc=after.get('coins',0)-before.get('coins',0);dn=after.get('notes',0)-before.get('notes',0)
        choices={(r.get('amount'),0) if r.get('kind')=='coin' else (0,r.get('amount')) for r in reward.get('resources',[]) if r.get('kind') in ('coin','note')}
        need((dc,dn) in choices,'reward_actual_resource_choice_amount')
        pointers=row.get('pointer_events',[]);modal=row.get('modal_frames',[])
        need([e.get('kind') for e in pointers]==['mouse_button_press','mouse_button_release'],'actual_reward_mouse_choice')
        need(len(modal)>=5 and all(f.get('paused') is True and f.get('supports') and f.get('position')==modal[0].get('position') and f.get('motion_steps')==modal[0].get('motion_steps') for f in modal),'actual_reward_modal_freezes_world')
    for e in data.get('events',[]):
        if e.get('kind')=='v16_duplicate_cache_reader_dismissed':need(e.get('paused_before') is True and e.get('reader_closed') is True and e.get('paused_after') is False and e.get('before')==e.get('after'),'actual_duplicate_reader_neutral_close')


def run_case(i,case,output,layout,movie,deadline):
    seed,index,route=case;folder=output/f'{i:02d}-map{index}-{route}';folder.mkdir()
    capture=folder/'capture.json';log=folder/'native.log'
    argv=['bash','tools/godot.sh','--headless','--fixed-fps','60','--path','.','--script','tests/forest_depth_region_runner.gd','--',f'--seed={seed}',f'--map={index}',f'--route={route}',f'--output={capture}']
    if layout:argv.append('--layout='+layout)
    if movie:argv=['bash','tools/godot.sh','--rendering-method','gl_compatibility','--audio-driver','Dummy','--write-movie',str(folder/'gameplay.avi')]+argv[3:]+['--capture-movie']
    row={'seed':seed,'map':index,'route':route,'argv':argv,'native_timeout_seconds':NATIVE_CAP};started=time.monotonic()
    try:
        remaining=deadline-time.monotonic()
        if remaining<=0:raise TimeoutError('whole_600s_cap')
        env={**os.environ,'GUNMAN_DATA_HOME':str(folder/'user-data'),'XDG_CONFIG_HOME':str(folder/'config'),'XDG_CACHE_HOME':str(folder/'cache'),'LP_NUM_THREADS':'1','OMP_NUM_THREADS':'1'}
        with original.movie_display(env,folder,movie) as native_env:
            r,fatal=run_engine_process(argv,log,native_env,min(NATIVE_CAP,remaining))
        text=log.read_text();data=json.loads(capture.read_text()) if capture.exists() else {}
        errors=validate(data) if capture.exists() else ['capture_absent']
        if r.returncode:errors.append('native_nonzero')
        if fatal:errors.append('fatal_script_parse_or_compile')
        if original.ERRORS.search(text):errors.append('native_script_error_or_leak')
        if not re.search(r'^FOREST DEPTH ROUTE: .* / 0 failures$',text,re.M):errors.append('native_completion_missing')
        if movie:
            row['movie']=original.inspect_movie(folder/'gameplay.avi',data);errors.extend(row['movie']['errors'])
            if 'OpenGL API' not in text:errors.append('movie_actual_GL_context_missing')
        health=[f['health'] for f in data.get('frames',[])]
        row.update(status='passed' if not errors else 'failed',errors=errors,exit_code=r.returncode,capture_sha256=original.sha(capture) if capture.exists() else None,log_sha256=original.sha(log),frames=len(data.get('frames',[])),legs=len(data.get('completed_legs',[])),minimum_health=min(health) if health else None,observed_damage_transitions=sum(b<a for a,b in zip(health,health[1:])),requested_layout_pin=layout)
    except (subprocess.TimeoutExpired,TimeoutError) as exc:row.update(status='timeout',errors=['whole_600s_cap' if time.monotonic()>=deadline else 'original_240s_native_cap'])
    except (OSError,ValueError,TypeError,KeyError,IndexError,RuntimeError) as exc:row.update(status='failed',errors=[type(exc).__name__+': '+str(exc)])
    row.update(log_sha256=original.sha(log) if log.exists() else None,capture_sha256=original.sha(capture) if capture.exists() else None)
    row['seconds']=time.monotonic()-started
    return row


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path)
    p.add_argument('--seed',default='forest-depth-hollow-00');p.add_argument('--map',type=int,choices=(1,2),default=1)
    p.add_argument('--route',choices=ROUTES+TRIAL_ROUTES+('all',),default='fast');p.add_argument('--routes',nargs='+',choices=ROUTES)
    p.add_argument('--corpus',action='store_true');p.add_argument('--matrix',action='store_true')
    p.add_argument('--layout',choices=(LAYOUT,),default='',help='Omit to exercise the real unpinned current App default')
    p.add_argument('--movie',action='store_true');p.add_argument('--validate-only',type=Path)
    a=p.parse_args()
    if a.validate_only:
        errors=validate(json.loads(a.validate_only.read_text()));print(json.dumps({'errors':errors}));return int(bool(errors))
    if a.output is None:p.error('--output required for execution')
    if a.corpus and (a.matrix or a.routes or a.route not in ('fast','all')):p.error('--corpus has the original fixed80 order')
    if a.matrix and (a.routes or a.route not in ('fast','all')):p.error('--matrix has the original fixed16 order')
    if a.routes and len(a.routes)!=len(set(a.routes)):p.error('--routes must be unique')
    if a.movie and (a.corpus or a.matrix or a.routes or a.route=='all'):p.error('--movie requires one explicit case')
    output=a.output.resolve()
    if output.exists() or not (output.is_relative_to(ROOT/'build') or output.is_relative_to(Path('/tmp'))):p.error('fresh output under ignored build/ or /tmp required')
    output.mkdir(parents=True)
    cases=original.corpus_cases() if a.corpus else original.corpus_cases()[:16] if a.matrix else [(a.seed,a.map,r) for r in (a.routes or ROUTES if a.route=='all' else a.routes or (a.route,))]
    report={'schema':'forest-exploration-Motor-v16','scope':'actual_new_v16_Router_Motor_routes_not_v15_or_Boss_or_release','source_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'source_before':original.inventory(),'requested_cases':[{'seed':s,'map':m,'route':r} for s,m,r in cases],'requested_layout_pin':a.layout,'case_workers':2 if a.corpus else 1,'import_cap_seconds':IMPORT_CAP,'native_cap_seconds':NATIVE_CAP,'whole_cap_seconds':WHOLE_CAP,'fixed_fps':60,'runs':[],'status':'running'}
    def save():(output/'receipt.json').write_text(json.dumps(report,indent=2)+'\n')
    save();lock=ROOT/'build/verification/engine.lock';lock.parent.mkdir(parents=True,exist_ok=True)
    with lock.open('a') as handle:
        fcntl.flock(handle,fcntl.LOCK_EX);started=time.monotonic();deadline=started+WHOLE_CAP
        argv=['bash','tools/godot.sh','--headless','--path','.','--editor','--quit'];log=output/'import.log';entry={'argv':argv,'timeout_seconds':IMPORT_CAP};t=time.monotonic()
        try:
            env={**os.environ,'GUNMAN_DATA_HOME':str(output/'import-user'),'XDG_CONFIG_HOME':str(output/'import-config'),'XDG_CACHE_HOME':str(output/'import-cache'),'LP_NUM_THREADS':'1'}
            r,fatal=run_engine_process(argv,log,env,IMPORT_CAP)
            entry.update(exit_code=r.returncode,errors=(['import_nonzero'] if r.returncode else [])+(['import_script_error_or_leak'] if original.ERRORS.search(log.read_text()) else [])+(['fatal_script_parse_or_compile'] if fatal else []))
        except subprocess.TimeoutExpired:entry.update(exit_code=None,errors=['original_90s_import_cap'])
        except OSError as exc:entry.update(exit_code=None,errors=[type(exc).__name__+': '+str(exc)])
        entry.update(seconds=time.monotonic()-t,log_sha256=original.sha(log) if log.exists() else None)
        report['import']=entry;report['source_after_import']=original.inventory();report['import_source_guard']=original.import_inventory_guard(report['source_before'],report['source_after_import']);save()
        completed={}
        if not entry['errors'] and report['import_source_guard']['passed']:
            def record(i,row,ordered):
                report['runs']=[r for _,r in ordered];report['completed_case_indices']=[i for i,_ in ordered];save();print(json.dumps(row),flush=True)
            completed=original.schedule_cases(cases,lambda i,c:run_case(i,c,output,a.layout,a.movie,deadline),record,report['case_workers'])
        report['not_executed_case_indices']=[i for i in range(len(cases)) if i not in completed]
        report['source_after']=original.inventory();report['source_stable']=report['import_source_guard']['passed'] and report['source_after_import']==report['source_after']
        report['seconds']=time.monotonic()-started
        report['status']='passed' if len(completed)==len(cases) and all(r['status']=='passed' for r in report['runs']) and report['source_stable'] and report['seconds']<=WHOLE_CAP else 'failed';save()
    print(f"FOREST EXPLORATION MOTOR: {report['status']} / {len(report['runs'])} cases / {output}")
    return int(report['status']!='passed')

if __name__=='__main__':raise SystemExit(main())
