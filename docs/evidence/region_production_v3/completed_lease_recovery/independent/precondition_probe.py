"""Independent collector precondition attacks on real temporary Git worktrees; simulated host payloads only."""
import importlib.util,json,os,pathlib,sys,fcntl,hashlib
from unittest.mock import patch
ROOT=pathlib.Path('/workspace/gunman-rush');sys.path.insert(0,str(ROOT/'tools'));import production_loop as loop
spec=importlib.util.spec_from_file_location('collector_fixture_contracts',ROOT/'tests/test_production_loop.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod);results={}
for mutation in ['expired_coherent_receipt','valid_nonce_without_matching_response','fake_implement_verdict_as_review','coherent_wrong_task_context','same_author','coherent_checklog_without_completion','changed_source','live_controller','exclusive_lock','wrong_feedback_checks','stage_quality_missing']:
 f=mod.CompletedReviewCollectionTests();f.setUp()
 try:
  mission,evidence,review=f.fixture(mutation,verdict='accept');q=json.loads((review/'host_request.json').read_text());r=json.loads((review/'host_response.json').read_text());state=json.loads((evidence/'state.json').read_text())
  if mutation=='expired_coherent_receipt':q['expires_at']=loop.time.time()-1
  elif mutation=='valid_nonce_without_matching_response':q['nonce']='c'*32
  elif mutation=='fake_implement_verdict_as_review':r['result']['status']='ready_for_review'
  elif mutation=='coherent_wrong_task_context':q['task_id']='ANOTHER_TASK'
  elif mutation=='same_author':r['agent_id']='/root/SIMULATED_author'
  elif mutation=='changed_source':(f.target/'tools/check_fixture.py').write_text('actual changed source\n')
  elif mutation=='wrong_feedback_checks':
   context=json.loads(q['feedback']);context['checks'][0]['status']='failed';q['feedback']=json.dumps(context)
  elif mutation=='coherent_checklog_without_completion':
   log=review.parent/'docs.log';log.write_text('no expected native completion\n');cp=review.parent/'checkpoint.json';v=json.loads(cp.read_text());v['check_logs']['docs']=hashlib.sha256(log.read_bytes()).hexdigest();loop.save(cp,v);state['tasks']['DRILL']['checkpoint']['sha256']=hashlib.sha256(cp.read_bytes()).hexdigest();loop.save(evidence/'state.json',state)
  elif mutation=='stage_quality_missing':
   m=json.loads(mission.read_text());m['tasks'][0].update(completion='stage',required_gates=['G0','G1'],quality_record='docs/quality/records/never_created.json');loop.save(mission,m);state['mission_hash']=loop.digest(m);loop.save(evidence/'state.json',state);q['task_contract']=m['tasks'][0]
  if mutation in ['expired_coherent_receipt','valid_nonce_without_matching_response','coherent_wrong_task_context','wrong_feedback_checks','stage_quality_missing']:
   q['request_hash']=loop.digest({k:v for k,v in q.items() if k!='request_hash'});loop.save(review/'host_request.json',q)
   if mutation!='valid_nonce_without_matching_response':r['request_hash']=q['request_hash']
   if mutation=='coherent_wrong_task_context':r['task_id']=q['task_id']
  loop.save(review/'host_response.json',r);before=(evidence/'state.json').read_bytes()
  try:
   with patch.object(loop,'ROOT',f.main):
    if mutation=='exclusive_lock':
     with (evidence/'lock').open('a') as lock:
      fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB);loop.collect_completed_review(mission,evidence,f.target,f.vanished_pid)
    else:loop.collect_completed_review(mission,evidence,f.target,os.getpid() if mutation=='live_controller' else f.vanished_pid)
   answer={'rejected':False}
  except Exception as e:answer={'rejected':True,'error':type(e).__name__+': '+str(e)}
  answer.update(state_original_bytes_preserved=(evidence/'state.json').read_bytes()==before,no_published_result=not (review/'result.json').exists(),no_published_invocation=not (review/'invocation.json').exists());results[mutation]=answer;print(mutation,answer['rejected'],answer['state_original_bytes_preserved'],flush=True)
 finally:f.doCleanups()
results['source_sha256']=hashlib.sha256((ROOT/'tools/production_loop.py').read_bytes()).hexdigest();(ROOT/'build/region_production_v3/independent/completed_lease_recovery/precondition_probe_results.json').write_text(json.dumps(results,indent=2)+'\n')
