from pathlib import Path
import json,hashlib,shutil
D=Path(__file__).resolve().parent; R=Path('/tmp/gunman-v16-fifteenth')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
rows=[]
for name in sorted(p.parent.name for p in R.glob('[0-9]*/capture.json')):
 p=R/name/'capture.json';d=json.loads(p.read_text());fs=d['frames'];bytick={f['tick']:f for f in fs}; ps={x['id']:x['rect'] for x in d['manifest']['platforms']}; findings=[]
 for f in fs:
  if f['motor_steps']!=1:findings.append(['motor_steps',f['tick'],f['motor_steps']])
 for leg in d['completed_legs']:
  plan=d['itinerary'][leg['leg']];target=plan['landing'];sid=plan.get('support_id',plan.get('landing_support_id',''));supports=[sid] if sid else leg['supports']
  for tick in range(leg['tick']-11,leg['tick']+1):
   f=bytick[tick];x,y=f['position']
   full=[s for s in supports if s in ps and abs(y+18-ps[s][1])<=1 and x-12>=ps[s][0]-.1 and x+12<=ps[s][0]+ps[s][2]+.1]
   if not(f['grounded'] and abs(x-target[0])<=7 and abs(y-target[1])<=2 and full):findings.append(['support_tail',leg['leg'],tick,sid,f['supports']])
 txs=[]
 for tx in d['bible_admission']['reward_transactions']:
  before,after=tx['before'],tx['after']; q='thorn_forest/map_'+str(d['map_index'])+'/'+tx['claim_id'];dup=tx['duplicate_before'];dupa=tx['duplicate_after']
  t={'claim_id':q,'coin_delta':after['coins']-before['coins'],'note_delta':after['notes']-before['notes'],'new_claim':not before['claimed'].get(q,False) and after['claimed'].get(q,False),'duplicate_resource_idempotent':all(dup[k]==dupa[k] for k in ['coins','notes','items','claimed']),'paused_modal_frames':len(tx['modal_frames']),'all_modal_paused':all(x['paused'] for x in tx['modal_frames']),'pointer_events':[x['kind'] for x in tx['pointer_events']]};txs.append(t)
  if not(t['coin_delta']==next(x.get('coins',0) for x in d['manifest']['rewards'] if x['id']==tx['claim_id']) and t['note_delta']==0 and t['new_claim'] and t['duplicate_resource_idempotent'] and t['all_modal_paused'] and t['paused_modal_frames']==5):findings.append(['transaction',q])
 row={'route':d['route'],'map_index':d['map_index'],'capture_sha256':sha(p),'frames':len(fs),'legs':len(d['completed_legs']),'findings':findings,'reported_failures':d['failures'],'manual_motor_step':d['manual_motor_step'],'position_or_resource_injection':d['position_or_resource_injection'],'minimum_health':min(f['health'] for f in fs),'transactions':txs,'shortcut_events':[e for e in d['events'] if 'shortcut' in e.get('kind','')],'world_source_sha256':d['bible_admission']['world_source_sha256'],'module_source_sha256':d['bible_admission']['module_source_sha256']};rows.append(row)
a=Path('build/region_bible_v2/forest-feedback-native-15/source-before.json');b=a.with_name('source-after.json');inv_a=json.loads(a.read_text());inv_b=json.loads(b.read_text()) if b.exists() else None
result={'scope':'Independent native15 formal trace checks: actual Motor count, complete12-frame full-foot support tail at every completed leg, actual declared coin OR choice/idempotence/modal input, and actual claimed shortcut event. No reviewer engine. Not a fresh-closed-gate/save/FUN proof.','source_before_after_identical':inv_a==inv_b if inv_b is not None else None,'source_before_sha256':sha(a),'source_after_sha256':sha(b) if b.exists() else None,'rows':rows}
(D/'formal-routes-review.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');shutil.copytree(R/'manifests',D/'actual-manifests',dirs_exist_ok=True)
print(json.dumps({'stable':inv_a==inv_b,'rows':[{k:x[k] for k in ['route','frames','legs','findings','minimum_health']} for x in rows]}))
