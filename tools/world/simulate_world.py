#!/usr/bin/env python3
"""Replay the authored world at room-and-section resolution.

Door crossings and within-room routes are different graph edges. Actions,
benches and rifts bind to a section. This is a progression/inventory model;
it does not execute Godot physics, enemy combat, cooldowns or human memory.
"""
from __future__ import annotations

from collections import Counter, defaultdict, deque
from copy import deepcopy
from dataclasses import dataclass, field
from pathlib import Path
import argparse
import hashlib
import heapq
import itertools
import json
import re

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / 'build/world/validation'
WORLD = REPO / 'config/world/world.json'
ROUTES = REPO / 'config/world/routes.json'
ABILITIES = ('H', 'W', 'D', 'Q')
EQUIPMENT = ('eq_lamp', 'eq_filter')
OWNER = {'eq_lamp': 'lamp', 'eq_filter': 'filter'}
ATTACK_VALUES = [5, 9, 13, 17, 21]
FORWARD = {'both', 'forward', 'a_to_b', 'a->b', 'one_way'}
REVERSE = {'both', 'reverse', 'b_to_a', 'b->a'}


def clauses(value):
    if value is None or value == []:
        return [[]]
    if isinstance(value, str):
        return [[value]]
    if all(isinstance(x, str) for x in value):
        return [value]
    return value


def atom_holds(atom, tokens, inventory):
    match = re.fullmatch(r'([A-Za-z0-9_]+)\s*(>=|<=|==|>|<)\s*(\d+)', atom)
    if not match:
        return atom in tokens
    key, op, raw = match.groups()
    value, target = inventory.get(key, 0), int(raw)
    return {'>=': value >= target, '<=': value <= target, '==': value == target,
            '>': value > target, '<': value < target}[op]


def holds(req, tokens, inventory=None):
    return any(all(atom_holds(a, tokens, inventory or {}) for a in c) for c in clauses(req))


def missing(req, tokens, inventory=None):
    return [[a for a in c if not atom_holds(a, tokens, inventory or {})] for c in clauses(req)]


@dataclass
class State:
    room: str
    section: str = 'main'
    tokens: set = field(default_factory=lambda: {'gun'})
    equipped: set = field(default_factory=set)
    inventory: Counter = field(default_factory=Counter)
    done: set = field(default_factory=set)
    visited: set = field(default_factory=set)
    visited_locations: set = field(default_factory=set)
    subject_rooms: set = field(default_factory=set)
    discovered_regions: set = field(default_factory=set)
    deep_regions: set = field(default_factory=set)
    seen_locks: dict = field(default_factory=dict)
    unlocked_seen: dict = field(default_factory=dict)
    first_room_discovery_states: dict = field(default_factory=dict)
    first_subject_visit_states: dict = field(default_factory=dict)
    first_region_deep_states: dict = field(default_factory=dict)
    last_rest: str | None = None
    last_rest_section: str | None = None
    loadout_ready: bool = False
    trace: list = field(default_factory=list)
    milestones: list = field(default_factory=list)

    def all_tokens(self):
        return self.tokens | self.equipped

    @property
    def location(self):
        return self.room, self.section


