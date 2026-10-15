import sys,json,os,shutil,concurrent.futures,subprocess
from pathlib import Path
r=Path('/workspace/gunman-rush');b=r/'build/plains_redesign/reward_entry';p=b/'before_reproduction'
sys.path.insert(0,str(r/'tools'));import level_formal as f
os.environ['GUNMAN_TOOLCHAIN_ROOT']='/workspace/toolchains'
def run(case):
 side,policy=case;target=b/'formal_paired'/side/policy/'capture.json'
 if side=='after':result=f.capture_one('level-design-v2-baseline',1,'return',target,max_ticks=15000,encounter_policy=policy)
 else:
  destination=p/target.relative_to(r);env=dict(os.environ);env['PYTHONPATH']=str(p/'tools')
  code='import level_formal as f,sys,json; print(json.dumps(f.capture_one("level-design-v2-baseline",1,"return",sys.argv[1],max_ticks=15000,encounter_policy=sys.argv[2])))'
  process=subprocess.run(['python3','-c',code,str(destination),policy],cwd=p,env=env,capture_output=True,text=True,timeout=180)
  (b/('paired_before_'+policy+'.log')).write_text(process.stdout+process.stderr);assert process.returncode==0
  result=json.loads(process.stdout.strip().splitlines()[-1]);target.parent.mkdir(parents=True,exist_ok=True)
  for path in destination.parent.iterdir():shutil.copy2(path,target.parent/path.name)
 print(side,policy,json.dumps(result),flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as ex:list(ex.map(run,[(s,p) for s in ['before','after'] for p in ['kill_from_bank_v1','bait_then_bypass_v1']]))
