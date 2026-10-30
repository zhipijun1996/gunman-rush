import ast,hashlib,importlib.util,json,pathlib,re,subprocess,sys
ROOT=pathlib.Path('/workspace/gunman-rush'); COMMIT='2c32948271b2f002f76aea846a83aa1cba4f0a13'; BASE='a5ff2ccb9bd59efc79eb5fb1bc2b6e59de0f4249'
sys.path.insert(0,str(ROOT/'tools'))
import run_root_bell_spaces as spaces
import run_root_bell_ecology as ecology
checks=[]
def check(name,ok,detail=None):
 checks.append({'id':name,'passed':bool(ok),'detail':detail})
def sha(b):return hashlib.sha256(b).hexdigest()
def gitshow(commit,path):return subprocess.check_output(['git','show',f'{commit}:{path}'],cwd=ROOT)
p=ROOT/'build/production_repair/ecology/plains_loot_02_spaces_03'; arc=ROOT/'docs/evidence/plains_motion_loot_02/development/root-bell-coin-guard-03'
r=json.loads((p/'report.json').read_text());a=json.loads((p/'audit.json').read_text());log=(p/'runtime.log').read_text()
check('execution_status',r['status']=='passed' and r['exit_code']==0)
check('native_clean_runtime',not ecology.native_runtime_failed(r['exit_code'],log))
check('native_marker','ROOT BELL SPACES: maps=40 negatives=10 failures=0' in log)
check('source_before_after_identical',r['source_before']==r['source_after'])
check('current_inventory_same_keys',set(ecology.source_files())==set(r['source_before']))
tree={}
for row in subprocess.check_output(['git','ls-tree','-rz',COMMIT],cwd=ROOT).split(b'\0'):
 if not row:continue
 meta,name=row.split(b'\t',1);mode,kind,oid=meta.split();tree[name.decode()]=(kind.decode(),oid.decode())
items=[]
for name,wanted in sorted(r['source_before'].items()):
 file=ROOT/name
 data=file.read_bytes() if file.is_file() else b''
 actual=sha(data);blob=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
 good=file.is_file() and actual==wanted and tree.get(name)==('blob',blob)
 items.append({'path':name,'sha256':wanted,'frozen_git_blob':tree.get(name,[None,None])[1],'matched':good})
 check('inventory/'+name,good)
actual_observed=spaces.validate(a);mutations=spaces.mutations(a)
check('independent_pure_receipt_validate',actual_observed==r['observed'],actual_observed)
check('independent_eight_mutations',mutations==r['mutation_refusals'] and len(mutations)==8,mutations)
old_six=['drop/physical_negatives','drop/saved_map_compatibility','drop/run_manifest_replay','boolean_replacement','lost_old_hash','version_false_accept']
check('original_six_python_mutations_preserved',all(x in mutations for x in old_six))
check('all12_native_drop_refusals',len(a['drop_contract_negatives'])==12 and all(x['refused'] is True for x in a['drop_contract_negatives']),a['drop_contract_negatives'])
check('source_fixed_60hz',r['command'][r['command'].index('--fixed-fps')+1]=='60')
check('execution_under_original240',0<r['native_verification_seconds']<240,r['native_verification_seconds'])
changed=subprocess.check_output(['git','diff','--name-only',BASE,COMMIT],cwd=ROOT,text=True).splitlines()
check('only_two_nondocumentation_changes',[x for x in changed if not x.startswith('docs/')]==['tests/root_bell_spaces_runner.gd','tools/run_root_bell_spaces.py'],[x for x in changed if not x.startswith('docs/')])
guard_paths=['tests/root_bell_spaces_runner.gd','tools/run_root_bell_spaces.py'];guard_hashes={}
for name in guard_paths:
 new=gitshow(COMMIT,name);old=gitshow(BASE,name);guard_hashes[name]=sha(new)
 check('current_guard_matches_frozen/'+name,new==(ROOT/name).read_bytes())
 check('original_source_archive/'+name,old==(ROOT/'docs/evidence/plains_motion_loot_02/integration/ci-40993924803/before-a5ff'/name).read_bytes())
for name in ['report.json','audit.json','runtime.log']:
 check('archive_exact/'+name,(p/name).read_bytes()==(arc/name).read_bytes())
check('archive_wrapper_marker','ROOT BELL SPACES VERIFIED:' in (arc/'wrapper.log').read_text())
old=gitshow(BASE,guard_paths[0]).decode();new=gitshow(COMMIT,guard_paths[0]).decode()
def funcs(s):
 starts=list(re.finditer(r'^func (\w+)\(',s,re.M));return {m[1]:s[m.start():starts[i+1].start() if i+1<len(starts) else len(s)] for i,m in enumerate(starts)}
o,n=funcs(old),funcs(new)
for fn in o:
 if fn=='run':continue
 # New helpers precede original finish; only the trailing descriptive comment joins run.
 check('original_native_function_exact/'+fn,o[fn]==n[fn])
