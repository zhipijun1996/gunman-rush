from pathlib import Path
import json,os,hashlib,subprocess,zipfile,datetime,collections
OUT=Path('build/integration01/upper-duplicates-readonly07');ROOT=Path.cwd();COMMIT=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip();tree=subprocess.check_output(['git','ls-tree','-r','--format=%(objectname) %(path)',COMMIT,'docs/evidence/parallel_integration_01'],text=True).splitlines();alternatives=collections.defaultdict(list);verified_docs=[]
for line in tree:
 oid,s=line.split(' ',1);p=Path(s)
 if not p.is_file():continue
 st=p.stat();h=hashlib.sha256();gh=hashlib.sha1();gh.update(('blob '+str(st.st_size)+'\0').encode())
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b);gh.update(b)
 assert gh.hexdigest()==oid,'Working doc differs from exact committed blob';d={'committed_path':s,'commit':COMMIT,'git_blob_oid':oid,'file_sha256':h.hexdigest(),'file_bytes':st.st_size};verified_docs.append(d)
 if st.st_size>=65536:alternatives[(st.st_size,h.hexdigest())].append(dict(d,kind='direct_committed_file'))
 if p.suffix=='.zip':
  with zipfile.ZipFile(p) as z:
   for info in z.infolist():
    if info.is_dir() or info.file_size<65536:continue
    mh=hashlib.sha256();n=0
    with z.open(info.filename) as src:
     for b in iter(lambda:src.read(1048576),b''):mh.update(b);n+=len(b)
    assert n==info.file_size;alternatives[(n,mh.hexdigest())].append(dict(d,kind='exact_member_in_committed_zip',member=info.filename,member_sha256=mh.hexdigest(),member_bytes=n))
# Read only this task's build outputs; skip every active CI7/browser probe and all unique custody archives.
excluded_prefixes=('ci07','ci-artifact-browser07','candidate7','local-gui07','style-lab-browser07','touch-scroll-diagnosis07','fan_','hook-','custody','cache-','storage','upper-','worktree-cache','avi-lossless','json-lossless')
sizes={k[0] for k in alternatives};candidates=[];size_matches=0
for dp,ds,fs in os.walk('build/integration01',followlinks=False):
 rel=Path(dp).relative_to('build/integration01')
 if rel==Path('.'):
  ds[:]=[d for d in ds if not d.startswith(excluded_prefixes)]
 ds[:]=[d for d in ds if d!='.git']
 for name in fs:
  p=Path(dp)/name
  if p.is_symlink():continue
  st=p.stat()
  if st.st_size not in sizes or st.st_nlink!=1:continue
  size_matches+=1;h=hashlib.sha256()
  with p.open('rb') as f:
   for b in iter(lambda:f.read(1048576),b''):h.update(b)
  a=alternatives.get((st.st_size,h.hexdigest()))
  if not a:continue
  candidates.append({'build_path':str(p),'sha256':h.hexdigest(),'bytes':st.st_size,'logical_allocated_bytes':st.st_blocks*512,'nlink':st.st_nlink,'inode':st.st_ino,'mtime_ns':st.st_mtime_ns,'alternative':sorted(a,key=lambda x:(x['kind']!='direct_committed_file',len(x['committed_path'])))[0],'physical_upper_layer_origin':'Created during current integration task according to path/task provenance; not established from st_blocks alone. Actual statvfs delta must be measured if separately authorized for cleanup.','restore_command':['python3',str(OUT/'restore.py'),str(p)],'live_recheck_required':True})
candidates.sort(key=lambda x:x['bytes'],reverse=True);byfolder=collections.Counter()
for x in candidates:byfolder[Path(x['build_path']).parts[2] if len(Path(x['build_path']).parts)>3 else '(top-level)']+=x['logical_allocated_bytes']
report={'scope':'Read-only exact duplicate plan, no deletion/compression/engine/browser. Only files >=64KiB with nlink1 and exact same bytes as a committed docs file or fully decompressed member of a committed ZIP. CI7 extraction, current probes, unique WebZIPs and unique custody archives excluded. No physical reclaimed-byte claim.','created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'committed_head':COMMIT,'verified_committed_doc_file_count':len(verified_docs),'candidate_count':len(candidates),'candidate_logical_allocated_bytes':sum(x['logical_allocated_bytes'] for x in candidates),'actual_physical_bytes_reclaimable':None,'physical_reclaim_requires_measured_statvfs':True,'folder_logical_allocated_bytes':dict(byfolder),'candidates':candidates,'excluded_prefixes':excluded_prefixes,'no_cleanup_executed':True}
(OUT/'plan.json').write_text(json.dumps(report,indent=2)+'\n');(OUT/'committed-doc-proofs.json').write_text(json.dumps(verified_docs,indent=2)+'\n');print('candidates',len(candidates),'logical',report['candidate_logical_allocated_bytes']);print(json.dumps(dict(byfolder),indent=2));print('SIZE candidates hashed',size_matches)
