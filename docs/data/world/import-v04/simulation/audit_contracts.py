#!/usr/bin/env python3
"""Meaningful structural and counterfactual checks for the section migration."""
from collections import Counter
from copy import deepcopy
from pathlib import Path
import hashlib
import json

from simulate_world import ABILITIES, clauses, holds, load_model, states_from_trace

ROOT = Path(__file__).resolve().parents[1]


def main():
    canonical = ROOT / 'world-room-layout-v04.json'
    replay_path = ROOT / 'simulation/route-replays-v04.json'
    model = load_model(canonical)
    doc = json.loads(replay_path.read_text())
    replays = {r['id']: r for r in doc['replays']}
    checks = []

    def add(cid, passed, evidence):
        checks.append({'id': cid, 'passed': bool(passed), 'evidence': evidence})

    def tokens_in(req):
        return {token for clause in clauses(req) for token in clause}

    add('replays_match_current_canonical',
        doc['source_world_sha256'] == hashlib.sha256(canonical.read_bytes()).hexdigest(),
        {'world_sha256': doc['source_world_sha256']})
    bad_doors = [e['id'] for e in model.edges.values() if tokens_in(e.get('requires')) & set(ABILITIES)]
    add('physical_doors_do_not_check_HWDQ', not bad_doors,
        {'door_connections': len(model.edges), 'violations': bad_doors})
    add('every_action_binds_a_real_section', not model.warnings, model.warnings)
    add('all_rest_and_rift_sections_exist',
        all(loc in model.sections for loc in model.rest_locations | set(model.rift_locations)),
        {'rests': len(model.rest_locations), 'rifts': len(model.rift_locations)})
    unsupported = []
    for loc, section in model.sections.items():
        if section.get('kind') != 'entrance_preview':
            continue
        # An entrance preview has a normal door back to its approach. That
        # door may still have legitimate item/story requirements from entry.
        exits = [t for t in model.adj[loc] if t['kind'] == 'move'
                 and not tokens_in(t['requires']) & set(ABILITIES)]
        if not exits:
            unsupported.append({'room': loc[0], 'section': loc[1]})
    add('every_preview_has_a_physical_return_door', not unsupported,
        {'previews': sum(s.get('kind') == 'entrance_preview' for s in model.sections.values()),
         'without_return_door': unsupported,
         'scope': 'topological return path; landing/platform physics not simulated'})
    initial = model.initial()
    reach = model.search(initial)['locations']
    add('start_is_only_tutorial_before_actions', reach == {model.start_location},
        {'start': list(model.start_location), 'reachable': [list(x) for x in sorted(reach)]})
    for aid in ['tutorial_move', 'tutorial_shoot']:
        model.perform(model.actions[aid], initial)
    reach = model.search(initial)['locations']
    add('unfinished_tutorial_does_not_open_station', reach == {model.start_location},
        {'reachable': [list(x) for x in sorted(reach)]})
    model.perform(model.actions['tutorial_recoil'], initial)
    reach = model.search(initial)['rooms']
    add('tutorial_completion_leads_only_to_station_before_briefing',
        reach == {'P-R03', 'P-R01'}, {'reachable_rooms': sorted(reach)})
    station_path = model.search(initial, [('P-R01', 'main')])
    if station_path:
        model.traverse(initial, station_path)
    add('station_briefing_has_declared_receipt_arrival_is_not_rest',
        ('station_briefed' in initial.tokens) == ('station_briefing' in initial.done)
        and initial.last_rest is None and not initial.loadout_ready,
        {'location': list(initial.location), 'station_briefed': 'station_briefed' in initial.tokens,
         'briefing_receipt': 'station_briefing' in initial.done, 'last_rest': initial.last_rest,
         'note': 'Station introduction is a declared automatic_landmark action; it does not rest.'})
    add('all_four_planned_replays_succeed', len(replays) == 4 and all(r['success'] for r in replays.values()),
        [{'id': r['id'], 'success': r['success'], 'failure': r['failure']} for r in replays.values()])
    if not all(r['success'] for r in replays.values()):
        result = {'schema': 'world.section-contract-audit.v04', 'passed': False,
                  'checks': checks, 'check_count': len(checks),
                  'blocked': 'Fix replay failure before post-route checks.'}
        (ROOT / 'simulation/contract-audit-v04.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
        print('failed route checks; see contract-audit-v04.json')
        return
    events = {rid: [(event, deepcopy(state)) for event, state, _, _ in states_from_trace(model, replay)]
              for rid, replay in replays.items()}
    A = events['A_normal_w_first']
    B = events['B_normal_d_first']
    C = events['C_true_16_regions']
    D = events['D_all_unique_rewards']
    a = replays['A_normal_w_first']
    b = replays['B_normal_d_first']
    c = replays['C_true_16_regions']
    d = replays['D_all_unique_rewards']
    for replay in replays.values():
        approaches = replay['boss_approaches']
        add('actual_rest_section_before_every_boss_' + replay['id'],
            len(approaches) == len(replay['bosses_defeated']) and
            all(x['success'] and x['reentry_transitions'] <= 2 for x in approaches),
            {'bosses': len(replay['bosses_defeated']), 'rests': len(approaches),
             'maximum_door_crossings': max(x['reentry_transitions'] for x in approaches),
             'maximum_internal_routes': max(x['reentry_internal_routes'] for x in approaches),
             'scope': 'not a measured retry time or platform difficulty result'})
        active = set()
        invalid = []
        for event in replay['trace']:
            if event['kind'] == 'action':
                active.update(x for x in event.get('grants', []) if x.startswith('rift_'))
            if event['kind'] == 'teleport':
                locs = [(event['from'], event['from_section']), (event['to'], event['to_section'])]
                if not all(model.rift_locations.get(loc) in active for loc in locs):
                    invalid.append(event)
        add('teleports_use_actual_activated_sections_' + replay['id'], not invalid,
            {'teleports': replay['teleports'], 'invalid': invalid})
        used = Counter(event['action'] for event in replay['trace'] if event['kind'] == 'action'
                       and not model.actions[event['action']].get('repeat', False))
        duplicates = {key: count for key, count in used.items() if count > 1}
        add('unique_actions_never_repeat_' + replay['id'], not duplicates, {'duplicates': duplicates})
    add('normal_A_explores_twelve_main_regions', len(a['deep_regions']) == 12,
        {'discovered': a['discovered_regions'], 'deep': a['deep_regions'],
         'definition': 'explicit designated main-area locations, not merely entering a preview'})
    add('normal_B_explores_at_least_twelve_main_regions', len(b['deep_regions']) >= 12,
        {'discovered': b['discovered_regions'], 'deep': b['deep_regions']})
    add('true_route_explores_sixteen_main_regions', len(c['deep_regions']) == 16,
        {'discovered': c['discovered_regions'], 'deep': c['deep_regions']})
    clocks = sorted(t for t in c['tokens'] if t.startswith('clock_') and t not in ['clock_Z', 'clock_key'])
    records = sorted(t for t in c['tokens'] if t.startswith('record_'))
    add('true_route_repairs_fifteen_and_collects_sixteen_records', len(clocks) == 15 and len(records) == 16,
        {'local_clocks': clocks, 'records': records, 'bosses': len(c['bosses_defeated'])})
    add('normal_and_true_boss_witness_counts', len(a['bosses_defeated']) == 9 and len(c['bosses_defeated']) == 18,
        {'A': len(a['bosses_defeated']), 'B': len(b['bosses_defeated']), 'C': len(c['bosses_defeated']),
         'note': 'B optional boss choices may differ; no equalization of experience or attack ranks'})
    add('true_ending_has_no_prior_normal_ending_requirement',
        'ending_true' in c['tokens'] and 'ending_normal' not in c['tokens'],
        {'ending_tokens': [t for t in c['tokens'] if t.startswith('ending_')]})

    # Observe the real preview state before gaining the missing ability, then
    # inspect its routes without granting tokens or moving to an unreachable room.
    for cid, room, edge_id, absent in [
        ('forest_H_preview', 'F-R04', 'L03', 'H'),
        ('glacier_D_preview', 'I-R11', 'L08', 'D'),
        ('furnace_Q_preview', 'E-R12', 'C22', 'Q')]:
        edge = model.edges[edge_id]
        preview = (room, edge['a_section'] if edge['a'] == room else edge['b_section'])
        candidates = [(t, s) for t, s in A if s.location == preview and absent not in s.tokens]
        if not candidates:
            add(cid, False, {'reason': 'no real pre-ability preview in A', 'preview': list(preview)})
            continue
        event, state = candidates[0]
        model.allowed_regions = None
        reachable = model.search(state, allow_teleport=False)['locations']
        main_blocked = (room, 'main') not in reachable
        return_destinations = [t['to'] for t in model.adj[preview] if t['kind'] == 'move'
                               and holds(t['requires'], state.all_tokens(), state.inventory)]
        add(cid, main_blocked and bool(return_destinations),
            {'actual_trace_step': event['step'], 'preview': list(preview), 'missing_ability': absent,
             'main_reachable_without_it': not main_blocked,
             'legal_return_destinations': [list(x) for x in return_destinations]})
        misplaced = []
        for action in model.actions_by_room[room]:
            if action.get('section_id') != preview[1] and model.available(action, state):
                misplaced.append(action['id'])
        add(cid + '_does_not_grant_other_sections_interactions', not misplaced,
            {'invalid_actions': misplaced})

    # Check each ability was actually acquired without already owning itself.
    for ability in ABILITIES:
        aid = 'get_' + ability
        positions = [i for i, (t, _) in enumerate(A) if t.get('action') == aid]
        if not positions:
            add('obtain_' + ability + '_without_self_requirement', False, {'action': aid})
            continue
        index = positions[0]
        before = deepcopy(A[index - 1][1])
        action = model.actions[aid]
        add('obtain_' + ability + '_without_self_requirement',
            ability not in before.tokens and model.available(action, before),
            {'action': aid, 'before_location': list(before.location),
             'before_abilities': [a for a in ABILITIES if a in before.tokens],
             'interaction_section': action['section_id']})
    furnace_entries = [(t, s) for t, s in B if s.location in model.deep_locations['E']]
    first_event, first_state = furnace_entries[0]
    smith_step = next(t['step'] for t, _ in B if t.get('action') == 'rescue_smith')
    release_step = next(t['step'] for t, _ in B if t.get('action') == 'release_workshop')
    add('D_first_enters_furnace_with_HDQ_without_W',
        {'H', 'D', 'Q', 'smith'} <= first_state.tokens and 'W' not in first_state.tokens
        and release_step < smith_step < first_event['step'],
        {'first_deep_entry': first_event, 'release_step': release_step,
         'smith_step': smith_step, 'abilities': [a for a in ABILITIES if a in first_state.tokens]})
    before_first_E = None
    for index, (t, s) in enumerate(B):
        if t['kind'] == 'move' and model.rooms[s.room]['region'] == 'E':
            before_first_E = deepcopy(B[index - 1][1])
            break
    for removed in ['Q', 'smith']:
        state = deepcopy(before_first_E)
        state.tokens.discard(removed)
        model.allowed_regions = None
        reachable = model.search(state, allow_teleport=False)['locations']
        deep = sorted(reachable & model.deep_locations['E'])
        add('first_furnace_main_requires_' + removed, not deep,
            {'counterfactual_removed': removed, 'start': list(state.location),
             'reachable_furnace_deep_locations': [list(x) for x in deep],
             'scope': 'counterfactual based on actual pre-entry state; no new progress granted'})

    knight_after = next(deepcopy(s) for t, s in A if t.get('action') == 'defeat_K_KNIGHT')
    knight_after.tokens.discard('boss_K_KNIGHT_defeated')
    add('Q_pickup_cannot_skip_living_knight', not model.available(model.actions['get_Q'], knight_after),
        {'location': list(knight_after.location), 'knight_defeated': False})
    corridor = next(deepcopy(s) for t, s in A if t['kind'] in ['move', 'internal']
                    and s.location not in model.rest_locations and 'lamp' in s.tokens)
    add('loadout_change_requires_actual_bench_section',
        not model.available(model.actions['equip_lamp'], corridor),
        {'location': list(corridor.location), 'owned': 'lamp' in corridor.tokens})
    bench = next(deepcopy(s) for t, s in A if t.get('type') == 'rest' and 'lamp' in s.tokens)
    not_rested = deepcopy(bench)
    not_rested.loadout_ready = False
    add('bench_arrival_is_not_rest', not model.available(model.actions['equip_lamp'], not_rested),
        {'location': list(bench.location), 'loadout_ready': False})
    add('explicit_rest_permits_owned_tool_change', model.available(model.actions['equip_lamp'], bench),
        {'location': list(bench.location), 'loadout_ready': True})

    actions = [t for t in d['trace'] if t['kind'] == 'action']
    alloy_grants = sum(model.actions[t['action']].get('inventory_grants', {}).get('attack_alloy', 0) for t in actions)
    alloy_spend = [model.actions[t['action']]['consumes']['attack_alloy'] for t in actions
                   if model.actions[t['action']].get('consumes', {}).get('attack_alloy')]
    add('eight_attack_alloys_consumed_1_2_2_3',
        alloy_grants == 8 and alloy_spend == [1, 2, 2, 3] and d['inventory'].get('attack_alloy') == 0,
        {'grants': alloy_grants, 'spend_order': alloy_spend, 'remaining': d['inventory'].get('attack_alloy')})
    skill_grants = sum(model.actions[t['action']].get('inventory_grants', {}).get('skill_core', 0) for t in actions)
    skill_spend = sum(model.actions[t['action']].get('consumes', {}).get('skill_core', 0) for t in actions)
    add('two_shared_skill_cores_consumed',
        skill_grants == 2 and skill_spend == 2 and d['inventory'].get('skill_core') == 0,
        {'grants': skill_grants, 'spent': skill_spend, 'remaining': d['inventory'].get('skill_core')})
    parts = ['triple', 'laser', 'fan', 'boomerang', 'magnetic', 'singularity']
    add('six_branch_parts_forged',
        all('forge_' + part in d['unique_actions'] and d['inventory'].get('part_' + part) == 0 for part in parts),
        {'forge_actions': ['forge_' + part for part in parts]})
    add('forty_gears_collected_and_delivered',
        len([aid for aid in d['unique_actions'] if aid.startswith('pickup_TG')]) == 40
        and d['inventory'].get('delivered_gears') == 40 and d['inventory'].get('time_gear') == 0,
        {'collected': len([aid for aid in d['unique_actions'] if aid.startswith('pickup_TG')]),
         'delivered': d['inventory'].get('delivered_gears'), 'held': d['inventory'].get('time_gear')})
    first_delivery = next(i for i, (t, _) in enumerate(D) if t.get('action') == 'deliver_time_gears')
    before_delivery = deepcopy(D[first_delivery - 1][1])
    target_alloy = model.actions['pickup_ATK08']
    # State is already at the real delivery counter in the trace.
    add('ATK08_requires_delivery_not_inventory_only',
        before_delivery.inventory.get('time_gear', 0) >= 20 and not model.available(target_alloy, before_delivery),
        {'location': list(before_delivery.location), 'held': before_delivery.inventory.get('time_gear'),
         'delivered': before_delivery.inventory.get('delivered_gears', 0)})
    last = D[-1][1]
    model.allowed_regions = None
    reachable = model.search(last)
    add('endgame_can_reach_all_216_room_subjects', set(model.rooms) == reachable['subject_rooms'],
        {'subjects_reachable': len(reachable['subject_rooms']), 'total': len(model.rooms),
         'missing_subjects': sorted(set(model.rooms) - reachable['subject_rooms'])})
    add('all_twenty_two_bosses_have_actual_route_receipts', len(d['bosses_defeated']) == 22,
        {'bosses': d['bosses_defeated']})
    add('core_installation_consumes_items_keeps_receipt',
        all(key not in d['tokens'] for key in ['core_root', 'core_ice', 'core_ember'])
        and 'cores_installed' in d['tokens'],
        {'items': ['core_root', 'core_ice', 'core_ember'], 'installation_receipt': 'cores_installed' in d['tokens']})
    pre_god = next(deepcopy(s) for t, s in C if t.get('action') == 'defeat_Z_KING')
    pre_god.tokens.discard('record_V')
    god = model.actions['defeat_Z_DEITY']
    god_path = model.search(pre_god, [(god['room_id'], god['section_id'])], action=god)
    add('one_missing_record_blocks_true_boss_approach', god_path is None,
        {'removed': 'record_V', 'start': list(pre_god.location)})
    add('no_shop_purchase_or_free_inventory_assumed',
        not any(t.get('type') in ['shop_purchase', 'purchase'] for r in replays.values() for t in r['trace']),
        {'scope': '12 shop equipment placements/services exist; prices and purchases remain unmodelled.'})
    result = {'schema': 'world.section-contract-audit.v04',
              'source_world_sha256': hashlib.sha256(canonical.read_bytes()).hexdigest(),
              'source_replays_sha256': hashlib.sha256(replay_path.read_bytes()).hexdigest(),
              'passed': all(c['passed'] for c in checks), 'check_count': len(checks),
              'checks': checks,
              'verified': ['section-level door/internal-route progression', 'real-location interactions',
                           'planned ending witnesses', 'weapon material consumption',
                           '40 unique gears and actual hand-in', 'bench/rift access and receipts'],
              'not_simulated': ['Godot movement and collision', 'Q two-second timing', 'damage/death HP dynamics',
                                'actual Boss victories or enemy combat', 'human memory/visibility',
                                'shop prices and purchases', 'all equipment effect balance',
                                'full 50-equipment acquisition', 'measured travel or retry seconds']}
    (ROOT / 'simulation/contract-audit-v04.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'checks': len(checks), 'passed': sum(c['passed'] for c in checks),
                      'failed': [c['id'] for c in checks if not c['passed']]}, ensure_ascii=False))


if __name__ == '__main__':
    main()
