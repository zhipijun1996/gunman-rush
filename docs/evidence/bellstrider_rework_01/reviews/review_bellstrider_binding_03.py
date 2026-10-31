from pathlib import Path
import ast,collections,copy,hashlib,json,re,subprocess
R=Path('/workspace/gunman-rush');B='840108da9ae91e412dc9f1d8a38ccdad0229bb11';checks=[]
def raw(p):return (R/p).read_bytes()
def obj(p):return json.loads(raw(p))
def sha(x):return hashlib.sha256(x).hexdigest()
def ck(n,v):checks.append({'check':n,'passed':bool(v)})
def git(p):return subprocess.check_output(['git','show',B+':'+p],cwd=R)
prior=json.loads(Path('/tmp/bellstrider-binding-review-02.json').read_bytes()); ck('prior_independent_review_accepted',prior['checks_failed']==0 and prior['checks_passed']==946)
stylep='docs/creative_direction/bibles/style-continuity-20261030-v23-bellstrider-rework.json';regp='docs/creative_direction/bibles/registry.json';prof='tools/harness/profiles.json';new=obj(stylep);live=obj(prof)
for p,h in [(stylep,'2281fc29e0a7ede8928af968d14763f2fc683c39c95fc95a4f83a67667ca94ba'),(regp,'af520a84ca27522c5e0536513afb510f7c58094abfc694805a14f62bd96ff054'),(prof,'4c4d226372e1b98c2eb848922b2563c3fa475d08a21f787fd45b6c9e4b4d4f7e')]:ck('exact_requested_SHA/'+p,sha(raw(p))==h)
A='docs/creative_direction/archive/bellstrider-style23-candidate94-before-arc/';manifest=obj(A+'manifest.json');oldraw=raw(A+'manifest-before-md-relocation.json.txt');oldm=json.loads(oldraw);ck('old94_manifest_exact_reviewed_SHA',sha(oldraw)=='f1a8e433ad8c4656c17ba47534ae7ea71388b6e7d7d24466dca59d8bc96880e1')
oldrows=oldm['files'];rows=manifest['files'];ck('archive_original15_plus_backup',len(oldrows)==15 and len(rows)==16)
for before,after in zip(oldrows,rows):
 expected=copy.deepcopy(before)
 if before['path']=='docs/creative_direction/revision_creative_v26.md':expected.update(path=before['path']+'.txt',source_path=before['path'])
 ck('archive_only_one_path_mapping/'+before['path'],after==expected)
 data=raw(A+after['path']);ck('archive_payload_exact_old_bytes/'+after['path'],len(data)==before['bytes'] and sha(data)==before['sha256'])
ck('archive_original_md_removed',not(R/A/'docs/creative_direction/revision_creative_v26.md').exists())
ck('backup_manifest_row_exact',rows[-1]['sha256']==sha(oldraw) and rows[-1]['bytes']==len(oldraw))
oldstyle=copy.deepcopy(new);oldstyle['revision_impact']['previous_candidate_manifest']['sha256']=sha(oldraw);oldstylebytes=(json.dumps(oldstyle,ensure_ascii=False,indent=2)+'\n').encode();ck('style_only_archive_manifest_SHA_delta',sha(oldstylebytes)==prior['source_SHA'][stylep])
refs=new['runtime_reference']['references'];before=obj('docs/creative_direction/archive/creative-v25-before-bellstrider-rework/style22.json')['runtime_reference']['references'];ck('original83_order_current96',len(refs)==96 and [(x['role'],x['path']) for x in refs[:83]]==[(x['role'],x['path']) for x in before]);changed=[]
for old,current in zip(before,refs):
 ck('old83_metadata/'+old['role'],{k:v for k,v in old.items() if k!='sha256'}=={k:v for k,v in current.items() if k!='sha256'})
 if old!=current:changed.append(current['path'])
