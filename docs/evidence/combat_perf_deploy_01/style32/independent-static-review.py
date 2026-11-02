from pathlib import Path
import json,hashlib,subprocess,ast
R=Path('/workspace/gunman-rush-refactor');E=Path(__file__).parent
sha=lambda b:hashlib.sha256(b).hexdigest();F=json.loads((E/'freeze.json').read_text());base=F['baseline'];git=lambda p:subprocess.check_output(['git','show',base+':'+p],cwd=R)
assert sha((E/'freeze.json').read_bytes())=='5da381323cd1d1186b7211b53f6c41eb1676be2916579d0f0d8fcaf4bb33c825'
assert len(F['files'])==21
for row in F['files']:
 data=(R/row['path']).read_bytes();assert sha(data)==row['sha256'] and len(data)==row['bytes'],row['path']
 if row['previous_sha256'] is not None:assert sha(git(row['path']))==row['previous_sha256'],row['path']
assert sha((E/'candidate.patch').read_bytes())==F['candidate_patch_sha256']
s=json.loads((R/F['files'][0]['path']).read_text());oldpath=s['supersedes']['path'];oldraw=(R/oldpath).read_bytes();old=json.loads(oldraw);assert oldraw==git(oldpath);assert sha(oldraw)==s['supersedes']['sha256']
a=old['runtime_reference']['references'];b=s['runtime_reference']['references'];assert len(a)==len(b)==206
assert [(r['role'],r['path'])for r in a]==[(r['role'],r['path'])for r in b]
changed=[];non_gd=0
for x,y in zip(a,b):
 assert sha((R/y['path']).read_bytes())==y['sha256'],y['path']
 if x!=y:
  assert {k:v for k,v in x.items()if k!='sha256'}=={k:v for k,v in y.items()if k!='sha256'}
  assert y['path'].endswith('.gd');changed.append(y['path'])
 if not y['path'].endswith('.gd'):assert x==y;non_gd+=1
assert len(changed)==6 and non_gd==86
assert set(k for k in old if old[k]!=s[k])=={'version','supersedes','runtime_reference','revision_impact'}
for p in ['docs/creative_direction/thorn_forest.json','docs/creative_direction/windchime_plains.json']:
 x=json.loads(git(p));y=json.loads((R/p).read_bytes());assert {k:v for k,v in x.items()if k not in ['version','region_bible','authority_sources','revision_impact']}=={k:v for k,v in y.items()if k not in ['version','region_bible','authority_sources','revision_impact']};assert y['authority_sources'][:-1]==x['authority_sources'];assert (x['version'],y['version'])==('creative-v34','creative-v35')
rp='docs/creative_direction/bibles/registry.json';x=json.loads(git(rp));y=json.loads((R/rp).read_text());assert {k:v for k,v in x.items()if k!='shared_style_authority'}=={k:v for k,v in y.items()if k!='shared_style_authority'}
arch='docs/creative_direction/archive/combat-perf-before-style32/';manifest=json.loads((R/arch/'manifest.json').read_text());narchive=0
for row in F['files']:
 if not row['path'].startswith(arch) or row['path']==arch+'manifest.json':continue
 rel=row['path'][len(arch):];original=rel[len('sources/'):-len('.txt')] if rel.startswith('sources/') else rel
 assert (R/row['path']).read_bytes()==git(original),row['path'];narchive+=1
assert narchive==12
assert sha((R/arch/'manifest.json').read_bytes())==s['revision_impact']['previous_binding_manifest']['sha256']
assert {r['path']for r in manifest['sources']}==set(changed)
p='tools/harness/profiles.json';x=json.loads(git(p));y=json.loads((R/p).read_text());assert len(x['checks'])==len(y['checks'])==219;assert x['profiles']==y['profiles'];assert len(y['profiles']['full'])==171
ci=[]
for id,before in x['checks'].items():
 after=y['checks'][id]
 if before==after:continue
 assert id in ['region-bible-tests','region-bible-contract'];assert {k:v for k,v in before.items()if k!='inputs'}=={k:v for k,v in after.items()if k!='inputs'};assert after['inputs'][:len(before['inputs'])]==before['inputs'];assert after['inputs'][len(before['inputs']):]==[F['files'][0]['path'],arch.rstrip('/')];ci.append(id)
