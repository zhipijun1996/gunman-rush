import sys,json,concurrent.futures
from pathlib import Path
sys.path.insert(0,'tools');import level_formal as f
b=Path('build/plains_redesign/reward_entry').resolve()
def run(policy):
 result=f.capture_one('level-design-v2-baseline',1,'return',b/'formal_final_after'/policy/'capture.json',max_ticks=15000,encounter_policy=policy);print(json.dumps(result),flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:list(pool.map(run,['kill_from_bank_v1','bait_then_bypass_v1']))
