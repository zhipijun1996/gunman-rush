from pathlib import Path
import subprocess,json,hashlib,os,fcntl,time,re,importlib.util,contextlib
R=Path('/workspace/gunman-rush-design');S=R/'build/forest_depth/snapshots/level_capability04';O=Path(__file__).resolve().parent;B=S/'build/error_ledger01'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def inventory():
 names=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z'],cwd=S).decode().split('\0')
 return {p:digest(S/p) if (S/p).is_file() else 'deleted' for p in sorted(set(names)-{''})}
before=inventory();producers={str(p.relative_to(S)):digest(p) for p in B.glob('*.gd')};sentinel=digest(B/'existing_directory/sentinel.txt');(O/'source-before.json').write_text(json.dumps(before,indent=2)+'\n')
env=os.environ.copy();env.update(GUNMAN_TOOLCHAIN_ROOT='/workspace/toolchains',GUNMAN_DATA_HOME=str(S/'build/error-ledger-data'),XDG_CONFIG_HOME=str(S/'build/error-ledger-config'),XDG_CACHE_HOME=str(S/'build/error-ledger-cache'))
os.environ.update(env)
spec=importlib.util.spec_from_file_location('actual_exit_reader',S/'tools/run_tests.py');reader=importlib.util.module_from_spec(spec);spec.loader.exec_module(reader)
cases=[('old_directory','old_case.gd','res://build/error_ledger01/existing_directory',0,2,0),('new_directory','new_case.gd','res://build/error_ledger01/existing_directory',2,2,2),('new_file','new_case.gd','res://build/error_ledger01/new_report.json',0,0,0)]
receipt={'scope':'Direct real save_report output I/O and sticky-code control; not normal41/169 replay or full capture CLI','old_positive_fullwrapper_source_scope_preserved':True,'producers_before':producers,'cases':[],'passed':False}
try:
 with open(R/'build/verification/engine.lock','w') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX)
  for label,helper,path,exit_code,saved,final in cases:
   argv=['bash','tools/godot.sh','--headless','--verbose','--path','.', '--script','build/error_ledger01/probe.gd','--','--helper=res://build/error_ledger01/'+helper,'--output='+path];start=time.monotonic()
   reader_error=None
   with (O/(label+'.log')).open('w') as log, contextlib.redirect_stdout(log):
    try:
     reader.run_engine(argv[2:],10); actual_exit=0
    except RuntimeError as error:
     reader_error=str(error); match=re.fullmatch(r'Godot returned (-?\d+)',reader_error)
     if not match: raise
     actual_exit=int(match.group(1))
   text=(O/(label+'.log')).read_text();events=[json.loads(x) for x in re.findall(r'^CAPTURE ERROR LEDGER (.+)$',text,re.M)];strict=not bool(re.search(r'(^|\n)(?:SCRIPT )?ERROR:|Parse Error:|SHADER ERROR:|ObjectDB.*leaked|resources? still in use at exit',text,re.I));actual=events[0] if len(events)==1 else {}
   good=actual_exit==exit_code and strict and actual.get('code_after_save_report')==saved and actual.get('code_after_finish_zero')==final and actual.get('owner_released') is True and actual.get('output_is_directory')==('directory' in label)
   row={'id':label,'argv':argv,'budget_seconds':10,'expected_exit':exit_code,'exit_code':actual_exit,'elapsed_seconds':time.monotonic()-start,'strict_log_clean':strict,'actual_reader_error':reader_error,'actual_reader_accepts':reader_error is None,'observation':actual,'passed':good,'log_sha256':digest(O/(label+'.log'))};receipt['cases'].append(row);print(json.dumps(row),flush=True)
   if not good:raise RuntimeError('First unexpected diagnostic result: '+label)
  assert (B/'existing_directory').is_dir() and digest(B/'existing_directory/sentinel.txt')==sentinel
  output=json.loads((B/'new_report.json').read_text());assert output['scope'].startswith('direct real save_report') and output['assertions']==0 and output['failures']==[]
  receipt['positive_output']={'path':str((B/'new_report.json').relative_to(S)),'sha256':digest(B/'new_report.json'),'content':output}
 receipt['passed']=True
finally:
 after=inventory();receipt['source_guard']=before==after;receipt['producers_after']={str(p.relative_to(S)):digest(p) for p in B.glob('*.gd')};receipt['producer_guard']=producers==receipt['producers_after'];(O/'source-after.json').write_text(json.dumps(after,indent=2)+'\n');receipt['passed']=receipt['passed'] and receipt['source_guard'] and receipt['producer_guard'];(O/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('PASS: real FileAccess directory failure retained; positive report writes; no normal route rerun',flush=True)