assert len(ci)==2
proof=json.loads((E/'static-proof.json').read_text());inverse={(r['path'],r['method']):r['steps']for r in proof['original_method_inverse']}
assert len(inverse)==8
old_methods={};new_methods={};counts={};changed_methods=[]
for path in ['tests/test_region_bible.py','tests/test_region_creative_direction.py']:
 before=git(path).decode();after=(R/path).read_text();old_methods[path]={n.name:n for n in ast.walk(ast.parse(before))if isinstance(n,ast.FunctionDef) and n.name.startswith('test_')};new_methods[path]={n.name:n for n in ast.walk(ast.parse(after))if isinstance(n,ast.FunctionDef)and n.name.startswith('test_')}
 for name,node in old_methods[path].items():
  new=new_methods[path][name];source=ast.get_source_segment(after,new)
  if ast.dump(node,include_attributes=False)!=ast.dump(new,include_attributes=False):
   steps=inverse[(path,name)];changed_methods.append(path+'::'+name)
   for step in steps:
    assert source.count(step['new'])==step['count'],(path,name,step);source=source.replace(step['new'],step['original'])
   assert ast.dump(ast.parse(source).body[0],include_attributes=False)==ast.dump(node,include_attributes=False),(path,name)
  else:assert (path,name)not in inverse
 counts[path]={'old':len(old_methods[path]),'current':len(new_methods[path]),'all_original_complete_method_AST_after_finite_inverse':True}
assert len(changed_methods)==8
# Independently check the entire existing method-lock table history, not just
# that authors regenerated hashes. Original identities never change.
def maps(text):
 out={}
 for n in ast.parse(text).body:
  if isinstance(n,ast.Assign) and len(n.targets)==1 and isinstance(n.targets[0],ast.Name) and n.targets[0].id.endswith('_TEST_METHOD_MIGRATIONS'):
   out[n.targets[0].id]=ast.literal_eval(n.value)
 return out
bm=maps(git('tests/test_region_bible.py').decode());nm=maps((R/'tests/test_region_bible.py').read_text());pinchanges=0
for name,oldmap in bm.items():
 assert set(oldmap)==set(nm[name])
 for key,oldentry in oldmap.items():
  new=nm[name][key];assert oldentry['original_ast_sha256']==new['original_ast_sha256']
  if oldentry==new:continue
  assert set(k for k in set(oldentry)|set(new)if oldentry.get(k)!=new.get(k))<= {'current_ast_sha256','prior_current_ast_sha256s','reason'}
  assert new['prior_current_ast_sha256s']==oldentry.get('prior_current_ast_sha256s',[])+[oldentry['current_ast_sha256']]
  filename,method=key.split('::');node=new_methods['tests/'+filename][method];assert sha(ast.dump(node,include_attributes=False).encode())==new['current_ast_sha256'];pinchanges+=1
assert set(nm)-set(bm)=={'COMBAT_PERF_TEST_METHOD_MIGRATIONS'}
for key,row in nm['COMBAT_PERF_TEST_METHOD_MIGRATIONS'].items():
 filename,method=key.split('::');path='tests/'+filename
 assert row['original_ast_sha256']==sha(ast.dump(old_methods[path][method],include_attributes=False).encode())
 assert row['current_ast_sha256']==sha(ast.dump(new_methods[path][method],include_attributes=False).encode())
# The shared complete-method guard and partition validator/loader must not change.
def funcs(text):return {n.name:ast.dump(n,include_attributes=False)for n in ast.parse(text).body if isinstance(n,ast.FunctionDef)}
f0=funcs(git('tests/test_region_bible.py').decode());f1=funcs((R/'tests/test_region_bible.py').read_text())
for name in f0:assert f0[name]==f1[name],name
history0=funcs(git('tools/region_style_history.py').decode());history1=funcs((R/'tools/region_style_history.py').read_text())
for name in history0:
 if name!='style30_source':assert history0[name]==history1[name],name
