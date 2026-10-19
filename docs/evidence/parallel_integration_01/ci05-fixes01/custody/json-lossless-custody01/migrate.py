from pathlib import Path
import json,zipfile,hashlib,os,datetime
base=Path('build/integration01/json-lossless-custody01')
items=[('build/integration01/ci05-scene-diagnosis01/positive.json','build/integration01/ci05-scene-diagnosis01.archive.json','positive.json','build/integration01/ci05-scene-diagnosis01/process.json'),('build/plains_redesign/scene/run_oc2p8d_z/positive.json','build/integration01/ci05-scene-migration01.archive.json','original_run/positive.json','build/integration01/ci05-scene-migration01/wrapper.process.json')]
def digeststream(f):
 h=hashlib.sha256();n=0
 for b in iter(lambda:f.read(1048576),b''):h.update(b);n+=len(b)
 return h.hexdigest(),n
def digest(p):
 with Path(p).open('rb') as f:return digeststream(f)
rec={'scope':'Authorized lossless storage migration of only two new diagnostic JSON working copies; no new gameplay validation','started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'preflight','files':[]}
def save():
 p=base/'receipt.json.tmp'
 with p.open('w') as f:json.dump(rec,f,indent=2);f.write('\n');f.flush();os.fsync(f.fileno())
 os.replace(p,base/'receipt.json');fd=os.open(base,os.O_RDONLY);os.fsync(fd);os.close(fd)
ids={(Path(x[0]).stat().st_dev,Path(x[0]).stat().st_ino) for x in items};holders=[];engines=[];zombies=[]
for proc in Path('/proc').iterdir():
 if not proc.name.isdigit():continue
 try:
  comm=(proc/'comm').read_text().strip();state=next(s for s in (proc/'status').read_text().splitlines() if s.startswith('State:'))
  if comm.lower().startswith(('godot','ffmpeg')):(zombies if 'Z (zombie)' in state else engines).append({'pid':proc.name,'comm':comm,'state':state,'cmdline':(proc/'cmdline').read_bytes().replace(bytes([0]),b' ').decode(errors='replace')})
  for fd in (proc/'fd').iterdir():
   try:
    st=fd.stat()
    if (st.st_dev,st.st_ino) in ids:holders.append({'pid':proc.name,'fd':fd.name,'target':os.readlink(fd)})
   except OSError:pass
 except OSError:pass
rec['preflight']={'active_engines':engines,'open_target_handles':holders,'defunct_nonwriters':zombies};save();assert not holders;assert not any(any(x[0] in e['cmdline'] or x[3] in e['cmdline'] for x in items) for e in engines)
for path,receipt,member,process in items:
 p=Path(path);ar=json.loads(Path(receipt).read_text());pr=json.loads(Path(process).read_text());assert pr['process']['status']=='passed' and pr['process']['exit_code']==0 and pr['process']['ended_at_unix'] is not None
 zpath=Path(ar['archive']);zsha,zn=digest(zpath);assert (zsha,zn)==(ar['archive_sha256'],ar['archive_bytes']);expected=next(m for m in ar['members'] if m['path']==member);osha,on=digest(p);assert (osha,on)==(expected['sha256'],expected['bytes']);assert p.stat().st_nlink==1 and not p.is_symlink()
 with zipfile.ZipFile(zpath) as z:
  with z.open(member) as f:sha,n=digeststream(f)
 assert (sha,n)==(osha,on)
 row={'original_path':path,'original_sha256':osha,'original_bytes':on,'original_nlink':p.stat().st_nlink,'original_inode':p.stat().st_ino,'archive_path':str(zpath),'archive_sha256':zsha,'archive_bytes':zn,'archive_receipt':receipt,'archive_receipt_sha256':digest(receipt)[0],'member':member,'decompressed_member_sha256':sha,'decompressed_member_bytes':n,'full_stream_roundtrip':True,'producer_process_receipt':process,'producer_process_receipt_sha256':digest(process)[0],'producer_terminal_status':pr['process']['status'],'producer_exit_code':pr['process']['exit_code'],'migration_command':'python3 build/integration01/json-lossless-custody01/migrate.py','restore_command':['python3','build/integration01/json-lossless-custody01/restore.py',path],'status':'verified_original_retained'}
 rec['files'].append(row);save()
 assert digest(p)==(osha,on) and p.stat().st_nlink==1;p.unlink();row['status']='uncompressed_working_copy_unlinked_exact_bytes_retained_in_original_zip';row['unlinked_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();save()
rec['status']='completed';rec['logical_bytes_released']=sum(x['original_bytes'] for x in rec['files']);rec['finished_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();save();print(json.dumps(rec,indent=2))
