from pathlib import Path
import json, zipfile, hashlib, subprocess, tarfile, collections
root=Path('/tmp/gunman-forest-variety-03/round11')
out=Path(__file__).parent
inventory=json.loads((root/'source-before.json').read_text());after=json.loads((root/'source-after.json').read_text())
archive=zipfile.ZipFile(root/'changed-source.zip');changed=set(archive.namelist());base={};missing=set(inventory)-changed
p=subprocess.Popen(['git','archive','ee0b646e779b4680319e9a377518b27c10bfbe87'],stdout=subprocess.PIPE)
with tarfile.open(fileobj=p.stdout,mode='r|') as tar:
 for m in tar:
  if m.isfile() and m.name in missing:base[m.name]=hashlib.sha256(tar.extractfile(m).read()).hexdigest()
assert p.wait()==0
bad=[n for n,h in inventory.items() if (hashlib.sha256(archive.read(n)).hexdigest() if n in changed else base.get(n))!=h]
assert not bad and inventory==after
print('source',len(inventory),len(changed),len(base),'all exact, stable',flush=True)
def fullfoot(frame,platform):
 x,y,w,h=platform['rect'];px,py=frame['position']
 return frame['grounded'] and platform['id'] in frame['supports'] and px-12>=x-.1 and px+12<=x+w+.1 and abs(py+18-y)<1
def segment_rect(a,b,rect):
 x,y,w,h=rect;lo=0.;hi=1.
 for pos,delta,mn,mx in [(a[0],b[0]-a[0],x-12,x+w+12),(a[1],b[1]-a[1],y-18,y+h+18)]:
  if abs(delta)<1e-10:
   if not mn<pos<mx:return False
  else:
   t0=(mn-pos)/delta;t1=(mx-pos)/delta;lo=max(lo,min(t0,t1));hi=min(hi,max(t0,t1))
   if lo>=hi:return False
 return lo<hi and hi>0 and lo<1
