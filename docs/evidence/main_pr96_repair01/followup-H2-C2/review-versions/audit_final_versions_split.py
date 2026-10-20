from pathlib import Path
import sys,json,copy,ast,hashlib,subprocess,importlib.util,zipfile
sys.path.insert(0,'tools');import run_forest_depth_versions as v
R=Path.cwd();O=Path('build/forest_revision04/forest-versions-review');D=Path('build/forest_depth/versions/split-C2-positive-r3').resolve();N=Path('build/forest_depth/versions/split-C2-failure-probe-r2');S=Path('build/forest_revision04/versions-split-C2');B='3affbc89011bce1ef206ce377f9ebdfc724880d4'
def load(p):return json.loads(Path(p).read_text())
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def exact(a,b,p=''):
 assert type(a) is type(b),p+':type'
 if isinstance(a,dict):
  assert a.keys()==b.keys(),p+':keys'
  for k in a:exact(a[k],b[k],p+'/'+k)
 elif isinstance(a,list):
  assert len(a)==len(b),p+':length'
  for i,(x,y) in enumerate(zip(a,b)):exact(x,y,p+'/'+str(i))
 else:assert a==b,p+':value'
top=load(D/'receipt.json');sources=top['verifier_before'];assert top['passed'] and top['source_guard'] and top['source_before']==top['source_after'] and sources==top['verifier_after']
assert sources==v.verifier_identity() and top['base_commit']==B and top['original_shared_native_cap_seconds']==top['original_import_cap_seconds']==90
reports={p:load(D/(p+'.json')) for p in v.PHASES};receipts={p:load(D/(p+'-receipt.json')) for p in v.PHASES}
combined=v.aggregate(reports,receipts,top['run_id'],sources,D);actual=load(D/'capture.json');exact(combined,actual)
old=load('build/forest_depth/versions/diagnosis-C2-verbose/capture.json')
for k in ['assertions','failures','engine','cases','checks','exit_lifecycle']:exact(actual[k],old[k],'/'+k)
assert len(actual['checks'])==327 and len(actual['cases'])==24
# All original Python validators and imports/constants remain unchanged before protocol additions.
original=subprocess.check_output(['git','show',B+':tools/run_forest_depth_versions.py'],text=True);current=Path('tools/run_forest_depth_versions.py').read_text();assert original[:original.index('def main():')].strip()==current[:current.index('PHASES =')].strip()
oldGD=subprocess.check_output(['git','show',B+':tests/forest_depth_version_runner.gd'],text=True);newGD=Path('tests/forest_depth_version_runner.gd').read_text();assert oldGD[oldGD.index('func check_recorded_layouts('):]==newGD[newGD.index('func check_recorded_layouts('):]
helper='tests/forest_depth_version_app_case.gd';assert Path(helper).read_bytes()==subprocess.check_output(['git','show',B+':'+helper])
assert (reports['data']['assertions'],reports['world']['assertions'])==(280,47) and len(reports['data']['cases'])==22 and len(reports['world']['cases'])==2
exact(actual['checks'],reports['data']['checks'][:-4]+reports['world']['checks']+reports['data']['checks'][-4:])
assert top['native_elapsed_seconds']<90 and receipts['world']['timeout_seconds']<90 and receipts['data']['engine_pid']!=receipts['world']['engine_pid']
outer=load(S/'positive-r3-outer.json');negativeouter=load(S/'failure-probe-r2-outer.json');neg=load(N/'receipt.json');world=load(N/'world.json');data=load(N/'data.json');wr=load(N/'world-receipt.json')
assert outer['exit_code']==0 and outer['original_harness_cap_seconds']==210 and outer['source_guard'] and outer['extra_total_timer'] is None
assert negativeouter['exit_code']==1 and negativeouter['source_guard'] and negativeouter['no_success_aggregate'] and negativeouter['no_success_stdout']
assert not neg['passed'] and neg['source_guard'] and neg['source_before']==neg['source_after'] and neg['verifier_before']==neg['verifier_after']==sources
assert data['assertions']==280 and data['failures']==0 and world['assertions']==48 and world['failures']==1 and all(x['passed'] is True for x in world['checks'][:47]) and world['checks'][47]['passed'] is False
assert wr['exit_code']==1 and wr['status']=='failed' and not (N/'capture.json').exists()
for folder in [D,N]:
 for phase in ['data','world']:
  log=(folder/(phase+'.log')).read_text();assert not any(s in log for s in ['SCRIPT ERROR:','Parse Error:','SHADER ERROR:','ObjectDB instances','resources still in use','ERROR:'])
