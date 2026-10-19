from pathlib import Path
import json,hashlib,subprocess,datetime,os
b=Path(__file__).resolve().parent;r=json.loads((b/'cleanup-receipt.json').read_text());plan=json.loads((b/'approved-plan.json').read_text());assert r['status']=='completed' and r['deleted_count']==164;assert {x['original_build_path'] for x in r['deleted']}=={x['build_path'] for x in plan['candidates']};seen=set()
for x in plan['candidates']:
 assert not Path(x['build_path']).exists() and Path(x['build_path']).parent.is_dir();a=x['alternative'];p=Path(a['committed_path'])
 if str(p) not in seen:
  assert not p.is_symlink() and p.stat().st_nlink==1;h=hashlib.sha256();gh=hashlib.sha1();gh.update(('blob '+str(p.stat().st_size)+'\0').encode())
  with p.open('rb') as f:
   for data in iter(lambda:f.read(1048576),b''):h.update(data);gh.update(data)
  assert (h.hexdigest(),gh.hexdigest(),p.stat().st_size)==(a['file_sha256'],a['git_blob_oid'],a['file_bytes']);subprocess.check_call(['git','cat-file','-e',a['git_blob_oid']]);seen.add(str(p))
v={'scope':'Post-cleanup originals absent only at 164 approved duplicate paths; retained parent dirs; all distinct committed alternatives remain exact SHA256/Git blob and nlink1, Git blobs present. Per-item complete ZIP-member/source equality and no-FD evidence referenced from durable executed cleanup receipt; not redundantly decompressed again. No restoration or engine/browser run.','observed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'passed','approved_path_count':164,'distinct_retained_doc_alternatives':len(seen),'receipt_sha256':hashlib.sha256((b/'cleanup-receipt.json').read_bytes()).hexdigest(),'observed_statvfs_before_bytes':r['statvfs_available_bytes_before_cleanup'],'observed_statvfs_after_bytes':r['statvfs_available_bytes_after_cleanup'],'observed_overall_statvfs_delta_bytes':r['observed_overall_statvfs_delta_bytes'],'observed_sum_item_statvfs_delta_bytes':r['observed_sum_item_statvfs_delta_bytes'],'physical_measurement_limit':'Observed actual available-space windows can include concurrent writes; logical st_blocks quantities were not substituted for physical delta.'}
p=b/'verification.json'
with p.open('w') as f:json.dump(v,f,indent=2);f.write('\n');f.flush();os.fsync(f.fileno())
print(json.dumps(v,indent=2))
