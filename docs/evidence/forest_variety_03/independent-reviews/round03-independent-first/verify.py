import json,hashlib,zipfile,subprocess,tarfile,math
from pathlib import Path
r=Path('/tmp/gunman-forest-variety-03/module-runtime-snapshot/build/variety-round03')
out=Path(__file__).resolve().parent
inv=json.loads((r/'source-before.json').read_text());after=json.loads((r/'source-after.json').read_text());z=zipfile.ZipFile(r/'changed-source.zip');changed=set(z.namelist());missing=set(inv)-changed;baseline={}
p=subprocess.Popen(['git','archive','ee0b646e779b4680319e9a377518b27c10bfbe87'],stdout=subprocess.PIPE)
with tarfile.open(fileobj=p.stdout,mode='r|') as tar:
 for f in tar:
  if f.isfile() and f.name in missing:baseline[f.name]=hashlib.sha256(tar.extractfile(f).read()).hexdigest()
assert p.wait()==0
bad=[n for n,h in inv.items() if (hashlib.sha256(z.read(n)).hexdigest() if n in changed else baseline.get(n))!=h]
assert not bad,bad
assert inv==after
print('Source reconstructed',len(inv),'changed',len(changed),'baseline',len(baseline),flush=True)
def segment_rect(a,b,r):
 x,y,w,h=r;lo=0.;hi=1.
 for pos,delta,mn,mx in [(a[0],b[0]-a[0],x-12,x+w+12),(a[1],b[1]-a[1],y-18,y+h+18)]:
  if abs(delta)<1e-10:
   if not mn<pos<mx:return False
  else:
   t0=(mn-pos)/delta;t1=(mx-pos)/delta;lo=max(lo,min(t0,t1));hi=min(hi,max(t0,t1))
   if lo>=hi:return False
 return lo<hi and hi>0 and lo<1
results=[]
for name in [x['module'] for x in json.loads((r/'receipt.json').read_text())['cases']]:
 f=r/(name+'.json');d=json.loads(f.read_text());frames=d['frames'];m=d['manifest'];row=next(x for x in m['platforms'] if x['id']=='crown');events=d['events'];sweeps=[]
 for a,b in zip(frames,frames[1:]):
  for i,hazard in enumerate(m['dangers']):
   if segment_rect(a['position'],b['position'],hazard):sweeps.append({'tick_from':a['tick'],'tick_to':b['tick'],'danger_index':i})
 def foot(frame,s):
  x,y,w,h=s['rect']
  return frame['grounded'] and frame['position'][0]-12>=x-.1 and frame['position'][0]+12<=x+w+.1 and abs(frame['position'][1]+18-y)<1
 final_ok=all(foot(fr,row) and fr['crown_support'] for fr in frames[-12:]);assert final_ok,name
 legs=[]
 for e in events:
  if e['kind']!='actual_ordinary_leg_complete':continue
  i=e['step'];step=m['routes']['main']['steps'][i];support=next(x for x in m['platforms'] if x['id']==step['support_id']);tick=e['tick']
  # Completion is emitted by pre-Motor driver using the existing observed
  # position. Its stable predicate refers to the previous12 physics states.
  # A final finished=true suppresses observation of tickN itself.
  window=[fr for fr in frames if fr['tick']<tick][-12:]
  okay=len(window)==12 and all(foot(fr,support) and math.dist(fr['position'],step['landing'])<=1 for fr in window)
  legs.append({'step':i,'tick':tick,'support':support['id'],'stable_frames':e['stable_frames'],'independent_prior12_fullfoot':okay,'physical_window':[window[0]['tick'],window[-1]['tick']]})
  assert okay,(name,i,tick)
 anchors={x['id']:x for x in m['hook_anchors']};causal=[]
 for e in events:
  if e['kind'] not in ['actual_cavity_bay_observation','actual_cavity_side_departure']:continue
  c=e.copy();causal.append(c)
  if e['kind']=='actual_cavity_bay_observation':
   tick=e['tick'];support=next(x for x in m['platforms'] if x['id']==e['support']);window=[fr for fr in frames if fr['tick']<tick][-12:];assert len(window)==12 and all(foot(fr,support) for fr in window)
  else:
   pos=e['position'];anchor=anchors['cavity_ring_b']['position'];c['second_target_origin_distance']=math.dist([pos[0],pos[1]-6],anchor)
   assert c['second_target_origin_distance']<=231 and not e['grounded']
 badticks=[i for i,fr in enumerate(frames,1) if fr['tick']!=i or fr['motor_steps']!=1]
 assert not badticks,name
 assert not sweeps,(name,sweeps)
 results.append({'module':name,'trace_sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'frames':len(frames),'native_passed':d['passed'],'reached':d['reached'],'failure':d['failure'],'manual_motor_step':d['manual_motor_step'],'midroute_injection':d['midroute_injection'],'formal_damage_policy':d['formal_damage_policy'],'motor_tick_anomalies':badticks,'final12_full_crown':final_ok,'raw_danger_contacts':d['danger_contacts'],'independent_continuous_body_danger_segments':sweeps,'ordinary_legs':legs,'cavity_causality_events':causal,'contact_targets':[e.get('target') for e in events if e['kind']=='hook_contact_kick'],'actual_shots':[e for e in events if e['kind']=='shot_fired'],'min_health':min(x['health'] for x in frames),'min_shots':min(x['shots'] for x in frames),'recovered':d['recovered'],'goal':m['goal'],'final_pre_motor_event_tick':max((e['tick'] for e in events),default=0)})
 print(name,'frames',len(frames),'final12',final_ok,'sweeps',len(sweeps),'legs',len(legs),'cavity',causal,flush=True)
report={'reviewer':'/root/forest_repeat_diagnosis','scope':'Read-only independent reconstruction and complete isolated traces; no engine or formal world/art/FUN/device approval','source_root':str(r),'baseline_commit':'ee0b646e779b4680319e9a377518b27c10bfbe87','source_paths':len(inv),'changed_zip_paths':len(changed),'baseline_paths':len(baseline),'all_path_sha256_equal':True,'before_after_equal':True,'changed_zip_sha256':hashlib.sha256((r/'changed-source.zip').read_bytes()).hexdigest(),'inventory_sha256':hashlib.sha256((r/'source-before.json').read_bytes()).hexdigest(),'native_outer_receipt_sha256':hashlib.sha256((r/'receipt.json').read_bytes()).hexdigest(),'total_frames':sum(x['frames'] for x in results),'cases':results,'verdict':'ACCEPT_SCOPED eight actual isolated goal arrivals; whole-world/alternate-port/reward-return/art/FUN/device UNVERIFIED','design_limit':'8 candidate IDs are not 8 new fun mechanics; first2 same-family connectors retain earlier cheap-alternative evidence at its original source'}
(out/'review.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('PASS independent trace audit',report['total_frames'],'physics frames',sum(len(x['ordinary_legs']) for x in results),'ordinary legs')
