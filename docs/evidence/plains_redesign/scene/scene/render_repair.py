import sys,os,json,subprocess,selectors,hashlib
from pathlib import Path
sys.path.insert(0,'tools')
import harness,level_formal
root=Path.cwd();folder=root/'build/plains_redesign/scene/repair_render_current';folder.mkdir()
producer=Path(__file__).resolve();script=root/'build/plains_redesign/scene/render_repair.gd'
source=level_formal.source_files();env=os.environ.copy();env['LP_NUM_THREADS']='1';env['LIBGL_ALWAYS_SOFTWARE']='1'
handle=(folder/'display.log').open('wb');display=subprocess.Popen(['/workspace/toolchains/xvfb/usr/bin/Xvfb','-displayfd','1','-screen','0','1280x720x24','-nolisten','tcp','-ac'],stdout=subprocess.PIPE,stderr=handle)
report={'status':'failed','source_files':source,'producer_sha256':level_formal.file_hash(producer),'script_sha256':level_formal.file_hash(script),'environment':{'LP_NUM_THREADS':'1','LIBGL_ALWAYS_SOFTWARE':'1'},'scope':'actual software-GPU 1280x720 live formal inputs, screenshot evidence only'}
try:
 with selectors.DefaultSelector() as selector:
  selector.register(display.stdout,selectors.EVENT_READ)
  if not selector.select(20):raise RuntimeError('display timeout')
  env['DISPLAY']=':'+display.stdout.readline().decode().strip()
 command=['bash','tools/godot.sh','--rendering-method','gl_compatibility','--fixed-fps','60','--path','.','--script',str(script),'--','--output='+str(folder/'capture.json'),'--screens-dir='+str(folder/'frames')]
 report['command']=command
 result=harness.run_check({'argv':command,'timeout_seconds':220,'success_pattern':r'^SCENE REPAIR RENDER: [1-9]\d* assertions, 0 failures$'},folder/'capture.log',root,env);report['process']=result
 data=json.loads((folder/'capture.json').read_text())
 report['outcome']=data['cases'][0]['outcome'];report['screenshots']=data['screenshots']
 assert result['status']=='passed' and data['cases'][0]['outcome']=='route_target_reached' and data['screenshots']
 assert all(s['error']==0 and s['width']==1280 and s['height']==720 and level_formal.file_hash(Path(s['path']))==s['sha256'] for s in data['screenshots'])
 assert source==level_formal.source_files()
 report['status']='captured'
finally:
 (folder/'receipt.json').write_text(json.dumps(report,indent=2)+'\n');display.terminate();display.wait(timeout=10);handle.close()
