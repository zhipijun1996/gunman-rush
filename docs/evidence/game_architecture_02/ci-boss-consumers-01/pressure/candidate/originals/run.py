from pathlib import Path
import subprocess,os,json,time,hashlib,signal,re
root=Path('/workspace/gunman-rush-integration');out=Path(__file__).resolve().parent;engine=Path('/workspace/refactor-evidence/engine-184-download/lanes/engine-built-linux-editor/godot-linux-x86_64');before=json.loads((out/'before.json').read_text());rows=[]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();assert sha(engine)=='eeaec2b65dc3234168be1e1cbcc89731514bbb78dfb2c1b502920c50830a0638'
env=os.environ.copy();env.update(XDG_DATA_HOME=str(out/'data'),XDG_CONFIG_HOME=str(out/'config'),XDG_CACHE_HOME=str(out/'cache'))
try:
 for label,args,limit in [('import',['--headless','--path','.','--editor','--quit'],90),('energy',['--headless','--fixed-fps','60','--path','.','--script','tests/plains_experience_energy_runner.gd'],90),('pressure',['--headless','--fixed-fps','60','--path','.','--script','tests/plains_pressure_boss_runner.gd'],90)]:
  start=time.monotonic();log=out/(label+'.log')
  with log.open('wb') as f:
   p=subprocess.Popen([str(engine),*args],cwd=root,env=env,stdout=f,stderr=subprocess.STDOUT,start_new_session=True)
   try:code=p.wait(timeout=limit)
   except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait();code=124
  raw=log.read_text(errors='replace');row={'case':label,'exit_code':code,'seconds':time.monotonic()-start,'timeout_seconds':limit,'log_sha256':sha(log),'failures':re.findall(r'^FAIL:?.*$',raw,re.M),'marker':re.findall(r'^(?:PLAINS EXPERIENCE ENERGY|PLAINS PRESSURE BOSS):.*$',raw,re.M)};rows.append(row);print(json.dumps(row),flush=True)
  if label=='import' and (code or re.search(r'SCRIPT ERROR:|(?m:^ERROR:)',raw)):break
 report={'source_commit':before['target'],'engine_sha256':sha(engine),'script_sha256':{n:sha(root/n) for n in ['tests/plains_experience_energy_runner.gd','tests/plains_pressure_boss_runner.gd']},'source_clean_after':subprocess.check_output(['git','status','--porcelain'],cwd=root,text=True)=='','scope':'Exact pre-P9 ed95, same optimized editor, two original explicitly historical Boss fixture scripts and original native budgets','results':rows};(out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
finally:
 p=subprocess.run(['git','checkout','--detach',before['head']],cwd=root,capture_output=True,text=True);(out/'restore.log').write_text(p.stdout+p.stderr);assert p.returncode==0
