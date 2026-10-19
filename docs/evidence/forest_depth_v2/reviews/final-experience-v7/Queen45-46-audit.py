import json,hashlib
from pathlib import Path
out=Path('build/forest_depth/independent/final-experience-v7')
paths={
'ordinary45':Path('build/forest_depth/snapshots/queen45-route-knot/build/forest_depth/queen/round45-route-ordinary'),
'H45':Path('build/forest_depth/snapshots/queen45-route-knot/build/forest_depth/queen/round45-route-H'),
'cut45fail':Path('build/forest_depth/snapshots/queen45-route-knot/build/forest_depth/queen/round45-route-cut'),
'cut46':Path('build/forest_depth/snapshots/queen46-route-knot/build/forest_depth/queen/round46-route-cut')}
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
r={'scope':'Independent offline explicit initial local purpose; not full fight, film, save or native rerun','runs':{}}
for n,p in paths.items():
 d=json.loads((p/'capture.json').read_text());re=json.loads((p/'receipt.json').read_text());snap=Path('build/forest_depth/snapshots/queen46-route-knot' if n=='cut46' else 'build/forest_depth/snapshots/queen45-route-knot');fs=d['frames'];es=d['events'];row=d['cases'][0]
 r['runs'][n]={'path':str(p),'capture_sha256':sha(p/'capture.json'),'receipt_sha256':sha(p/'receipt.json'),'source_before_after_identical':re['source_before']==re.get('source_after'),'source_count':len(re['source_before']),'independent_source_mismatches':[f for f,v in re['source_before'].items() if not(snap/f).exists() or sha(snap/f)!=v],'assertions':d['assertions'],'failures':d['failures'],'row':row,'continuous_ticks':all(f['tick']==i+1 for i,f in enumerate(fs)),'one_motor_increment_per_frame':all(b['motor_steps']-a['motor_steps']==1 for a,b in zip(fs,fs[1:])),'initial_actual_fields':fs[0]['fields'],'boss_policy':[e for e in es if e.get('event')=='policy_result' and e.get('target')=='boss'],'node_policy':[e for e in es if e.get('event')=='policy_result' and e.get('target')=='queen/weave_knot'],'player_policy':[e for e in es if e.get('event')=='policy_result' and e.get('target')=='player'],'node_commit':[e for e in es if e.get('event')=='route_node_damage_committed'],'node_collisions':[e for e in es if e.get('event')=='route_node_motion' and e.get('collision')],'previews':[e for e in es if e.get('event')=='candidate_route_preview'],'arrivals':[e for e in es if e.get('event')=='candidate_route_arrived'],'first_accepted_Boss_shot':next((e for e in es if e.get('event')=='accepted_shot' and e['tick']>=row['leg_start']),None),'first_fire_after_next_arrival':next((e for e in es if e.get('event')=='accepted_shot' and e['tick']>=max(a['tick'] for a in es if a.get('event')=='candidate_route_arrived')),None)}
# Compare all current production bytes between the two frozen workspaces, not just filenames.
s45=Path('build/forest_depth/snapshots/queen45-route-knot');s46=Path('build/forest_depth/snapshots/queen46-route-knot')
prod=[];diff=[]
for root in ['scripts','resources','scenes','config']:
 a={str(p.relative_to(s45)) for p in (s45/root).rglob('*') if p.is_file()};b={str(p.relative_to(s46)) for p in (s46/root).rglob('*') if p.is_file()}
 for p in sorted(a|b):
  prod.append(p)
  if p not in a or p not in b or sha(s45/p)!=sha(s46/p):diff.append(p)
r['production_compare']={'roots':['scripts','resources','scenes','config'],'files':len(prod),'different':diff}
(out/'Queen45-46-audit.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps({'prod':r['production_compare'],'runs':{k:{'failures':v['failures'],'source_mismatches':v['independent_source_mismatches'],'row':v['row'],'previews':v['previews'],'arrivals':v['arrivals'],'boss_policy':v['boss_policy']} for k,v in r['runs'].items()}},indent=2))
