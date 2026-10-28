import sys,contextlib,json,time,re,subprocess,hashlib
from pathlib import Path
sys.path.insert(0,'tools')
from run_tests import run_engine
p=Path('build/item_art_01/world-shader-native-03')
r={'phase':'actual-GL-shared-world-shader','budget_seconds':120,'status':'failed','source_head_base':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'shader_sha256':hashlib.sha256(Path('shaders/underworld_fine_sprite.gdshader').read_bytes()).hexdigest(),'probe_sha256':hashlib.sha256(Path('build/item_art_01/runtime-draft/world_shader_probe.gd').read_bytes()).hexdigest()}
t=time.monotonic()
try:
 with (p/'native-gl.log').open('w') as log,contextlib.redirect_stdout(log):
  out=run_engine(['--path','.','--rendering-method','gl_compatibility','--audio-driver','Dummy','--resolution','640x560','--script','res://build/item_art_01/runtime-draft/world_shader_probe.gd','--','--capture-dir=res://build/item_art_01/world-shader-native-03'],120)
 if re.search(r'SCRIPT ERROR:|SHADER ERROR:|(?m:^ERROR:)|ObjectDB.*leaked|resources? still in use at exit',out): raise RuntimeError('strict engine error')
 if not re.search(r'^ITEM WORLD SHADER: [1-9]\d* checks, 0 failures$',out,re.M): raise RuntimeError('missing exact0failurecompletion')
 r['status']='passed'
except Exception as e:r['error']=str(e)
r['elapsed_seconds']=time.monotonic()-t
(p/'run-receipt.json').write_text(json.dumps(r,indent=2));print(json.dumps(r))
sys.exit(0 if r['status']=='passed' else 1)
