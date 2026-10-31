from pathlib import Path
import json,hashlib,subprocess,ast,re,collections,wave,sys
R=Path('/workspace/gunman-rush');BASE='840108da9ae91e412dc9f1d8a38ccdad0229bb11';A=R/'docs/creative_direction/archive/creative-v25-before-bellstrider-rework';checks=[]
def ck(n,v,d=None):checks.append({'id':n,'passed':bool(v),'detail':d})
def sha(b):return hashlib.sha256(b).hexdigest()
def read(p):return (R/p).read_bytes()
def git(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=R)
def obj(p):return json.loads(read(p))
base_manifest=json.loads(git('tools/harness/profiles.json'));live=obj('tools/harness/profiles.json');archive=json.loads((A/'manifest.json').read_bytes());ck('archive_exact_baseline',archive['source_commit']==BASE)
for row in archive['files']:
 raw=(A/row['path']).read_bytes();ck('archive_bytes/'+row['path'],len(raw)==row['bytes'] and sha(raw)==row['sha256'])
 if row['path']=='harness-region-checks.json':
  frozen=json.loads(raw);ck('frozen_full_manifest_SHA',frozen['source_sha256']==sha(git('tools/harness/profiles.json')));ck('frozen_four_real_checks',frozen['checks']=={k:base_manifest['checks'][k] for k in frozen['checks']})
 else:ck('archive_actual_Git_blob/'+row['path'],raw==git(row['source_path']))
old=json.loads((A/'style22.json').read_bytes());stylepath='docs/creative_direction/bibles/style-continuity-20261030-v23-bellstrider-rework.json';new=obj(stylepath);before=old['runtime_reference']['references'];refs=new['runtime_reference']['references'];ck('96_count83_prefix',len(before)==83 and len(refs)==96 and [(r['role'],r['path']) for r in refs[:83]]==[(r['role'],r['path']) for r in before]);changed=[]
for i,(a,b) in enumerate(zip(before,refs)):
 ck('old_role_no_metadata_change/'+str(i),{k:v for k,v in a.items() if k!='sha256'}=={k:v for k,v in b.items() if k!='sha256'});ck('old_reference_bound_real_BASE/'+str(i),a['sha256']==sha(git(a['path'])))
 if a!=b:changed.append({'role':b['role'],'path':b['path'],'old_sha256':a['sha256'],'new_sha256':b['sha256']})
for r in refs:ck('96_actual_current_bytes/'+r['role'],r['sha256']==sha(read(r['path'])))
ck('only3_declared_changed',new['revision_impact']['changed_references']==changed and {r['path'] for r in changed}=={'scripts/demo/demo_app.gd','scripts/demo/plains_region_stage.gd','scripts/combat/weapon_action_runtime.gd'})
ck('13_finite_added_refs',new['revision_impact']['added_references']==refs[83:] and len({r['path'] for r in refs[83:]})==13)
ck('style_nonbinding_contract_unchanged',{k:v for k,v in new.items() if k not in ['version','runtime_reference','supersedes','revision_impact']}=={k:v for k,v in old.items() if k not in ['version','runtime_reference','supersedes','revision_impact']})
registry=obj('docs/creative_direction/bibles/registry.json');oldreg=json.loads((A/'registry.json').read_bytes());ck('actual_selected_Bibles_unchanged',{k:v for k,v in registry.items() if k!='shared_style_authority'}=={k:v for k,v in oldreg.items() if k!='shared_style_authority'});ck('current_registry_actualstyle',registry['shared_style_authority']['path']==stylepath and registry['shared_style_authority']['sha256']==sha(read(stylepath)))
for region in ['windchime_plains','thorn_forest']:
 current=obj('docs/creative_direction/'+region+'.json');prior=json.loads((A/(region+'.json')).read_bytes());ck('direction_other_content_unchanged/'+region,{k:v for k,v in current.items() if k not in ['version','region_bible','authority_sources','revision_impact','boss']}=={k:v for k,v in prior.items() if k not in ['version','region_bible','authority_sources','revision_impact','boss']})
 if region=='thorn_forest':ck('Forest_boss_unchanged',current['boss']==prior['boss'])
 else:
  ck('Plains_old_boss_preserved',{k:v for k,v in current['boss'].items() if k!='current_overrides'}==prior['boss']);overrides=current['boss']['current_overrides'];ck('one_Bell_only_override',len(overrides)==1 and overrides[0]['boss_id']=='bellstrider' and 'unverified' in overrides[0]['acceptance']);ck('actual_user_spec_fingerprint',sha(read(overrides[0]['source']))==overrides[0]['source_sha256'])
 ck('old_authority_prefix/'+region,current['authority_sources'][:len(prior['authority_sources'])]==prior['authority_sources'])
