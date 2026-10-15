"""Wait for every actual movie terminal, then derive maps from final controlled native captures."""
from pathlib import Path
import json,subprocess,time,os,sys,hashlib
R=Path('/workspace/gunman-rush');B=R/'build/plains_redesign';P=B/'map_execution.json';assert not P.exists()
d={'status':'waiting_actual10movies','scope':'Only source-bound actual native geometry/trajectory diagrams, not gameplay screenshots or physical/art approval.'}
def save():P.write_text(json.dumps(d,indent=2)+'\n')
save();deadline=time.monotonic()+7200
while True:
 q=json.loads((B/'worst_movie_execution.json').read_text())
 if q['status']=='recorded':break
 if q['status'].startswith('blocked'):d['status']='blocked_movie_queue';save();raise SystemExit(2)
 if time.monotonic()>deadline:d['status']='blocked_wait_deadline';save();raise SystemExit(2)
 time.sleep(2)
sys.path.insert(0,str(R/'tools'));import level_formal
source=level_formal.source_files();d['source_commit']=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip();d['source_before']=source
argv=['python3',str(B/'plot_controlled_maps.py'),'--before-project','/workspace/plains-redesign-baseline','--after-project',str(R),'--trajectories']
d.update(status='running',argv=argv,started_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()));save();env=os.environ.copy();env['MPLBACKEND']='Agg';env['LP_NUM_THREADS']='1'
with (B/'map_execution.log').open('w') as f:r=subprocess.run(argv,cwd=R,env=env,stdout=f,stderr=subprocess.STDOUT)
d.update(exit_code=r.returncode,finished_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),source_after=level_formal.source_files());d['status']='derived' if r.returncode==0 and source==d['source_after'] else 'blocked';save();raise SystemExit(0 if d['status']=='derived' else 2)