reports=[]
for name in ['old-HH','old-skill','L-coin','L-note','map1-annex','map2-L-journey']:
 d=json.loads((root/(name+'.json')).read_text());frames=d['frames'];platforms={p['id']:p for p in d['manifest']['platforms']}
 assert d['passed'] and not d['failures'] and len(d['completed'])==len(d['itinerary'])
 assert not d['manual_motor_step'] and not d['midroute_injection'] and not d['resource_override']
 assert all(f['tick']==i and f['motor_steps']==1 for i,f in enumerate(frames,1))
 assert d['initial']['config']==d['final']['config'] and d['initial']['hook_enabled'] and not d['initial']['double_enabled'] and not d['initial']['wall_enabled']
 if name in ['L-coin','L-note']:
  assert d['initial_fixture_spawn_override'] and d['fixture']['motion_steps_before_override']==0 and not d['fixture']['resource_or_health_override']
 else:assert d['initial']['position']==d['manifest']['spawn']==[-2200.0,1882.0]
 legs=[];leg_failures=[]
 for c in d['completed']:
  leg=d['itinerary'][c['leg']];target=leg['landing'];expected=leg.get('landing_support_id',leg.get('support_id',''))
  window=[f for f in frames if c['tick']-11<=f['tick']<=c['tick']]
  if not expected:
   candidates=[q['id'] for q in d['manifest']['platforms'] if q['id'] in c['supports'] and target[0]-12>=q['rect'][0]-.1 and target[0]+12<=q['rect'][0]+q['rect'][2]+.1 and abs(target[1]+18-q['rect'][1])<1]
   expected=next((s for s in candidates if len(window)==12 and all(fullfoot(f,platforms[s]) for f in window)),'')
  valid=expected in platforms and len(window)==12 and all(fullfoot(f,platforms[expected]) and abs(f['position'][0]-target[0])<=7 and abs(f['position'][1]-target[1])<=2 for f in window)
  if not valid:leg_failures.append({'leg':c['leg'],'edge':c['edge_id'],'support':expected,'target':target,'window':[{k:f[k] for k in ['tick','position','grounded','supports']} for f in window]})
  legs.append({'leg':c['leg'],'edge':c['edge_id'],'kind':leg['kind'],'start_tick':c['start_tick'],'tick':c['tick'],'support':expected,'last12_fullfoot_and_original_destination':bool(valid),'target':target})
 sweeps=[]
 for a,b in zip(frames,frames[1:]):
  for i,h in enumerate(d['manifest']['dangers']):
   if segment_rect(a['position'],b['position'],h):sweeps.append({'from_tick':a['tick'],'to_tick':b['tick'],'danger_index':i})
 events=d['events'];damage=[e for e in events if e['kind']=='committed_damage' and e['target']=='player']
 rewards=d['reward_transactions'];modal=d['modal_frames'];pointer=d['pointer_events']
 if name in ['L-coin','L-note','map2-L-journey']:
  assert len(rewards)==1 and len(pointer)==2 and len(modal)>=2
  tx=rewards[0];assert tx['duplicate_before']==tx['duplicate_after']==tx['after']
  coin_delta=tx['after']['coins']-tx['before']['coins'];note_delta=tx['after']['notes']-tx['before']['notes']
  assert (coin_delta,note_delta)==((0,1) if name=='L-note' else (4,0))
  assert len(tx['after']['claimed'])==1 and not tx['before']['claimed']
  assert all(m['paused'] and m['motion_steps']==modal[0]['motion_steps'] and m['position']==modal[0]['position'] for m in modal)
  for kind in ['varied_fixed_return_departure','varied_fixed_return_hook_intent','varied_fixed_hang_observed','varied_fixed_hang_jump_intent']:assert any(e['kind']==kind for e in events)
  hang=next(e for e in events if e['kind']=='varied_fixed_hang_observed');jump=next(e for e in events if e['kind']=='varied_fixed_hang_jump_intent')
  assert hang['anchor_id']==jump['anchor_id']=='varied_l_return_fruit' and hang['target_instance']==jump['target_instance']
  assert any(f['hook_state']=='hook_hang' and f['tick']==hang['tick'] for f in frames)
  assert any(e['kind']=='jumped' and e['tick']==jump['tick'] for e in events)
 else:assert not rewards
 result={'name':name,'route':d['route'],'scope':d['scope'],'raw_sha256':hashlib.sha256((root/(name+'.json')).read_bytes()).hexdigest(),'frames':len(frames),'legs':legs,'independent_leg_failures':leg_failures,'swept_static_danger_intersections':sweeps,'minimum_health':min(f['health'] for f in frames),'damage':damage,'health_changes':[{'tick':b['tick'],'before':a['health'],'after':b['health'],'position':b['position']} for a,b in zip(frames,frames[1:]) if a['health']!=b['health']],'initial':d['initial'],'final':d['final'],'initial_fixture':d.get('fixture'),'reward_transactions':rewards,'modal_frames':modal,'pointer_events':pointer,'fixed_hang_events':[e for e in events if e['kind'].startswith('varied_fixed')],'actual_contacts':[e for e in events if e['kind']=='hook_contact_kick'],'shots_fired':[e for e in events if e['kind']=='shot_fired'],'enemy_terminals':[e for e in events if 'terminal' in e['kind']]}
 reports.append(result)
 print(name,'frames',len(frames),'legs',len(legs),'legfails',len(leg_failures),'sweep',len(sweeps),'hpmin',result['minimum_health'],'damage',len(damage),'rewards',len(rewards),flush=True)
report={'scope':'independent read-only six actual routes; no new engine, no FUN/art/device/publication acceptance','source_root':str(root),'source_paths':len(inventory),'changed_zip_paths':len(changed),'baseline_paths':len(base),'all_source_hashes_equal':True,'source_before_after_equal':True,'inventory_sha256':hashlib.sha256((root/'source-before.json').read_bytes()).hexdigest(),'zip_sha256':hashlib.sha256((root/'changed-source.zip').read_bytes()).hexdigest(),'receipt':json.loads((root/'receipt.json').read_text()),'routes':reports}
(out/'review.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
assert not any(r['independent_leg_failures'] or r['swept_static_danger_intersections'] for r in reports)
print('independent route physical checks PASS',flush=True)
