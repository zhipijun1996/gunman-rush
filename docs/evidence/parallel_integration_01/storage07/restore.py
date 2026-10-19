from pathlib import Path
import argparse,json,hashlib,zipfile,os,subprocess,io,shutil
base=Path(__file__).resolve().parent;root=base.parents[2];a=argparse.ArgumentParser();a.add_argument('original_build_path');args=a.parse_args();plan=json.loads((base/'approved-plan.json').read_text());row=next(x for x in plan['candidates'] if x['build_path']==args.original_build_path);p=root/row['build_path'];assert not p.exists() and p.parent.is_dir();alt=row['alternative'];assert subprocess.check_output(['git','-C',str(root),'rev-parse',alt['commit']+':'+alt['committed_path']],text=True).strip()==alt['git_blob_oid'];source=root/alt['committed_path'];data=None
# Exact Git blob fallback keeps recovery valid if later docs edits change the working copy.
if source.is_file():
 h=hashlib.sha256()
 with source.open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 if h.hexdigest()!=alt['file_sha256'] or source.stat().st_size!=alt['file_bytes']:source=None
else:source=None
if source is None:
 data=subprocess.check_output(['git','-C',str(root),'cat-file','blob',alt['git_blob_oid']]);assert hashlib.sha256(data).hexdigest()==alt['file_sha256'] and len(data)==alt['file_bytes']
tmp=p.with_name(p.name+'.upper-duplicate07.restore.tmp');assert not tmp.exists();h=hashlib.sha256();n=0
if alt['kind']=='direct_committed_file':src=source.open('rb') if source else io.BytesIO(data);archive=None
else:archive=zipfile.ZipFile(source if source else io.BytesIO(data));src=archive.open(alt['member'])
try:
 with src,tmp.open('xb') as dst:
  for b in iter(lambda:src.read(1048576),b''):dst.write(b);h.update(b);n+=len(b)
  dst.flush();os.fsync(dst.fileno())
finally:
 if archive:archive.close()
assert (h.hexdigest(),n)==(row['sha256'],row['bytes']);assert not p.exists();os.rename(tmp,p);fd=os.open(p.parent,os.O_RDONLY);os.fsync(fd);os.close(fd);assert p.stat().st_nlink==1;print('Restored exact independent build file',p,h.hexdigest(),n)
