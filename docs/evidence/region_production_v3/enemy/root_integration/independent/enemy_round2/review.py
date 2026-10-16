"""Read-only independent R2 evidence validation; no native engine execution."""
import sys,json,hashlib,importlib.util,zipfile,copy,subprocess,time,ast
from pathlib import Path
sys.path.insert(0,str(Path.cwd()/'tools'))
import production_loop as p
spec=importlib.util.spec_from_file_location('bell','tools/run_root_bell_tests.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
OUT=Path('build/region_production_v3/independent/enemy_round2');PORT=Path('docs/evidence/region_production_v3/enemy');R2=PORT/'round2';REC=PORT/'controller_revalidation'
sha=lambda path:hashlib.sha256(Path(path).read_bytes()).hexdigest();read=lambda path:json.loads(Path(path).read_text())
req=read('build/verification/v3-enemy-revalidation/V3-ENEMY-01/1/review/host_request.json')
assert req['source_hash']==p.digest(p.snapshot()) and req['request_hash']==p.digest({k:v for k,v in req.items() if k!='request_hash'})
assert all(sha(s['path'])==s['sha256'] for s in req['skills'])
assert m.sources()==read(REC/'revalidation_receipt.json')['enemy_source_sha256']==read(R2/'recheck_report.json')['current_acceptance_sources']
assert all(sha(PORT/f)==r['sha256'] and (PORT/f).stat().st_size==r['bytes'] for f,r in read(PORT/'artifact_index.json')['files'].items())
archive=zipfile.ZipFile(R2/'round1_exact_sources.zip');manifest=json.loads(archive.read('source_manifest.json'))['source_sha256'];native=read(PORT/'g1_report.json')
assert manifest==native['source_before']==native['source_after']
assert all(hashlib.sha256(archive.read(f)).hexdigest()==h for f,h in manifest.items())
assert all(m.sources()[f]==manifest[f] for f in m.SOURCES if f!='tools/run_root_bell_tests.py')
raw=(PORT/'g1_capture.json').read_bytes();runtime=(PORT/'g1_runtime.log').read_bytes();data=json.loads(raw)
original_stats=m.validate_evidence(raw,native,runtime,manifest,native['source_commit'])
refused_content=m.tamper_checks(data);refused_source=m.provenance_tamper_checks(raw,native,runtime,manifest,native['source_commit'])
assert len(refused_content)==41 and len(refused_source)==9
results={'request_hash':req['request_hash'],'reviewer':'/root/v3_independent_engineering','scope':'G0/G1 historical authentic native165 independently revalidated by current Python consumer; no engine replay','current_source_sha256':m.sources(),'original_native_stats':original_stats,'original39_artifacts_unchanged':True,'native_art_fixture13_sources_unchanged':True,'frozen_R2_all14_sources_unchanged':True,'content_refusals':refused_content,'source_refusals':refused_source,'original_independent_bad_cases':[],'extra_cases':[]}
badzip=zipfile.ZipFile(R2/'independent_round1_originals.zip')
original_dir=Path('build/region_production_v3/independent/enemy_round1')
for name in ['erase_pause_inactive_save_duplicate_cases','erase_interrupt_warning_frames','erase_all_restored_cancel_trace','replace_six_width_directions_with_one_run_copies','wrong_declared_source_scope_and_formal_claim']:
 payload=badzip.read(name+'.json');assert payload==(original_dir/(name+'.json')).read_bytes()
 altered=json.loads(payload);patched=copy.deepcopy(native);patched['capture_sha256']=hashlib.sha256(payload).hexdigest()
 row={'case':name,'original_sha256':hashlib.sha256(payload).hexdigest()}
 for label,call in [('capture',lambda:m.validate_capture(altered)),('full_evidence_with_rehashed_receipt',lambda:m.validate_evidence(payload,patched,runtime,manifest,native['source_commit']))]:
  try:call();row[label]={'rejected':False}
  except ValueError as e:row[label]={'rejected':True,'reason':str(e)}
  assert row[label]['rejected']
 results['original_independent_bad_cases'].append(row)
# Reverse role labels alone while preserving all physical frames.
changed=copy.deepcopy(data)
a=next(c for c in changed['cases'] if c['id']=='width_400_dir_1');b=next(c for c in changed['cases'] if c['id']=='width_400_dir_-1')
a['calibration'],b['calibration']=b['calibration'],a['calibration'];a['id'],b['id']=b['id'],a['id']
try:m.validate_capture(changed);raise AssertionError('Direction relabel passed')
except ValueError as e:results['extra_cases'].append({'case':'swap_direction_metadata_ids_leave_physics','rejected':True,'reason':str(e)})
# Existing essential warning samples must retain their causal accepted damage IDs.
changed=copy.deepcopy(data);c=next(c for c in changed['cases'] if c['id']=='real_projectile_interrupt')
for e in c['events']:
 if e['kind']=='damage':e['id']='forged_other_projectile:99999'
try:m.validate_capture(changed);raise AssertionError('Projectile identity relabel passed')
except ValueError as e:results['extra_cases'].append({'case':'coherent_counts_wrong_projectile_identity','rejected':True,'reason':str(e)})
# Old assertions remain as a suffix; old five erasure entries remain unchanged.
old=ast.parse(archive.read('tools/run_root_bell_tests.py').decode());new=ast.parse(Path('tools/run_root_bell_tests.py').read_text())
def fun(tree,name):return next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name==name)
assert ast.dump(ast.Module(body=fun(old,'validate_capture').body,type_ignores=[]),include_attributes=False)==ast.dump(ast.Module(body=fun(new,'validate_capture').body[1:],type_ignores=[]),include_attributes=False)
results['original_validate_assertion_body_preserved']=True
migration=read(REC/'migration.json');oldstate=Path('build/verification/v3-enemy/state.json');oldresponse=Path('build/verification/v3-enemy/V3-ENEMY-01/2/implement/host_response.json')
assert sha(oldstate)==migration['actual_legacy_resume']['old_state_sha256']==sha(REC/'legacy_state.json')
assert oldresponse.read_bytes()==(REC/'legacy_r2_unconsumed_response.json').read_bytes()
assert sha(REC/'legacy_production_loop.py.source')==migration['legacy_controller_sha256']
assert sha('tools/production_loop.py')==migration['new_controller_sha256']=='de7469335f19f0ada676197c0d0bb1d97b93839012cd9978ed10c9ddd4df99c8'
assert 'Mission/source changed outside loop' in (REC/'legacy_resume.log').read_text() and migration['actual_legacy_resume']['exit_code']==1
assert not oldresponse.with_name('invocation.json').exists() and not oldresponse.with_name('result.json').exists()
legacy=read(oldstate);newstate=read('build/verification/v3-enemy-revalidation/state.json')
assert legacy['calls']==3 and newstate['calls']==2 and legacy['calls']+newstate['calls']==5<=6
results['controller_migration']={'legacy_calls':3,'new_calls':2,'combined':5,'cap':6,'legacy_state_unchanged':True,'legacy_R2_response_unconsumed':True,'legacy_actual_resume_exit':1,'accepted_new_controller_sha':migration['new_controller_sha256']}
cp=p._restore_checkpoint(req['task_contract'],newstate['tasks']['V3-ENEMY-01'],Path('build/verification/v3-enemy-revalidation').resolve(),worker_mode='invoke_host')
assert cp['round_record']['checks'][0]['status']=='passed'
assert 'ALL TESTS: 5676 assertions, 0 failures' in Path('build/verification/v3-enemy-revalidation/V3-ENEMY-01/1/core.log').read_text()
results['actual_fresh_parent_core']='5676 assertions,0 failures; source/log checkpoint verified; reviewer did not run engine'
command=[sys.executable,'tools/run_root_bell_tests.py','--recheck-existing',str(PORT),'--source-archive',str(R2/'round1_exact_sources.zip'),'--native-source-commit',native['source_commit'],'--output-dir','build/root_bell/independent_review_r2_revalidation']
start=time.monotonic();run=subprocess.run(command,capture_output=True,text=True,timeout=60);(OUT/'fresh_python_cli.log').write_text(run.stdout+run.stderr)
assert run.returncode==0
results['fresh_python_cli']={'command':command,'exit_code':run.returncode,'seconds':round(time.monotonic()-start,3),'log':str(OUT/'fresh_python_cli.log'),'output':run.stdout,'native_reexecuted':False}
results['stage_quality']=p.check_task_quality(req['task_contract'])
assert results['stage_quality']['scope_complete'] and not results['stage_quality']['content_complete']
results['source_unchanged']=req['source_hash']==p.digest(p.snapshot());assert results['source_unchanged']
(OUT/'results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in results.items() if k not in ['current_source_sha256','content_refusals','source_refusals','stage_quality']},ensure_ascii=False,indent=2))
