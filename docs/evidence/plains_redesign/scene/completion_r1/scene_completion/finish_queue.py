from pathlib import Path
import os,time,subprocess,sys,json
sys.path.insert(0,'tools');import level_formal
base=Path('build/plains_redesign/scene_completion');receipt=Path('build/plains_redesign/scene/run_us9izlj2/receipt.json')
while not receipt.exists():time.sleep(1)
if json.loads(receipt.read_text()).get('status')!='passed':raise SystemExit('Native gate failed; no movie acceptance')
source=level_formal.source_files();runs=[];env=os.environ.copy();env['LP_NUM_THREADS']='1'
for name,command,timeout in [('current3_extra_touch',[sys.executable,str(base/'render_case.py'),'--mode','extra_touch','--folder',str(base/'current3_extra_touch')],200),('current_spatial',[sys.executable,'tools/run_plains_redesign_spatial_tests.py'],250)]:
 log=base/(name+'_final.log');start=time.time()
 with log.open('w') as f:
  try:code=subprocess.run(command,stdout=f,stderr=subprocess.STDOUT,env=env,timeout=timeout).returncode
  except subprocess.TimeoutExpired:code=-1
 runs.append({'name':name,'command':command,'exit_code':code,'seconds':time.time()-start,'source_unchanged':source==level_formal.source_files(),'log':str(log),'sha256':level_formal.file_hash(log)});(base/'finish_queue.json').write_text(json.dumps({'source_files':source,'runs':runs},indent=2)+'\n')
 if code or source!=level_formal.source_files():raise SystemExit(1)
