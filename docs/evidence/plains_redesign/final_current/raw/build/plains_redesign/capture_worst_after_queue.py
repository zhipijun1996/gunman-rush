"""One explicit worst-seed observation after the original serial queue; never retries."""
from pathlib import Path
import json,subprocess,os,time
R=Path('/workspace/gunman-rush');B=R/'build/plains_redesign';P=B/'worst_movie_execution.json';assert not P.exists()
d={'status':'waiting_original_queue','scope':'Additional actual unresolved worst-seed movie, not a creative production call or automatic retry. Keep policy failure, source/input/GUI/fun boundaries.','case':{'seed':'level-design-v2-baseline/03','map_index':2,'strategy':'deep','encounter_policy':'kill_from_bank_v1'},'started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())}
def save():P.write_text(json.dumps(d,indent=2)+'\n')
save();deadline=time.monotonic()+7200
while True:
 q=json.loads((B/'remaining_after_gui_fix_execution.json').read_text())
 if q['status']=='recorded_all':break
 if q['status'].startswith('blocked'):d['status']='blocked_original_queue';save();raise SystemExit(2)
 if time.monotonic()>deadline:d['status']='blocked_wait_deadline';save();raise SystemExit(2)
 time.sleep(2)
assert not (B/'worst_movie').exists()
code="import sys;sys.path.insert(0,'tools');from level_visual_capture import capture;capture('level-design-v2-baseline/03',2,'deep','build/plains_redesign/worst_movie',max_ticks=18000,timeout=900,encounter_policy='kill_from_bank_v1')"
argv=['python3','-c',code];d.update(status='running',argv=argv);save();env=os.environ.copy();env['LP_NUM_THREADS']='1';env['LIBGL_ALWAYS_SOFTWARE']='1'
with (B/'worst_movie.log').open('w') as f:r=subprocess.run(argv,cwd=R,env=env,stdout=f,stderr=subprocess.STDOUT)
d.update(status='recorded' if r.returncode==0 else 'blocked',exit_code=r.returncode,finished_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()));save();raise SystemExit(r.returncode)
