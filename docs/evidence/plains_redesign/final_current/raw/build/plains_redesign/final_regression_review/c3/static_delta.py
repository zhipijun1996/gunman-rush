"""Read-only C3 guard delta. No engine/browser/encoder or production writes."""
import json,subprocess,hashlib,tarfile,gzip,ast,sys,re
from pathlib import Path
R=Path.cwd();O=R/'build/plains_redesign/final_regression_review/c3';A='30f6a825712fbb30e607791c996de142c6757a79';C2='20f9b21d7e092348dd9de146267c46540a88d9cb';C3='ee821ce18746253c01ad9e27270df96488870264';sys.path.insert(0,str(R/'tools'));import level_formal as formal,check_quality_diff as qualitydiff
H=lambda b:hashlib.sha256(b).hexdigest();run=lambda *a:subprocess.check_output(['git',*a]);head=run('rev-parse','HEAD').decode().strip();assert head==C3
execution_path=R/'build/plains_redesign/q6_rollback/execution.json';execution=json.loads(execution_path.read_text());assert execution['restored_exact_commit']==C2;restored=[]
for row in execution['rows']:
 name=row['path'];old=run('show',C2+':'+name);commit=run('show',C3+':'+name);current=(R/name).read_bytes();assert old==commit==current and H(current)==row['restored_sha256'];backup=R/row['rejected_exact_backup'];assert H(backup.read_bytes())==row['rejected_sha256'];restored.append(dict(path=name,current_sha256=H(current),rejected_sha256=row['rejected_sha256'],rejected_backup=row['rejected_exact_backup']))
assert len(restored)==4
# All active code/assets/tests/checks outside generated Foundry remain C2 exact.
changes=run('diff','--name-only',C2,C3,'--','scripts','tests','tools','config','assets','shaders','resources','project.godot').decode().splitlines();assert len(changes)==56 and all(p.startswith('resources/foundry/') for p in changes),changes
# Existing baseline47 check definitions+all memberships; current52 exactly C2.
base=json.loads(run('show',A+':tools/harness/profiles.json'));c2=json.loads(run('show',C2+':tools/harness/profiles.json'));current=json.loads((R/'tools/harness/profiles.json').read_text());assert current==c2 and all(current['checks'].get(k)==v for k,v in base['checks'].items()) and all(set(v)<=set(current['profiles'][k]) for k,v in base['profiles'].items())
# C3 rolled back candidate-only tests, not committed baseline assertions.
old_tests=run('ls-tree','-r','--name-only',A,'tests').decode().splitlines();current_tests=run('ls-tree','-r','--name-only',C3,'tests').decode().splitlines();assert set(old_tests)<=set(current_tests);assert not run('diff','--name-only',C2,C3,'--','tests','tools').strip()
weak=[]
for name in run('diff','--name-only',A,C3,'--','tests','tools').decode().splitlines():
 exists=subprocess.run(['git','cat-file','-e',A+':'+name],capture_output=True).returncode==0
 if not exists or not name.endswith(('.gd','.py','.json','.mjs','.sh')):continue
 if not(name.startswith('tests/') or 'run_' in name or name in ['tools/harness.py','tools/harness/profiles.json']):continue
 old=run('show',A+':'+name).decode();new=run('show',C3+':'+name).decode();removed=qualitydiff.weakened_checks(old,new)
 if removed:weak.append(dict(path=name,conservative_signals=removed))
# Exact current core & 19 driver paths. First against C2, core also baseline30f.
core=sorted(formal.core_source_paths());driver=sorted(formal.driver_source_paths());assert len(core)==133 and len(driver)==19
for name in set(core)|set(driver):assert run('show',C2+':'+name)==run('show',C3+':'+name)==(R/name).read_bytes(),name
for name in core:assert run('show',A+':'+name)==(R/name).read_bytes(),name
# Frozen historical source archive+manifest remain byte exact C2.
frozen=[]
for name in ['docs/evidence/plains_redesign/frozen_v9/manifest.json','docs/evidence/plains_redesign/frozen_v9/source.tar.gz']:
 b=run('show',C2+':'+name);assert b==run('show',C3+':'+name)==(R/name).read_bytes();frozen.append(dict(path=name,sha256=H(b)))
# Failed sources/raw/native/movie and the rejected asset are exact portable members.
indices=[];member_rows=[]
for directory in ['scene_q6_rework','q6_cliff_asset','q6_before']:
 folder=R/'docs/evidence/plains_redesign'/directory;index=json.loads((folder/'index.json').read_text());rows=[]
 for m in index['members']:
  path=folder/m['stored'];b=path.read_bytes();assert H(b)==m['stored_sha256'];raw=gzip.decompress(b) if m['compression']=='gzip' else b;assert H(raw)==m['sha256'] and len(raw)==m['bytes'];rows.append(dict(path=str(path.relative_to(R)),stored_sha256=H(b),raw_sha256=H(raw),bytes=len(raw)))
 member_rows+=rows;indices.append(dict(path=str((folder/'index.json').relative_to(R)),sha256=H((folder/'index.json').read_bytes()),members=len(rows)))
