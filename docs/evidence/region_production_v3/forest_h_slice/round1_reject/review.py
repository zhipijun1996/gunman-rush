"""Independent native-proof consumer review. No engine or nested loop."""
import json,sys,copy,hashlib,tempfile,subprocess,time
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path.cwd()/'tools'))
import production_loop as p
import level_design as ld
import level_design_contracts as c
import run_forest_h_slice_tests as wrapper
OUT=Path('build/region_production_v3/independent/forest_round1');PORT=Path('docs/evidence/region_production_v3/forest_h_slice')
sha=lambda path:hashlib.sha256(Path(path).read_bytes()).hexdigest();read=lambda path:json.loads(Path(path).read_text())
req=read('build/verification/v3-forest-startup/V3-FOREST-STARTUP-01/1/review/host_request.json');task=req['task_contract']
assert req['request_hash']==p.digest({k:v for k,v in req.items() if k!='request_hash'}) and req['source_hash']==p.digest(p.snapshot())
ver=read(PORT/'verification.json');assert all(sha(f)==h for f,h in ver['source_files'].items())
data=read(PORT/'native/positive/capture.json');native_source=ld.source_files();receipt=read(PORT/'native/positive/capture.invocation.json')
assert receipt['source_files']==native_source
assert receipt['capture_sha256']==sha(PORT/'native/positive/capture.json')
assert receipt['log_sha256']==sha(PORT/'native/positive/capture.log')
assert receipt['exit_code']==0 and len(data['observations'])==169 and not c.validate_forest_h_slice(data)
record=p.quality.read_json(p.quality.local_file(p.ROOT,task['quality_record']))
accept=p.check_task_quality(task);assert accept['scope_complete'] and not accept['content_complete']
auto=ld.route_request('制作荆棘森林');production=ld.route_request('制作荆棘森林',phase='production')
assert auto['phase']=='prototype' and len(auto['tasks'])==1 and len(auto['production_plan'])==9 and len(production['tasks'])==9
results={'request_hash':req['request_hash'],'scope':'G0/G1 H-only isolated actual native-proof review; Python mutations are not native runs','original_positive':{'ticks':len(data['observations']),'assertions':data['assertions'],'exit_code':receipt['exit_code'],'capabilities':data['capability_snapshot']['abilities']},'original_quality_acceptance':{'scope_complete':accept['scope_complete'],'content_complete':accept['content_complete']},'native_source_inventory_files':len(native_source),'mutation_cases':[],'uid_cases':[]}
for variant in ['missing-anchor','no-hook']:
 negative=read(PORT/'native'/variant/'capture.json');inv=read(PORT/'native'/variant/'capture.invocation.json')
 assert inv['exit_code']==1 and len(negative['observations'])==480 and c.validate_forest_h_slice(negative)
 spoof=copy.deepcopy(negative);spoof.update(failures=[],branch_landed=True,returned=True,case='positive')
 errors=c.validate_forest_h_slice(spoof);assert errors
 results['mutation_cases'].append({'case':'actual_negative_'+variant+'_relabel_reached','rejected':bool(errors),'errors':errors})
mutations={
 'erase_hook_kick':lambda d:d.update(events=[e for e in d['events'] if e['kind']!='hook_kick']),
 'erase_all_landing_events':lambda d:d.update(events=[e for e in d['events'] if e['kind']!='landed']),
 'truncate_whole_return':lambda d:d.update(observations=d['observations'][:90],events=[e for e in d['events'] if e['tick']<=90],returned=True),
 'all_hook_events_outside_observed_time':lambda d:[e.update(tick=0) for e in d['events'] if e['kind'].startswith('hook_')],
 'erase_observed_hook_states_keep_event_counts':lambda d:[f.update(traversal='idle',hook_used=False) for f in d['observations']],
 'router_request_after_route':lambda d:d['input_requests'][0].update(tick=1000000),
 'midroute_resource_and_health_injection':lambda d:d['observations'][50].update(energy=99999,health=0),
}
for capability in ['W','D','U1','U2']:
 mutations['extra_capability_'+capability]=lambda d,capability=capability:d['capability_snapshot']['abilities'].append(capability)
