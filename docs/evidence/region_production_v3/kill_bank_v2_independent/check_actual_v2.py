"""Independent read-only source, four native traces and causal-resource audit."""
import collections,hashlib,json,math,subprocess,sys,copy
from pathlib import Path
import zipfile
ROOT=Path(__file__).resolve().parents[4];OUT=Path(__file__).resolve().parent
P=ROOT/'docs/evidence/region_production_v3/kill_bank_v2'
sha=lambda b:hashlib.sha256(b).hexdigest()
sys.path.insert(0,str(ROOT/'tools'));import level_formal as formal
z=zipfile.ZipFile(P/'actual_native_and_sources.zip');cases={};receipts={};metrics=[];bindings=[]
for case in ['before_deep_v1','before_fast_v1','after_deep_v2','after_fast_v1']:
 name=next(n for n in z.namelist() if n.startswith(case+'/') and n.endswith('/capture.json'))
 raw=z.read(name);d=json.loads(raw);r=json.loads(z.read(name.replace('capture.json','capture.invocation.json')))
 assert sha(raw)==r['capture_sha256'] and sha(z.read(name.replace('capture.json','capture.log')))==r['log_sha256']
 assert r['source_before']==r['source_after']==r['source_files'] and len(r['source_files'])==806 and r['exit_code']==0
 path=ROOT/'build/region_production_v3/kill_bank_v2'/name
 assert path.read_bytes()==raw
 errors=formal.validate_capture(path,d,r,path.with_suffix('.log'),current_sources=r['source_files']);assert not errors,errors
 manifest=json.loads((P/'effective_sources'/f'{case}.json').read_text());inventory={}
 for b in manifest['bindings']:
  inventory[b['path']]=b['sha256']
  if b['basis']!='original_git_blob':
   q=(P/'effective_sources'/b['overlay_blob']).resolve();assert q.is_relative_to((P/'effective_sources/dirty_blobs').resolve());assert sha(q.read_bytes())==b['sha256']
 assert inventory==r['source_before'];assert r['source_commit']=='9eef7a88003deaf924f895d585cb7e5de0cb48b0'
 for n in ['config/player_tuning.json','resources/player/plains_shot_energy.tres','scripts/enemies/enemy_attack_behavior.gd']:
  assert sha(subprocess.check_output(['git','show',r['source_commit']+':'+n],cwd=ROOT))==inventory[n]
 bindings.append({'case':case,'sources':len(inventory),'dirty_count':sum(b['basis']!='original_git_blob' for b in manifest['bindings']),
                  'original_receipt_sha256':sha(z.read(name.replace('capture.json','capture.invocation.json'))),'source_commit_unchanged':r['source_commit']})
 frames=d['frames'];events=d['events'];assert [f['tick'] for f in frames]==list(range(1,len(frames)+1))
 key=lambda e:json.dumps(e,sort_keys=True,separators=(',',':'))
 assert collections.Counter(map(key,events))==collections.Counter(key(e) for f in frames for e in f['accepted_events'])
 by_tick=collections.defaultdict(list);rr=collections.defaultdict(list)
 for e in events:by_tick[e['tick']].append(e)
 for x in d['resource_receipts']:rr[x['tick']].append(x)
 cap=d['initial_capability'];config=cap['shot_energy'];energy=config['current'];delay=config['_delay'];ground=cap['grounded'];hp=5.;shots={e['shot_id']:e for e in events if e['kind']=='shot_accepted'};consumed=set();granted=set();epoch=frames[0]['resource_epoch'];seen=set();dt=1/d['physics_hz'];damagehits={}
 for e in events:
  if e['kind']=='damage_committed' and e['target']!='player' and e['source'].startswith('player_projectile:'):
   damagehits.setdefault(e['event_id'],e)
 for f in frames:
  gain=max(0,dt-delay);delay=max(0,delay-dt)
  if ground:energy=min(config['capacity'],energy+config['ground_energy_recovery']*gain)
  for e in by_tick[f['tick']]:
   if e['kind']=='player_health':hp+=e['amount'];assert abs(hp-e['current'])<1e-6 and e['status']==0
  assert abs(f['health']-hp)<1e-6 and 0<hp<=5
  for x in rr[f['tick']]:
   kind,session,sid=x['event_id'].split('/');sid=int(sid);shot=shots[sid]
   assert (x['epoch'],x['event_id']) not in seen;seen.add((x['epoch'],x['event_id']))
   assert int(session)==cap['session_id']==x['session_id'] and x['epoch']==epoch and x['status']==0
   before=energy
   if x['operation']=='consume':
    assert kind=='shot' and sid not in consumed and x['tick']==shot['tick'] and x['requested_amount']==config['shot_energy_cost'];consumed.add(sid)
    assert any(a['type']=='shoot_release' for a in f['input_requests'])
    energy-=config['shot_energy_cost'];delay=config['shot_energy_delay'];assert abs(shot['energy_after']-energy)<1e-5
   else:
    assert kind=='hit' and x['operation']=='grant' and sid not in granted;granted.add(sid)
    hit=damagehits[shot['event_id']];assert hit['tick']==x['tick'] and hit['source']=='player_projectile:'+str(shot['owner_id'])
    assert x['requested_amount']==config['hit_energy_recovery'];energy=min(config['capacity'],energy+x['requested_amount'])
    assert any(e['kind']=='energy_recovered' and abs(e['amount']-(energy-before))<1e-6 for e in by_tick[x['tick']])
   assert abs(x['amount_applied']-(energy-before))<1e-6 and abs(x['current']-energy)<1e-5
  assert abs(energy-f['shot_energy'])<1e-5 and 0<=energy<=config['capacity']
  ground=f['grounded']
 assert consumed==set(shots)
 expected={sid for sid,e in shots.items() if e['event_id'] in damagehits};assert granted==expected
 cases[case]=d;receipts[case]=r
 metrics.append({'case':case,'frames':len(frames),'outcome':d['outcome'],'min_hp':min(f['health'] for f in frames),'final_hp':hp,
                 'accepted_shots':len(shots),'real_first_hit_grants':len(granted),'all_recorded_HP_and_energy_replayed':True})
