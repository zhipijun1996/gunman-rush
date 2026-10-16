import subprocess,json,sys,os,hashlib
from pathlib import Path
repo=Path('/workspace/gunman-rush');out=repo/'build/region_production_v3/independent/ci_uid_portability_review';runs=[]
for uid,prefix in [(os.geteuid(),[]),(1001,['unshare','--user','--map-user=1001','--map-group=1001','--'])]:
 for label,script in [('uid3','tests/test_forest_uid_preservation.py'),('route16','tests/test_level_design_routing.py'),('identity','build/region_production_v3/independent/ci_uid_portability_review/identity_probe.py')]:
  command=prefix+[sys.executable,script];p=subprocess.run(command,cwd=repo,capture_output=True,text=True,timeout=35);log=out/(str(uid)+'_'+label+'.log');log.write_text(p.stdout+p.stderr);runs.append({'uid':uid,'label':label,'command':command,'exit_code':p.returncode,'log':log.name,'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest()});assert p.returncode==0,(command,p.stdout,p.stderr)
(out/'actual_runs.json').write_text(json.dumps({'scope':'Actual unprivileged host and real unshare kernel UID1001; no euid monkeypatch/native/AI','runs':runs},indent=2)+'\n');print(json.dumps(runs))
