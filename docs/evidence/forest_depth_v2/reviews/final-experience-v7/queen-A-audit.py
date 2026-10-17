import json,hashlib
from pathlib import Path
out=Path('build/forest_depth/independent/final-experience-v7')
paths={
'hook40':'build/forest_depth/snapshots/queen40-third-intercept/build/forest_depth/queen/round40-third_hook/capture.json',
'shoot40':'build/forest_depth/snapshots/queen40-third-intercept/build/forest_depth/queen/round40-third_shoot/capture.json',
'refuge39':'build/forest_depth/snapshots/queen39-refuge-lifecycle/build/forest_depth/queen/round39-crossline_refuge/capture.json',
'oldH37':'build/forest_depth/snapshots/queen37-crossline-A/build/forest_depth/queen/round37-adaptive_full/capture.json',
'oldedge37':'build/forest_depth/snapshots/queen37-crossline-A/build/forest_depth/queen/round37-edge-full_edge/capture.json'}
ds={k:json.loads(Path(p).read_text()) for k,p in paths.items()}
a=ds['hook40']['frames'];b=ds['shoot40']['frames'];eq=all({k:v for k,v in x.items() if k!='queen_motor_id'}=={k:v for k,v in y.items() if k!='queen_motor_id'} for x,y in zip(a[:710],b[:710]));assert eq
r={'scope':'Independent offline raw only; not native/film/player acceptance','shared_prefix':{'equal_physical_frames':710,'only_excluded':'queen_motor_id','actual_compared':eq},'runs':{}}
for k,d in ds.items():
 fs=d['frames'];r['runs'][k]={'path':paths[k],'sha256':hashlib.sha256(Path(paths[k]).read_bytes()).hexdigest(),'assertions':d['assertions'],'failures':d['failures'],'frames':len(fs),'tick_continuous':all(f['tick']==i+1 for i,f in enumerate(fs)),'one_actual_motor_every_frame':all(y['motor_steps']-x['motor_steps']==1 for x,y in zip(fs,fs[1:])),'boss_start_hp':fs[0]['boss_hp'],'boss_end_hp':fs[-1]['boss_hp'],'player_end_hp':fs[-1]['hp'],'player_end_energy':fs[-1]['energy'],'field2_cut_events':[e for e in d['events'] if e.get('event')=='knot_health_severed' and e.get('field')==2],'player_policy_damage':[e for e in d['events'] if e.get('event')=='policy_result' and e.get('target')=='player'],'decisions':[e for e in d['events'] if e.get('event') in ['crossline_response_decision','crossline_response_departure','third_response_complete','actual_hook_target_contact']],'case':d['cases'][0]}
(out/'queen-A-audit.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({k:{x:v[x] for x in ['frames','boss_end_hp','player_end_hp','player_end_energy','tick_continuous','one_actual_motor_every_frame']} for k,v in r['runs'].items()},indent=2))
