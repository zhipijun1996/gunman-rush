from pathlib import Path
import json,ast,subprocess,hashlib,time,sys,io,tempfile
from PIL import Image,ImageDraw
R=Path.cwd();out=R/'build/forest_revision04/main-M-review/menu-width-followup';base=R/'build/forest_revision04/mobile-title-P';P='09f09f99d8d3c2a6a1e3ff6edd4a3147814e4b58';sha=lambda b:hashlib.sha256(b).hexdigest();h=json.loads((base/'handoff.json').read_text())
for x in h['owned_paths']:b=(R/x['path']).read_bytes();assert len(b)==x['bytes'] and sha(b)==x['sha256']
old=subprocess.check_output(['git','show',P+':tools/studio_gui_pointer.py']);new=(R/'tools/studio_gui_pointer.py').read_bytes();assert sha(new)=='2c17f6d06af3bcbb0308cd8c7590684cce289351c6de125a229b033c2d466894'
def funcs(b):return {n.name:n for n in ast.parse(b).body if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef))}
a=funcs(old);b=funcs(new);assert [k for k in a if ast.dump(a[k])!=ast.dump(b[k])]==['enter_action_studio'];assert set(b)-set(a)=={'_studio_title_from_pixels'}
# Reverse exactly the one dispatch statement to compare whole original enter AST.
f=b['enter_action_studio'];changed=0
for n in ast.walk(f):
 if isinstance(n,ast.Assign)and isinstance(n.value,ast.IfExp)and isinstance(n.value.body,ast.Call)and isinstance(n.value.body.func,ast.Name)and n.value.body.func.id=='_studio_title_from_pixels':n.value=n.value.orelse;changed+=1
assert changed==1 and ast.dump(f)==ast.dump(a['enter_action_studio'])
def tests(raw):return {(c.name,n.name):n for c in ast.parse(raw).body if isinstance(c,ast.ClassDef) for n in c.body if isinstance(n,ast.FunctionDef)and n.name.startswith('test_')}
a=tests(subprocess.check_output(['git','show',P+':tools/test_studio_gui_pointer.py']));b=tests((R/'tools/test_studio_gui_pointer.py').read_bytes());assert len(a)==15 and len(b)==21 and all(ast.dump(n)==ast.dump(b[k])for k,n in a.items())
for x in json.loads((base/'AST-preservation.json').read_text())['original6CLI_bytes_preserved']:assert sha((R/x['path']).read_bytes())==x['sha256'] and(R/x['path']).read_bytes()==subprocess.check_output(['git','show',P+':'+x['path']])
prov=json.loads((R/'tests/fixtures/studio_gui_pointer/provenance.json').read_text())
for x in prov['files']:assert(R/'tests/fixtures/studio_gui_pointer'/x['fixture']).read_bytes()==(R/x['original_path']).read_bytes() and sha((R/x['original_path']).read_bytes())==x['sha256']
sys.path.insert(0,str(R/'tools'));import studio_gui_pointer as helper
nav=R/h['original_actual_browser_failure']['raw_navigation'];im=Image.open(nav/'title-0.png').convert('RGB');tsv=(nav/'title-0.tsv').read_text();assert sha(tsv.encode())==h['original_actual_browser_failure']['original_tsv_sha256']
def locate(image,whole=tsv):
 raw=io.BytesIO();image.save(raw,format='PNG');o={}
 with tempfile.TemporaryDirectory()as d:return helper._studio_title_from_pixels(raw.getvalue(),Path(d),'independent',o,whole),o
actual,ob=locate(im);assert actual==(509.5,262) and ob['whole_frame_title']=='missing'
controls=[]
# Original unique fullframe path succeeds without any validimage or ROIwork.
header='level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n';row='5\t1\t1\t1\t1\t1\t30\t60\t300\t30\t99\tDEVELOPMENT DEMOS / ALL ENTRIES\n'
with tempfile.TemporaryDirectory()as d:
 result=helper._studio_title_from_pixels(b'invalidimage',Path(d),'x',{},header+row);assert result==(60,25);controls.append({'name':'originalwholeframeuniqueinvalidimage','result':'originalpoint withoutROI'})
# Crop only blank rightside ofbutton; alloriginalEnglishglyphs remain visible.
try:locate(im.crop((0,0,620,390)))
except helper.StudioMenuLabelMissing:controls.append({'name':'cropblankrightbuttonedgekeepallglyphs','result':'rejected'})
else:raise AssertionError('croppedrightfillaccepted')
translated=im.copy();crop=im.crop((429,249,632,275));ImageDraw.Draw(translated).rectangle((429,249,631,274),fill=(9,4,7));translated.paste(crop,(50,310));point,_=locate(translated);assert point==(130.5,323);controls.append({'name':'moveactualbutton379left61down','result':'actualpoint130.5,323 derived'})
labelonly=Image.new('RGB',im.size,(3,7,11));labelonly.paste(im.crop((437,259,584,265)),(437,259))
try:locate(labelonly,'')
except helper.StudioMenuLabelMissing:controls.append({'name':'actualcompleteglyphswithoutbuttonfill','result':'rejected'})
else:raise AssertionError('nonbuttontextfallbackaccepted')
# Confirm actualfour-fill-boundary fact without inventing rightstroke.
assert im.getpixel((630,262))==(16,24,25) and im.getpixel((631,262))==(9,4,7) and im.getpixel((429,262))==(82,96,75)
start=time.monotonic();log=out/'independent-title-twentyone-tests.log'
with log.open('w')as stream:run=subprocess.run([sys.executable,'tools/test_studio_gui_pointer.py'],stdout=stream,stderr=subprocess.STDOUT,timeout=90)
assert run.returncode==0 and'Ran 21 tests'in log.read_text()and log.read_text().rstrip().endswith('OK')
result={'decision':'SCOPED_ACCEPT_CODE_AND_PURE_PIXEL_PROOF','base_P':P,'helper_SHA256':sha(new),'all4manifest_files_and_fixturebytes_verified':True,'only_original_function_changed':'enter_action_studio oneTITLEdispatch; reversing exactnode makesASTidentical','other10helpers_AST_unchanged':True,'original15testmethods_AST_equal':True,'original6CLIs_exact':True,'direct_actualP_failedTSV_replay_point':actual,'actual_fillboundary_facts':{'innerRGB':[16,24,25],'leftstrokeRGB':[82,96,75],'rightoutsideRGB':[9,4,7],'four_strokes_claimed':False},'independent_additional_controls':controls,'independent21pure':{'exit_code':0,'seconds':time.monotonic()-start,'log':str(log.relative_to(R)),'SHA256':sha(log.read_bytes())},'limits':['OnlyrealPmobilePNG andpurecontrols; no actualtouchclick/Studioevent/popup/gameplay acceptance.','OriginalPfirst201.741sFAIL and5wholeframemisses retained.','Fullframeambiguity remainsfatal; original5observations/300CLI budgets unchanged.'],'reviewer_activity':'PureAST/hash/PIL/Tesseract andnewignoredreport only; no browser/native/network/trackedwrite.'}
(out/'title_candidate_independent_audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps(result,ensure_ascii=False))
