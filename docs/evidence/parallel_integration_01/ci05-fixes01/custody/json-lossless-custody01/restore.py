from pathlib import Path
import sys,json,zipfile,hashlib,os
r=json.loads(Path(__file__).with_name('receipt.json').read_text());row=next(x for x in r['files'] if x['original_path']==sys.argv[1]);p=Path(row['original_path']);assert not p.exists();tmp=p.with_name(p.name+'.restore.tmp');assert not tmp.exists();h=hashlib.sha256();n=0
with zipfile.ZipFile(row['archive_path']) as z,z.open(row['member']) as src,tmp.open('xb') as dst:
 for b in iter(lambda:src.read(1048576),b''):dst.write(b);h.update(b);n+=len(b)
 dst.flush();os.fsync(dst.fileno())
assert (h.hexdigest(),n)==(row['original_sha256'],row['original_bytes']);assert not p.exists();os.rename(tmp,p);print('Restored exact original',p,h.hexdigest(),n)
