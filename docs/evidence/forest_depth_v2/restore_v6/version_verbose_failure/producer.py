from pathlib import Path
import contextlib,hashlib,json,os,sys,time
S=Path.cwd();sys.path.insert(0,str(S/'tools'))
from run_tests import run_engine
import level_formal
O=S/'build/forest_depth/versions/verbose04';O.mkdir(parents=True,exist_ok=False)
receipt={'scope':'ONE actual verbose repeat of failing versions04 frozen source, original assertions and90s native cap unchanged; no production fix or new acceptance','source_before':level_formal.source_files(),'passed':False,'native_cap_seconds':90}
start=time.monotonic();failure=None
try:
 argv=['--verbose','--headless','--fixed-fps','60','--path','.','--script','tests/forest_depth_version_runner.gd','--','--output=res://build/forest_depth/versions/verbose04/capture.json']
 receipt['argv']=argv
 with (O/'native.log').open('w') as log,contextlib.redirect_stdout(log):text=run_engine(argv,90)
 receipt['passed']=True
except Exception as error:
 receipt['exception']=type(error).__name__+': '+str(error);failure=error
finally:
 receipt['source_after']=level_formal.source_files();receipt['source_guard']=receipt['source_before']==receipt['source_after'];receipt['elapsed_seconds']=time.monotonic()-start
 snapshot=json.loads((S/'build/snapshot-receipt.json').read_text());receipt['all_snapshot_raw_bytes_unchanged']=all(hashlib.sha256((S/p).read_bytes()).hexdigest()==sha for p,sha in snapshot['source_files'].items())
 receipt['files']={p.name:{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in O.iterdir() if p.is_file()}
 (O/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
if failure:raise failure
assert receipt['source_guard'] and receipt['all_snapshot_raw_bytes_unchanged']
