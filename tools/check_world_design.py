"""Validate fixed-world identities and interfaces, never claim engine playability."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'docs/bible/world_regions.json'
from world.build import build as build_world


def validate_data(world, contracts, catalog):
    errors = []
    def unique(rows, key, label):
        ids = [r[key] for r in rows]
        if len(ids) != len(set(ids)):
            errors.append('Duplicate ' + label)
        return {r[key]: r for r in rows}
    rooms = unique(world['rooms'], 'id', 'room IDs')
    regions = unique(world['regions'], 'code', 'region codes')
    unique(world['regions'], 'id', 'region IDs')
    edges = unique(world['connections'], 'id', 'connection IDs')
    actions = unique(world['actions'], 'id', 'action IDs')
    sections = {}
    for rid, room in rooms.items():
        if room['region'] not in regions:
            errors.append('Unknown region: ' + rid)
        sections[rid] = unique(room['sections'], 'id', 'section IDs in ' + rid)
        routes = unique(room['internal_routes'], 'id', 'internal route IDs in ' + rid)
        for route in routes.values():
            if route['from_section'] not in sections[rid] or route['to_section'] not in sections[rid]:
                errors.append('Unknown internal section: ' + route['id'])
    def location(room, section, label):
        if section not in sections.get(room, {}):
            errors.append('Unknown room/section: ' + label)
    for edge in edges.values():
        for side in ('a', 'b'):
            location(edge[side], edge[side + '_section'], edge['id'])
        if any(set(clause) & {'H','W','D','Q'} for clause in edge['requires']):
            errors.append('Ability on physical door: ' + edge['id'])
    receipts = []
    for action in actions.values():
        if not (action['room_id'] == action['section_id'] == '@current' and action.get('requires_rest_interaction') is True):
            location(action['room_id'], action['section_id'], action['id'])
        if action.get('receipt_id'):
            receipts.append(action['receipt_id'])
        if action.get('receipt_id') and action.get('repeat'):
            errors.append('Repeatable permanent action: ' + action['id'])
    if len(receipts) != len(set(receipts)):
        errors.append('Duplicate permanent receipts')
    for shortcut in world['shortcuts']:
        action = actions.get(shortcut['open_action_id'])
        if not action or action['room_id'] != shortcut['open_from_room'] or shortcut['open_token'] not in action['grants']:
            errors.append('Invalid shortcut control side/token: ' + shortcut['id'])
    planned = unique(contracts['rooms'], 'room_id', 'contract rooms')
    if set(planned) != set(rooms):
        errors.append('Contract/world room set differs')
    doors = unique([d for r in planned.values() for d in r['doors']], 'id', 'door IDs')
    spawns = unique([s for r in planned.values() for s in r['entry_spawns']], 'id', 'spawn IDs')
    opposite = {'left':'right','right':'left','up':'down','down':'up'}
    if len(doors) != 2 * len(edges):
        errors.append('Expected two physical door endpoints per connection')
    spawn_owners = {s['id']: r['room_id'] for r in planned.values() for s in r['entry_spawns']}
    for door in doors.values():
        edge = edges.get(door['edge_id'])
        endpoints = {(door['room_id'], door['section']), (door['target_room'], door['target_section'])}
        if not edge or endpoints != {(edge['a'], edge['a_section']), (edge['b'], edge['b_section'])}:
            errors.append('Door differs from canonical connection: ' + door['id'])
        if spawn_owners.get(door['target_spawn']) != door['target_room']:
            errors.append('Spawn belongs to wrong target room: ' + door['id'])
        target = doors.get(door['target_door_id'])
        if not target or target['target_door_id'] != door['id'] or target['room_id'] != door['target_room'] or opposite.get(door['direction']) != target['direction']:
            errors.append('Broken door pair: ' + door['id'])
        if door['target_spawn'] not in spawns:
            errors.append('Missing target spawn: ' + door['id'])
        location(door['room_id'], door['section'], door['id'])
        location(door['target_room'], door['target_section'], door['id'])
    slots = catalog['equipment_sources']
    unique(slots, 'reward_id', 'equipment reward IDs')
    stock = unique(world['shop_inventory'], 'id', 'shop stock IDs')
    for slot in slots:
        if not (slot.get('action_ref') in actions if 'action_ref' in slot else slot.get('stock_ref') in stock):
            errors.append('Invalid catalog source: ' + slot['reward_id'])
    return errors


def validate(path=None, contract_path=None, root=ROOT):
    root = Path(root)
    errors = []
    try:
        mapping = json.loads(Path(path or root / 'docs/bible/world_regions.json').read_text())
        contract = json.loads(Path(contract_path or root / 'docs/bible/design_contract.json').read_text())
        if mapping.get('schema_version') != 2 or mapping.get('kind') != 'fixed_world_region_identity_mapping':
            errors.append('Expected fixed-world identity mapping schema')
        if any(r.get('runtime_available') is not False for r in mapping['regions']):
            errors.append('Identity mapping must not claim fixed-world runtime availability')
        source = root / mapping['canonical']
        world = json.loads(source.read_text())
        contracts, _ = build_world(root)
        catalog = json.loads((root / 'config/world/collections.json').read_text())
        errors.extend(validate_data(world, contracts, catalog))
        sha = hashlib.sha256(source.read_bytes()).hexdigest()
        if contracts['canonical_sha256'] != sha or catalog['canonical_reference']['sha256'] != sha:
            errors.append('Stale source digest in contracts/catalog')
        expected = {(r['id'], r['code'], r['name']) for r in world['regions']}
        actual = {(r['id'], r['code'], r['working_name']) for r in mapping['regions']}
        if actual != expected or len(actual) != len(mapping['regions']):
            errors.append('Region identity mapping differs from canonical')
        if contract.get('world_source') != mapping['canonical']:
            errors.append('Multiple world authorities')
    except (OSError, ValueError, KeyError, TypeError) as error:
        errors.append('Invalid world data: ' + str(error))
    return errors


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--catalog', type=Path)
    errors = validate(parser.parse_args().catalog)
    print('\n'.join(errors) if errors else 'PASS: fixed-world IDs, endpoints, sections, shortcuts, receipts, source digests and references; runtime not tested')
    raise SystemExit(bool(errors))
