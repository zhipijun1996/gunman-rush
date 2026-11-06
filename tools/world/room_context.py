"""Bounded room context. Does not load scenes or grant runtime state."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IMPORT = ROOT / 'docs/data/world/import-v04'


def extract(room_id, folder=IMPORT, full_contract=False):
    world = json.loads((folder / 'world-room-layout-v04.json').read_text())
    matches = [r for r in world['rooms'] if r['id'] == room_id]
    if len(matches) != 1:
        raise ValueError('Unknown/duplicate room: ' + room_id)
    room = matches[0]
    contracts = json.loads((folder / 'design/room-graybox-contracts-v04.json').read_text())
    contract = next(r for r in contracts['rooms'] if r['room_id'] == room_id)
    return {'room': {k: v for k, v in room.items() if k not in {'polygon', 'components'}},
            'connections': [c for c in world['connections'] if room_id in (c['a'], c['b'])],
            'actions': [a for a in world['actions'] if a.get('room_id') == room_id],
            'contract': contract if full_contract else {k: contract[k] for k in ('scene_ref', 'scene_ref_status', 'purpose')},
            'runtime_status': 'planned; no fixed-world scenes implemented',
            'state_authority': 'docs/bible/home_and_save.md'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('room_id')
    parser.add_argument('--contract', action='store_true')
    args = parser.parse_args()
    try:
        print(json.dumps(extract(args.room_id, full_contract=args.contract), ensure_ascii=False, indent=2))
    except ValueError as error:
        parser.error(str(error))
