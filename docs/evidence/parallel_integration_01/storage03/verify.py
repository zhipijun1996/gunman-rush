from pathlib import Path
import json,zipfile,hashlib,datetime,os
base=Path(__file__).resolve().parent;r=json.loads((base/'receipt.json').read_text());raw=(base/'path-blob-map.json').read_bytes();assert hashlib.sha256(raw).hexdigest()==r['path_blob_map_sha256'];m=json.loads(raw);assert r['status']=='completed';zpath=Path(m['archive']);h=hashlib.sha256()
with zpath.open('rb') as f:
 for b in iter(lambda:f.read(1048576),b''):h.update(b)
assert h.hexdigest()==m['archive_sha256'] and zpath.stat().st_size==m['archive_bytes'];verified={}
with zipfile.ZipFile(zpath) as z:
 assert len(z.namelist())==55 and z.testzip() is None
 for blob in m['blobs']:
  h=hashlib.sha256();n=0
  with z.open(blob['blob']) as f:
   for b in iter(lambda:f.read(1048576),b''):h.update(b);n+=len(b)
  assert (h.hexdigest(),n)==(blob['sha256'],blob['bytes']);verified[blob['blob']]=(h.hexdigest(),n)
for row in m['original_paths']:
 assert verified[row['blob']]==(row['sha256'],row['bytes']);p=Path(row['absolute_original_path']);assert not p.exists() and p.parent.is_dir();assert Path(row['associated_snapshot_project']).is_dir()
assert len(m['original_paths'])==195 and len(r['unlinked'])==195 and set(r['unlinked'])=={x['original_path'] for x in m['original_paths']};assert Path('/workspace/gunman-rush-design/.godot').resolve()==Path(r['current_shared_cache_excluded']) and Path(r['current_shared_cache_excluded']).is_dir()
v={'scope':'Post-migration independent read-only verification; full ZIP CRC/decompression and SHA/size, complete path map, absence only of authorized originals, retained parent project directories, current shared cache binding. No original file restored or another gameplay run claimed.','command':'nice -n 19 python3 build/integration01/cache-custody03/verify.py','status':'passed','verified_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'zip':str(zpath),'zip_sha256':m['archive_sha256'],'distinct_blob_count':len(verified),'original_path_count':len(m['original_paths']),'original_paths_all_recoverable_from_verified_blobs':True,'all_parent_directories_retained':True,'shared_current_cache_binding_unchanged':True,'prior_dedup_paths_transferred':sum(x['in_prior_dedup_inventory'] for x in m['original_paths'])}
p=base/'verification.json'
with p.open('w') as f:json.dump(v,f,indent=2);f.write('\n');f.flush();os.fsync(f.fileno())
print(json.dumps(v,indent=2))
