"""Current spider/real-charger local ecology: real input, bullets, policy, strict native exit."""
import argparse
import contextlib
import hashlib
import json
import math
import os
import subprocess
from pathlib import Path
import re
import time

from run_tests import run_engine
import level_formal

ROOT = Path(__file__).resolve().parent.parent


def validate(data):
    if data.get('failures') != 0 or data.get('assertions', 0) < 35:
        raise ValueError('Complete native assertions are required')
    expected = {'spider_stand_line', 'spider_live_bypass', 'spider_bullets',
                'spider_cancel_pause_epoch_inactive'}
    rows = data.get('cases', [])
    if len(rows) != len(expected) or {r.get('id') for r in rows} != expected:
        raise ValueError('Every independent golden/counterfactual is required')
    events = data.get('events', [])
    for target in ('forest_thread_spider',):
        hits = [e for e in events if e.get('kind') == 'policy_result'
                and e.get('target') == target and e.get('hp') == 0
                and str(e.get('source', '')).startswith('player_projectile:')]
        if not hits:
            raise ValueError(f'{target}: actual projectile lethal policy result missing')
    if not any(e.get('kind') == 'accepted_shot' and e.get('projectiles', 0) > 0 for e in events):
        raise ValueError('Actual accepted shot with a spawned projectile required')
    row = next(r for r in rows if r['id'] == 'spider_stand_line')
    if row['hp_before'] - row['hp_after'] != 1:
        raise ValueError('Occupied-line policy damage must occur once')
    if not any(e.get('kind') == 'policy_result' and e.get('target') == 'player'
               and ':thread:' in str(e.get('event_id', '')) for e in events):
        raise ValueError('Actual thread hazard policy event missing')
    controls = data.get('comparisons', [])
    expected_controls = {f'root_split/{version}/{strategy}'
                         for version in ('legacy',)
                         for strategy in ('bank_shoot', 'lower_wait', 'fixed_H')}
    expected_controls |= {f'woven_crown/depth/{strategy}' for strategy in
                          ('bank_shoot', 'wait_line', 'fixed_H', 'live_H')}
    if len(controls) != 7 or {row.get('id') for row in controls} != expected_controls:
        raise ValueError('All seven current spatial strategy controls required')
    frames = data.get('comparison_frames', [])
    for row in controls:
        observed = [frame for frame in frames if frame.get('comparison') == row['id']]
        if not observed or row.get('ticks', 0) <= 0:
            raise ValueError(f"{row['id']}: real frame observations missing")
        if not row.get('completed'):
            raise ValueError(f"{row['id']}: strategy did not complete; retain failed control")
        if row.get('requested_H') and not row.get('caught_expected_H_target'):
            raise ValueError(f"{row['id']}: expected real H target was not caught")
        if row.get('strategy') != 'bank_shoot' and not row.get('observed_preview'):
            raise ValueError(f"{row['id']}: strategy bypassed actual observation")
        if row.get('strategy') == 'live_H':
            validate_live_recoil(row, events)
    validate_stress(data)


def validate_live_recoil(row, events):
    before, after = row.get('recoil_before', {}), row.get('recoil_after', {})
    request_tick = row.get('recoil_request_tick', -1)
    shot = [e for e in events[row['event_start']:row['event_end']]
            if e.get('kind') == 'accepted_shot' and e.get('aim') == [-1, 0]
            and request_tick <= e.get('tick', -1) <= request_tick + 1
            and e.get('projectiles', 0) > 0]
    if not shot or before.get('H_state') != 'free' or before.get('grounded'):
        raise ValueError('Live H must actually fire a left projectile at first free airborne recovery')
    if after.get('shot_charges') != before.get('shot_charges', 0) - 1:
        raise ValueError('Actual H->R must consume one real air shot')
    if abs(before.get('stamina', 0) - after.get('stamina', 0) - before.get('shot_cost', -1)) > 1e-6:
        raise ValueError('Actual H->R must consume the real configured shot cost')
    if not row.get('upper_support_seen'):
        raise ValueError('Live H->R must actually reach the named main support')


def _initial_signature(row):
    frame = row['start']
    return {key: frame[key] for key in ('position', 'hp', 'stamina', 'shot_charges', 'actors')}


def validate_stress(data):
    rows = data.get('stress_controls', [])
    expected = {f'ablation/{phase}/{strategy}/{switch}'
                for phase in ('fresh', 'line_hold')
                for strategy in ('direct_walk', 'wait_line', 'fixed_H', 'live_H')
                for switch in ('on', 'off')}
    expected |= {'phase/travel_left', 'phase/travel_right', 'dead_lantern/fixed_H', 'low_resource/live_H'}
    if len(rows) != len(expected) or {row.get('id') for row in rows} != expected:
        raise ValueError('All twenty causal/phase/dead/low-resource controls required')
    events = data['events']
    frames = data['comparison_frames']
    by_id = {row['id']: row for row in rows}
    for row in rows:
        if not row.get('setup_ok') or not row.get('completed'):
            raise ValueError(f"{row['id']}: actual setup or legal completion failed")
        observed = [frame for frame in frames if frame.get('comparison') == row['id']]
        if not observed:
            raise ValueError(f"{row['id']}: no actual frame observations")
        if row.get('requested_H') and not row.get('caught_expected_H_target'):
            raise ValueError(f"{row['id']}: requested H missed its actual target")
        if row.get('strategy') == 'live_H':
            validate_live_recoil(row, events)
        if row.get('strategy') not in ('bank_shoot', 'direct_walk') and not row.get('observed_preview'):
            raise ValueError(f"{row['id']}: missing actual observed preview")
        suppressed = row.get('thread_suppressed', [])
        if not row['variant'].get('line_disabled') and suppressed:
            raise ValueError('Normal controls must never suppress damage')
        if any(e.get('source') != 'woven_thread_spider' or ':thread:' not in e.get('event_id', '')
               or e.get('target') != 'player' or e.get('amount') != row['primary_definition']['line_damage']
               for e in suppressed):
            raise ValueError('Ablation may suppress only this spider line, never body/other damage')
    for phase in ('fresh', 'line_hold'):
        for strategy in ('direct_walk', 'wait_line', 'fixed_H', 'live_H'):
            left, right = [by_id[f'ablation/{phase}/{strategy}/{switch}'] for switch in ('on', 'off')]
            if left['geometry_hash'] != right['geometry_hash'] or _initial_signature(left) != _initial_signature(right):
                raise ValueError('Causal line pairs need exactly matched geometry, entry, resources and actor states')
    for phase in ('travel_left', 'travel_right'):
        row = by_id[f'phase/{phase}']
        actor = next(a for a in row['setup_state']['actors'] if a['id'] == 'forest_lantern')
        if actor['state'] != 'travel':
            raise ValueError('Moving-anchor phase must be reached through actual travel')
    row = by_id['dead_lantern/fixed_H']
    actor = next(a for a in row['start']['actors'] if a['id'] == 'forest_lantern')
    prefix = events[row['setup_event_start']:row['event_start']]
    if actor['hp'] != 0 or not any(e.get('kind') == 'policy_result' and e.get('target') == 'woven_lantern'
                                  and e.get('hp') == 0 and str(e.get('source', '')).startswith('player_projectile:')
                                  for e in prefix):
        raise ValueError('Dead-anchor fallback needs real projectile death before the route')
    row = by_id['low_resource/live_H']
    cost = row['start']['shot_cost']
    if not cost <= row['start']['stamina'] <= 2 * cost:
        raise ValueError('Low-energy route must start with one or two configured shot costs')
    prefix = events[row['setup_event_start']:row['event_start']]
    if not any(e.get('kind') == 'accepted_shot' and e.get('aim') == [-1, 0] and e.get('projectiles', 0) > 0 for e in prefix):
        raise ValueError('Low-energy setup needs actual costly missed projectiles')
    if any(e.get('kind') == 'policy_result' for e in prefix):
        raise ValueError('Low-energy miss setup must not secretly hit/refund or damage the player')


def summarize_stress(data):
    rows = {row['id']: row for row in data['stress_controls']}
    effects = []
    for phase in ('fresh', 'line_hold'):
        for strategy in ('direct_walk', 'wait_line', 'fixed_H', 'live_H'):
            on, off = [rows[f'ablation/{phase}/{strategy}/{switch}'] for switch in ('on', 'off')]
            effects.append({'phase': phase, 'strategy': strategy,
                            'line_on': {'ticks': on['ticks'], 'hp': on['end']['hp'], 'stamina': on['end']['stamina']},
                            'line_off': {'ticks': off['ticks'], 'hp': off['end']['hp'], 'stamina': off['end']['stamina']},
                            'off_suppressed_requests': len(off['thread_suppressed'])})
    return {'scope': 'Actual local matched causal observations, not fun/formal pool acceptance',
            'pairs': effects, 'no_automatic_mechanic_acceptance': True}




FORMAL_STRATEGIES = ('live_H', 'shoot_clear', 'wait_phase', 'fixed_route_continue', 'stand_danger', 'entry_clear', 'entry_wait', 'entry_hold', 'west_clear', 'west_wait', 'west_jump')
LIFT_BASE_STRATEGIES = ('alive_lift', 'jump_two_R', 'fixed_return', 'dead_fixed_return')
LIFT_STRATEGIES = LIFT_BASE_STRATEGIES + ('dead_jump_two_R', 'left_phase_lift', 'low_air_recover_lift', 'lethal_contact_lift')

def validate_router_observation(data):
    queued_requests = [r for r in data.get('requests', []) if r.get('queued') is True]
    sequences = [r.get('router_sequence') for r in queued_requests]
    if not sequences or any(type(n) is not int for n in sequences) or any(a >= b for a, b in zip(sequences, sequences[1:])):
        raise ValueError('Actual Router submission identities must be present and strictly increasing')
    for request in queued_requests:
        if request.get('observation') != 'actual_router_queued_direction' or type(request.get('router_epoch')) is not int:
            raise ValueError('Real queued direction/type/epoch observation required')
        raw, canonical = request.get('raw_aim', []), request.get('aim', [])
        if len(raw) != 2 or len(canonical) != 2:
            raise ValueError('Raw and actual canonical directions must both remain available')
        length = (raw[0] ** 2 + raw[1] ** 2) ** .5
        expected = [v / length for v in raw] if length else [0, 0]
        if any(abs(a - b) > 1e-6 for a, b in zip(expected, canonical)):
            raise ValueError('Observed canonical aim must preserve the original requested direction')


