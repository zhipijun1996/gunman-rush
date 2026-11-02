import subprocess,os,time,json
from pathlib import Path
OUT=Path('/workspace/refactor-evidence/death-runtime-01/loot-gpu')
TMP=Path('/tmp/loot-gpu-02')
GODOT='/workspace/toolchains/godot/godot-4.7.2-gunman-sd1/godot-linux-x86_64'
with (OUT/'native-parse.log').open('w') as f:
 parsed=subprocess.run([GODOT,'--headless','--main-pack',str(TMP/'candidate/diagnostic.pck'),'--check-only','--script','res://loot_fixture.gd'],stdout=f,stderr=subprocess.STDOUT,timeout=30)
assert parsed.returncode==0
log=(TMP/'xvfb.log').open('w')
x=subprocess.Popen(['/workspace/toolchains/xvfb/usr/bin/Xvfb',':91','-screen','0','1280x720x24','-nolisten','tcp'],stdout=log,stderr=subprocess.STDOUT)
try:
 for _ in range(50):
  if Path('/tmp/.X11-unix/X91').exists():break
  time.sleep(.1)
 env=dict(os.environ,DISPLAY=':91',LIBGL_ALWAYS_SOFTWARE='1',XDG_CONFIG_HOME=str(TMP/'xdg-config'),XDG_DATA_HOME=str(TMP/'xdg-data'),GODOT_SILENCE_ROOT_WARNING='1')
 argv=[GODOT,'--main-pack',str(TMP/'candidate/diagnostic.pck'),'--display-driver','x11','--rendering-method','gl_compatibility','--audio-driver','Dummy','--','--loot-native-output='+str(OUT)]
 with (OUT/'native.log').open('w') as f:r=subprocess.run(argv,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=90)
 text=(OUT/'native.log').read_text()
 errors=[line for line in text.splitlines() if any(x in line for x in ['ERROR:','SCRIPT ERROR:','leaked','leaks','RID allocations'])]
 row={'argv':argv,'exit_code':r.returncode,'renderer':'X11 llvmpipe software GL; no hardware GPU','parse_exit_code':parsed.returncode,'errors_or_leaks':errors}
 (OUT/'native-run-receipt.json').write_text(json.dumps(row,indent=2)+'\n')
 print(json.dumps(row,indent=2))
 assert r.returncode==0 and not errors
finally:
 x.terminate();x.wait(timeout=5);log.close()
