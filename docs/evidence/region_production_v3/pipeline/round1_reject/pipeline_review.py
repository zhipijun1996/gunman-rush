"""Independent controller-only review. All fake workers/receipts are SIMULATED."""
import sys,json,hashlib,copy,subprocess,time
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path.cwd()/'tools'))
import production_loop as p
OUT=Path('build/region_production_v3/independent')
REQUEST=Path('build/verification/v3-pipeline/V3-PIPELINE-01/1/review/host_request.json')
req=json.loads(REQUEST.read_text())
sha=lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
results={'scope':'INDEPENDENT SIMULATED controller counterexamples; no model/game/host kill-resume execution','request_hash':req['request_hash'],'reviewer':'/root/v3_independent_engineering','cases':[]}
v=json.loads(Path('docs/evidence/region_production_v3/pipeline/verification.json').read_text())
results['source_sha256']={f:sha(f) for f in v['code_sha256']}
assert results['source_sha256']==v['code_sha256']
assert req['request_hash']==p.digest({k:v for k,v in req.items() if k!='request_hash'})
assert req['source_hash']==p.digest(p.snapshot())
assert all(sha(s['path'])==s['sha256'] for s in req['skills'])
results['request_source_and_skill_binding']='passed'
results['implementation_agent']=json.loads(Path('build/verification/v3-pipeline/V3-PIPELINE-01/1/implement/invocation.json').read_text())['agent_id']
assert results['implementation_agent']!=results['reviewer']
M={'schema_version':1,'objective':'SIMULATED independent controller review','max_calls':8,'max_rounds':2,'call_timeout_seconds':60,'tasks':[{'id':'DRILL','goal':'SIMULATED readonly','skills':['gameplay-reviewer'],'checks':['docs'],'read_only':True}]}
def fixture(root):
    calls=[]
    def simulated(task,mission,role,folder,feedback):
        calls.append(role)
        events=[{'type':'thread.started','thread_id':'SIMULATED-'+role},{'type':'turn.completed'}]
        (folder/'events.jsonl').write_text(''.join(json.dumps(e)+'\n' for e in events))
        p.save(folder/'invocation.json',{'kind':'actual_codex_exec','role':role,'exit_code':0,'timed_out':False,'turn_completed':True,'thread_ids':['SIMULATED-'+role],'event_errors':[],'launch_error':None,'events_sha256':sha(folder/'events.jsonl')})
        return {'status':'ready_for_review' if role=='implement' else 'accept','summary':'SIMULATED controller review','findings':[]}
    def check(config,log):
        log.write_text('PASS: SIMULATED independent controller completion\n')
        return {'status':'passed','exit_code':0}
    with patch.object(p.harness,'run_check',side_effect=check):
        state=p.run(M,root,simulated)
    assert state['status']=='complete'
    return state,simulated,calls
for mutation in ['log-bytes','invocation-bytes','rehash-log-no-marker','rehash-failed-exit','rehash-same-agent','budget-undercount','budget-overcount']:
    root=OUT/('case_'+mutation);root.mkdir()
    with patch.object(p,'snapshot',return_value={}):
        state,worker,calls=fixture(root)
        at=root/'DRILL/1';cp=at/'checkpoint.json';data=json.loads(cp.read_text())
        if mutation=='log-bytes':(at/'docs.log').write_text('CORRUPT no marker\n')
        elif mutation=='invocation-bytes':(at/'review/invocation.json').write_text('{}')
        elif mutation=='rehash-log-no-marker':
            (at/'docs.log').write_text('CORRUPT no marker\n');data['check_logs']['docs']=sha(at/'docs.log')
        elif mutation.startswith('rehash-'):
            path=at/'review/invocation.json';meta=json.loads(path.read_text())
            if mutation=='rehash-failed-exit':meta['exit_code']=1
            else:
                meta['thread_ids']=['SIMULATED-implement']
                (at/'review/events.jsonl').write_text(json.dumps({'type':'thread.started','thread_id':'SIMULATED-implement'})+'\n'+json.dumps({'type':'turn.completed'})+'\n')
                meta['events_sha256']=sha(at/'review/events.jsonl')
            p.save(path,meta);data['role_metadata']['review']=sha(path)
        elif mutation=='budget-undercount':state['calls']=1
        elif mutation=='budget-overcount':state['calls']=3
        if mutation.startswith('rehash-'):
            p.save(cp,data);state['tasks']['DRILL']['completion_checkpoint']['sha256']=sha(cp)
        p.save(root/'state.json',state)
        try:
            accepted=p.run(M,root,worker);case={'case':mutation,'rejected':False,'actual':accepted['status']}
        except ValueError as e:case={'case':mutation,'rejected':True,'error':str(e)}
        assert calls==['implement','review']
        results['cases'].append(case)
# Direct host transport: inject a response during the sleep between polling checks.
# This executes invoke_host, but the worker response is deliberately SIMULATED.
for mode in ['live-valid','expired-valid','revoked-and-response','wrong-nonce-hash']:
    root=OUT/('host_'+mode);root.mkdir()
    def respond(delay):
        request=json.loads((root/'host_request.json').read_text())
        response={'schema_version':1,**{k:request[k] for k in ['request_hash','task_id','attempt','role']},'agent_id':'/SIMULATED/independent','result':{'status':'accept','summary':'SIMULATED host response, not a real worker','findings':[]}}
        if mode=='wrong-nonce-hash':response['request_hash']='0'*64
        if mode=='revoked-and-response':p.save(root/'lease_revoked.json',{'request_hash':request['request_hash'],'revoked_at':time.time()})
        p.save(root/'host_response.json',response)
    now=100.0
    def monotonic():
        return now
    def sleep(delay):
        global now
        respond(delay)
        if mode=='expired-valid':now=200.0
    try:
        with patch.object(p,'snapshot',return_value={}),patch.object(p.time,'sleep',side_effect=sleep),patch.object(p.time,'monotonic',side_effect=monotonic):
            answer=p.invoke_host(M['tasks'][0],M,'review',root,'{}')
        case={'case':'host-'+mode,'accepted':True,'status':answer['status']}
    except (RuntimeError,ValueError) as e:case={'case':'host-'+mode,'accepted':False,'error':str(e)}
    results['cases'].append(case)
# Independent direct checks, preserving exact original command entries.
results['checks']=[]
for path in ['tests/test_production_loop.py','tests/test_level_design_routing.py','tests/test_level_region_context.py','tests/test_level_experience.py','tests/test_level_design_contracts.py']:
    start=time.monotonic();run=subprocess.run([sys.executable,path],capture_output=True,text=True,timeout=60)
    log=OUT/(Path(path).stem+'.log');log.write_text(run.stdout+run.stderr)
    results['checks'].append({'argv':[sys.executable,path],'exit_code':run.returncode,'seconds':round(time.monotonic()-start,3),'log':str(log),'sha256':sha(log),'tail':(run.stdout+run.stderr).splitlines()[-4:]})
results['source_unchanged']=results['source_sha256']=={f:sha(f) for f in results['source_sha256']}
results['request_source_unchanged']=req['source_hash']==p.digest(p.snapshot())
(OUT/'pipeline_review_results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(results,ensure_ascii=False,indent=2))
