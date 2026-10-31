"""Real wrapper main with tiny subprocess producers; scheduling tests only, no Godot acceptance."""
from pathlib import Path
import copy,importlib.util,json,os,signal,subprocess,sys,tempfile,threading,time,types,contextlib,io
from unittest.mock import patch
R=Path(__file__).resolve().parent
sys.path.insert(0,'/workspace/integration-four/tools')
spec=importlib.util.spec_from_file_location('scheduling_candidate',R/'tools/run_plains_encounter_policy_tests.py'); m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
results=[]
def exercise(mode):
 with tempfile.TemporaryDirectory(prefix='plains-scheduling-') as directory:
  root=Path(directory);lock=threading.Lock();active=0;peak=0;launched=[];finished=[];children=[];validations=[];writes=[]
  def capture(seed,index,strategy,target,max_ticks=18000,encounter_policy='blind_legacy'):
   nonlocal active,peak
   relative=Path(target).relative_to(root).as_posix()
   with lock:
    active+=1;peak=max(peak,active);launched.append({'seed':seed,'map_index':index,'strategy':strategy,'target':relative,'max_ticks':max_ticks,'policy':encounter_policy})
   child=None
   try:
    # Actual child processes exercise in-flight joining and bounded group cleanup.
    delay=(.12 if '/case_0/' in relative else .04) if mode=='success' else (.02 if '/case_0/' in relative else .2)
    if mode=='timeout' and '/case_0/' in relative:delay=5
    child=subprocess.Popen([sys.executable,'-c','import time; time.sleep('+str(delay)+')'],start_new_session=True)
    with lock:children.append(child)
    try:child.wait(timeout=.25)
    except subprocess.TimeoutExpired:
     os.killpg(child.pid,signal.SIGTERM);child.wait(timeout=.5)
     return {'captured':False,'capture':relative,'fake_reason':'bounded child timeout'}
    if '/case_0/' in relative and mode=='exception':raise RuntimeError('simulated capture exception')
    data={'events':[{'kind':'shot_accepted'}],'strategy':strategy,'policy_observations':[{'kind':'actual_nonkill_bypass','enemy_health':1}],'target':relative}
    target.parent.mkdir(parents=True,exist_ok=True);target.write_text(json.dumps(data))
    return {'captured':not(mode=='false' and '/case_0/' in relative),'capture':relative}
   finally:
    if child is not None and child.poll() is None:
     os.killpg(child.pid,signal.SIGTERM);child.wait(timeout=.5)
    with lock:active-=1;finished.append(relative)
  fakeformal=types.SimpleNamespace(source_files=lambda:{'simulated-readonly-source':'exact'},file_hash=lambda path:'simulated-hash',capture_one=capture)
  def native(*args):
   return {'scope':'fake native fixture never acceptance'}, {'cases':[{'id':'kill_and_dead_fake','events':[{'kind':'segment_returned'}],'frames':[{'requests':[]}],'policy_observations':[{'kind':'actual_wrong_choice_rejected','rejected':True}]}]}
  def reject_tamper(*args):raise ValueError('simulated pre-scheduling validator')
  def validate(data):
   validations.append(data['target'])
   if mode=='validation' and '/case_0/' in data['target']:raise ValueError('simulated validation rejection')
  def compare(a,b):
   assert a['paths']!=b['paths'],'Independent repeat became self-comparison'
   return {'scope':'simulated comparison; scheduling only'}
  fakeexperience=types.SimpleNamespace(validate_capture=validate,report=lambda paths:{'paths':[str(p) for p in paths]},compare=compare)
  def write(path,data):
   path=Path(path);path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(data));writes.append(path.name)
  error=None; started=time.monotonic()
  with patch.object(m,'ROOT',root),patch.object(m,'formal',fakeformal),patch.object(m,'experience',fakeexperience),patch.object(m,'native_run',side_effect=native),patch.object(m,'reward_entry_checks',return_value={'scope':'fake preceding consumers'}),patch.object(m,'validate_native',side_effect=reject_tamper),patch.object(m,'policy_tamper_checks',return_value=[]),patch.object(m,'claim_tamper_checks',return_value=[]),patch.object(m,'write',side_effect=write),patch.dict(sys.modules,{'run_formal_trace_cancel_tests':types.SimpleNamespace(run=lambda folder:{'scope':'fake preceding cancellation'})}),patch.object(m.subprocess,'run',return_value=types.SimpleNamespace(returncode=0)),patch.object(m.subprocess,'check_output',return_value='simulated-source\n'),patch.object(sys,'argv',['candidate']),contextlib.redirect_stdout(io.StringIO()):
   cases=m.CASES[:-1] if mode=='incomplete' else m.CASES
   with patch.object(m,'CASES',cases):
    try:code=m.main()
    except (ValueError,RuntimeError) as exc:code=None;error=type(exc).__name__+': '+str(exc)
  elapsed=time.monotonic()-started
  receipt=json.loads(next((root/'build/verification/plains-encounter').glob('*/receipt.json')).read_text())
  assert active==0 and all(child.poll() is not None for child in children),'Producer escaped wrapper cleanup'
  assert peak<=2
  assert elapsed<2,'Tiny fake cleanup was not bounded'
  if mode=='success':
   assert code==0 and receipt['status']=='passed' and len(launched)==6 and peak==2
   targets=[x['target'] for x in launched];assert len(set(targets))==6
   expected=['after/case_'+str(i)+'/capture.json' for i in range(4)]
   assert [p.split('/run_',1)[-1].split('/',1)[-1] for p in receipt['current_cases']]==expected
   assert '/case_1/' in finished[0] and '/case_0/' not in finished[0],finished
   ordered=sorted(launched,key=lambda x:expected.index(x['target'].split('/run_',1)[-1].split('/',1)[-1]) if '/after/' in x['target'] else 4 if '/current_repeat/' in x['target'] else 5)
   assert [(x['seed'],x['map_index'],x['strategy']) for x in ordered[:4]]==m.CASES
   assert ordered[4]['seed']==m.CASES[0][0] and ordered[4]['strategy']==m.CASES[0][2]
   assert [x['max_ticks'] for x in ordered]==[15000]*5+[10000]
   assert [x['policy'] for x in ordered]==['kill_from_bank_v1']*5+['bait_then_bypass_v1']
   assert len(validations)==5 and receipt['same_source_repeat']['capture']!=receipt['current_cases'][0]
  else:
   assert code is None and error and receipt['status']=='failed',(mode,code,error,receipt['status'])
   if mode=='incomplete':assert launched==[]
   else:assert len(launched)<6,'Queued producers were not cancelled after observed failure'
  results.append({'mode':mode,'status':'passed scheduling assertions only','peak_workers':peak,'launched':launched,'completed_order':finished,'all_children_reaped':True,'elapsed_seconds':elapsed,'wrapper_return':code,'wrapper_exception':error,'receipt_status':receipt['status']})
for mode in ['success','false','exception','validation','timeout','incomplete']:exercise(mode)
(R/'scheduling-results.json').write_text(json.dumps({'scope':'Six real wrapper-main scheduling tests with tiny Python subprocesses; preceding consumers and payload validators explicitly simulated, no Godot/native approval','cases':results},indent=2)+'\n')
print('SCHEDULING ONLY:6/6; max2, six unique exact jobs, ordered validation/repeat, false/exception/rejection/timeout/incomplete all stay failed, queued cancelled and active children reaped')