origin=obj('docs/creative_direction/bibles/bellstrider-rework-20261030.json');ck('scope_provenance_not_fake_transcript',origin['boss_id']=='bellstrider' and origin['source']['kind']=='direct_user_specification_retained_by_root' and 'not an API export' in origin['source']['scope']);ck('spec_actualSHA',origin['source']['sha256']==sha(read(origin['source']['path'])));ck('no_acceptance_in_authorization',all(origin['g0'][k]=='unverified' for k in ['technical_status','visual_status','audio_status','device_status','user_acceptance']))
allowed={'tests/test_region_bible.py':{'test_actual_player_body_closure_is_required_and_superseded_binding_refused','test_actual_player_body_closure_is_required_and_superseded_binding_refused_audio_history','test_merged22_keeps83_roles_and_both_parent21_histories_and_rejects_stale'},'tests/test_region_creative_direction.py':{'test_selected_direction_binds_every_specialist_and_retains_stage_gates','test_merged25_preserves_both_parent24_directions_and_authority_union'}};method_counts={}
for path,changed_allowed in allowed.items():
 a,b=git(path).decode(),read(path).decode();trees=[ast.parse(a),ast.parse(b)];methods=[{n.name:n for n in ast.walk(t) if isinstance(n,ast.FunctionDef) and n.name.startswith('test_')} for t in trees];am,bm=methods;method_counts[path]={'original':len(am),'current':len(bm)};ck('all_original_methods/'+path,am.keys()<=bm.keys());actually_changed={k for k,v in am.items() if ast.get_source_segment(a,v)!=ast.get_source_segment(b,bm[k])};ck('only5_mechanical_methods/'+path,actually_changed==changed_allowed,sorted(actually_changed));ck('all_old_SHA_literals/'+path,set(re.findall(r'[a-f0-9]{64}',a))<=set(re.findall(r'[a-f0-9]{64}',b)))
 for name,node in am.items():
  neg=lambda x:collections.Counter(ast.dump(n,include_attributes=False) for n in ast.walk(x) if isinstance(n,ast.Call) and isinstance(n.func,ast.Attribute) and n.func.attr.startswith('assertRaises'))
  ck('all_old_negatives/'+path+'/'+name,not(neg(node)-neg(bm[name])))
four=json.loads((A/'harness-region-checks.json').read_bytes())['checks'];inputs={}
for name,prior in four.items():
 now=live['checks'][name];ck('four_guard_noninputs_exact/'+name,{k:v for k,v in prior.items() if k!='inputs'}=={k:v for k,v in now.items() if k!='inputs'})
 if 'inputs' in prior:
  ck('original_ordered_input_prefix/'+name,now['inputs'][:len(prior['inputs'])]==prior['inputs']);inputs[name]={'old':len(prior['inputs']),'new':len(now['inputs'])};newinputs=now['inputs'][len(prior['inputs']):];ck('newinputs_explicit_finite/'+name,len(newinputs)==len(set(newinputs)) and not set(newinputs)&set(prior['inputs']) and all('*' not in p and (R/p).is_file() for p in newinputs))
 else:ck('no_new_inputs_on_implicit_guard/'+name,'inputs' not in now)
for name,prior in base_manifest['checks'].items():
 if name not in four:ck('other_check_unchanged/'+name,live['checks'][name]==prior)
