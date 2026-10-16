"""Resume original blocked evidence queue after actual test-only locator fix; no fake resume."""
from pathlib import Path
import json,subprocess,time,os
R=Path('/workspace/gunman-rush');B=R/'build/plains_redesign';P=B/'remaining_after_gui_fix_execution.json';assert not P.exists()
d={'scope':'New explicitly attributed evidence queue after real GUI locator failure. Original remaining_observations remainsblocked; no history rewritten. C3runtime/build unchanged, C4test-only bridge and GUIv2 actual result required. Technical collection does not imply route goals/fun/visual quality.','status':'waiting_for_gui_v2','stages':[]}
def save():P.write_text(json.dumps(d,indent=2)+'\n')
save();deadline=time.monotonic()+600
while True:
 p=B/'final_gui_v2/execution.json'
 if p.exists():
  report=json.loads(p.read_text())
  if report.get('status')=='passed':break
  if any(c.get('exit_code',0)!=0 for c in report.get('commands',[])):d['status']='blocked_gui_v2';save();raise SystemExit(2)
 if time.monotonic()>deadline:d['status']='blocked_gui_v2_deadline';save();raise SystemExit(2)
 time.sleep(1)
d['status']='running';save();env=os.environ.copy();env['LP_NUM_THREADS']='1'
for name,script in [('historical_lossless_archive','archive_historical_traces.py'),('controlled_160','run_controlled_comparison.py'),('matched_8_movies','run_matched_movies.py'),('outer_circuit_movie','record_outer_loop.py')]:
 argv=['python3',str(B/script)];row={'name':name,'argv':argv,'status':'running','started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'log':f'build/plains_redesign/resumed_{name}.log'};d['stages'].append(row);save();print('Actually starting',name,flush=True)
 with (R/row['log']).open('w') as f:r=subprocess.run(argv,cwd=R,env=env,stdout=f,stderr=subprocess.STDOUT)
 row.update(exit_code=r.returncode,status='passed' if r.returncode==0 else 'failed',finished_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()));save()
 if r.returncode:d['status']='blocked_'+name;save();raise SystemExit(r.returncode)
d['status']='recorded_all';save()