# Three source edits are exactly a whitelist addition and trace dispatch/search
# logging. Remove only those exact new spans to reconstruct original trace.
a=z.read('before/level_formal_trace.gd').decode();b=z.read('candidate_source/level_formal_trace.gd').decode()
b=b.replace('["blind_legacy", "kill_from_bank_v1", "kill_from_bank_v2", "bait_then_bypass_v1"]','["blind_legacy", "kill_from_bank_v1", "bait_then_bypass_v1"]')
b=b.replace('encounter_policy in ["kill_from_bank_v1", "kill_from_bank_v2"]','encounter_policy == "kill_from_bank_v1"')
b=b.replace('var shifts: Array[float] = [16.0,32.0,48.0,64.0,-16.0,-32.0,-48.0,-64.0]\n\t\tif encounter_policy == "kill_from_bank_v2": shifts.append_array([80.0,96.0,-80.0,-96.0])\n\t\tfor shift: float in shifts:','for shift: float in [16.0,32.0,48.0,64.0,-16.0,-32.0,-48.0,-64.0]:')
lines=b.splitlines(keepends=True);b=''.join(line for i,line in enumerate(lines) if not (line.startswith('\t\t\tif encounter_policy == "kill_from_bank_v2":') or '"kill_bank_candidate_v2"' in line or '"kill_bank_candidate_clearance_v2"' in line));assert b==a
v1fields=['manifest','initial_capability','final_capability','frames','events','edges','policy_observations','resource_receipts','initial_runtime','final_runtime','outcome','tick_count']
assert all(cases['before_fast_v1'][k]==cases['after_fast_v1'][k] for k in v1fields)
d=cases['after_deep_v2'];target='plains/enemy/window/deep_high_ferry/ferry_air_intercept';local=d['frames'][930:1026]
assert all(f['health']==5 for f in local) and max(f['recovery_count'] for f in d['frames'])==0
cand=[x for x in d['policy_observations'] if x['kind']=='kill_bank_candidate_v2' and x['enemy']==target and x['shift']==80][0]
assert cand['candidate']==[-50.,-1100.02624511719] and cand['path_supported'] and cand['recoil_supported']
hits=[e for e in d['events'] if e['kind']=='damage_committed' and e['target']==target];assert len(hits)==3 and hits[-1]['lethal']
playerdamage=[e for e in d['events'] if e['kind']=='damage_committed' and e['target']=='player'];assert [e['tick'] for e in playerdamage]==[1180,1284,1391,1489]
assert all(e['source']=='plains/enemy/window/deep_high_ferry/ferry_fan_crossfire' for e in playerdamage)
claims=[x for x in d['policy_observations'] if x['kind']=='actual_cache_claim'];heart=next(x for x in claims if x['claim_output']['resource']=='heart')
assert heart['claim_output']['amount']==4 and heart['transaction']['before']['health']==2 and heart['transaction']['after']['health']==5
ledger=heart['transaction']['after']['health_receipts'];heals=[v for v in ledger.values() if v['operation']=='heal'];assert sorted(x['amount_applied'] for x in heals)==[1.,3.]
assert any('drop_plains/enemy/area_2_0' in k and v['requested_amount']==1 for k,v in ledger.items() if v['operation']=='heal')
assert any('chest/region_top/resource' in k and v['requested_amount']==4 and v['amount_applied']==3 for k,v in ledger.items() if v['operation']=='heal')
request=dict(source_commit='a'*40,root_seed='UNIT_ONLY_NOT_NATIVE',strategy='deep',map_index=2,phase_wait_ticks=0,max_ticks=18000,encounter_policy='kill_from_bank_v2')
assert '--encounter-policy=kill_from_bank_v2' in formal.command_for(request,ROOT/'build/region_production_v3/independent_unit_never_executed.json')
try:formal.command_for(dict(request,encounter_policy='kill_from_bank_v99'),ROOT/'build/region_production_v3/independent_unit_never_executed.json')
except ValueError:pass
else:raise AssertionError('Unknown policy accepted')
# Independently enforce the old80 comparison's only legitimate process aliases.
with zipfile.ZipFile(ROOT/'docs/evidence/region_production_v3/final_multiseed_80/original_captures_receipts_and_logs.zip') as oldz:
    older=json.loads(oldz.read('build/region_production_v3/final_multiseed_80/seed_00/map_2/fast/capture.json'))
