import sys,importlib.util,json,subprocess,time,signal
from pathlib import Path
r=Path('/workspace/gunman-rush');out=r/'build/region_production_v3/independent/check_preflight_review'
s=importlib.util.spec_from_file_location('actual_fixture',r/'tests/test_production_loop.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
t=m.SelectedInputPreflightTests();t.setUp()
try:
 (t.main/'tools/production_loop.py').write_bytes((r/'tools/production_loop.py').read_bytes())
 task=t.configure();subprocess.run(['git','-C',str(t.target),'sparse-checkout','add','--stdin'],input='/'+t.proof+'\n',text=True,check=True);subprocess.check_call(['git','-C',str(t.target),'read-tree','-mu','HEAD'])
 p=t.target/t.proof;p.unlink();p.symlink_to('/etc/hostname')
 e=t.target/'build/verification/independent-cli';e.mkdir(parents=True);mission=e/'mission.json';m.loop.save(mission,t.mission)
 proc=subprocess.Popen([sys.executable,str(t.target/'tools/production_loop.py'),'--mission',str(mission),'--execute','--worker-mode','host','--evidence-dir',str(e)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 requests=[]
 for _ in range(100):
  requests=list(e.glob('*/*/*/host_request.json'))
  if requests or proc.poll() is not None:break
  time.sleep(.03)
 if proc.poll() is None:proc.send_signal(signal.SIGTERM)
 output=proc.communicate(timeout=5)[0]
 (out/'cli_symlink_final.stdout.log').write_text(output)
 state=json.loads((e/'state.json').read_text())
 record={'scope':'Actual CLI controller only, synthetic Git fixture, no AI response or native engine','controller_exit':proc.returncode,'request_allocated':bool(requests),'state':state,'source_version':'frozen final production_loop 4a822d33'}
 (out/'cli_symlink_final.json').write_text(json.dumps(record,indent=2));print(json.dumps({'controller_exit':proc.returncode,'request_allocated':bool(requests),'calls':state['calls'],'status':state['status']}))
finally:t.doCleanups()