rework=R/'docs/evidence/plains_redesign/scene_q6_rework';idx=json.loads((rework/'index.json').read_text());assert idx['native']['assertions']==59 and idx['native']['real_node_negatives']==14 and idx['native']['receipt_negatives']==14
for row in restored:
 matches=[x for x in member_rows if x['raw_sha256']==row['rejected_sha256']];assert matches,row['path'];row['portable_rejected_matches']=[x['path'] for x in matches]
with tarfile.open(rework/'current_source.tar.gz') as a:
 archived={m.name:a.extractfile(m).read() for m in a.getmembers() if m.isfile()}
assert len(archived)==idx['current_source_files']==688
# Actual failed candidate source contained the extra4 Node/extra2 receipt conditions.
source=Path(execution['rows'][3]['rejected_exact_backup']).read_text();module=ast.parse(source);mut=next(n.value for n in ast.walk(module) if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='MUTATIONS' for t in n.targets));assert len(ast.literal_eval(mut))==14
live=ast.parse((R/'tools/run_plains_redesign_scene_tests.py').read_text());mut=next(n.value for n in ast.walk(live) if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='MUTATIONS' for t in n.targets));assert len(ast.literal_eval(mut))==10
assetfolder=R/'docs/evidence/plains_redesign/q6_cliff_asset';assetidx=json.loads((assetfolder/'index.json').read_text());assert assetidx['runtime_asset_registered'] is False and assetidx['actual_imagegen_calls']==1;png=assetfolder/'source/candidate-v1.png';assert H(png.read_bytes())==assetidx['actual_generated_png_sha256'];assert not run('diff','--name-only',C2,C3,'--','assets').strip()
# Search active runtime/source references, not evidence/docs snapshots.
for folder in ['scripts','scenes','resources','config','assets']:
 for p in (R/folder).rglob('*'):
  if p.is_file() and p.suffix in ['.gd','.json','.tres','.tscn','.import']:
   text=p.read_text(errors='replace');assert 'candidate-v1.png' not in text and 'q6_cliff_asset' not in text and assetidx['actual_generated_png_sha256'] not in text,str(p)
# Current non-doc inputs vs the actual saved C2 basis. Two Skills were explicitly added after rollback.
non_doc_delta=[]
for name,h in execution['c2_non_document_inputs_compared'].items():
 path=R/name;now=H(path.read_bytes()) if path.is_file() else 'deleted'
 if h!=now:non_doc_delta.append(dict(path=name,c2_sha256=h,current_sha256=now))
assert {x['path'] for x in non_doc_delta}<={'.agents/skills/art-director/SKILL.md','.agents/skills/scene-composer/SKILL.md'},non_doc_delta
# Foundry is stable after real stamp/harness entry; record exact leaf changes, no mid-build read.
log=(R/'build/plains_redesign/q6_final_delivery.log').read_text();assert "'tools/harness.py'" in log

def diff(a,b,p=''):
 if type(a)!=type(b):return [p]
 if isinstance(a,dict):return [z for k in a.keys()|b.keys() for z in ([p+'/'+str(k)] if k not in a or k not in b else diff(a[k],b[k],p+'/'+str(k)))]
 if isinstance(a,list):return [p+'/length'] if len(a)!=len(b) else [z for i,(x,y) in enumerate(zip(a,b)) for z in diff(x,y,p+'/'+str(i))]
 return [] if a==b else [p]
foundry=[]
for name in changes:
 c2b=run('show',C2+':'+name);c3b=run('show',C3+':'+name);actual=(R/name).read_bytes();paths=diff(json.loads(c2b),json.loads(c3b));assert all(p.rsplit('/',1)[-1] in ['basis','hash','manifest_hash'] for p in paths);assert actual==c3b,name;foundry.append(dict(path=name,c2_sha256=H(c2b),c3_sha256=H(c3b),actual_post_stamp_sha256=H(actual),changed_json_paths=paths))
# Preserve source-bound outputs only; no final actual execution admission yet.
result=dict(scope='C3 static preparation only; UNVERIFIED pending fresh delivery/GUI/cohort',baseline=A,c2=C2,c3=C3,restored_exact_files=restored,committed_active_delta=changes,old_tests_retained=len(old_tests),current_tests=len(current_tests),profiles=dict(old_checks=len(base['checks']),current_checks=len(current['checks']),old_config_exact=True,old_profile_members_retained=True,c2_profile_identical=True),conservative_changed_guard_signals=weak,core133_unchanged=True,driver19_equals_c2=True,frozen_v9=frozen,failed_archive_indices=indices,rejected_native_counts=[59,14,14],current_restored_counts=[59,10,12],rejected_runtime_asset_registered=False,rejected_png_sha256=H(png.read_bytes()),c2_actual_non_document_basis_count=len(execution['c2_non_document_inputs_compared']),intentional_after_rollback_doc_delta=non_doc_delta,root_quality_diff_log_sha256=H((R/'build/plains_redesign/final_diff_pre_review.log').read_bytes()),execution_json_sha256=H(execution_path.read_bytes()))
(O/'static_delta.json').write_text(json.dumps(result,indent=2));(O/'failed_member_hashes.json').write_text(json.dumps(member_rows,indent=2));(O/'foundry_c2_c3_actual_bridge.json').write_text(json.dumps(foundry,indent=2));print('C3 STATIC CHECKED exact4; original47/current52; core133/driver19; archives',[(x['path'],x['members']) for x in indices],'; Foundry56 only basis/hash and actual C3 exact; no runtime asset; UNVERIFIED')
