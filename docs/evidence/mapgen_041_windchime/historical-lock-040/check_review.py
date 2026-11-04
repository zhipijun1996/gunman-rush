from pathlib import Path
import subprocess,hashlib,json,copy,sys,datetime,re
R=Path('/tmp/gunman-rush-mapgen-041');O=Path('/workspace/refactor-evidence/mapgen-041-integration/review-historical-lock-migration');D=R/'docs/evidence/mapgen_041_windchime/historical-lock-040'
sys.path.insert(0,str(R/'tools'));from quality import validate_record
checks=[]
def ck(name,v,detail=None):
 checks.append({'name':name,'passed':bool(v),'detail':detail});assert v,name
def g(*args):return subprocess.check_output(['git','--no-lazy-fetch',*args],cwd=R)
sha=lambda b:hashlib.sha256(b).hexdigest()
old=(D/'mapgen_candidate-0.4.0.json').read_bytes();expected='09c2c213e1d0311a0d8417595201c262d3ab32dca23616b779e30d2ca5dffb62';ck('old_lock_exact_sha',sha(old)==expected)
for c in ['f6b61ee7026bc4c696d15fa26b09de5ff03be903','d37b37075144c7a7550ad0fe9d3bd7118d6dae1d','9ba7d4b64b939f80168a3d7d1ef08fd32a5b6be8']:
 ck('old_lock_git_source_'+c[:8],g('show',c+':config/mapgen_candidate.json')==old)
for name in ['MAPGEN-GODOT-04','MAPGEN-HOST-04-ACCEPTANCE-01']:
 path='docs/quality/records/'+name+'.json';before=g('show','4df3c6a6e3b42cf7aec39a8783b0ca27042c0b60:'+path);arch=(D/(name+'.original.json')).read_bytes();after=(R/path).read_bytes();x=json.loads(before);y=json.loads(after)
 ck(name+'_raw_original_preserved',before==arch)
 oe=next(z for z in x['evidence'] if z['id']=='lock');ne=next(z for z in y['evidence'] if z['id']=='lock')
 ck(name+'_old_evidence_expected',oe['sha256']==expected and oe['path']=='config/mapgen_candidate.json')
 ck(name+'_new_evidence_path',ne['path']=='docs/evidence/mapgen_041_windchime/historical-lock-040/mapgen_candidate-0.4.0.json')
 z=copy.deepcopy(y);next(z for z in z['evidence'] if z['id']=='lock')['path']=oe['path'];ck(name+'_only_semantic_path_delta',z==x)
 ck(name+'_only_byte_path_delta',before.replace(b'"path": "config/mapgen_candidate.json",',b'"path": "docs/evidence/mapgen_041_windchime/historical-lock-040/mapgen_candidate-0.4.0.json",')==after)
 valid=validate_record(y,R);ck(name+'_validator_success',not valid['errors'],valid['errors'])
 neg=copy.deepcopy(y);next(z for z in neg['evidence'] if z['id']=='lock')['path']='config/mapgen_candidate.json';invalid=validate_record(neg,R);ck(name+'_current_041_lock_rejected','Evidence hash mismatch: lock' in invalid['errors'],invalid['errors'])
 neg=copy.deepcopy(y);next(z for z in neg['evidence'] if z['id']=='lock')['sha256']='0'*64;invalid=validate_record(neg,R);ck(name+'_wrong_digest_rejected','Evidence hash mismatch: lock' in invalid['errors'],invalid['errors'])
 neg=copy.deepcopy(y);next(z for z in neg['evidence'] if z['id']=='lock')['path']='docs/evidence/mapgen_041_windchime/historical-lock-040/does-not-exist.json';invalid=validate_record(neg,R);ck(name+'_missing_file_rejected',any('lock' in e for e in invalid['errors']),invalid['errors'])
current=(R/'config/mapgen_candidate.json').read_bytes();ck('current_lock_041_unchanged_since_actual_web',current==g('show','a0a90061816516bb4ac15ea56b3d644b5c8b477d:config/mapgen_candidate.json'));ck('current_lock_differs_from_historical',sha(current)!=expected)
ck('runtime_inputs_unchanged_since_actual_web',not g('diff','--name-only','a0a90061816516bb4ac15ea56b3d644b5c8b477d','--','game','addons','experiments','resources','config').strip())
presets=(R/'export_presets.cfg').read_text();ck('every_preset_excludes_docs',all('docs/*' in x.split(',') for x in re.findall(r'^exclude_filter="(.*)"$',presets,re.M)));ck('no_explicit_docs_export',all(not any(p.startswith('docs/') for p in x.split(',')) for x in re.findall(r'^include_filter="(.*)"$',presets,re.M)))
m=json.loads((D/'migration.json').read_text());ck('receipt_source_blob',m['git_blob']==g('rev-parse','9ba7d4b64b939f80168a3d7d1ef08fd32a5b6be8:config/mapgen_candidate.json').decode().strip());ck('receipt_old_hash',m['historical_lock_sha256']==expected)
for row in m['records']:
 ck('receipt_original_sha_'+Path(row['record']).stem,sha((R/row['original_path']).read_bytes())==row['original_sha256']);ck('receipt_migrated_sha_'+Path(row['record']).stem,sha((R/row['record']).read_bytes())==row['migrated_sha256'])
res=subprocess.run([sys.executable,'tools/check_quality.py'],cwd=R,text=True,capture_output=True);(O/'independent-quality.stdout.log').write_text(res.stdout);(O/'independent-quality.stderr.log').write_text(res.stderr);ck('independent_original_quality_command_pass',res.returncode==0 and 'PASS:' in res.stdout,{'returncode':res.returncode,'stdout':res.stdout,'stderr':res.stderr})
out={'status':'ACCEPT_SCOPED_MIGRATION','reviewer':'/root/review_historical_lock_migration','implementer':'/root','observed_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'candidate_parent':g('rev-parse','HEAD').decode().strip(),'checks':checks,'check_count':len(checks),'full_ci_accepted':False,'current_041_lock_sha256':sha(current),'historical_lock_sha256':sha(old),'unverified':['final exact head 179+affected','runtime or browser rerun not needed for metadata-only migration','old run remains failed; serial pending']};(O/'independent-review.json').write_text(json.dumps(out,indent=2,ensure_ascii=False)+'\n');print(len(checks),'PASS scoped; no full CI acceptance')