for name,mutate in mutations.items():
 altered=copy.deepcopy(data);mutate(altered);errors=c.validate_forest_h_slice(altered)
 (OUT/(name+'.json')).write_text(json.dumps(altered,ensure_ascii=False,indent=2)+'\n')
 results['mutation_cases'].append({'case':name,'rejected':bool(errors),'errors':errors})
# Full original quality consumer on actual fixture refs and isolated mutation copies.
# Patching only record lookup selects the copied evidence; every receipt/hash/native
# completion check remains real and active.
original_read=p.quality.read_json
for name in ['all_hook_events_outside_observed_time','erase_observed_hook_states_keep_event_counts','router_request_after_route','midroute_resource_and_health_injection']:
 folder=OUT/('full_consumer_'+name);folder.mkdir();capture=folder/'capture.json';capture.write_bytes((OUT/(name+'.json')).read_bytes())
 log=capture.with_suffix('.log');log.write_bytes((PORT/'native/positive/capture.log').read_bytes())
 inv=copy.deepcopy(receipt);inv['capture']=str(capture);inv['capture_sha256']=sha(capture);inv['command']=[a if not a.startswith('--output=') else '--output=res://'+str(capture) for a in inv['command']]
 wrapper.write(capture.with_suffix('.invocation.json'),inv)
 selected=copy.deepcopy(record);selected['region_proofs']=[{'path':str(capture),'sha256':sha(capture)}]
 def read_selected(path):
  return selected if Path(path)==p.quality.local_file(p.ROOT,task['quality_record']) else original_read(path)
 with patch.object(p.quality,'read_json',side_effect=read_selected):outcome=p.check_task_quality(task)
 results['mutation_cases'].append({'case':'full_original_quality_'+name,'rejected':not outcome['scope_complete'],'quality_errors':outcome['quality']['errors']})
for mode in ['existing','tracked','tracked_scene_reference','untracked_scene_reference','tracked_gd_uid_reference']:
 with tempfile.TemporaryDirectory() as temp:
  root=Path(temp);relative=wrapper.DEV_UIDS[0];side=root/relative;side.parent.mkdir(parents=True);side.write_text('uid://independent_reference\n');before={relative:mode=='existing'};tracked=[relative] if mode=='tracked' else []
  if 'reference' in mode:
   ref=root/('consumer.gd' if mode=='tracked_gd_uid_reference' else 'scene.tscn');ref.write_text('const SAMPLE = preload("uid://independent_reference")\n' if ref.suffix=='.gd' else '[ext_resource type="Script" uid="uid://independent_reference"]\n')
   if mode!='untracked_scene_reference':tracked.append(ref.relative_to(root).as_posix())
  outcome=wrapper.preserve_new_unreferenced_uids(root,before,tracked,root/'archived')
  results['uid_cases'].append({'case':mode,'uid_preserved':side.exists(),'outcome':outcome})
results['python_checks']=[]
for file in ['tests/test_production_loop.py','tests/test_level_design_routing.py','tests/test_level_design_contracts.py','tests/test_level_region_context.py','tests/test_level_experience.py']:
 started=time.monotonic();run=subprocess.run([sys.executable,file],capture_output=True,text=True,timeout=60);log=OUT/(Path(file).stem+'.log');log.write_text(run.stdout+run.stderr)
 results['python_checks'].append({'command':[sys.executable,file],'exit_code':run.returncode,'seconds':round(time.monotonic()-started,3),'log':str(log),'tail':(run.stdout+run.stderr).splitlines()[-4:]})
results['source_unchanged']=req['source_hash']==p.digest(p.snapshot());assert results['source_unchanged']
(OUT/'results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(results,ensure_ascii=False,indent=2))
