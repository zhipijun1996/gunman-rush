"""Actual collector against temporary Git worktrees; host payloads are SIMULATED, no real lease touched."""
import copy,importlib.util,json,pathlib,sys,hashlib
from unittest.mock import patch
ROOT=pathlib.Path('/workspace/gunman-rush');sys.path.insert(0,str(ROOT/'tools'));import production_loop as loop
spec=importlib.util.spec_from_file_location('existing_collection_fixtures',ROOT/'tests/test_production_loop.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
OUT=ROOT/'build/region_production_v3/independent/completed_lease_recovery';results={}
for mutation in ['baseline_accept','baseline_reject','expiry_during_quality','revocation_during_quality','source_during_quality','response_during_quality','revocation_at_checkpoint_save']:
 f=mod.CompletedReviewCollectionTests();f.setUp()
 try:
  mission,evidence,review=f.fixture(mutation,verdict='reject' if mutation=='baseline_reject' else 'accept');before=(evidence/'state.json').read_bytes();wall=[loop.time.time()];old_quality=loop.check_task_quality;old_save=loop.save
  def altered_quality(task):
   answer=old_quality(task)
   if mutation=='expiry_during_quality':wall[0]+=1000
   elif mutation=='revocation_during_quality':(review/'lease_revoked.json').write_text('{"actual_review_fixture_revocation":true}\n')
   elif mutation=='source_during_quality':(f.target/'tools/check_fixture.py').write_text('changed actual fixture source during finalization\n')
   elif mutation=='response_during_quality':(review/'host_response.json').write_text('{}\n')
   return answer
  def altered_save(path,value):
   old_save(path,value)
   if mutation=='revocation_at_checkpoint_save' and path.name=='checkpoint.json':(review/'lease_revoked.json').write_text('{"actual_review_fixture_revocation":true}\n')
  try:
   with patch.object(loop,'ROOT',f.main),patch.object(loop,'check_task_quality',side_effect=altered_quality),patch.object(loop,'save',side_effect=altered_save),patch.object(loop.time,'time',side_effect=lambda:wall[0]):state=loop.collect_completed_review(mission,evidence,f.target,f.vanished_pid)
   r={'returned':True,'status':state['status'],'calls':state['calls']}
  except Exception as e:r={'returned':False,'error':type(e).__name__+': '+str(e)}
  state=json.loads((evidence/'state.json').read_text());r.update(state_unchanged=(evidence/'state.json').read_bytes()==before,published_result=(review/'result.json').exists(),published_invocation=(review/'invocation.json').exists(),saved_state_status=state['status'],saved_task_status=state['tasks']['DRILL']['status'],simulated_fixture_only=True)
  results[mutation]=r;print(mutation,json.dumps(r),flush=True)
 finally:f.doCleanups()
results['source_sha256']=hashlib.sha256((ROOT/'tools/production_loop.py').read_bytes()).hexdigest();(OUT/'independent_probe_results.json').write_text(json.dumps(results,indent=2)+'\n')
