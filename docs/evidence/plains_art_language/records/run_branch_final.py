import sys,json,time,subprocess,fcntl,re
from pathlib import Path
ROOT=Path('/workspace/art-direction-exploration');sys.path.insert(0,str(ROOT/'tools'))
from level_formal import source_files
from run_plains_joint_recoil_tests import logged_engine
from run_root_bell_ecology import godot_lock_path,native_runtime_failed
out=Path('/tmp/plains_art_language/branch_library_02');out.mkdir(exist_ok=False)
args=['--headless','--fixed-fps','60','--path','.','--script','tests/branch_library_runner.gd']
r={'status':'failed','scope':'Original branch library normal/reflected Motor and no-shot negatives; not new whole-region route or art admission','source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'command':['bash','tools/godot.sh',*args]};t=time.monotonic()
try:
 with godot_lock_path(ROOT).open('a') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX);r['source_before']=source_files()
  log=logged_engine(args,120,out/'native.log');r['source_after']=source_files();r['source_unchanged']=r['source_before']==r['source_after']
  if native_runtime_failed(0,log) or not re.search(r'1310 assertions, 0 failures',log) or not r['source_unchanged']:raise RuntimeError('Strict original regression failed')
  r['status']='passed'
except Exception as e:r['error']=str(e);raise
finally:
 r['elapsed_seconds']=time.monotonic()-t;(out/'report.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'],r['elapsed_seconds'])
