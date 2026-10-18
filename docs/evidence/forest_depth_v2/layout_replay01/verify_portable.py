"""Offline checks only. No Godot, subprocess, game loading or writes."""
from pathlib import Path
import ast,copy,gzip,hashlib,json,math
ROOT=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
index=json.loads((ROOT/'members.json').read_text());n=0
for row in index['files']:
 p=ROOT/row['path'];assert p.resolve().is_relative_to(ROOT) and not p.is_symlink();b=p.read_bytes();assert sha(b)==row['sha256'] and len(b)==row['bytes'];original=gzip.decompress(b)if row['encoding']=='gzip'else b
 if 'original_sha256'in row:assert sha(original)==row['original_sha256']and len(original)==row['original_bytes']
 n+=1
for name in ['full-2063-source-inventory.json','full-2063-snapshot-receipt.json']:assert len(json.loads((ROOT/'snapshot'/name).read_text()).get('source_files',{})or json.loads((ROOT/'snapshot'/name).read_text()))==2063
raw=gzip.decompress((ROOT/'native/capture.json.gz').read_bytes());data=json.loads(raw);assert data['assertions']==126 and data['failures']==0 and len(data['cases'])==14
prov=json.loads((ROOT/'tests/fixtures/forest_recorded_layouts/provenance.json').read_text())
for k,p in [('v7_root00_map2','old-v7-capture.json.gz'),('v9_root00_map2_before_north','old-v9-capture.json.gz')]:
 r=prov[k];old=gzip.decompress((ROOT/'raw-originals'/p).read_bytes());assert sha(old)==r['original_capture_sha256'];f=ROOT/r['fixture'];assert sha(f.read_bytes())==r['fixture_sha256']and json.loads(f.read_text())==json.loads(old)['manifest']
def load_reader(path):
 t=ast.parse(path.read_text());f=[n for n in t.body if isinstance(n,ast.FunctionDef)and n.name in ['validate','validate_current']];g={'ROOT':ROOT,'json':json,'hashlib':hashlib,'math':math};exec(compile(ast.Module(body=f,type_ignores=[]),'portable-reader-functions','exec'),g);return g
current=load_reader(ROOT/'independent/reader-delta03/reader.py.txt');old=load_reader(ROOT/'native-source/tools/run_forest_depth_versions.py.txt');current['validate_current'](data)
try:old['validate_current'](data);raise AssertionError('original failed reader unexpectedly accepted')
except ValueError as e:assert 'Unexpected/missing native cases'in str(e)
mutants=[]
for field,value in [('version','bad-version'),('map_index',1),('manifest_hash','0'*64)]:
 z=copy.deepcopy(data);next(r for r in z['cases']if r['id']=='canopy_content_contract')['manifest'][field]=value
 try:current['validate_current'](z);raise AssertionError('identity mutation accepted')
 except ValueError:mutants.append(field)
for name,value in [('bool-as-number',0),('nonfinite',float('nan'))]:
 z=copy.deepcopy(data);r=next(r for r in z['cases']if r['id']=='canopy_content_contract')
 if name=='bool-as-number':r['manifest']['boss_geometry']['platforms'][0]['one_way']=value
 else:r['manifest']['boss_geometry']['safe_return'][0]=value
 r['geometry_from_resource']=copy.deepcopy(r['manifest']['boss_geometry'])
 try:current['validate_current'](z);raise AssertionError('coherent mutation accepted')
 except ValueError:mutants.append(name)
assert json.loads((ROOT/'host/receipt.json').read_text())['exit_code']==1
print(json.dumps({'scope':'offline selected portable artifact/readers only, not new native result','indexed_members_verified':n,'native126_original_outerFAIL_preserved':True,'delta03_fixed_case_accepted':True,'independent_mutants_rejected':mutants},indent=2))