def validate_formal_choice(data):
    from run_forest_depth_region import validate as validate_actual_route
    errors = validate_actual_route(data)
    if errors:
        raise ValueError('Actual DemoApp route rejected: ' + ', '.join(errors))
    validate_router_observation(data)
    strategy = data.get('ecology_strategy')
    if strategy not in FORMAL_STRATEGIES or not (0 < data.get('ecology_started', -1) < data.get('ecology_finished', -1)):
        raise ValueError('Actual crown encounter entry/exit required')
    manifest = data['manifest']
    contract = manifest.get('encounter_plan_contract', {})
    if contract.get('version') != 'compact-authored-ecology-v3' or contract.get('mix_consumed') is not True or contract.get('selected_mix') != manifest['choices']['enemy_mix']:
        raise ValueError('Actual recorded seed ecology recipe must be consumed')
    events = data['events']
    begin, end = data['ecology_started'], data['ecology_finished']
    observed = [e for e in events if begin <= e['tick'] <= end]
    primary = next(e['primary'] for e in observed if e.get('kind') == 'ecology_choice_started')
    if strategy in ('west_clear', 'west_wait', 'west_jump'):
        if data.get('map_index') != 2 or primary != 'hollow_route__west_seed_watch':
            raise ValueError('West comparison requires actual map2 west side-branch sentry')
        if data['ecology_entry']['health'] != data['ecology_exit']['health']:
            raise ValueError('West legal response must preserve real local HP without refill')
        arrivals = [e for e in observed if e.get('kind') == 'west_seed_actual_M_arrival']
        if len(arrivals) != 1 or not any(str(s).startswith('hollow__belly') for s in arrivals[0].get('supports', [])):
            raise ValueError('Actual original west gap and full supported M successor required')
        kills = [e for e in observed if e.get('kind') == 'committed_damage' and e.get('target') == primary and e.get('lethal') is True and not str(e.get('event_id','')).startswith('hook/')]
        if strategy == 'west_clear' and (len(kills) != 1 or not str(kills[0].get('source','')).startswith('player_projectile:')):
            raise ValueError('West clear requires actual ordinary projectile lethal, not ray assumption')
        if strategy == 'west_clear':
            bank = next((e for e in observed if e.get('kind') == 'west_seed_actual_outside_spawn_gun_bank'), None)
            started = next(e for e in observed if e.get('kind') == 'ecology_choice_started')
            spawn = manifest['spawn']
            shots = [e for e in observed if e.get('kind') == 'shot_fired']
            if bank is None or 'west_court' not in bank.get('supports', []) or started.get('actual_spawn') != spawn or not shots:
                raise ValueError('West clear must actually leave spawn and reach a physically supported gun bank')
            protected = started.get('protected_radius', -1)
            if protected <= 0 or any(((e['position'][0]-spawn[0])**2+(e['position'][1]-spawn[1])**2)**.5 <= protected for e in shots):
                raise ValueError('West clear must fire actual ordinary shots outside unchanged spawn protection')
        if strategy != 'west_clear' and kills:
            raise ValueError('West live route must preserve the actual sentry')
        if strategy == 'west_wait' and not any(e.get('kind') == 'ecology_actual_seed_zone' and e.get('source') == primary for e in observed):
            raise ValueError('West wait needs an actual unsuppressed landed seed zone outside spawn protection')
        if strategy == 'west_jump' and any(e.get('kind') in ('shot_fired','hook_cast') for e in observed):
            raise ValueError('Cheap west control must retain ordinary gap input without H/gun cost')
        return
    if strategy in ('entry_clear', 'entry_wait', 'entry_hold'):
        if data.get('route') != 'borer' or data.get('map_index') != 1 or primary != 'hollow_route__borer_entry_thread':
            raise ValueError('Entry line comparison must use the actual map1 M-to-S region prefix')
        arrivals = [e for e in observed if e.get('kind') == 'entry_thread_actual_S_arrival']
        if len(arrivals) != 1 or 'hollow__cavity_observe' not in arrivals[0].get('supports', []):
            raise ValueError('Actual shared S arrival and original full successor route are required')
        damage = [e for e in observed if e.get('kind') == 'committed_damage' and str(e.get('event_id', '')).startswith(primary + ':thread:')]
        before, after = data['ecology_entry']['health'], data['ecology_exit']['health']
        if strategy == 'entry_hold':
            if len(damage) != 1 or before - after != 1 or not any(e.get('kind') == 'entry_thread_actual_hold_observed' for e in observed):
                raise ValueError('Hold counterfactual needs actual physical thread damage once and a completed real recovery')
        elif damage or before != after:
            raise ValueError('Clear/wait line response must preserve actual HP without refill')
        if strategy == 'entry_wait':
            if not any(e.get('kind') == 'entry_thread_actual_hold_observed' for e in observed) or not any(e.get('kind') == 'entry_thread_actual_retraction_observed' for e in observed):
                raise ValueError('Wait must actually observe hold then retraction, not inject a phase')
        if strategy == 'entry_clear':
            kills = [e for e in observed if e.get('kind') == 'committed_damage' and e.get('target') == primary and e.get('lethal') is True and str(e.get('source','')).startswith('player_projectile:') and not str(e.get('event_id','')).startswith('hook/')]
            if len(kills) != 1:
                raise ValueError('Actual ordinary projectile kill is required before the supported access')
        elif any(e.get('kind') == 'committed_damage' and e.get('target') == primary for e in observed):
            raise ValueError('Live wait/hold line comparisons must leave the actual spider intact')
        return
    if strategy == 'fixed_route_continue':
        prefix = [e for e in events if e['tick'] < begin]
        if not any(e.get('kind') == 'hook_contact_kick' and e.get('target') == 'hollow__upper_window_ring' for e in prefix):
            raise ValueError('Fixed-route control must actually reach E through the existing fixed ring')
        if any(r.get('kind') == 'grapple' and begin <= r['tick'] <= end for r in data['requests']):
            raise ValueError('Fixed-route control must not add an artificial reverse hook or use the live anchor')
        for target in (primary, 'hollow_route__canopy_lantern'):
            if any(e.get('kind') == 'committed_damage' and e.get('target') == target and e.get('lethal') is True for e in observed):
                raise ValueError('Fixed-route control must preserve the actual pair alive')
    if strategy == 'live_H':
        kind = 'ecology_actual_live_arrival'
        arrivals = [e for e in observed if e.get('kind') == kind]
        if len(arrivals) != 1 or arrivals[0].get('enemy_id') != 'hollow_route__canopy_lantern':
            raise ValueError('Requested hook must actually arrive at its intended real target')
        r = [e for e in observed if e.get('kind') == 'ecology_first_free_R']
        if len(r) != 1 or r[0]['snapshot']['shots'] <= 0 or r[0].get('hook_state') != 'free' or r[0].get('grounded') is not False:
            raise ValueError('Actual airborne first-free R observation missing')
        free_frames = [f for f in data['frames'] if arrivals[0]['tick'] <= f['tick'] < r[0]['tick'] and f.get('hook_state') == 'free' and f.get('grounded') is False]
        if not free_frames or r[0]['tick'] != free_frames[0]['tick'] + 1:
            raise ValueError('R must be requested at the first input step after the actual free airborne Motor frame')
        shot = [e for e in observed if e.get('kind') == 'shot_fired' and e.get('aim') == [-1, 0] and r[0]['tick'] <= e['tick'] <= r[0]['tick'] + 1]
        if len(shot) != 1:
            raise ValueError('Real accepted left projectile after H required')
        by_tick = {f['tick']: f for f in data['frames']}
        after = by_tick[shot[0]['tick']]
        before = r[0]['snapshot']
        cost = float(r[0]['shot_cost'])
        if after['shots'] != before['shots'] - 1 or abs(before['energy'] - after['energy'] - cost) > .001:
            raise ValueError('Actual H-to-R shot/energy deduction does not match the real Definition')
    if strategy == 'shoot_clear':
        for target in (primary, 'hollow_route__canopy_lantern'):
            lethal = [e for e in observed if e.get('kind') == 'committed_damage' and e.get('target') == target and e.get('lethal') is True and str(e.get('source', '')).startswith('player_projectile:')]
            if len(lethal) != 1:
                raise ValueError('Both actual enemies must die to normal projectiles')
            event_id = str(lethal[0].get('event_id', '')).split(':')
            if len(event_id) != 3 or lethal[0]['source'] != 'player_projectile:' + event_id[0] or not any(e.get('kind') == 'shot_fired' and str(e.get('serial')) == event_id[-1] and e['tick'] < lethal[0]['tick'] for e in observed):
                raise ValueError('Lethal must bind an actual normal shot serial, not grapple damage mislabeled by the shared Policy source')
        if any(r.get('kind') == 'grapple' and begin <= r['tick'] <= end for r in data['requests']):
            raise ValueError('Shoot-clear must use normal shots without grapple damage')
    if strategy in ('wait_phase', 'stand_danger'):
        if not any(e.get('kind') == 'ecology_actual_preview' for e in observed) or not any(e.get('kind') == 'ecology_actual_danger_finished' for e in observed):
            raise ValueError('Wait must observe a real warning and real hazard completion')
    if strategy in ('wait_phase', 'stand_danger') and primary == 'hollow_route__outer_watch':
        if not any(e.get('kind') == 'ecology_actual_seed_zone' and e.get('source') == primary for e in observed):
            raise ValueError('A supported seed warning alone is not a danger: require an actual unsuppressed landed zone')
    if strategy == 'stand_danger' and not any(e.get('kind') == 'committed_damage' and e.get('target') == 'player' and e.get('source') == primary and e.get('amount', 0) > 0 for e in observed):
        raise ValueError('Counterexample requires actual configured line/seed Policy damage, not body contact')


