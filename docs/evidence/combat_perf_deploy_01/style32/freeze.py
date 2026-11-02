from pathlib import Path
import ast,json,hashlib,subprocess,difflib
R=Path('/workspace/gunman-rush-refactor');E=Path('/workspace/refactor-evidence/combat-perf-deploy-01/style32');BASE='e42b277f37425458a2920815258d1cfc817acfc3'
H=lambda b:hashlib.sha256(b).hexdigest()
def git(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=R)
m=json.loads((E/'metadata.json').read_bytes());A=m['archive'];style=json.loads((R/m['style']).read_bytes());old=json.loads(git(style['supersedes']['path']));proof={}
assert (R/style['supersedes']['path']).read_bytes()==git(style['supersedes']['path'])
a,b=old['runtime_reference']['references'],style['runtime_reference']['references'];assert len(a)==len(b)==206
assert [(x['role'],x['path']) for x in a]==[(x['role'],x['path']) for x in b]
changes=[y['path'] for x,y in zip(a,b) if x!=y];assert len(changes)==6
for x in b:assert H((R/x['path']).read_bytes())==x['sha256']
assert all(x==y for x,y in zip(a,b) if not x['path'].endswith('.gd'))
proof['references']={'count':206,'role_path_order_unchanged':True,'changed':changes,'unchanged':200,'non_gd_unchanged':86,'all_current_sha_match':True}
manifest=json.loads((R/A/'manifest.json').read_bytes());assert H((R/A/'manifest.json').read_bytes())==m['manifest']['sha256']
for x in manifest['files']:
 p=x['path'];orig=p.removeprefix('sources/').removesuffix('.txt') if p.startswith('sources/') else p
 assert (R/A/p).read_bytes()==git(orig)
proof['archive']={'exact_git_files':len(manifest['files']),'git_commit':BASE,'media_or_runtime_uids_copied':False}
for region in ['thorn_forest','windchime_plains']:
 p='docs/creative_direction/'+region+'.json';x=json.loads(git(p));y=json.loads((R/p).read_text());assert y['version']=='creative-v35';assert y['user_acceptance']=='direction_only_not_art_gameplay_or_device'
 for k in x.keys()-{'version','region_bible','authority_sources','revision_impact'}:assert x[k]==y[k]
 assert y['authority_sources'][:-1]==x['authority_sources']
proof['creative_content_preserved_no_acceptance_inherited']=True
p='tools/harness/profiles.json';x=json.loads(git(p));y=json.loads((R/p).read_bytes());changedchecks=[]
for name in x['checks']:
 if x['checks'][name]!=y['checks'][name]:
  changedchecks.append(name);u=x['checks'][name];v=y['checks'][name];assert {k:w for k,w in u.items() if k!='inputs'}=={k:w for k,w in v.items() if k!='inputs'};assert v['inputs']==u['inputs']+[m['style'],A]
assert set(changedchecks)=={'region-bible-tests','region-bible-contract'}
for k in x.keys()-{'checks'}:assert x[k]==y[k]
assert x['checks'].keys()==y['checks'].keys()
proof['profiles']={'check_count':len(x['checks']),'only_append_inputs':changedchecks,'old_prefix_multiplicity_order_preserved':True,'all_commands_budgets_and_suite_selections_unchanged':True}
# Inverse ONLY finite documented version/root adaptation; no whole-method replacement.
inverse=[]
for p in ['tests/test_region_bible.py','tests/test_region_creative_direction.py']:
 oldtext=git(p).decode();newtext=(R/p).read_text()
 def methods(s):return {z.name:ast.get_source_segment(s,z) for z in ast.walk(ast.parse(s)) if isinstance(z,ast.FunctionDef) and z.name.startswith('test_')}
 om,nm=methods(oldtext),methods(newtext)
 for name,v in om.items():
  n=nm[name];steps=[]
  def undo(new,old,count=None):
   global n
   times=n.count(new) if count is None else count
   if times:
    assert n.count(new)==times;n=n.replace(new,old,times);steps.append({'new':new,'original':old,'count':times})
  if p.endswith('test_region_bible.py'):
   if name in ['test_actual_player_body_closure_is_required_and_superseded_binding_refused','test_actual_player_body_closure_is_required_and_superseded_binding_refused_audio_history']:
    undo("self.assertEqual(style['content']['version'],'32')","self.assertEqual(style['content']['version'],'31')",1)
   elif name=='test_merged22_keeps83_roles_and_both_parent21_histories_and_rejects_stale':undo("self.assertEqual(live['version'],'32')","self.assertEqual(live['version'],'31')",1)
   elif name=='test_preserved_original_test_methods_are_unchanged':
    undo("'31':'25','32':'25'","'31':'25'",1);undo("'creative-v34':'creative-v28','creative-v35':'creative-v28'","'creative-v34':'creative-v28'",1)
   elif name in ['test_current31_exact206_sources_roles_media_and_three_technical_changes','test_current31_rejects_old_missing_corrupt_sources_and_manifest_resigning']:
    undo("        self.root = frozen31_root(self)\n        self.bible, self.ref = creative.bind_region_bible('thorn_forest', self.root)\n",'',1)
  else:
   if name=='test_selected_direction_binds_every_specialist_and_retains_stage_gates':undo("'creative-v35'","'creative-v34'",1)
   elif name=='test_current34_retains_selected_content_and_refuses_prior33_binding':
    undo('from test_region_bible import frozen30_root, frozen31_root','from test_region_bible import frozen30_root',1);undo('\n        current_root = frozen31_root(self)','',1);undo('creative.load_direction(path, region, root=current_root)','creative.load_direction(path, region)',1);undo('creative.load_bible_registry(current_root)','creative.load_bible_registry()',1);undo('creative.bind_region_bible(region, current_root)[1]','creative.bind_region_bible(region)[1]',1);undo("creative.validate_bible_binding(old['region_bible'], root=current_root)","creative.validate_bible_binding(old['region_bible'])",1)
  assert n==v,(p,name)
  if steps:inverse.append({'path':p,'method':name,'steps':steps})
 proof[p]={'original_methods_all_exact_after_finite_inverse':len(om),'current_total':len(nm),'added_methods':sorted(nm.keys()-om.keys())}
