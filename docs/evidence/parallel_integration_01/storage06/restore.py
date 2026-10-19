from pathlib import Path
import json,lzma,hashlib,os,argparse
base=Path(__file__).resolve().parent;a=argparse.ArgumentParser();a.add_argument('original_path');args=a.parse_args();r=json.loads((base/'receipt.json').read_text());x=next(x for x in r['migrations'] if x['original_path']==args.original_path);p=Path(x['original_path']);z=Path(x['compressed_path']);assert p.is_absolute() and str(p).startswith('/tmp/gunman-forest-feedback-runtime/build/forest_feedback/');assert p.name=='gameplay.avi' and not p.exists() and p.parent.is_dir();h=hashlib.sha256()
with z.open('rb') as f:
 for b in iter(lambda:f.read(1048576),b''):h.update(b)
assert h.hexdigest()==x['compressed_sha256'] and z.stat().st_size==x['compressed_bytes'];tmp=p.with_name(p.name+'.custody06.restore.tmp');assert not tmp.exists();h=hashlib.sha256();n=0
with lzma.open(z,'rb') as src,tmp.open('xb') as dst:
 for b in iter(lambda:src.read(1048576),b''):dst.write(b);h.update(b);n+=len(b)
 dst.flush();os.fsync(dst.fileno())
assert (h.hexdigest(),n)==(x['original_sha256'],x['original_bytes']);os.chmod(tmp,x['original_mode']);os.utime(tmp,ns=(x['original_mtime_ns'],x['original_mtime_ns']));assert not p.exists();os.rename(tmp,p);fd=os.open(p.parent,os.O_RDONLY);os.fsync(fd);os.close(fd);assert p.stat().st_nlink==1;print('Exact original restored; original producer status remains',x['producer_recorded_status'],x['producer_run_status'],'XZ retained',p,h.hexdigest(),n)
