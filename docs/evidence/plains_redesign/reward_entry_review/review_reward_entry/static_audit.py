import json,gzip,tarfile,hashlib,sys,difflib
from pathlib import Path
R=Path.cwd();O=R/'build/plains_redesign/review_reward_entry';sys.path.insert(0,str(R/'tools'))
import level_formal as f
H=lambda b:hashlib.sha256(b).hexdigest()
idxpath=R/'docs/evidence/plains_redesign/reward_entry/index.json';idx=json.loads(idxpath.read_text());verified=[]
for x in idx['members']:
 p=R/x['portable'];b=p.read_bytes();assert H(b)==x['portable_sha256'];raw=gzip.decompress(b) if x['compression']=='gzip' else b;assert H(raw)==x['source_sha256'] and len(raw)==x['source_bytes'];verified.append(dict(path=x['portable'],sha256=H(b),raw_sha256=H(raw)))
s=json.loads((R/idx['source']).read_text());assert len(s['members'])==689
for name,h in s['members'].items():assert f.file_hash(R/name)==h,name
archive=R/'docs/evidence/plains_redesign/reward_entry/sources/current_source.tar.gz';assert H(archive.read_bytes())==s['archive_sha256'];count=0
with tarfile.open(archive) as a:
 for m in a.getmembers():
  if not m.isfile():continue
  assert a.extractfile(m).read()==(R/m.name).read_bytes();count+=1
assert count==689
# Independent baseline archive comparison: only generator/runtime observer changed.
base=R/'docs/evidence/plains_redesign/reward_entry/history_and_design/baseline_source.tar.gz';changed=[];diff=[]
with tarfile.open(base) as a:
 for m in a.getmembers():
  if not m.isfile() or m.name not in s['members']:continue
  b=a.extractfile(m).read();current=(R/m.name).read_bytes()
  if b!=current:changed.append(m.name)
  if m.name=='scripts/generation/plains_region_generator.gd':diff=list(difflib.unified_diff(b.decode().splitlines(),current.decode().splitlines(),fromfile='baseline generator',tofile='current generator'))
assert not set(f.core_source_paths())&set(changed)
(O/'generator.diff').write_text('\n'.join(diff)+'\n')
freshpath=R/'build/verification/plains-encounter/run_e4mp251i/receipt.json';fresh=json.loads(freshpath.read_text());assert fresh['source_before']==fresh['source_after']==f.source_files();cases=[]
for proof in fresh['reward_entry']['runs']:
 path=R/proof['output'];assert f.file_hash(path)==proof['sha256'];assert f.file_hash(R/proof['log'])==proof['log_sha256'];assert proof['source_before']==proof['source_after']==fresh['source_before'];row=json.loads(path.read_text())['cases'][0];claim=[o for o in row['policy_observations'] if o.get('kind')=='actual_cache_claim'];damage=[e for e in row['events'] if e['kind']=='damage_committed' and e.get('target')=='player'];cases.append(dict(name=proof['name'],exit_code=proof['exit_code'],negative=proof['expected_physical_failure'],frames=len(row['frames']),hp_min=min(x['health'] for x in row['frames']),claimed=row['claimed'],claim_outputs=[x['claim_output'] for x in claim],player_damage=damage,modules=[x['module_id'] for x in row['modules']],state=row['state'],guard_id=row['guard_id']))
budget=json.loads((R/'build/plains_redesign/reward_entry/budget_audit.json').read_text());assert not budget['failures'] and len(budget['cases'])==100
checks=[]
for p in (R/'build/verification/plains-redesign-reward-entry/PLAINS-REWARD-ENTRY-01/1').glob('*.log'):checks.append(dict(path=str(p.relative_to(R)),sha256=f.file_hash(p),log=p.read_text()))
(O/'fresh_checks.json').write_text(json.dumps(checks,indent=2));(O/'content_cases.json').write_text(json.dumps(cases,indent=2));(O/'portable_verification.json').write_text(json.dumps(dict(index_sha256=f.file_hash(idxpath),members=verified,archive_sha256=s['archive_sha256'],archive_members=count,baseline_delta=changed,core_unchanged=len(f.core_source_paths()),recorded_budget_cases=len(budget['cases']),recorded_moved_guards=sum(len(x['moved']) for x in budget['cases'])),indent=2));print('STATIC PASS',len(verified),count,'delta',changed,'core',len(f.core_source_paths()))
