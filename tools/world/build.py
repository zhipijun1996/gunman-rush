"""Compile owned world inputs; never write an authored scene or imported source."""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from compile_contracts import compile_contracts, write_json


def build(root=ROOT):
    root = Path(root)
    source = root / 'config/world'
    world = json.loads((source/'world.json').read_text())
    contracts, report = compile_contracts(source/'world.json', source/'construction.json', root/'build/world/no-route-samples')
    if not report['passed']:
        raise ValueError(report['issues'])
    construction = json.loads((source/'construction.json').read_text())
    implemented = {r['room_id'] for r in construction['rooms'] if r.get('implemented')}
    scene_refs = {r['room_id']:r['scene_ref'] for r in construction['rooms']}
    for room in contracts['rooms']:
        room['scene_ref_status'] = 'implemented_graybox' if room['room_id'] in implemented else 'planned_new_scene_path; not already implemented'
        for door in room['doors']:
            door['target_scene'] = scene_refs[door['target_room']]
    sources = {n:hashlib.sha256((source/n).read_bytes()).hexdigest() for n in ['world.json','construction.json','collections.json','player.json']}
    scene_sources = {r['scene_ref']:hashlib.sha256((root/r['scene_ref'].removeprefix('res://')).read_bytes()).hexdigest() for r in construction['rooms'] if r['room_id'] in implemented and (root/r['scene_ref'].removeprefix('res://')).is_file()}
    version = hashlib.sha256(json.dumps({'inputs':sources,'scenes':scene_sources},sort_keys=True).encode()).hexdigest()
    bundle = {'schema':1,'content_version':version,'sources':sources,
              'start':contracts['initial_state'], 'actions':world['actions'], 'scene_sources':scene_sources,
              'player':json.loads((source/'player.json').read_text()), 'runtime_rules':world['runtime_rules'],
              'rooms':{r['room_id']:r for r in contracts['rooms'] if r['room_id'] in implemented}}
    for room in bundle['rooms'].values():
        if not (root / room['scene_ref'].removeprefix('res://')).is_file():
            raise ValueError('Implemented scene missing: '+room['scene_ref'])
    write_json(root/'build/world/contracts.json', contracts)
    write_json(root/'build/world/runtime.json', bundle)
    return contracts, bundle

if __name__ == '__main__':
    contracts, bundle = build()
    print(f'WORLD BUILD: {len(contracts["rooms"])} contracts, {len(bundle["rooms"])} implemented rooms, {bundle["content_version"][:12]}')
