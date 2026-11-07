#!/usr/bin/env python3
"""Report room-section route evidence; keep logical reachability and purchases separate."""
from __future__ import annotations

from collections import Counter, defaultdict, deque
from copy import deepcopy
from pathlib import Path
import hashlib
import json

from simulate_world import ROOT, WORLD, ROUTES, holds, load_model, states_from_trace


def location(event):
    if event['kind'] in ('move', 'internal', 'teleport'):
        return event['to'], event.get('to_section', 'main')
    return event.get('room'), event.get('section', 'main')


def memory_evidence(model, replay):
    trace = replay['trace']
    seen = {v['transition_id']: v for v in replay['observed_locks']}
    unlocked = {v['transition_id']: v for v in replay['revisit_opportunities']}
    rows = []
    for marker in model.world.get('memory_gates', []):
        preview = marker['preview_room'], marker.get('preview_section_id', 'main')
        ir = marker.get('internal_route_id')
        candidates = ['internal:' + ir] if ir else [
            t['id'] for t in model.transitions.values()
            if t['public_id'] == marker['edge_id'] and t['from'] == preview]
        tid = next((i for i in candidates if i in seen), candidates[0] if candidates else None)
        observation, unlock = seen.get(tid), unlocked.get(tid)
        row = {'marker': marker['id'], 'landmark': marker['landmark'],
               'preview_room': preview[0], 'preview_section': preview[1],
               'transition_id': tid, 'reward_action': marker.get('reward_action'),
               'seen_locked': observation is not None, 'complete_return_chain': False}
        if not observation:
            row['status'] = 'not_observed_locked_on_this_route'
            rows.append(row)
            continue
        first = observation['first_seen_step']
        row['first_seen_step'] = first
        if not unlock:
            row['status'] = 'seen_but_not_unlocked_on_this_route'
            rows.append(row)
            continue
        us, crossed = unlock['unlocked_at_step'], unlock['first_used_after_unlock']
        departures = [e for e in trace[first + 1:us + 1]
                      if e['kind'] in ('move', 'teleport') and
                      e.get('from') == preview[0] and e.get('to') != preview[0]]
        return_events = [e for e in trace[us + 1:]
                         if e['kind'] in ('move', 'internal', 'teleport') and location(e) == preview]
        reward = next((e for e in trace if e.get('action') == marker.get('reward_action')
                       and crossed is not None and e['step'] > crossed), None)
        complete = bool(departures and location(trace[us]) != preview and return_events
                        and crossed is not None and return_events[0]['step'] <= crossed and reward)
        row.update({'unlock_step': us, 'unlock_action': unlock['unlock_action'],
                    'unlock_location': list(location(trace[us])),
                    'left_preview_room_before_unlock_step': departures[0]['step'] if departures else None,
                    'return_to_preview_step': return_events[0]['step'] if return_events else None,
                    'cross_after_unlock_step': crossed,
                    'reward_claim_step': reward['step'] if reward else None,
                    'complete_return_chain': complete,
                    'status': 'observed_left_unlocked_returned_crossed_rewarded' if complete
                              else 'partial_or_same_visit_unlock_chain'})
        rows.append(row)
    return rows


def reachable_branch_objectives(model, state, first_door, max_doors=6):
    """Fixed actual equipment/state, no rifts/future rewards. Stop at live arenas."""
    origin = state.location
    start = first_door['to']
    distances = {start: 1}
    q = deque([start])
    goals = {}
    interesting = {'ability', 'weapon', 'regional_clock', 'story_key', 'boss_defeat',
                   'attack_alloy', 'skill_core', 'branch_material', 'npc'}
    while q:
        loc = q.popleft()
        distance = distances[loc]
        probe = deepcopy(state)
        probe.room, probe.section = loc
        for action in model.actions_by_location[loc]:
            if action.get('type') in interesting and model.available(action, probe):
                goals[action['id']] = {'kind': action.get('type'), 'room': loc[0],
                                       'section': loc[1], 'door_distance': distance}
        region = model.rooms[loc[0]]['region']
        if region not in state.deep_regions and loc in model.deep_locations[region]:
            goals['explore_main_' + region] = {'kind': 'new_region_main', 'room': loc[0],
                                              'section': loc[1], 'door_distance': distance}
        boss = model.boss_locations.get(loc)
        if boss and boss['defeat_token'] not in state.tokens:
            continue
        for tr in model.adj[loc]:
            dst = tr['to']
            if dst == origin or not holds(tr['requires'], state.all_tokens(), state.inventory):
                continue
            if model.allowed_regions is not None and model.rooms[dst[0]]['region'] not in model.allowed_regions:
                continue
            nd = distance + int(tr['kind'] == 'move')
            if nd <= max_doors and nd < distances.get(dst, 999):
                distances[dst] = nd
                (q.append if tr['kind'] == 'move' else q.appendleft)(dst)
    return goals


