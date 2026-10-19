import sys,json,tarfile,tempfile,hashlib,gzip,importlib.util
from pathlib import Path
archive=Path(sys.argv[1])
with tarfile.open(archive) as t:
 index=json.load(t.extractfile('members.json'))
 assert all(not Path(n).is_absolute() and '..' not in Path(n).parts for n in t.getnames())
 for k,row in index.items():assert hashlib.sha256(t.extractfile(k).read()).hexdigest()==row['sha256'],k
 with tempfile.TemporaryDirectory() as tmp:
  context=Path(tmp)/'context'
  for k in index:
   if k.startswith('context/'):
    p=Path(tmp)/k;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(t.extractfile(k).read())
  d=json.loads(gzip.decompress(t.extractfile('actual/capture.json.gz').read()));spec=importlib.util.spec_from_file_location('frozen',context/'tools/run_forest_depth_region.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);m.ROOT=context
  errors=m.validate(d);assert errors==[],errors
  receipt=json.load(t.extractfile('actual/receipt.json'));run=receipt['runs'][0];movie=run['movie'];assert m.validate_movie_timeline(d,movie['frames'])==[]
  print(json.dumps({'members_verified':len(index),'frozen_verifier_errors':errors,'physical_frames':len(d['frames']),'movie_frames':movie['frames'],'min_health':min(f['health']for f in d['frames']),'final_health':d['final_snapshot']['health'],'scope':'Offline exact archived checker only. No native/movie recapture; media hashes verified, no human/audio approval.'},indent=2))
