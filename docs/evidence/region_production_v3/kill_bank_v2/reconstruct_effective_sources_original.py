"""Resolve exact original native inventory via original Git base plus preserved dirty bytes.
Never mutate captures, receipts, source_commit fields or game source.
"""
from pathlib import Path
import hashlib,json,subprocess,datetime
ROOT=Path(__file__).resolve().parents[3]
CASE_ROOT=ROOT/'build/region_production_v3/kill_bank_v2'
OUT=ROOT/'docs/evidence/region_production_v3/kill_bank_v2/effective_sources'
OUT.mkdir(parents=True,exist_ok=False)
labels=['before_deep_v1','before_fast_v1','after_deep_v2','after_fast_v1']
receipts={}
for label in labels:
 p=next((CASE_ROOT/label).rglob('capture.invocation.json'))
 receipts[label]=(p,json.loads(p.read_text()))
commits={d['source_commit'] for _,d in receipts.values()}
trees={}
objects=set()
for commit in commits:
 tree={}
 for line in subprocess.check_output(['git','ls-tree','-r',commit],cwd=ROOT).decode().splitlines():
  meta,path=line.split('\t',1);mode,kind,oid=meta.split()
  if kind=='blob':tree[path]=oid
 trees[commit]=tree
 for _,d in receipts.values():
  if d['source_commit']==commit:objects.update(tree[n] for n in d['source_before'] if n in tree)
ids=sorted(objects)
proc=subprocess.Popen(['git','cat-file','--batch'],cwd=ROOT,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
raw,err=proc.communicate(('\n'.join(ids)+'\n').encode(),timeout=60)
assert proc.returncode==0,err.decode()
blobs={};offset=0
for oid in ids:
 end=raw.index(b'\n',offset);header=raw[offset:end].decode().split();assert header[:2]==[oid,'blob'],header
 size=int(header[2]);offset=end+1;body=raw[offset:offset+size];offset+=size;assert raw[offset:offset+1]==b'\n';offset+=1
 blobs[oid]=body
assert offset==len(raw)
blob_hashes={oid:hashlib.sha256(value).hexdigest() for oid,value in blobs.items()}
case_reports=[];overlay={}
for label,(receipt_path,d) in receipts.items():
 assert d['status']=='accepted' and d['source_before']==d['source_after']
 commit=d['source_commit'];tree=trees[commit];inventory=d['source_before'];bindings=[];missing=[]
 for name,expected in sorted(inventory.items()):
  oid=tree.get(name);base_hash=blob_hashes.get(oid)
  if base_hash==expected:
   body=blobs[oid];binding={'path':name,'sha256':expected,'basis':'original_git_blob','git_blob':oid}
  else:
   candidates=[ROOT/name,CASE_ROOT/'before'/Path(name).name,CASE_ROOT/'candidate_source'/Path(name).name]
   match=next((p for p in candidates if p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest()==expected),None)
   if match is None:missing.append({'path':name,'expected':expected,'base_sha256':base_hash});continue
   body=match.read_bytes();dest=OUT/'dirty_blobs'/expected;dest.parent.mkdir(exist_ok=True)
   if dest.exists():assert dest.read_bytes()==body
   else:dest.write_bytes(body)
   binding={'path':name,'sha256':expected,'basis':'preserved_dirty_overlay','overlay_blob':str(dest.relative_to(OUT)),'retrieved_from':str(match.relative_to(ROOT)),'base_git_blob':oid,'base_sha256':base_hash}
   overlay[expected]={'sha256':expected,'size':len(body),'paths':sorted(set(overlay.get(expected,{}).get('paths',[])+[name]))}
  assert hashlib.sha256(body).hexdigest()==expected
  bindings.append(binding)
 actual={x['path']:x['sha256'] for x in bindings}
 assert not missing,('Cannot reconstruct original effective source',label,missing)
 assert actual==inventory
 projection=json.dumps(inventory,sort_keys=True,separators=(',',':')).encode()
 report={'case':label,'original_source_commit_field_unchanged':commit,'original_receipt':str(receipt_path.relative_to(ROOT)),'original_receipt_sha256':hashlib.sha256(receipt_path.read_bytes()).hexdigest(),'inventory_projection_format':'UTF-8 JSON sorted keys separators comma/colon, no newline','inventory_projection_sha256':hashlib.sha256(projection).hexdigest(),'source_count':len(inventory),'base_blob_count':sum(x['basis']=='original_git_blob' for x in bindings),'dirty_overlay_count':sum(x['basis']=='preserved_dirty_overlay' for x in bindings),'all_sources_reconstructed_sha256_equal':True,'bindings':bindings,'scope':'Original producer source_files projection only, not all repository/PNG/GPU files. Git source_commit is a real base plus exact dirty overlay, NOT clean Git reconstruction.'}
 (OUT/(label+'.json')).write_text(json.dumps(report,indent=2)+'\n');case_reports.append({k:v for k,v in report.items() if k!='bindings'})
summary={'created_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'Exact original four native source_files inventories reconstructed as original Git base plus preserved dirty overlay. Original capture/receipt bytes/source_commit remain unchanged. Not a new native execution.','cases':case_reports,'unique_dirty_blobs':list(overlay.values()),'unique_dirty_blob_count':len(overlay),'unique_dirty_bytes':sum(x['size'] for x in overlay.values())}
(OUT/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k!='unique_dirty_blobs'},indent=2))