ck('all_profile_original_order_prefixes',all(live['profiles'][k][:len(v)]==v for k,v in base_manifest['profiles'].items()))
ck('only_real_Bell_check_append',set(live['checks'])==set(base_manifest['checks'])|{'bellstrider-rework-01'} and {k:live['profiles'][k][len(v):] for k,v in base_manifest['profiles'].items() if live['profiles'][k]!=v}=={'full':['bellstrider-rework-01'],'gameplay':['bellstrider-rework-01']})
helper=read('tools/run_bellstrider_rework_01_tests.py').decode();tree=ast.parse(helper);cases=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='CASES' for t in n.targets));ck('new_check_seven_actual_guarded_consumers',len(cases)==7 and len({row[1] for row in cases})==7 and all((R/row[1]).is_file() for row in cases) and 'from run_tests import run_engine' in helper and 'run_engine(["--headless", "--path", ".", "--script", script], 90)' in helper)

record=obj('docs/quality/asset_records/bellstrider-rework-01-material-audio.json');manifest=obj(record['source_path']);sources=obj('assets/audio/bellstrider_01/sources.json')['sources'];recipes=obj('assets/audio/bellstrider_01/recipes.json');audio_source=read('scripts/audio/bellstrider_audio.gd').decode();literal=re.findall(r'preload\("res://(assets/audio/bellstrider_01/[^\"]+\.wav)"\)',audio_source)
ck('record_candidate_not_acceptance',record['disposition']=='runtime_candidate' and record['audio_status']=='unverified' and record['visual_status']=='unverified' and record['user_acceptance_evidence']==[]);ck('literal17_manifest_record_recipe_closure',len(literal)==17 and len(set(literal))==17 and set(literal)==set(record['runtime_paths'])=={r['path'] for r in manifest['assets']} and set(recipes['recipes'])=={r['id'] for r in manifest['assets']});ck('record_manifest_actualbytes',record['source_sha256']==sha(read(record['source_path'])))
for row in manifest['assets']:
 raw=read(row['path']);ck('WAV_actualSHA/'+row['id'],sha(raw)==row['sha256'])
 with wave.open(str(R/row['path']),'rb') as wav:ck('WAV_real_PCM/'+row['id'],(wav.getnchannels(),wav.getsampwidth(),wav.getframerate(),wav.getnframes())==(1,2,48000,row['frames']))
 ck('WAV_recipe_declared_sources/'+row['id'],all(x['source'] in sources for x in row['layers']))
for row in record['associated_files']:ck('associated_actualSHA/'+row['path'],sha(read(row['path']))==row['sha256'])
for name,row in sources.items():
 ck('actual_existing_source/'+name,sha(read(row['path']))==row['sha256'] and read(row['path'])==git(row['path']));ck('source_CC0_scope/'+name,row['license']=='CC0-1.0' and row['commercial_use'] is True and row['attribution_required'] is False)
 for pathkey,hashkey in [('source_page_path','source_page_sha256'),('license_path','license_sha256'),('parent_recipe_path','parent_recipe_sha256'),('parent_manifest_path','parent_manifest_sha256')]:
  if pathkey in row:ck('source_custody/'+name+'/'+pathkey,sha(read(row[pathkey]))==row[hashkey] and read(row[pathkey])==git(row[pathkey]))
 if 'original_source' in row:
  original=row['original_source'];ck('bell_original_page_license',all(sha(read(original[pk]))==original[hk] for pk,hk in [('source_page_path','source_page_sha256'),('license_path','license_sha256')]));ck('bell_original_cache_honest_missing',not (R/original['path']).exists(),original['path'])
