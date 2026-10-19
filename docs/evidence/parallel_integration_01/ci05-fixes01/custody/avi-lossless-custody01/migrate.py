from pathlib import Path
import json,os,hashlib,lzma,time,datetime
BASE=Path('build/integration01/avi-lossless-custody01');receipt={'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'method':'Python lzma FORMAT_XZ preset=6, one compression thread, streaming 1MiB blocks; no media re-encoding','status':'running','files':[]}
paths=[Path('build/integration01')/f'movie-{prefix}{name}'/f'00-{name}'/'gameplay.avi' for prefix in ('','final-') for name in ('map1-growth','map2-fast')]
def digest(p):
 h=hashlib.sha256();n=0
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b);n+=len(b)
 return h.hexdigest(),n
def save():
 t=BASE/'receipt.json.tmp';t.write_text(json.dumps(receipt,indent=2)+'\n');os.replace(t,BASE/'receipt.json')
# Prove no active engine and no process holds any target file open.
target_inodes={(p.stat().st_dev,p.stat().st_ino) for p in paths};holders=[];engines=[];zombie_engines=[]
for proc in Path('/proc').iterdir():
 if not proc.name.isdigit():continue
 try:
  comm=(proc/'comm').read_text().strip()
  if comm.lower().startswith(('godot','ffmpeg')):
   state=next(x for x in (proc/'status').read_text().splitlines() if x.startswith('State:'))
   (zombie_engines if 'Z (zombie)' in state else engines).append({'pid':proc.name,'comm':comm,'state':state})
  for fd in (proc/'fd').iterdir():
   try:
    st=fd.stat()
    if (st.st_dev,st.st_ino) in target_inodes:holders.append({'pid':proc.name,'fd':fd.name,'target':os.readlink(fd)})
   except (OSError,PermissionError):pass
 except (OSError,PermissionError):pass
receipt['preflight']={'active_engines':engines,'target_open_handles':holders,'defunct_nonwriters':zombie_engines};save();print(receipt['preflight'],flush=True);assert not holders and not engines
for p in paths:
 rp=p.parents[1]/'receipt.json';r=json.loads(rp.read_text());m=r['runs'][0]['movie'];sha,n=digest(p);st=p.stat();assert sha==m['sha256'] and n==m['bytes'];assert st.st_nlink==1 and p.is_file() and not p.is_symlink()
 row={'original_path':str(p),'original_sha256':sha,'original_bytes':n,'original_inode':st.st_ino,'original_nlink':st.st_nlink,'original_mode':oct(st.st_mode),'source_receipt':str(rp),'source_receipt_sha256':digest(rp)[0],'source_head':r['source_head'],'source_stable':r['source_stable'],'expected_sha256_matched':True,'expected_bytes_matched':True,'compression_command':'python3 build/integration01/avi-lossless-custody01/migrate.py','compression_equivalent':'xz --threads=1 --format=xz -6 --stdout ORIGINAL > ORIGINAL.xz','compressed_path':str(p)+'.xz','status':'preflight_verified'}
 receipt['files'].append(row)
save()
for row in receipt['files']:
 p=Path(row['original_path']);xz=Path(row['compressed_path']);assert not xz.exists();start=time.monotonic()
 with p.open('rb') as src,lzma.open(xz,'xb',format=lzma.FORMAT_XZ,preset=6) as dst:
  for block in iter(lambda:src.read(1048576),b''):dst.write(block)
 with xz.open('rb') as f:os.fsync(f.fileno())
 h=hashlib.sha256();n=0
 with lzma.open(xz,'rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b);n+=len(b)
 row.update(compressed_sha256=digest(xz)[0],compressed_bytes=xz.stat().st_size,decompressed_sha256=h.hexdigest(),decompressed_bytes=n,elapsed_seconds=time.monotonic()-start)
 assert h.hexdigest()==row['original_sha256'] and n==row['original_bytes'];row['verified_full_decompression']=True;row['logical_bytes_saved']=n-xz.stat().st_size;row['status']='verified_compressed_original_retained';save()
 if row['logical_bytes_saved']<45000000:
  receipt['status']='stopped_insufficient_compression_no_original_unlinked';save();raise SystemExit('Insufficient compression; original retained')
 # Receipt of successful complete decompression is durable before unlinking only the authorized working AVI.
 assert digest(p)==(row['original_sha256'],row['original_bytes']);assert p.stat().st_nlink==1;p.unlink();row['status']='migrated_original_exact_bytes_in_xz';row['original_unlinked_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();save();print(str(p),row['logical_bytes_saved'],flush=True)
receipt['status']='completed';receipt['logical_bytes_saved']=sum(x['logical_bytes_saved'] for x in receipt['files']);receipt['finished_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();save();print('TOTAL',receipt['logical_bytes_saved'],flush=True)
