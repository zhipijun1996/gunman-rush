"""Independent real-Git/file boundary probes. No worker or native execution."""
import ast,hashlib,importlib.util,json,pathlib,subprocess,sys,os
from unittest.mock import patch
ROOT=pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'tools'))
spec=importlib.util.spec_from_file_location('review_loop_test',ROOT/'tests/test_production_loop.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
case=mod.SelectedInputPreflightTests('test_declared_directory_input_uses_boundary_and_unknown_untracked_warning');case.setUp()
results={'euid':os.geteuid(),'cases':{}}
try:
 task=case.configure(); paths={'fixtures/prefix/nested/proof.txt':'proof','fixtures/prefix-other/neighbor.txt':'neighbor'}
 for name,body in paths.items():
  p=case.main/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(body)
 manifest=json.loads((case.main/'tools/harness/profiles.json').read_text());manifest['checks']['quality-tests']['inputs']=['fixtures/prefix/','future-created-only/'];mod.loop.save(case.main/'tools/harness/profiles.json',manifest)
 case.git('add','.');case.git('commit','-qm','Independent real prefix and neighbor source')
 subprocess.check_call(['git','-C',str(case.target),'reset','--hard','-q',case.git('rev-parse','HEAD').decode().strip()]);subprocess.check_call(['git','-C',str(case.target),'read-tree','-mu','HEAD'])
 actual={**task,'checks':['quality-tests'],'allowed_paths':['fixtures/prefix/']}
 proof=case.target/'fixtures/prefix/nested/proof.txt';neighbor=case.target/'fixtures/prefix-other/neighbor.txt';neighbor.unlink()
 def probe():
  with patch.object(mod.loop,'ROOT',case.main),mod.loop._collection_worktree(case.target):return mod.loop.required_input_preflight(actual)
 result=probe();assert result['status']=='passed';assert any(w.get('index')=='future-created-only/' and w.get('warning')=='declared_input_has_no_tracked_match' for w in result['index_warnings']);results['cases']['neighbor_missing_and_unknown_future']=result
 original=proof.read_bytes();proof.unlink();result=probe();assert result['status']=='blocked';assert [x['path'] for x in result['missing_tracked_inputs']]==['fixtures/prefix/nested/proof.txt'];results['cases']['prefix_scope_does_not_waive_deleted_input']=result
 proof.symlink_to('/etc/hostname');result=probe();assert result['status']=='blocked';assert result['missing_tracked_inputs'][0]['reason']=='symlink_input';results['cases']['real_external_symlink']=result;proof.unlink();proof.write_bytes(original)
 proof.parent.chmod(0)
 try:
  result=probe();assert os.geteuid()!=0;assert result['status']=='blocked';assert result['missing_tracked_inputs'][0]['reason'].startswith('unreadable:');results['cases']['real_unreadable_directory']=result
 finally:proof.parent.chmod(0o755)
 result=probe();assert result['status']=='passed';results['cases']['restored_readable']=result
 before=ROOT/'docs/evidence/region_production_v3/forest_fixture_preflight/before/tests/test_production_loop.py';after=ROOT/'tests/test_production_loop.py'
 def tests(path):
  tree=ast.parse(path.read_text());return {n.name:ast.dump(n,include_attributes=False) for n in ast.walk(tree) if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef)) and n.name.startswith('test_')}
 b,a=tests(before),tests(after);assert len(b)==81;assert all(a[k]==v for k,v in b.items());results['old_test_ast_preserved']=len(b);results['new_test_names']=sorted(a.keys()-b.keys())
 receipt=json.loads((ROOT/'docs/evidence/region_production_v3/forest_fixture_preflight/receipt.json').read_text());results['frozen_sha256']={}
 for name,v in receipt['before_after'].items():
  h=hashlib.sha256((ROOT/name).read_bytes()).hexdigest();assert h==v['after_sha256'];results['frozen_sha256'][name]=h
 old=json.loads((ROOT/'docs/evidence/region_production_v3/forest_fixture_preflight/before/tools/harness/profiles.json').read_text());new=json.loads((ROOT/'tools/harness/profiles.json').read_text());old['checks'].pop('level-design-contracts');selected=new['checks'].pop('level-design-contracts');assert old==new;assert selected['cacheable'] is False;results['other_profile_metadata_identical']=True
 results['status']='scoped_accept'
finally:case.doCleanups()
print(json.dumps(results,indent=2))