fresh=cases['before_fast_v1'];oldowners={e['owner_id'] for e in older['events'] if e['kind']=='shot_accepted'};newowners={e['owner_id'] for e in fresh['events'] if e['kind']=='shot_accepted'}
assert len(oldowners)==len(newowners)==1
oldowner=next(iter(oldowners));newowner=next(iter(newowners));changed=[]
def remap(value,key='',path=''):
    if isinstance(value,dict):return {k:remap(v,k,path+'/'+k) for k,v in value.items()}
    if isinstance(value,list):return [remap(v,key,path+'/'+str(i)) for i,v in enumerate(value)]
    if key=='owner_id' and value==oldowner:changed.append(path);return newowner
    if key=='event_id' and isinstance(value,str) and value.startswith(str(oldowner)+':'):changed.append(path);return str(newowner)+value[len(str(oldowner)):]
    if key=='source' and value=='player_projectile:'+str(oldowner):changed.append(path);return 'player_projectile:'+str(newowner)
    return value
for field in v1fields:assert remap(older[field],field,'/'+field)==fresh[field],field
assert len(changed)==172
for path in ['tools/level_formal.py','tools/level_formal_capture.gd']:
    old=z.read('before/'+Path(path).name).decode();new=z.read('candidate_source/'+Path(path).name).decode()
    assert new.replace('"kill_from_bank_v1", "kill_from_bank_v2",','"kill_from_bank_v1",')==old,path
result={'reviewer':'/root/v3_ecology_admission','scope':'Original four native cases independently reconsumed; no new Godot and no full-route fairness approval',
        'effective_source_bindings':bindings,'exact_original_trace_reconstructed_after_removing_only_v2_additions':True,
        'raw_before_after_v1_all12_fields_equal':True,'old80_strict_alias_only_comparison':{'matched':True,'changed_fields':len(changed),'old_owner':oldowner,'new_owner':newowner,'allowed_keys':['owner_id','event_id ownerprefix','source exactplayer_projectileowner']},'case_metrics':metrics,'local_candidate':cand,'local_three_real_hits':hits,
        'whole_route_player_damage':playerdamage,'whole_route_health_events':[e for e in d['events'] if e['kind']=='player_health'],
        'real_heal_transaction_ledger':ledger,'region_top_claim':{'claim_output':heart['claim_output'],'health_before':2,'health_after':5},
        'pure_CLI_positive_and_unknown_negative':True,'actual_archive_sha256':sha((P/'actual_native_and_sources.zip').read_bytes())}
(OUT/'audit_results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('Independent4native/806each: source overlays, exactv1 preservation, localHP5gain, whole4damage/heals and CLI verified; no native rerun.')