def branch_evidence(model, replay, route_plan):
    model.allowed_regions = set(route_plan['allowed_regions']) if route_plan.get('allowed_regions') else None
    samples, signatures = [], set()
    prior_door_from = None
    for event, state, previous, npcs in states_from_trace(model, replay):
        if event['kind'] == 'move':
            prior_door_from = event['from']
        if event['kind'] not in ('move', 'internal', 'action'):
            continue
        if event['kind'] == 'action' and event.get('type') not in ('ability', 'weapon', 'regional_clock', 'story_key'):
            continue
        # Branches are actual distinct physical exits accessible from this section.
        internal = {state.location}
        q = deque([state.location])
        doors = []
        while q:
            loc = q.popleft()
            for tr in model.adj[loc]:
                if not holds(tr['requires'], state.all_tokens(), state.inventory):
                    continue
                if tr['kind'] == 'internal':
                    if tr['to'] not in internal:
                        internal.add(tr['to']); q.append(tr['to'])
                elif tr['to'][0] != prior_door_from:
                    doors.append(tr)
        if len(doors) < 2:
            continue
        # A reconverging objective belongs to the shortest first-exit approach only.
        objectives = {tr['id']: reachable_branch_objectives(model, state, tr) for tr in doors}
        assignments = defaultdict(dict)
        all_goals = {key for gs in objectives.values() for key in gs}
        for goal in sorted(all_goals):
            possible = [(gs[goal]['door_distance'], tid) for tid, gs in objectives.items() if goal in gs]
            _, best = min(possible)
            assignments[best][goal] = objectives[best][goal]
        if len(assignments) < 2:
            continue
        signature = (state.room, tuple(sorted((t, tuple(gs)) for t, gs in assignments.items())))
        if signature in signatures:
            continue
        signatures.add(signature)
        samples.append({'step': event['step'], **model.state_summary(state),
                        'excluded_immediate_return_room': prior_door_from,
                        'first_door_options': [
                            {'transition_id': tid, 'door': model.transitions[tid]['public_id'],
                             'next_room': model.transitions[tid]['to'][0],
                             'next_section': model.transitions[tid]['to'][1],
                             'objectives': [{'action_or_target': gid, **detail} for gid, detail in gs.items()]}
                            for tid, gs in assignments.items()]})
    model.allowed_regions = None
    return samples


def acquisition_and_npc_evidence(model, replay):
    visits = {}
    offer_seen = {}
    previous_inventory = Counter()
    for event, state, previous, seen in states_from_trace(model, replay):
        for npc in model.npcs_by_location[state.location]:
            if npc['id'] in seen:
                visits.setdefault(npc['id'], {'step': event['step'], 'room': state.room,
                                              'section': state.section, 'name': npc.get('display_name', npc.get('name'))})
        for stock in model.world.get('shop_inventory', []):
            if (stock['room_id'], stock.get('section_id', 'main')) == state.location:
                if holds(stock.get('source_requires'), state.all_tokens(), state.inventory):
                    offer_seen.setdefault(stock['id'], {'step': event['step'], 'room': state.room,
                                                       'section': state.section, 'merchant_id': stock['merchant_id']})
    receipts = set(replay['unique_actions'])
    categories = {}
    for category, sources in model.world.get('collectibles', {}).items():
        categories[category] = {'source_count': len(sources),
                               'claimed_ids': [s['id'] for s in sources if s.get('action_id') in receipts],
                               'claimed_count': sum(s.get('action_id') in receipts for s in sources),
                               'price_deferred_ids': [s['id'] for s in sources if s.get('source') == 'shop']}
    return {'npc_sections_actually_visited': visits, 'shop_offers_seen': offer_seen,
            'shop_purchases_simulated': 0,
            'shop_scope': 'Seen means the offer location was reached. No stock is awarded without a price and a gold budget.',
            'collectible_receipts': categories}


