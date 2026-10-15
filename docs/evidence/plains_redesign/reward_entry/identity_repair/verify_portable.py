from pathlib import Path
import gzip,hashlib,io,json,sys,tarfile
ROOT=Path.cwd();BASE=ROOT/'docs/evidence/plains_redesign/reward_entry';F=ROOT/'build/plains_redesign/reward_entry/identity_repair';sys.path.insert(0,str(ROOT/'tools'));import level_formal as f
sha=lambda b:hashlib.sha256(b).hexdigest();index=json.loads((BASE/'index.json').read_text());old=json.loads((F/'rejected_r1/index.json').read_text());assert index['members'][:594]==old['members'];paths=[]
for m in index['members']:
 b=(ROOT/m['portable']).read_bytes();assert sha(b)==m['portable_sha256'],m['portable'];raw=gzip.decompress(b) if m['compression']=='gzip' else b;assert sha(raw)==m['source_sha256'] and len(raw)==m['source_bytes'],m['portable'];paths.append(m['portable'])
assert len(set(paths))==len(paths)
snapshot=json.loads((ROOT/index['source']).read_text());archive=ROOT/index['source_archive'];assert sha(archive.read_bytes())==snapshot['archive_sha256'];assert snapshot['archive_path']==index['source_archive']
with tarfile.open(archive) as tar:
 files={m.name:sha(tar.extractfile(m).read()) for m in tar.getmembers() if m.isfile()}
assert files==snapshot['members'];assert all(sha((ROOT/p).read_bytes())==h for p,h in files.items())
old_members=json.loads((F/'rejected_r1/sources/source_snapshot.json').read_text())['members'];delta=[p for p in set(files)|set(old_members) if files.get(p)!=old_members.get(p)];assert delta==['tools/run_plains_encounter_policy_tests.py']
assert f.source_files()==json.loads((F/'source_before.json').read_text())['formal_runtime']
result=dict(status='passed',members=len(paths),preserved_original_members=594,source_members=len(files),changed_source_vs_rejected22=delta,formal_runtime_count=len(f.source_files()),formal_runtime_unchanged=True,core_unchanged=all(snapshot['unchanged_core_invariants'].values()),asset_blob_checks_unchanged=all(snapshot['shared_assets_from_frozen_v9']['exact_git_blob_checks'].values()))
(F/'portable_verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps(result,ensure_ascii=False))
