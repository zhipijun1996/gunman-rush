from pathlib import Path
import hashlib, json, sys, difflib, os
os.environ['PYTHONDONTWRITEBYTECODE']='1'
ROOT=Path('/workspace/gunman-rush-refactor')
OUT=Path('/workspace/refactor-evidence/death-runtime-01/loot-gpu')
TMP=Path('/tmp/loot-gpu-02')
AUTHOR=OUT.parent/'loot-material-candidate'
sys.path.insert(0,str(ROOT/'tools'))
sys.path.insert(0,str(ROOT/'tools/mobile_web_perf'))
from check_web_bundle import Pack
from build_probe import write_pack
from prepare_frame_pair import prepare
from godot_identity import verify_templates

def sha(data): return hashlib.sha256(data).hexdigest()
def fsha(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

stage_path='game/presentation/world/art/plains_stage_visual.gd'
helper_path='game/presentation/rendering/canvas_shader_preparation.gd'
app_path='game/application/demo_app.gd'
original_stage=(AUTHOR/'original'/stage_path).read_bytes()
optional_stage=(AUTHOR/'with-optional-warming'/stage_path).read_text()
old='\tCANVAS_PREPARATION.prepare_loot(self, _loot_material, _texture(&"coin"))'
new='\tif DisplayServer.get_name() != "headless":\n\t\tCANVAS_PREPARATION.prepare_loot(self, _loot_material, _texture(&"coin"))'
assert optional_stage.count(old)==1
guarded=optional_stage.replace(old,new)
(OUT/'candidate'/stage_path).parent.mkdir(parents=True,exist_ok=True)
(OUT/'candidate'/stage_path).write_text(guarded)
(OUT/'headless-guard.patch').write_text(''.join(difflib.unified_diff(optional_stage.splitlines(True),guarded.splitlines(True),fromfile='a/'+stage_path,tofile='b/'+stage_path)))
app=(ROOT/app_path).read_text()
injection='''\t# External loot rendering fixture only; original main scene is retained.
\tset_process(false)
\tset_physics_process(false)
\tset_process_input(false)
\tset_process_unhandled_input(false)
\tset_process_unhandled_key_input(false)
\tadd_child(load("res://loot_fixture.gd").new())
\treturn
'''
needle='func _ready() -> void:\n'
assert app.count(needle)==1
patched=app.replace(needle,needle+injection,1)
assert patched.replace(injection,'',1)==app
(OUT/'fixture-app.patch').write_text(''.join(difflib.unified_diff(app.splitlines(True),patched.splitlines(True),fromfile='a/'+app_path,tofile='b/'+app_path)))
basepack=Path('/tmp/gunman-first-use-web-source/build/web/index.9dd3a9a2ecd8.pck')
pack=Pack(basepack)
common={app_path:patched.encode(),'loot_fixture.gd':(OUT/'loot_fixture.gd').read_bytes(),'loot_baseline_reference.gd':original_stage.replace(b'class_name PlainsStageVisual\n',b'',1)}
receipt={'scope':'external technical fixture only, exact same fixture/App bytes in both packs; original production main scene unchanged; no natural death, phone FPS or deployment claim','base_pack':{'path':str(basepack),'sha256':fsha(basepack),'bytes':basepack.stat().st_size},'fixture_sha256':sha(common['loot_fixture.gd']),'app_original_sha256':sha(app.encode()),'app_fixture_sha256':sha(patched.encode()),'app_inverse_verified':True,'candidate_before_guard_sha256':sha(optional_stage.encode()),'candidate_guarded_sha256':sha(guarded.encode()),'variants':{}}
for mode in ['baseline','candidate']:
    directory=TMP/mode
    directory.mkdir(exist_ok=False)
    replacements=dict(common)
    replacements[stage_path]=original_stage if mode=='baseline' else guarded.encode()
    replacements[helper_path]=(AUTHOR/('original' if mode=='baseline' else 'with-optional-warming')/helper_path).read_bytes()
    target=directory/'diagnostic.pck'
    skip={p+'.remap' for p in [app_path,stage_path,helper_path]}
    write_pack(pack,replacements,skip,target)
    # Original helper constructs both engines; only its debug site will run.
    pair=prepare(basepack.parent,directory/'web',verify_templates(),target)
    row={'pack_sha256':fsha(target),'pack_bytes':target.stat().st_size,'replaced_sha256':{p:sha(b) for p,b in replacements.items()},'removed_remaps':sorted(skip),'site':str(directory/'web/engine-debug')}
    (directory/'pair-receipt.json').write_text(json.dumps(pair,indent=2)+'\n')
    receipt['variants'][mode]=row
(OUT/'pack-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt,indent=2))
