"""Independent R1 replay and adjacent causal perturbations; writes only this ignored review folder."""
import copy, importlib.util, pathlib, json, hashlib, sys
sys.path.insert(0,str(pathlib.Path('tools').resolve()))
import run_plains_experience_golden_tests as current
base=pathlib.Path('build/plains_redesign/review_experience_completion_r2')
def load_module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
old=load_module('rejected_validator',pathlib.Path('docs/evidence/plains_redesign/experience/causal_repair/actual_repair/rejected_validator.py'))
original_drill=load_module('r1_independent_drill',pathlib.Path('build/plains_redesign/review_experience_completion/reproduce_validator_gaps.py'))
source=pathlib.Path('build/plains_redesign/experience/run_igiwoygr/positive.json');data=json.loads(source.read_text())
results=[]
for name in ['remove_all_jump_accepts','remove_all_landing_accepts','remove_all_drop_through','erase_callback_event_timing','remove_remote_latch_health_commit']:
    bad=original_drill.mutate(data,name)
    results.append({'kind':'original_R1','case':name,'old_accepted':old.valid(bad),'current_accepted':current.valid(bad)})
for case in ['absent_callback','absent_entire_return','changed_park_clock','wrong_end_position']:
    bad=copy.deepcopy(data);obs=next(o for o in bad['observations'] if o['kind']=='creek')
    if case=='absent_callback':obs['events']=[e for e in obs['events'] if e['kind']!='grounded_island_callback']
    elif case=='absent_entire_return':obs['frames']=obs['frames'][:obs['visits'][0]['tick']+1]
    elif case=='changed_park_clock':obs['frames'][obs['visits'][0]['tick']-4]['latches'][0]['motion_clock']+=1
    else:obs['frames'][-1]['position']=[420,192]
    results.append({'kind':'old_adjacent','case':case,'current_accepted':current.valid(bad)})
for case in ['callback_same_position_wrong_frame','jump_input_missing_one','landing_support_lie','reboard_floor_transition_lie','drop_same_position_wrong_tick','remote_damage_credit_instead_of_hit','remote_impact_after_damage','remote_sequence_without_first_hit','creek_restart_before_boat_support','tolerance_landing_receipt_missing','tolerance_jump_position_wrong','resource_consume_wrong_frame','resource_regeneration_ground_lie']:
    bad=copy.deepcopy(data);creek=next(o for o in bad['observations'] if o['kind']=='creek');remote=next(o for o in bad['observations'] if o['kind']=='remote');es=creek['events'];rs=remote['events'];pick=lambda seq,kind:next(e for e in seq if e['kind']==kind)
    if case=='callback_same_position_wrong_frame':pick(es,'grounded_island_callback')['tick']+=1
    elif case=='jump_input_missing_one':es.remove(next(e for e in es if e['kind']=='input_request' and e['action']=='jump'))
    elif case=='landing_support_lie':creek['frames'][[e for e in es if e['kind']=='accepted_landing'][2]['tick']]['support'][0]=False
    elif case=='reboard_floor_transition_lie':creek['frames'][[e for e in es if e['kind']=='accepted_landing'][3]['tick']]['grounded']=False
    elif case=='drop_same_position_wrong_tick':next(e for e in es if e['kind']=='input_request' and e['action']=='drop_through')['tick']+=1
    elif case=='remote_damage_credit_instead_of_hit':pick(rs,'latch_health_commit')['operation']='grant'
    elif case=='remote_impact_after_damage':[e for e in rs if e['kind']=='projectile_impact'][-1]['tick']+=1
    elif case=='remote_sequence_without_first_hit':remote['events'].remove(pick(rs,'projectile_impact'))
    elif case=='creek_restart_before_boat_support':
        e=[e for e in es if e['kind']=='latch_committed'][-1];e['tick']=[e for e in es if e['kind']=='accepted_landing'][3]['tick']-1
    elif case=='tolerance_landing_receipt_missing':bad['tolerance'][0]['events']=[e for e in bad['tolerance'][0]['events'] if e['kind']!='accepted_landing']
    elif case=='tolerance_jump_position_wrong':pick(bad['tolerance'][0]['events'],'accepted_jump')['position'][1]+=2
    elif case=='resource_consume_wrong_frame':next(e for e in es if e['kind']=='energy_transaction' and e['operation']=='consume')['tick']+=1
    elif case=='resource_regeneration_ground_lie':
        o=next(o for o in bad['observations'] if o['low']);e=next(e for e in o['events'] if e['kind']=='energy_transaction' and e['amount']>0);o['frames'][e['tick']-1]['grounded']=False
    for o in bad['observations']:o['events'].sort(key=lambda e:e['tick'])
    results.append({'kind':'new_independent_adjacent','case':case,'current_accepted':current.valid(bad)})
result={'source':str(source),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'honest_old_accepted':old.valid(data),'honest_current_accepted':current.valid(data),'old_checker_sha256':hashlib.sha256(pathlib.Path(old.__file__).read_bytes()).hexdigest(),'current_checker_sha256':hashlib.sha256(pathlib.Path(current.__file__).read_bytes()).hexdigest(),'results':results}
(base/'causal_recheck.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
assert result['honest_old_accepted'] and result['honest_current_accepted']
assert all(not row['current_accepted'] for row in results)
assert all(row['old_accepted'] for row in results if row['kind']=='original_R1')