def validate_lift_choice(data):
    from run_forest_depth_region import VERSION, expected_itinerary
    if data.get('failures') or data.get('scope') != 'actual_DemoApp_R_E_lift_candidate_not_admitted_route':
        raise ValueError('Actual bounded R-to-E candidate must finish without native route failures')
    manifest = data['manifest']
    if data.get('actual_stage_version') != VERSION or manifest.get('version') != VERSION or data.get('actual_stage_map') != data.get('map_index') or manifest.get('map_index') != data.get('map_index'):
        raise ValueError('Actual stage/Manifest version and map identity required')
    if manifest.get('seed') != f"{data.get('seed')}/thorn_forest/map_{data.get('map_index')}":
        raise ValueError('Actual seed identity required')
    if data.get('manual_motor_step') is not False or data.get('position_or_resource_injection') is not False or data.get('audio_released') is not True:
        raise ValueError('Normal actual Motor/resources and strict owner teardown required')
    frames, events = data['frames'], data['events']
    if not frames or any(f['tick'] != i + 1 or f['motor_steps'] != 1 for i, f in enumerate(frames)):
        raise ValueError('Every real continuous single-Motor frame required')
    validate_router_observation(data)
    for event in events:
        if event.get('kind') == 'shot_fired' and not any(r.get('kind') == 'shoot_release' and r.get('queued') is True and r['tick'] == event['tick'] and r['aim'] == event['aim'] for r in data['requests']):
            raise ValueError('Actual shot must bind its exact real Router submission')
    initial, final = data['initial_snapshot'], data['final_snapshot']
    if initial.get('hook_enabled') is not True or initial.get('double_enabled') is not False or initial.get('wall_enabled') is not False or initial.get('weapon') != 'pulse_gun' or initial.get('tier') != 1:
        raise ValueError('Actual H-only basic Pulse setup required')
    if any(final.get(k) != initial.get(k) for k in ('config', 'hook_enabled', 'double_enabled', 'wall_enabled', 'weapon', 'tier')) or final.get('health', 0) <= 0:
        raise ValueError('Runtime, abilities, weapon and living natural route must remain valid')
    actual = expected_itinerary(manifest, 'high_return')
    if data.get('lift_original_itinerary') != actual:
        raise ValueError('Natural common approach must use the actual generated high-return itinerary')
    prefix = data['lift_prefix']
    if not prefix or len(prefix) >= len(actual) or actual[len(prefix)].get('edge_id') != 'outer_to_inner':
        raise ValueError('Actual natural common prefix must end at R before its real return edge')
    if any(row['edge_id'] != actual[index]['edge_id'] or row['leg'] != index for index, row in enumerate(prefix)):
        raise ValueError('Natural R approach prefix cannot be skipped or renamed')
    begin, end = data.get('lift_started', -1), data.get('lift_finished', -1)
    entry, exit = data.get('lift_entry', {}), data.get('lift_exit', {})
    if not 0 < begin < end or entry.get('shots') != 2 or entry.get('health', 0) <= 0:
        raise ValueError('Actual normal same-R entry and bounded E arrival required')
    areas = {a['id']: a['position'] for a in manifest['areas']}
    for snapshot, goal, support in ((entry, areas['R'], 'hollow__outer_root'), (exit, areas['E'], 'hollow__outer_crown')):
        if abs(snapshot['position'][0] - goal[0]) > 7 or abs(snapshot['position'][1] - goal[1]) > 2 or support not in snapshot.get('supports', []):
            raise ValueError('Both actual same-terminal full-body supported ports required')
    arrival = [f for f in frames if end - 11 <= f['tick'] <= end]
    if len(arrival) != 12 or any('hollow__outer_crown' not in f['supports'] or not f['grounded'] or abs(f['position'][0] - areas['E'][0]) > 7 for f in arrival):
        raise ValueError('Twelve actual supported E endpoint frames required')
    row = next((r for r in manifest['enemies'] if r['id'] == 'hollow_route__outer_lift_lantern'), {})
    if row.get('position') != [1050, 680] or row.get('stable_id') != 'forest_lantern':
        raise ValueError('Only the actual new lower-lift placement is in scope')
    observed = [e for e in events if begin <= e['tick'] <= end]
    strategy = data.get('lift_strategy')
    if strategy not in LIFT_STRATEGIES:
        raise ValueError('Unknown actual lift strategy')
    _validate_lift_motion(data, row, entry, initial, frames, observed, begin, end, strategy)
    if strategy in ('fixed_return', 'dead_fixed_return'):
        if [r['edge_id'] for r in data['completed_legs'][len(prefix):]] != ['outer_to_inner', 'inner_recovery', 'upper_out']:
            raise ValueError('Existing full R-D-M-E return must really execute, not an invented staircase')
    if strategy == 'dead_fixed_return':
        lethal = [e for e in observed if e.get('kind') == 'committed_damage' and e.get('target') == row['id'] and e.get('lethal') is True and not str(e.get('event_id', '')).startswith('hook/')]
        selected = [e for e in observed if e.get('kind') == 'lift_existing_fixed_return_selected']
        if len(lethal) != 1 or len(selected) != 1 or lethal[0]['tick'] >= selected[0]['tick']:
            raise ValueError('Normal projectile death must precede the actual unchanged fixed return')


def _validate_lift_motion(data, row, entry, initial, frames, observed, begin, end, strategy):
    motion_begin = max(begin, data.get('lift_motion_started', begin))
    motion = [e for e in observed if e['tick'] >= motion_begin]
    shots = [e for e in motion if e.get('kind') == 'shot_fired']
    if strategy in ('alive_lift', 'left_phase_lift', 'low_air_recover_lift', 'lethal_contact_lift'):
        contacts = [e for e in observed if e.get('kind') == 'lift_actual_contact' and e.get('enemy_id') == row['id']]
        lethal_contact = strategy == 'lethal_contact_lift'
        hits = [e for e in observed if e.get('kind') == 'committed_damage' and e.get('target') == row['id'] and str(e.get('event_id', '')).startswith('hook/') and e.get('health_after') == (0 if lethal_contact else 1) and bool(e.get('lethal')) == lethal_contact]
        if len(contacts) != 1 or len(hits) != 1 or len(shots) != 1 or shots[0]['aim'] != [0, 1]:
            raise ValueError('Real moving contact, HP2-to-1 grapple Policy and one actual downward shot required')
        hit_frame = next(f for f in frames if f['tick'] == hits[0]['tick'])
        hook_parts = hits[0]['event_id'].split('/')
        config = data['lift_resource_config']
        packet = hook_parts[2] + '/hook/' + hook_parts[3]
        combat_gain = min(config['combat_target_gain'], config['combat_packet_limit'])
        if hit_frame.get('combat_hit_packets', {}).get(packet) != combat_gain:
            raise ValueError('Actual accepted grapple hit must bind the independent combat currency packet')
        launch = next((e for e in observed if e.get('kind') == 'lift_motion_started'), {})
        stamina_receipts = launch.get('shot_energy_hit_receipts') if lethal_contact else entry.get('shot_energy_hit_receipts')
        if hit_frame.get('shot_energy_hit_receipts') != stamina_receipts:
            raise ValueError('Grapple combat credit must not be mislabeled as a normal projectile stamina/round refund')
        first_free = next((f for f in frames if f['tick'] >= contacts[0]['tick'] and f['hook_state'] == 'free' and not f['grounded']), None)
        requests = [e for e in observed if e.get('kind') == 'lift_first_free_down_R_request']
        if first_free is None or len(requests) != 1 or requests[0]['tick'] != first_free['tick'] + 1 or shots[0]['tick'] != requests[0]['tick']:
            raise ValueError('Downward R must occur at the first actual free-air input step')
        after = next(f for f in frames if f['tick'] == shots[0]['tick'])
        before = requests[0]['snapshot']
        if after['shots'] != before['shots'] - 1 or abs(before['energy'] - after['energy'] - requests[0]['shot_cost']) > .001:
            raise ValueError('One real air round and configured stamina cost must be spent')
    if strategy == 'lethal_contact_lift':
        prime = [e for e in observed if e.get('kind') == 'committed_damage' and e.get('target') == row['id'] and e.get('health_after') == 1 and not e.get('lethal') and not str(e.get('event_id', '')).startswith('hook/')]
        setup = [e for e in observed if e.get('kind') == 'shot_fired' and e['tick'] < motion_begin]
        marker = [e for e in observed if e.get('kind') == 'lift_actual_projectile_prime_HP1']
        if len(prime) != 1 or len(setup) != 1 or len(marker) != 1 or not setup[0]['tick'] <= prime[0]['tick'] < motion_begin:
            raise ValueError('One real ordinary shot must prime actual HP2-to-1 before lethal H, without a second setup shot')
        parts = str(prime[0].get('event_id', '')).split(':')
        if len(parts) != 3 or int(parts[2]) != int(setup[0]['serial']) or prime[0].get('source') != 'player_projectile:' + parts[0]:
            raise ValueError('HP1 priming must bind the actual accepted ordinary projectile serial')
        prior = next(f for f in frames if f['tick'] == motion_begin-1)
        if not prior['grounded'] or 'hollow__outer_root' not in prior['supports'] or abs(prior['position'][0] - entry['position'][0]) > 7:
            raise ValueError('Primed H must naturally return to the same supported R bank')
    if strategy in ('jump_two_R', 'dead_jump_two_R'):
        if not 1 <= len(shots) <= 2 or any(e['aim'] != [0, 1] for e in shots) or any(e.get('kind') == 'hook_cast' for e in observed):
            raise ValueError('Strong ordinary control allows at most two down shots and no H')
        if not any(e.get('kind') == 'lift_normal_full_jump_apex' for e in observed):
            raise ValueError('Strong control must reach a genuine full-jump apex rather than an early short release')
    if strategy == 'dead_jump_two_R':
        lethal = [e for e in observed if e.get('kind') == 'committed_damage' and e.get('target') == row['id'] and e.get('lethal') is True and not str(e.get('event_id', '')).startswith('hook/')]
        if len(lethal) != 1 or lethal[0]['tick'] >= motion_begin:
            raise ValueError('Actual ordinary projectile death must precede the strong full-jump return')
        motion_event = next((e for e in observed if e.get('kind') == 'lift_motion_started'), None)
        if motion_event is None or 'hollow__outer_root' not in next(f for f in frames if f['tick'] == motion_begin-1)['supports']:
            raise ValueError('Dead strong return must naturally realign at the same R bank, without resource reset')
    if strategy == 'left_phase_lift':
        start = next((e for e in observed if e.get('kind') == 'lift_R_choice_started'), {})
        launch = next((e for e in observed if e.get('kind') == 'lift_motion_started'), {})
        if data.get('expedition_scope'):
            opposite = [e for e in observed if e.get('kind') == 'expedition_opposite_phase_observed']
            if len(opposite) != 1 or opposite[0].get('travel_side') != 1 or not begin < opposite[0]['tick'] < launch.get('tick', begin):
                raise ValueError('Expedition must actually observe an intervening rightward trip before its later left phase')
            travel = [next((actor for actor in frame['enemies'] if actor['id'] == row['id']), {})
                      for frame in frames if opposite[0]['tick'] <= frame['tick'] < launch['tick']]
            if not any(a.get('state') == b.get('state') == 'travel' and len(a.get('position', [])) == len(b.get('position', [])) == 2
                       and b['position'][0] > a['position'][0] for a, b in zip(travel, travel[1:])):
                raise ValueError('Actual frames must show rightward body motion, not only a phase label')
            if launch.get('travel_side') != -1 or launch.get('enemy_state') != 'travel' or launch.get('tick', begin) <= begin:
                raise ValueError('New expedition phase must wait for real leftward travel')
        elif start.get('travel_side') != 1 or launch.get('travel_side') != -1 or launch.get('enemy_state') != 'travel' or launch.get('tick', begin) <= begin:
            raise ValueError('Alternative phase must be reached by actual waiting for the opposite real movement, not injected time')
    if strategy == 'low_air_recover_lift':
        empty = data.get('lift_empty_tick', -1)
        restored = data.get('lift_floor_recovery_tick', -1)
        if not begin < empty < restored == motion_begin:
            raise ValueError('Low-air route must actually run out and naturally recover before selecting H')
        empty_frame = next(f for f in frames if f['tick'] == empty)
        if empty_frame['grounded'] or empty_frame['shots'] != 0:
            raise ValueError('The actual airborne empty-round state is required')
        before_motion = [e for e in observed if e['tick'] < motion_begin]
        setup_shots = [e for e in before_motion if e.get('kind') == 'shot_fired']
        if [e['aim'] for e in setup_shots] != [[-1, 0], [1, 0]] or any(e.get('kind') in ('committed_damage', 'actual_shot_energy_recovered') for e in before_motion):
            raise ValueError('Low-air setup must spend two actual enemy misses without secret hit/refund or damage')
        restored_event = next((e for e in before_motion + motion if e.get('kind') == 'lift_actual_ground_round_recovery'), {})
        if restored_event.get('snapshot', {}).get('shots') != initial['shots'] or 'hollow__outer_root' not in next(f for f in frames if f['tick'] == restored-1)['supports']:
            raise ValueError('The real R floor must restore the configured rounds before the live route')


