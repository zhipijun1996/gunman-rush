import subprocess,time,json,hashlib
from pathlib import Path
R=Path('/workspace/gunman-rush-refactor');E=Path('/workspace/refactor-evidence/combat-perf-deploy-01/style32');profiles=json.loads((R/'tools/harness/profiles.json').read_bytes());runs=[]
for name in ['region-bible-tests','region-bible-contract','creative-direction','creative-direction-tests','region-bible-history-tests']:
 c=profiles['checks'][name];start=time.monotonic()
 try:
  p=subprocess.run(c['argv'],cwd=R,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=c['timeout_seconds']);raw=p.stdout;code=p.returncode;timed=False
 except subprocess.TimeoutExpired as e:raw=e.stdout or b'';code=None;timed=True
 log=E/(name+'-01.log');log.write_bytes(raw);row=dict(name=name,argv=c['argv'],timeout_seconds=c['timeout_seconds'],elapsed_seconds=time.monotonic()-start,exit_code=code,timed_out=timed,log=str(log),log_sha256=hashlib.sha256(raw).hexdigest());runs.append(row);(E/'runs-01.json').write_text(json.dumps(runs,indent=2)+'\n');print(json.dumps(row),flush=True)
