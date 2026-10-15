"""Root evidence packaging helper; never edits source or rewrites original receipts."""
from pathlib import Path
import gzip,hashlib,json,shutil

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def pack_files(items,destination):
 destination=Path(destination);destination.mkdir(parents=True,exist_ok=True);members=[]
 for source,relative in items:
  source=Path(source);relative=Path(relative)
  if relative.is_absolute() or '..' in relative.parts:raise ValueError('unsafe relative evidence path')
  raw=source.read_bytes();target=destination/relative
  compress=target.suffix in {'.json','.jsonl','.log','.txt'}
  if compress:target=target.with_name(target.name+'.gz')
  if target.exists():raise ValueError('retain existing evidence; choose a new output')
  target.parent.mkdir(parents=True,exist_ok=True)
  if compress:target.write_bytes(gzip.compress(raw,compresslevel=9,mtime=0))
  else:shutil.copy2(source,target)
  recovered=gzip.decompress(target.read_bytes()) if compress else target.read_bytes()
  if recovered!=raw:raise ValueError('packaging changed original evidence')
  members.append({'source':str(source),'stored':str(target.relative_to(destination)),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'stored_sha256':digest(target),'compression':'gzip' if compress else 'none'})
 return members
