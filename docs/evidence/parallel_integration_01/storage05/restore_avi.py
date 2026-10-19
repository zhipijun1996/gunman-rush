from pathlib import Path
import json,hashlib,lzma,os,argparse
base=Path(__file__).resolve().parent;root=base.parents[2];a=argparse.ArgumentParser();a.add_argument('original_path');args=a.parse_args();r=json.loads((base/'receipt.json').read_text());row=next(x for x in r['migrations'] if x['original_path']==args.original_path);p=root/row['original_path'];xz=root/row['compressed_path'];assert not p.exists() and p.parent.is_dir();h=hashlib.sha256()
with xz.open('rb') as f:
 for b in iter(lambda:f.read(1048576),b''):h.update(b)
assert h.hexdigest()==row['compressed_sha256'] and xz.stat().st_size==row['compressed_bytes'];tmp=p.with_name(p.name+'.storage05.restore.tmp');assert not tmp.exists();h=hashlib.sha256();n=0
with lzma.open(xz,'rb') as src,tmp.open('xb') as dst:
 for b in iter(lambda:src.read(1048576),b''):dst.write(b);h.update(b);n+=len(b)
 dst.flush();os.fsync(dst.fileno())
assert (h.hexdigest(),n)==(row['original_sha256'],row['original_bytes']);os.chmod(tmp,row['original_mode']);os.utime(tmp,ns=(row['original_mtime_ns'],row['original_mtime_ns']));assert not p.exists();os.rename(tmp,p);fd=os.open(p.parent,os.O_RDONLY);os.fsync(fd);os.close(fd);assert p.stat().st_nlink==1;print('Exact original restored; adjacent XZ retained',p,h.hexdigest(),n)
