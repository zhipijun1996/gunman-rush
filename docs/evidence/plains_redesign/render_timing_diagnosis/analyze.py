from pathlib import Path
import json,hashlib,collections
root=Path.cwd();out=root/'build/plains_redesign/render_timing_diagnosis';old=Path('/workspace/plains-redesign-baseline/build/plains_redesign/final_comparison')
cases=[('current_A',root/'build/plains_redesign/reward_entry/current_a_movie/capture.json',root/'build/plains_redesign/reward_entry/formal_paired/after/kill_from_bank_v1/capture.json')]
for name,map_index,strategy in [('intro_fast',1,'fast'),('creek_growth',2,'growth'),('high_return',1,'return'),('advanced_deep',2,'deep')]:
 movie=old/'before_movies'/name/'capture.json';movie_data=json.load(open(movie));candidates=list((root/'build/plains_redesign/final_comparison/before').glob('seed_*/map_'+str(map_index)+'/'+strategy+'/capture.json'));headless=next(p for p in candidates if json.load(open(p))['root_seed']==movie_data['root_seed']);cases.append(('old_'+name,movie,headless))
rows=[]
for name,mp,hp in cases:
 m=json.load(open(mp));h=json.load(open(hp));row={'id':name,'inputs':{k:{'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for k,p in [('movie',mp),('headless',hp)]},'same_manifest':m['manifest_hash']==h['manifest_hash'],'same_19_driver':m['policy_basis']['driver_sources']==h['policy_basis']['driver_sources'],'driver_count':len(m['policy_basis']['driver_sources']),'same_core':m['policy_basis']['core_invariants']==h['policy_basis']['core_invariants'],'core_count':len(m['policy_basis']['core_invariants']),'same_initial_capability':m['initial_capability']==h['initial_capability'],'same_initial_runtime':m['initial_runtime']==h['initial_runtime'],'sides':{}}
 for side,d in [('movie',m),('headless',h)]:
  shots={e['tick']:e for e in d['events'] if e['kind']=='shot_accepted'}
  unanswered=[]
  for f in d['frames']:
   requests=[a for a in f['input_requests'] if a['type']=='shoot_release']
   if requests and f['tick'] not in shots and not any(e['kind']=='input_rejected' for e in f['accepted_events']):
    unanswered.append({'tick':f['tick'],'controller_tick':f['controller_tick'],'sequence':[a['sequence'] for a in requests],'cooldown':f['shot_cooldown'],'health':f['health'],'energy':f['shot_energy'],'position':f['position'],'edge':f['edge']})
  last_bank=next((o for o in reversed(d['policy_observations']) if o.get('kind')=='kill_bank_enter'),None)
  bank=None
  if last_bank:
   start=last_bank['tick'];enemy=last_bank['enemy'];requests=[o for o in d['policy_observations'] if o.get('kind')=='enemy_shot_request' and o['tick']>=start and o['enemy']==enemy]
   bank_shots=[e for e in d['events'] if e['kind']=='shot_accepted' and e['tick']>=start];commits=[e for e in d['events'] if e['kind']=='damage_committed' and e['tick']>=start and e.get('target')==enemy]
   bank={'entry':last_bank,'requests':requests,'accepted_shots':bank_shots,'actual_target_commits':commits,'unanswered_requests':[f for f in unanswered if f['tick']>=start]}
  row['sides'][side]={'ticks':len(d['frames']),'outcome':d['outcome'],'controller_tick_minus_trace':dict(collections.Counter(str(f['controller_tick']-f['tick']) for f in d['frames'])),'unanswered_shoot_requests':unanswered,'last_bank':bank,'diagnostics':d['driver_diagnostics']}
 rows.append(row)
(out/'trace_comparison.json').write_text(json.dumps({'scope':'Original actual raw only. Unanswered is a factual request with no accepted/rejected shot; raw v3 lacks queue timestamps, so individual TTL attribution needs monitor. It is not a player failure rate.','cases':rows},ensure_ascii=False,indent=2)+'\n')
for r in rows:
 print(r['id'],'manifest/driver/core',r['same_manifest'],r['same_19_driver'],r['same_core'],'initialcap',r['same_initial_capability'])
 for side,x in r['sides'].items():
  b=x['last_bank'];print(side,x['ticks'],x['outcome'],'unanswered',len(x['unanswered_shoot_requests']),'lastbank',b['entry']['enemy'] if b else None,'req/accept/commit',[(len(b[k]) if b else 0) for k in ['requests','accepted_shots','actual_target_commits']])
