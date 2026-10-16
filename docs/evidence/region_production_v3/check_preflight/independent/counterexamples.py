import sys,importlib.util,json,os
from pathlib import Path
from unittest.mock import patch
repo=Path('/workspace/gunman-rush')
spec=importlib.util.spec_from_file_location('fixture_tests',repo/'tests/test_production_loop.py'); m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
results=[]
def run_case(name,change,uid=None):
 t=m.SelectedInputPreflightTests();t.setUp()
 try:
  task=t.configure();p=t.target/t.proof
  import subprocess
  subprocess.run(['git','-C',str(t.target),'sparse-checkout','add','--stdin'],input='/'+t.proof+'\n',text=True,check=True)
  subprocess.check_call(['git','-C',str(t.target),'read-tree','-mu','HEAD'])
  change(t,p)
  with patch.object(m.loop,'ROOT',t.main),m.loop._collection_worktree(t.target):
   try:
    if uid:
     for root,dirs,files in os.walk(t.tmp.name):
      os.chmod(root,0o755)
     os.environ['GIT_CONFIG_COUNT']='1';os.environ['GIT_CONFIG_KEY_0']='safe.directory';os.environ['GIT_CONFIG_VALUE_0']='*'
     pass # Already actual uid 1000
    outcome=m.loop.required_input_preflight(task)
   except Exception as e:outcome={'raised':type(e).__name__,'message':str(e)}
   finally:
    if uid:pass
  results.append({'name':name,'outcome':outcome})
 finally:t.doCleanups()
def symlink_missing(t,p):
 p.unlink();p.symlink_to('missing_target.txt')
def symlink_external(t,p):
 p.unlink();p.symlink_to('/etc/hostname')
def binary_index(t,p):
 (t.target/'docs/quality/records/OLD.json').write_bytes(b'\xff\xfe\x00')
def unreadable_index(t,p):
 (t.target/'docs/quality/records/OLD.json').chmod(0)
 p.unlink()
def unreadable_evidence(t,p):p.chmod(0)
def missing_check_source(t,p): (t.target/'tools/check_quality.py').unlink()
def unreadable_directory(t,p): (t.target/'docs/quality/records').chmod(0)
for name,fn,uid in [('missing_tracked_symlink',symlink_missing,None),('external_tracked_symlink',symlink_external,None),('binary_tracked_index',binary_index,None),('unreadable_tracked_index_missing_dependency',unreadable_index,1000),('unreadable_tracked_evidence',unreadable_evidence,1000),('missing_selected_argv_source',missing_check_source,None),('unreadable_index_directory',unreadable_directory,None)]:run_case(name,fn,uid)
out=repo/'build/region_production_v3/independent/check_preflight_review/counterexamples.json';out.write_text(json.dumps({'scope':'Actual temporary Git/files; no worker or native invoked','cases':results},indent=2));print(json.dumps(results,indent=2))
