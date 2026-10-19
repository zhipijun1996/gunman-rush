from pathlib import Path
import json,hashlib,lzma,datetime,os
base=Path(__file__).resolve().parent;root=base.parents[2];r=json.loads((base/'receipt.json').read_text());assert r['status']=='completed_target_reached' and r['net_allocated_bytes_released']>=250000000
verified=[]
def digest(p):
 h=hashlib.sha256();n=0
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b);n+=len(b)
 return h.hexdigest(),n
for x in r['migrations']:
 p=root/x['original_path'];xz=root/x['compressed_path'];assert not p.exists() and p.parent.is_dir() and xz.stat().st_nlink==1 and not xz.is_symlink();assert digest(xz)==(x['compressed_sha256'],x['compressed_bytes']);assert digest(root/x['source_receipt'])[0]==x['source_receipt_sha256'];h=hashlib.sha256();n=0
 with lzma.open(xz,'rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b);n+=len(b)
 assert (h.hexdigest(),n)==(x['original_sha256'],x['original_bytes']);verified.append({'original_path_requires_exact_restore':x['original_path'],'actual_retained_xz_path':x['compressed_path'],'original_sha256':h.hexdigest(),'original_bytes':n,'compressed_sha256':x['compressed_sha256'],'compressed_bytes':x['compressed_bytes'],'full_decompression_verified':True,'original_producer_receipt_unchanged':True})
v={'scope':'Post-migration full stream lossless storage verification only; no engine/browser/gameplay run and no restoration executed','verified_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'command':'nice -n 19 python3 build/integration01/storage05/verify_avi.py','status':'passed','file_count':len(verified),'net_allocated_bytes_released':r['net_allocated_bytes_released'],'files':verified}
p=base/'verification.json'
with p.open('w') as f:json.dump(v,f,indent=2);f.write('\n');f.flush();os.fsync(f.fileno())
print(json.dumps({k:v[k] for k in ('status','file_count','net_allocated_bytes_released')},indent=2))