def validate_expedition(data):
    from run_forest_depth_region import validate as validate_actual_route, expected_itinerary
    errors = validate_actual_route(data)
    if errors:
        raise ValueError('Complete actual expedition route rejected: ' + ', '.join(errors))
    expected_scope = 'actual_map2_lower_reward_then_optional_R_E_and_gate' if data.get('map_index') == 2 else 'actual_reward_camp_then_optional_R_E_and_gate'
    if data.get('expedition_scope') != expected_scope or data.get('route') != 'ecology_expedition':
        raise ValueError('Explicit complete expedition scope and actual manifest route required')
    validate_router_observation(data)
    if data.get('map_index') == 2:
        validate_map2_expedition(data)
        return
    m, frames, events = data['manifest'], data['frames'], data['events']
    if data.get('map_index') != 1 or m['choices']['skeleton'] != 1:
        raise ValueError('Only the actual shared-root map1 expedition is admitted here')
    full = expected_itinerary(m, 'ecology_expedition')
    prefix = expected_itinerary(m, 'high_return')
    if full[:len(prefix)] != prefix or data.get('expedition_prefix_count') != len(prefix):
        raise ValueError('Every original reward/camp route leg must remain unchanged before the optional extension')
    if len(full) <= len(prefix) + 2 or full[len(prefix)].get('edge_id') != 'camp_outer_back' or full[len(prefix)+1].get('edge_id') != 'outer_lift_return':
        raise ValueError('Real camp-to-R then optional R-to-E then actual gate tail required')
    optional = full[len(prefix)+1]
    if optional.get('kind') != 'hollow_live_return' or optional.get('a') != 'R' or optional.get('b') != 'E' or optional.get('optional') is not True or optional.get('enemy_id') != 'hollow_route__outer_lift_lantern':
        raise ValueError('Optional edge cannot be forged or relabeled from an old R-D return')
    completed = data['completed_legs']
    camp_row = completed[len(prefix)-1]
    if data.get('expedition_camp_tick') != camp_row['tick'] or data.get('expedition_started_leg') != len(prefix)+1:
        raise ValueError('Real supported camp checkpoint must precede the second R visit')
    marker = [e for e in events if e.get('kind') == 'expedition_reward_return_complete']
    if len(marker) != 1 or marker[0]['tick'] != camp_row['tick'] or data.get('cache_claimed') is not True or data.get('duplicate_checked') is not True:
        raise ValueError('Actual claim/modal/return checkpoint required, not the first spawn R shortcut')
    if len(data.get('pointer_events', [])) != 2 or data.get('duplicate_before') != data.get('duplicate_after'):
        raise ValueError('Actual pointer claim and repeated interaction must remain intact')
    if data.get('gate_saved_open') is not True or data.get('gate_shape_disabled') is not True or full[-1].get('kind') != 'gate_hook':
        raise ValueError('Complete actual gate objective after E is required; local E truncation rejected')
    begin, end = data.get('lift_started', -1), data.get('lift_finished', -1)
    entry, exit = data.get('lift_entry', {}), data.get('lift_exit', {})
    if not camp_row['tick'] < begin < end < frames[-1]['tick']:
        raise ValueError('Reward return, new choice, E and final destination must occur in real order')
    if data.get('lift_prefix') != completed[:len(prefix)+1] or completed[len(prefix)+1]['tick'] != end:
        raise ValueError('New choice must follow the complete real prefix and end its real optional leg')
    areas = {a['id']: a['position'] for a in m['areas']}
    for snap, goal, support in ((entry, areas['R'], 'hollow__outer_root'), (exit, areas['E'], 'hollow__outer_crown')):
        if len(snap.get('position', [])) != 2 or abs(snap['position'][0]-goal[0]) > 7 or abs(snap['position'][1]-goal[1]) > 2 or support not in snap.get('supports', []):
            raise ValueError('Actual supported R and E terminals required')
    arrival = [f for f in frames if end-11 <= f['tick'] <= end]
    if len(arrival) != 12 or any('hollow__outer_crown' not in f['supports'] or not f['grounded'] for f in arrival):
        raise ValueError('Actual twelve-frame E support required before continuing')
    if any('wallet_balance' not in f or 'meta_notes' not in f or 'item_ids' not in f or 'combat_hit_packets' not in f for f in frames):
        raise ValueError('Read-only whole-route wallet/build/combat resource observations required')
    row = next((r for r in m['enemies'] if r['id'] == optional['enemy_id']), {})
    if row.get('position') != [1050, 680] or row.get('stable_id') != 'forest_lantern':
        raise ValueError('Actual lower moving actor identity required')
    strategy = data.get('lift_strategy')
    if strategy not in ('alive_lift', 'jump_two_R', 'left_phase_lift', 'low_air_recover_lift'):
        raise ValueError('Unsupported expedition strategy')
    if data.get('expedition_fallback') is not False:
        raise ValueError('Dead-anchor fallback may complete gameplay but cannot establish the requested live strategy')
    observed = [e for e in events if begin <= e['tick'] <= end]
    _validate_lift_motion(data, row, entry, data['initial_snapshot'], frames, observed, begin, end, strategy)
    if not observed or data.get('lift_original_itinerary') != full:
        raise ValueError('The original full manifest itinerary must not be truncated or rewritten')


def validate_map2_expedition(data):
    """The actual lower-cache return reaches R before camp; do not invent a loop."""
    from run_forest_depth_region import expected_itinerary
    m, frames, events = data['manifest'], data['frames'], data['events']
    choices = m.get('choices', {})
    if m.get('map_index') != 2 or any(choices.get(k) != 0 for k in ('skeleton', 'cache_route', 'cavity_direction')):
        raise ValueError('Actual map2 outer reward family required')
    full = expected_itinerary(m, 'ecology_expedition')
    original = expected_itinerary(m, 'high_return')
    exits = [i for i, leg in enumerate(original) if leg['edge_id'] == 'reward_other_exit']
    if len(exits) != 1:
        raise ValueError('Unique original lower reward exit required')
    prefix = original[:exits[0]+1]
    n = len(prefix)
    if full[:n] != prefix or len(full) <= n+1 or data.get('expedition_prefix_count') != n:
        raise ValueError('Every original arrival/reward/return leg through R must remain unchanged')
    optional = full[n]
    if (optional.get('edge_id') != 'outer_lift_return' or optional.get('kind') != 'hollow_live_return'
            or optional.get('a') != 'R' or optional.get('b') != 'E' or optional.get('optional') is not True
            or optional.get('enemy_id') != 'hollow_route__outer_lift_lantern'):
        raise ValueError('Actual optional R-to-E edge identity required')
    if any(leg['edge_id'] == 'camp_outer_back' for leg in prefix) or data.get('expedition_camp_tick') != -1:
        raise ValueError('Map2 natural lower reward route must not fabricate a mandatory camp loop')
    completed = data['completed_legs']
    row = completed[n-1]
    markers = [e for e in events if e['kind'] == 'expedition_reward_R_complete']
    if (data.get('expedition_reward_R_tick') != row['tick'] or len(markers) != 1
            or markers[0]['tick'] != row['tick'] or markers[0].get('actual_edge') != 'reward_other_exit'
            or data.get('expedition_started_leg') != n or row['edge_id'] != 'reward_other_exit'):
        raise ValueError('Real claimed reward then supported natural R checkpoint required')
    if (data.get('cache_claimed') is not True or data.get('duplicate_checked') is not True
            or len(data.get('pointer_events', [])) != 2 or data.get('duplicate_before') != data.get('duplicate_after')):
        raise ValueError('Actual pointer claim, modal and duplicate transaction must remain intact')
    areas = {a['id']: a['position'] for a in m['areas']}
    checkpoint = data.get('expedition_reward_R', {})
    window = [f for f in frames if row['tick']-11 <= f['tick'] <= row['tick']]
    if (len(window) != 12 or 'hollow__outer_root' not in checkpoint.get('supports', [])
            or checkpoint.get('health', 0) <= 0 or any(not f['grounded'] or 'hollow__outer_root' not in f['supports']
            or abs(f['position'][0]-areas['R'][0]) > 7 for f in window)):
        raise ValueError('Original reward exit must finish on twelve actual R support frames')
    previous = next((f for f in frames if f['tick'] == row['tick']-1), None)
    if (previous is None or len(checkpoint.get('position', [])) != 2 or markers[0].get('snapshot') != checkpoint
            or any(checkpoint.get(k) != previous[k] for k in ('health', 'energy', 'shots', 'wallet_balance', 'meta_notes', 'item_ids', 'claimed_ids'))
            or any(abs(a-b)>.001 for a,b in zip(checkpoint.get('position', []), previous['position']))):
        raise ValueError('Reward/R checkpoint must bind its real pre-Motor frame and transaction state')
    begin, end = data.get('lift_started', -1), data.get('lift_finished', -1)
    if not row['tick'] < begin < end < frames[-1]['tick'] or completed[n]['tick'] != end:
        raise ValueError('Reward, R choice, E and complete final gate must occur in actual order')
    if data.get('lift_prefix') != completed[:n] or data.get('lift_original_itinerary') != full:
        raise ValueError('Actual complete original itinerary and whole prefix cannot be truncated')
    if not data.get('gate_saved_open') or not data.get('gate_shape_disabled') or full[-1].get('kind') != 'gate_hook':
        raise ValueError('Only the actual accepted key can finish the real gate objective')
    entry, exit = data['lift_entry'], data['lift_exit']
    for snap, goal, support in ((entry, areas['R'], 'hollow__outer_root'), (exit, areas['E'], 'hollow__outer_crown')):
        if (len(snap.get('position', [])) != 2 or abs(snap['position'][0]-goal[0]) > 7
                or abs(snap['position'][1]-goal[1]) > 2 or support not in snap.get('supports', [])):
            raise ValueError('Actual same supported R and E endpoints required')
    arrival = [f for f in frames if end-11 <= f['tick'] <= end]
    if len(arrival) != 12 or any(not f['grounded'] or 'hollow__outer_crown' not in f['supports'] for f in arrival):
        raise ValueError('Actual twelve full E support frames required')
    required = ('wallet_balance', 'meta_notes', 'item_ids', 'combat_hit_packets', 'claimed_ids')
    if any(any(k not in f for k in required) for f in frames):
        raise ValueError('Read-only full-route wallet/build/claims/combat observations required')
    actor = next((r for r in m['enemies'] if r['id'] == optional['enemy_id']), {})
    if actor.get('position') != [1050, 680] or actor.get('stable_id') != 'forest_lantern':
        raise ValueError('Actual original lower live actor identity required')
    strategy = data.get('lift_strategy')
    if strategy not in ('alive_lift', 'jump_two_R') or data.get('expedition_fallback') is not False:
        raise ValueError('Only requested actual live/strong-two-R comparison admitted here')
    observed = [e for e in events if begin <= e['tick'] <= end]
    _validate_lift_motion(data, actor, entry, data['initial_snapshot'], frames, observed, begin, end, strategy)
    validate_crown_return(data, n+1)


