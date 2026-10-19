from pathlib import Path
import json,hashlib,lzma,os,datetime,time
BASE=Path('build/integration01/storage05');TARGET=250000000
NAMES=[('movie_map2_growth01','00-map2-growth'),('movie_final_map1_growth02','00-map1-growth'),('movie_final_map2_fast02','00-map2-fast'),('movie_map1_fast01','00-map1-fast')]
def digest(p):
 h=hashlib.sha256();n=0
 with Path(p).open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b);n+=len(b)
 return h.hexdigest(),n
def durable(p,obj):
 tmp=p.with_name(p.name+'.tmp')
 with tmp.open('w') as f:json.dump(obj,f,indent=2);f.write('\n');f.flush();os.fsync(f.fileno())
 os.replace(tmp,p);fd=os.open(p.parent,os.O_RDONLY);os.fsync(fd);os.close(fd)
r={'scope':'Exact reversible lossless storage migration of old native AVI working files; original complete bytes in adjacent XZ; no transcoding, no new source/frames/gameplay proof','started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'command':'nice -n 19 python3 build/integration01/storage05/migrate_avi.py','compression':'Python lzma XZ preset=1, one compression thread, 1MiB streaming; equivalent xz -T1 -1 --stdout ORIGINAL > ORIGINAL.xz','target_net_allocated_bytes':TARGET,'status':'preflight','candidates':[],'migrations':[],'net_allocated_bytes_released':0}
def save():durable(BASE/'receipt.json',r)
def guard(p):
 target=p.absolute();project=p.parents[1].absolute();st=p.stat();issues=[]
 for proc in Path('/proc').iterdir():
  if not proc.name.isdigit() or int(proc.name)==os.getpid():continue
  try:
   if (proc/'stat').read_text().split(') ',1)[1].split()[0]=='Z':continue
   cwd=(proc/'cwd').resolve();argv=[x.decode(errors='replace') for x in (proc/'cmdline').read_bytes().split(bytes([0])) if x];matches=[]
   for fd in (proc/'fd').iterdir():
    try:
     fst=fd.stat()
     if (fst.st_dev,fst.st_ino)==(st.st_dev,st.st_ino):matches.append({'fd':fd.name,'path':os.readlink(fd)})
    except OSError:pass
   if cwd.is_relative_to(project) or any(a==str(project) or a.startswith(str(project)+'/') for a in argv) or matches:issues.append({'pid':proc.name,'cwd':str(cwd),'argv':argv,'target_fds':matches})
  except OSError:pass
 return issues
try:
 for name,case in NAMES:
  p=Path('build/forest_grapple02')/name/case/'gameplay.avi';receipt=p.parents[1]/'receipt.json';old=json.loads(receipt.read_text());m=old['runs'][0]['movie'];assert p.is_file() and not p.is_symlink() and p.stat().st_nlink==1 and not Path(str(p)+'.xz').exists();assert digest(p)==(m['sha256'],m['bytes']);issues=guard(p);assert not issues
  r['candidates'].append({'original_path':str(p),'original_sha256':m['sha256'],'original_bytes':m['bytes'],'original_allocated_bytes':p.stat().st_blocks*512,'original_inode':p.stat().st_ino,'original_nlink':p.stat().st_nlink,'original_mode':p.stat().st_mode & 0o7777,'original_mtime_ns':p.stat().st_mtime_ns,'source_receipt':str(receipt),'source_receipt_sha256':digest(receipt)[0],'source_head_as_recorded_in_existing_receipt':old.get('source_head'),'original_frames_as_recorded_in_existing_receipt':m.get('frames'),'original_seconds_as_recorded_in_existing_receipt':m.get('seconds'),'initial_active_references':issues})
 save()
 for candidate in r['candidates']:
  if r['net_allocated_bytes_released']>=TARGET:break
  row=dict(candidate);p=Path(row['original_path']);xz=Path(str(p)+'.xz');start=time.monotonic();assert not guard(p);assert digest(p)==(row['original_sha256'],row['original_bytes']);assert p.stat().st_nlink==1
  with p.open('rb') as src,lzma.open(xz,'xb',format=lzma.FORMAT_XZ,preset=1) as dst:
   for b in iter(lambda:src.read(1048576),b''):dst.write(b)
  with xz.open('rb') as f:os.fsync(f.fileno())
  h=hashlib.sha256();n=0
  with lzma.open(xz,'rb') as src:
   for b in iter(lambda:src.read(1048576),b''):h.update(b);n+=len(b)
  assert (h.hexdigest(),n)==(row['original_sha256'],row['original_bytes']);xsha,xbytes=digest(xz);row.update(compressed_path=str(xz),compressed_sha256=xsha,compressed_bytes=xbytes,compressed_allocated_bytes=xz.stat().st_blocks*512,full_decompression_sha256=h.hexdigest(),full_decompression_bytes=n,full_decompression_matched=True,elapsed_seconds=time.monotonic()-start,net_allocated_bytes_saved=row['original_allocated_bytes']-xz.stat().st_blocks*512,status='verified_compressed_original_retained',restore_command=['python3',str(BASE/'restore_avi.py'),str(p)])
  r['migrations'].append(row);r['status']='verified_receipt_durable_before_unlink';save()
  assert row['net_allocated_bytes_saved']>0;assert not guard(p);assert p.stat().st_nlink==1 and digest(p)==(row['original_sha256'],row['original_bytes']);assert digest(row['source_receipt'])[0]==row['source_receipt_sha256'];p.unlink();row['original_unlinked_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();row['status']='original_bytes_retained_in_adjacent_xz_original_raw_path_requires_restore';r['net_allocated_bytes_released']+=row['net_allocated_bytes_saved'];save();print(p,'saved',row['net_allocated_bytes_saved'],'cumulative',r['net_allocated_bytes_released'],flush=True)
 r['status']='completed_target_reached' if r['net_allocated_bytes_released']>=TARGET else 'completed_authorized_candidates_target_not_reached';r['finished_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();r['unused_candidate_paths_remain_unchanged']=[x['original_path'] for x in r['candidates'] if x['original_path'] not in {y['original_path'] for y in r['migrations']}];save();print('FINAL',r['status'],r['net_allocated_bytes_released'],flush=True)
except Exception as exc:
 r['status']='paused_error';r['error']=repr(exc);save();raise
