from pathlib import Path
import sys,json,shutil,hashlib,tarfile
ROOT=Path('/workspace/gunman-rush');sys.path.insert(0,str(ROOT/'tools'));import level_formal as f
base=ROOT/'build/plains_redesign/reward_entry';source=f.source_files()
(base/'baseline_sources.json').write_text(json.dumps(source,indent=2))
with tarfile.open(base/'baseline_source.tar.gz','w:gz') as tar:
 for name in source:tar.add(ROOT/name,arcname=name)
p=base/'candidate_a';p.mkdir(exist_ok=True)
for folder in ['scripts','scenes','resources','config','tools','tests','shaders']:
 if (ROOT/folder).exists():shutil.copytree(ROOT/folder,p/folder,dirs_exist_ok=True,ignore=shutil.ignore_patterns('__pycache__'))
shutil.copy2(ROOT/'project.godot',p/'project.godot')
for folder in ['assets','.godot']:
 if folder=='.godot':shutil.copytree(ROOT/folder,p/folder,dirs_exist_ok=True)
 elif not (p/folder).exists():(p/folder).symlink_to(ROOT/folder,target_is_directory=True)
gen=p/'scripts/generation/plains_region_generator.gd';s=gen.read_text();old='\t\tvar p := _point(a.position) + (Vector2(70,-110) if aerial else Vector2(130,0))';new=old+'\n\t\t# Authored ascent: reserve first jump/receiver; same guard watches the wide outside bank.\n\t\tvar trial_entrance: bool=m.connections.any(func(e: Dictionary):return e.kind=="challenge" and e.a==a.id)\n\t\tif trial_entrance:p=_point(a.position)+(Vector2(-130,-65) if aerial else Vector2(-130,0))'
assert old in s;gen.write_text(s.replace(old,new))
(base/'candidate_a_design.json').write_text(json.dumps({'candidate':'A','decision':'same guard/id/behavior/patrol moved to wide outside observation bank; first ascent receiver reserved','aerial_local':[-130,-65],'ground_local':[-130,0],'same_budget':True,'baseline_sources':source,'candidate_generator_sha256':f.file_hash(gen)},indent=2))
print(p)
