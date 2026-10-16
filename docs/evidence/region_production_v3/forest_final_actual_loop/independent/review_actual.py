import sys,json,hashlib,copy,subprocess,time
from pathlib import Path
sys.path.insert(0,'tools')
import production_loop as p
from level_design_contracts import validate_forest_h_slice
from level_design import source_files
R=Path.cwd(); O=R/'build/forest_final_actual_loop/independent'
req=json.loads((R/'build/verification/forest_final_actual_loop/level-new_region-thorn_forest-prototype/1/review/host_request.json').read_text())
out={}
out['request_hash_actual']=p.digest({k:v for k,v in req.items() if k!='request_hash'})
out['request_hash_match']=out['request_hash_actual']==req['request_hash']
out['source_hash_actual']=p.digest(p.snapshot());out['source_hash_match']=out['source_hash_actual']==req['source_hash']
out['live_lease']=time.time()<req['expires_at'];out['skills']={x['path']:hashlib.sha256((R/x['path']).read_bytes()).hexdigest()==x['sha256'] for x in req['skills']}
out['quality']=p.check_task_quality(req['task_contract'])
base=R/'docs/evidence/region_production_v3/forest_final_actual_loop/native'
sources=source_files(R);out['source_count']=len(sources);out['cases']={}
for case in ['positive','missing-anchor','no-hook']:
 c=json.loads((base/case/'capture.json').read_text());v=json.loads((base/case/'capture.invocation.json').read_text());log=(base/case/'capture.log').read_text();orig=R/v['capture']
 out['cases'][case]={'errors':validate_forest_h_slice(c),'exit':v['exit_code'],'ticks':len(c['observations']),'assertions':c['assertions'],'source_files_match':sources==v['source_files'],'capture_hash_match':hashlib.sha256((base/case/'capture.json').read_bytes()).hexdigest()==v['capture_sha256'],'log_hash_match':hashlib.sha256((base/case/'capture.log').read_bytes()).hexdigest()==v['log_sha256'],'portable_original_match':orig.read_bytes()==(base/case/'capture.json').read_bytes(),'leak_lines':[x for x in log.splitlines() if any(s in x for s in ['leaked','resources still','PagedAllocator','DummyTexture','SCRIPT ERROR','Parse Error'])]}
positive=json.loads((base/'positive/capture.json').read_text())
variants={}
a=copy.deepcopy(positive);a['events']=[];variants['deleted_events']=a
a=copy.deepcopy(positive);a['input_requests'][0]['tick']=len(a['observations']);variants['request_after_chain']=a
a=copy.deepcopy(positive)
for f in a['observations']:f['traversal']='free';f['hook_used']=False
variants['coherent_no_hook_states']=a
a=copy.deepcopy(positive);a['observations'][-1]['health']=0;variants['dead_return']=a
a=copy.deepcopy(positive)
for f in a['observations']:f['energy']=1e7
variants['overspent_energy']=a
a=copy.deepcopy(positive);a['observations']=a['observations'][:-20];variants['missing_return']=a
a=copy.deepcopy(positive);a['capability_snapshot']['abilities'].append('D');variants['hidden_D']=a
out['tamper']={}
for name,value in variants.items():
 errors=validate_forest_h_slice(value);(O/(name+'.json')).write_text(json.dumps(value))
 out['tamper'][name]={'rejected':bool(errors),'errors':errors}
for test in ['tests/test_level_design_contracts.py','tests/test_level_design_routing.py','tests/test_level_region_context.py']:
 proc=subprocess.run(['python3',test],capture_output=True,text=True);(O/(Path(test).stem+'.log')).write_text(proc.stdout+proc.stderr);out[test]={'exit':proc.returncode,'last_lines':(proc.stdout+proc.stderr).splitlines()[-5:]}
# Read complete binding Skills and authoritative docs and record byte identity.
paths=[x['path'] for x in req['skills']]+['AGENTS.md','docs/current_state.md','docs/handoff.md','docs/design/player_actions/README.md','docs/design/player_actions/regions_v0.3.md','docs/design/player_actions/weapons_v0.8.md','docs/quality/level_quality_dimensions.md','docs/quality/review_method.md','docs/quality/policy.json']
out['read_authorities']={path:{'bytes':len((R/path).read_bytes()),'sha256':hashlib.sha256((R/path).read_bytes()).hexdigest()} for path in paths}
out['request_live_after']=time.time()<req['expires_at'];out['source_unchanged_after']=p.digest(p.snapshot())==req['source_hash']
(O/'actual_results.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in out.items() if k not in ['read_authorities','cases','quality','tamper']},ensure_ascii=False,indent=2));print('quality',out['quality']['scope_complete'],out['quality']['content_complete'],out['quality']['quality']['errors']);print('cases',[(k,v['exit'],v['ticks'],v['source_files_match']) for k,v in out['cases'].items()]);print('tamper',[(k,v['rejected']) for k,v in out['tamper'].items()])
