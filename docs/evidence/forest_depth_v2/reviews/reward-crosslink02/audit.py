import sys,pathlib,json,hashlib,copy
repo=pathlib.Path('/workspace/gunman-rush-design');root=repo/'build/forest_depth/snapshots/reward_crosslink02';sys.path.insert(0,str(root/'tools'));import run_forest_depth_enemies as reader
base=root/'build/forest_depth/ecology/reward_crosslink02';paths=sorted(base.glob('[01]*/capture.json'));ds=[json.loads(p.read_text()) for p in paths];receipt=json.loads((base/'receipt.json').read_text())
result={'source_files':len(receipt['source_before']),'source_mismatches':[k for k,h in receipt['source_before'].items() if not(root/k).is_file() or hashlib.sha256((root/k).read_bytes()).hexdigest()!=h],'reader_sha256':hashlib.sha256((root/'tools/run_forest_depth_enemies.py').read_bytes()).hexdigest(),'base_sha256':hashlib.sha256((root/'tools/run_forest_depth_region.py').read_bytes()).hexdigest(),'prefix450':{},'cases':[],'mutants':[]}
for key in ('frames','requests'):
 p=[[f for f in d[key] if f['tick']<=450] for d in ds];result['prefix450'][key]={'count':[len(v) for v in p],'exact':p[0]==p[1]}
for path,d in zip(paths,ds):
 reader.validate_expedition(d)
 result['cases'].append({'file':str(path.relative_to(repo)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'offline_reader':'ACCEPT','legs':d['completed_legs'],'player_hurts':[e for e in d['events'] if e['kind']=='committed_damage' and e.get('target')=='player'],'lift_exit':d['lift_exit'],'C_exit':d['crown_return_exit'],'final':d['final_snapshot'],'hook_anchors':[r['id'] for r in d['manifest']['hook_anchors']],'connections':[{'id':e.get('id'), 'a':e.get('a'),'b':e.get('b')} for e in d['manifest']['connections'] if e.get('id') in ('outer_to_inner','crown_reverse_return')],'actor_epochs':sorted(set(f['actor_epoch'] for f in d['frames'])),'stage_epochs':sorted(set(f['stage_epoch'] for f in d['frames']))})
def trial(name,edit):
 d=copy.deepcopy(ds[0]);edit(d)
 try:reader.validate_expedition(d);out={'name':name,'result':'ACCEPT'}
 except Exception as e:out={'name':name,'result':'REJECT','reason':str(e)}
 result['mutants'].append(out)
trial('delete_actual_lower_body_contact',lambda d:d.update(events=[e for e in d['events'] if e['kind']!='lift_actual_contact']))
trial('delete_actual_first_free_event',lambda d:d.update(events=[e for e in d['events'] if e['kind']!='lift_first_actual_free_frame']))
trial('hide_actual_free_frame',lambda d:d['frames'][484].update(hook_state='hook_kick'))
trial('delete_frame471',lambda d:d.update(frames=[f for f in d['frames'] if f['tick']!=471]))
trial('remove_upper_R_request',lambda d:d.update(requests=[r for r in d['requests'] if not(r['tick']==545 and r['kind']=='shoot_release')]))
trial('truncate_at_C',lambda d:d.update(frames=[f for f in d['frames'] if f['tick']<=582]))
trial('forge_C_saved_open_false',lambda d:d.update(gate_saved_open=False))
trial('remove_reward_pointer',lambda d:d.update(pointer_events=[]))
trial('erase_lift_cost',lambda d:d['frames'][485].update(energy=100.0))
(repo/'build/forest_depth/independent/reward-crosslink02/raw-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'sources':result['source_files'],'mismatches':result['source_mismatches'],'prefix':result['prefix450'],'controls':result['mutants']},ensure_ascii=False,indent=2))
