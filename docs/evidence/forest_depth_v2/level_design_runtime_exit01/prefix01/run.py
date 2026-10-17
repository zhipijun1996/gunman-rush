import os,json,pathlib,subprocess,hashlib,time,re,fcntl
R=pathlib.Path('/workspace/gunman-rush-design');S=R/'build/forest_depth/snapshots/level_capability01';O=pathlib.Path(__file__).resolve().parent
scope={p:hashlib.sha256((S/p).read_bytes()).hexdigest() for p in json.load(open(S/'build/snapshot-receipt.json'))['source_files']}
env=os.environ.copy();env.update(GUNMAN_TOOLCHAIN_ROOT='/workspace/toolchains',GUNMAN_DATA_HOME=str(S/'build/boundary-data'),XDG_CONFIG_HOME=str(S/'build/boundary-config'),XDG_CACHE_HOME=str(S/'build/boundary-cache'))
rows=[]
with open(R/'build/verification/engine.lock','w') as lock:
 fcntl.flock(lock,fcntl.LOCK_EX)
 for label in ['player','build','snapshot','trace']:
  cmd=['bash','tools/godot.sh','--headless','--verbose','--path','.','--script',f'build/capability_boundary/{label}_entry.gd'];start=time.monotonic()
  with (O/(label+'.log')).open('w') as out:
   p=subprocess.run(cmd,cwd=S,env=env,stdout=out,stderr=subprocess.STDOUT,timeout=10)
  text=(O/(label+'.log')).read_text(); rows.append({'case':label,'argv':cmd,'budget_seconds':10,'exit':p.returncode,'seconds':time.monotonic()-start,'marker':f'PREFIX {label}:' in text,'strict_clean':not bool(re.search(r'ERROR:|ObjectDB.*leaked|resources? still in use',text))});print(rows[-1],flush=True)
after={p:hashlib.sha256((S/p).read_bytes()).hexdigest() for p in scope};receipt={'scope':'Controlled load-only dependency boundary; not full41 proof','source_guard':scope==after,'cases':rows};(O/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