ck('no_old_audio_assets_modified',not subprocess.check_output(['git','diff','--name-only',BASE,'--','assets/audio','config/audio_director/selected'],cwd=R));ck('old_PNG_actualbytes',all(read(p)==git(p) for p in ['assets/underworld_plains/actors/bellstrider.png','assets/underworld_plains/actors/bell.png']))
logs={}
folder=R/'build/verification/harness/20261030T112317.585573Z'; report=json.loads((folder/'report.json').read_bytes()); expected=['region-bible-contract','region-bible-tests','creative-direction','creative-direction-tests']
ck('latest_report_four_exact_fresh',report['status']=='passed' and report['targeted_checks'] and report['release'] and report['jobs']==1 and [r['id'] for r in report['checks']]==expected and all(r['status']=='passed' and r['exit_code']==0 and r['reused'] is False and r['failure_reason'] is None for r in report['checks']))
ck('latest_report_manifest_exact_current',report['manifest_sha256']==sha(read('tools/harness/profiles.json')))
ck('exact_requested_style_SHA',sha(read(stylepath))=='03a9b283265d0f9ccfa406adb21856cebbab5e71f996b6c7a8834e40ed02723f')
ck('exact_requested_registry_SHA',sha(read('docs/creative_direction/bibles/registry.json'))=='2ef561598f0fba3400dba9d39c26b35e23e9de7ef857c667c38785ac613c98be')
for row in report['checks']:
 current=live['checks'][row['id']]; logpath=folder/row['log']; raw=logpath.read_bytes(); ck('fresh_report_original_contract/'+row['id'],row['argv']==current['argv'] and row['timeout_seconds']==current['timeout_seconds'] and row['duration_seconds']<row['timeout_seconds'] and len(row['check_token'])==32 and re.search(current['success_pattern'],raw.decode(),re.M) is not None)
 ck('fresh_report_raw_artifact_same/'+row['id'],raw==(Path(row['artifact_directory'])/'check.log').read_bytes())
 ck('fresh_report_raw_no_errors/'+row['id'],not re.search(r'(?m)^ERROR:|SCRIPT ERROR:|Traceback|^FAIL:|^FAILED',raw.decode()))
 if row['id'] in ['region-bible-tests','creative-direction-tests']:
  count=43 if row['id']=='region-bible-tests' else 18; ck('fresh_actual_method_counts/'+row['id'],('Ran %s tests'%count).encode() in raw and b'\nOK\n' in raw)
 logs[row['id']]={'path':str(logpath),'sha256':sha(raw),'native':False,'executed_by_reviewer':False,'argv':row['argv'],'budget':row['timeout_seconds'],'duration':row['duration_seconds'],'check_token':row['check_token'],'input_digest_reported':row['input_digest']}
mismatches={path:{'reported':digest,'current':sha(read(path))} for path,digest in report['working_files'].items() if sha(read(path))!=digest}
ck('fresh_report158_same_two_declared_changes',set(mismatches)=={'tools/run_bellstrider_rework_01_tests.py','tests/bellstrider_rework_01/effect_targets.gd'})
helper_path='tools/run_bellstrider_rework_01_tests.py'; current_helper=read(helper_path).decode(); first=current_helper.index('    # A fresh isolated'); last=current_helper.index('    rows = []',first); import_block=current_helper[first:last]; reconstructed=current_helper[:first]+current_helper[last:]
ck('old_helper_reconstructed_exact_receiptSHA',sha(reconstructed.encode())==report['working_files'][helper_path])
ck('helper_delta_only_strict_editor_import', 'run_engine(["--headless", "--path", ".", "--editor", "--import", "--quit"], 90)' in import_block and 'raise RuntimeError("Editor import emitted a native engine error")' in import_block)
for path,digest in report['working_files'].items():
 if path not in mismatches:ck('fresh_report_working_file_exact_current/'+path,sha(read(path))==digest)
for name in ['region-bible-tests','region-bible-contract']:
 for changed_path in mismatches:ck('explicit_Bible_closure_excludes_changed_leaf/'+name+'/'+changed_path,'inputs' in live['checks'][name] and not any(changed_path==prefix or changed_path.startswith(prefix.rstrip('/')+'/') for prefix in live['checks'][name]['inputs']))
for name in ['creative-direction','creative-direction-tests']:ck('implicit_creative_closure_not_current_receipt/'+name,'inputs' not in live['checks'][name])
archive94=R/'docs/creative_direction/archive/bellstrider-style23-candidate94-before-arc'; m94=json.loads((archive94/'manifest.json').read_bytes()); prior_review=json.loads(Path('/tmp/bellstrider-binding-review-01.json').read_bytes()); old94=json.loads((archive94/stylepath).read_bytes())
ck('reviewed94_archive_exact_previous_review_SHA',sha((archive94/stylepath).read_bytes())==prior_review['source_SHA'][stylepath])
ck('96_preserves94_role_path_order',[(r['role'],r['path']) for r in refs[:94]]==[(r['role'],r['path']) for r in old94['runtime_reference']['references']])
for row in m94['files']:
 raw=(archive94/row['path']).read_bytes();ck('reviewed94_archive_actualbytes/'+row['path'],len(raw)==row['bytes'] and sha(raw)==row['sha256'])
 ck('reviewed94_exact_old_review_file/'+row['path'],row['path'] not in prior_review['source_SHA'] or row['sha256']==prior_review['source_SHA'][row['path']])
