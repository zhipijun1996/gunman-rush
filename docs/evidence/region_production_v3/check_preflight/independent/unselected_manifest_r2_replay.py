import importlib.util,json,copy
from pathlib import Path
from unittest.mock import patch
r=Path('/workspace/gunman-rush');s=importlib.util.spec_from_file_location('f',r/'tests/test_production_loop.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
z=importlib.util.spec_from_file_location('archived_r2_loop',r/'build/region_production_v3/independent/check_preflight_review/production_loop.r2.py');old=importlib.util.module_from_spec(z);z.loader.exec_module(old);m.loop=old
t=m.SelectedInputPreflightTests();t.setUp()
try:
 (t.main/'tools/production_loop.py').write_bytes((r/'build/region_production_v3/independent/check_preflight_review/production_loop.r2.py').read_bytes());task=t.configure();task['checks']=['quality-tests'];(t.target/'tools/check_quality.py').unlink();calls=[]
 def worker(task,mission,role,*args):
  calls.append(role);return {'status':'ready_for_review' if role=='implement' else 'accept','summary':'SIMULATED worker only; no actual AI','findings':[]}
 folder=t.target/'build/verification/unselected-entry'
 with patch.object(m.loop,'ROOT',t.main),m.loop._collection_worktree(t.target):
  pre=m.loop.required_input_preflight(task)
  try:state=m.loop.run(t.mission,folder,worker);error=None
  except Exception as e:error={'type':type(e).__name__,'message':str(e)};state=json.loads((folder/'state.json').read_text())
 result={'scope':'Actual temporary Git/files and controller; SYNTHETIC worker only, no AI or native','preflight':pre,'calls':calls,'error':error,'state':state}
 (r/'build/region_production_v3/independent/check_preflight_review/unselected_manifest.r2.replay.json').write_text(json.dumps(result,indent=2));print({'preflight':pre['status'],'calls':calls,'error':error})
finally:t.doCleanups()
