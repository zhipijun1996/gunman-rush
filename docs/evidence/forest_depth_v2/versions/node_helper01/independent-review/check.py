from pathlib import Path
import json,hashlib,re,importlib.util,sys,copy
R=Path.cwd();O=R/'build/forest_depth/review/version-node-helper01';P=R/'build/forest_depth/versions/node_helper01';A=R/'build/forest_depth/snapshots/version_lifecycle01';B=R/'build/forest_depth/snapshots/version_node_helper01';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
original=(A/'tests/forest_depth_version_runner.gd').read_text();runner=(B/'tests/forest_depth_version_runner.gd').read_text();helper=(B/'tests/forest_depth_version_app_case.gd').read_text();original_body=original[original.index('func app_case(map_index: int) -> void:'):]
reconstructed=helper[helper.index('func run(map_index: int) -> void:'):].replace('func run(map_index: int) -> void:','func app_case(map_index: int) -> void:',1).replace('get_tree().root.add_child(app)','root.add_child(app)').replace('legacy_version','LEGACY.VERSION').replace('reporter.get_ref().cases.append(identity)','cases.append(identity)')
assert reconstructed==original_body
assert runner[:runner.index('func app_case(map_index: int) -> void:')]==original[:original.index('func app_case(map_index: int) -> void:')].replace('const AUDIO := preload("res://tests/audio_teardown.gd")\n','')
oldframes=original[original.index('func frames('):original.index('func run()')].replace('await physics_frame','await get_tree().physics_frame').replace('await process_frame','await get_tree().process_frame')
newframes=helper[helper.index('func frames('):helper.index('func run(map_index: int)')];assert oldframes==newframes
assert 'var reporter: WeakRef' in helper and 'load("res://tests/forest_depth_version_app_case.gd").new()' in runner and 'await helper.run(map_index)\n\thelper.free()' in runner
snap=json.loads((P/'snapshot-receipt.json').read_text());host=json.loads((P/'host-receipt.json').read_text());assert snap['source_files']==json.loads((B/'build/snapshot-receipt.json').read_text())['source_files'];assert len(snap['source_files'])==2011
assert set(snap['controlled_delta'])=={'tests/forest_depth_version_runner.gd','tests/forest_depth_version_app_case.gd'}
assert all((B/p).is_file() and sha(B/p)==h for p,h in snap['source_files'].items())
assert all(sha(A/p)==h for p,h in snap['baseline_source_files'].items())
for p,h in snap['source_files'].items():
 if p not in snap['controlled_delta']:assert h==snap['baseline_source_files'][p]
assert host['source_before']==host['source_after'] and host['source_guard'] and host['all_snapshot_raw_bytes_unchanged'] and host['probe_guard'] and host['static_passed'] and host['full_wrapper_exit_code']==0
for n in ['forest_depth_version_runner.gd','forest_depth_version_app_case.gd']:assert (P/n).read_bytes()==(B/'tests'/n).read_bytes()
N=B/'build/forest_depth/versions';old=json.loads((A/'build/forest_depth/versions/lifecycle01/capture.json').read_text());new=json.loads((N/'node_helper_full01/capture.json').read_text());assert new['assertions']==90 and new['failures']==0 and old['checks']==new['checks'] and old['cases']==new['cases'] and len(new['cases'])==11
receipt=json.loads((N/'node_helper_full01/receipt.json').read_text());assert receipt['passed'] and receipt['source_guard'] and receipt['source_before']==receipt['source_after']
for n,h in receipt['logs'].items():assert sha(N/'node_helper_full01'/n)==h
assert sha(B/'build/snapshot-receipt.json')==receipt['runtime_snapshot_receipt_sha256']
errors=re.compile(r'(?m)SCRIPT ERROR:|Parse Error:|SHADER ERROR:|^ERROR:|ObjectDB.*leaked|resources? still in use at exit')
logs={}
for relative in ['node_helper01/import.log','node_helper01/load_only.log','node_helper_full01/import.log','node_helper_full01/native.log']:
 p=N/relative;text=p.read_text();assert 'Godot Engine v4.7.2.' in text and not errors.search(text);logs[relative]=sha(p)
assert re.search(r'^FOREST DEPTH VERSIONS: 90 assertions, 0 failures$',(N/'node_helper_full01/native.log').read_text(),re.M)
probeA=A/'build/forest_depth/versions/static_dependency01/load_full.gd';probeB=N/'node_helper01/load_only.gd';assert probeA.read_bytes()==probeB.read_bytes() and sha(probeB)==host['probe_sha256'];assert 'script=null' in probeB.read_text() and 'script.new' not in probeB.read_text()
oldload=(A/'build/forest_depth/versions/static_dependency01/load_full.log').read_text();assert errors.search(oldload) and 'scripts/player/player_tuning.gd (GDScript)' in oldload
assert not errors.search((A/'build/forest_depth/versions/static_dependency01/typed_App.log').read_text())
assert sha(B/'tools/run_forest_depth_versions.py')==sha(A/'tools/run_forest_depth_versions.py') and sha(B/'tools/run_tests.py')==sha(A/'tools/run_tests.py')
sys.path.insert(0,str(B/'tools'));spec=importlib.util.spec_from_file_location('versions',B/'tools/run_forest_depth_versions.py');v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v);v.validate(new)
neg=[]
for mutation in ['missing_app','missing_delegate','wrong_queen_admission','failed_assertion','unreleased_tuning']:
 x=copy.deepcopy(new)
 if mutation=='missing_app':x['cases']=[r for r in x['cases'] if not(r['id']=='app_legacy' and r['map']==2)]
 elif mutation=='missing_delegate':x['cases']=[r for r in x['cases'] if r is not x['cases'][0]]
 elif mutation=='wrong_queen_admission':next(r for r in x['cases'] if r['id']=='v2_map2_experimental')['boss_contract']['admission']='promoted'
 elif mutation=='failed_assertion':x['checks'][0]['passed']=False
 elif mutation=='unreleased_tuning':x['exit_lifecycle']['tuning']['after_run_return_alive']=True
 try:v.validate(x)
 except (ValueError,AssertionError):neg.append({'mutation':mutation,'rejected':True})
 else:raise AssertionError(mutation)
result={'status':'ACCEPT','scope':'Only controlled test-runner Nodehelper extraction and observed Godot4.7.2 full version-compatibility regression. Not production promotion or v2 gameplay/fun/device acceptance.','reviewer':'/root/forest_runtime_review','independence':'Did not author candidate/runner/helper or run native. Independently read source, reconstructed method bodies, checked original/frozen inventories, raw logs, ledger/cases, and actual Python negative controls.','mechanical_app_and_dispose_bodies_equal':True,'frame_waits_equivalent_no_added_delay':True,'non_app_runner_prefix_unchanged_except_AUDIO_dependency':True,'production_sources_byte_identical':True,'snapshot_files':2011,'checks_exact_original':90,'cases_exact_original':11,'engine':'4.7.2.stable.official.ed1daf0bf','native_cap_seconds':90,'import_cap_seconds':90,'old_load_only_still_leaks_PlayerTuning_script':True,'typed_App_unused_original_control_clean':True,'new_identical_load_probe_clean':True,'raw_log_sha256':logs,'negative_controls':neg,'limitations':['Controlled original source basis plus two test-file delta, not fresh verification of later main overlays.','This establishes a dependency/lifetime-sensitive test loader remedy in the observed build; it does not identify a unique engine SCC/cache implementation bug or prove universal Godot fix.','Source-contract.json retains its prepared/unexecuted wording; actual execution is established separately by host/full receipts and raw logs.']}
(O/'review.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
