from pathlib import Path
import subprocess,json,hashlib,copy
R=Path('/workspace/gunman-rush-refactor');E=Path('/workspace/refactor-evidence/combat-perf-deploy-01/style32')
H=lambda b:hashlib.sha256(b).hexdigest()
BASE='e42b277f37425458a2920815258d1cfc817acfc3'
def git(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=R)
def write(p,v):
 q=R/p;q.parent.mkdir(parents=True,exist_ok=True);q.write_text(json.dumps(v,indent=2,ensure_ascii=False)+'\n')
oldstyle='docs/creative_direction/bibles/style-continuity-20261101-v31-mobile-combat-mesh.json';newstyle='docs/creative_direction/bibles/style-continuity-20261102-v32-combat-perf.json';A='docs/creative_direction/archive/combat-perf-before-style32';registry='docs/creative_direction/bibles/registry.json';style=json.loads(git(oldstyle));before=copy.deepcopy(style)
assert (R/oldstyle).read_bytes()==git(oldstyle)
allowed={'game/loadout/effects/'+p+'.gd' for p in ['item_art_library','item_companion_effects','item_runtime']}|{'game/enemies/presentation/plains_revision_'+p+'.gd' for p in ['flora','pose','skin']}
changes=[];sources=[];files=[]
def archive(path,ap):
 raw=git(path);out=R/A/ap;out.parent.mkdir(parents=True,exist_ok=True)
 if out.exists():assert out.read_bytes()==raw
 else:out.write_bytes(raw)
 files.append(dict(path=ap,sha256=H(raw),bytes=len(raw),source_commit=BASE));return raw
for row in style['runtime_reference']['references']:
 raw=(R/row['path']).read_bytes();now=H(raw)
 if now==row['sha256']:continue
 assert row['path'] in allowed,row['path']
 ap='sources/'+row['path']+'.txt';old=archive(row['path'],ap);assert H(old)==row['sha256']
 sources.append(dict(path=row['path'],archive_path=ap,sha256=H(old),role=row['role'],source_commit=BASE))
 changes.append(dict(role=row['role'],path=row['path'],previous_sha256=row['sha256'],sha256=now));row['sha256']=now
assert {c['path'] for c in changes}==allowed
for p in [registry,'docs/creative_direction/windchime_plains.json','docs/creative_direction/thorn_forest.json','tests/test_region_bible.py','tests/test_region_creative_direction.py','tools/harness/profiles.json']:archive(p,p)
manifest=dict(schema_version=1,parent='style31-creative34',source_commit=BASE,source_identity='Original six source leaves and six metadata/tests/profiles are exact committed e42b277f bytes; original source SHA exactly match retained style31.',scope='Finite historical replay only: six actually changed bound GD leaves and original metadata/tests/profiles; no media, runtime UID or copied acceptance.',selection=dict(original_reference_count=206,changed_source_count=6,media_copied=False,runtime_uid_copied=False),sources=sources,files=files)
write(A+'/manifest.json',manifest);mref=dict(path=A+'/manifest.json',sha256=H((R/A/'manifest.json').read_bytes()))
impact=dict(task_id='COMBAT-PERF-DEPLOY-01',source_commit=BASE,source_identity='Baseline e42b277f plus frozen working-tree candidate_source SHA; these six candidate bytes are not part of the baseline commit. Final commit ownership is separate from this technical source identity.',candidate_source=[dict(path=r['path'],sha256=r['sha256']) for r in changes],scope='Technical source binding for exported validated item-art cache, equivalent companion target selection/order and prepared mesh arithmetic. Preserve all selected media, geometry and resource rules. No new art/audio or inherited gameplay/art/user/device acceptance.',previous_binding_manifest=mref,original_reference_count=206,changed_references=changes,added_references=[],preserved='Exact206 role/path/order;200 references unchanged, including every non-GD reference. Original style31, historical source/media SHA, acceptance and failed evidence remain unchanged.',binding_scope_limit='Only six existing GD references; no new resource allowlist, asset, runtime registry or selected media version. Unbound legacy-feedback callers remain covered by their original runtime tests; not inserted as invented style roles.',validation='Technical provenance only. Native, fixed-workload performance, full Integration, exports and public GUI have separate actual receipts; this binding itself does not sign any of them or visual/listening/user/device acceptance.',historical_failure=before['revision_impact']['historical_failure'])
style['version']='32';style['runtime_reference']['status']='technical_combat_perf_source_binding_no_inherited_gameplay_art_audio_user_or_device_acceptance';style['supersedes']=dict(path=oldstyle,sha256=H(git(oldstyle)));style['revision_impact']=impact
write(newstyle,style);ref=dict(path=newstyle,sha256=H((R/newstyle).read_bytes()));reg=json.loads(git(registry));reg['shared_style_authority']=ref;write(registry,reg)
for region in ('windchime_plains','thorn_forest'):
 p='docs/creative_direction/'+region+'.json';d=json.loads(git(p));previous=H(git(p));d['version']='creative-v35';d['region_bible']['supplemental_authority_path']=newstyle;d['region_bible']['supplemental_authority_sha256']=ref['sha256'];d['region_bible']['registry_sha256']=H((R/registry).read_bytes());d['authority_sources'].append(ref)
 d['revision_impact']={k:copy.deepcopy(impact[k]) for k in ('task_id','source_commit','source_identity','candidate_source','scope')};d['revision_impact'].update(previous_direction=A+'/'+p,previous_sha256=previous,shared_style_path=newstyle,shared_style_sha256=ref['sha256'],previous_binding_manifest=mref,affected_consumers=[r['path'] for r in changes],validation=impact['validation'],historical_failure=impact['historical_failure']);write(p,d)
p=R/'tools/region_style_history.py';text=git('tools/region_style_history.py').decode();old='    return repository_file(path, root).read_bytes() if raw is None else raw\n';assert text.count(old)==1
text=text.replace(old,'    return style31_source(root, path) if raw is None else raw\n');text+=f'''\n\nSTYLE31_ARCHIVE = {A!r}\nSTYLE31_MANIFEST_SHA = {mref['sha256']!r}\n\n\ndef style31_source(root, path):\n    """Six prior31 leaves only; never used by current binding validators."""\n    raw = archived_source(root, STYLE31_ARCHIVE, path, STYLE31_MANIFEST_SHA)\n    return repository_file(path, root).read_bytes() if raw is None else raw\n''';p.write_text(text)
p='tools/harness/profiles.json';v=json.loads(git(p))
for name in ('region-bible-tests','region-bible-contract'):v['checks'][name]['inputs'] += [newstyle,A]
write(p,v)
(E/'metadata.json').write_text(json.dumps(dict(base=BASE,old_source=BASE,current_source=BASE,source_status='BASE_PLUS_FROZEN_WIP_PENDING_ROOT_FINAL_VECTOR',archive=A,style=newstyle,manifest=mref,changes=changes,old_style_sha256=H(git(oldstyle))),indent=2)+'\n')
print(json.dumps({'changes':len(changes),'manifest':mref,'new_style':ref,'archive_files':len(files)},indent=2))