assert '98e2454f2781c028d1a6c512bd7976845a4396ef4d546e08dea2b4f4ece6a333' in (R/'tools/check_quality_diff.py').read_text()
assert git('tools/region_creative_direction.py')==(R/'tools/region_creative_direction.py').read_bytes()
# Only historical31 methods move current->history, no omissions, and loader exact.
def literals(text,names):
 return {n.targets[0].id:ast.literal_eval(n.value) for n in ast.parse(text).body if isinstance(n,ast.Assign)and len(n.targets)==1 and isinstance(n.targets[0],ast.Name)and n.targets[0].id in names}
p0=literals(git('tests/test_region_bible.py').decode(),['CURRENT_METHODS','HISTORY_METHODS']);p1=literals((R/'tests/test_region_bible.py').read_text(),['CURRENT_METHODS','HISTORY_METHODS']);assert set(p0['CURRENT_METHODS']+p0['HISTORY_METHODS'])<=set(p1['CURRENT_METHODS']+p1['HISTORY_METHODS']);assert len(p1['CURRENT_METHODS'])+len(p1['HISTORY_METHODS'])==90
# Actual existing logs are read and hashed, not rerun here.
runs=json.loads((E/'runs-01.json').read_text())
for row in runs:assert sha(Path(row['log']).read_bytes())==row['log_sha256'] and row['exit_code']==0 and not row['timed_out'] and row['elapsed_seconds']<=row['timeout_seconds']
report={'status':'LIMITED_STATIC_ACCEPT_STYLE32_CREATIVE35_21_FILES','baseline':base,'freeze_sha256':sha((E/'freeze.json').read_bytes()),'files':F['files'],'independent_findings':{'all21_frozen_bytes_verified':True,'old_style31_exact_git_bytes_unchanged':True,'206_role_path_order_exact':True,'six_changed_GD_only':changed,'86_non_GD_rows_and_current_bytes_verified':True,'old12_archive_leaves_exact_e42_git':True,'registry_only_shared_authority_changed':True,'creative_selected_content_and_acceptance_unchanged':True,'check219_full171_all_profiles_commands_budgets_unchanged':True,'only_two_inputs_append_preserves_order_and_multiplicity':ci,'original_test_methods_preserved':counts,'exact8_finite_complete_method_inverse':changed_methods,'old_original_AST_hashes_immutable':True,'current_AST_pins_independently_recomputed_and_prior_current_pins_retained':pinchanges,'shared_full_method_guard_and_suite_loader_AST_unchanged':True,'live_validator_bytes_unchanged':True,'history_chain_only_adds_finite31_and_preserves_failclosed_reader':True,'quality_diff_loader_current98e_pin_present':True},'test_change_justification':'Only current31->32/creative34->35 identity expectations, explicit frozen31 replay for old31/34 consumers and finite original-method normalization extension. All86+28 original complete methods recover by8 counted inverse mappings;4Bible+1creative tests add current drift/missing/resigned archive and full-AST control-flow mutation rejection. No old assertion/loop/partition guard removed.','existing_author_runs_observed':[{'name':r['name'],'elapsed_seconds':r['elapsed_seconds'],'budget':r['timeout_seconds'],'log_sha256':r['log_sha256']}for r in runs],'limits':['No engine, CI or tests executed by this reviewer; existing five source-bound logs only inspected.','Only21 metadata/history/test/input files accepted; performance/gameplay equivalence of8GD runtime changes needs its own independent/native evidence.','Loader98e pin preserved and noted; root prior separate quality-diff review remains responsible for that out-of-write-set tool change.','No new art/audio, device/player acceptance or complete deployment signed; source identity remains baseline plus frozen WIP vector, not a fabricated committed runtime.'],'repo_written':False}
(E/'independent-review.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(sha((E/'independent-review.json').read_bytes()));print(json.dumps(report['independent_findings'],ensure_ascii=False))