# Re-run independent original-source old guard counterexamples against exact preserved r2 source.
spec=importlib.util.spec_from_file_location('old_protocol',O/'protocol-before-typed-identity-fix.py');prior=importlib.util.module_from_spec(spec);spec.loader.exec_module(prior);prior.ROOT=R
assert sha(O/'protocol-before-typed-identity-fix.py')=='a4aec872419c4c59498f66d0f694d232397d2ee16e0d907aaecb6bf9ce19f9b2'
spec=importlib.util.spec_from_file_location('phase_tests','tools/test_forest_depth_versions.py');t=importlib.util.module_from_spec(spec);spec.loader.exec_module(t);t.NATIVE_DIR=Path('build/forest_depth/versions/split-C2-positive-r2').resolve();proofs=[]
for name in ['nested_PID_float','engine_major_float','both_engine_null']:
 c=t.NativeAggregationTests('test_exact_original327_and24');c.setUp()
 try:
  if name=='nested_PID_float':c.receipts['world']['native_identity']['engine_pid']=float(c.receipts['world']['engine_pid'])
  elif name=='engine_major_float':c.reports['world']['engine']['major']=float(c.reports['world']['engine']['major']);c.resign_report('world')
  else:
   for p in v.PHASES:c.reports[p]['engine']=None;c.resign_report(p)
  prior.aggregate(c.reports,c.receipts,c.run_id,c.sources,c.directory)
  try:v.aggregate(c.reports,c.receipts,c.run_id,c.sources,c.directory)
  except ValueError as e:proofs.append({'case':name,'old_actual_r2_guard_accepted':True,'final_guard_rejected':True,'reason':str(e)})
  else:raise AssertionError('Final accepts '+name)
 finally:c.doCleanups()
# Frozen delivery source index: five changed paths plus original read-only actual-App helper.
ix=load(S/'final-source-index.json')['files'];assert len(ix)==6
for row in ix:assert sha(row['path'])==row['sha256']
unit=load(O/'independent-final-python45.json');assert unit['tests_run']==45 and unit['failures']==unit['errors']==0
zipdir=Path('build/forest_revision04/versions-split-C2-delivery');idx=load(zipdir/'file-index.json');zp=zipdir/'versions-split-C2-selected.zip';assert zp.stat().st_size==9430184 and sha(zp)=='ef48ba4d95f9c3271e6cbdc74a138d84bc77f613cb621ae7c2f8edfd71c7f001'
with zipfile.ZipFile(zp) as z:
 assert len(z.namelist())==129 and z.testzip() is None
 rows=idx['files']
 for row in rows:
  data=z.read(row.get('archive_path',row.get('path')));assert hashlib.sha256(data).hexdigest()==row['sha256']
r={'decision':'SCOPED_ACCEPT__EXACT_FROZEN_TEST_TOOL_BLOBS','execution_base_commit':B,'tested_reviewed_source_sha256':{row['path']:row['sha256'] for row in ix},'read_only_original_App_helper':helper,'original_validators_prefix_byte_exact':True,'original_all_contract_GDScript_methods_byte_exact':True,'exact_original_assertions':327,'exact_original_cases':24,'all_case_and_check_values_types_engine_lifecycle_exact_original':True,'ledger_order':'data276 + actualApp47 + data localrelease4','native_domains':{'data_assertions':280,'world_assertions':47,'distinct_PIDs':[receipts[p]['engine_pid'] for p in v.PHASES],'actual_shared90_seconds':top['native_elapsed_seconds'],'world_remaining_seconds':receipts['world']['timeout_seconds'],'import90_unchanged':True,'original_manifest210_unchanged':True,'positive_outer_seconds':outer['seconds']},'actual_negative':{'outer_exit':1,'seconds':negativeouter['seconds'],'data280_kept':True,'world_original47true_then48false':True,'native_exit1':True,'source_guard':True,'aggregate_absent':True,'no_engine_leaks_errors':True},'independent_pure_checks':{'original45_tests':unit,'extra31_type_budget_identity_mutants_all_refused':True,'old_counterexamples_reproduced_on_exact_old_actual_source':proofs},'failed_history_preserved':['original combined327/0 exit223objects/150resources','runtime-comparator same327/24 and same223 leak, not a repair','r1 missing argv/sequence/PID/duration guards; r2 type-coercion and missing-engine artifact holes, preserved as REWORK','C2_domain_budget_erratum corrects preliminary180 to actual original210 without changing source'], 'delivery':{'sha256':sha(zp),'bytes':zp.stat().st_size,'members':129,'index_members_verified':len(rows)},'not_approved':['whole project CI/remaining49/merge or public deployment','same-process mixed data+world lifetime root fix','forest route/Boss/taste/device/user acceptance'],'reviewer_started_native_or_changed_tracked_source':False}
(O/'versions_split_final_audit.json').write_text(json.dumps(r,indent=2)+'\n');print('PASS final versions exact327/24,45+31 controls,real0/1,old3holesreject')
