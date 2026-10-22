from pathlib import Path
import json,hashlib,zipfile,re,subprocess
R=Path('/workspace/gunman-rush');O=R/'build/region_bible_v2/foundry-refresh05';BASE='e594d3ff54daaf9d8f5e30f3190890737ce39a1e'
sha=lambda b:hashlib.sha256(b).hexdigest()
b=json.loads((O/'source-before.json').read_text());a=json.loads((O/'source-after.json').read_text());r=json.loads((O/'receipt.json').read_text());changes=sorted(k for k in set(a)|set(b) if a.get(k)!=b.get(k));assert changes==r['changed_paths'] and all(k.startswith('resources/foundry/') and k.endswith('.json') for k in changes)
lib=json.loads((R/'build/region_bible_v2/forest-library-feedback/d4c1dfd72b3a4c9592b68d83bd9e716c/source-after.json').read_text());assert b==lib
assert all(sha((R/n).read_bytes())==h for n,h in a.items())
idx=json.loads((O/'old-foundry-index.json').read_text());z=zipfile.ZipFile(O/'old-foundry.zip');assert sorted(z.namelist())==sorted(i['path'] for i in idx)
for i in idx:
 raw=z.read(i['path']);assert len(raw)==i['bytes'] and sha(raw)==i['sha256']==b[i['path']]
assert r['exit_code']==0 and all(c['exit_code']==0 for c in r['commands'])
for n in ['tools/foundry.py','tools/foundry_validate.gd','tools/foundry_export_stamp.gd','scripts/generation/foundry_catalog.gd']:
 raw=subprocess.check_output(['git','show',BASE+':'+n],cwd=R);assert raw==(R/n).read_bytes(),n
batch=json.loads((R/'resources/foundry/batch.json').read_text());stamp=json.loads((R/'resources/foundry/export_basis.json').read_text());assert len(batch['accepted'])==36 and len(batch['itineraries'])==len(batch['connection_proofs'])==18 and batch['rejected']==[] and batch['production_pool'] is False and batch['design_status']=='awaiting_playtest'
assert batch['basis']==stamp['basis']==r['basis'];assert all(sha((R/n.removeprefix('res://')).read_bytes())==h for n,h in stamp['configs'].items())
# Independently reproduce the unchanged FoundryCatalog basis path rules, without Godot.
src=(R/'scripts/generation/foundry_catalog.gd').read_text();initial=src.split('var files: Array[String] = ',1)[1].split('\n',1)[0];files=set(re.findall(r'"(res://[^"]+)"',initial));files.add('res://config/platforming_foundry.json')
cat=json.loads((R/'config/platforming_foundry.json').read_text())
for t in cat['templates']:
 for v in t['variants']:
  for id in v:files.add(f'res://resources/generation/modules/{id}.tres')
segment=src.split('files.sort()',1)[1].split('for directory: String in',1)[0];files.update(re.findall(r'files.append\("(res://[^"]+)"\)',segment))
for directory in ['scripts/player','scripts/combat','scripts/input','scripts/generation']:
 files.update('res://'+p.relative_to(R).as_posix() for p in (R/directory).glob('*.gd'))
for directory in ['scripts/damage','scripts/resources','scripts/run','scripts/enemies','resources/player','resources/weapons','resources/enemies']:
 files.update('res://'+p.relative_to(R).as_posix() for p in (R/directory).rglob('*') if p.is_file() and p.suffix in ['.gd','.tres'])
computed=sha(('\n'.join([batch['engine']]+[p+':'+sha((R/p.removeprefix('res://')).read_bytes()) for p in sorted(files)])).encode());assert computed==batch['basis'],computed
profiles={};totalframes=0;identicalframes=0
for item in batch['accepted']:
 assert item['replay']['ok'] and item['replay']['max_position_error']==0 and item['ticks']==item['replay']['ticks']>0 and item['repair_attempt']==0
 m=item['manifest'];profiles[m['capability_profile']]=profiles.get(m['capability_profile'],0)+1
for proof in batch['connection_proofs']:assert proof['ok'] and proof['replay']['ok'] and proof['replay']['max_position_error']==0 and proof['replay']['ticks']>0
for m in [i['manifest'] for i in batch['accepted']]+batch['itineraries']:
 n=f'resources/foundry/replays/{m["id"]}.json';d=json.loads((R/n).read_text());assert d['basis']==batch['basis'] and d['manifest_hash']==m['hash'] and d['frames'] and d['capability_profile']==m['capability_profile'];totalframes+=len(d['frames'])
 old=json.loads(z.read(n));identicalframes+=old['frames']==d['frames']
# Compare unchanged forest source bytes to exact already-proven closure, not a whole-new-source test claim.
out={'scope':'independent read-only refresh record and byte-delta review; no engine','exit_code':r['exit_code'],'changed_paths_count':len(changes),'only_foundry_development_JSON':True,'before_matches_proven_library_runtime_inventory':True,'all_other_3652_runtime_paths_unchanged':len(a)-len(changes),'original_tools_and_basis_guard_equal_baseline':True,'old_zip_members_verified':len(idx),'independently_recomputed_basis':computed,'basis_files':len(files),'phrase_profiles':profiles,'accepted':36,'continuous_itineraries':18,'positive_replays':54,'replay_total_frames':totalframes,'identical_old_new_replay_frame_payloads':identicalframes,'production_pool':False,'design_status':'awaiting_playtest'}
Path('/tmp/forest-v18-foundry-refresh05-review.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
