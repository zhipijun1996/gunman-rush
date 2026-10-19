import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
result={'scope':'Readonly offline raw/source inspection; no engine; not player or audiovisual acceptance','sources':{},'cases':{}}
p23=json.loads((ROOT/'build/forest_depth/queen/whole23-review-package/package.json').read_text())
s23=ROOT/p23['snapshot'];s24=ROOT/'build/forest_depth/snapshots/queen24-purpose-pair'
for name,want in p23['source_sha256'].items():
 p=s23/name;result['sources'][name]={'23_sha':sha(p),'23_package_matches':sha(p)==want,'24_sha':sha(s24/name),'equal_23_24':p.read_bytes()==(s24/name).read_bytes()}
for label in ['H','edge']:
 t=json.loads((ROOT/f'build/forest_depth/queen/whole24-review-package/{label}-timeline.json').read_text());p=ROOT/t['capture'];r=json.loads(p.read_text());fs=r['frames'];es=r['events'];phases={}
 for f in fs:
  k=str(f['route_phase']);v=phases.setdefault(k,{'first':f['tick'],'last':f['tick'],'n':0,'x':[],'y':[]});v['last']=f['tick'];v['n']+=1;v['x'].append(f['player'][0]);v['y'].append(f['player'][1])
 for v in phases.values():
  for k in ['x','y']:v[k+'_range']=[min(v[k]),max(v[k])];del v[k]
 inputs=[e for e in es if e['event']=='actual_queued_input'];hooks=[e for e in es if e['event']=='actual_hook_target_contact'];damages=[e for e in es if e['event']=='policy_result'];hits=[e for e in damages if e['target']=='boss']
 result['cases'][label]={'capture':t['capture'],'sha':sha(p),'bound_sha_matches':sha(p)==t['capture_sha256'],'frames':len(fs),'continuous_ticks':list(range(1,len(fs)+1))==[f['tick'] for f in fs],'one_motor_per_frame':all(f['motor_steps']==f['tick'] for f in fs),'midroute_writes_declared':r['midroute_player_position_or_resource_writes'],'phases':phases,'player_damage_events':[e for e in damages if e['target']=='player'],'boss_hit_count':len(hits),'boss_damage':sum(e['amount'] for e in hits),'kill_tick':next((f['tick'] for f in fs if f['boss_hp']==0),None),'final_hp':fs[-1]['hp'],'final_energy':fs[-1]['energy'],'hook_contacts':hooks,'severs':[e for e in es if e['event']=='knot_health_severed'],'inputs_after_tick300':[e for e in inputs if e['tick']>300],'network_events':[e for e in es if e['event'] in ['network_phase_started','route_phase_started','perch_arrived']]}
(ROOT/'build/forest_depth/independent/queen23-whole/raw-audit.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:{a:b for a,b in v.items() if a in ['frames','continuous_ticks','one_motor_per_frame','kill_tick','final_hp','final_energy','boss_damage','phases']} for k,v in result['cases'].items()},indent=2))