ck('96_only_two_additional_real_projectile_refs',[(r['role'],r['path']) for r in refs[94:]]==[('bellstrider_local_ring_vfx','scripts/bosses/bellstrider_ring_projectile.gd'),('bellstrider_lob_bell_vfx','scripts/bosses/bellstrider_bell_projectile.gd')])
preflight=json.loads(Path('/tmp/bellstrider-production-final-preflight.json').read_bytes())
for row in preflight['reviewed_files']:ck('current_production_same_reviewed_preflight/'+row['path'],sha(read(row['path']))==row['sha256'])
result={'verdict':'ACCEPT_SCOPED_BINDING_AND_ASSET_CUSTODY_ONLY' if all(x['passed'] for x in checks) else 'REWORK','reviewer':'/root/guard_review_recovery','implementers':['/root/binding_plan','/root/bellstrider_audio','/root'],'independent':True,'baseline_commit':BASE,'source_status':'Dirty development candidate, no clean commit invented; full169 append is separate owner increment, original168 retained','engine_executed_by_reviewer':False,'own_damage_policy_test_excluded':True,'checks_passed':sum(x['passed'] for x in checks),'checks_failed':sum(not x['passed'] for x in checks),'checks':checks,'new_check_append':{'id':'bellstrider-rework-01','full_count':len(live['profiles']['full']),'gameplay_count':len(live['profiles']['gameplay']),'helper_sha256':sha(read('tools/run_bellstrider_rework_01_tests.py')),'native_executed_by_reviewer':False},'test_method_counts':method_counts,'guard_inputs':inputs,'observed_fresh_harness_runs':logs,'changed_three_references':changed,'added_thirteen_references':refs[83:],'asset_counts':{'WAVs':17,'source_rows':len(sources),'associated_files':len(record['associated_files'])},'audio_original_cache_boundary':'Original bell_ding1.wav ignored cache not materialized; verified tracked derivative, original page/license, parent manifest/recipe exact existing bytes, not a newly fetched original or fresh legal opinion.','source_SHA':{p:sha(read(p)) for p in ['tests/test_region_bible.py','tests/test_region_creative_direction.py','tools/harness/profiles.json',stylepath,'docs/creative_direction/bibles/registry.json','docs/creative_direction/windchime_plains.json','docs/creative_direction/thorn_forest.json','docs/creative_direction/bibles/bellstrider-rework-20261030.json','docs/quality/asset_records/bellstrider-rework-01-material-audio.json','assets/audio/bellstrider_01/manifest.json','assets/audio/bellstrider_01/sources.json','assets/audio/bellstrider_01/recipes.json']},'commands':['python3 /tmp/review_bellstrider_binding_02.py > /tmp/bellstrider-binding-review-02-proof.log'],'harness_report':{'path':str(folder/'report.json'),'sha256':sha((folder/'report.json').read_bytes()),'source_guard':'Original non-lane harness passed internal before/after guards, dirty development checkout.158/160 working_files independently current. Later helper editor-import and effect_targets authorized fixture migration differ. Two Bible explicit closures exclude both changed leaves; two creative implicit all-source receipts are prior-source. Owner will rerun after freeze. Classic receipt does not store toolchain, so input_digest not independently reconstructed.','postrun_working_file_changes':mismatches},'not_accepted':['Four-row Harness as whole-current-source after helper/effect_targets changes; owner rerun pending','Current full GUI/natural fight/two-shot or greed timing','Audio listening/mix/art quality/user/device/G1-G5','Headless03 gameplay numbers as source-clean formal pass','PriorPR119 merge waiver as future bypass authorization']}
Path('/tmp/bellstrider-binding-review-02.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('CHECKS',result['checks_passed'],result['checks_failed']);print('FAILURES',[x for x in checks if not x['passed']]);print('INPUTS',inputs)
