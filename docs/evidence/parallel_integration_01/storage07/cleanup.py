from pathlib import Path
import json,hashlib,os,subprocess,zipfile,datetime,stat
BASE=Path('build/integration01/upper-duplicates-readonly07');PLAN=BASE/'approved-plan.json';praw=PLAN.read_bytes();assert hashlib.sha256(praw).hexdigest()=='7a9e2c86f0c78e2a5ae82919087a16f8c19e25e7414637857b83e3aabf41828d';plan=json.loads(praw);rows=plan['candidates'];assert len(rows)==164;assert len({x['build_path'] for x in rows})==164
r={'scope':'Root-approved exact 164 build duplicate files, recoverable from immutable committed docs or exact committed ZIP members; no compression/new archive/hardlink/source modification; no CI7 files touched','command':'nice -n 19 python3 build/integration01/upper-duplicates-readonly07/cleanup.py','started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'preflight_no_unlink','approved_plan':str(PLAN),'approved_plan_sha256':hashlib.sha256(praw).hexdigest(),'candidate_count':164,'logical_candidate_allocated_bytes':sum(x['logical_allocated_bytes'] for x in rows),'deleted':[],'physical_free_space_note':'Observed statvfs differences are actual filesystem available-byte measurements at their stated times. They may include concurrent work. Logical st_blocks sums are reported separately and never substituted for physical free-space deltas.'}
def digest(p):
 h=hashlib.sha256();n=0
 with Path(p).open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b);n+=len(b)
 return h.hexdigest(),n
def save():
 t=BASE/'cleanup-receipt.json.tmp'
 with t.open('w') as f:json.dump(r,f,indent=2);f.write('\n');f.flush();os.fsync(f.fileno())
 os.replace(t,BASE/'cleanup-receipt.json');fd=os.open(BASE,os.O_RDONLY);os.fsync(fd);os.close(fd)
def available():s=os.statvfs('.');return s.f_bavail*s.f_frsize
def source_check(x):
 p=Path(x['build_path']);assert str(p).startswith('build/integration01/') and not p.is_symlink();s=p.stat();assert stat.S_ISREG(s.st_mode) and s.st_nlink==1 and (s.st_ino,s.st_size,s.st_mtime_ns)==(x['inode'],x['bytes'],x['mtime_ns']);assert digest(p)==(x['sha256'],x['bytes']);return s
def source_fds(s):
 matches=[]
 for proc in Path('/proc').iterdir():
  if not proc.name.isdigit() or int(proc.name)==os.getpid():continue
  try:
   for fd in (proc/'fd').iterdir():
    try:
     fs=fd.stat()
     if (fs.st_dev,fs.st_ino)==(s.st_dev,s.st_ino):matches.append({'pid':proc.name,'fd':fd.name,'target':os.readlink(fd)})
    except OSError:pass
  except OSError:pass
 return matches
def alternative_check(x):
 a=x['alternative'];p=Path(a['committed_path']);assert str(p).startswith('docs/evidence/parallel_integration_01/');assert subprocess.check_output(['git','rev-parse',a['commit']+':'+str(p)],text=True).strip()==a['git_blob_oid'];st=p.stat();assert not p.is_symlink() and st.st_nlink==1,'Committed alternative shares links or changed type; do not risk mutable archive';gh=hashlib.sha1();gh.update(('blob '+str(st.st_size)+'\0').encode());h=hashlib.sha256();n=0
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):gh.update(b);h.update(b);n+=len(b)
 assert (gh.hexdigest(),h.hexdigest(),n)==(a['git_blob_oid'],a['file_sha256'],a['file_bytes'])
 if a['kind']=='direct_committed_file':assert (h.hexdigest(),n)==(x['sha256'],x['bytes'])
 else:
  with zipfile.ZipFile(p) as z:
   hh=hashlib.sha256();nn=0
   with z.open(a['member']) as f:
    for b in iter(lambda:f.read(1048576),b''):hh.update(b);nn+=len(b)
   assert (hh.hexdigest(),nn)==(x['sha256'],x['bytes'])
 return {'committed_path':str(p),'commit':a['commit'],'git_blob_oid':a['git_blob_oid'],'alternative_nlink':st.st_nlink,'member':a.get('member'),'kind':a['kind'],'full_target_bytes_verified':True}
try:
 r['manifest_files_sha256']={str(p):digest(p)[0] for p in [PLAN,BASE/'restore.py',BASE/'cleanup.py']}
 # All candidate original states must be valid before the first unlink.
 for x in rows:
  s=source_check(x);assert not source_fds(s),'Open build source FD; pause entire cleanup before any unlink'
 for p in [PLAN,BASE/'restore.py',BASE/'cleanup.py']:
  with p.open('rb') as f:os.fsync(f.fileno())
 r['status']='manifest_restorehelper_durable_before_any_unlink';save();r['statvfs_available_bytes_before_cleanup']=available();r['statvfs_before_recorded_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();save()
 for x in rows:
  s=source_check(x);proof=alternative_check(x);assert not source_fds(s),'Open build source FD at deletion gate; pause remaining cleanup';s2=Path(x['build_path']).stat();assert (s2.st_dev,s2.st_ino,s2.st_size,s2.st_mtime_ns,s2.st_nlink)==(s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns,1)
  # Durable item authorization and exact alternative verification precede unlink.
  item={'original_build_path':x['build_path'],'sha256':x['sha256'],'bytes':x['bytes'],'logical_allocated_bytes':x['logical_allocated_bytes'],'alternative':proof,'restore_command':x['restore_command'],'status':'verified_durable_original_retained'};r['pending_item']=item;r['status']='item_verified_durable_before_unlink';save();before=available();Path(x['build_path']).unlink();after=available();item.update(status='uncompressed_or_duplicate_build_file_removed_exact_committed_alternative_retained',statvfs_available_bytes_immediately_before_unlink=before,statvfs_available_bytes_immediately_after_unlink=after,observed_statvfs_item_delta_bytes=after-before,deleted_utc=datetime.datetime.now(datetime.timezone.utc).isoformat());r['deleted'].append(item);r.pop('pending_item');save()
 r.update(status='completed',finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),deleted_count=len(r['deleted']),statvfs_available_bytes_after_cleanup=available(),observed_sum_item_statvfs_delta_bytes=sum(x['observed_statvfs_item_delta_bytes'] for x in r['deleted']));r['observed_overall_statvfs_delta_bytes']=r['statvfs_available_bytes_after_cleanup']-r['statvfs_available_bytes_before_cleanup'];save();print(json.dumps({k:v for k,v in r.items() if k not in ['deleted','manifest_files_sha256']},indent=2))
except Exception as exc:r.update(status='paused_error',error=repr(exc),statvfs_available_bytes_at_error=available(),error_utc=datetime.datetime.now(datetime.timezone.utc).isoformat());save();print('PAUSED after',len(r['deleted']),'deletions',repr(exc),flush=True);raise