ck('only3_original_rebinds',set(changed)=={'scripts/demo/demo_app.gd','scripts/demo/plains_region_stage.gd','scripts/combat/weapon_action_runtime.gd'})
for row in refs:ck('all96_actual_runtime_SHA/'+row['role'],row['sha256']==sha(raw(row['path'])))
recordp='docs/quality/asset_records/bellstrider-rework-01-material-audio.json';record=obj(recordp);doc=[r for r in record['associated_files'] if r.get('role')=='documentation'];oldrecord=copy.deepcopy(record);oldrecord['associated_files']=[r for r in record['associated_files'] if r not in doc];ck('only_existing_README_doc_append',len(doc)==1 and doc[0]['path']=='assets/audio/bellstrider_01/README.md' and doc[0]['sha256']==sha(raw(doc[0]['path'])) and sha((json.dumps(oldrecord,ensure_ascii=False,indent=2)+'\n').encode())==prior['source_SHA'][recordp])
for row in record['associated_files']:ck('asset_current_custody/'+row['path'],row['sha256']==sha(raw(row['path'])))
# Reconstruct the exact previously executed tracked profile from its actual Git diff.
report02=obj('build/verification/harness/20261030T112317.585573Z/report.json'); diff=report02['diff']; section=diff.split('diff --git a/'+prof+' b/'+prof+'\n',1)[1].split('\ndiff --git ',1)[0]; base=git(prof).decode().splitlines(keepends=True);out=[];cursor=0
for hunk in re.split(r'(?m)^@@ ',section)[1:]:
 header,*lines=hunk.splitlines(keepends=True); m=re.match(r'-(\d+)(?:,\d+)? \+\d+(?:,\d+)? @@',header);start=int(m.group(1))-1;out+=base[cursor:start];cursor=start
 for line in lines:
  if line.startswith(' '):assert base[cursor].rstrip('\n')==line[1:].rstrip('\n');out.append(base[cursor]);cursor+=1
  elif line.startswith('-'):assert base[cursor].rstrip('\n')==line[1:].rstrip('\n');cursor+=1
  elif line.startswith('+'):out.append(line[1:])
out+=base[cursor:];oldprofilebytes=''.join(out).encode();ck('exact_prior_profiles_reconstructed_from_raw_receipt',sha(oldprofilebytes)==report02['manifest_sha256']==prior['source_SHA'][prof]);oldprofiles=json.loads(oldprofilebytes)
ck('all_profiles_order_unchanged_since96_review',live['profiles']==oldprofiles['profiles'])
for name,priorcheck in oldprofiles['checks'].items():
 current=live['checks'][name];ck('all_check_contracts_unchanged/'+name,{k:v for k,v in current.items() if k!='inputs'}=={k:v for k,v in priorcheck.items() if k!='inputs'})
 if name in ['region-bible-contract','region-bible-tests']:
  prefix=24 if name=='region-bible-contract' else 422
  ck('immutable_original_input_prefix/'+name,current['inputs'][:prefix]==priorcheck['inputs'][:prefix]);expected=[p+'.txt' if p==A+'docs/creative_direction/revision_creative_v26.md' else p for p in priorcheck['inputs']]
  additions=[p for p in current['inputs'] if p not in expected];ck('input_only_path_migration_and2_finite_additions/'+name,current['inputs'][:len(expected)]==expected and set(additions)=={A+'manifest-before-md-relocation.json.txt','assets/audio/bellstrider_01/README.md'} and len(current['inputs'])==len(priorcheck['inputs'])+2)
 else:ck('all_other_inputs_exact/'+name,current.get('inputs')==priorcheck.get('inputs'))
for file,oldcount in [('tests/test_region_bible.py',40),('tests/test_region_creative_direction.py',17)]:
 old=ast.parse(git(file).decode());current=ast.parse(raw(file).decode());methods=lambda t:{x.name:x for x in ast.walk(t) if isinstance(x,ast.FunctionDef) and x.name.startswith('test_')};a,b=methods(old),methods(current);ck('57_original_methods/'+file,len(a)==oldcount and a.keys()<=b.keys());ck('old_historical_SHA_literals/'+file,set(re.findall(r'[a-f0-9]{64}',git(file).decode()))<=set(re.findall(r'[a-f0-9]{64}',raw(file).decode())))
 for name,node in a.items():
  neg=lambda x:collections.Counter(ast.dump(n,include_attributes=False) for n in ast.walk(x) if isinstance(n,ast.Call) and isinstance(n.func,ast.Attribute) and n.func.attr.startswith('assertRaises'))
  ck('all_original_negatives/'+file+'/'+name,not(neg(node)-neg(b[name])))