class Model:
    def __init__(self, layout):
        self.layout = deepcopy(layout)
        self.world = self.layout  # Compatibility for reports, without an old overlay.
        self.rooms = {r['id']: r for r in self.layout['rooms']}
        self.sections = {}
        self.warnings = []
        for room in self.rooms.values():
            for section in room.get('sections', [{'id': 'main', 'kind': 'main'}]):
                self.sections[(room['id'], section['id'])] = section
        self.actions = {a['id']: deepcopy(a) for a in self.layout['actions']}
        self.edges = {e['id']: deepcopy(e) for e in self.layout['connections']}
        self.internal_routes = {}
        self.transitions = {}
        self.adj = defaultdict(list)
        self.room_adj = defaultdict(set)
        for edge in self.edges.values():
            direction = edge.get('direction', 'both')
            if direction not in FORWARD | REVERSE:
                raise ValueError('Unknown door direction: ' + str(direction))
            left = (edge['a'], edge.get('a_section', 'main'))
            right = (edge['b'], edge.get('b_section', 'main'))
            requirements = [a + b for a in clauses(edge.get('requires'))
                            for b in clauses(edge.get('room_guard'))]
            edge['requires'] = requirements
            if direction in FORWARD:
                self._add_transition('door:' + edge['id'] + ':ab', left, right,
                                     requirements, 'move', edge['id'], edge)
                self.room_adj[left[0]].add(right[0])
            if direction in REVERSE:
                self._add_transition('door:' + edge['id'] + ':ba', right, left,
                                     requirements, 'move', edge['id'], edge)
                self.room_adj[right[0]].add(left[0])
        for room in self.rooms.values():
            for route in room.get('internal_routes', []):
                rid = route['id']
                if rid in self.internal_routes:
                    raise ValueError('Duplicate internal route: ' + rid)
                route = deepcopy(route)
                route['room_id'] = room['id']
                self.internal_routes[rid] = route
                self._add_transition('internal:' + rid,
                    (room['id'], route['from_section']),
                    (room['id'], route['to_section']), route.get('requires'),
                    'internal', rid, route)
        self.rest_locations = {
            (r['id'], r.get('rest_section_id', 'main'))
            for r in self.rooms.values() if r.get('rest_point')}
        self.rests = {r for r, _ in self.rest_locations}
        self.rift_locations = {
            (r['id'], r.get('rift_section_id', 'main')): 'rift_' + r['region']
            for r in self.rooms.values() if r.get('rift_machine')}
        self.rifts = {room: token for (room, _), token in self.rift_locations.items()}
        for room, section in self.rest_locations:
            self.actions['rest_at_' + room] = {
                'id': 'rest_at_' + room, 'room_id': room, 'section_id': section,
                'type': 'rest', 'requires': [[]], 'grants': [], 'repeat': True,
                'description': '明确休息：登记复活点、恢复HP并开启新休息周期'}
        self.actions_by_location = defaultdict(list)
        self.actions_by_room = defaultdict(list)
        for action in self.actions.values():
            action.setdefault('section_id', 'main' if action.get('room_id') != '@current' else '@current')
            if 'inventory_grant' in action and 'inventory_grants' not in action:
                action['inventory_grants'] = action['inventory_grant']
            room = action.get('room_id')
            if room != '@current' and (room, action['section_id']) not in self.sections:
                self.warnings.append({'unbound_action': action['id'], 'room': room,
                                      'section': action['section_id']})
            self.actions_by_location[(room, action['section_id'])].append(action)
            self.actions_by_room[room].append(action)
        self.bosses = self.layout['boss_plan']['bosses']
        self.boss_rooms = {b['room_id']: b for b in self.bosses}
        self.boss_locations = {}
        for boss in self.bosses:
            action = self.actions[boss['defeat_action']]
            loc = (action['room_id'], action['section_id'])
            self.boss_locations[loc] = boss
        self.start = self.layout.get('start_room', 'P-R03')
        self.start_section = self.layout.get('start_section_id', 'main')
        self.start_location = self.start, self.start_section
        self.initial_tokens = set(self.layout.get('initial_tokens', ['gun']))
        self.auto_types = {'station', 'automatic_landmark'}
        self.auto_switches = True
        self.routes = self.layout.get('route_plans', [])
        if isinstance(self.routes, dict):
            self.routes = self.routes.get('routes', [])
        self.allowed_regions = None
        self.deep_locations = defaultdict(set)
        for region in self.layout.get('regions', []):
            code = region.get('code', region.get('region_code'))
            if not code:
                region_id = region.get('id')
                codes = {r['region'] for r in self.rooms.values()
                         if r.get('region_id') == region_id}
                if len(codes) == 1:
                    code = next(iter(codes))
            for loc in region.get('exploration_main_locations', []):
                if isinstance(loc, str):
                    position = (loc, 'main')
                else:
                    position = (loc.get('room_id', loc.get('room')),
                                loc.get('section_id', loc.get('section', 'main')))
                code = code or self.rooms[position[0]]['region']
                self.deep_locations[code].add(position)
        for loc, section in self.sections.items():
            if section.get('counts_as_region_deep_exploration'):
                self.deep_locations[self.rooms[loc[0]]['region']].add(loc)
        if not self.deep_locations:
            self.warnings.append({'missing': 'explicit region deep-exploration locations'})
        self.npcs_by_location = defaultdict(list)
        for npc in self.layout.get('npcs', []):
            self.npcs_by_location[(npc['room_id'], npc.get('section_id', 'main'))].append(npc)

    def _add_transition(self, tid, source, target, requirements, kind, public_id, data):
        for loc in [source, target]:
            if loc not in self.sections:
                raise ValueError('Unknown transition endpoint: ' + tid + ' ' + repr(loc))
        row = {'id': tid, 'from': source, 'to': target,
               'requires': clauses(requirements), 'kind': kind,
               'public_id': public_id, 'data': data}
        self.transitions[tid] = row
        self.adj[source].append(row)

    def state_summary(self, state):
        rank = 0
        for i in range(1, 5):
            if ('attack_rank_' + str(i)) in state.tokens:
                rank = i
        return {'room': state.room, 'section': state.section,
                'abilities': [a for a in ABILITIES if a in state.tokens],
                'weapon_flags': [w for w in ['gun', 'shuriken', 'bomb'] if w in state.tokens],
                'attack_rank': rank, 'attack_value': ATTACK_VALUES[rank],
                'equipment': sorted(state.equipped)}

    def initial(self):
        state = State(self.start, self.start_section, tokens=set(self.initial_tokens))
        self.arrive(state)
        return state

    def _action_location_matches(self, action, location):
        if action.get('room_id') == '@current':
            return True
        return location == (action.get('room_id'), action.get('section_id', 'main'))

    def available(self, action, state, location=True):
        if not action.get('repeat', False) and action['id'] in state.done:
            return False
        if location and not self._action_location_matches(action, state.location):
            return False
        if action.get('type') in ['equip', 'unequip']:
            if state.location not in self.rest_locations or not state.loadout_ready:
                return False
        boss = self.boss_locations.get(state.location)
        if boss and boss['defeat_token'] not in state.tokens:
            if action['id'] != boss['defeat_action'] and not action.get('available_before_boss', False):
                return False
        if not holds(action.get('requires'), state.all_tokens(), state.inventory):
            return False
        if any(token not in state.tokens for token in action.get('consumes_story_items', [])):
            return False
        return all(state.inventory.get(key, 0) >= value
                   for key, value in action.get('consumes', {}).items())

    def perform(self, action, state, automatic=False):
        if not self.available(action, state):
            raise ValueError('Unavailable action ' + action['id'] + ' at ' + repr(state.location))
        tokens_before = state.all_tokens()
        inventory_before = dict(state.inventory)
        for key, value in action.get('consumes', {}).items():
            state.inventory[key] -= value
        for token in action.get('consumes_story_items', []):
            state.tokens.discard(token)
        for key, value in action.get('inventory_grants', {}).items():
            state.inventory[key] += value
        transfer = action.get('inventory_transfer')
        if transfer:
            src, dst = transfer['from'], transfer['to']
            quantity = state.inventory.get(src, 0) if transfer.get('quantity') == 'all' else transfer.get('quantity', 0)
            if quantity > state.inventory.get(src, 0):
                raise ValueError('Insufficient transfer ' + action['id'])
            state.inventory[src] -= quantity
            state.inventory[dst] += quantity
        for token in action.get('removes', []):
            state.equipped.discard(token)
            state.tokens.discard(token)
        for token in action.get('grants', []):
            (state.equipped if token in EQUIPMENT else state.tokens).add(token)
        if action.get('type') == 'rest':
            state.last_rest, state.last_rest_section = state.location
            state.loadout_ready = True
        if not action.get('repeat', False):
            state.done.add(action['id'])
        state.trace.append({'step': len(state.trace), 'kind': 'action',
            'action': action['id'], 'type': action.get('type'),
            'automatic': automatic, 'grants': action.get('grants', []),
            'inventory_before': inventory_before, 'inventory_after': dict(state.inventory),
            'requires': clauses(action.get('requires')),
            'consumed_story_items': action.get('consumes_story_items', []),
            **self.state_summary(state)})
        self.notice_unlocked(state, tokens_before, inventory_before, action['id'])
        if action.get('type') in ['ability', 'weapon', 'regional_clock', 'story_key',
                                   'attack_upgrade', 'skill_upgrade']:
            state.milestones.append(self.choice_snapshot(state, action['id']))

    def arrive(self, state, auto=True):
        loc = state.location
        region = self.rooms[state.room]['region']
        state.visited.add(state.room)
        state.visited_locations.add(loc)
        state.discovered_regions.add(region)
        sample = {'step': max(0, len(state.trace) - 1), **self.state_summary(state),
                  'inventory': dict(state.inventory)}
        state.first_room_discovery_states.setdefault(state.room, sample)
        section = self.sections[loc]
        if section.get('kind') == 'main' or section.get('counts_as_subject_exploration'):
            state.subject_rooms.add(state.room)
            state.first_subject_visit_states.setdefault(state.room, sample)
        if loc in self.deep_locations[region]:
            state.deep_regions.add(region)
            state.first_region_deep_states.setdefault(region, sample)
        for transition in self.adj[loc]:
            if holds(transition['requires'], state.all_tokens(), state.inventory):
                continue
            # Only edges originating at the occupied section are observable.
            tid = transition['id']
            if tid not in state.seen_locks:
                state.seen_locks[tid] = {
                    'transition_id': tid, 'edge': transition['public_id'],
                    'kind': transition['kind'], 'from_room': loc[0], 'from_section': loc[1],
                    'to_room': transition['to'][0], 'to_section': transition['to'][1],
                    'first_seen_step': max(0, len(state.trace) - 1),
                    'missing_when_seen': missing(transition['requires'], state.all_tokens(), state.inventory),
                    'requires': transition['requires'],
                    'observation_scope': 'locally adjacent section route; physical sightline must be grayboxed'}
        if auto:
            changed = True
            while changed:
                changed = False
                for action in self.actions_by_location[loc]:
                    allowed = action.get('type') in self.auto_types or (
                        action.get('type') == 'switch' and self.auto_switches) or action.get('auto_collect', False)
                    if allowed and not action.get('repeat', False) and self.available(action, state):
                        self.perform(action, state, automatic=True)
                        changed = True

    def notice_unlocked(self, state, before, inventory_before, action_id):
        for tid, seen in state.seen_locks.items():
            if tid in state.unlocked_seen:
                continue
            transition = self.transitions[tid]
            if (not holds(transition['requires'], before, inventory_before)
                    and holds(transition['requires'], state.all_tokens(), state.inventory)):
                state.unlocked_seen[tid] = {
                    'transition_id': tid, 'edge': transition['public_id'],
                    'kind': transition['kind'], 'first_seen_step': seen['first_seen_step'],
                    'unlocked_at_step': len(state.trace) - 1, 'unlock_action': action_id,
                    'from_room': seen['from_room'], 'from_section': seen['from_section'],
                    'to_room': seen['to_room'], 'to_section': seen['to_section'],
                    'first_used_after_unlock': None}

    def allowed_location(self, location, state, tokens, goal_locations=None):
        if self.allowed_regions is not None and self.rooms[location[0]]['region'] not in self.allowed_regions:
            return False
        boss = self.boss_locations.get(location)
        if boss and boss['defeat_token'] not in state.tokens:
            if location not in (goal_locations or set()):
                return False
            action = self.actions[boss['defeat_action']]
            return holds(action.get('requires'), tokens, state.inventory)
        return True

    def _targets(self, targets, action):
        if targets is None:
            return None
        result = set()
        if action and action.get('room_id') != '@current':
            return {(action['room_id'], action.get('section_id', 'main'))}
        for target in targets:
            if isinstance(target, str):
                result.add((target, 'main'))
            elif isinstance(target, dict):
                result.add((target.get('room_id', target.get('room')),
                            target.get('section_id', target.get('section', 'main'))))
            else:
                result.add(tuple(target))
        return result

    def search(self, state, targets=None, action=None, allow_teleport=True):
        """Dijkstra on (room, section, loadout); progression stays fixed in a search."""
        target_set = self._targets(targets, action)
        start = (*state.location, tuple(sorted(state.equipped)))
        costs = {start: 0.0}
        predecessors = {}
        heap = [(0.0, 0, start)]
        serial = itertools.count(1)
        found = None
        while heap:
            cost, _, key = heapq.heappop(heap)
            if cost != costs[key]:
                continue
            room, section, equipment = key
            loc = room, section
            tokens = state.tokens | set(equipment)
            if target_set is not None and loc in target_set:
                valid = True
                if action:
                    valid = holds(action.get('requires'), tokens, state.inventory)
                    valid = valid and all(state.inventory.get(k, 0) >= v for k, v in action.get('consumes', {}).items())
                    valid = valid and all(t in state.tokens for t in action.get('consumes_story_items', []))
                    if action.get('type') in ['equip', 'unequip']:
                        valid = valid and loc in self.rest_locations
                    boss = self.boss_locations.get(loc)
                    if boss and boss['defeat_token'] not in state.tokens:
                        valid = valid and (action['id'] == boss['defeat_action'] or action.get('available_before_boss', False))
                if valid:
                    found = key
                    break
            living = self.boss_locations.get(loc)
            if living and living['defeat_token'] not in state.tokens and loc != state.location:
                continue
            options = []
            for transition in self.adj[loc]:
                dst = transition['to']
                if holds(transition['requires'], tokens, state.inventory) and self.allowed_location(dst, state, tokens, target_set):
                    step = {'kind': transition['kind'], 'transition_id': transition['id'],
                            'edge': transition['public_id'], 'from': room,
                            'from_section': section, 'to': dst[0], 'to_section': dst[1]}
                    # Cost ranks routes, not travel time; internal challenge cost is deliberately explicit.
                    options.append(((*dst, equipment), 1.0 if transition['kind'] == 'move' else 0.35, step))
            if loc in self.rest_locations:
                for token in EQUIPMENT:
                    if OWNER[token] not in state.tokens:
                        continue
                    after = set(equipment)
                    if token in after:
                        after.remove(token)
                        aid = 'unequip_' + OWNER[token]
                    else:
                        after.add(token)
                        aid = 'equip_' + OWNER[token]
                    options.append(((room, section, tuple(sorted(after))), 0.2,
                                    {'kind': 'equipment', 'action': aid, 'room': room, 'section': section}))
            if allow_teleport and loc in self.rift_locations and self.rift_locations[loc] in state.tokens:
                for dst, token in self.rift_locations.items():
                    if dst != loc and token in state.tokens and self.allowed_location(dst, state, tokens, target_set):
                        options.append(((*dst, equipment), 1.25,
                            {'kind': 'teleport', 'from': room, 'from_section': section,
                             'to': dst[0], 'to_section': dst[1]}))
            for next_key, added, step in options:
                new_cost = cost + added
                if new_cost < costs.get(next_key, float('inf')):
                    costs[next_key] = new_cost
                    predecessors[next_key] = key, step
                    heapq.heappush(heap, (new_cost, next(serial), next_key))
        if targets is None:
            locations = {(r, section) for r, section, _ in costs}
            return {'states': costs, 'locations': locations,
                    'rooms': {r for r, _ in locations},
                    'subject_rooms': {r for r, section in locations if self.sections[(r, section)].get('kind') == 'main'}}
        if found is None:
            return None
        steps = []
        key = found
        while key != start:
            key, step = predecessors[key]
            steps.append(step)
        steps.reverse()
        return {'steps': steps, 'cost': costs[found], 'destination': found[0],
                'destination_section': found[1], 'equipment': list(found[2]),
                'cost_scope': 'logical route preference, not seconds'}

    def traverse(self, state, path):
        for step in path['steps']:
            if step['kind'] == 'equipment':
                if not state.loadout_ready:
                    self.perform(self.actions['rest_at_' + state.room], state)
                self.perform(self.actions[step['action']], state)
                continue
            if (step['from'], step['from_section']) != state.location:
                raise ValueError('Broken replay position')
            if step['kind'] in ['move', 'internal']:
                transition = self.transitions[step['transition_id']]
                if not holds(transition['requires'], state.all_tokens(), state.inventory):
                    raise ValueError('Illegal transition ' + transition['id'])
                unlocked = state.unlocked_seen.get(transition['id'])
                if unlocked and unlocked['first_used_after_unlock'] is None:
                    unlocked['first_used_after_unlock'] = len(state.trace)
            elif step['kind'] == 'teleport':
                endpoints = [(step['from'], step['from_section']), (step['to'], step['to_section'])]
                if not all(self.rift_locations.get(loc) in state.tokens for loc in endpoints):
                    raise ValueError('Unactivated rift')
            state.room, state.section = step['to'], step['to_section']
            state.loadout_ready = False
            state.trace.append({'step': len(state.trace), **step, **self.state_summary(state)})
            self.arrive(state)

    def choice_snapshot(self, state, label):
        reachable = self.search(state, allow_teleport=False)
        states = reachable['states']
        equipment_by_loc = defaultdict(list)
        for room, section, eq in states:
            equipment_by_loc[(room, section)].append(eq)
        types = {'ability', 'weapon', 'regional_clock', 'npc', 'branch_material',
                 'skill_core', 'attack_alloy', 'story_key', 'boss_defeat'}
        goals = []
        for action in self.actions.values():
            if action['id'] in state.done or action.get('type') not in types:
                continue
            loc = action.get('room_id'), action.get('section_id', 'main')
            available = any(holds(action.get('requires'), state.tokens | set(eq), state.inventory)
                            for eq in equipment_by_loc[loc])
            if not available and action.get('type') == 'boss_defeat':
                available = self.search(state, [loc], action=action, allow_teleport=False) is not None
            if available:
                goals.append({'action': action['id'], 'room': loc[0], 'section': loc[1], 'type': action['type']})
        groups = defaultdict(list)
        for goal in goals:
            groups[self.rooms[goal['room']]['region']].append(goal['action'])
        return {'after_action': label, **self.state_summary(state),
                'reachable_rooms_without_teleport': len(reachable['rooms']),
                'reachable_subject_rooms_without_teleport': len(reachable['subject_rooms']),
                'available_objectives': goals, 'regional_choices': dict(groups),
                'region_choice_count': len(groups),
                'newly_unlocked_seen_routes': [v for v in state.unlocked_seen.values() if v['unlock_action'] == label]}

    def _nearby_rest_rooms(self, boss_room, maximum=2):
        reverse = defaultdict(set)
        for source, targets in self.room_adj.items():
            for target in targets:
                reverse[target].add(source)
        queue = deque([(boss_room, 0)])
        seen = {boss_room}
        while queue:
            room, distance = queue.popleft()
            if distance >= maximum:
                continue
            for previous in reverse[room]:
                if previous not in seen:
                    seen.add(previous)
                    queue.append((previous, distance + 1))
        return seen & self.rests

    def rest_for_boss(self, state, action, allow_teleport=True):
        target = action['room_id'], action['section_id']
        boss = self.boss_locations[target]
        candidates = []
        near = self._nearby_rest_rooms(action['room_id'])
        for loc in sorted(self.rest_locations):
            if loc[0] not in near:
                continue
            first = self.search(state, [loc], allow_teleport=allow_teleport)
            if first is None:
                continue
            test = deepcopy(state)
            test.room, test.section = loc
            test.equipped = set(first['equipment'])
            second = self.search(test, [target], action=action, allow_teleport=False)
            if second is None:
                continue
            door_moves = sum(s['kind'] == 'move' for s in second['steps'])
            if door_moves <= 2:
                candidates.append((first['cost'] + second['cost'], door_moves, loc, first, second))
        if not candidates:
            return {'success': False, 'boss': boss['id'],
                    'reason': 'no actual reachable rest section within two door crossings'}
        _, moves, loc, first, second = min(candidates, key=lambda x: (x[0], x[1], x[2]))
        self.traverse(state, first)
        self.perform(self.actions['rest_at_' + loc[0]], state)
        return {'success': True, 'boss': boss['id'], 'boss_room': target[0], 'boss_section': target[1],
                'rest_room': loc[0], 'rest_section': loc[1], 'reentry_transitions': moves,
                'reentry_internal_routes': sum(s['kind'] == 'internal' for s in second['steps']),
                'reentry_path': [{'room': loc[0], 'section': loc[1]}] +
                    [{'room': s['to'], 'section': s['to_section']} for s in second['steps'] if s['kind'] in ['move', 'internal']],
                'tokens_before_boss': sorted(state.tokens), 'attack_value': self.state_summary(state)['attack_value'],
                'rest_action_step': len(state.trace) - 1,
                'scope': 'graph reachability; no timing or terrain difficulty assertion'}

    def replay(self, plan):
        self.allowed_regions = set(plan['allowed_regions']) if plan.get('allowed_regions') else None
        state = self.initial()
        failure = None
        segments, boss_approaches = [], []
        for index, target in enumerate(plan['targets']):
            if isinstance(target, dict):
                aid = target.get('action')
                visit = target.get('visit_room')
            else:
                aid, visit = target, None
            if visit:
                requested = (visit, target.get('visit_section', 'main'))
                path = self.search(state, [requested], allow_teleport=plan.get('allow_teleport', True))
                if path is None:
                    failure = {'index': index, 'target': target, 'reason': 'visit section unreachable',
                               'at': list(state.location)}
                    break
                self.traverse(state, path)
                segments.append({'target': target, 'travel': path})
                continue
            action = self.actions.get(aid)
            if action is None:
                failure = {'index': index, 'target': aid, 'reason': 'unknown action'}
                break
            if aid in state.done and not action.get('repeat', False):
                segments.append({'target': aid, 'already_done': True})
                continue
            if action.get('type') == 'boss_defeat' and plan.get('rest_before_boss', False):
                checkpoint = self.rest_for_boss(state, action, plan.get('allow_teleport', True))
                boss_approaches.append(checkpoint)
                if not checkpoint['success']:
                    failure = {'index': index, 'target': aid, 'reason': 'boss checkpoint policy failed', 'detail': checkpoint}
                    break
            targets = self.rest_locations if action.get('room_id') == '@current' else [(action['room_id'], action['section_id'])]
            path = self.search(state, targets, action=action, allow_teleport=plan.get('allow_teleport', True))
            if path is None:
                failure = {'index': index, 'target': aid, 'target_room': action.get('room_id'),
                           'target_section': action.get('section_id'), 'reason': 'no legal section path/action state',
                           'at': list(state.location), 'missing': missing(action.get('requires'), state.all_tokens(), state.inventory),
                           'inventory': dict(state.inventory), 'requires_consumes': action.get('consumes', {}),
                           'tokens': sorted(state.tokens), 'equipped': sorted(state.equipped)}
                break
            start_trace = len(state.trace)
            self.traverse(state, path)
            if action.get('type') in ['equip', 'unequip'] and not state.loadout_ready:
                self.perform(self.actions['rest_at_' + state.room], state)
            if aid not in state.done or action.get('repeat', False):
                self.perform(action, state)
            self.arrive(state)
            segments.append({'target': aid, 'room': state.room, 'section': state.section,
                             'travel_steps': len(path['steps']), 'travel': path,
                             'trace_start': start_trace, 'trace_end': len(state.trace) - 1})
        self.last_state = state
        return {'id': plan['id'], 'name': plan.get('name', plan['id']),
                'success': failure is None, 'failure': failure, 'segments': segments,
                'trace': state.trace, 'milestones': state.milestones,
                'end_room': state.room, 'end_section': state.section,
                'visited_rooms': len(state.visited), 'visited_room_ids': sorted(state.visited),
                'visited_sections': [{'room': r, 'section': s} for r, s in sorted(state.visited_locations)],
                'subject_rooms': len(state.subject_rooms), 'subject_room_ids': sorted(state.subject_rooms),
                'visited_regions': sorted(state.discovered_regions),
                'discovered_regions': sorted(state.discovered_regions), 'deep_regions': sorted(state.deep_regions),
                'first_room_discovery_states': list(state.first_room_discovery_states.values()),
                'first_subject_visit_states': list(state.first_subject_visit_states.values()),
                'first_region_deep_states': state.first_region_deep_states,
                'move_steps': sum(t['kind'] == 'move' for t in state.trace),
                'internal_steps': sum(t['kind'] == 'internal' for t in state.trace),
                'teleports': sum(t['kind'] == 'teleport' for t in state.trace),
                'equipment_switches': sum(t.get('type') in ['equip', 'unequip'] for t in state.trace),
                'inventory': dict(state.inventory), 'tokens': sorted(state.tokens),
                'unique_actions': sorted(state.done),
                'boss_approaches': boss_approaches, 'last_rest': state.last_rest,
                'last_rest_section': state.last_rest_section,
                'respawn_anchor': {'room': state.last_rest or self.start,
                                   'section': state.last_rest_section or self.start_section},
                'rest_interactions': sum(t.get('type') == 'rest' for t in state.trace),
                'bosses_defeated': [b['id'] for b in self.bosses if b['defeat_token'] in state.tokens],
                'observed_locks': list(state.seen_locks.values()),
                'revisit_opportunities': list(state.unlocked_seen.values()),
                'revisited_unlocked_routes': [v for v in state.unlocked_seen.values()
                                               if v['first_used_after_unlock'] is not None]}


