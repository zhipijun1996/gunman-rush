import pathlib,json,hashlib,subprocess,os,time,re,uuid,sys,fcntl
ROOT=pathlib.Path('/workspace/gunman-rush-design'); S=ROOT/'build/forest_depth/snapshots/level_capability03'; O=ROOT/'build/forest_depth/level_capability/capture_candidate03'
def inventory():
 paths=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z'],cwd=S).decode().split('\0')
 return {p:hashlib.sha256((S/p).read_bytes()).hexdigest() if (S/p).is_file() else 'deleted' for p in sorted(set(paths)-{''})}
before=inventory(); (O/'source-before.json').write_text(json.dumps(before,indent=2)+'\n')
env=os.environ.copy();env.update(GUNMAN_TOOLCHAIN_ROOT='/workspace/toolchains',GUNMAN_DATA_HOME=str(S/'build/capability-data'),XDG_DATA_HOME=str(S/'build/capability-data'),XDG_CONFIG_HOME=str(S/'build/capability-config'),XDG_CACHE_HOME=str(S/'build/capability-cache'))
checks={'capture-target': {'argv': ['python3', 'tools/level_design.py', 'capture', '--output', 'build/level_design_v2/capture_boundary03/capture.json'], 'timeout_seconds': 600, 'success_pattern': '^PASS: level design capture \\(3 actual strategies\\)'}}; receipt={'scope':'Exact target command development validation, NOT Harness full profile','snapshot':str(S),'checks':[],'passed':False}
try:
 with open(ROOT/'build/verification/engine.lock','w') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX)
  for name in ['capture-target']:
   c=checks[name]; token=uuid.uuid4().hex; argv=[x.replace('{check_token}',token) for x in c['argv']]; start=time.monotonic();print('START '+name,flush=True)
   log=O/(name+'.log')
   with log.open('w') as f:
    try: result=subprocess.run(argv,cwd=S,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=c['timeout_seconds']);code=result.returncode
    except subprocess.TimeoutExpired: code='timeout'
   text=log.read_text(); strict=not re.search(r'(^|\n)(?:SCRIPT )?ERROR:|Parse Error:|SHADER ERROR:|ObjectDB.*leaked|resources? still in use at exit',text,re.I); marker=bool(re.search(c['success_pattern'],text,re.M)); after=inventory();guard=before==after
   row={'name':name,'argv':argv,'timeout_seconds':c['timeout_seconds'],'exit_code':code,'elapsed_seconds':time.monotonic()-start,'strict_log_clean':strict,'success_pattern_found':marker,'source_guard':guard,'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest()};receipt['checks'].append(row);print(json.dumps(row),flush=True)
   (O/'source-after.json').write_text(json.dumps(after,indent=2)+'\n')
   if code!=0 or not strict or not marker or not guard: raise RuntimeError('First failure: '+name)
 receipt['passed']=True
finally:
 (O/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('PASS equivalent targeted commands; not Harness profile',flush=True)
