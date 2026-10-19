"""Read-only evidence inventory; archive only with explicit --pack-after-review.
No source restoration, engine, Git mutation, or asset copying.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess,stat,zlib,tarfile,shutil
ROOT=Path('/workspace/gunman-rush-design')
OUT=ROOT/'build/forest_depth/independent/crossbranch01-06-custody'
NAMES=['crossbranch_physics01','crossbranch_view02','crossbranch_view03','crossbranch_purpose04','crossbranch_controls05','crossbranch_controls06']
S='9fdf7fad08550ea0da46b59ef7126fa721571f28'
def sha(data):return hashlib.sha256(data).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def verify_bytes(data,spec):
 assert len(data)==spec['bytes'] and sha(data)==spec['sha256'],'Exact SHA/size mismatch'
def verify_payload(payload):
 for name,v in payload.items():verify_bytes(regular(ROOT/v['source_path']).read_bytes(),v)
def regular(path):
 assert path.is_file() and not path.is_symlink(),str(path)
 assert path.resolve().is_relative_to(ROOT),str(path)
 for p in path.parents:
  if p==ROOT:break
  assert not p.is_symlink(),str(p)
 return path

def plan():
 OUT.mkdir(parents=True,exist_ok=True)
 assert git('rev-parse',S+'^{commit}').decode().strip()==S
 reachable=subprocess.run(['git','merge-base','--is-ancestor',S,'HEAD'],cwd=ROOT).returncode==0
 assert reachable,'Exact S not reachable from current HEAD'
 tree={}
 for row in git('ls-tree','-r','-z',S).split(b'\0'):
  if row:
   meta,path=row.split(b'\t',1);mode,kind,oid=meta.decode().split();tree[path.decode()]={'mode':mode,'type':kind,'oid':oid}
 payload={};projects=[];excluded_movies=[];hash_cache={};binary_git_cache={};binary_refs={};source_raw=0
 def add(arc,path):
  regular(path);data=path.read_bytes();v={'source_path':str(path.relative_to(ROOT)),'sha256':sha(data),'bytes':len(data),'mode':stat.S_IMODE(path.stat().st_mode)}
  if arc in payload:
   assert payload[arc]["sha256"]==v["sha256"] and payload[arc]["bytes"]==v["bytes"],arc
  else:payload[arc]=v
 for name in NAMES:
  snap=ROOT/'build/forest_depth/snapshots'/name;rpath=snap/'build/snapshot-receipt.json';r=json.loads(regular(rpath).read_text());sources={};different=[]
  add(f'contexts/{name}/snapshot-receipt.json',rpath)
  expected_inventory=dict(r['source_files']);native_bindings=[];observed={}
  for receipt_path in sorted((snap/'build/forest_depth/ecology').glob('*/receipt.json')):
   n=json.loads(regular(receipt_path).read_text())
   assert n.get('source_guard') is True and n['source_before']==n['source_after'],str(receipt_path)
   assert n['verifier_before']==n['verifier_after'],str(receipt_path)
   if 'verifier_guard' in n:assert n['verifier_guard'] is True,str(receipt_path)
   for key,sha256 in {**n['source_before'],**n['verifier_before']}.items():
    if key in observed:assert observed[key]==sha256,'Native cases used different source: '+key
    observed[key]=sha256
   native_bindings.append({'path':str(receipt_path.relative_to(ROOT)),'sha256':sha(receipt_path.read_bytes()),'original_has_explicit_verifier_guard':'verifier_guard' in n,'verifier_vectors_equal':n['verifier_before']==n['verifier_after']})
  assert native_bindings,'Actual post-overlay native inventory absent'
  assert set(observed)<=set(expected_inventory),'Review source inventory additions first'
  expected_inventory.update(observed)
  overlay_delta={key:{'copy_sha256':r['source_files'][key],'native_sha256':value}for key,value in observed.items()if value!=r['source_files'][key]}
  for rel,expected in sorted(expected_inventory.items()):
   p=regular(snap/rel);st=p.stat();key=(st.st_dev,st.st_ino,st.st_size,st.st_mtime_ns)
   if key not in hash_cache:
    b=p.read_bytes()
    try:b.decode('utf-8');text=b'\0' not in b
    except UnicodeDecodeError:text=False
    hash_cache[key]=(sha(b),text)
   actual,text=hash_cache[key];assert actual==expected, f'sealed drift {name}/{rel}'
   entry={'sha256':actual,'bytes':st.st_size,'mode':stat.S_IMODE(st.st_mode)}
   base=tree.get(rel);entry['exact_S_git_blob']=base['oid'] if base and base['type']=='blob' else None
   if text:
    arc='source_blobs/'+actual;entry['restore']='archive:'+arc
    add(arc,p)
   else:
    assert base and base['type']=='blob','Binary has no exact-S source: '+rel
    oid=base['oid']
    if oid not in binary_git_cache:binary_git_cache[oid]=sha(git('cat-file','blob',oid))
    assert binary_git_cache[oid]==actual,'Binary differs from S; no invented reuse: '+rel
    entry['restore']='git_binary_or_external_exact_sha'
    binary_refs[actual]={'path':rel,'git_commit':S,'git_blob':oid,'sha256':actual,'bytes':st.st_size,'mode':entry['mode']}
   if base:
    # Git blob ID is a strict content identity, not inferred from file suffix.
    blob_oid=hashlib.sha1(f'blob {st.st_size}\0'.encode()+p.read_bytes()).hexdigest()
    if blob_oid!=base['oid']:different.append(rel)
   else:different.append(rel)
   sources[rel]=entry
  projects.append({'name':name,'recorded_base_commit':r['base_commit'],'exact_reachable_binary_basis':S,'source_files':sources,'differences_from_S':different,'all_recorded_sources_verified':True,'initial_copy_receipt_is_not_post_overlay':bool(overlay_delta),'copy_to_native_overlay_delta':overlay_delta,'native_inventory_bindings':native_bindings})
  native=snap/'build/forest_depth/ecology'
  for p in native.rglob('*'):
   if p.is_file():
    if p.suffix.lower() in ['.avi','.mp4','.webm']:
     excluded_movies.append({'source_path':str(p.relative_to(ROOT)),'sha256':sha(p.read_bytes()),'bytes':p.stat().st_size,'reason':'Historical complete movie omitted, original remains build; package is NOT full-movie proof'})
    else:
     assert p.suffix in ['.json','.log','.png'], 'Review extra native member first: '+str(p)
     add('actual/'+name+'/'+str(p.relative_to(native)),p)
  for p in (snap/'build').iterdir():
   if p.is_file() and p.suffix=='.log':add('host/'+name+'/'+p.name,p)
 # Exact producer material/stills/mutation reports. Do not inspect or include07.
 host=ROOT/'build/forest_depth/ecology/f2-crossbranch01'
 for p in host.iterdir():
  if p.is_file() and p.name!='copy07.log':add('host/preparation/'+p.name,p)
 for folder_name in ['controls05-diagnosis','view02-frames','view03-frames','credit06-static']:
  folder=host/folder_name
  for p in folder.rglob('*'):
   if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc':add('host/preparation/'+str(p.relative_to(host)),p)
 review=ROOT/'build/forest_depth/independent/projectile-refund-review'
 for p in review.rglob('*'):
  if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc':add('independent_original/'+str(p.relative_to(review)),p)
 # Only cache rows that actually cover these terminal projects.
 storage=ROOT/'build/forest_depth/storage'
 for folder in sorted(storage.glob('cache-reclaim*')):
  matches=[p for p in folder.glob('*.json')if any(name in p.name for name in NAMES)]
  if matches:
   add('cache_custody/'+folder.name+'/receipt.json',folder/'receipt.json')
   for p in matches:add('cache_custody/'+folder.name+'/'+p.name,p)
 raw_bytes=sum(v['bytes']for v in payload.values());compressed_estimate=sum(len(zlib.compress((ROOT/v['source_path']).read_bytes(),6))for v in payload.values())
 report={'scope':'Exact six sealed crossbranch text closures, raw/failed stdout/stills/refund mutation and independent-review custody; no native replay, full AVI or design/current-region approval','S':S,'S_reachable_from_HEAD':reachable,'projects':projects,'excluded_movies_NOT_PACKAGED':excluded_movies,'binary_by_sha':binary_refs,'payload':payload,'estimates':{'payload_regular_files':len(payload),'payload_raw_bytes':raw_bytes,'individually_zlib_compressed_bytes_ESTIMATE_NOT_TAR':compressed_estimate,'excluded_unique_binary_bytes':sum(v['bytes']for v in binary_refs.values()),'unique_binary_refs':len(binary_refs),'free_bytes_now':shutil.disk_usage(OUT).free},'archive_created':False}
 p=OUT/'plan.json';p.write_text(json.dumps(report,indent=2)+'\n')
 summary={k:report[k]for k in ['S','S_reachable_from_HEAD','estimates','archive_created']};summary['projects']=[{'name':p['name'],'files':len(p['source_files']),'different_from_S':p['differences_from_S']}for p in projects];(OUT/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2));return report

def pack(report):
 assert report['S']==S and report['S_reachable_from_HEAD']
 assert report['estimates']['individually_zlib_compressed_bytes_ESTIMATE_NOT_TAR']<12*1024*1024
 assert report['estimates']['payload_raw_bytes']<64*1024*1024,'Stop: closure too large for reviewed minimal archive'
 assert shutil.disk_usage(OUT).free>report['estimates']['payload_raw_bytes']+128*1024*1024
 archive=OUT/'crossbranch01-06-selected.tar.gz';assert not archive.exists()
 payload=dict(report['payload'])
 for name in ['plan.json','summary.json','producer.py','PLAN.md','refund-and-status-ledger.json']:
  p=OUT/name
  if p.is_file():payload['custody/'+name]={'source_path':str(p.relative_to(ROOT)),'sha256':sha(p.read_bytes()),'bytes':p.stat().st_size,'mode':stat.S_IMODE(p.stat().st_mode)}
 assert sum(v['bytes']for v in payload.values())<64*1024*1024,'Final metadata-inclusive payload exceeds bound'
 verify_payload(payload)
 with tarfile.open(archive,'w:gz')as tar:
  for name,v in sorted(payload.items()):
   p=regular(ROOT/v['source_path']);assert p.stat().st_size==v['bytes'] and sha(p.read_bytes())==v['sha256'],name
   tar.add(p,arcname=name,recursive=False)
 assert archive.stat().st_size<=12*1024*1024,'Compressed archive exceeds approved12MiB: retain and report'
 seen=set()
 with tarfile.open(archive,'r|gz')as tar:
  for member in tar:
   assert member.isfile() and not member.issym() and not member.islnk() and member.name in payload and member.name not in seen,member.name
   verify_bytes(tar.extractfile(member).read(),payload[member.name]);seen.add(member.name)
 assert seen==set(payload)
 (OUT/'archive-receipt.json').write_text(json.dumps({'archive':str(archive.relative_to(ROOT)),'sha256':sha(archive.read_bytes()),'bytes':archive.stat().st_size,'members':len(payload),'every_member_verified':True,'scope':report['scope']},indent=2)+'\n')

if __name__=='__main__':
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--pack-after-review',action='store_true');a=ap.parse_args()
 r=json.loads((OUT/'plan.json').read_text()) if a.pack_after_review else plan()
 if a.pack_after_review:pack(r)
