from pathlib import Path
import json,hashlib
root=Path('/workspace/gunman-rush')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def owner(data):return next(e['owner_id'] for e in data['events'] if e.get('kind')=='shot_accepted')
def normalize(value,player_id):
 if isinstance(value,dict):return {k:('PLAYER_RUNTIME_INSTANCE' if k=='owner_id' and v==player_id else normalize(v,player_id)) for k,v in value.items()}
 if isinstance(value,list):return [normalize(v,player_id) for v in value]
 if isinstance(value,str):return value.replace(str(player_id)+':','PLAYER_RUNTIME_INSTANCE:').replace('player_projectile:'+str(player_id),'player_projectile:PLAYER_RUNTIME_INSTANCE')
 return value
reports=[]
for generation in ['golden1','golden2']:
 for name in ['clock_return','creek_growth']:
  a_path=root/'build/plains_redesign/q6_controlled_before'/name/'capture.json';b_path=root/'build/plains_redesign/q6_rework'/generation/name/'capture.json'
  if not b_path.exists():continue
  a=json.loads(a_path.read_text());b=json.loads(b_path.read_text());aa=owner(a);bb=owner(b)
  state_keys=['tick','position','velocity','grounded','health','shot_energy','shots','used_jumps','shot_cooldown','edge']
  differences=[{'tick':x['tick'],'fields':{k:[x.get(k),y.get(k)] for k in state_keys if x.get(k)!=y.get(k)}} for x,y in zip(a['frames'],b['frames']) if any(x.get(k)!=y.get(k) for k in state_keys)]
  old_events=normalize(a['events'],aa);new_events=normalize(b['events'],bb)
  diffevents=[{'index':i,'before':x,'after':y} for i,(x,y) in enumerate(zip(old_events,new_events)) if x!=y]
  reports.append({'generation':generation,'route':name,'before':str(a_path.relative_to(root)),'after':str(b_path.relative_to(root)),'before_sha256':sha(a_path),'after_sha256':sha(b_path),'manifest_exact_equal':a['manifest']==b['manifest'],'initial_capability_exact_equal':a['initial_capability']==b['initial_capability'],'ticks':[len(a['frames']),len(b['frames'])],'outcomes':[a['outcome'],b['outcome']],'actual_state_differences':differences,'normalized_event_differences':diffevents,'event_counts':[len(old_events),len(new_events)],'raw_events_exact_equal':a['events']==b['events'],'normalization':{'reason':'Process-local PlayerMotor Object instance ID changes when presentation node count changes. Only actual shot owner ID and its event/projectile-source prefixes are bijectively replaced; all raw receipts retained. Ticks/directions/resources/packet/session/shot/targets/amounts are unchanged and still compared.','before_player_object_id':aa,'after_player_object_id':bb},'comparison_ok':a['manifest']==b['manifest'] and a['initial_capability']==b['initial_capability'] and len(a['frames'])==len(b['frames']) and not differences and old_events==new_events})
out=root/'build/plains_redesign/q6_rework/controlled_comparison.json';out.write_text(json.dumps({'scope':'C2 exact gameplay comparison of actual controlled prefixes; not a fun or aesthetics score','comparisons':reports},ensure_ascii=False,indent=2)+'\n')
for r in reports:print(r['generation'],r['route'],r['comparison_ok'],'state_diff',len(r['actual_state_differences']),'event_diff',len(r['normalized_event_differences']))
