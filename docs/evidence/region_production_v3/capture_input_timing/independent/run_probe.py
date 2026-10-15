import subprocess,os,time,selectors,json,hashlib
from pathlib import Path
r=Path('/workspace/gunman-rush');o=r/'build/region_production_v3/independent/capture_input_timing_review';xlog=(o/'xvfb.log').open('wb');x=subprocess.Popen(['/workspace/toolchains/xvfb/usr/bin/Xvfb','-displayfd','1','-screen','0','1280x720x24','-nolisten','tcp','-ac'],stdout=subprocess.PIPE,stderr=xlog)
try:
 with selectors.DefaultSelector() as sel:
  sel.register(x.stdout,selectors.EVENT_READ);assert sel.select(10);n=x.stdout.readline().decode().strip();assert n.isdigit()
 env=os.environ.copy();env.update(DISPLAY=':'+n,LIBGL_ALWAYS_SOFTWARE='1',GODOT_BIN=str(r/'build/region_production_v3/godot_locked.sh'),LP_NUM_THREADS='1',OMP_NUM_THREADS='1');argv=[env['GODOT_BIN'],'--path','.', '--rendering-method','gl_compatibility','--audio-driver','Dummy','--fixed-fps','60','--script','res://build/region_production_v3/independent/capture_input_timing_review/probe.gd'];start=time.time();p=subprocess.run(argv,cwd=r,env=env,capture_output=True,text=True,timeout=90);(o/'probe.log').write_text(p.stdout+p.stderr);(o/'invocation.json').write_text(json.dumps({'command':argv,'environment':{k:env[k] for k in ['DISPLAY','LIBGL_ALWAYS_SOFTWARE','GODOT_BIN','LP_NUM_THREADS','OMP_NUM_THREADS']},'started':start,'finished':time.time(),'exit_code':p.returncode,'scope':'Actual visible controlled timing fixture, normally scheduled controller, no manual stepping'},indent=2)+'\n');print(p.returncode,p.stdout+p.stderr);assert p.returncode==0
finally:
 x.terminate();x.wait(timeout=5);xlog.close()
