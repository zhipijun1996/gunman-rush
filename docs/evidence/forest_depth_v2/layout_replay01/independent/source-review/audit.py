from pathlib import Path
import json,hashlib,ast,subprocess,re,copy,sys
R=Path.cwd();O=R/'build/independent/layout-replay01';S=R/'build/forest_depth/snapshots/forest-layout-replay01';D=S/'build/forest_depth/versions/layout-replay01';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();raw=D/'capture.json';d=json.loads(raw.read_text());assert d['assertions']==126 and d['failures']==0 and len(d['checks'])==126 and all(x['passed']is True for x in d['checks'])and len(d['cases'])==14
sr=json.loads((S/'build/snapshot-receipt.json').read_text());assert sr['source_copy_guard'] and len(sr['source_files'])==2063 and all(sha(S/p)==h for p,h in sr['source_files'].items())
log=(D/'native.log').read_text();assert '4.7.2' in log and re.search(r'FOREST DEPTH VERSIONS: 126 assertions, 0 failures',log)and not re.search(r'(?m)^ERROR:|SCRIPT ERROR:|Parse Error:|ObjectDB.*leaked|resources? still in use at exit',log)
outer=json.loads((R/'build/forest_depth/root/layout-replay01/receipt.json').read_text());assert outer['exit_code']==1 and outer['full_source_guard']
proof=json.loads((O/'frozen-source-and-fixture-proof.json').read_text());
for row in [x for x in d['cases']if x['id']=='recorded_depth_layout']:
 f=R/'tests/fixtures/forest_recorded_layouts'/row['fixture'];v=json.loads(f.read_text());assert row['original']==v==row['rebuilt']and sha(f)==row['fixture_sha256']
# Read precise copied pre-fix reader so later author edits cannot silently retag this result.
reader=O/'source/tools/run_forest_depth_versions.py.txt';t=reader.read_text();old=subprocess.check_output(['git','show','HEAD:tools/run_forest_depth_versions.py'],text=True);get=lambda s:ast.dump(next(n for n in ast.parse(s).body if isinstance(n,ast.FunctionDef)and n.name=='validate'),include_attributes=False);assert get(t)==get(old)
module=ast.parse(t);functions=[n for n in module.body if isinstance(n,ast.FunctionDef)and n.name in ['validate','validate_current']];g={'ROOT':R,'hashlib':hashlib,'json':json,'math':__import__('math')};exec(compile(ast.Module(body=functions,type_ignores=[]),'reviewed-reader','exec'),g)
try:g['validate'](d);raise AssertionError('old reader should reject 14')
except ValueError as e:assert 'Unexpected/missing native cases' in str(e)
g['validate_current'](d)
mut=[]
for name,fn in [('deleted_new_case',lambda z:z['cases'].pop()),('old_case_failure_ledger',lambda z:z['checks'][0].update(passed=False)),('changed_full_old_manifest_hash',lambda z:next(r for r in z['cases']if r['id']=='recorded_depth_layout')['rebuilt'].__setitem__('manifest_hash','0'*64)),('duplicate_old_fixture',lambda z:[r for r in z['cases']if r['id']=='recorded_depth_layout'][1].__setitem__('fixture','v7_root00_map2.json'))]:
 z=copy.deepcopy(d);fn(z);err=None
 try:g['validate_current'](z)
 except Exception as e:err=str(e)
 assert err;mut.append({'case':name,'rejected':True,'error':err})
miss=[]
for field,value in [('version','not-a-forest-version'),('map_index',1),('manifest_hash','0'*64)]:
 z=copy.deepcopy(d);next(r for r in z['cases']if r['id']=='canopy_content_contract')['manifest'][field]=value;err=None
 try:g['validate_current'](z)
 except Exception as e:err=str(e)
 assert err is None;miss.append({'field':field,'accepted':True})
paths=['scripts/generation/thorn_forest_region_v2_v7.gd','scripts/generation/thorn_forest_region_v2_v9.gd','scripts/generation/thorn_forest_region_generator.gd','scripts/demo/demo_app.gd','scripts/demo/thorn_forest_region_stage.gd','scripts/run/run_manifest.gd','scripts/generation/forest_boss_arena_factory.gd','scripts/generation/thorn_forest_region_v2.gd']
res={'status':'BOUNDED_PRODUCTION_COMPATIBILITY_CONTINUE_NEW_READER_IDENTITY_REVISE','scope':'Version/hash dispatch and compatibility plumbing only, not new Queen mechanics/App seams','native_run':False,'original_native':{'capture_sha256':sha(raw),'actual126_ledger14cases':True,'strictclean4_7_2':True,'complete2063_snapshot_SHA_verified':True,'outer_exit1_preserved':True,'old_original_reader_rejects14':True,'current_reader_accepts_same_raw_offline_only':True,'seconds':outer['seconds']},'old_full_manifest_rebuilds':proof,'old_validate_AST_exact':True,'old_failure_and_missing_case_controls':mut,'reader_identity_holes':miss,'reviewed_reader_sha256':sha(reader),'source_bindings':{p:sha(O/'source'/str(Path(p).parent)/(Path(p).name+'.txt'))for p in paths},'limits':['Old actual manifest generation reconstruction is not actual old-v7/v9 App reload','New canopy entry/reward supports are offline data checks, not natural App walk/closed-seal reload','Default remains registryv9; privatev10 not promoted','No 194/fullCI/fun or new Queen save mechanics approval']}
(O/'review.json').write_text(json.dumps(res,indent=2)+'\n');print(json.dumps({'status':res['status'],'old_proofs':True,'reader_holes':miss},indent=2))
