from pathlib import Path
import subprocess,sys,json,os,time
sys.path.insert(0,'tools');import level_formal
base=Path('build/plains_redesign/scene_completion');source=level_formal.source_files();runs=[];env=os.environ.copy();env['LP_NUM_THREADS']='1'
commands=[('extra',[sys.executable,str(base/'render_case.py'),'--mode','extra','--folder',str(base/'extra_movie')],350),('repair',[sys.executable,str(base/'render_case.py'),'--mode','repair','--folder',str(base/'repair_movie')],350),('clock',[sys.executable,'tools/level_visual_capture.py','--seed','level-design-v2-baseline','--map-index','1','--strategy','return','--encounter-policy','kill_from_bank_v1','--max-ticks','1100','--output',str(base/'clock_movie')],350),('growth',[sys.executable,'tools/level_visual_capture.py','--seed','level-design-v2-baseline','--map-index','2','--strategy','growth','--encounter-policy','kill_from_bank_v1','--max-ticks','6000','--output',str(base/'growth_movie')],650)]
for name,command,budget in commands:
 log=base/(name+'_render.log');start=time.time()
 with log.open('w') as f:
  try:code=subprocess.run(command,stdout=f,stderr=subprocess.STDOUT,env=env,timeout=budget).returncode
  except subprocess.TimeoutExpired:code=-1;f.write('Actual timeout\n')
 runs.append({'name':name,'command':command,'exit_code':code,'seconds':time.time()-start,'log':str(log),'sha256':level_formal.file_hash(log),'source_unchanged':source==level_formal.source_files()});(base/'render_pipeline.json').write_text(json.dumps({'source_files':source,'runs':runs},indent=2)+'\n')
 if code or source!=level_formal.source_files():break
