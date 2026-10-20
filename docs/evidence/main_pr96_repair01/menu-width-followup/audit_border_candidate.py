import ast,json,hashlib,subprocess,time,sys
from pathlib import Path
from collections import Counter
from PIL import Image,ImageDraw
R=Path.cwd();out=R/'build/forest_revision04/main-M-review/menu-width-followup';b=R/'build/forest_revision04/menu-border-U';U='e4b2132dd30bf8ca176a28eb79d1b32a65bb59e3';sha=lambda x:hashlib.sha256(x).hexdigest()
handoff=json.loads((b/'handoff.json').read_text())
for x in handoff['source_files']:data=(R/x['path']).read_bytes();assert len(data)==x['bytes'] and sha(data)==x['sha256']
old=subprocess.check_output(['git','show',U+':tools/studio_gui_pointer.py']);new=(R/'tools/studio_gui_pointer.py').read_bytes();assert sha(old)=='c72234698687d25b8dec588dfbd7d87b32b1516e1f1cf4f584a0b157146cc316' and sha(new)=='80e96f99549b0da9cc56a44964dbc6574875fa2450ae66f7409af284850f566d';assert old==(b/'studio_gui_pointer-original.py').read_bytes()
a=ast.parse(old);c=ast.parse(new);fa={x.name:x for x in a.body if isinstance(x,(ast.FunctionDef,ast.AsyncFunctionDef))};fc={x.name:x for x in c.body if isinstance(x,(ast.FunctionDef,ast.AsyncFunctionDef))};changed=[k for k in fa if ast.dump(fa[k])!=ast.dump(fc[k])];assert changed==['_studio_button_boxes']
# Border acceptance and every OCR/gesture/readiness helper remain original.
assert old.decode().split('  direction=np.asarray(color,',1)[1]==new.decode().split('  direction=np.asarray(color,',1)[1]
prov=json.loads((R/'tests/fixtures/studio_gui_pointer/provenance.json').read_text())
for x in prov['files']:
 f=R/'tests/fixtures/studio_gui_pointer'/x['fixture'];assert f.read_bytes()==(R/x['original_path']).read_bytes() and sha(f.read_bytes())==x['sha256'] and f.stat().st_size==x['bytes']
im=Image.open(R/'tests/fixtures/studio_gui_pointer/menu_U_complete.png').convert('RGB');rank=[x[0]for x in Counter(im.getdata()).most_common()].index(im.getpixel((254,285)))+1;assert rank==84
sys.path.insert(0,str(R/'tools'));import studio_gui_pointer as helper
controls=[]
for color in [(12,160,220),(220,49,80),(130,155,119)]:
 image=Image.new('RGB',(420,400),(9,3,7));draw=ImageDraw.Draw(image);draw.rectangle((113,144,310,190),outline=color)
 boxes=helper._studio_button_boxes(image);assert boxes==[(111,142,313,193)],(color,boxes);controls.append({'kind':'translated arbitrary RGB rectangle','rgb':color,'boxes':boxes})
image=Image.new('RGB',(800,1000),(9,3,7));draw=ImageDraw.Draw(image)
for i in range(33):x=10+(i%3)*220;y=10+(i//3)*80;draw.rectangle((x,y,x+190,y+40),outline=(130,155,119))
try:helper._studio_button_boxes(image)
except AssertionError as e:assert 'More than 32'in str(e);controls.append({'kind':'33closed rectangles','rejected':str(e)})
else:raise AssertionError('complexity cap bypassed')
log=out/'independent-border-eight-tests.log';start=time.monotonic()
with log.open('w')as f:result=subprocess.run([sys.executable,'tools/test_studio_gui_pointer.py'],stdout=f,stderr=subprocess.STDOUT,timeout=60)
assert result.returncode==0 and 'Ran 8 tests'in log.read_text() and log.read_text().rstrip().endswith('OK')
report={'decision':'SCOPED_ACCEPT_CODE_AND_PURE_PIXEL_PARSER','base_U':U,'helper_SHA256':sha(new),'changed_functions':changed,'unchanged_function_AST_count':len(fa)-1,'original_geometry_acceptance_and_all_later_source_exact':True,'new_source_manifest_all_SHA_match':True,'fixtures_byte_exact_originals':True,'actual_U_border_palette_rank':rank,'independent_additional_controls':controls,'independent_original_eight_suite':{'exit_code':0,'seconds':time.monotonic()-start,'log':str(log.relative_to(R)),'log_sha256':sha(log.read_bytes())},'original_helper_same_tests_failure':json.loads((b/'unit-original-helper.json').read_text()),'original_U_browser_FAILURE':'Preserved; not retrospectively passed by pure screenshot parsing.','future_live_browser':'pending; no native/browser/network in independent audit.'}
(out/'border_candidate_independent_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items()if k not in ['independent_additional_controls']},ensure_ascii=False))
