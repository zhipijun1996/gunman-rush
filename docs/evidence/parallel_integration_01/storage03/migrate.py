from pathlib import Path
import os,json,hashlib,zipfile,datetime,stat
BASE=Path('build/integration01/cache-custody03');REPORT=Path('build/integration01/cache-candidates03/generated-doc-cache-report.json');SCOPE=Path('build/integration01/cache-candidates03/eligible-generated-doc-cache-paths.txt');CURRENT=Path('/tmp/gunman-forest-feedback-godot-cache').resolve();ROOT=Path.cwd()
def sha(p):
 h=hashlib.sha256();n=0
 with Path(p).open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b);n+=len(b)
 return h.hexdigest(),n
def durable_json(p,value):
 temp=p.with_name(p.name+'.tmp')
 with temp.open('w') as f:json.dump(value,f,indent=2);f.write('\n');f.flush();os.fsync(f.fileno())
 os.replace(temp,p);fd=os.open(p.parent,os.O_RDONLY);os.fsync(fd);os.close(fd)
report=json.loads(REPORT.read_text());rows=[r for r in report['candidates'] if r['eligible_as_inactive_single_file_cache_candidate']];paths=[r['path'] for r in rows];assert len(rows)==195 and len(set(paths))==195;assert SCOPE.read_text().splitlines()==paths
assert sha(SCOPE)[0]=='59334bf3dd3e473cdf84a55606820d518d05b4d87f1aad879e194120d7dca176'
receipt={'scope':'Exact authorized 195-file old generated Godot documentation cache custody migration; preserve original bytes in content-addressed ZIP, no hardlinks or other deletions','command':'nice -n 19 python3 build/integration01/cache-custody03/migrate.py','started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'preflight','source_report':str(REPORT),'source_report_sha256':sha(REPORT)[0],'scope_list':str(SCOPE),'scope_list_sha256':sha(SCOPE)[0],'current_shared_cache_excluded':str(CURRENT),'original_file_count':195,'old_dedup_inventory_paths_transferred':sum(r['in_prior_dedup_inventory'] for r in rows),'prior_inventory_scope_note':'149 exact paths previously listed in integration-exact-dedup.json are transferred to this lossless archive custody. That previous inventory and its verification remain historical point-in-time observations; they are not rewritten or claimed to represent current file presence.','unlinked':[]}
def save():durable_json(BASE/'receipt.json',receipt)
save()
def process_guard():
 projects={str(Path(r['associated_snapshot_project'])) for r in rows};absolute_paths={str((ROOT/p).resolve()) for p in paths};issues=[]
 for proc in Path('/proc').iterdir():
  if not proc.name.isdigit() or int(proc.name)==os.getpid():continue
  try:
   state=(proc/'stat').read_text().split(') ',1)[1].split()[0]
   if state=='Z':continue
   cwd=str((proc/'cwd').resolve());argv=[a.decode(errors='replace') for a in (proc/'cmdline').read_bytes().split(bytes([0])) if a];cwdrefs=[p for p in projects if cwd==p or cwd.startswith(p+'/')];cmdrefs=[a for a in argv if any(a==p or a.startswith(p+'/') for p in projects)];fdrefs=[]
   for fd in (proc/'fd').iterdir():
    try:
     target=str(fd.resolve())
     if target in absolute_paths:fdrefs.append({'fd':fd.name,'path':target})
    except OSError:pass
   if cwdrefs or cmdrefs or fdrefs:issues.append({'pid':proc.name,'cwd':cwd,'argv':argv,'project_cwd_references':cwdrefs,'command_references':cmdrefs,'target_open_handles':fdrefs})
  except OSError:pass
 return issues
try:
 issues=process_guard();receipt['initial_active_references']=issues;save();assert not issues,'A cache/snapshot acquired an active reference; stop all deletion'
 signatures={};mapping=[]
 for r in rows:
  p=Path(r['path']);assert p.name=='editor_doc_cache-4.7.res' and str(p).startswith('build/forest_depth/snapshots/') and '/artifacts/' not in str(p);assert not p.is_symlink();real=p.resolve();assert real!=CURRENT and not real.is_relative_to(CURRENT);st=p.stat();assert stat.S_ISREG(st.st_mode) and st.st_nlink==1;assert sha(p)==(r['sha256'],r['bytes']);signatures[str(p)]=(st.st_dev,st.st_ino,st.st_size,st.st_mtime_ns,st.st_nlink)
  mapping.append({'original_path':str(p),'absolute_original_path':str(p.absolute()),'blob':'sha256/'+r['sha256']+'.bin','sha256':r['sha256'],'bytes':r['bytes'],'allocated_bytes_before':st.st_blocks*512,'original_nlink':st.st_nlink,'original_mode':stat.S_IMODE(st.st_mode),'original_mtime_ns':st.st_mtime_ns,'original_inode':st.st_ino,'associated_snapshot_project':r['associated_snapshot_project'],'in_prior_dedup_inventory':r['in_prior_dedup_inventory']})
 blob_source={m['sha256']:m for m in mapping};archive=BASE/'generated-doc-cache-original-bytes01.zip';assert not archive.exists()
 with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for h,m in blob_source.items():z.write(m['original_path'],m['blob'])
 with archive.open('rb') as f:os.fsync(f.fileno())
 verified=[]
 with zipfile.ZipFile(archive) as z:
  assert len(z.namelist())==len(blob_source) and z.testzip() is None
  for h,m in blob_source.items():
   digest=hashlib.sha256();n=0
   with z.open(m['blob']) as f:
    for b in iter(lambda:f.read(1048576),b''):digest.update(b);n+=len(b)
   assert (digest.hexdigest(),n)==(h,m['bytes']);verified.append({'blob':m['blob'],'sha256':h,'bytes':n,'full_decompression_verified':True,'crc_verified':True})
 mapdoc={'schema_version':1,'archive':str(archive),'archive_sha256':sha(archive)[0],'archive_bytes':archive.stat().st_size,'original_paths':mapping,'blobs':verified,'original_file_count':195,'distinct_blob_count':len(blob_source)};durable_json(BASE/'path-blob-map.json',mapdoc)
 receipt.update(status='archive_verified_all_originals_retained',archive=str(archive),archive_sha256=mapdoc['archive_sha256'],archive_bytes=mapdoc['archive_bytes'],path_blob_map=str(BASE/'path-blob-map.json'),path_blob_map_sha256=sha(BASE/'path-blob-map.json')[0],distinct_blob_count=len(blob_source),full_decompression_and_crc_passed=True,original_logical_bytes=sum(m['bytes'] for m in mapping),original_allocated_bytes=sum(m['allocated_bytes_before'] for m in mapping));save()
 # Global all-or-nothing gate before the first unlink: every original must still match and be inactive.
 for m in mapping:
  p=Path(m['original_path']);st=p.stat();assert not p.is_symlink() and (st.st_dev,st.st_ino,st.st_size,st.st_mtime_ns,st.st_nlink)==signatures[str(p)];assert sha(p)==(m['sha256'],m['bytes'])
 issues=process_guard();receipt['final_active_references']=issues;assert not issues,'A cache/snapshot became active; stop all deletion'
 assert Path('/workspace/gunman-rush-design/.godot').resolve()==CURRENT and CURRENT.is_dir();receipt['all_originals_reverified_before_first_unlink']=True;receipt['status']='all_verified_receipt_durable_before_first_unlink';save()
 fs=os.statvfs(ROOT);receipt['filesystem_available_bytes_immediately_before_unlink']=fs.f_bavail*fs.f_frsize;save()
 for m in mapping:
  p=Path(m['original_path']);st=p.stat();assert not p.is_symlink() and (st.st_dev,st.st_ino,st.st_size,st.st_mtime_ns,st.st_nlink)==signatures[str(p)];p.unlink();receipt['unlinked'].append(m['original_path'])
  # Preserve progress receipt after each exact authorized unlink; never delete containing directories.
  save()
 fs=os.statvfs(ROOT);receipt['filesystem_available_bytes_immediately_after_unlink']=fs.f_bavail*fs.f_frsize;receipt['filesystem_available_bytes_delta_unlink_window']=receipt['filesystem_available_bytes_immediately_after_unlink']-receipt['filesystem_available_bytes_immediately_before_unlink'];assert all(not Path(p).exists() for p in paths);assert CURRENT.is_dir() and Path('.godot').resolve()==CURRENT
 receipt.update(status='completed',finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),unlinked_file_count=len(receipt['unlinked']),gross_allocated_bytes_released=receipt['original_allocated_bytes'],net_allocated_bytes_released_less_archive=receipt['original_allocated_bytes']-archive.stat().st_blocks*512,current_shared_cache_unchanged_binding=True,restoration_command=['python3',str(BASE/'restore.py'),'--all']);save();print(json.dumps({k:v for k,v in receipt.items() if k!='unlinked'},indent=2))
except Exception as exc:
 receipt['status']='paused_error';receipt['error']=repr(exc);save();raise
