import ast,hashlib,importlib.util,io,json,pathlib,subprocess,sys,tempfile
from types import SimpleNamespace
from unittest.mock import patch
from PIL import Image,ImageDraw
root=pathlib.Path('/workspace/gunman-rush');sys.path.insert(0,str(root/'tools'));import studio_gui_pointer as h
out=root/'build/forest_revision04/main-M-review/menu-width-followup'
old=subprocess.check_output(['git','show','4aec8b56743d1a14d1b44ba43d795e56811d7615:tools/studio_gui_pointer.py'],cwd=root,text=True)
oldtest=subprocess.check_output(['git','show','4aec8b56743d1a14d1b44ba43d795e56811d7615:tools/test_studio_gui_pointer.py'],cwd=root,text=True)
def fns(s):return {n.name:ast.dump(n,include_attributes=False) for n in ast.parse(s).body if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef))}
o=fns(old);n=fns((root/'tools/studio_gui_pointer.py').read_text());changed=[k for k in o if o[k]!=n[k]];assert changed==['_studio_actions_from_pixels'];assert set(n)-set(o)=={'_studio_button_inner_fill'}
def methods(s):
 return {c.name+'.'+m.name:ast.dump(m,include_attributes=False) for c in ast.parse(s).body if isinstance(c,ast.ClassDef) for m in c.body if isinstance(m,ast.FunctionDef) and m.name.startswith('test_')}
om=methods(oldtest);nm=methods((root/'tools/test_studio_gui_pointer.py').read_text());assert len(om)==21;assert all(nm[k]==v for k,v in om.items());assert len(nm)==25
hand=json.loads((root/'build/forest_revision04/mobile-actions-Q/handoff.json').read_text());shas={}
for r in hand['owned_source_files']:
 p=root/r['path'];s=hashlib.sha256(p.read_bytes()).hexdigest();assert s==r['sha256'];shas[r['path']]=s
prov=json.loads((root/'tests/fixtures/studio_gui_pointer/provenance.json').read_text())['files'][-1];assert (root/'tests/fixtures/studio_gui_pointer'/prov['fixture']).read_bytes()==(root/prov['original_path']).read_bytes()
cli=json.loads((root/'build/forest_revision04/mobile-actions-Q/AST-preservation.json').read_text())['original6CLI_bytes_preserved'];assert all(hashlib.sha256((root/r['path']).read_bytes()).hexdigest()==r['sha256'] for r in cli)
pixels=(root/'tests/fixtures/studio_gui_pointer/actions_Q_mobile.png').read_bytes();box=(211,145,316,178)
header='level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n';tsv=header+''.join(f'5\t1\t{i}\t1\t1\t1\t20\t{i*30}\t90\t12\t95\tACTIONS\n' for i in (1,2))
with tempfile.TemporaryDirectory() as d, patch.object(h,'_studio_button_boxes',return_value=[box]),patch('subprocess.run',return_value=SimpleNamespace(stdout=tsv)),patch.object(h,'_studio_button_inner_fill',side_effect=RuntimeError('fallback must not be entered')):
 try:h._studio_actions_from_pixels(pixels,pathlib.Path(d),'ambiguous',{})
 except AssertionError as e:assert 'found 2' in str(e)
 else:raise AssertionError('ambiguity accepted')
im=Image.open(io.BytesIO(pixels)).convert('RGB');assert h._studio_button_inner_fill(im,box)==(214,148,313,175)
ImageDraw.Draw(im).rectangle((248,148,285,149),fill=(130,155,119));assert h._studio_button_inner_fill(im,box) is None
r={'all_static_checks_passed':True,'source_sha256':shas,'original_functions_changed':changed,'original21_testmethods_ast_equal':True,'original6CLI_sha_equal':True,'fixture_equals_original_failed_Q_observer_png':True,'extra_controls':{'first_pass_ambiguity_raises_before_inner_fallback':True,'missing_inner_top_fill_boundary_rejected_with_actual_glyphs_retained':True}}
(out/'mobile_actions_independent_audit.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
