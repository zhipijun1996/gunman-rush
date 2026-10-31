import json,hashlib,sys,urllib.request
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0,'tools/mobile_web_perf')
from verify_published_audio import download
root='https://zhipijun1996.github.io/gunman-rush/'
prepared=Path('/workspace/gunman-rush-prepared-mobile-fps-04')
out=Path('build/mobile_web_fps_04/actions/public-files-01.json')
assert not out.exists()
r={'scope':'Actual public metadata for4entries; complete new candidate PCK/JS/WASM/worklets/HTML/worker HTTP bytes. Prior-entry packs not redownloaded this round; prepared Git diff adds only perf-actions.','metadata':{},'files':[],'status':'running'}
def save():out.write_text(json.dumps(r,indent=2)+'\n')
save()
try:
 for d in ['','audio-before/','perf-04/','perf-actions/']:
  expected=json.loads((prepared/d/'build-info.json').read_text())
  with urllib.request.urlopen(root+d+'build-info.json?audit='+expected['build_id'],timeout=90) as response:actual=json.load(response)
  r['metadata'][d]=actual;save();assert actual==expected,(d,actual,expected)
 info=r['metadata']['perf-actions/'];names=[info['pack'],'index.html','index.cache-sw.js']+['index.'+info['engine_id']+'.engine'+s for s in ['.js','.wasm','.audio.worklet.js','.audio.position.worklet.js']]
 jobs=[]
 for name in names:
  p=prepared/'perf-actions'/name;jobs.append((root+'perf-actions/'+name,p.stat().st_size,hashlib.sha256(p.read_bytes()).hexdigest()))
 with ThreadPoolExecutor(max_workers=2) as pool:
  for job,result in zip(jobs,pool.map(download,[j[0] for j in jobs])):
   r['files'].append(result);save();assert result['status']==200 and result['bytes']==job[1] and result['sha256']==job[2],result
 r['status']='passed';save();print(json.dumps({'status':'passed','metadata':4,'full_files':len(names)}))
except Exception as e:
 r['status']='failed';r['error']=str(e);save();raise
