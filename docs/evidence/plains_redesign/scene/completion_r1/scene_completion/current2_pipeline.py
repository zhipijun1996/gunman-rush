from pathlib import Path
import subprocess,sys,json,os,time
sys.path.insert(0,'tools');import level_formal
base=Path('build/plains_redesign/scene_completion');source=level_formal.source_files();runs=[];env=os.environ.copy();env['LP_NUM_THREADS']='1'
commands=[('current2_extra_touch',[sys.executable,str(base/'render_case.py'),'--mode','extra_touch','--folder',str(base/'current2_extra_touch')],350),('current2_well',[sys.executable,'tools/level_visual_capture.py','--seed','level-design-v2-baseline','--map-index','1','--strategy','fast','--encounter-policy','kill_from_bank_v1','--max-ticks','1100','--output',str(base/'current2_well')],350),('current2_clock',[sys.executable,'tools/level_visual_capture.py','--seed','level-design-v2-baseline','--map-index','1','--strategy','return','--encounter-policy','kill_from_bank_v1','--max-ticks','1100','--output',str(base/'current2_clock')],350),('current2_growth',[sys.executable,'tools/level_visual_capture.py','--seed','level-design-v2-baseline','--map-index','2','--strategy','growth','--encounter-policy','kill_from_bank_v1','--max-ticks','2000','--output',str(base/'current2_growth')],650),('current2_repair',[sys.executable,str(base/'render_case.py'),'--mode','repair','--folder',str(base/'current2_repair')],350),('current2_spatial',[sys.executable,'tools/run_plains_redesign_spatial_tests.py'],300),('current2_experience',[sys.executable,'tools/run_plains_experience_golden_tests.py'],250),('current2_old64',[sys.executable,'tools/run_plains_redesign_golden_tests.py'],250)]
for name,command,budget in commands:
 log=base/(name+'_render.log');start=time.time()
 with log.open('w') as f:
  try:code=subprocess.run(command,stdout=f,stderr=subprocess.STDOUT,env=env,timeout=budget).returncode
  except subprocess.TimeoutExpired:code=-1;f.write('Actual timeout\n')
 runs.append({'name':name,'command':command,'exit_code':code,'seconds':time.time()-start,'log':str(log),'sha256':level_formal.file_hash(log),'source_unchanged':source==level_formal.source_files()});(base/'current2_pipeline.json').write_text(json.dumps({'source_files':source,'runs':runs},indent=2)+'\n')
 if code or source!=level_formal.source_files():break
