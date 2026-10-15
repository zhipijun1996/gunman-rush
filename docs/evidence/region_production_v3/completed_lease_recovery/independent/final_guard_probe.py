"""Independent actual temporary-file final-publication mutation; simulated host payload only."""
import importlib.util,json,pathlib,sys
from unittest.mock import patch
ROOT=pathlib.Path('/workspace/gunman-rush');sys.path.insert(0,str(ROOT/'tools'));import production_loop as loop
spec=importlib.util.spec_from_file_location('collector_fixtures',ROOT/'tests/test_production_loop.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
results={}
for mutation in ['state','checkpoint','invocation','result']:
 f=mod.CompletedReviewCollectionTests();f.setUp()
 try:
  mission,evidence,review=f.fixture('late_'+mutation,verdict='accept');before=(evidence/'state.json').read_bytes();original_save=loop.save
  def alter(path,value):
   original_save(path,value)
   if path.name=='state.after.json':
    target={'state':evidence/'state.json','checkpoint':review.parent/'checkpoint.json','invocation':review/'invocation.json','result':review/'result.json'}[mutation]
    target.write_text('{}\n')
  try:
   with patch.object(loop,'ROOT',f.main),patch.object(loop,'save',side_effect=alter):s=loop.collect_completed_review(mission,evidence,f.target,f.vanished_pid)
   r={'returned':True,'returned_status':s['status']}
  except Exception as e:r={'returned':False,'error':type(e).__name__+': '+str(e)}
  r.update(original_state_restored=(evidence/'state.json').read_bytes()==before,actual_state=json.loads((evidence/'state.json').read_text()),published_result=(review/'result.json').exists());results[mutation]=r;print(mutation,json.dumps({k:v for k,v in r.items() if k!='actual_state'}))
 finally:f.doCleanups()
(ROOT/'build/region_production_v3/independent/completed_lease_recovery/final_guard_probe_results.json').write_text(json.dumps(results,indent=2)+'\n')