proof['original_method_inverse']=inverse
changedall=subprocess.check_output(['git','diff','--name-only',BASE],cwd=R,text=True).splitlines();media=[p for p in changedall if p.startswith(('assets/','resources/','shaders/'))];assert not media
proof['resource_change_audit']={'tracked_assets_resources_shaders_changed':media,'all86_bound_non_gd_bytes_verified':True,'no_all_media_download_or_rehash_claim':True}
vector=[]
for p in changedall:
 if p.startswith('game/') and p.endswith('.gd'):vector.append({'path':p,'sha256':H((R/p).read_bytes()),'bound_style_role':p in [r['path'] for r in b]})
for folder in ['cache','companions','legacy-feet']:
 candidate=json.loads((E.parent/folder/'candidate.json').read_bytes())
 for row in candidate['files']:assert H((R/row['path']).read_bytes())==row.get('after_sha256',row.get('sha256'))
proof['frozen_all_runtime_vector']=vector
assert '98e2454f2781c028d1a6c512bd7976845a4396ef4d546e08dea2b4f4ece6a333' in (R/'tools/check_quality_diff.py').read_text()
assert git('tools/region_creative_direction.py')==(R/'tools/region_creative_direction.py').read_bytes()
proof['unchanged_live_validator_and_preserved_root_loader_sha']=True
paths=[m['style'],'docs/creative_direction/bibles/registry.json','docs/creative_direction/windchime_plains.json','docs/creative_direction/thorn_forest.json','tools/region_style_history.py','tests/test_region_bible.py','tests/test_region_creative_direction.py','tools/harness/profiles.json']+[str(q.relative_to(R)) for q in sorted((R/A).rglob('*')) if q.is_file()]
rows=[];patch=[]
for p in paths:
 raw=(R/p).read_bytes()
 if p==m['style'] or p.startswith(A+'/'):oldraw=b''
 else:oldraw=git(p)
 rows.append({'path':p,'sha256':H(raw),'bytes':len(raw),'previous_sha256':H(oldraw) if oldraw else None})
 patch.extend(difflib.unified_diff(oldraw.decode().splitlines(True),raw.decode().splitlines(True),fromfile='a/'+p if oldraw else '/dev/null',tofile='b/'+p))
(E/'candidate.patch').write_text(''.join(patch));(E/'static-proof.json').write_text(json.dumps(proof,indent=2)+'\n');(E/'freeze.json').write_text(json.dumps({'baseline':BASE,'status':'FROZEN_METADATA_TEST_INPUT_CANDIDATE_PENDING_NONAUTHOR_REVIEW','files':rows,'candidate_patch_sha256':H((E/'candidate.patch').read_bytes()),'runtime_vector':vector,'static_proof_sha256':H((E/'static-proof.json').read_bytes())},indent=2)+'\n')
print(json.dumps({'files':len(rows),'freeze_sha256':H((E/'freeze.json').read_bytes()),'runtime_leaves':len(vector),'original_bible_methods':proof['tests/test_region_bible.py']['original_methods_all_exact_after_finite_inverse'],'original_creative_methods':proof['tests/test_region_creative_direction.py']['original_methods_all_exact_after_finite_inverse']},indent=2))