def post_route_nonpriced_claim_audit(model, replay):
    """Extend D by real moves/actions to collect every authored nonpriced placeholder.

    This audits the logical source contracts, not final equipment effects/economy.
    No token injection. The extension starts from the recorded D inventory/state.
    """
    for _, state, _, _ in states_from_trace(model, replay):
        pass
    state = deepcopy(state)
    state.trace = []
    model.allowed_regions = None
    sources = [s for category in model.world['collectibles'].values() for s in category
               if s.get('source') != 'shop' and s.get('action_id') in model.actions]
    target_ids = {s['action_id'] for s in sources}
    target_ids.update(a['id'] for a in model.actions.values() if a.get('type') == 'npc_quest_objective')
    before = set(state.done)
    while True:
        candidates = []
        for aid in sorted(target_ids - state.done):
            action = model.actions[aid]
            path = model.search(state, [(action['room_id'], action['section_id'])], action=action)
            if path is not None:
                candidates.append((path['cost'], aid, path))
        if not candidates:
            break
        _, aid, path = min(candidates, key=lambda row: (row[0], row[1]))
        model.traverse(state, path)
        if aid not in state.done:
            model.perform(model.actions[aid], state)
        model.arrive(state)
    categories = {}
    for key, records in model.world['collectibles'].items():
        categories[key] = [
            {'id': s['id'], 'action_id': s.get('action_id'), 'room': s['room_id'],
             'section': s.get('section_id', 'main'),
             'status': 'claimed_on_D' if s.get('action_id') in before else
                       'claimed_in_audit_extension' if s.get('action_id') in state.done else
                       'price_and_currency_not_specified' if s.get('source') == 'shop' else
                       'not_claimed',
             'claim_scope': 'unique source placeholder; final effect/economy not validated'}
            for s in records]
    free_equipment_sources = [s for s in sources if s['id'].startswith('EQ_')]
    return {'schema': 'world.nonpriced-source-claim-audit.v04',
            'base_route': replay['id'], 'injected_tokens': [],
            'nonpriced_source_count': len(sources),
            'claimed_on_D': sum(s['action_id'] in before for s in sources),
            'claimed_in_extension': sum(s['action_id'] in state.done - before for s in sources),
            'remaining_nonpriced_sources': [s['id'] for s in sources if s['action_id'] not in state.done],
            'free_equipment_source_count': len(free_equipment_sources),
            'free_equipment_source_claim_count': sum(s['action_id'] in state.done for s in free_equipment_sources),
            'unpriced_equipment_shop_count': len(model.world.get('shop_inventory', [])),
            'unpriced_growth_shop_ids': [s['id'] for s in model.world['collectibles']['growth_minor_sources'] if s.get('source') == 'shop'],
            'categories': categories, 'trace': state.trace,
            'scope': 'Actual section moves and explicit receipts from the D end state. Proves logical nonpriced source acquisition. Does not validate purchasing or final equipment effects.'}


def text_report(evidence, acquisition):
    lines = ['世界房间布局 v04：分区路线证据', '',
             '位置使用 (房间, 分区)。进入入口预览区不算深入主体；不会领取其他分区的奖励。',
             '本报告验证数据状态、前置依赖和唯一收据；没有运行 Godot 物理、Boss 战斗、Q 冷却或人类试玩。', '',
             '一、四条路线']
    for row in evidence['routes']:
        lines += [f"{row['name']}：{'通过' if row['success'] else '失败'}；主体房间 {row['subject_rooms']}，深入区域 {row['deep_region_count']}，Boss {row['boss_count']}；过门 {row['physical_door_crossings']} 次、房内段 {row['internal_route_crossings']} 次、已激活裂缝交通 {row['rift_trips']} 次。",
                  f"  实际观察后完整折返并取得目标奖励：{row['memory_complete_count']}/{len(row['memory_evidence'])} 个预设地标；实际轨迹的局部多出口目标样本 {len(row['branch_samples'])} 个（同一房间在不同进度可重复计样本，不代表这么多独立岔路口）。",
                  f"  NPC 实际到访 {len(row['acquisition']['npc_sections_actually_visited'])}，商店报价点看到 {len(row['acquisition']['shop_offers_seen'])}，购买模拟 0。"]
        for mem in row['memory_evidence']:
            if mem['complete_return_chain']:
                lines += [f"  {mem['marker']} {mem['landmark']}：第 {mem['first_seen_step']} 步遇阻 → {mem['unlock_action']}（{mem['unlock_step']}）→ 返回 {mem['return_to_preview_step']} → 穿越 {mem['cross_after_unlock_step']} → {mem['reward_action']}（{mem['reward_claim_step']}）。"]
        lines.append('')
    lines += ['二、分岔口的统计口径',
              '从玩家实际所处分区出发，使用当时已有能力与当前装备；不使用传送，不假定未来获得能力。',
              '沿不同的第一扇物理门，在最多 6 次过门内可到达不同的重要目标才算样本。排除刚来的门；同一目标在汇合支路中只分配给最短支路。',
              '这是地图结构中“可从不同出口追逐目标”的证据，路径可能在更远处汇合，不代表相互独立的故事线。玩家是否发现并理解选择仍需试玩。6 次过门是分析窗口，不是设计保证或秒数。', '',
              '三、领取与经济范围',
              f"D 路线后续审计实际补走并领取：{acquisition['claimed_in_extension']} 个非付费来源；含 D 原已领取的 {acquisition['claimed_on_D']} 个，全部 {acquisition['nonpriced_source_count']} 个非付费来源均可取得。",
              f"其中装备来源占位 {acquisition['free_equipment_source_claim_count']}/{acquisition['free_equipment_source_count']}；其具体效果、负荷、最终装备映射未由此验证。",
              f"未模拟购买：{acquisition['unpriced_equipment_shop_count']} 个装备商店槽及成长商品 {', '.join(acquisition['unpriced_growth_shop_ids'])}。没有免费发放，也没有将到访当购买。",
              'D 本身仍是 40 齿轮交付、16 武器成长大材料与 22 Boss 的审计；D 不代表 50 装备全部购买完成。', '',
              '四、仍需灰盒实测',
              '门着陆安全、地形失败回到实际挑战入口、1/2 HP 扣血、Q 的 2 秒冷却与落地再触发、实体危险穿透禁止、镜头边界、2 枪安全窗口、Boss 重试实际秒数、装备购买经济与效果。']
    return '\n'.join(lines) + '\n'