old_assert='previous.manifest.enemy_drops==actual.manifest.enemy_drops'
check('original_run_exact_except_narrow_additions',all(s in new for s in ['previous.manifest.nodes==actual.manifest.nodes','previous.manifest.connections==actual.manifest.connections','previous.manifest.rewards==actual.manifest.rewards','"non_ecology_content_drift/"+seed_value','previous.manifest.enemies.size()==actual.manifest.enemies.size()']))
helper=n['drops_follow_selected_species']
check('species_branch_before_equality',helper.index('if old_species==new_species:')<helper.index('if before!=after: return false'))
check('exact_species_scope','old_species!="charger" or new_species!="root_bell"' in helper)
check('exact_admitted_identity','id!=admission.get("id","")' in helper and 'changed>1' in helper and 'admission.get("replaced",0)!=1' in helper)
check('clone_full_dictionary_equality','before.duplicate(true)' in helper and 'expected!=after' in helper)
check('both_integer_budgets','typeof(actual.budget.enemy_drop_coin_total)!=TYPE_INT or typeof(previous.budget.enemy_drop_coin_total)!=TYPE_INT' in helper)
check('extra_refusals_for_review_findings',set(['rolled_back_species_payout','fractional_budget','fractional_before_budget']) <= {x['mutation'] for x in a['drop_contract_negatives']})
oldpy=gitshow(BASE,guard_paths[1]).decode();newpy=gitshow(COMMIT,guard_paths[1]).decode()
def pyfunc(s,fn):
 node=next(n for n in ast.parse(s).body if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef)) and n.name==fn)
 return ast.dump(node,include_attributes=False)
check('original_wrapper_main_identical',pyfunc(oldpy,'main')==pyfunc(newpy,'main'))
profiles=gitshow(COMMIT,'tools/harness/profiles.json')
check('harness_profile_bytes_unchanged',profiles==gitshow(BASE,'tools/harness/profiles.json'))
profile_data=json.loads(profiles)
def findid(x):
 if isinstance(x,dict):
  if x.get('id')=='root-bell-spaces':return x
  for v in x.values():
   r=findid(v)
   if r:return r
 elif isinstance(x,list):
  for v in x:
   r=findid(v)
   if r:return r
 return None
profile=profile_data['checks']['root-bell-spaces'];check('harness_timeout360',profile.get('timeout_seconds')==360,profile)
# Process card is intentionally pending, not a counterfeit accepted gate.
card=json.loads((ROOT/'docs/quality/records/PLAINS-ROOT-BELL-COIN-GUARD-02.json').read_text())
check('process_card_unverified_before_review',card['gates']['G4']['status']=='unverified' and card['dimensions']['technical']['status']=='unverified' and card['dimensions']['independent_review']['status']=='unverified')
# Retain the rejected first candidate and immutable failure evidence.
first=ROOT/'docs/evidence/plains_motion_loot_02/development/root-bell-coin-guard-02'
first_report=json.loads((first/'report.json').read_text())
for name in guard_paths:
 check('first_candidate_exact_reconstruction/'+name,sha((first/'before-independent-correction'/name).read_bytes())==first_report['source_before'][name])
ci=ROOT/'docs/evidence/plains_motion_loot_02/integration/ci-40993924803'
receipt=json.loads((ci/'receipt.json').read_text());api={x['id']:x for x in json.loads((ci/'github-api-artifacts.json').read_text())['artifacts']}
check('original_failed_ci_stays_failed',receipt['status']=='failed' and receipt['parallel']=={'passed':48,'failed':1,'not_executed':43,'failure':'root-bell-spaces/non_ecology_content_drift/plains-redesign-8/plains/map_2'})
for row in receipt['artifacts']:
 f=ROOT/row['path']; metadata=api[row['id']]
 check('failed_artifact_exact/'+str(row['id']),len(f.read_bytes())==row['bytes']==metadata['size_in_bytes'] and sha(f.read_bytes())==row['sha256'] and metadata.get('digest')=='sha256:'+row['sha256'])
# Every captured input other than the two guards is also byte-identical to a5ff.
base_tree={}
for row in subprocess.check_output(['git','ls-tree','-rz',BASE],cwd=ROOT).split(b'\0'):
 if row:
  meta,name=row.split(b'\t',1);base_tree[name.decode()]=meta.split()[2].decode()
different=[x['path'] for x in items if base_tree.get(x['path'])!=x['frozen_git_blob']]
check('exactly_two_development_input_changes',different==sorted(guard_paths),different)
proof={'source_commit':COMMIT,'implementers':['/root'],'reviewed_commit':COMMIT,'base_commit':BASE,'reviewer':'/root/guard_review_recovery','author':'/root','independent':True,'execution_origin':'Root development execution before commit, a5ff + two dirty guard files; not a Git-clean execution and not independently rerun by reviewer','inventory_count':len(items),'guard_sha256':guard_hashes,'original_execution_report_sha256':sha((p/'report.json').read_bytes()),'original_audit_sha256':sha((p/'audit.json').read_bytes()),'checks':checks,'inventory':items,'pure_commands':['python3 /tmp/review_root_bell_coin_final.py (imports frozen adapter validation/mutations only; no engine)'],'passed':sum(c['passed'] for c in checks),'failed':sum(not c['passed'] for c in checks),'current_git_status':subprocess.check_output(['git','status','--short'],cwd=ROOT,text=True)}
pathlib.Path('/tmp/plains_root_bell_coin_guard_final_proof.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in proof.items() if k not in ['inventory','checks']},indent=2));print('FAILED_CHECKS',json.dumps([x for x in checks if not x['passed']],ensure_ascii=False))
