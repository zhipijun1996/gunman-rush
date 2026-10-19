from pathlib import Path
import argparse,json,hashlib,os,zipfile
base=Path(__file__).resolve().parent;parser=argparse.ArgumentParser();parser.add_argument('original_path',nargs='?');parser.add_argument('--all',action='store_true');args=parser.parse_args();assert bool(args.all)!=bool(args.original_path),'Choose one exact original path or --all'
def sha(p):
 h=hashlib.sha256();n=0
 with Path(p).open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b);n+=len(b)
 return h.hexdigest(),n
r=json.loads((base/'receipt.json').read_text());mp=base/'path-blob-map.json';assert sha(mp)[0]==r['path_blob_map_sha256'];m=json.loads(mp.read_text());archive=Path(m['archive']);assert sha(archive)==(m['archive_sha256'],m['archive_bytes']);chosen=m['original_paths'] if args.all else [x for x in m['original_paths'] if x['original_path']==args.original_path];assert chosen,'Path not in authorized exact original map'
with zipfile.ZipFile(archive) as z:
 for x in chosen:
  p=Path(x['absolute_original_path']);assert str(p).startswith('/workspace/gunman-rush-design/build/forest_depth/snapshots/');assert p.name=='editor_doc_cache-4.7.res' and p.parent.is_dir()
  if p.exists():assert not p.is_symlink() and sha(p)==(x['sha256'],x['bytes']);print('Already exact',p);continue
  tmp=p.with_name(p.name+'.cache-custody03.restore.tmp');assert not tmp.exists();h=hashlib.sha256();n=0
  with z.open(x['blob']) as src,tmp.open('xb') as dst:
   for b in iter(lambda:src.read(1048576),b''):dst.write(b);h.update(b);n+=len(b)
   dst.flush();os.fsync(dst.fileno())
  assert (h.hexdigest(),n)==(x['sha256'],x['bytes']);os.chmod(tmp,x['original_mode']);os.utime(tmp,ns=(x['original_mtime_ns'],x['original_mtime_ns']));assert not p.exists();os.rename(tmp,p);fd=os.open(p.parent,os.O_RDONLY);os.fsync(fd);os.close(fd);assert p.stat().st_nlink==1;print('Restored exact independent file',p,h.hexdigest(),n)
print('Complete; lossless archive retained')