def validate_crown_return(data, index):
    """The ordinary recoil crosslink must really bypass the D/M/S loop."""
    full = data['itinerary']
    leg = full[index]
    contract = data.get('crown_return_contract', {})
    m, frames, events = data['manifest'], data['frames'], data['events']
    areas = {a['id']:a['position'] for a in m['areas']}
    if (leg.get('kind') != 'ecology_return' or leg.get('role') != 'crown_reverse_return'
            or leg.get('a') != 'E' or leg.get('b') != 'C' or leg.get('edge_id') != 'crown_reverse_return'
            or contract.get('leg') != index or contract.get('edge_id') != leg['edge_id']
            or contract.get('from_support_id') != leg.get('from_support_id')
            or contract.get('landing_support_id') != leg.get('landing_support_id')):
        raise ValueError('Actual optional E-to-C side return identity required')
    if any(x.get('edge_id') in ('lower_in','inner_recovery','belly_borer_access','borer_crossing') for x in full[index+1:]):
        raise ValueError('The claimed return must not secretly descend D then repeat the original cavity')
    start, end = data.get('crown_return_started', -1), data.get('crown_return_finished', -1)
    if not data['lift_finished'] < start < end < frames[-1]['tick'] or data['completed_legs'][index]['tick'] != end:
        raise ValueError('Supported E, real side/ordinary return, C and gate must complete in actual order')
    entry, exit = data.get('crown_return_entry', {}), data.get('crown_return_exit', {})
    for snap, point, support in ((entry,areas['E'],'hollow__outer_crown'),(exit,areas['C'],'hollow__cavity_exit')):
        if (len(snap.get('position',[])) != 2 or math.dist(snap['position'],point)>8
                or support not in snap.get('supports',[]) or snap.get('health',0)<=0):
            raise ValueError('Actual full E and C terminal snapshots required')
    prefix_end = data['completed_legs'][index-1]['tick']
    window = [f for f in frames if prefix_end-11<=f['tick']<=prefix_end]
    branch = [f for f in frames if start<=f['tick']<=end]
    if (len(window)!=12 or any(not f['grounded'] or 'hollow__outer_crown' not in f['supports'] for f in window)
            or len(branch)<12 or any(not f['grounded'] or 'hollow__cavity_exit' not in f['supports'] for f in branch[-12:])
            or any(f.get('crown_return_actor_epoch') != contract.get('actor_epoch') for f in branch)):
        raise ValueError('Actual twelve-frame E/C supports and stable actor epoch required')
    observed = [e for e in events if start<=e['tick']<=end]
    shots = [e for e in observed if e['kind']=='shot_fired']
    requests = [e for e in observed if e['kind']=='crown_return_R_request']
    mode = data.get('crown_return_strategy')
    maximum = 2 if mode=='direct_two_R' else 1
    if mode not in ('direct_one_R','direct_two_R') or not 1<=len(shots)<=maximum or len(requests)!=len(shots):
        raise ValueError('Real declared one/two-shot return strategy required')
    by = {f['tick']:f for f in frames}
    for event, request in zip(shots, requests):
        if event['tick'] != request['tick'] or math.dist(event['aim'], request['aim'])>.0001:
            raise ValueError('Every recoil must bind its actual accepted Router shot')
        f=by[event['tick']];before=request['snapshot']
        if f['shots'] != before['shots']-1 or abs(before['energy']-f['energy']-request['shot_cost'])>.001 or request['shot_cost'] != data['lift_resource_config']['shot_cost']:
            raise ValueError('Each actual air shot and normal energy cost must be accounted before any later real hit refund')
    hs = [e for e in observed if e['kind']=='hook_cast']
    if hs or any(e['aim']!=[0,1] for e in shots):
        raise ValueError('The strong ordinary ascent must use zero H and only real downward recoil')
    apex = [e for e in observed if e['kind']=='crown_return_ordinary_real_apex']
    if len(apex)!=1 or apex[0]['tick']!=shots[0]['tick'] or by[shots[0]['tick']-1]['crown_return_normal_velocity'][1]<0:
        raise ValueError('Ordinary recoil must follow the true full-jump apex, not a weakened short jump')



