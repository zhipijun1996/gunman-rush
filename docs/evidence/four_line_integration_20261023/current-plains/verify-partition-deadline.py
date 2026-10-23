import sys,importlib.util,json,hashlib,tempfile,shutil,types,threading,subprocess,ast
from pathlib import Path
from unittest.mock import patch
r=Path('/workspace/integration-four');sys.path.insert(0,str(r/'tools'))
spec=importlib.util.spec_from_file_location('scene_guard_actual',r/'tools/run_plains_redesign_scene_tests.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
raw=Path('/workspace/scratch/plains-scene-current-20261023/overlay/build/plains_redesign/scene/run_nc89i53z')
original=json.loads((raw/'positive-partitions.json').read_text());assert original['within_aggregate_deadline'] and original['aggregate_seconds']<180
oldtext=subprocess.check_output(['git','show','9a9eb8637e78d827af92f939466b485931e5bc17:tools/run_plains_redesign_scene_tests.py'],cwd=r,text=True)
node=next(x for x in ast.parse(oldtext).body if isinstance(x,ast.FunctionDef) and x.name=='run_positive');oldsrc=ast.get_source_segment(oldtext,node)
proof=[]
def verify(kind,old=False):
 folder=Path(tempfile.mkdtemp(prefix='deadline-probe-',dir=r/'build/verification'));count=0;lock=threading.Lock()
 def clock():
  nonlocal count
  with lock:count+=1;current=count
  return 0.0 if current<=3 else 100.0 if current==4 else 181.0 if kind=='aggregate_overrun' else 120.0
 def child(check,log,repo,env):
  shard=int(check['argv'][-1].split('=')[1]);data=json.loads((raw/f'positive-shard-{shard}.json').read_text())
  if kind=='missing_coverage' and shard==1:data['scene_case_indices']=[0,1,2,3]
  (folder/f'positive-shard-{shard}.json').write_text(json.dumps(data));Path(log).write_text('Offline replay of actual native output; no engine reexecuted.\n')
  result=dict(original['native_runs'][shard]['process'])
  if shard==1 and kind in ('nonzero_child','missing_marker','timeout_child'):
   result.update(status='timeout' if kind=='timeout_child' else 'failed',exit_code=1 if kind=='nonzero_child' else 0,failure_reason=kind)
  return result
 try:
  with patch.object(m.harness,'run_check',child),patch.object(m,'time',types.SimpleNamespace(monotonic=clock)):
   fn=m.run_positive
   if old:
    ns=dict(vars(m));exec(oldsrc,ns);fn=ns['run_positive']
   result=fn(folder,{})
  expected='passed' if kind=='normal' or old else 'failed';assert result['status']==expected,(kind,old,result['status'])
  proof.append({'case':kind,'reader':'old-S' if old else 'final-S2','status':result['status'],'injected_clock_seconds':result['actual_native_partitions']['aggregate_seconds'],'expected':expected,'correct':True})
 finally:shutil.rmtree(folder)
verify('aggregate_overrun',True)
for kind in ['normal','aggregate_overrun','nonzero_child','missing_marker','timeout_child','missing_coverage']:verify(kind)
result={'status':'passed','verification_kind':'Offline execution of actual partition function with retained real native outputs; child process outcome/clock fault injection only; NOT fresh native','implementation_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),'reader_sha256':hashlib.sha256((r/'tools/run_plains_redesign_scene_tests.py').read_bytes()).hexdigest(),'original_native_partition_proof_sha256':hashlib.sha256((raw/'positive-partitions.json').read_bytes()).hexdigest(),'actual_original_aggregate_seconds':original['aggregate_seconds'],'native_reexecuted':False,'cases':proof}
p=Path('/workspace/scratch/integration-four-20261023/final-plains/deadline-fault-injection.json');p.write_text(json.dumps(result,indent=2)+'\n');print('PASS old-overrun reproduced; final normal accepted and five partition failures rejected')
