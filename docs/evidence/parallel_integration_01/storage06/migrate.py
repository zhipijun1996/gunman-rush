from pathlib import Path
import json,os,hashlib,lzma,datetime,time
BASE=Path('build/integration01/custody06');ROOT=Path('/tmp/gunman-forest-feedback-runtime');NAMES=[('movies01-map1','00-map1-fast'),('movies03-map2-fast','00-map2-fast'),('movies02-map2','00-map2-growth')]
def digest(p):
 h=hashlib.sha256();n=0
 with Path(p).open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b);n+=len(b)
 return h.hexdigest(),n
def durable(p,obj):
 tmp=p.with_name(p.name+'.tmp')
 with tmp.open('w') as f:json.dump(obj,f,indent=2);f.write('\n');f.flush();os.fsync(f.fileno())
 os.replace(tmp,p);fd=os.open(p.parent,os.O_RDONLY);os.fsync(fd);os.close(fd)
r={'scope':'Lossless custody migration of exactly three authorized old runtime AVI byte streams, including one original producer timeout failure. No source/frames/gameplay acceptance and no re-encoding.','status':'preflight','started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'resource_coordination':'aim_save_migration confirmed hook browser released first, then native probe02 exit0 and engine released; no further engine/browser work by that agent. Root notified before compression.','command':'nice -n 19 python3 build/integration01/custody06/migrate.py','method':'Single-threaded Python lzma FORMAT_XZ preset1, 1MiB streaming; equivalent xz -T1 -1 --stdout ORIGINAL > ORIGINAL.xz','candidates':[],'migrations':[],'net_allocated_bytes_released':0}
def save():durable(BASE/'receipt.json',r)
def guard(p=None,all_media=False):
 issues=[];st=p.stat() if p else None
 for proc in Path('/proc').iterdir():
  if not proc.name.isdigit() or int(proc.name)==os.getpid():continue
  try:
   if (proc/'stat').read_text().split(') ',1)[1].split()[0]=='Z':continue
   comm=(proc/'comm').read_text().strip();argv=[a.decode(errors='replace') for a in (proc/'cmdline').read_bytes().split(bytes([0])) if a];cwd=(proc/'cwd').resolve();matches=[]
   for fd in (proc/'fd').iterdir():
    try:
     fst=fd.stat()
     if st and (fst.st_dev,fst.st_ino)==(st.st_dev,st.st_ino):matches.append({'fd':fd.name,'target':os.readlink(fd)})
    except OSError:pass
   related=cwd.is_relative_to(ROOT) or any(a==str(ROOT) or a.startswith(str(ROOT)+'/') for a in argv)
   active_media=all_media and comm.lower().startswith(('godot','chromium','chrome','ffmpeg'))
   if matches or related or active_media:issues.append({'pid':proc.name,'comm':comm,'cwd':str(cwd),'argv':argv,'target_open_handles':matches})
  except OSError:pass
 return issues
try:
 r['global_media_preflight']=guard(all_media=True);save();assert not r['global_media_preflight'],'Active engine/browser/media or old-runtime dependency; stop without mutation'
 for name,case in NAMES:
  p=ROOT/'build/forest_feedback'/name/case/'gameplay.avi';rp=p.parents[1]/'receipt.json';old=json.loads(rp.read_text());run=old['runs'][0];m=run.get('movie',{});actual,n=digest(p);assert p.is_file() and not p.is_symlink() and p.stat().st_nlink==1 and not Path(str(p)+'.xz').exists();assert not guard(p);st=p.stat();provided='sha256' in m and 'bytes' in m
  if provided:assert (actual,n)==(m['sha256'],m['bytes'])
  else:assert old['status']=='failed' and run['status']=='timeout'
  r['candidates'].append({'original_path':str(p),'original_sha256':actual,'original_bytes':n,'original_allocated_bytes':st.st_blocks*512,'original_inode':st.st_ino,'original_nlink':st.st_nlink,'original_mode':st.st_mode&0o7777,'original_mtime_ns':st.st_mtime_ns,'source_receipt':str(rp),'source_receipt_sha256':digest(rp)[0],'producer_recorded_status':old['status'],'producer_run_status':run['status'],'producer_run_exit_code':run.get('exit_code'),'producer_provided_movie_sha_and_size':provided,'original_sha_binding_basis':'Complete actual AVI matches the existing terminal PASS producer movie SHA/size' if provided else 'Original producer timed out and supplied no movie SHA/size; baseline SHA/size first measured from the complete existing failed raw file for this lossless custody migration only','source_head_as_recorded':old.get('source_head'),'frames_as_recorded':m.get('frames'),'seconds_as_recorded':m.get('seconds'),'full_successful_movie_claim':provided and old['status']=='passed' and run['status']=='passed'})
 save()
 for candidate in r['candidates']:
  row=dict(candidate);p=Path(row['original_path']);xz=Path(str(p)+'.xz');assert not guard(p,all_media=True);assert digest(p)==(row['original_sha256'],row['original_bytes']);assert p.stat().st_nlink==1;start=time.monotonic()
  with p.open('rb') as src,lzma.open(xz,'xb',format=lzma.FORMAT_XZ,preset=1) as dst:
   for b in iter(lambda:src.read(1048576),b''):dst.write(b)
  with xz.open('rb') as f:os.fsync(f.fileno())
  h=hashlib.sha256();n=0
  with lzma.open(xz,'rb') as f:
   for b in iter(lambda:f.read(1048576),b''):h.update(b);n+=len(b)
  assert (h.hexdigest(),n)==(row['original_sha256'],row['original_bytes']);xzsha,xn=digest(xz);row.update(compressed_path=str(xz),compressed_sha256=xzsha,compressed_bytes=xn,compressed_allocated_bytes=xz.stat().st_blocks*512,full_decompression_sha256=h.hexdigest(),full_decompression_bytes=n,full_decompression_matched=True,elapsed_seconds=time.monotonic()-start,net_allocated_bytes_saved=row['original_allocated_bytes']-xz.stat().st_blocks*512,status='verified_compressed_original_retained',restore_command=['python3','build/integration01/custody06/restore.py',str(p)])
  r['migrations'].append(row);r['status']='verified_receipt_durable_before_unlink';save();assert row['net_allocated_bytes_saved']>0;assert not guard(p);assert p.stat().st_nlink==1 and digest(p)==(row['original_sha256'],row['original_bytes']);assert digest(row['source_receipt'])[0]==row['source_receipt_sha256'];p.unlink();row['status']='complete_original_bytes_retained_in_adjacent_xz_old_raw_path_requires_exact_restore';row['unlinked_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();r['net_allocated_bytes_released']+=row['net_allocated_bytes_saved'];save();print(p,'net saved',row['net_allocated_bytes_saved'],'cumulative',r['net_allocated_bytes_released'],flush=True)
 r.update(status='completed_storage_migration_not_gameplay_acceptance',finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),original_AVI_count=3,original_PASS_producers=2,original_failed_timeout_producers=1);save();print('FINAL NET',r['net_allocated_bytes_released'],flush=True)
except Exception as exc:r.update(status='paused_error',error=repr(exc));save();raise