def validate_crossbranch(data):
    """Candidate injection is explicit. This first gate proves NPC motion, not reward admission."""
    if data.get('failures') or data.get('position_or_resource_injection') is not False or data.get('audio_released') is not True:
        raise ValueError('Crossbranch actual driver/native/cleanup failure')
    c=data.get('candidate_overlay',{})
    formal=data.get('crossbranch_formal') is True
    if data.get('ecology_strategy')=='crossbranch_lifecycle':
        checks=data.get('lifecycle',[])
        required={'real_flight_save_entry','real_menu_pause_freezes_actor','real_App_rebinds_recorded_actor','actual_App_reload_preserves_midair_phase_velocity_HP','restored_actor_resumes_real_motion','real_App_cancel_retains_physical_velocity','cancel_lands_on_real_support_and_resumes_cycle','actual_ordinary_projectile_death','dead_App_actor_rebind','dead_Actor_reload_never_restarts_migration'}
        if not formal or c.get('scope')!='actual_generated_crossbranch_contract' or not checks or any(r.get('passed') is not True for r in checks) or not required.issubset({r.get('check') for r in checks}) or len([r for r in checks if r.get('check','').startswith('atomic_reject_')])!=16:
            raise ValueError('Complete actual App reload/pause/cancel/ordinary death and atomic malformed record rejection required')
        saved=next(r['facts'] for r in checks if r['check']=='actual_App_reload_preserves_midair_phase_velocity_HP')
        if saved['saved']['depth_state']!=saved['actual'] or saved['saved']['position']!=saved['position']:
            raise ValueError('Actual saved and restored airborne pose/velocity/phase must match exactly')
        damage=next(r['facts']['damage'] for r in checks if r['check']=='actual_ordinary_projectile_death')
        if len(damage)!=3 or any(r['amount']!=1 or not r['source'].startswith('player_projectile:') for r in damage) or [r['health'] for r in damage]!=[2,1,0] or damage[-1]['lethal'] is not True:
            raise ValueError('Three real committed ordinary projectile hits must own the actual death')
        return
    if formal:
        contract=data['manifest'].get('crossbranch_contract',{})
        actors=[r for r in data['manifest']['enemies'] if r['id']==contract.get('enemy_id')]
        if c.get('scope')!='actual_generated_crossbranch_contract' or len(actors)!=1 or actors[0].get('behavior_id')!='forest_crossbranch' or actors[0].get('shore_rows')!=contract.get('shore_rows') or c.get('actor_id')!=contract.get('enemy_id'):
            raise ValueError('One actual generated migration placement/shore contract required')
    if (not formal and c.get('scope')!='candidate_data_overlay_after_actual_DemoApp_generation_not_formal_generator_admission') or any(c.get(k) is not False for k in ('player_reset','resource_injection','enemy_phase_reset')):
        raise ValueError('Candidate custody must preserve actual App/actor and declare geometry overlay')
    frames=data['frames']
    if not frames or any(f['tick']!=i+1 or f['motor_steps']!=1 for i,f in enumerate(frames)):
        raise ValueError('Continuous real PlayerMotor observations required')
    if data.get('ecology_strategy')!='crossbranch_physics':
        contact=c.get('actual_contact',{})
        half=[v/2+1 for v in c.get('actual_definition',{}).get('body',[])]
        if contact.get('source_id')!=str(c.get('actor_id'))+'_contact' or contact.get('registered_in_App') is not True or contact.get('half_size')!=half or contact.get('amount')!=1 or contact.get('interval')!=.7 or contact.get('kind')!=0:
            raise ValueError('Current complete combat consumer requires the exact normal DemoApp contact binding; archived missing-contact runs retain only historical motion scope')
    if data.get('ecology_strategy')=='crossbranch_contact_recovery':
        contact=c.get('actual_contact',{})
        hits=[e for e in data['events'] if e['kind']=='committed_damage' and e.get('target')=='player' and e.get('source')==contact['source_id'] and e.get('damage_kind')==0 and e.get('amount')==1]
        blocks=[e for e in data['candidate_NPC_ledger'] if e['event']=='blocked' and e.get('collision',{}).get('player') is True]
        recovered=[e for e in data['candidate_NPC_ledger'] if e['event']=='recovered_static_support']
        complete=[e for e in data['events'] if e['kind']=='candidate_actual_component_recovery_complete']
        if not hits or not blocks or len(recovered)!=1 or len(complete)!=1 or data['final_snapshot']['health']>=data['initial_snapshot']['health'] or any(e['event']=='recovery_budget_failed' for e in data['candidate_NPC_ledger']):
            raise ValueError('Real Player contact damage, actual Player obstruction and bounded recovery required')
        support=recovered[0]['support'];rect=support.get('rect',[]);pos=recovered[0]['position'];body=c['actual_definition']['body']
        budget=c['actual_definition'].get('recovery_budget_seconds',0)
        if not 0<budget or support.get('static') is not True or support.get('not_player') is not True or len(support.get('feet',[]))!=3 or not support.get('support_ids') or len(rect)!=4 or pos[0]-body[0]/2<rect[0]-.01 or pos[0]+body[0]/2>rect[0]+rect[2]+.01 or abs(pos[1]+body[1]/2-rect[1])>1 or recovered[0]['elapsed']>budget:
            raise ValueError('Actual non-Player static full-body recovery support required')
        recorded=[p for p in data['manifest']['platforms'] if p['id'] in support['support_ids'] and p['rect']==rect]
        feet=support['feet'];xs=[pos[0]-body[0]/2+.5,pos[0],pos[0]+body[0]/2-.5]
        if len(recorded)!=1 or any(len(foot)!=2 or abs(foot[0]-x)>.1 or abs(foot[1]-rect[1])>1 for foot,x in zip(feet,xs)):
            raise ValueError('All three real foot rays must bind the recorded static body rectangle')
        moves=[e for e in data['candidate_NPC_ledger'] if e['event']=='recovery_move']
        inward=[e for e in moves if e['part']=='supported_inward_step']
        hz=json.loads((ROOT/'config/player_tuning.json').read_text())['physics_hz']
        if not inward or [e['elapsed'] for e in moves]!=sorted(e['elapsed'] for e in moves) or any(abs(e['requested'][0])>c['actual_definition']['return_speed']/hz+.001 or e['requested'][1]!=0 for e in inward):
            raise ValueError('Partial support recovery must use bounded physical inward steps without resetting the clock')
        for stamp in sorted({e['physics_frame'] for e in moves}):
            group=[e for e in moves if e['physics_frame']==stamp]
            observed=[f for f in frames if f['crossbranch']['physics_frame']==stamp]
            if not observed or any(a['to']!=b['from'] for a,b in zip(group,group[1:])):
                raise ValueError('Both real recovery move segments must retain continuous actual positions')
            actor=next(e for e in observed[0]['enemies'] if e['id']=='candidate__crossbranch')
            if math.dist(actor['position'],group[-1]['to'])>.001:
                raise ValueError('Recovery move totals must match the same actual physics-frame NPC position')
        recovery_frames=[f for f in frames if f['crossbranch']['physics_frame']>=recovered[0]['physics_frame']][:12]
        if len(recovery_frames)!=12:raise ValueError('Twelve actual frames after recovery required')
        for f in recovery_frames:
            actor=next((e for e in f['enemies'] if e['id']=='candidate__crossbranch'),{})
            if actor.get('state') not in ('settle','rest','grounded_recovery') or actor.get('depth_state',{}).get('recovery_support')!=support or actor.get('depth_state',{}).get('recovery_budget_failed') is not False:
                raise ValueError('Recovered NPC must retain actual support for twelve real Motor frames')
        lands=[e for e in data['candidate_NPC_ledger'] if e['event']=='land']
        if len(lands)!=2 or [e['shore'] for e in lands]!=[1,0] or not all(next(e for e in f['enemies'] if e['id']=='candidate__crossbranch')['state']=='rest' for f in frames[-12:]):
            raise ValueError('Recovery on an authored shore must resume its actual physical outward and return cycle')
        return
    if data.get('ecology_strategy')!='crossbranch_physics':
        # Reuse all existing actual body/itinerary/claim/modal/real-gate checks.
        # Only the vocabulary field is adapted in this local validation view;
        # raw provenance remains explicitly candidate, never formal admission.
        import run_forest_depth_region as region
        view=dict(data, scope='formal_DemoApp_forest_v2_continuous_route_not_boss_fight')
        errors=region.validate(view)
        if errors:raise ValueError('Candidate complete actual route rejected: '+', '.join(errors))
        mode=data['ecology_strategy']
        if mode in ('crossbranch_live_H','crossbranch_live_coyote_H'):
            heads=[e for e in data['events'] if e['kind']=='candidate_migrant_H_request']
            contacts=[e for e in data['events'] if e['kind']=='candidate_actual_migrant_body_contact']
            recoils=[e for e in data['events'] if e['kind']=='candidate_first_actual_free_R']
            if len(heads)!=1 or len(contacts)!=1 or len(recoils)!=1 or not heads[0]['tick']<contacts[0]['tick']<recoils[0]['tick']:
                raise ValueError('Actual moving target H/body/free-R sequence required')
            if mode=='crossbranch_live_coyote_H':
                actual_heads=[e for e in data['events'] if e['kind']=='candidate_actual_migrant_head_contact']
                actual_kicks=[e for e in data['events'] if e['kind']=='candidate_actual_migrant_kick']
                if len(actual_heads)!=1 or len(actual_kicks)!=1 or not heads[0]['tick']<actual_heads[0]['tick']<contacts[0]['tick']<actual_kicks[0]['tick']<recoils[0]['tick'] or any(e.get('latched_kick_side')!=-1 or e['hook_start'][0]>=actual_heads[0]['hook_tip'][0] for e in actual_heads+actual_kicks):
                    raise ValueError('Actual fixed-origin head contact must latch and retain left kick')
                kick_tick=actual_kicks[0]['tick'];by={f['tick']:f for f in frames}
                declared=re.search(r'(?m)^hook_kick\s*=\s*Vector2\(([-\d.]+),', (ROOT/'resources/player/traversal.tres').read_text())
                if declared is None:raise ValueError('Actual declared kick speed required')
                speed=float(declared.group(1));hz=json.loads((ROOT/'config/player_tuning.json').read_text())['physics_hz']
                if kick_tick not in by or kick_tick-1 not in by or abs(by[kick_tick]['velocity'][0]+speed)>.1 or abs(by[kick_tick]['position'][0]-by[kick_tick-1]['position'][0]+speed/hz)>.2:
                    raise ValueError('Actual Motor step must execute the latched left kick')
        else:
            out_leg=next((i for i,r in enumerate(data['itinerary']) if r.get('kind')=='crossbranch_crossing'),2)
            leg_events=[e for e in data['events'] if e['leg']==out_leg]
            if any(e['kind']=='hook_cast' for e in leg_events):
                raise ValueError('Ordinary candidate strategy cannot secretly borrow an H')
            air=[e for e in leg_events if e['kind']=='candidate_actual_ordinary_apex_R']
            if not air or any(e.get('velocity',[0,-1])[1]<0 for e in air):
                raise ValueError('Strong ordinary must shoot at actual full-jump/recoil apex')
            if mode=='crossbranch_ordinary_one_R':
                first=[e for e in air if e['budget']==1]
                if len(first)!=1 or first[0]['ordinal']!=1:
                    raise ValueError('Actual strongest direct one-R attempt required before any recovery')
                if data.get('candidate_one_R_failed') is True and not any(e['kind']=='candidate_one_R_actual_failure_landed_recovery' for e in leg_events):
                    raise ValueError('One-R failure must actually land in the preserved recovery geometry')
            elif len(air)!=2:
                raise ValueError('Declared two-R ascent must use exactly two actual air shots')
            if mode=='crossbranch_ordinary_safe_two_R':
                clears=[e for e in leg_events if e['kind']=='candidate_actual_vertical_body_clear']
                projections=[e for e in leg_events if e['kind']=='candidate_two_R_joint_projection']
                if len(clears)!=1 or len(projections)!=1 or not clears[0]['tick']<air[0]['tick']<air[1]['tick'] or clears[0]['player_bottom']>=clears[0]['NPC_top']-1:
                    raise ValueError('Strong ordinary must be allowed to jump clear of the rest NPC before moving across it')
            if mode in ('crossbranch_shoot_then_two_R','crossbranch_dead_lower_two_R'):
                death=[e for e in leg_events if e['kind']=='committed_damage' and e['target']=='candidate__crossbranch' and e['lethal']]
                if len(death)!=1 or death[0]['tick']>=air[0]['tick']:
                    raise ValueError('Enemy must die from actual accepted damage before the ordinary dead-anchor ascent')
        if not any(e['kind']=='candidate_actual_reward_return_W' for e in data['events']):
            raise ValueError('Actual alternate W return and same cache required')
        return
    lands=[r for r in data.get('candidate_NPC_ledger',[]) if r['event']=='land']
    if len(lands)<2 or lands[0]['shore']!=1 or lands[1]['shore']!=0:
        raise ValueError('Actual physical round trip on both branches required')
    ends=[[-350,252],[76,452]]
    if any(math.dist(r['position'],p)>2 for r,p in zip(lands,ends)):
        raise ValueError('No reset or cosmetic endpoint arrival')
    states=[f.get('crossbranch',{}).get('NPC',{}).get('state') for f in frames]
    if 'flight' not in states or 'settle' not in states or 'blocked' in states:
        raise ValueError('Real flight/support states required without obstruction fallback')
    camera=[c for c in data.get('candidate_camera',[]) if c.get('near_reward_edge_visible') and c.get('npc_visible')]
    if not camera:
        raise ValueError('Actual unchanged-zoom view must show destination shore and moving body')
    if any(c.get('zoom')!=[1.6,1.6] for c in camera):
        # Godot float representation may be serialized as 1.6000000238.
        if any(max(abs(v-1.6) for v in c['zoom'])>1e-6 for c in camera):
            raise ValueError('Candidate must not change camera zoom')
    if data.get('cache_claimed'):
        raise ValueError('NPC first gate cannot claim complete reward route admission')


