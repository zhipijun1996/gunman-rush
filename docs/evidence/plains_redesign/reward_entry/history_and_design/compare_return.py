import sys,json
from pathlib import Path
sys.path.insert(0,'tools');import level_experience as e
b=Path('build/plains_redesign/reward_entry');old=(b/'behavior_entries/charger/capture.json').resolve();new=(b/'behavior_entries_final/charger/capture.json').resolve()
before=e.report([old]);after=e.report([new]);delta=e.compare(before,after)
for name,data in [('return_before_report',before),('return_after_report',after),('return_comparison',delta)]: (b/(name+'.json')).write_text(json.dumps(data,indent=2))
a=json.load(open(old));d=json.load(open(new));shots={s['event_id']:s for s in d['events'] if s['kind']=='shot_accepted'};facts=[]
for hit in d['events']:
 if hit['kind']!='damage_committed' or hit['tick']<1624 or not hit.get('source','').startswith('player_projectile:'):continue
 shot=shots[hit['event_id']];requests=[o for o in d['policy_observations'] if o['kind']=='enemy_shot_request' and o['tick']==shot['tick']]
 facts.append({'request_tick':shot['tick'],'request_target':requests[0]['enemy'] if requests else None,'actual_hit_tick':hit['tick'],'actual_target':hit['target'],'health_after':hit['health_after'],'event_id':hit['event_id']})
result={'root_seed':'two-map-corpus/2','map_index':1,'strategy':'return','encounter_policy':'kill_from_bank_v1','before':{'outcome':a['outcome'],'ticks':a['tick_count'],'min_health':min(f['health'] for f in a['frames']),'claim_completed':any(o['kind']=='actual_cache_claim' for o in a['policy_observations']),'damage':[x for x in a['events'] if x['kind']=='damage_committed' and x['target']=='player']},'after':{'outcome':d['outcome'],'ticks':d['tick_count'],'min_health':min(f['health'] for f in d['frames']),'claim_completed':any(o['kind']=='actual_cache_claim' for o in d['policy_observations'])},'same_driver_basis':a['policy_basis']==d['policy_basis'],'same_capability_basis':e.capability_basis(a)==e.capability_basis(d),'actual_projectile_target_facts':facts,'interpretation':'Both enemy budgets/AI and actual ballistic interception preserved. The observer aims at lane; three shots really hit the nearer guard then three lane. This does not prove precise deliberate aim at nearer guard or human readability.'}
(b/'return_actual_before_after.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print(json.dumps(result,ensure_ascii=False,indent=2))
