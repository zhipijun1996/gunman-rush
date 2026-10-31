from pathlib import Path
import hashlib,json,os,re,signal,subprocess,time,shutil
root=Path('/workspace/gunman-rush-refactor');out=Path(__file__).resolve().parent
engine=Path('/workspace/engine-diagnostics/godot-4.7.2-standard-shutdown-c')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(engine)=='c54ecbeb70aa099d3e985b6e3098b84540491c567578b0dce838ca0922f33311'
assert subprocess.check_output(['git','status','--porcelain'],cwd=root,text=True)==''
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
cases=[('tests/audio_director_lab.gd',r'^AUDIO_DIRECTOR_LAB checks=[1-9][0-9]* failures=0$','build/audio_director/lab-runtime'),('tests/audio_director_v2_scene.gd',r'^AUDIO_DIRECTOR_V2_SCENE checks=[1-9][0-9]* failures=0$','build/audio_director_v2/scene-runtime'),('tests/audio_director_reels.gd',r'^AUDIO_DIRECTOR_REELS checks=[1-9][0-9]* failures=0$','build/audio_director_v3/reels-runtime')]
rows=[]
for index,(scene,marker,receipt) in enumerate(cases,1):
 env=os.environ.copy();env.update(XDG_DATA_HOME=str(out/'data'/str(index)),XDG_CONFIG_HOME=str(out/'config'/str(index)),XDG_CACHE_HOME=str(out/'cache'))
 command=[str(engine),'--headless','--verbose','--fixed-fps','60','--path',str(root),'--script',scene]
 start=time.monotonic();log=out/f'{index}.log'
 with log.open('wb') as stream:
  p=subprocess.Popen(command,cwd=root,env=env,stdout=stream,stderr=subprocess.STDOUT,start_new_session=True)
  try:code=p.wait(timeout=180)
  except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait();code=124
 raw=log.read_text(errors='replace');errors=[]
 if code:errors.append('exit='+str(code))
 if re.search(r'(?m)^ERROR:|SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ObjectDB.*leaked|resources still in use|RID.*leaked',raw):errors.append('raw engine/script/resource error')
 if not re.search(marker,raw,re.M):errors.append('original completion marker missing')
 if (root/receipt).exists():shutil.copytree(root/receipt,out/f'receipt-{index}')
 row={'script':scene,'source_sha256':sha(root/scene),'argv':command,'timeout_seconds':180,'seconds':time.monotonic()-start,'exit_code':code,'log':log.name,'log_sha256':sha(log),'errors':errors,'status':'failed' if errors else 'diagnostic_passed'}
 rows.append(row);print(json.dumps(row),flush=True)
report={'source_commit':head,'source_unchanged':head==subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip() and subprocess.check_output(['git','status','--porcelain'],cwd=root,text=True)=='','engine_sha256':sha(engine),'scope':'Unchanged existing native scripts under diagnostic O0 C only. Not official Harness or optimized engine acceptance; original180-second budgets and completion markers retained; strict raw errors added.','results':rows}
(out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
raise SystemExit(1 if any(r['errors'] for r in rows) or not report['source_unchanged'] else 0)
