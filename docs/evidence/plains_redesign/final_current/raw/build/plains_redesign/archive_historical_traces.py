"""Lossless reversible archival of superseded, load-confounded80, never primary160."""
from pathlib import Path
import json,gzip,hashlib,sys,time
R=Path('/workspace/gunman-rush');B=R/'build/plains_redesign/historical_raw_archive';M=B/'manifest.json';sha=lambda x:hashlib.sha256(x).hexdigest()
if '--restore' in sys.argv:
 d=json.loads(M.read_text())
 for row in d['members']:
  raw=gzip.decompress((R/row['stored']).read_bytes());assert sha(raw)==row['raw_sha256'];p=R/row['original']
  if p.exists():assert sha(p.read_bytes())==row['raw_sha256']
  else:p.write_bytes(raw)
 print('Restored original raw captures byte-exactly; gzip originals retained');raise SystemExit(0)
assert not B.exists();S=R/'build/plains_redesign/final_comparison/before';files=sorted(S.rglob('capture.json'));assert len(files)==80,len(files);B.mkdir()
d={'scope':'Only original superseded load-confounded aware80. All raw bytes retained losslessly with SHA; original batch/receipts/logs/source untouched. Primary controlled160 is a distinct directory and not touched. Restore before rerunning any legacy analysis referencing these raw paths.','restore_argv':['python3','build/plains_redesign/archive_historical_traces.py','--restore'],'status':'archiving','members':[],'started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())}
for p in files:
 raw=p.read_bytes();target=B/'raw'/p.relative_to(S);target=target.with_name(target.name+'.gz');target.parent.mkdir(parents=True,exist_ok=True);assert not target.exists();z=gzip.compress(raw,compresslevel=1,mtime=0);target.write_bytes(z);assert gzip.decompress(target.read_bytes())==raw
 row={'original':str(p.relative_to(R)),'stored':str(target.relative_to(R)),'raw_bytes':len(raw),'raw_sha256':sha(raw),'stored_bytes':len(z),'stored_sha256':sha(z)};d['members'].append(row);M.write_text(json.dumps(d,indent=2)+'\n');assert p.read_bytes()==raw;p.unlink()
d.update(status='archived_reversible',raw_bytes=sum(x['raw_bytes'] for x in d['members']),stored_bytes=sum(x['stored_bytes'] for x in d['members']),finished_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()));M.write_text(json.dumps(d,indent=2)+'\n');print('Lossless archived80 superseded raw captures; bytes freed',d['raw_bytes']-d['stored_bytes'],'restore recipe preserved')
