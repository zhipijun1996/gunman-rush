import sys,json
from pathlib import Path
sys.path.insert(0,'tools');import level_experience as e
base=Path('build/plains_redesign/reward_entry');oldkill=(base/'formal_paired/before/kill_from_bank_v1/capture.json').resolve();oldbait=(base/'formal_paired/before/bait_then_bypass_v1/capture.json').resolve()
comparisons=[]
for policy,old in [('kill_from_bank_v1',oldkill),('bait_then_bypass_v1',oldbait)]:
 new=(base/'formal_final_after'/policy/'capture.json').resolve()
 before=e.report([old]);after=e.report([new]);delta=e.compare(before,after)
 (base/('final_'+policy+'_before_report.json')).write_text(json.dumps(before,indent=2));(base/('final_'+policy+'_after_report.json')).write_text(json.dumps(after,indent=2));(base/('final_'+policy+'_comparison.json')).write_text(json.dumps(delta,indent=2))
 a=json.loads(old.read_text());b=json.loads(new.read_text());comparisons.append({'policy':policy,'before_capture':str(old),'after_candidate_capture':str(new),'before_outcome':a['outcome'],'after_outcome':b['outcome'],'before_ticks':a['tick_count'],'after_ticks':b['tick_count'],'before_min_hp':min(f['health'] for f in a['frames']),'after_min_hp':min(f['health'] for f in b['frames']),'before_claims':[o['chest'] for o in a['policy_observations'] if o['kind']=='actual_cache_claim'],'after_claims':[o['chest'] for o in b['policy_observations'] if o['kind']=='actual_cache_claim'],'same_driver_basis':a['policy_basis']==b['policy_basis'],'same_capability_basis':e.capability_basis(a)==e.capability_basis(b),'scope':'same root/map/return/phase0 policy, true revised content and actual outcomes, not fun score'})
(base/'actual_before_after_final.json').write_text(json.dumps(comparisons,ensure_ascii=False,indent=2));print(json.dumps(comparisons,indent=2))
