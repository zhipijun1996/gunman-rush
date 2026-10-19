from pathlib import Path
import hashlib,json,zipfile,os,time
root=Path('/tmp/gunman-forest-feedback-godot-cache');cache=root/'imported';out=Path('build/integration01/cache-custody04')
assert Path('.godot').is_symlink() and Path('.godot').resolve()==root and not cache.is_symlink()
def no_users():
 for p in Path('/proc').iterdir():
  if not p.name.isdigit():continue
  try:
   cmd=(p/'cmdline').read_bytes().split(b'\0');name=Path(os.fsdecode(cmd[0])).name.lower() if cmd and cmd[0]else''
   assert not name.startswith('godot'),f'live engine {p.name}'
   for fd in (p/'fd').iterdir():
    try:assert not os.readlink(fd).startswith(str(cache)+'/'),f'cache active FD {p.name}'
    except FileNotFoundError:pass
  except (FileNotFoundError,PermissionError,ProcessLookupError):pass
no_users();files=sorted(p for p in cache.rglob('*')if p.is_file());assert files and not any(p.is_symlink() for p in files)
rows=[{'path':str(p.relative_to(root)),'bytes':p.stat().st_size,'sha256':hashlib.file_digest(p.open('rb'),'sha256').hexdigest(),'nlink':p.stat().st_nlink}for p in files]
z=out/'imported-cache.zip'
with zipfile.ZipFile(z,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=1) as a:
 for row in rows:a.write(root/row['path'],row['path'])
with z.open('rb') as f:os.fsync(f.fileno())
with zipfile.ZipFile(z) as a:
 assert a.testzip() is None and set(a.namelist())=={r['path']for r in rows}
 for row in rows:
  with a.open(row['path']) as f:assert hashlib.file_digest(f,'sha256').hexdigest()==row['sha256']
receipt={'scope':'Lossless custody of generated current imported editor cache after native/GL work finished. Source, UID/script metadata, movie/original test evidence untouched. ZIP kept build-local; Git receipts alone do not contain cache bytes. Restore exact ZIP before future native no-import use, or regenerate with Godot editor import.','root':str(root),'zip':str(z),'zip_bytes':z.stat().st_size,'zip_sha256':hashlib.file_digest(z.open('rb'),'sha256').hexdigest(),'source_bytes':sum(r['bytes']for r in rows),'rows':rows,'verified_before_unlink':True,'timestamp':time.time()}
p=out/'receipt.json';p.write_text(json.dumps(receipt,indent=2)+'\n')
with p.open('rb') as f:os.fsync(f.fileno())
no_users()
for row in rows:
 f=root/row['path'];assert f.stat().st_size==row['bytes'] and hashlib.file_digest(f.open('rb'),'sha256').hexdigest()==row['sha256']
for row in rows:(root/row['path']).unlink()
receipt['removed_count']=len(rows);p.write_text(json.dumps(receipt,indent=2)+'\n')
print('verified cache custody',len(rows),'source',receipt['source_bytes'],'zip',receipt['zip_bytes'],'net',receipt['source_bytes']-receipt['zip_bytes'])
