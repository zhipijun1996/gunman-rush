import json,sys,copy,subprocess,hashlib
from pathlib import Path
R=Path.cwd();O=R/'build/plains_redesign/final_regression_review';sys.path.insert(0,str(R/'tools'));import run_plains_redesign_spatial_tests as s
H=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();root=R/'build/plains_redesign/scene_independent_review';complete=json.loads((root/'complete_receiver.json').read_text());residue=json.loads((root/'platform_residue.json').read_text());assert s.validate_receiver_fault(complete,True) and s.validate_native(complete,True);assert s.validate_receiver_fault(residue,False) and not s.validate_native(residue,True)
results=[]
for name in ['all_earth_removed','unknown_neighbor_id','shift_removed_fragment','shift_surviving_fragment','layer_before_changed','platform_only_claims_complete','fall_threshold_not_met']:
 d=copy.deepcopy(residue if name=='platform_only_claims_complete' else complete);f=d['receiver_fault']
 if name=='all_earth_removed':f['support_after']=[]
 elif name=='unknown_neighbor_id':
  before={x['instance_id'] for x in f['support_before']};row=next(x for x in f['support_after'] if x['instance_id'] in before);row['instance_id']=-100
 elif name=='shift_removed_fragment':f['removed_fragments'][0][0]+=1
 elif name=='shift_surviving_fragment':f['support_after'][0]['rect'][0]+=1
 elif name=='layer_before_changed':f['support_before'][0]['collision_layer']=2
 elif name=='platform_only_claims_complete':f['complete']=True;d['platform_only']=False
 elif name=='fall_threshold_not_met':d['observations'][0]['frames'][-1]['position'][1]=499
 refused=not (s.validate_native(d,True) if name=='fall_threshold_not_met' else s.validate_receiver_fault(d,True));assert refused,name;results.append(dict(case=name,rejected=refused))
receipts=json.loads((root/'independent_negative_receipts.json').read_text())
for row in receipts:
 label=row['label'];assert row['exit_code']==1;assert H(root/(label+'.json'))==row['output_sha256'];assert H(root/(label+'.log'))==row['log_sha256']
# Bound regenerated Foundry metadata separately from C2's clean committed bytes.
def diff(a,b,path=''):
 if type(a)!=type(b):return [path]
 if isinstance(a,dict):
  keys=a.keys()|b.keys();return [p for k in keys for p in ([path+'/'+str(k)] if k not in a or k not in b else diff(a[k],b[k],path+'/'+str(k)))]
 if isinstance(a,list):
  if len(a)!=len(b):return [path+'/length']
  return [p for i,(x,y) in enumerate(zip(a,b)) for p in diff(x,y,path+'/'+str(i))]
 return [] if a==b else [path]
changed=subprocess.check_output(['git','diff','--name-only','20f9b21','--','resources/foundry'],text=True).splitlines();rows=[]
for p in changed:
 oldbytes=subprocess.check_output(['git','show','20f9b21:'+p]);newbytes=Path(p).read_bytes();paths=sorted(diff(json.loads(oldbytes),json.loads(newbytes)));rows.append(dict(path=p,commit_sha256=hashlib.sha256(oldbytes).hexdigest(),actual_regenerated_sha256=H(p),changed_json_paths=paths))
(O/'fault_validation.json').write_text(json.dumps(dict(actual_independent_report='build/plains_redesign/scene_independent_review/report.md',reused_native_commands=receipts,complete_end_y=complete['observations'][0]['frames'][-1]['position'][1],platform_residue_end_y=residue['observations'][0]['frames'][-1]['position'][1],new_independent_python_counterexamples=results,no_godot_run_by_this_review=True),indent=2));(O/'foundry_regeneration_delta.json').write_text(json.dumps(rows,indent=2));print('FAULT guards checked',len(results),'Foundry actual changed',len(rows),'unique paths',sorted({p for r in rows for p in r['changed_json_paths']}))
