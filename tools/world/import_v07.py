"""One-time verified v07 handoff extraction into the project's owned inputs.

Run only for the initial migration. Refuses to overwrite a migrated world; later
room edits belong to config/world and authored scenes, never the source archive.
"""
from pathlib import Path
import argparse, hashlib, json, shutil
ROOT=Path(__file__).resolve().parents[2]
def write(path,value):
 path.parent.mkdir(parents=True,exist_ok=True)
 path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('source',type=Path);args=parser.parse_args();src=args.source
 manifest=json.loads((src/'MANIFEST_LIGHT.json').read_text())
 for record in manifest['files']:
  path=(src/record['path']).resolve()
  if not path.is_relative_to(src.resolve()) or hashlib.sha256(path.read_bytes()).hexdigest()!=record['sha256']:raise ValueError(record['path'])
 world=json.loads((src/'world-room-layout-v07.json').read_text());contracts=json.loads((src/'design/room-graybox-contracts-v07.json').read_text())
 if len(world['rooms'])!=309 or len([r for r in world['rooms'] if r['region']=='P'])!=35:raise ValueError('Unexpected world revision')
 old=json.loads((ROOT/'config/world/world.json').read_text())
 if old['schema'].endswith('v07'):raise ValueError('Already migrated; edit owned inputs, do not reimport')
 construction={'schema':'gunman-rush.construction.v2','rooms':[],'door_pairs':contracts['door_coordinate_audit'],'boss_first_visit':{},'shop_policy':contracts['shop_policy']}
 for room in contracts['rooms']:
  geometry=room['world_geometry'];rid=room['room_id']
  row={'room_id':rid,'scene_ref':f'res://game/world/regions/{room["region"]}/rooms/{rid}.tscn','extent':geometry['bounds_world_units'][2:],'shape_class':geometry['shape_class'],'rationale':geometry['rationale'],'camera':room['camera'],'doors':[{k:d[k] for k in ['id','position_candidate','landing_contract'] if k in d} for d in room['doors']],'entry_spawns':room['entry_spawns'],'rest':room['rest'],'terrain_failure':room['terrain_failure'],'shop_stock_refs':room['shop_stock_refs'],'save_scope':room['save_scope'],'implemented':False}
  if 'boss' in room:
   row['boss']=room['boss'];row['boss_arena_override']=room['boss_arena'];construction['boss_first_visit'][room['boss_arena']['boss_id']]=room['first_visit']['minimum_legal_state_dnf']
  construction['rooms'].append(row)
 # Separate detailed acquisition/secret design from topology; runtime compiles only needed records.
 write(ROOT/'config/world/world.json',world);write(ROOT/'config/world/construction.json',construction)
 for origin,target in [('design/collection-catalog-v07.json','collections.json'),('design/collection-level-design-v07.json','collection_design.json'),('simulation/route-plans-v07.json','routes.json')]:
  data=json.loads((src/origin).read_text())
  if target=='routes.json':data['canonical']='config/world/world.json'
  if target=='collections.json':data['canonical_reference']['file']='world.json'
  write(ROOT/'config/world'/target,data)
 # Frozen latest source for provenance and human maps. Historical migration inputs
 # and generators stay in the original ZIP; they are not a second production path.
 dest=ROOT/'docs/data/world/source-v07';dest.mkdir(parents=True,exist_ok=True)
 for path in src.rglob('*'):
  rel=path.relative_to(src)
  if not path.is_file() or 'source_inputs' in rel.parts or path.suffix=='.py':continue
  out=dest/rel;out.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,out)
 (dest/'.gdignore').touch()
 write(ROOT/'config/world/provenance.json',{'schema':1,'revision':'v07.1','source_comment':'https://github.com/zhipijun1996/gunman-rush/pull/141#issuecomment-6711181818','archive_sha256':'c4e6f7692bd3341aadf972f8c766a533fe39cea925c50694ad76ccfa32fdc395','canonical_source_sha256':manifest['canonical_sha256'],'frozen_reference':'docs/data/world/source-v07/','retired':'v04 topology; retained only in Git history','authority':'config/world/world.json; construction.json; collection_design.json'})
 print('Imported 309 rooms / 411 connections / 35 plains rooms. Scenes require explicit construction.')
if __name__=='__main__':main()
