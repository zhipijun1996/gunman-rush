from pathlib import Path
import ast,json,hashlib,subprocess,sys,time
from PIL import Image,ImageDraw
R=Path.cwd();out=R/'build/forest_revision04/main-M-review/menu-width-followup';b=R/'build/forest_revision04/popup-pixels-W';W='5a4d0da86fb217415aeb80c7c2a618ec2565b35b';sha=lambda b:hashlib.sha256(b).hexdigest();h=json.loads((b/'handoff.json').read_text())
for r in h['source_files']:data=(R/r['path']).read_bytes();assert len(data)==r['bytes'] and sha(data)==r['sha256']
old=subprocess.check_output(['git','show',W+':tools/studio_gui_pointer.py']);new=(R/'tools/studio_gui_pointer.py').read_bytes();assert sha(new)=='b02e6aef03c65d21f8d8222593c95e3f35be0819dd6d4cdeffa64d0a3db77402'
def functions(t):return {n.name:n for n in ast.parse(t).body if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef))}
f=functions(old);g=functions(new);assert [k for k in f if ast.dump(f[k])!=ast.dump(g[k])]==['open_weapon_picker'];assert set(g)-set(f)=={'_weapon_popup_from_pixels'}
def tests(t):return {n.name:n for c in ast.parse(t).body if isinstance(c,ast.ClassDef) for n in c.body if isinstance(n,ast.FunctionDef) and n.name.startswith('test_')}
a=tests(subprocess.check_output(['git','show',W+':tools/test_studio_gui_pointer.py']));c=tests((R/'tools/test_studio_gui_pointer.py').read_bytes());assert len(a)==8 and len(c)==15 and all(ast.dump(n)==ast.dump(c[k])for k,n in a.items())
p=json.loads((R/'tests/fixtures/studio_gui_pointer/provenance.json').read_text())
for r in p['files']:
 x=R/'tests/fixtures/studio_gui_pointer'/r['fixture'];assert x.read_bytes()==(R/r['original_path']).read_bytes() and len(x.read_bytes())==r['bytes'] and sha(x.read_bytes())==r['sha256']
for row in json.loads((b/'AST-preservation.json').read_text())['original_CLI_bytes_preserved']:
 assert sha((R/row['path']).read_bytes())==row['unchanged_sha256'];assert (R/row['path']).read_bytes()==subprocess.check_output(['git','show',W+':'+row['path']])
sys.path.insert(0,str(R/'tools'));import studio_gui_pointer as helper
image=Image.open(R/'tests/fixtures/studio_gui_pointer/popup_W_green.png').convert('RGB');actual=helper._weapon_popup_from_pixels(image,1,197);assert actual['marker_x']==59.5 and actual['rows']==[218.5+29*i for i in range(15)]
controls=[]
# Arbitrary actual-pixel palette remap, preserving shapes; does not mutate raw fixture.
im=image.copy();pixels=list(im.getdata());mapping={(27,38,37):(22,43,81),(82,96,75):(201,109,75)};im.putdata([mapping.get(x,x)for x in pixels]);got=helper._weapon_popup_from_pixels(im,1,197);assert got['rows']==actual['rows'] and got['marker_x']==actual['marker_x'];controls.append({'name':'non-green non-gray palette remap','result':'sameactual15centers'})
# Translate complete observed popup without any runtimecoordinate fallback.
im=image.copy();crop=image.crop((35,190,287,655));ImageDraw.Draw(im).rectangle((35,190,286,654),fill=(3,7,11));im.paste(crop,(400,200));got=helper._weapon_popup_from_pixels(im,1,197);assert got['marker_x']==424.5 and got['rows']==[x+10 for x in actual['rows']];controls.append({'name':'observedpopuptranslated365right10down','result':'derivedx424.5+allrows10down'})
# Constant rectangles at each row must not satisfy round silhouette.
im=image.copy();draw=ImageDraw.Draw(im)
for i in range(15):top=212+29*i;draw.rectangle((53,top,66,top+13),fill=(26,31,31))
try:helper._weapon_popup_from_pixels(im,1,197)
except AssertionError:controls.append({'name':'15squarefakeiconsretaintext','result':'rejected'})
else:raise AssertionError('squareiconsaccepted')
for edge,rect in [('top',(34,189,287,194)),('bottom',(34,651,287,656)),('left',(34,190,39,654)),('right',(282,190,287,654))]:
 im=image.copy();ImageDraw.Draw(im).rectangle(rect,fill=(3,7,11))
 try:helper._weapon_popup_from_pixels(im,1,197)
 except AssertionError:controls.append({'name':'removedactualpanel_'+edge,'result':'rejected'})
 else:raise AssertionError('openpanelframeaccepted '+edge)
start=time.monotonic();log=out/'independent-popup-fifteen-tests.log'
with log.open('w')as f:run=subprocess.run([sys.executable,'tools/test_studio_gui_pointer.py'],stdout=f,stderr=subprocess.STDOUT,timeout=60)
assert run.returncode==0 and 'Ran 15 tests'in log.read_text() and log.read_text().rstrip().endswith('OK')
report={'decision':'SCOPED_ACCEPT_CODE_AND_PURE_PIXEL_PROOF','base_commit':W,'helper_SHA256':sha(new),'original9helper_AST_unchanged':True,'changed_original_function':'open_weapon_picker','added_pure_function':'_weapon_popup_from_pixels','original8tests_AST_unchanged':True,'tests_now':15,'original6CLIs_byte_exact':True,'allmanifest_and_originalfixture_SHA_verified':True,'actualrawpopup_result':actual,'independent_additional_controls':controls,'independent15puretests':{'exit':0,'seconds':time.monotonic()-start,'log':str(log.relative_to(R)),'log_sha256':sha(log.read_bytes())},'actualW_browser_original':'FAIL57.607s and0actionchecks/2laterconsumers notrun retained. PureasyncScreenshotPage is not actualbrowserclick orweapon_equipped proof.','scope_limits':['ActualrawWdesktoppopup+purecontrols only; no15actualequippedIDs/newbrowser claim.','Exactcenter grouping/roundness atotherbrowserzoom/noninteger/touchscales notproved bythisoneactualdesktopPNG.','No newgeneralperformanceclaim.'],'reviewer_activity':'PureAST/bytes/PIL/numpy tests andnewignoredreports; no browser/native/network/trackedwrites.'}
(out/'popup_candidate_independent_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items()if k not in ['actualrawpopup_result','independent_additional_controls']},ensure_ascii=False))
