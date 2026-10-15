import sys,json,concurrent.futures
from pathlib import Path
sys.path.insert(0,'tools');import level_formal as f,level_experience as e
b=Path('build/plains_redesign/reward_entry/behavior_entries_final').resolve();b.mkdir(exist_ok=True)
def run(item):
 behavior,seed=item;target=b/behavior/'capture.json';result=f.capture_one(seed,1,'return',target,max_ticks=18000,encounter_policy='kill_from_bank_v1');data=json.load(open(target));e.validate_capture(data);print(behavior,json.dumps(result),flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:list(pool.map(run,[('sentry','two-map-corpus/0'),('charger','two-map-corpus/2')]))
