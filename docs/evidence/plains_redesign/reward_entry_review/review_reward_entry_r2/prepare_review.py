"""Read-only review preparation. No lease response or admission verdict."""
import sys,json,copy,hashlib,tarfile,importlib.util,gzip,time
from pathlib import Path
R=Path.cwd();O=R/'build/plains_redesign/review_reward_entry_r2';sys.path.insert(0,str(R/'tools'))
import level_formal as f,run_plains_encounter_policy_tests as current
H=lambda b:hashlib.sha256(b).hexdigest()
assert f.file_hash(R/'tools/run_plains_encounter_policy_tests.py')=='fbd4b0cd3911b9124d492bbe75a6fd274ac0d11557bf02b92cdf257777ee854f'
# Extract only rejected validator, do not overlay any runtime or test source.
with tarfile.open(R/'build/plains_redesign/review_reward_entry/reviewed_current_source.tar.gz') as a:b=a.extractfile('tools/run_plains_encounter_policy_tests.py').read()
oldpath=O/'reviewed_r1_validator.py';oldpath.write_bytes(b);spec=importlib.util.spec_from_file_location('reviewed_r1_validator',oldpath);old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
rpath=R/'build/verification/plains-encounter/run_f5p7af_k/receipt.json';receipt=json.loads(rpath.read_text());assert receipt['source_before']==receipt['source_after']==f.source_files()
for name,h in receipt['verifier_sources'].items():assert f.file_hash(R/name)==h
proof=next(x for x in receipt['reward_entry']['runs'] if x['name']=='reward_kill0');actual=json.loads((R/proof['output']).read_text());sources=proof['source_before'];results=[]
def check(name,mutate,expected=True):
 bad=copy.deepcopy(actual);mutate(bad['cases'][0])
 try:current.validate_reward_entry(bad,sources);rejected=False;reason='accepted'
 except (ValueError,KeyError,TypeError) as error:rejected=True;reason=str(error)
 results.append(dict(case=name,rejected=rejected,expected_rejected=expected,reason=reason));assert rejected==expected,name
 return bad
old_guard=actual['cases'][0]['guard_id']
def erase(row,newid=None):
 row['state']['entry_guard']=[]
 for frame in row['frames']:frame['reward_guard']=[]
 row['policy_observations']=[o for o in row['policy_observations'] if not(o.get('kind')=='actual_enemy_transition' and o.get('enemy')==old_guard)]
 if newid is not None:row['guard_id']=newid
check('untouched_declared_guard',lambda r:None,False)
bad=check('original_R1_unknown_identity_and_erasure',lambda r:erase(r,'plains/enemy/not_the_declared_high_entrance'))
old.validate_reward_entry(bad,sources);results.append(dict(case='original_R1_on_preserved_old_validator',accepted=True,expected_accepted=True))
check('coherent_erasure_true_id',lambda r:erase(r))
check('unknown_id_without_erasure',lambda r:r.update(guard_id='plains/enemy/nonexistent'))
check('empty_id_without_erasure',lambda r:r.update(guard_id=''))
check('other_tier_identity_without_erasure',lambda r:r.update(tier='region_top'))
check('duplicate_real_entry_area',lambda r:r['manifest']['areas'].append(copy.deepcopy(next(a for a in r['manifest']['areas'] if 'plains/enemy/'+a['id']==r['guard_id']))))
check('guard_area_omitted',lambda r:next(x for x in r['manifest']['enemies'] if x['id']==r['guard_id']).pop('area'))
check('guard_area_wrong',lambda r:next(x for x in r['manifest']['enemies'] if x['id']==r['guard_id']).update(area='area_does_not_match'))
check('entry_bank_moves_2d_state_only',lambda r:r['state'].update(entry_position=[r['state']['entry_position'][0]+10,r['state']['entry_position'][1]]))
# Reuse author's ten adjacent identity regressions, explicitly separate from own probes.
author_adjacent=current.reward_entry_identity_checks(actual,sources);assert len(author_adjacent)==10
positives=[]
for name in ['reward_top1','reward_high2']:
 p=next(x for x in receipt['reward_entry']['runs'] if x['name']==name);d=json.loads((R/p['output']).read_text());current.validate_reward_entry(d,p['source_before']);row=d['cases'][0];assert not any(x['id']==row['guard_id'] for x in row['manifest']['enemies']);positives.append(dict(name=name,accepted=True,declared_guard=False,output=p['output'],sha256=p['sha256']))
# Portable bytes and exact reviewed old-member preservation, including documented relocation.
idxpath=R/'docs/evidence/plains_redesign/reward_entry/index.json';idx=json.loads(idxpath.read_text());members=[]
for x in idx['members']:
 b=(R/x['portable']).read_bytes();assert H(b)==x['portable_sha256'];raw=gzip.decompress(b) if x['compression']=='gzip' else b;assert H(raw)==x['source_sha256'] and len(raw)==x['source_bytes'];members.append(dict(source=x['source'],portable=x['portable'],sha256=x['source_sha256']))
oldidx=json.loads((R/'build/plains_redesign/review_reward_entry/reviewed_index.json').read_text());available={(x['source'],x['source_sha256']) for x in idx['members']};relocated=[]
for x in oldidx['members']:
 if (x['source'],x['source_sha256']) not in available:
  candidates=[y for y in idx['members'] if y['source_sha256']==x['source_sha256']];assert candidates,(x['source'],x['portable']);relocated.append(dict(old=x['portable'],new=[y['portable'] for y in candidates]))
snapshot=json.loads((R/idx['source']).read_text());archivepath=R/idx['source_archive'];assert H(archivepath.read_bytes())==snapshot['archive_sha256'];count=0
with tarfile.open(archivepath) as a:
 for m in a.getmembers():
  if not m.isfile():continue
  assert a.extractfile(m).read()==(R/m.name).read_bytes();count+=1
assert count==689
native=[]
for p in receipt['reward_entry']['runs']:
 assert f.file_hash(R/p['output'])==p['sha256'] and f.file_hash(R/p['log'])==p['log_sha256'];assert p['source_before']==p['source_after']==receipt['source_before'];native.append(dict(name=p['name'],output=p['output'],exit=p['exit_code'],expected_negative=p['expected_physical_failure']))
(O/'identity_neighbors.json').write_text(json.dumps(dict(results=results,author_ten=author_adjacent,legitimate_absence=positives),indent=2));(O/'preparation_provenance.json').write_text(json.dumps(dict(scope='preparation only; not admission; no actual new lease yet',time=time.time(),verifier_sha256=f.file_hash(R/'tools/run_plains_encounter_policy_tests.py'),preserved_old_verifier_sha256=H(b) if False else f.file_hash(oldpath),receipt=str(rpath.relative_to(R)),receipt_sha256=f.file_hash(rpath),formal_source_count=len(receipt['source_before']),portable_index_sha256=f.file_hash(idxpath),portable_members=len(members),preserved_old_member_count=len(oldidx['members']),relocated_old_members=relocated,archive_members=count,archive_sha256=H(archivepath.read_bytes()),native=native,original_refusals=len(receipt['reward_entry']['validator_refusals']),independent_godot_runs=0),indent=2));print('PREPARATION CHECKED',len(results),'own outcomes;10 author identity cases;2 actual legitimate absent positives;',len(members),'portable',count,'archive; no admission/response')
