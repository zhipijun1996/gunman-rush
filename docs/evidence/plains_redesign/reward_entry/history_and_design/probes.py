import concurrent.futures,subprocess,json,time,sys
from pathlib import Path
sys.path.insert(0,'tools');import level_formal as f
base=Path('build/plains_redesign/reward_entry/native_initial');base.mkdir(exist_ok=True);before=f.source_files()
cases=[('kill0',[]),('kill100',['--entry-phase=100']),('bypass0',['--entry-policy=bait_then_bypass_v1']),('bypass100',['--entry-policy=bait_then_bypass_v1','--entry-phase=100']),('low',['--entry-low']),('top1',['--entry-tier=region_top']),('high2',['--entry-map=2']),('top2',['--entry-map=2','--entry-tier=region_top']),('negative_kill',['--restore-unsafe-entry']),('negative_bypass',['--restore-unsafe-entry','--entry-policy=bait_then_bypass_v1'])]
def run(case):
 name,args=case;cmd=['bash','tools/godot.sh','--headless','--fixed-fps','60','--path','.','--script','tests/plains_encounter_policy_runner.gd','--','--reward-entry','--output=res://'+str(base/(name+'.json'))]+args;start=time.time()
 with (base/(name+'.log')).open('w') as out:
  try:r=subprocess.run(cmd,stdout=out,stderr=subprocess.STDOUT,timeout=180);code=r.returncode
  except subprocess.TimeoutExpired:code=124
 receipt={'command':cmd,'exit_code':code,'started':start,'ended':time.time(),'source_before':before,'source_after':f.source_files()};(base/(name+'.receipt.json')).write_text(json.dumps(receipt,indent=2));print(name,code,flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:list(pool.map(run,cases))
