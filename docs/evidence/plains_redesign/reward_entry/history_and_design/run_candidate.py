import sys,json,os,concurrent.futures
from pathlib import Path
p=Path('/workspace/gunman-rush/build/plains_redesign/reward_entry/candidate_a');sys.path.insert(0,str(p/'tools'));import level_formal as f
b=p/'build/reward_entry_toolchain_corrected'
def run(case):
 policy,phase=case;output=b/(policy+'_'+str(phase))/'capture.json'
 result=f.capture_one('level-design-v2-baseline',1,'return',output,max_ticks=15000,encounter_policy=policy,phase_wait_ticks=phase)
 print(json.dumps({'policy':policy,'phase':phase,'result':result}),flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as ex:list(ex.map(run,[(p,t) for p in ['kill_from_bank_v1','bait_then_bypass_v1'] for t in [0,100]]))
