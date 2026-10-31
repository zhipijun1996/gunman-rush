from pathlib import Path
import subprocess,time,json,hashlib,re,os,signal
root=Path('/workspace/gunman-rush-refactor');out=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
files=[*sorted((root/'resources/foundry').rglob('*.json')),*[root/('tests/'+n) for n in ['foundry_lab_runner.gd','foundry_touch_runner.gd','foundry_feedback_runner.gd']]]
frozen={str(p.relative_to(root)):sha(p) for p in files}
rows=[('foundry-lab','tests/foundry_lab_runner.gd',r'^FOUNDRY LAB: [1-9][0-9]* assertions, 0 failures$'),('foundry-touch','tests/foundry_touch_runner.gd',r'^FOUNDRY TOUCH: [1-9][0-9]* assertions, 0 failures$'),('foundry-feedback','tests/foundry_feedback_runner.gd',r'^LAB FEEDBACK: [1-9][0-9]* assertions, 0 failures$')]
report={'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'source_wip':'Generated canonical devpool and four-line Android artifact handoff; game scripts unchanged','scope':'Three original Foundry UI/replay consumers absent from full182; headless limited interaction, not pixels or user acceptance','frozen_files':frozen,'runs':[],'status':'running'}
start=time.monotonic()
def save():
 report['elapsed_seconds']=time.monotonic()-start;(out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
for name,script,marker in rows:
 command=['python3','tools/run_audio_lifecycle_tests.py','--script',script,'--marker',marker,'--timeout','180','--output','build/entry-final-foundry-fixed/'+name]
 row={'id':name,'command':command,'native_timeout_seconds':180,'coordinator_timeout_seconds':190,'coordinator_limit_reason':'Wrapper itself enforces the original native180; extra10 only bounds wrapper I/O, never permits native over180','status':'running'};report['runs'].append(row);save();t=time.monotonic()
 with (out/(name+'.log')).open('wb') as f:
  p=subprocess.Popen(command,cwd=root,stdout=f,stderr=subprocess.STDOUT,start_new_session=True)
  try:code=p.wait(timeout=190)
  except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait();code=124
 output=root/('build/entry-final-foundry-fixed/'+name);native=output/'native.log';rr=output/'report.json';payload=json.loads(rr.read_text()) if rr.exists() else {}
 raw=native.read_text(errors='replace') if native.exists() else ''
 errors=bool(re.search(r'SCRIPT ERROR:|Parse Error:|SHADER ERROR:|^ERROR:|ObjectDB.*leaked|resources? still in use at exit',raw,re.M))
 row.update(exit_code=code,seconds=time.monotonic()-t,native_report=payload,native_log_sha256=sha(native) if native.exists() else None,strict_errors=errors)
 row['status']='passed' if code==0 and payload.get('status')=='passed' and not errors else 'failed';save();print(json.dumps(row),flush=True)
 if row['status']!='passed':report['status']='failed';save();raise SystemExit(1)
report['source_unchanged']=frozen=={str(p.relative_to(root)):sha(p) for p in files};report['status']='passed' if report['source_unchanged'] else 'failed';save()
