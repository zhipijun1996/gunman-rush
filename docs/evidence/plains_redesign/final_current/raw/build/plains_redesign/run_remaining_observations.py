"""One serial root evidence queue. Uses original tools, no production edits or fake worker results."""
from pathlib import Path
import subprocess,time,json,sys,os,hashlib
R=Path('/workspace/gunman-rush');B=R/'build/plains_redesign';D=R/'build/verification/delivery/20261015T105103Z/report.json'
record_path=B/'remaining_observations_execution.json';assert not record_path.exists()
record={'scope':'Actual serial root technical verification after production31calls closed. Q6 rejected art staysfailed; no creative/asset retries, source changes, or human/device claims.','status':'waiting_for_original_delivery','original_delivery':str(D.relative_to(R)),'stages':[],'started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())}
def save():record_path.write_text(json.dumps(record,indent=2)+'\n')
save();deadline=time.monotonic()+3600
while True:
 d=json.loads(D.read_text())
 if d['status']!='running':break
 if time.monotonic()>deadline:record['status']='blocked_original_delivery_deadline';save();raise SystemExit(2)
 time.sleep(1)
if d['status']!='passed':record['status']='blocked_original_delivery_'+d['status'];save();raise SystemExit(2)
# Original final report is written in deliver.finally only after server shutdown; verify no engines.
engines=[s for s in subprocess.check_output(['ps','-eo','args'],text=True).splitlines() if 'Godot_v4.7.2-stable_linux.x86_64' in s and 'ps -eo' not in s];assert not engines,engines
record['original_delivery_report_sha256']=hashlib.sha256(D.read_bytes()).hexdigest();record['status']='running';save()
commands=[('gui',['python3',str(B/'run_final_gui.py'),str(D.relative_to(R))]),('controlled_160',['python3',str(B/'run_controlled_comparison.py')]),('matched_8_movies',['python3',str(B/'run_matched_movies.py')]),('outer_circuit_movie',['python3',str(B/'record_outer_loop.py')])]
env=os.environ.copy();env['LP_NUM_THREADS']='1'
for name,argv in commands:
 entry={'name':name,'argv':argv,'started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'log':f'build/plains_redesign/remaining_{name}.log','status':'running'};record['stages'].append(entry);save();print('Actually starting',name,flush=True)
 with (R/entry['log']).open('w') as log:r=subprocess.run(argv,cwd=R,env=env,stdout=log,stderr=subprocess.STDOUT)
 entry.update(exit_code=r.returncode,finished_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),status='passed' if r.returncode==0 else 'failed');save()
 if r.returncode:record['status']='blocked_'+name;save();raise SystemExit(r.returncode)
record['status']='recorded_all';record['finished_utc']=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime());save();print('All actual serial observations terminated; subjective target remains unverified/failed',flush=True)