def load_model(layout_path=None):
    path = Path(layout_path or WORLD)
    return Model(json.loads(path.read_text()))


def states_from_trace(model, replay):
    """Reconstruct only recorded operations; never grant future progress."""
    state = State(model.start, model.start_section, tokens=set(model.initial_tokens))
    state.visited = {state.room}
    state.visited_locations = {state.location}
    previous = None
    npc_seen = set()
    for event in replay['trace']:
        if event['kind'] in ['move', 'internal', 'teleport']:
            previous = event['from'], event['from_section']
            state.room, state.section = event['to'], event['to_section']
            state.loadout_ready = False
        elif event['kind'] == 'action':
            action = model.actions[event['action']]
            state.tokens.difference_update(action.get('removes', []) + action.get('consumes_story_items', []))
            state.tokens.update(t for t in action.get('grants', []) if t not in EQUIPMENT)
            state.inventory = Counter(event['inventory_after'])
            if not action.get('repeat', False):
                state.done.add(action['id'])
            if action.get('type') == 'rest':
                state.last_rest, state.last_rest_section = state.location
                state.loadout_ready = True
        if 'equipment' in event:
            state.equipped = set(event['equipment'])
        state.visited.add(state.room)
        state.visited_locations.add(state.location)
        region = model.rooms[state.room]['region']
        state.discovered_regions.add(region)
        if model.sections[state.location].get('kind') == 'main':
            state.subject_rooms.add(state.room)
        if state.location in model.deep_locations[region]:
            state.deep_regions.add(region)
        for npc in model.npcs_by_location[state.location]:
            if holds(npc.get('availability', {}).get('visible_when'), state.all_tokens(), state.inventory):
                npc_seen.add(npc['id'])
        yield event, state, previous, npc_seen


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layout', type=Path, default=WORLD)
    parser.add_argument('--route-file', type=Path, default=ROUTES)
    parser.add_argument('--out', type=Path, default=ROOT / 'simulation/route-replays-v04.json')
    parser.add_argument('--plans', nargs='*')
    args = parser.parse_args()
    model = load_model(args.layout)
    plans = json.loads(args.route_file.read_text())['routes']
    result = {'schema': 'world.section-state-replay.v04',
              'source_world_sha256': hashlib.sha256(args.layout.read_bytes()).hexdigest(),
              'source_plans_sha256': hashlib.sha256(args.route_file.read_bytes()).hexdigest(),
              'scope': 'Logical door, in-room-section, progression and inventory model. No physics, combat, Q cooldown timing or human-memory validation.',
              'rules': {'position': '(room_id, section_id)', 'requirements': 'OR of AND clauses; inventory predicates interpreted',
                        'equipment': 'actual rest in the designated bench section',
                        'uniqueness': 'persistent unique action receipts', 'living_boss': 'no transit through its arena',
                        'teleport': 'both endpoint sections physically reached and stations activated',
                        'region_coverage': 'discovery and designated main-area exploration recorded separately',
                        'currency': 'no assumed purchase or free shop inventory'},
              'warnings': model.warnings, 'replays': []}
    for plan in plans:
        if args.plans and plan['id'] not in args.plans:
            continue
        replay = model.replay(plan)
        result['replays'].append(replay)
        print(json.dumps({k: replay[k] for k in ['id', 'success', 'failure', 'visited_rooms',
              'subject_rooms', 'discovered_regions', 'deep_regions', 'move_steps', 'internal_steps', 'teleports']}, ensure_ascii=False), flush=True)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')


if __name__ == '__main__':
    main()