def validate_root_entry(data):
    """Actual R spawn phase, not a reward-return expedition or data-only case."""
    import run_forest_depth_region as region
    errors=region.validate(data)
    if errors:raise ValueError('Actual base route rejected: '+','.join(errors))
    validate_router_observation(data)
    m=data['manifest'];frames=data['frames'];events=data['events'];completed=data['completed_legs']
    current_layout=re.search(r'const LAYOUT_VERSION := "([^"]+)"',(region.ROOT/'scripts/generation/thorn_forest_region_v2.gd').read_text()).group(1)
    if (data.get('root_entry_scope')!='actual_R_spawn_then_live_R_E_ordinary_E_C_gate_not_reward_expedition'
            or data.get('route')!='crown_entry' or data.get('map_index')!=2 or m.get('layout_version')!=current_layout
            or m['choices'].get('root_entry') is not True or m.get('entry_contract',{}).get('selected')!='R'
            or m.get('spawn')!=[1020,882] or m.get('entry_contract',{}).get('alternate_route')!='crown_entry'):
        raise ValueError('True actual source-bound R spawn/alternate identity required')
    if data.get('expedition_scope') or data.get('cache_claimed') or data.get('duplicate_checked') or data.get('pointer_events') or data.get('modal_frames') or data.get('claimed_ids'):
        raise ValueError('This new root-entry mode must not claim a reward/camp expedition prefix')
    full=region.expected_itinerary(m,'crown_entry');ids=['arrival_reading','outer_lift_return','crown_reverse_return','cavity_prep','crown_approach']
    if [r.get('edge_id')for r in full]!=ids or data['itinerary']!=full or [r['edge_id']for r in completed]!=ids:
        raise ValueError('Whole actual root-entry graph, all five legs required')
    if full[0].get('a')!='arrival' or full[0].get('b')!='R' or full[0].get('path')!=[[1020,882],[1020,882]]:
        raise ValueError('Actual arrival must be R-to-R, never privileged relocation or R-to-W walk')
    platforms={p['id']:p['rect']for p in m['platforms']};rect=platforms['hollow__outer_root']
    def support(frame,point,sid):
        r=platforms[sid];x,y=frame['position']
        return frame.get('grounded') is True and sid in frame.get('supports',[]) and abs(x-point[0])<=7 and abs(y-point[1])<=2 and x-12>=r[0]-.1 and x+12<=r[0]+r[2]+.1 and abs(y+18-r[1])<1
    end_spawn=completed[0]['tick'];spawnframes=[f for f in frames if 1<=f['tick']<=end_spawn]
    if end_spawn!=12 or len(spawnframes)!=12 or any(not support(f,m['spawn'],'hollow__outer_root')for f in spawnframes):
        raise ValueError('True first twelve full-body R spawn support frames required')
    if math.dist(data['initial_snapshot']['position'],m['spawn'])>2:raise ValueError('Initial actual actor snapshot must be at Manifest spawn')
    for actor in m['enemies']:
        sweep=actor.get('authored_body_sweep',[])
        if len(sweep)!=4:raise ValueError('Every spawn enemy must expose actual full body sweep')
        near=[max(sweep[0],min(1020,sweep[0]+sweep[2])),max(sweep[1],min(882,sweep[1]+sweep[3]))]
        if math.dist(near,m['spawn'])<150:raise ValueError('Actual authored spawn body exclusion violated')
    markers=[e for e in events if e['kind']=='root_entry_actual_R_spawn_supported']
    snap=data.get('root_entry_snapshot',{});previous=frames[end_spawn-2]
    if (data.get('root_entry_ready_tick')!=12 or len(markers)!=1 or markers[0]['tick']!=12
            or markers[0].get('actual_spawn')!=m['spawn'] or markers[0].get('snapshot')!=snap or markers[0].get('completed_prefix')!=[]
            or snap.get('supports')!=previous.get('supports') or math.dist(snap.get('position',[]),previous['position'])>.001
            or any(snap.get(k)!=previous[k]for k in ('health','energy','shots'))):
        raise ValueError('Actual spawn marker must bind its pre-Motor body/resources, not a label')
    begin,end=data.get('lift_started',-1),data.get('lift_finished',-1)
    if begin!=13 or not begin<end<frames[-1]['tick'] or completed[1]['tick']!=end or data.get('lift_prefix')!=completed[:1] or data.get('lift_original_itinerary')!=full:
        raise ValueError('Live lift must directly follow actual spawn in the unchanged full Manifest route')
    optional=full[1]
    if optional.get('kind')!='hollow_live_return' or optional.get('a')!='R' or optional.get('b')!='E' or optional.get('optional')is not True or optional.get('enemy_id')!='hollow_route__outer_lift_lantern':
        raise ValueError('Actual optional living R-to-E graph leg required')
    actor=next((a for a in m['enemies']if a['id']==optional['enemy_id']),{})
    if actor.get('position')!=[1050,680] or actor.get('stable_id')!='forest_lantern' or data.get('lift_strategy')!='alive_lift':
        raise ValueError('Only single requested actual original live-actor strategy in scope')
    entry=data['lift_entry'];exit=data['lift_exit']
    if (not support(frames[end-1],[980,558],'hollow__outer_crown') or any(not support(f,[980,558],'hollow__outer_crown')for f in frames[end-12:end])
            or math.dist(entry['position'],[1020,882])>2 or entry.get('shots')!=2 or 'hollow__outer_root'not in entry.get('supports',[]) or math.dist(exit['position'],[980,558])>2):
        raise ValueError('Unchanged actual R entry and twelve full-body E supports required')
    observed=[e for e in events if begin<=e['tick']<=end]
    _validate_lift_motion(data,actor,entry,data['initial_snapshot'],frames,observed,begin,end,'alive_lift')
    validate_crown_return(data,2)
    key=m['vine_gate']['key_anchor']
    if (data.get('gate_saved_open')is not True or data.get('gate_shape_disabled')is not True
            or not any(e['kind']=='hook_contact_kick'and e.get('target')==key for e in events)):
        raise ValueError('Actual key contact and persistent physical gate opening required')
    required=('wallet_balance','meta_notes','item_ids','claimed_ids','combat_hit_packets')
    if any(any(k not in f for k in required)for f in frames):raise ValueError('Full unchanged phase/transaction observations required')
    if any(f['wallet_balance']!=frames[0]['wallet_balance']or f['meta_notes']!=frames[0]['meta_notes']or f['item_ids']!=frames[0]['item_ids']or f['claimed_ids']for f in frames):
        raise ValueError('Root-entry alternate cannot acquire or invent expedition rewards')
    return {'frames':len(frames),'spawn_support_tick':12,'lift_started':begin,'lift_finished':end,'crown_return_finished':data['crown_return_finished'],'min_health':min(f['health']for f in frames),'final_health':data['final_snapshot']['health'],'route':'crown_entry','scope':data['root_entry_scope']}