def main():
    sim = ROOT / 'simulation'
    model = load_model()
    replays_path = sim / 'route-replays-v04.json'
    data = json.loads(replays_path.read_text())
    plans = {p['id']: p for p in json.loads(ROUTES.read_text())['routes']}
    canonical_hash = hashlib.sha256((WORLD).read_bytes()).hexdigest()
    if data['source_world_sha256'] != canonical_hash:
        raise RuntimeError('Replay is stale: run simulate_world.py first')
    evidence = {'schema': 'world.section-route-evidence.v04',
                'source_world_sha256': canonical_hash,
                'source_replay_sha256': hashlib.sha256(replays_path.read_bytes()).hexdigest(),
                'branch_analysis': {'max_physical_doors': 6, 'teleport': False,
                                    'equipment_switch_in_branch_search': False,
                                    'tokens': 'actual recorded state only',
                                    'reconvergence': 'one objective assigned to shortest first door only',
                                    'human_awareness': 'not simulated'}, 'routes': []}
    for replay in data['replays']:
        memory = memory_evidence(model, replay)
        branches = branch_evidence(model, replay, plans[replay['id']])
        row = {'id': replay['id'], 'name': replay['name'], 'success': replay['success'],
               'subject_rooms': replay['subject_rooms'], 'discovered_regions': replay['discovered_regions'],
               'deep_regions': replay['deep_regions'], 'deep_region_count': len(replay['deep_regions']),
               'boss_count': len(replay['bosses_defeated']),
               'physical_door_crossings': replay['move_steps'], 'internal_route_crossings': replay['internal_steps'],
               'rift_trips': replay['teleports'], 'memory_evidence': memory,
               'memory_complete_count': sum(m['complete_return_chain'] for m in memory),
               'branch_samples': branches, 'progress_milestones': replay['milestones'],
               'acquisition': acquisition_and_npc_evidence(model, replay)}
        evidence['routes'].append(row)
        print(json.dumps({'id': row['id'], 'memory_complete': row['memory_complete_count'],
                          'branch_samples': len(branches)}, ensure_ascii=False), flush=True)
    audit = post_route_nonpriced_claim_audit(model, data['replays'][-1])
    audit['source_world_sha256'] = canonical_hash
    audit['source_replay_sha256'] = evidence['source_replay_sha256']
    (sim / 'route-evidence-v04.json').write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + '\n')
    (sim / 'nonpriced-acquisition-audit-v04.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
    report = text_report(evidence, audit)
    (sim / 'route-summary-v04.txt').write_text(report)
    (sim / 'route-evidence-v04.txt').write_text(report)
    print(json.dumps({k: audit[k] for k in ['nonpriced_source_count', 'claimed_on_D', 'claimed_in_extension',
                                          'remaining_nonpriced_sources', 'free_equipment_source_claim_count']}, ensure_ascii=False))


if __name__ == '__main__':
    main()
