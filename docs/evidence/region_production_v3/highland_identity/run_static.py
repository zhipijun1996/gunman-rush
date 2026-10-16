import pathlib,sys,os,subprocess,time,json
root=pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0,str(root/'tools'));import level_formal
out=root/'build/region_production_v3/highland_identity'; before=level_formal.source_files();env=os.environ.copy();env.update({'GODOT_BIN':str(root/'build/region_production_v3/godot_locked.sh'),'LP_NUM_THREADS':'1','OMP_NUM_THREADS':'1','DISPLAY':':89','LIBGL_ALWAYS_SOFTWARE':'1','PLAINS_HIGHLAND_PILOT':'1','PLAINS_SHARED_WIND':'0','LD_LIBRARY_PATH':'/workspace/toolchains/xvfb/usr/lib/x86_64-linux-gnu:'+env.get('LD_LIBRARY_PATH','')})
with (out/'display_v2.log').open('w') as log:
 display=subprocess.Popen(['/workspace/toolchains/xvfb/usr/bin/Xvfb',':89','-screen','0','1280x720x24','-nolisten','tcp'],env=env,stdout=log,stderr=subprocess.STDOUT)
 try:
  time.sleep(.5);cmd=['bash','tools/godot.sh','--path','.','--rendering-method','gl_compatibility','--audio-driver','Dummy','--script','build/region_production_v3/highland_identity/static_probe.gd'];started=time.time();r=subprocess.run(cmd,cwd=root,env=env,capture_output=True,text=True,timeout=90);(out/'static_v2/native.log').write_text(r.stdout+r.stderr);after=level_formal.source_files();(out/'static_v2/invocation.json').write_text(json.dumps({'command':cmd,'env':{k:env[k] for k in ['GODOT_BIN','LP_NUM_THREADS','OMP_NUM_THREADS','DISPLAY','LIBGL_ALWAYS_SOFTWARE','PLAINS_HIGHLAND_PILOT','PLAINS_SHARED_WIND']},'exit_code':r.returncode,'seconds':time.time()-started,'source_before':before,'source_after':after,'source_stable':before==after},indent=2)+'\n');print(r.returncode,r.stdout[-1000:],r.stderr[-1000:])
 finally:display.terminate();display.wait(timeout=10)
