"""Exact immutable build-mirror storage deduplication, never runtime/source edits."""
from pathlib import Path
import os,hashlib,json,time
R=Path('/workspace/gunman-rush');O=Path('/workspace/plains-redesign-baseline');B=R/'build/plains_redesign';P=B/'frozen_mirror_storage.json';assert not P.exists()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
S=Path('build/plains_redesign/controlled_comparison/before');files=sorted((O/S).rglob('capture.json'));assert len(files)==80
rows=[]
for old in files:
 rel=old.relative_to(O);current=R/rel;assert old.is_file() and current.is_file() and not old.is_symlink() and not current.is_symlink()
 a,b=old.stat(),current.stat();assert a.st_dev==b.st_dev and a.st_size==b.st_size
 v=sha(old);assert v==sha(current)
 rows.append({'old_path':str(old),'identical_root_mirror':str(current),'sha256':v,'bytes':a.st_size,'old_inode':a.st_ino,'root_inode':b.st_ino,'already_same_inode':a.st_ino==b.st_ino})
d={'scope':'Only80 completed immutable OLD workspace raw captures and their verified byte-exact ROOT mirror. Physical storage deduplication; both original paths/raw bytes/receipts remain. No engine/source/assets/tests/log/media changes. Never overwrite these frozen evidence paths.','status':'preflight_verified','started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'members':rows};P.write_text(json.dumps(d,indent=2)+'\n')
for row in rows:
 old=Path(row['old_path']);current=Path(row['identical_root_mirror'])
 if row['already_same_inode']:continue
 temp=old.with_name(old.name+'.verified_duplicate.tmp');assert not temp.exists();os.link(current,temp);assert temp.stat().st_ino==current.stat().st_ino;os.replace(temp,old);assert old.stat().st_ino==current.stat().st_ino and sha(old)==row['sha256']
d.update(status='exact_bytes_both_paths_retained',finished_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),reclaimed_duplicate_bytes=sum(x['bytes'] for x in rows if not x['already_same_inode']));P.write_text(json.dumps(d,indent=2)+'\n');print('Byte-exact80 frozen raw mirrors retained at both paths; physical duplicate bytes reclaimed',d['reclaimed_duplicate_bytes'])
