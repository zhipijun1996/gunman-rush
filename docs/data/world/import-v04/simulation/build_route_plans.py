"""Keep route intentions, relocate preview visits to actual observable sections."""
from pathlib import Path
from copy import deepcopy
import json

ROOT = Path(__file__).resolve().parents[1]


def build():
    old = json.loads((ROOT / 'source_inputs/route-plans-v03.json').read_text())
    world = json.loads((ROOT / 'world-room-layout-v04.json').read_text())
    # The old plan visits these landmark approaches explicitly. Item locks stay
    # on the door; only the H/W/D/Q previews need to enter the next room.
    moved_previews = {
        'F-R03': ('F-R04', 'L03'),
        'F-R16': ('F-R15', 'L04'),
        'I-R05': ('I-R11', 'L08'),
        'G-R05': ('E-R12', 'C22'),
    }
    connections = {edge['id']: edge for edge in world['connections']}
    memory_by_edge = {memory['edge_id']: memory for memory in world.get('memory_gates', [])}
    rows, log = [], []
    for route in old['routes']:
        result = deepcopy(route)
        result['scope'] = ('Concrete legal progression witness at room-section resolution; '
                           'not an optimal route, combat/physics test, purchase simulation or proof of human memory.')
        for target in result['targets']:
            if not isinstance(target, dict):
                continue
            previous = target.get('visit_room')
            if previous not in moved_previews:
                target.setdefault('visit_section', 'main')
                continue
            room, edge_id = moved_previews[previous]
            edge = connections[edge_id]
            section = edge['b_section'] if edge['b'] == room else edge['a_section']
            memory = memory_by_edge.get(edge_id, {})
            target.update({'visit_room': room, 'visit_section': section,
                           'observed_landmark': memory.get('id'),
                           'purpose': '进入新房入口安全区观察或回访房内障碍；' + target.get('purpose', '')})
            log.append({'route': result['id'], 'old_preview_room': previous,
                        'new_preview_room': room, 'new_preview_section': section, 'edge_id': edge_id})
        rows.append(result)
    doc = {'schema': 'world.player-route-plans.v04',
           'canonical': '../world-room-layout-v04.json',
           'position_model': '(room_id, section_id)',
           'route_change_policy': 'Retain rewards, abilities and intended optional choices; move previews to the actual inside-room obstacle approach.',
           'routes': rows}
    (ROOT / 'simulation/route-plans-v04.json').write_text(json.dumps(doc, ensure_ascii=False, indent=2) + '\n')
    (ROOT / 'simulation/route-plan-migration-v04.json').write_text(json.dumps({'preview_relocations': log}, ensure_ascii=False, indent=2) + '\n')
    print('routes', len(rows), 'relocated previews', len(log))


if __name__ == '__main__':
    build()