folder=R/'build/verification/harness/20261030T114011.163401Z';receipt=json.loads((folder/'report.json').read_bytes());ck('fresh4_pass_no_reuse',receipt['status']=='passed' and len(receipt['checks'])==4 and all(x['status']=='passed' and x['exit_code']==0 and x['reused'] is False for x in receipt['checks']));ck('fresh_manifest_exact_current',receipt['manifest_sha256']==sha(raw(prof)));logs=[]
for row in receipt['checks']:
 c=live['checks'][row['id']];data=(folder/row['log']).read_bytes();ck('fresh_exact_original_contract/'+row['id'],row['argv']==c['argv'] and row['timeout_seconds']==c['timeout_seconds'] and row['duration_seconds']<row['timeout_seconds'] and re.search(c['success_pattern'],data.decode(),re.M)!=None);ck('fresh_raw_artifact_copy/'+row['id'],data==(Path(row['artifact_directory'])/'check.log').read_bytes());ck('fresh_log_no_errors/'+row['id'],not re.search(r'(?m)^ERROR:|SCRIPT ERROR:|Traceback|^FAIL:|^FAILED',data.decode()))
 if row['id'].endswith('-tests'):ck('fresh43_or18_methods/'+row['id'],('Ran %s tests'%(43 if row['id']=='region-bible-tests' else 18)).encode() in data)
 logs.append({'path':str(folder/row['log']),'sha256':sha(data),'executed_by_reviewer':False,'check_token':row['check_token'],'input_digest_reported':row['input_digest']})
for p,h in receipt['working_files'].items():ck('fresh219_working_file_current/'+p,sha(raw(p))==h)
preflight=json.loads(Path('/tmp/bellstrider-production-final-preflight.json').read_bytes())
for row in preflight['reviewed_files']:ck('production_preflight_unchanged/'+row['path'],sha(raw(row['path']))==row['sha256'])
result={'reviewer':'/root/guard_review_recovery','independence':'No production/binding migration authored by reviewer. Own damage_policy86 excluded.','baseline_commit':B,'source_state':'Dirty development checkout; exact recorded leaves, no invented clean commit.','verdict':'ACCEPT_METADATA_INCREMENT_AND_FRESH4_RECEIPT_ONLY' if all(x['passed'] for x in checks) else'REWORK','passed':sum(x['passed'] for x in checks),'failed':sum(not x['passed'] for x in checks),'checks':checks,'source_SHA':{p:sha(raw(p)) for p in [stylep,regp,prof,recordp,A+'manifest.json','tests/test_region_bible.py','tests/test_region_creative_direction.py']},'fresh_report':{'path':str(folder/'report.json'),'sha256':sha((folder/'report.json').read_bytes()),'working_files_count':len(receipt['working_files']),'logs':logs,'limits':'Read existing root-executed classic Harness receipt. Internal source guard passed; all219 reported working file SHA independently current. Classic report lacks full inventory/toolchain, so do not independently reconstruct unstored full input digest.'},'actual_command':'python3 /tmp/review_bellstrider_binding_03.py > /tmp/bellstrider-binding-review-03-proof.log','script_sha256':sha(Path(__file__).read_bytes()),'engine_executed_by_reviewer':False,'not_accepted':['Final GUI/original audio film','Own damage_policy86','Native689 aggregate as wholly independent author review','Subjective art/listening/user/device and G1-G5']}
Path('/tmp/bellstrider-binding-review-03.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('CHECKS',result['passed'],result['failed']);print('FAILURES',[x for x in checks if not x['passed']])
