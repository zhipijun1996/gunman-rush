from pathlib import Path
import json,zipfile,hashlib,subprocess,tarfile,math
r=Path('/tmp/gunman-forest-variety-03/round07');out=Path(__file__).parent/'round07-actual';out.mkdir(parents=True,exist_ok=True)
inv=json.loads((r/'source-before.json').read_text());after=json.loads((r/'source-after.json').read_text());z=zipfile.ZipFile(r/'changed-source.zip');changed=set(z.namelist());base={};missing=set(inv)-changed
proc=subprocess.Popen(['git','archive','ee0b646e779b4680319e9a377518b27c10bfbe87'],stdout=subprocess.PIPE)
with tarfile.open(fileobj=proc.stdout,mode='r|') as tar:
 for m in tar:
  if m.isfile() and m.name in missing:base[m.name]=hashlib.sha256(tar.extractfile(m).read()).hexdigest()
assert proc.wait()==0
bad=[n for n,h in inv.items() if (hashlib.sha256(z.read(n)).hexdigest() if n in changed else base.get(n))!=h]
assert not bad and inv==after
print('sources',len(inv),len(changed),len(base),'exact',flush=True)
d=json.loads((r/'varied_entry_trial.json').read_text());frames=d['frames'];manifest=d['manifest'];plats={x['id']:x for x in manifest['platforms']};frames_by_tick={x['tick']:x for x in frames}
assert d['initial']['position']==manifest['spawn']==[-2200.0,1882.0]
assert not d['manual_motor_step'] and not d['midroute_injection'] and not d['resource_override']
assert d['passed'] and not d['failures'] and len(d['completed'])==len(d['itinerary'])==7
assert all(f['tick']==i and f['motor_steps']==1 for i,f in enumerate(frames,1))
def foot(f,p):
 x,y,w,h=p['rect'];px,py=f['position'];return f['grounded'] and p['id'] in f['supports'] and px-12>=x-.1 and px+12<=x+w+.1 and abs(py+18-y)<1
legs=[]
for c in d['completed']:
 leg=d['itinerary'][c['leg']];expected=leg.get('landing_support_id',leg.get('support_id',''))
 target=leg['landing']
 if not expected:
  expected=next(p['id'] for p in manifest['platforms'] if p['id'] in c['supports'] and abs(float(p['rect'][1])-target[1]-18)<1 and target[0]-12>=p['rect'][0]-.1 and target[0]+12<=p['rect'][0]+p['rect'][2]+.1)
 window=[f for f in frames if c['tick']-11<=f['tick']<=c['tick']]
 okay=len(window)==12 and all(foot(f,plats[expected]) and abs(f['position'][0]-target[0])<=7 and abs(f['position'][1]-target[1])<=2 for f in window)
 assert okay,(c,expected)
 legs.append({'leg':c['leg'],'edge':c['edge_id'],'start_tick':c['start_tick'],'completion_tick':c['tick'],'frames':c['tick']-c['start_tick']+1,'support':expected,'last12_fullfoot':okay,'target':target})
def seg_rect(a,b,r):
 x,y,w,h=r;lo=0.;hi=1.
 for pos,delta,mn,mx in [(a[0],b[0]-a[0],x-12,x+w+12),(a[1],b[1]-a[1],y-18,y+h+18)]:
  if abs(delta)<1e-10:
   if not mn<pos<mx:return False
  else:
   t0=(mn-pos)/delta;t1=(mx-pos)/delta;lo=max(lo,min(t0,t1));hi=min(hi,max(t0,t1))
   if lo>=hi:return False
 return lo<hi and hi>0 and lo<1
sweeps=[]
for a,b in zip(frames,frames[1:]):
 for i,h in enumerate(manifest['dangers']):
  if seg_rect(a['position'],b['position'],h):sweeps.append({'from_tick':a['tick'],'to_tick':b['tick'],'danger_index':i})
contacts=[e for e in d['events'] if e.get('kind')=='hook_contact_kick'];casts=[e for e in d['events'] if e.get('kind')=='hook_cast'];shots=[e for e in d['events'] if e.get('kind')=='shot_fired'];damage=[e for e in d['events'] if e.get('kind')=='committed_damage' and e.get('target')=='player']
assert [e['target'] for e in contacts]==['interwoven_lesson_ring','interwoven_hollow_a','interwoven_hollow_b']
assert not shots and not damage and not sweeps
assert all(f['health']==5 for f in frames)
assert not d['initial']['double_enabled'] and not d['initial']['wall_enabled'] and d['initial']['hook_enabled']
assert d['initial']['config']==d['final']['config']
bay=plats['varied_entry_rest_bay'];start=next(e for e in d['events'] if e.get('kind')=='jumped' and e.get('leg')==6)['position'];x,y,w,h=bay['rect'];margin=x+w-(start[0]+12)
print('frames',len(frames),'legs',len(legs),'sweep_hits',len(sweeps),'bay',bay['rect'],'second_launch',start,'right_foot_margin',margin,flush=True)
report={'reviewer':'/root/forest_repeat_diagnosis','scope':'new17 actual formal-spawn entry only; no engine run or new FUN/art/device acceptance','source_root':str(r),'baseline':'ee0b646e779b4680319e9a377518b27c10bfbe87','source_paths':len(inv),'zip_changed_paths':len(changed),'baseline_paths':len(base),'all_hashes_equal':True,'before_after_equal':True,'source_inventory_sha256':hashlib.sha256((r/'source-before.json').read_bytes()).hexdigest(),'source_zip_sha256':hashlib.sha256((r/'changed-source.zip').read_bytes()).hexdigest(),'capture_sha256':hashlib.sha256((r/'varied_entry_trial.json').read_bytes()).hexdigest(),'native_outer_exit':json.loads((r/'receipt.json').read_text())['exit_code'],'entry_passed':True,'old_spawn':manifest['spawn'],'frames':len(frames),'legs':legs,'bay_rect':bay['rect'],'second_H_launch':start,'second_H_launch_right_foot_margin':margin,'actual_contact_events':contacts,'actual_cast_events':casts,'actual_shot_events':shots,'player_damage_events':damage,'independent_continuous_danger_sweep':sweeps,'min_health':5,'initial':d['initial'],'final':d['final'],'verdict':'ACCEPT_SCOPED actual new resting entry path; original HH/rootspiral under165wu bay and wider map/visual/FUN unverified'}
(out/'review.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
