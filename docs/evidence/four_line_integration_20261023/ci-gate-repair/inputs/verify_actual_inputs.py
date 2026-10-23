import hashlib,json,sys,subprocess,tempfile,shutil
from pathlib import Path
base=Path('/workspace/scratch/encounter-input-closure');root=Path('/workspace/integration-four');overlay=Path('/workspace/scratch/encounter-boundary-scope/overlay');sys.path.insert(0,str(overlay/'tools'));import cloud_inputs as inputs
endpoint='docs/evidence/plains_redesign/encounter/frozen_50fb10c/';names=[endpoint+'manifest.json',endpoint+'delta.tar.gz'];excluded='docs/evidence/unrelated/other-history.bin'
def git(repo,*args):return subprocess.check_output(['git','-C',str(repo),*args],stderr=subprocess.PIPE).decode().strip()
with tempfile.TemporaryDirectory(prefix='actual-endpoint-',dir=base) as tmp:
 source=Path(tmp)/'source';target=Path(tmp)/'target';source.mkdir();git(source,'init','-q');git(source,'config','user.name','Input Audit');git(source,'config','user.email','input-audit@example.invalid')
 for name in names:
  p=source/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((root/name).read_bytes())
 p=source/excluded;p.parent.mkdir(parents=True);p.write_bytes(b'not a selected dependency')
 runner='tools/run_plains_encounter_policy_tests.py';p=source/runner;p.parent.mkdir();p.write_text('print("fixture only: no native executed")\n')
 checks={name:{'argv':['python3',runner,*flags],'timeout_seconds':600,'success_pattern':'^fixture only: no native executed$'} for name,flags in [('plains-encounter-policy',[]),('plains-encounter-policy-with-legacy',['--with-legacy'])]}
 p=source/'tools/harness/profiles.json';p.parent.mkdir();p.write_text(json.dumps({'schema_version':1,'checks':checks,'profiles':{}}));(source/'.gitignore').write_text('build/\n');git(source,'add','.');git(source,'commit','-qm','exact two endpoint input identities')
 subprocess.run(['git','clone','-q','--local','--no-hardlinks',str(source),str(target)],check=True);git(target,'sparse-checkout','init','--no-cone');subprocess.run(['git','-C',str(target),'sparse-checkout','set','--no-cone','--stdin'],input='/*\n!/docs/evidence/**\n',text=True,check=True,capture_output=True)
 before=git(target,'status','--porcelain');sparse=(target/'.git/info/sparse-checkout').read_bytes();plans={key:inputs.make_plan(target,checks=[key]) for key in checks}
 for plan in plans.values():assert {r['path'] for r in plan['inputs']}==set(names),plan
 report=inputs.materialize(target,checks=['plains-encounter-policy']);assert report['status']=='ready' and len(report['materialized'])==2;assert report['materialized_bytes']==977249;assert not(target/excluded).exists();assert not report['tests_executed'];assert(target/'.git/info/sparse-checkout').read_bytes()==sparse;assert git(target,'status','--porcelain')==before
 records=[]
 for name in names:
  a=(source/name).read_bytes();b=(target/name).read_bytes();assert a==b;records.append({'path':name,'size':len(b),'blob':git(target,'rev-parse','HEAD:'+name),'sha256':hashlib.sha256(b).hexdigest()})
 receipt={'status':'passed','scope':'actual committed endpoint bytes, temporary real sparse Git; availability only, no native/gameplay PASS','root_commit':git(root,'rev-parse','HEAD'),'fixture_commit':git(target,'rev-parse','HEAD'),'selected_commands':{key:checks[key]['argv'] for key in checks},'plans':{key:[r['path'] for r in p['inputs']] for key,p in plans.items()},'materialized':records,'materialized_bytes':report['materialized_bytes'],'unrelated_history_absent':True,'sparse_patterns_unchanged':True,'source_status_unchanged':True,'tests_executed':report['tests_executed']}
 (base/'actual-sparse-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt,indent=2))
