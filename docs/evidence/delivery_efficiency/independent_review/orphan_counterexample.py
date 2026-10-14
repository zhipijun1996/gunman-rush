"""Normal wrapper completion must not leave separate-session engine alive."""
import subprocess,tempfile,time,types,argparse,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--source',required=True);args=p.parse_args()
code=subprocess.check_output(['git','show',args.source+':tools/harness.py'],text=True)
h=types.ModuleType('review_harness');h.__file__=str(Path('tools/harness.py').resolve());exec(compile(code,h.__file__,'exec'),h.__dict__)
with tempfile.TemporaryDirectory() as d:
 root=Path(d);marker=root/'orphan-survived'
 child="from pathlib import Path; import time; time.sleep(.5); Path("+repr(str(marker))+").write_text('alive')"
 parent="import subprocess,sys; subprocess.Popen([sys.executable,'-c',"+repr(child)+"],start_new_session=True); print('COMPLETE')"
 result=h.run_check({'argv':['python3','-c',parent],'timeout_seconds':3,'success_pattern':'^COMPLETE$'},root/'log')
 time.sleep(.7)
 print(json.dumps({'source':args.source,'check_status':result['status'],'orphan_survived_after_completed_check':marker.exists(),'expected_survived':False},indent=2))
