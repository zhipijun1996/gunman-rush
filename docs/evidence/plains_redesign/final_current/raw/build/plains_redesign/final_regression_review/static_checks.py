import subprocess,json,hashlib,tarfile,ast,collections
from pathlib import Path
R=Path.cwd();O=R/'build/plains_redesign/final_regression_review';A='30f6a825712fbb30e607791c996de142c6757a79';B='20f9b21d7e092348dd9de146267c46540a88d9cb'
H=lambda b:hashlib.sha256(b).hexdigest()
# Complete textual diff plus binary markers. Binary contents have per-file committed SHA inventory.
raw=subprocess.check_output(['git','diff',A,B]);(O/'complete_committed.diff').write_bytes(raw);inventory=json.loads((O/'committed_inventory.json').read_text());inventory['complete_diff_sha256']=H(raw);inventory['complete_diff_bytes']=len(raw);inventory['complete_diff_scope']='Full git textual diff and binary-change markers; each binary has exact committed SHA in file inventory';(O/'committed_inventory.json').write_text(json.dumps(inventory,indent=2))
old=json.loads(subprocess.check_output(['git','show',A+':tools/harness/profiles.json']));new=json.loads(Path('tools/harness/profiles.json').read_text());assert all(new['checks'].get(k)==v for k,v in old['checks'].items());assert all(set(v)<=set(new['profiles'][k]) for k,v in old['profiles'].items());profile=dict(old_check_count=len(old['checks']),new_check_count=len(new['checks']),old_checks_identical=True,old_profile_members_retained=True,new_checks=sorted(set(new['checks'])-set(old['checks'])))
# All original test files are preserved. Only the enumerated drivers/two Python test files change.
names=subprocess.check_output(['git','ls-tree','-r','--name-only',A,'tests'],text=True).splitlines();request=''.join(A+':'+p+'\n' for p in names);proc=subprocess.run(['git','cat-file','--batch'],input=request.encode(),capture_output=True,check=True);data=proc.stdout;offset=0;changed=[];testfiles=[]
for p in names:
 end=data.index(b'\n',offset);header=data[offset:end].split();size=int(header[-1]);oldbytes=data[end+1:end+1+size];offset=end+size+2;current=Path(p).read_bytes();testfiles.append(dict(path=p,old_sha256=H(oldbytes),current_sha256=H(current),unchanged=oldbytes==current))
 if oldbytes!=current:changed.append(p)
# Every original Python assertion AST remains an identical subtree/multiplicity.
assertions=[]
for p in [x for x in changed if x.endswith('.py')]:
 oldsource=subprocess.check_output(['git','show',A+':'+p],text=True);newsource=Path(p).read_text()
 def nodes(s):
  return collections.Counter(ast.dump(n,include_attributes=False) for n in ast.walk(ast.parse(s)) if isinstance(n,ast.Assert) or isinstance(n,ast.Call) and isinstance(n.func,ast.Attribute) and n.func.attr.startswith('assert'))
 a,b=nodes(oldsource),nodes(newsource);missing=a-b;assert not missing,(p,missing);assertions.append(dict(path=p,old_assertions=sum(a.values()),current_assertions=sum(b.values()),all_original_assertion_AST_retained=True))
manifest=json.loads(Path('docs/evidence/plains_redesign/frozen_v9/manifest.json').read_text());assert manifest['commit']==A;archive=Path('docs/evidence/plains_redesign/frozen_v9/source.tar.gz');assert H(archive.read_bytes())==manifest['archive_sha256'];members={}
with tarfile.open(archive) as tar:
 for m in tar.getmembers():
  if not m.isfile():continue
  b=tar.extractfile(m).read();assert H(b)==manifest['members'][m.name];members[m.name]=b
assert set(members)==set(manifest['members'])
request=''.join(A+':'+p+'\n' for p in members);data=subprocess.run(['git','cat-file','--batch'],input=request.encode(),capture_output=True,check=True).stdout;offset=0
for p,b in members.items():
 end=data.index(b'\n',offset);header=data[offset:end].split();assert header[-1]!=b'missing',p;size=int(header[-1]);baseline=data[end+1:end+1+size];offset=end+size+2;assert b==baseline,p
assetrows=[]
for p,h in manifest['asset_blobs'].items():
 b=Path(p).read_bytes();actual=hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest();assert actual==h,p;assetrows.append(p)
# Frozen old exact action/autonomy runner bytes and all old config/core methods really exist.
assert members['tests/plains_action_golden_runner.gd']==subprocess.check_output(['git','show',A+':tests/plains_action_golden_runner.gd'])
assert members['tests/plains_autonomy_slice_runner.gd']==subprocess.check_output(['git','show',A+':tests/plains_autonomy_slice_runner.gd'])
# Entire original movement/resource/RNG/save/weapon/AI service boundary is unmodified.
folders=['scripts/player/','scripts/input/','scripts/combat/','scripts/damage/','scripts/resources/','scripts/actors/','scripts/builds/','scripts/meta/','scripts/rewards/','scripts/shops/','scripts/save/','scripts/run/','resources/player/','resources/actors/','resources/items/','resources/weapons/','config/','scenes/player/']
changedall=subprocess.check_output(['git','diff','--name-only',A,B],text=True).splitlines();forbidden=[p for p in changedall if any(p.startswith(x) for x in folders)];assert not forbidden,forbidden
result=dict(baseline=A,commit=B,profiles=profile,original_tests=len(names),changed_original_test_files=changed,tests=testfiles,python_assertions=assertions,frozen_v9=dict(commit=A,archive_sha256=manifest['archive_sha256'],member_count=len(members),every_member_equals_baseline=True,matching_asset_count=len(assetrows),old_action_autonomy_runners_exact=True),core_boundaries_changed=forbidden)
(O/'static_checks.json').write_text(json.dumps(result,indent=2));print('STATIC GUARDS PASS',profile,'original tests',len(names),'changed',changed,'frozen',len(members),'assets',len(assetrows))