def run_formal_choices(out, args, receipt):
    rows = []
    is_root_entry = args.scenario == 'root_entry'
    is_expedition = args.scenario == 'expedition'
    is_lift = args.scenario in ('lift', 'expedition', 'root_entry')
    receipt[getattr(args, 'receipt_key', 'root_entry_runs' if is_root_entry else 'lift_runs' if is_lift else 'formal_runs')] = rows
    strategies = ['alive_lift'] if is_root_entry else ['crossbranch_'+s for s in args.crossbranch_strategies] if args.scenario == 'crossbranch' else args.expedition_strategies if is_expedition else (args.lift_strategies if is_lift else args.formal_strategies)
    common_R = None
    common_entry = None
    common_E = {}
    returns = ['direct_one_R'] if is_root_entry else args.expedition_return_strategies if is_expedition and args.map==2 else ['original']
    cases = [(strategy, return_strategy) for strategy in strategies for return_strategy in returns]
    for index, (strategy, return_strategy) in enumerate(cases):
        suffix = '-'+return_strategy if return_strategy!='original' else ''
        folder = out / f'{index:02d}-{strategy}{suffix}'
        folder.mkdir()
        argv = ['--headless', '--fixed-fps', '60', '--path', '.', '--script',
                'tests/forest_depth_lift_runner.gd' if is_lift else 'tests/forest_depth_ecology_runner.gd', '--', f'--seed={args.seed}',
                f'--map={args.map}', ('--route=crown_entry' if is_root_entry else '--route=ecology_expedition' if is_expedition else '--route=high_return') if is_lift else f'--route={args.formal_route}', f'--strategy={strategy}',
                f'--output=res://{folder.relative_to(ROOT)}/capture.json'] + (['--root-entry'] if is_root_entry else ['--expedition'] if is_expedition else [])
        if is_root_entry or (is_expedition and args.map==2):
            argv.append('--return-strategy='+return_strategy)
        movie = bool(getattr(args, 'formal_movie', False))
        if movie:
            argv = ['--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy',
                    '--write-movie', str(folder / 'gameplay.avi')] + argv[1:] + ['--capture-movie']
        row = {'strategy': strategy, 'return_strategy': return_strategy, 'argv': argv, 'timeout_seconds': 240, 'passed': False}
        rows.append(row)
        start = time.monotonic()
        try:
            if movie:
                import run_forest_depth_region as region
                with region.movie_display(dict(os.environ), folder, True) as env:
                    with (folder / 'native.log').open('w') as log:
                        result = subprocess.run(['bash', 'tools/godot.sh', *argv], cwd=ROOT,
                                                env=env, stdout=log, stderr=subprocess.STDOUT, timeout=240)
                text = (folder / 'native.log').read_text()
                if result.returncode or region.ERRORS.search(text) or 'OpenGL API' not in text:
                    raise ValueError('Actual GL native movie failed strict exit/context guard')
            else:
                with (folder / 'native.log').open('w') as log, contextlib.redirect_stdout(log):
                    text = run_engine(argv, 240)
            if not re.search(r'FOREST DEPTH ROUTE: .* / 0 failures', text):
                raise ValueError('Formal actual route terminal result absent')
            data = json.loads((folder / 'capture.json').read_text())
            if is_root_entry:
                import run_forest_depth_region as region
                if region.ERRORS.search(text): raise ValueError('Strict root-entry engine exit error')
                row['root_entry_actual'] = validate_root_entry(data)
                row['capture_sha256'] = hashlib.sha256((folder / 'capture.json').read_bytes()).hexdigest()
                row['native_log_sha256'] = hashlib.sha256((folder / 'native.log').read_bytes()).hexdigest()
            else:
                (validate_crossbranch if args.scenario=='crossbranch' else validate_expedition if is_expedition else (validate_lift_choice if is_lift else validate_formal_choice))(data)
            if movie:
                row['movie'] = region.inspect_movie(folder / 'gameplay.avi', data)
                if row['movie']['errors']:
                    raise ValueError('Actual movie timeline rejected: ' + ', '.join(row['movie']['errors']))
            if is_lift:
                signature = {'entry': data['lift_entry'], 'frames': [{k: f[k] for k in ('position', 'health', 'energy', 'shots', 'enemies')} for f in data['frames'] if f['tick'] < data['lift_started']]}
                if is_expedition and args.map == 2:
                    signature['requests'] = [r for r in data['requests'] if r['tick'] < data['lift_started']]
                    signature['full_route_resources'] = [{k:f[k] for k in ('wallet_balance','meta_notes','item_ids','claimed_ids','combat_hit_packets')} for f in data['frames'] if f['tick'] < data['lift_started']]
                if common_R is None:
                    common_R = signature
                elif signature != common_R:
                    raise ValueError('Lift strategies must share the exact natural approach, same R resources and actual enemy phases')
                row['common_R_prefix_sha256'] = hashlib.sha256(json.dumps(signature, sort_keys=True).encode()).hexdigest()
                if is_expedition and args.map==2:
                    E_signature = {'entry':data['crown_return_entry'], 'frames':[{k:f[k] for k in ('position','health','energy','shots','enemies','wallet_balance','meta_notes','item_ids','claimed_ids','combat_hit_packets')} for f in data['frames'] if f['tick']<data['crown_return_started']], 'requests':[r for r in data['requests'] if r['tick']<data['crown_return_started']]}
                    if strategy not in common_E: common_E[strategy]=E_signature
                    elif common_E[strategy]!=E_signature: raise ValueError('Side H and strongest ordinary return must share the entire actual E prefix, resources and enemy phase')
                    row['common_E_prefix_sha256']=hashlib.sha256(json.dumps(E_signature,sort_keys=True).encode()).hexdigest()
            if not is_lift and strategy.startswith(('entry_', 'west_')):
                signature = {'entry': data['ecology_entry'], 'frames': [{k: f[k] for k in ('position', 'health', 'energy', 'shots', 'enemies')} for f in data['frames'] if f['tick'] < data['ecology_started']]}
                if common_entry is None:
                    common_entry = signature
                elif signature != common_entry:
                    raise ValueError('Entry strategies must share the exact actual M prefix/resources/enemy phase')
                row['common_entry_prefix_sha256'] = hashlib.sha256(json.dumps(signature, sort_keys=True).encode()).hexdigest()
            if args.scenario=='crossbranch' and strategy not in ('crossbranch_physics','crossbranch_contact_recovery','crossbranch_lifecycle'):
                signature={'entry':data['ecology_entry'],'frames':[{k:f[k] for k in ('position','health','energy','shots','enemies')} for f in data['frames'] if f['tick']<data['ecology_started']], 'requests':[r for r in data['requests'] if r['tick']<data['ecology_started']]}
                if common_entry is None:common_entry=signature
                elif common_entry!=signature:raise ValueError('Candidate strategies must share the exact natural W-to-N approach, actual resources and NPC phase')
                row['common_N_prefix_sha256']=hashlib.sha256(json.dumps(signature,sort_keys=True).encode()).hexdigest()
            if data.get('crossbranch_formal') is True:receipt['scope']='Actual generated crossbranch optional exploration and existing App lifecycle; no candidate geometry injection or efficiency claim'
            row.update(passed=True, frames=len(data['frames']), recipe=data['manifest']['encounter_plan_contract'],
                       entry=data['lift_entry' if is_lift else 'ecology_entry'], exit=data['lift_exit' if is_lift else 'ecology_exit'],
                       ticks=data['lift_finished' if is_lift else 'ecology_finished']-data['lift_started' if is_lift else 'ecology_started'])
        finally:
            row['elapsed_seconds'] = time.monotonic()-start
    receipt['passed'] = True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output-dir', default='build/forest_depth/ecology/native')
    parser.add_argument('--scenario', choices=('golden', 'formal', 'lift', 'expedition', 'crossbranch', 'root_entry'), default='golden')
    parser.add_argument('--crossbranch-strategies', nargs='+', choices=('physics','contact_recovery','live_H','live_coyote_H','ordinary_one_R','ordinary_two_R','ordinary_safe_two_R','shoot_then_two_R','dead_lower_two_R','lifecycle'), default=['physics'])
    parser.add_argument('--include-map2-expedition', action='store_true', help='Append actual map2 lower reward return live/two-R controls to the original map1 expedition')
    parser.add_argument('--formal-movie', action='store_true', help='Record one complete actual formal trace at normal 60fps with the existing region movie guards')
    parser.add_argument('--seed', default=None)
    parser.add_argument('--map', type=int, choices=(1, 2), default=1)
    parser.add_argument('--formal-route', choices=('fast', 'growth', 'borer'), default='fast')
    parser.add_argument('--formal-strategies', nargs='+', choices=FORMAL_STRATEGIES, default=['wait_phase', 'stand_danger'])
    parser.add_argument('--lift-strategies', nargs='+', choices=LIFT_STRATEGIES, default=list(LIFT_BASE_STRATEGIES))
    parser.add_argument('--expedition-strategies', nargs='+', choices=('alive_lift', 'jump_two_R', 'left_phase_lift', 'low_air_recover_lift'), default=['alive_lift'])
    parser.add_argument('--expedition-return-strategies', nargs='+', choices=('direct_two_R','direct_one_R'), default=['direct_one_R'])
    args = parser.parse_args()
    if args.scenario == 'root_entry' and args.map != 2:
        parser.error('--scenario root_entry requires --map 2 and an actual generated R-entry seed')
    if args.include_map2_expedition and (args.scenario != 'expedition' or args.map != 1):
        parser.error('--include-map2-expedition requires the original map1 --scenario expedition')
    if args.formal_movie and (args.scenario not in ('formal', 'expedition', 'crossbranch') or args.include_map2_expedition or len(args.crossbranch_strategies if args.scenario=='crossbranch' else args.expedition_strategies if args.scenario == 'expedition' else args.formal_strategies) != 1 or (args.scenario=='expedition' and args.map==2 and len(args.expedition_return_strategies)!=1)):
        parser.error('--formal-movie requires exactly one formal or expedition strategy')
    if args.seed is None:
        args.seed = 'forest-depth-hollow-08' if args.scenario == 'root_entry' else 'forest-depth-hollow-02' if args.scenario == 'expedition' else 'forest-depth-hollow-00'
    out = (ROOT / args.output_dir).resolve()
    if not out.is_relative_to((ROOT / 'build/forest_depth/ecology').resolve()):
        parser.error('output must be under build/forest_depth/ecology')
    if out.exists() and any(out.iterdir()):
        parser.error('fresh output directory required')
    out.mkdir(parents=True, exist_ok=True)
    before = level_formal.source_files()
    verifier = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in (Path(__file__).resolve(), ROOT / 'tests/forest_depth_enemy_runner.gd', ROOT / 'tests/forest_depth_ecology_trace.gd', ROOT / 'tests/forest_depth_ecology_runner.gd', ROOT / 'tests/forest_depth_lift_trace.gd', ROOT / 'tests/forest_depth_lift_runner.gd', ROOT / 'tests/forest_depth_region_trace.gd', ROOT / 'tools/run_forest_depth_region.py')}
    receipt = {'scope': 'Local actors, four spider actor cases, seven spatial controls and twenty causal/phase/dead/low-resource controls; rejected badger prototype retired. Mechanics value remains subject to actual comparison; not formal forest admission',
               'source_before': before, 'verifier_before': verifier, 'passed': False}
    if args.scenario in ('formal', 'lift', 'expedition', 'crossbranch', 'root_entry'):
        receipt['scope'] = 'Actual DemoApp seed recipe crown pair, natural route entry and fixed/live/kill/wait/damage controls; not whole forest admission'
    if args.scenario == 'crossbranch':
        # A requested strategy does not establish provenance. Only captured
        # actual manifest/actor validation can establish generated vs overlay.
        receipt['scope'] = 'Crossbranch DemoApp consumer requested; generated placement or historical candidate overlay provenance is pending captured Manifest validation; no mechanism or full-region admission'
    if args.scenario == 'lift':
        receipt['scope'] = 'Actual generated DemoApp R-to-E live lift vs strongest full-jump/two-R and original fixed return, including natural projectile death; not an admitted topology edge'
    if args.scenario == 'root_entry':
        receipt['scope'] = 'Actual generated R spawn, first twelve full-body supports, natural living R-to-E, ordinary one-R E-to-C and physical gate; no reward/camp expedition or Boss-fight claim'
    if args.scenario == 'expedition':
        receipt['scope'] = 'Complete actual map2 lower reward then natural R-to-E and real gate, without mandatory camp loop' if args.map == 2 else 'Complete actual reward/high_return, camp, optional R-to-E lift and real gate objective; no local truncation or altered manifest'
    if args.include_map2_expedition:
        receipt['scope'] += '; appended actual map2 lower-reward-to-R live/two-R return to the real gate, without an invented camp detour'
        receipt['included_map2_expedition'] = True
    receipt['scenario'] = args.scenario
    started = time.monotonic()
    try:
        # The public check must work from a clean checkout, not an author's
        # separately imported snapshot. Native gameplay keeps its original cap.
        with (out / 'import.log').open('w') as log, contextlib.redirect_stdout(log):
            imported = run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
        if re.search(r'(^|\n)(?:SCRIPT )?ERROR:', imported):
            raise RuntimeError('Unexpected native import ERROR')
        if args.scenario in ('formal', 'lift', 'expedition', 'crossbranch', 'root_entry'):
            run_formal_choices(out, args, receipt)
            if args.include_map2_expedition:
                receipt['passed'] = False
                other = argparse.Namespace(**vars(args))
                other.map = 2
                other.seed = 'forest-depth-hollow-02'
                other.expedition_strategies = ['alive_lift', 'jump_two_R']
                other.receipt_key = 'map2_expedition_runs'
                folder = out / 'map2_expedition'
                folder.mkdir()
                run_formal_choices(folder, other, receipt)
            if args.scenario == 'root_entry':
                print('PASS: actual R root entry live lift ordinary crown return and gate')
            else:
                print('PASS: actual DemoApp ecology choices, strict exit')
            return
        with (out / 'native.log').open('w') as log, contextlib.redirect_stdout(log):
            text = run_engine(['--headless', '--fixed-fps', '60', '--path', '.', '--script',
                               'tests/forest_depth_enemy_runner.gd', '--',
                               f'--output-dir=res://{out.relative_to(ROOT)}'], 180)
        if not re.search(r'^FOREST DEPTH ENEMIES: [1-9]\d* assertions, 0 failures$', text, re.M):
            raise RuntimeError('Native completion missing')
        if re.search(r'(^|\n)(?:SCRIPT )?ERROR:', text):
            raise RuntimeError('Unexpected engine ERROR')
        data = json.loads((out / 'capture.json').read_text())
        validate(data)
        (out / 'stress-summary.json').write_text(json.dumps(summarize_stress(data), indent=2) + '\n')
        receipt['passed'] = True
    finally:
        receipt['source_after'] = level_formal.source_files()
        receipt['source_guard'] = before == receipt['source_after']
        receipt['verifier_after'] = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
                                     for path in verifier}
        receipt['elapsed_seconds'] = time.monotonic() - started
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        if not receipt['source_guard'] or verifier != receipt['verifier_after']:
            raise RuntimeError('Source changed during native capture')
    print('PASS: local forest depth enemies, actual bullets/policy and strict exit')


if __name__ == '__main__':
    main()
