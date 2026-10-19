from pathlib import Path
import json,hashlib,copy,ast,subprocess,math
R=Path.cwd();O=R/'build/independent/layout-replay01/reader-delta03';p=R/'tools/run_forest_depth_versions.py';src=p.read_text();before=hashlib.sha256(p.read_bytes()).hexdigest();t=ast.parse(src);fns=[n for n in t.body if isinstance(n,ast.FunctionDef)and n.name in ['validate','validate_current']];g={'ROOT':R,'json':json,'hashlib':hashlib,'math':math};exec(compile(ast.Module(body=fns,type_ignores=[]),'delta03-frozen-reader','exec'),g);old=(R/'build/forest_depth/snapshots/forest-layout-replay01/tools/run_forest_depth_versions.py').read_text();get=lambda s:ast.dump(next(n for n in ast.parse(s).body if isinstance(n,ast.FunctionDef)and n.name=='validate'),include_attributes=False);assert get(src)==get(old)
main_at=lambda source:next(n for n in ast.parse(source).body if isinstance(n,ast.FunctionDef) and n.name=='main')
assert ast.dump(main_at(src),include_attributes=False)==ast.dump(main_at(old),include_attributes=False)
old_git=subprocess.check_output(['git','show','dd214ddec4394758d3d3efb71d604b86b7fdb7a3:tools/run_forest_depth_versions.py'],text=True)
new_main=main_at(src)
for node in ast.walk(new_main):
 if isinstance(node,ast.Name) and node.id=='validate_current':node.id='validate'
assert ast.dump(new_main,include_attributes=False)==ast.dump(main_at(old_git),include_attributes=False)
raw=R/'build/forest_depth/snapshots/forest-layout-replay01/build/forest_depth/versions/layout-replay01/capture.json';d=json.loads(raw.read_text());g['validate_current'](d);fixture=R/'tests/fixtures/forest_recorded_layouts/expected_canopy_v10.json';f=json.loads(fixture.read_text());getrow=lambda z:next(r for r in z['cases']if r['id']=='canopy_content_contract');canonical=lambda z:json.dumps(z,sort_keys=True,allow_nan=False,separators=(',',':'));assert canonical(f)==canonical(getrow(d)['manifest']);assert hashlib.sha256(fixture.read_bytes()).hexdigest()=='06b98b7e95ae39ffa23a4dcd6cf6a64d794e51ce5ef50f1048a3b8b6f700686c'
prov=json.loads((R/'tests/fixtures/forest_recorded_layouts/provenance.json').read_text())['expected_canopy_v10'];assert prov['original_capture_sha256']==hashlib.sha256(raw.read_bytes()).hexdigest() and prov['fixture_sha256']==hashlib.sha256(fixture.read_bytes()).hexdigest()
def coh(z,key,val):
 r=getrow(z);r['manifest']['boss_geometry'][key]=val;r['geometry_from_resource']=copy.deepcopy(r['manifest']['boss_geometry'])
def boolnum(z):
 r=getrow(z);r['manifest']['boss_geometry']['platforms'][0]['one_way']=0;r['geometry_from_resource']=copy.deepcopy(r['manifest']['boss_geometry'])
def nan_both(z):
 r=getrow(z);r['manifest']['boss_geometry']['safe_return'][0]=float('nan');r['geometry_from_resource']=copy.deepcopy(r['manifest']['boss_geometry'])
mutants=[('version',lambda z:getrow(z)['manifest'].update(version='not-a-forest-version')),('map_index',lambda z:getrow(z)['manifest'].update(map_index=1)),('manifest_hash',lambda z:getrow(z)['manifest'].update(manifest_hash='0'*64)),('seed',lambda z:getrow(z)['manifest'].update(seed='another-seed')),('region',lambda z:getrow(z)['manifest'].update(region='plains')),('coherent_bool_to_zero',boolnum),('coherent_NaN',nan_both),('row_geometry_bool_only',lambda z:getrow(z)['geometry_from_resource']['platforms'][0].update(one_way=0)),('coherent_reward_shift',lambda z:coh(z,'reward_position',[getrow(z)['manifest']['boss_geometry']['reward_position'][0]+20,getrow(z)['manifest']['boss_geometry']['reward_position'][1]])),('coherent_full_geometry_shift',lambda z:coh(z,'origin',[0,0])),('missing_new_case',lambda z:z['cases'].remove(getrow(z))),('old_ledger_false',lambda z:z['checks'][0].update(passed=False)),('old_rebuilt_hash',lambda z:next(r for r in z['cases']if r['id']=='recorded_depth_layout')['rebuilt'].update(manifest_hash='0'*64))]
rows=[]
for n,fn in mutants:
 z=copy.deepcopy(d);fn(z);err=None
 try:g['validate_current'](z)
 except Exception as e:err=type(e).__name__+': '+str(e)
 assert err,n;rows.append({'case':n,'rejected':True,'error':err})
outer=json.loads((R/'build/forest_depth/root/layout-replay01/receipt.json').read_text());assert outer['exit_code']==1
assert before==hashlib.sha256(p.read_bytes()).hexdigest()
(O/'reader.py.txt').write_text(src);(O/'expected_canopy_v10.json.txt').write_bytes(fixture.read_bytes());res={'status':'CONTINUE_BOUNDED_CURRENT_READER_FIXED_CASE','scope':'Offline fixed version-canopy-current full JSON-value binding only; not general Godot manifest hash recreation','reader_sha256':before,'fixture_sha256':hashlib.sha256(fixture.read_bytes()).hexdigest(),'original_raw_sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'fixture_entire_actual_manifest_type_sensitive_equal':True,'original_validate_AST_unchanged':True,'original_wrapper_main_AST_exact_after_only_reader_dispatch_rename':True,'unchanged_actual126_capture_accepted':True,'independent_mutants':rows,'original_outer_exit1_preserved':True,'native_run':False,'preserved_reviews':['../REVIEW.md','../reader-delta02/REVIEW.md'],'limits':['No new native/wrapper PASS','No new Queen mechanics/natural entry/closed-seal App seam approval','No all194 or current fullCI or player fun claim']};(O/'review.json').write_text(json.dumps(res,indent=2)+'\n');print(json.dumps({'status':res['status'],'rejected':len(rows),'reader_sha256':before},indent=2))
