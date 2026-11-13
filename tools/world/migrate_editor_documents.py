"""Adopt verified full room documents; retain thin scene entry points for consumers."""
from pathlib import Path
import argparse, json

ROOT = Path(__file__).resolve().parents[2]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--documents',type=Path,default=ROOT/'build/editor/rooms')
    args=parser.parse_args()
    receipt=json.loads((args.documents.parent/'roundtrip.json').read_text())
    if not receipt.get('passed') or not receipt.get('rooms') or not all(r['roundtrip'] for r in receipt['rooms']):
        raise SystemExit('Full document roundtrip must pass before migration')
    rows=json.loads((ROOT/'config/world/construction.json').read_text())['rooms']
    scenes={r['room_id']:ROOT/r['scene_ref'].removeprefix('res://') for r in rows}
    scripts={'FixedWorldRoom':'res://game/world/levels/fixed_world_room.gd','StarbridgeTrialRoom':'res://game/world/regions/V/starbridge_trial_room.gd'}
    prepared=[]
    for check in receipt['rooms']:
        rid=check['room_id'];doc=json.loads((args.documents/f'{rid}.json').read_text())
        if doc.get('schema')!=2 or doc.get('room_id')!=rid or doc['root']['component'] not in scripts:
            raise SystemExit('Invalid room document: '+rid)
        prepared.append((rid,doc,scripts[doc['root']['component']]))
    target=ROOT/'config/world/rooms';target.mkdir(parents=True,exist_ok=True)
    for rid,doc,script in prepared:
        (target/f'{rid}.json').write_text(json.dumps(doc,ensure_ascii=False,indent=2,sort_keys=True)+'\n')
        scenes[rid].write_text(f'[gd_scene format=3]\n\n[ext_resource type="Script" path="{script}" id="1"]\n\n[node name="{rid}" type="Node2D"]\nscript = ExtResource("1")\ndocument_ref = "res://config/world/rooms/{rid}.json"\n')
    print(f'Adopted {len(prepared)} room documents; scene entry points contain no layout')

if __name__=='__main__':main()
