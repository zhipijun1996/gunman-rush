"""Actual scheduler and original Harness process guards with tiny Python producers; no Godot."""
from pathlib import Path
import importlib.util,json,subprocess,sys,tempfile,threading,time,types
from unittest.mock import patch
R=Path(__file__).resolve().parent;sys.path.insert(0,'/workspace/integration-four/tools')
spec=importlib.util.spec_from_file_location('scene_scheduler_candidate',R/'tools/run_plains_redesign_scene_tests.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
original_check=m.harness.run_check;groups=([0,1],[2,7],[3,6],[4,5]);results=[]
def exercise(fault):
 with tempfile.TemporaryDirectory(prefix='scene-four-groups-') as directory:
  repo=Path(directory);folder=repo/'build/scene';folder.mkdir(parents=True);lock=threading.Lock();active=0;peak=0;calls=[];completed=0;expired=False
  def clock():return 181.0 if expired else 0.0
  def small_python_producer(check,log,root,env):
   nonlocal active,peak,completed,expired
   shard=int(next(x.split('=',1)[1] for x in check['argv'] if x.startswith('--positive-shard=')))
   output=Path(next(x.split('=',1)[1] for x in check['argv'] if x.startswith('--output=')))
   indices=list(groups[shard]);rows=[{'scene_case_index':i,'frames':[{'scope':'synthetic schedule control'}]} for i in indices]
   cleanups=[{'scene_case_index':i,'scope':'synthetic schedule control'} for i in indices]
   data={'positive_shard':shard,'scene_case_indices':indices,'cases':rows,'post_capture_cleanup':cleanups,'legacy_ui':{'scope':'simulated legacy payload'} if shard==0 else {},'assertions':40,'failures':0}
   if shard==1:data['cases'].append({'generation_corpus':[{'seed':'synthetic/'+str(i)} for i in range(10)]})
   if shard==0:
    if fault=='missing':data['cases'].pop()
    if fault=='duplicate':data['cases'][1]['scene_case_index']=data['cases'][0]['scene_case_index']
    if fault=='wrong_shard':data['positive_shard']=2
    if fault=='cleanup_duplicate':data['post_capture_cleanup'][1]['scene_case_index']=0
    if fault=='missing_legacy':data['legacy_ui']={}
   if fault=='extra_corpus' and shard==2:data['cases'].append({'generation_corpus':[{}]*10})
   marker='' if fault=='missing_marker' and shard==0 else 'PLAINS REDESIGN SCENE NATIVE: 40 assertions, 0 failures'
   exit_code=5 if fault=='nonzero' and shard==0 else 0
   delay=1 if fault=='process_timeout' and shard==0 else .035
   code='import json,time,pathlib; time.sleep('+repr(delay)+'); pathlib.Path('+repr(str(output))+').write_text('+repr(json.dumps(data))+'); print('+repr(marker)+'); raise SystemExit('+repr(exit_code)+')'
   with lock:
    active+=1;peak=max(peak,active);calls.append({'shard':shard,'output':str(output),'original_timeout':check['timeout_seconds'],'started':time.monotonic()})
   try:
    # The actual original run_check, including marker/nonzero/timeout/group cleanup.
    control=dict(check,argv=[sys.executable,'-c',code])
    if fault=='process_timeout' and shard==0:control['timeout_seconds']=.08
    return original_check(control,log,root,env)
   finally:
    with lock:
     active-=1;completed+=1
     if fault=='aggregate_timeout' and completed==4:expired=True
  with patch.object(m,'REPO',repo),patch.object(m.harness,'run_check',side_effect=small_python_producer):
   context=patch.object(m,'time',types.SimpleNamespace(monotonic=clock)) if fault=='aggregate_timeout' else patch.object(m,'time',time)
   with context:proof=m.run_positive(folder,{})
  data=json.loads((folder/'positive.json').read_text());report=json.loads((folder/'positive-partitions.json').read_text())
  assert len(calls)==4 and len({x['output'] for x in calls})==4 and peak==4 and active==0
  assert all(0<x['original_timeout']<=180 for x in calls)
  if fault!='aggregate_timeout':
   deadlines=[x['started']+x['original_timeout'] for x in calls];assert max(deadlines)-min(deadlines)<.1,'Worker received its own new deadline'
  assert report['aggregate_budget_seconds']==180
  if fault=='success':
   assert proof['status']=='passed'
   routes=[c for c in data['cases'] if 'frames' in c]
   assert [c['scene_case_index'] for c in routes]==list(range(8))
   assert [c['scene_case_index'] for c in data['post_capture_cleanup']]==list(range(8))
   assert len([c for c in data['cases'] if 'generation_corpus' in c])==1
  else:assert proof['status']=='failed' and proof['exit_code']==1,(fault,proof)
  results.append({'control':fault,'wrapper_status':proof['status'],'peak_workers':peak,'unique_outputs':len({x['output'] for x in calls}),'all_workers_joined':active==0,'native_process_statuses':[x['process']['status'] for x in report['native_runs']],'aggregate_within_deadline':report['within_aggregate_deadline'],'scope':'tiny Python process payload, not actual native evidence'})
for fault in ('success','missing','duplicate','wrong_shard','nonzero','missing_marker','process_timeout','aggregate_timeout','cleanup_duplicate','missing_legacy','extra_corpus'):exercise(fault)
(R/'fault-controls.json').write_text(json.dumps({'scope':'Actual run_positive and original Harness run_check exercised using tiny Python subprocesses; no Godot or content approval','groups':groups,'controls':results},indent=2)+'\n')
print('SCHEDULER/MERGE ONLY:11/11, including missing/duplicate/wrong-shard/nonzero/missing-marker/process-timeout/aggregate-timeout rejection;4 workers, one180 budget, unique outputs and joined workers')
