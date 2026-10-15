import subprocess,json,time,os,sys
from pathlib import Path
sys.path.insert(0,'tools')
import level_formal
base=Path('build/plains_redesign/scene'); source=level_formal.source_files();env=os.environ.copy();env['LP_NUM_THREADS']='1'
commands=[('final_well_movie',[sys.executable,'tools/level_visual_capture.py','--seed','level-design-v2-baseline','--map-index','1','--strategy','fast','--encounter-policy','kill_from_bank_v1','--max-ticks','1100','--output','build/plains_redesign/scene/final_well_movie'],350),('repair_render',[sys.executable,'build/plains_redesign/scene/render_repair.py'],240),('spatial',[sys.executable,'tools/run_plains_redesign_spatial_tests.py'],300),('experience',[sys.executable,'tools/run_plains_experience_golden_tests.py'],180),('old64',[sys.executable,'tools/run_plains_redesign_golden_tests.py'],180)]
results=[]
for name,command,timeout in commands:
 start=time.time();log=base/(name+'_local.log')
 with log.open('w') as f:
  try:r=subprocess.run(command,stdout=f,stderr=subprocess.STDOUT,env=env,timeout=timeout);code=r.returncode
  except Exception as exc:f.write(str(exc));code=-1
 results.append({'name':name,'command':command,'exit_code':code,'seconds':time.time()-start,'log':str(log),'log_sha256':level_formal.file_hash(log),'source_unchanged':source==level_formal.source_files()})
 (base/'local_checks.json').write_text(json.dumps({'source_files':source,'runs':results},indent=2)+'\n')
 if code or results[-1]['source_unchanged'] is not True:break
