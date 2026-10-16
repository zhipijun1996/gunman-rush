import json,subprocess,time,sys
from pathlib import Path
ROOT=Path('/workspace/gunman-rush');sys.path.insert(0,str(ROOT/'tools'));import publish_playtest
out=ROOT/'build/region_production_v3/final_native';run=38846504655;expected='50fb10c749871cb555f24fab84b3f539abde49fb';deadline=time.monotonic()+900;last=''
while time.monotonic()<deadline:
 for poll_attempt in range(3):
  response=subprocess.run(['gh','api',f'repos/zhipijun1996/gunman-rush/actions/runs/{run}'],text=True,capture_output=True,timeout=30)
  if response.returncode==0:
   d=json.loads(response.stdout);break
  print(f'Observer API poll failed {poll_attempt+1}/3: {response.stderr.strip()}',flush=True)
  if poll_attempt==2:raise RuntimeError('Observer API remains blocked; CI itself not modified')
  time.sleep(3*(poll_attempt+1))
 assert d['head_sha']==expected and d['run_attempt']==2,'Unexpected source or additional retry'
 status=f"attempt2 {d['status']} {d['conclusion']} {d['html_url']}"
 if status!=last:print(status,flush=True);last=status
 if d['status']=='completed':
  summary={k:d.get(k) for k in ['id','run_attempt','status','conclusion','head_sha','html_url','created_at','updated_at']}
  (out/'publish_attempt2_terminal.json').write_text(json.dumps(summary,indent=2)+'\n')
  assert d['conclusion']=='success','Actual retry failed; do not claim deployment'
  info=publish_playtest.live_info('https://zhipijun1996.github.io/gunman-rush/')
  assert info['source_commit']==expected,'Live source mismatch'
  result={'url':'https://zhipijun1996.github.io/gunman-rush/?v='+info['build_id'],'source_commit':expected,'build_info':info,'run_id':run,'attempt':2,'live_verified':True}
  (out/'public_published_result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True);break
 time.sleep(20)
else:raise RuntimeError('Bounded publishing retry deadline; preserve state and report blocked')
