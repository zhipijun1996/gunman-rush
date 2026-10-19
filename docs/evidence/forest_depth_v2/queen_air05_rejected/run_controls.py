from pathlib import Path
import fcntl,subprocess,json,os,time,re,hashlib
root=Path('/workspace/gunman-rush-design');snap=root/'build/forest_depth/snapshots/queen-air-motion05-controls';outer=root/'build/forest_depth/queen/air-motion-05-controls-outer';outer.mkdir();env=os.environ.copy();env.update(GUNMAN_TOOLCHAIN_ROOT='/workspace/toolchains',GUNMAN_DATA_HOME=str(snap/'build/queenuserdata'),XDG_CONFIG_HOME=str(snap/'build/queenconfig'),XDG_CACHE_HOME=str(snap/'build/queencache'));r={'snapshot':str(snap),'snapshot_receipt_sha256':hashlib.sha256((snap/'build/snapshot-receipt.json').read_bytes()).hexdigest(),'runs':[]};start=time.monotonic();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();inventory=json.loads((root/'build/forest_depth/queen/air-motion-05-controls/checkpoint-inventory.json').read_text())
def save():(outer/'receipt.json').write_text(json.dumps(r,indent=2)+'\n')
try:
 with (root/'build/verification/engine.lock').open('a') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
  for case in ['air_ordinary','air_camp','air_wrong']:
   assert all(sha(snap/p)==h for p,h in inventory.items())
   argv=['python3','tools/run_thorn_queen_sweep.py','--case',case,'--output-dir','build/forest_depth/queen/air-motion-05-'+case];t=time.monotonic()
   with (outer/(case+'.log')).open('w') as log:p=subprocess.run(argv,cwd=snap,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=210)
   txt=(outer/(case+'.log')).read_text();errors=re.findall(r'(?m)^.*(?:SCRIPT ERROR:|Parse Error:|^ERROR:).*$' ,txt)
   stable=all(sha(snap/path)==h for path,h in inventory.items())
   r['runs'].append({'name':case,'argv':argv,'timeout':210,'exit_code':p.returncode,'seconds':time.monotonic()-t,'errors':errors,'full2063_source_guard':stable});save();print(json.dumps(r['runs'][-1]),flush=True)
   if p.returncode or errors or not stable:break
finally:r['seconds']=time.monotonic()-start;save();print('engine lock released',flush=True)
if any(run['exit_code'] or run['errors'] or not run['full2063_source_guard'] for run in r['runs']):raise SystemExit(1)
