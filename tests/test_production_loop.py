"""Controller contract tests with an explicit fake worker, never proof of AI review."""
import copy
import functools
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch, Mock
import subprocess
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import production_loop as loop

MISSION = {"schema_version":1,"objective":"isolated read-only drill", "max_calls":4,"max_rounds":2,"call_timeout_seconds":60,
           "tasks":[{"id":"DRILL", "goal":"inspect", "skills":["gameplay-reviewer"], "read_only":True,"checks":["docs"]}]}

# Only these explicitly decorated fake-worker/state-machine tests share this
# actual, readable input fixture. Input/source/dependency mutation and all real
# preflight/worktree tests retain the original production function untouched.
_STABLE_PREFLIGHT = None
_REAL_PREFLIGHT = loop.required_input_preflight

def frozen_controller_inputs(test):
    @functools.wraps(test)
    def run(self):
        global _STABLE_PREFLIGHT
        if _STABLE_PREFLIGHT is None:
            task = copy.deepcopy(MISSION['tasks'][0])
            observed = _REAL_PREFLIGHT(task)
            self.assertEqual(observed['status'], 'passed')
            _STABLE_PREFLIGHT = (loop.ROOT, task, observed)
        root, expected_task, observed = _STABLE_PREFLIGHT
        def fixture(task):
            # Different scope/checks, a changed ROOT, or a future extension is
            # never silently treated as the same readable input set.
            if loop.ROOT != root or task != expected_task:
                return _REAL_PREFLIGHT(task)
            return copy.deepcopy(observed)
        with patch.object(loop, 'required_input_preflight', side_effect=fixture):
            return test(self)
    return run

def tearDownModule():
    if _STABLE_PREFLIGHT is not None:
        root, task, observed = _STABLE_PREFLIGHT
        if loop.ROOT != root or _REAL_PREFLIGHT(task) != observed:
            raise AssertionError('Actual controller input preflight changed across semantic fixtures')

class LoopTests(unittest.TestCase):
    def run_case(self, statuses, mission=None, snapshots=None):
        mission=copy.deepcopy(mission or MISSION)
        calls=[]
        def worker(task,m,role,folder,feedback):
            calls.append(role)
            return {"status":statuses.pop(0),"summary":"SIMULATED worker", "findings":[]}
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(loop,'snapshot', side_effect=snapshots) if snapshots else patch.object(loop,'snapshot',return_value={"file":"hash"}):
                with patch.object(loop.harness,'run_check',return_value={"status":"passed","exit_code":0}):
                    state=loop.run(mission,Path(tmp),worker)
                    before=len(calls)
                    resumed=loop.run(mission,Path(tmp),worker)
                    self.assertEqual(len(calls),before)
                    self.assertEqual(resumed['status'],state['status'])
        return state,calls
    def test_region_validator_is_reloaded_after_actual_on_disk_worker_repair(self):
        # Actual file rewrite in a temporary project, not a mocked validator result.
        # A process-cached first-round module must not survive a second-round repair.
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);(root/'tools').mkdir()
            contracts=root/'tools/level_design_contracts.py'
            design=root/'tools/level_design.py'
            contracts.write_text("def validate_region_production_proof(*args): return ['first-round defect']\n")
            design.write_text("def source_files(): return {}\ndef engine_log_matches(*args): return True\n")
            with patch.object(loop,'ROOT',root):
                first,_,_=loop.current_region_validation()
                self.assertEqual(first(),['first-round defect'])
                contracts.write_text("def validate_region_production_proof(*args): return []\n")
                second,_,_=loop.current_region_validation()
                self.assertEqual(second(),[])
                self.assertEqual(first(),['first-round defect'])

    @frozen_controller_inputs
    def test_independent_role_and_resume(self):
        state,calls=self.run_case(['ready_for_review','accept'])
        self.assertEqual(calls,['implement','review']); self.assertEqual(state['status'],'complete')
    @frozen_controller_inputs
    def test_reject_no_progress(self):
        state,_=self.run_case(['ready_for_review','reject'])
        self.assertEqual(state['status'],'blocked')
        self.assertIn('No source progress',state['tasks']['DRILL']['history'][0]['stop_reason'])
    @frozen_controller_inputs
    def test_human_pending_not_done(self):
        state,calls=self.run_case(['awaiting_acceptance'])
        self.assertEqual(calls,['implement']); self.assertEqual(state['status'],'awaiting_acceptance')
    def test_budget_before_invocation(self):
        m=copy.deepcopy(MISSION);m['max_calls']=1
        state,calls=self.run_case([],m)
        self.assertEqual(state['status'],'budget_exhausted');self.assertFalse(calls)
    def test_invalid_dependency_and_path(self):
        for edit in ({'depends_on':['DRILL']},{'id':'../escape'},{'allowed_paths':['../outside']}):
            m=copy.deepcopy(MISSION);m['tasks'][0].update(edit)
            with self.assertRaises(ValueError):loop.validate(m)
    def test_stale_source_rejected(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(loop,'snapshot',return_value={}):
            state={"mission_hash":loop.digest(MISSION),"source_hash":"old"}
            (Path(tmp)/'state.json').write_text(json.dumps(state))
            with self.assertRaises(ValueError):loop.run(MISSION,Path(tmp))
    def test_read_only_mutation_blocked(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(loop,'snapshot',side_effect=[{}, {}, {}, {}, {'changed':'hash'}, {'changed':'hash'}]):
            with self.assertRaisesRegex(RuntimeError,'Read-only'):
                loop.run(MISSION,Path(tmp),lambda *a:{'status':'accept'})
            self.assertEqual(json.loads((Path(tmp)/'state.json').read_text())['status'],'blocked')
    def test_worker_error_retains_consumed_call(self):
        def fail(*a):raise RuntimeError('simulated timeout')
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}):
            with self.assertRaises(RuntimeError):loop.run(MISSION,Path(tmp),fail)
            state=json.loads((Path(tmp)/'state.json').read_text())
            self.assertEqual(state['calls'],1);self.assertEqual(state['status'],'blocked')

    def test_invoke_timeout_always_writes_metadata(self):
        # Fake OS process only; this is not a successful model invocation.
        process=Mock(pid=123,returncode=-9)
        process.communicate.side_effect=subprocess.TimeoutExpired('codex',60)
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop.subprocess,'Popen',return_value=process),patch('os.killpg') as kill:
            with self.assertRaisesRegex(RuntimeError,'timed out'):
                loop.invoke(MISSION['tasks'][0],MISSION,'review',Path(tmp),'')
            meta=json.loads((Path(tmp)/'invocation.json').read_text())
            self.assertTrue(meta['timed_out']);self.assertEqual(meta['exit_code'],-9)
            self.assertGreaterEqual(meta['seconds'],0);kill.assert_called_once()
            self.assertTrue((Path(tmp)/'events.jsonl').exists())
    def test_invoke_launch_error_keeps_attempt_evidence(self):
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop.subprocess,'Popen',side_effect=FileNotFoundError('codex absent')):
            with self.assertRaises(FileNotFoundError):loop.invoke(MISSION['tasks'][0],MISSION,'review',Path(tmp),'')
            meta=json.loads((Path(tmp)/'invocation.json').read_text())
            self.assertIsNone(meta['exit_code']);self.assertIn('codex absent',meta['launch_error'])
            self.assertFalse(meta['timed_out'])

    def test_role_cannot_self_accept_and_result_shape(self):
        for result in ({'status':'accept','summary':'self-pass','findings':[]},
                       {'status':'ready_for_review','summary':'','findings':[]},
                       {'status':'ready_for_review','summary':'ok','findings':[{}]},
                       {'status':'ready_for_review','summary':'ok','findings':[], 'extra':True}):
            with self.assertRaises(ValueError):loop.validate_result(result,'implement')

    def test_dependencies_deliver_real_prior_result_and_resume_no_calls(self):
        m=copy.deepcopy(MISSION)
        m['tasks'].append({**copy.deepcopy(m['tasks'][0]),'id':'NEXT','depends_on':['DRILL']})
        feedback=[]
        def worker(task,mission,role,folder,context):
            feedback.append((task['id'],role,json.loads(context)))
            return {'status':'ready_for_review' if role=='implement' else 'accept','summary':'SIMULATED '+task['id'],'findings':[]}
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}),patch.object(loop.harness,'run_check',return_value={'status':'passed'}):
            state=loop.run(m,Path(tmp),worker)
            self.assertEqual(state['status'],'complete')
            self.assertIn('SIMULATED DRILL',json.dumps(feedback[2][2]['dependencies']))
            loop.run(m,Path(tmp),worker)
            self.assertEqual(len(feedback),4)

    def test_failed_check_repair_carries_feedback_and_skips_review(self):
        m=copy.deepcopy(MISSION);m['tasks'][0].update(read_only=False,allowed_paths=['tools/sample'],quality_record='docs/quality/records/DRILL.json')
        source={};calls=[]
        def worker(task,mission,role,folder,feedback):
            calls.append(role)
            if role=='implement':
                source['tools/sample']=str(len(calls))
                if len(calls)>1:
                    prior=json.loads(feedback)['previous_rounds'][0]
                    self.assertEqual(prior['checks'][0]['status'],'failed')
                    self.assertEqual(prior['result']['status'],'reject')
            return {'status':'ready_for_review' if role=='implement' else 'accept','summary':'SIMULATED repair','findings':[]}
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',side_effect=lambda:dict(source)),patch.object(loop.harness,'run_check',side_effect=[{'status':'failed'},{'status':'passed'}]),patch.object(loop,'check_task_quality',return_value={'scope_complete':True,'content_complete':False}):
            state=loop.run(m,Path(tmp),worker)
            self.assertEqual(calls,['implement','implement','review'])
            self.assertEqual(state['status'],'complete')
            self.assertFalse(state['content_complete'])

    def test_failed_targeted_prefix_skips_expensive_successor_and_independent_task_continues(self):
        # SIMULATION of the scheduler only: real production runs are separate evidence.
        m=copy.deepcopy(MISSION);m['max_calls']=6
        m['tasks'][0]['checks']=['docs','quality-tests']
        other=copy.deepcopy(m['tasks'][0]);other['id']='INDEPENDENT';other['checks']=['world']
        m['tasks'].append(other);executed=[];roles=[]
        def check(contract, log):
            executed.append(contract['argv'][1]);log.write_text('SIMULATED scheduling check')
            return {'status':'failed' if len(executed)==1 else 'passed'}
        def worker(task,mission,role,*unused):
            roles.append((task['id'],role))
            return {'status':'ready_for_review' if role=='implement' else 'accept','summary':'SIMULATED scheduling','findings':[]}
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}),patch.object(loop.harness,'run_check',side_effect=check):
            state=loop.run(m,Path(tmp),worker)
            self.assertEqual(executed,['tools/check_docs.py','tools/check_world_design.py'])
            self.assertEqual(roles,[('DRILL','implement'),('INDEPENDENT','implement'),('INDEPENDENT','review')])
            self.assertEqual(state['calls'],3)
            self.assertEqual(state['tasks']['INDEPENDENT']['status'],'complete')
            self.assertEqual(state['tasks']['DRILL']['history'][0]['checks'][0]['status'],'failed')

    def test_task_budget_caps_rework_without_refunding_failed_calls(self):
        # SIMULATION proves budget enforcement, not AI production success.
        m=copy.deepcopy(MISSION);m['tasks'][0].update(read_only=False,allowed_paths=['tools/sample'],quality_record='docs/quality/records/DRILL.json',max_calls=2)
        source={};roles=[]
        def worker(task,mission,role,*unused):
            roles.append(role)
            if role=='implement':source['tools/sample']='changed'
            return {'status':'ready_for_review' if role=='implement' else 'reject','summary':'SIMULATED rejected asset','findings':[]}
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',side_effect=lambda:dict(source)),patch.object(loop.harness,'run_check',return_value={'status':'passed'}):
            state=loop.run(m,Path(tmp),worker)
            self.assertEqual(roles,['implement','review']);self.assertEqual(state['calls'],2)
            self.assertEqual(state['status'],'budget_exhausted')
            self.assertEqual(loop.task_calls(m['tasks'][0],Path(tmp)),2)
        m['tasks'][0]['max_calls']=True
        with self.assertRaisesRegex(ValueError,'Task max_calls'):loop.validate(m)

    def test_source_mutation_during_check_rejected(self):
        source={}
        def check(*a):source['external']='change';return {'status':'passed'}
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',side_effect=lambda:dict(source)),patch.object(loop.harness,'run_check',side_effect=check):
            with self.assertRaisesRegex(RuntimeError,'during harness'):
                loop.run(MISSION,Path(tmp),lambda *a:{'status':'ready_for_review','summary':'SIMULATED','findings':[]})

    def test_independent_reject_is_reworked_with_original_findings(self):
        m=copy.deepcopy(MISSION);m['tasks'][0].update(read_only=False,allowed_paths=['tools/sample'],quality_record='docs/quality/records/DRILL.json')
        source={};roles=[]
        def worker(task,mission,role,folder,feedback):
            roles.append(role)
            if role=='implement':
                source['tools/sample']=str(len(roles))
                if len(roles)==3:
                    self.assertEqual(json.loads(feedback)['previous_rounds'][0]['roles']['review']['findings'],['SIMULATED counterexample'])
            status='ready_for_review' if role=='implement' else 'reject' if len(roles)==2 else 'accept'
            return {'status':status,'summary':'SIMULATED bounded rework','findings':['SIMULATED counterexample'] if status=='reject' else []}
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',side_effect=lambda:dict(source)),patch.object(loop.harness,'run_check',return_value={'status':'passed'}),patch.object(loop,'check_task_quality',return_value={'scope_complete':True,'content_complete':False}):
            state=loop.run(m,Path(tmp),worker)
            self.assertEqual(roles,['implement','review','implement','review'])
            self.assertEqual(state['calls'],4);self.assertEqual(state['status'],'complete')
            self.assertEqual(len(state['tasks']['DRILL']['history']),2)

    def test_incomplete_content_stops_after_technical_review(self):
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}),patch.object(loop.harness,'run_check',return_value={'status':'passed'}),patch.object(loop,'check_task_quality',return_value={'scope_complete':False,'content_complete':False,'quality':{'blockers':['G5 device unverified']}}):
            def worker(task,mission,role,*unused):
                return {'status':'ready_for_review' if role=='implement' else 'accept','summary':'SIMULATED','findings':[]}
            state=loop.run(MISSION,Path(tmp),worker)
            self.assertEqual(state['status'],'awaiting_acceptance')
            self.assertFalse(state['content_complete'])

    def test_interrupted_call_stays_blocked_and_consumes_budget(self):
        state={'mission_hash':loop.digest(MISSION),'source_hash':loop.digest({}),'worker_mode':'invoke','calls':1,'tasks':{'DRILL':{'rounds':1}},'status':'running','active_call':{'role':'implement'}}
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}):
            (Path(tmp)/'DRILL/1/implement').mkdir(parents=True)
            (Path(tmp)/'state.json').write_text(json.dumps(state))
            resumed=loop.run(MISSION,Path(tmp))
            self.assertEqual(resumed['status'],'blocked');self.assertEqual(resumed['calls'],1)

    def test_modified_restored_call_budget_rejected_without_repair(self):
        calls=[]
        def worker(task,mission,role,*unused):
            calls.append(role)
            return {'status':'ready_for_review' if role=='implement' else 'accept','summary':'SIMULATED','findings':[]}
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}),patch.object(loop.harness,'run_check',return_value={'status':'passed'}):
            folder=Path(tmp);state=loop.run(MISSION,folder,worker)
            self.assertEqual(loop.run(MISSION,folder,worker)['calls'],2)
            self.assertEqual(len(calls),2)
            for edited in (0,1,3,-1,True,2.0,'2',MISSION['max_calls']+1):
                with self.subTest(calls=edited):
                    bad=copy.deepcopy(state);bad['calls']=edited
                    original=json.dumps(bad);(folder/'state.json').write_text(original)
                    with self.assertRaisesRegex(ValueError,'Restored calls'):
                        loop.run(MISSION,folder,worker)
                    self.assertEqual((folder/'state.json').read_text(),original)
                    self.assertEqual(len(calls),2)

    def test_malformed_restored_rounds_rejected_without_repair(self):
        def worker(task,mission,role,*unused):
            return {'status':'ready_for_review' if role=='implement' else 'accept','summary':'SIMULATED','findings':[]}
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}),patch.object(loop.harness,'run_check',return_value={'status':'passed'}):
            folder=Path(tmp);state=loop.run(MISSION,folder,worker)
            for rounds in (-1,True,1.5,'1',3,0):
                with self.subTest(rounds=rounds):
                    bad=copy.deepcopy(state);bad['tasks']['DRILL']['rounds']=rounds
                    original=json.dumps(bad);(folder/'state.json').write_text(original)
                    with self.assertRaisesRegex(ValueError,'round'):
                        loop.run(MISSION,folder,worker)
                    self.assertEqual((folder/'state.json').read_text(),original)

    def test_malformed_mission_budget_and_round_types_rejected(self):
        for key in ('max_calls','max_rounds','call_timeout_seconds'):
            for value in (True,1.5,'2',-1):
                with self.subTest(key=key,value=value):
                    mission=copy.deepcopy(MISSION);mission[key]=value
                    with self.assertRaises(ValueError):loop.validate(mission)

    def test_renamed_allocated_round_is_not_ignored(self):
        state={'calls':1,'tasks':{'DRILL':{'rounds':1}}}
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);(folder/'DRILL/not-a-round/implement').mkdir(parents=True)
            with self.assertRaisesRegex(ValueError,'malformed round'):
                loop.validate_restored_budget(MISSION,state,folder)

    def test_empty_complete_state_cannot_skip_declared_tasks(self):
        state={'schema_version':1,'mission_hash':loop.digest(MISSION),'source_hash':loop.digest({}),
               'worker_mode':'invoke','calls':0,'tasks':{},'status':'complete','content_complete':False}
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}):
            folder=Path(tmp);original=json.dumps(state);(folder/'state.json').write_text(original)
            with self.assertRaisesRegex(ValueError,'completed declared tasks'):
                loop.run(MISSION,folder)
            self.assertEqual((folder/'state.json').read_text(),original)

    def completed_fixture(self, folder, mission=None):
        mission=mission or MISSION
        def worker(task,m,role,*unused):
            return {'status':'ready_for_review' if role=='implement' else 'accept','summary':'SIMULATED completion','findings':[]}
        with patch.object(loop.harness,'run_check',return_value={'status':'passed'}):
            return loop.run(mission,folder,worker),worker

    @frozen_controller_inputs
    def test_complete_resume_rejects_incomplete_history_checks_and_quality(self):
        edits={
            'history':lambda e:e.update(history=[]),
            'lost-round':lambda e:e.update(rounds=2),
            'roles':lambda e:e['history'][-1].update(roles={}),
            'review-reject':lambda e:e['history'][-1]['roles']['review'].update(status='reject'),
            'checks-missing':lambda e:e['history'][-1].update(checks=[]),
            'checks-other':lambda e:e['history'][-1]['checks'][0].update(id='other'),
            'checks-failed':lambda e:e['history'][-1]['checks'][0].update(status='failed'),
            'quality-missing':lambda e:e['history'][-1].pop('quality'),
            'quality-incomplete':lambda e:e['history'][-1]['quality'].update(scope_complete=False),
        }
        for name,edit in edits.items():
            with self.subTest(edit=name),tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}):
                folder=Path(tmp);state,worker=self.completed_fixture(folder)
                edit(state['tasks']['DRILL'])
                original=json.dumps(state);(folder/'state.json').write_text(original)
                with self.assertRaises(ValueError):loop.run(MISSION,folder,worker)
                self.assertEqual((folder/'state.json').read_text(),original)

    @frozen_controller_inputs
    def test_complete_resume_rejects_missing_moved_or_modified_role_results(self):
        for role in ('implement','review'):
            for mutation in ('delete','move','change'):
                with self.subTest(role=role,mutation=mutation),tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}):
                    folder=Path(tmp);state,worker=self.completed_fixture(folder)
                    original=(folder/'state.json').read_text()
                    result=folder/'DRILL/1'/role/'result.json'
                    if mutation=='delete':result.unlink()
                    elif mutation=='move':result.rename(result.with_suffix('.moved'))
                    else:
                        value=json.loads(result.read_text());value['summary']='modified response';result.write_text(json.dumps(value))
                    with self.assertRaisesRegex(ValueError,'role result'):
                        loop.run(MISSION,folder,worker)
                    self.assertEqual((folder/'state.json').read_text(),original)

    def test_complete_dependency_cannot_be_incomplete_on_resume(self):
        mission=copy.deepcopy(MISSION)
        mission['tasks'].append({**copy.deepcopy(mission['tasks'][0]),'id':'NEXT','depends_on':['DRILL']})
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}):
            folder=Path(tmp);state,worker=self.completed_fixture(folder,mission)
            state['status']='running';state['tasks']['DRILL']['status']='pending'
            original=json.dumps(state);(folder/'state.json').write_text(original)
            with self.assertRaisesRegex(ValueError,'incomplete dependency'):
                loop.run(mission,folder,worker)
            self.assertEqual((folder/'state.json').read_text(),original)

    def test_complete_resume_rechecks_current_final_scope_quality(self):
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}):
            folder=Path(tmp);state,worker=self.completed_fixture(folder)
            original=(folder/'state.json').read_text()
            with patch.object(loop,'check_task_quality',return_value={'scope_complete':False}):
                with self.assertRaisesRegex(ValueError,'current scope quality'):
                    loop.run(MISSION,folder,worker)
            self.assertEqual((folder/'state.json').read_text(),original)

    def test_scope_resume_cannot_forge_full_content_completion(self):
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}):
            folder=Path(tmp);state,worker=self.completed_fixture(folder)
            state['content_complete']=True
            original=json.dumps(state);(folder/'state.json').write_text(original)
            with self.assertRaisesRegex(ValueError,'content completion'):
                loop.run(MISSION,folder,worker)
            self.assertEqual((folder/'state.json').read_text(),original)

    def host_case(self, edit=None):
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}):
            folder=Path(tmp)
            def respond(*a):
                request=json.loads((folder/'host_request.json').read_text())
                response={key:request[key] for key in ('schema_version','request_hash','task_id','attempt','role')}
                response.update(agent_id='/root/simulated_unit_worker',result={'status':'ready_for_review','summary':'SIMULATED host transport only','findings':[]})
                if edit:edit(response)
                loop.save(folder/'host_response.json',response)
            with patch.object(loop.time,'sleep',side_effect=respond):
                result=loop.invoke_host(MISSION['tasks'][0],MISSION,'implement',folder,'{"dependencies":{}}')
            meta=json.loads((folder/'invocation.json').read_text())
            self.assertEqual(meta['kind'],'actual_host_codex_agent')
            self.assertEqual(meta['agent_id'],'/root/simulated_unit_worker')
            self.assertEqual(meta['lease_status'],'completed')
            return result

    def test_host_adapter_binding_and_role(self):
        self.assertEqual(self.host_case()['status'],'ready_for_review')
        for key in ('request_hash','task_id','attempt','role'):
            with self.subTest(key=key),self.assertRaisesRegex(ValueError,'does not match'):
                self.host_case(lambda response:response.update({key:'wrong'}))
        with self.assertRaisesRegex(ValueError,'Invalid implement'):
            self.host_case(lambda r:r['result'].update(status='accept'))

    def test_host_timeout_and_stale_response_rejected(self):
        m=copy.deepcopy(MISSION);m['call_timeout_seconds']=1
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}),patch.object(loop.time,'monotonic',side_effect=[0,2,2]):
            folder=Path(tmp)
            with self.assertRaisesRegex(RuntimeError,'timed out'):
                loop.invoke_host(m['tasks'][0],m,'implement',folder,'')
            meta=json.loads((folder/'invocation.json').read_text());self.assertTrue(meta['timed_out'])
            self.assertEqual(meta['lease_status'],'expired')
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}):
            folder=Path(tmp);(folder/'host_response.json').write_text('{}')
            with self.assertRaisesRegex(RuntimeError,'never reuse'):
                loop.invoke_host(MISSION['tasks'][0],MISSION,'implement',folder,'')

    def test_same_host_agent_cannot_review_itself(self):
        def worker(task,mission,role,folder,feedback):
            loop.save(folder/'invocation.json',{'kind':'actual_host_codex_agent','agent_id':'/root/simulated_same'})
            return {'status':'ready_for_review' if role=='implement' else 'accept','summary':'SIMULATED','findings':[]}
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}),patch.object(loop.harness,'run_check',return_value={'status':'passed'}):
            with self.assertRaisesRegex(RuntimeError,'same agent'):
                loop.run(MISSION,Path(tmp),worker)

    def test_prior_round_implementer_cannot_review_later_round(self):
        for identity_kind in ('agent','thread'):
            for last_reviewer in ('author-one','independent-two'):
                with self.subTest(identity=identity_kind,reviewer=last_reviewer):
                    mission=copy.deepcopy(MISSION);mission['tasks'][0].update(read_only=False,allowed_paths=['tools/sample'],quality_record='docs/quality/records/DRILL.json')
                    source={};calls=[]
                    def worker(task,m,role,folder,feedback):
                        calls.append(role)
                        actor=['author-one','independent-one','author-two',last_reviewer][len(calls)-1]
                        meta={'agent_id':'/root/'+actor} if identity_kind=='agent' else {'thread_ids':[actor]}
                        loop.save(folder/'invocation.json',meta)
                        if role=='implement':source['tools/sample']=str(len(calls))
                        return {'status':'ready_for_review' if role=='implement' else 'reject' if len(calls)==2 else 'accept','summary':'SIMULATED','findings':[]}
                    with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',side_effect=lambda:dict(source)),patch.object(loop.harness,'run_check',return_value={'status':'passed'}),patch.object(loop,'check_task_quality',return_value={'scope_complete':True,'content_complete':False}):
                        if last_reviewer=='author-one':
                            with self.assertRaisesRegex(RuntimeError,'previously implemented'):
                                loop.run(mission,Path(tmp),worker)
                            self.assertEqual(json.loads((Path(tmp)/'state.json').read_text())['status'],'blocked')
                        else:
                            state=loop.run(mission,Path(tmp),worker)
                            self.assertEqual(state['status'],'complete')
                            self.assertEqual(loop.run(mission,Path(tmp),worker)['calls'],4)

    def test_prior_task_implementer_cannot_review_dependent_task(self):
        mission=copy.deepcopy(MISSION)
        mission['tasks'].append({**copy.deepcopy(mission['tasks'][0]),'id':'NEXT','depends_on':['DRILL']})
        def worker(task,m,role,folder,feedback):
            actor={('DRILL','implement'):'author-one',('DRILL','review'):'independent-one',('NEXT','implement'):'author-two',('NEXT','review'):'author-one'}[(task['id'],role)]
            loop.save(folder/'invocation.json',{'agent_id':'/root/'+actor})
            return {'status':'ready_for_review' if role=='implement' else 'accept','summary':'SIMULATED','findings':[]}
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}),patch.object(loop.harness,'run_check',return_value={'status':'passed'}):
            with self.assertRaisesRegex(RuntimeError,'previously implemented'):
                loop.run(mission,Path(tmp),worker)

    def test_route_stage_and_final_content_are_distinct(self):
        from level_design import route_request
        m=route_request('优化风铃平原')
        loop.validate(m)
        self.assertEqual(m['tasks'][1]['completion'],'stage')
        self.assertEqual(m['tasks'][1]['required_gates'],['G0'])
        self.assertEqual(m['tasks'][-1]['completion'],'content')
        self.assertEqual(m['tasks'][-1]['quality_task_id'],m['tasks'][-2]['id'])

    def test_route_prepares_registered_context_and_scoped_lessons(self):
        from level_design import route_request
        for request,region_id in [('优化风铃平原','windchime_plains'),('制作荆棘森林','thorn_forest')]:
            with self.subTest(region=region_id),patch('level_experience.load_lessons',return_value=[{'source_kind':'design_review','limits':'SIMULATED scoped lesson, not player approval'}]) as loader:
                mission=route_request(request)
                self.assertEqual(mission['preparation']['region_context']['region_id'],region_id)
                self.assertIsNone(mission['preparation']['region_context']['implementation']['runtime_available'])
                loader.assert_called_once_with(region_id)
                self.assertEqual(mission['preparation']['lessons'][0]['source_kind'],'design_review')
                with tempfile.TemporaryDirectory() as tmp:
                    prompt,*_=loop.prepare_call(mission['tasks'][0],mission,'implement',Path(tmp),'{}')
                    self.assertIn('SIMULATED scoped lesson',prompt)
                    self.assertIn(region_id,prompt)

    def test_unknown_region_never_inherits_plains(self):
        from level_design import route_request
        mission=route_request('制作未知的地下河地区')
        context=mission['preparation']['region_context']
        self.assertIsNone(context['region_id']);self.assertEqual(context['status'],'unregistered')
        self.assertEqual(mission['preparation']['lessons'],[])

    def test_invalid_lessons_and_ambiguous_regions_fail_closed(self):
        from level_design import route_request
        with patch('level_experience.load_lessons',side_effect=ValueError('lesson evidence mismatch')):
            with self.assertRaisesRegex(ValueError,'lesson evidence mismatch'):
                route_request('优化风铃平原')
        with self.assertRaises(ValueError):
            route_request('制作荆棘森林和风铃平原')

    def test_stage_quality_never_becomes_content_acceptance(self):
        task={'id':'STAGE','completion':'stage','quality_record':'fake','required_gates':['G0']}
        record={'task_id':'STAGE','production_snapshot':loop.digest({}),'deliverables':['spec'],'affected_paths':['docs/spec'],
                'gates':{'G0':{'status':'passed'}},'criteria':[{'gate':'G0','status':'passed'}],'creative_decisions':[]}
        validation={'errors':[],'blockers':['G5 unverified'],'verdict':'UNVERIFIED','task_complete':False}
        with patch.object(loop.quality,'local_file',return_value=Path('fake')),patch.object(loop.quality,'read_json',return_value=record),patch.object(loop.quality,'validate_record',side_effect=lambda r, **kwargs:copy.deepcopy(validation)),patch.object(loop,'snapshot',return_value={}):
            result=loop.check_task_quality(task)
            self.assertTrue(result['scope_complete']);self.assertFalse(result['content_complete'])
            record['gates']['G0']['status']='unverified'
            self.assertFalse(loop.check_task_quality(task)['scope_complete'])
            record['gates']['G0']['status']='passed';record['production_snapshot']='stale'
            self.assertFalse(loop.check_task_quality(task)['scope_complete'])

class PhaseRecoveryTests(unittest.TestCase):
    """Simulated controller contracts; no worker/engine/host execution claim."""

    def worker(self, calls):
        def simulated(task, mission, role, folder, feedback):
            calls.append((task['id'], role, folder.name))
            return {'status': 'ready_for_review' if role == 'implement' else 'accept',
                    'summary': 'SIMULATED phase contract', 'findings': []}
        return simulated

    def test_host_revocation_races_response_parse_validation_and_result_commit(self):
        # Production consumer with SIMULATED response/cancellation transport only.
        for race in ('poll','parse','validation','result-write'):
            with self.subTest(race=race),tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}):
                folder=Path(tmp);original_save=loop.save;original_read=loop.quality.read_json;original_validate=loop.validate_result
                def revoke():
                    request=original_read(folder/'host_request.json')
                    original_save(folder/'lease_revoked.json',{'request_hash':request['request_hash'],'reason':'SIMULATED lease race'})
                def respond(delay):
                    request=original_read(folder/'host_request.json')
                    response={k:request[k] for k in ('schema_version','request_hash','task_id','attempt','role')}
                    response.update(agent_id='/root/simulated_race_review',result={'status':'accept','summary':'SIMULATED revoked response','findings':[]})
                    if race=='poll':revoke()
                    original_save(folder/'host_response.json',response)
                def read(path):
                    data=original_read(path)
                    if path==folder/'host_response.json' and race=='parse':revoke()
                    return data
                def validate(result,role):
                    valid=original_validate(result,role)
                    if race=='validation':revoke()
                    return valid
                def save(path,data):
                    original_save(path,data)
                    if path==folder/'result.json' and race=='result-write':revoke()
                with patch.object(loop.time,'sleep',side_effect=respond),patch.object(loop.quality,'read_json',side_effect=read),patch.object(loop,'validate_result',side_effect=validate),patch.object(loop,'save',side_effect=save):
                    with self.assertRaisesRegex(RuntimeError,'lease revoked'):
                        loop.invoke_host(MISSION['tasks'][0],MISSION,'review',folder,'{}')
                meta=original_read(folder/'invocation.json')
                self.assertEqual(meta['lease_status'],'failed');self.assertIsNone(meta['exit_code'])
                self.assertTrue(meta['revoked']);self.assertFalse((folder/'result.json').exists())
                self.assertEqual((folder/'rejected_result.json').exists(),race=='result-write')

    def test_host_expiry_is_rechecked_after_response_read_and_result_write(self):
        # Both monotonic budget and absolute request deadline remain authoritative.
        for race in ('parse','result-write'):
            with self.subTest(race=race),tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}):
                folder=Path(tmp);wall=[100.0];original_read=loop.quality.read_json;original_save=loop.save
                def respond(delay):
                    request=original_read(folder/'host_request.json')
                    response={k:request[k] for k in ('schema_version','request_hash','task_id','attempt','role')}
                    response.update(agent_id='/root/simulated_expiry_review',result={'status':'accept','summary':'SIMULATED expired response','findings':[]})
                    original_save(folder/'host_response.json',response)
                def read(path):
                    data=original_read(path)
                    if path==folder/'host_response.json' and race=='parse':wall[0]=200.0
                    return data
                def save(path,data):
                    original_save(path,data)
                    if path==folder/'result.json' and race=='result-write':wall[0]=200.0
                with patch.object(loop.time,'monotonic',return_value=0.0),patch.object(loop.time,'time',side_effect=lambda:wall[0]),patch.object(loop.time,'sleep',side_effect=respond),patch.object(loop.quality,'read_json',side_effect=read),patch.object(loop,'save',side_effect=save):
                    with self.assertRaisesRegex(RuntimeError,'lease expired'):
                        loop.invoke_host(MISSION['tasks'][0],MISSION,'review',folder,'{}')
                meta=original_read(folder/'invocation.json')
                self.assertEqual(meta['lease_status'],'expired');self.assertTrue(meta['timed_out'])
                self.assertIsNone(meta['exit_code']);self.assertFalse((folder/'result.json').exists())
                self.assertEqual((folder/'rejected_result.json').exists(),race=='result-write')

    def test_passed_shared_checks_cannot_accept_missing_forest_native_proof(self):
        task={'id':'FOREST','completion':'stage','quality_record':'fake','required_gates':['G0'],
              'region_proof':{'region_id':'thorn_forest','kind':'boss','scope':'prototype'}}
        record={'task_id':'FOREST','production_snapshot':loop.digest({}),'deliverables':['spec'],'affected_paths':['docs/spec'],
                'gates':{'G0':{'status':'passed'}},'criteria':[{'gate':'G0','status':'passed'}],'creative_decisions':[]}
        validation={'errors':[],'verdict':'UNVERIFIED','task_complete':False}
        with patch.object(loop.quality,'local_file',return_value=Path('fake')),patch.object(loop.quality,'read_json',return_value=record),patch.object(loop.quality,'validate_record',side_effect=lambda r, **kwargs:copy.deepcopy(validation)),patch.object(loop,'snapshot',return_value={}):
            acceptance=loop.check_task_quality(task)
        self.assertFalse(acceptance['scope_complete']);self.assertFalse(acceptance['content_complete'])
        self.assertIn('Missing region-specific native proof',' '.join(acceptance['quality']['errors']))

    def completed_metadata_fixture(self, folder):
        # Synthetic CLI metadata/event fixtures, never an actual model invocation.
        calls=[]
        def simulated(task,m,role,directory,feedback):
            calls.append(role)
            events=[{'type':'thread.started','thread_id':'simulated-'+role},{'type':'turn.completed'}]
            (directory/'events.jsonl').write_text(''.join(json.dumps(e)+'\n' for e in events))
            loop.save(directory/'invocation.json',{'kind':'actual_codex_exec','role':role,'exit_code':0,
                'timed_out':False,'turn_completed':True,'thread_ids':['simulated-'+role],
                'event_errors':[],'launch_error':None,
                'events_sha256':loop.hashlib.sha256((directory/'events.jsonl').read_bytes()).hexdigest()})
            return {'status':'ready_for_review' if role=='implement' else 'accept',
                    'summary':'SIMULATED retained invocation audit fixture','findings':[]}
        def check(config,path):
            path.write_text('PASS: SIMULATED native-independent controller log\n')
            return {'status':'passed','exit_code':0}
        with patch.object(loop.harness,'run_check',side_effect=check):
            state=loop.run(MISSION,folder,simulated)
        self.assertEqual(state['status'],'complete')
        return state,simulated,calls

    def test_finished_completion_rejects_log_and_invocation_byte_changes(self):
        for artifact in ('docs.log','review/invocation.json','review/events.jsonl'):
            with self.subTest(artifact=artifact),tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}):
                folder=Path(tmp);state,worker,calls=self.completed_metadata_fixture(folder)
                self.assertEqual(loop.run(MISSION,folder,worker)['status'],'complete')
                (folder/'DRILL/1'/artifact).write_text('SIMULATED corrupt retained artifact')
                before=(folder/'state.json').read_text()
                with self.assertRaises(ValueError):loop.run(MISSION,folder,worker)
                self.assertEqual((folder/'state.json').read_text(),before)
                self.assertEqual(calls,['implement','review'])

    def test_real_transport_cannot_omit_checkpoint_invocation_or_check_bindings(self):
        for missing in ('role_metadata','check_logs'):
            with self.subTest(missing=missing),tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}):
                folder=Path(tmp);state,worker,calls=self.completed_metadata_fixture(folder)
                entry=state['tasks']['DRILL']
                loop._restore_checkpoint(MISSION['tasks'][0],entry,folder,reference='completion_checkpoint',verify_source=False,worker_mode='invoke')
                path=folder/'DRILL/1/checkpoint.json';data=json.loads(path.read_text());data[missing]={}
                loop.save(path,data);entry['completion_checkpoint']['sha256']=loop.hashlib.sha256(path.read_bytes()).hexdigest()
                with self.assertRaisesRegex(ValueError,'complete invocation/check-log bindings'):
                    loop._restore_checkpoint(MISSION['tasks'][0],entry,folder,reference='completion_checkpoint',verify_source=False,worker_mode='invoke')

    def test_finished_completion_rechecks_termination_identity_and_success_marker_even_if_rehashed(self):
        for mutation in ('failed-invocation','same-identity','no-check-completion'):
            with self.subTest(mutation=mutation),tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}):
                folder=Path(tmp);state,worker,calls=self.completed_metadata_fixture(folder)
                attempt=folder/'DRILL/1';checkpoint=attempt/'checkpoint.json'
                data=json.loads(checkpoint.read_text())
                if mutation=='no-check-completion':
                    (attempt/'docs.log').write_text('SIMULATED no completion marker')
                    data['check_logs']['docs']=loop.hashlib.sha256((attempt/'docs.log').read_bytes()).hexdigest()
                else:
                    path=attempt/'review/invocation.json';meta=json.loads(path.read_text())
                    if mutation=='failed-invocation':meta['exit_code']=1
                    else:
                        meta['thread_ids']=['simulated-implement']
                        events=attempt/'review/events.jsonl'
                        events.write_text(json.dumps({'type':'thread.started','thread_id':'simulated-implement'})+'\n'+json.dumps({'type':'turn.completed'})+'\n')
                        meta['events_sha256']=loop.hashlib.sha256(events.read_bytes()).hexdigest()
                    loop.save(path,meta)
                    data['role_metadata']['review']=loop.hashlib.sha256(path.read_bytes()).hexdigest()
                loop.save(checkpoint,data)
                state['tasks']['DRILL']['completion_checkpoint']['sha256']=loop.hashlib.sha256(checkpoint.read_bytes()).hexdigest()
                loop.save(folder/'state.json',state);before=(folder/'state.json').read_text()
                with self.assertRaises(ValueError):loop.run(MISSION,folder,worker)
                self.assertEqual((folder/'state.json').read_text(),before)
                self.assertEqual(calls,['implement','review'])

    def test_clean_implement_and_checks_checkpoint_resume_without_reimplementation(self):
        for phase in ('implement', 'checks'):
            with self.subTest(phase=phase), tempfile.TemporaryDirectory() as tmp, patch.object(loop, 'snapshot', return_value={}):
                calls=[]; worker=self.worker(calls); folder=Path(tmp)
                with patch.object(loop.harness, 'run_check', return_value={'status':'passed'}) as check:
                    paused=loop.run(MISSION,folder,worker,stop_after_phase=phase)
                    self.assertEqual(paused['status'],'paused');self.assertEqual(paused['calls'],1)
                    self.assertIn('checkpoint',paused['tasks']['DRILL'])
                    resumed=loop.run(MISSION,folder,worker)
                    self.assertEqual(resumed['status'],'complete');self.assertEqual(resumed['calls'],2)
                    self.assertEqual([r for _,r,_ in calls],['implement','review'])
                    self.assertEqual(check.call_count,1)

    def test_checkpoint_rejects_changed_result_metadata_log_and_checkpoint(self):
        for artifact in ('result.json','invocation.json','docs.log','checkpoint.json'):
            with self.subTest(artifact=artifact), tempfile.TemporaryDirectory() as tmp, patch.object(loop,'snapshot',return_value={}):
                folder=Path(tmp);calls=[];base=self.worker(calls)
                def worker(task,m,role,directory,feedback):
                    loop.save(directory/'invocation.json',{'kind':'simulated_contract_test','agent_id':'/root/simulated_'+role})
                    return base(task,m,role,directory,feedback)
                def check(config,log):
                    log.write_text('SIMULATED check log');return {'status':'passed'}
                with patch.object(loop.harness,'run_check',side_effect=check):
                    loop.run(MISSION,folder,worker,stop_after_phase='checks')
                path=folder/'DRILL/1'/artifact
                if artifact in {'result.json','invocation.json'}:path=path.parent/'implement'/artifact
                path.write_text('{}')
                original=(folder/'state.json').read_text()
                with self.assertRaisesRegex(ValueError,'Checkpoint'):
                    loop.run(MISSION,folder,worker)
                self.assertEqual((folder/'state.json').read_text(),original)
                self.assertEqual(len(calls),1)

    def test_partial_check_checkpoint_only_reruns_interrupted_check(self):
        mission=copy.deepcopy(MISSION);mission['tasks'][0]['checks']=['docs','world']
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}):
            folder=Path(tmp);calls=[];worker=self.worker(calls);checks=[]
            def check(config,path):
                checks.append(path.stem)
                if len(checks)==2:raise KeyboardInterrupt('SIMULATED interrupted check')
                return {'status':'passed'}
            with patch.object(loop.harness,'run_check',side_effect=check):
                with self.assertRaises(KeyboardInterrupt):loop.run(mission,folder,worker)
                state=loop.run(mission,folder,worker)
            self.assertEqual(checks,['docs','world','world'])
            self.assertEqual(state['calls'],2);self.assertEqual(state['status'],'complete')

    def test_independent_package_continues_and_only_descendant_blocks(self):
        mission=copy.deepcopy(MISSION);mission['max_calls']=8
        mission['tasks'] += [{**copy.deepcopy(mission['tasks'][0]),'id':'CHILD','depends_on':['DRILL']},
                             {**copy.deepcopy(mission['tasks'][0]),'id':'INDEPENDENT'}]
        calls=[];base=self.worker(calls)
        def worker(task,m,role,folder,feedback):
            result=base(task,m,role,folder,feedback)
            if task['id']=='DRILL':result['status']='blocked'
            return result
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}),patch.object(loop.harness,'run_check',return_value={'status':'passed'}):
            state=loop.run(mission,Path(tmp),worker)
        self.assertEqual(state['status'],'blocked')
        self.assertEqual(state['tasks']['CHILD']['status'],'dependency_blocked')
        self.assertEqual(state['tasks']['CHILD']['blocked_by'],['DRILL'])
        self.assertEqual(state['tasks']['INDEPENDENT']['status'],'complete')
        self.assertEqual(calls,[('DRILL','implement','implement'),('INDEPENDENT','implement','implement'),('INDEPENDENT','review','review')])

    def test_transient_retry_is_bounded_consumes_calls_and_restores(self):
        mission=copy.deepcopy(MISSION);mission['transport_retry']={'max_retries':1,'backoff_seconds':2}
        calls=[];base=self.worker(calls)
        def worker(task,m,role,folder,feedback):
            if not calls:
                calls.append(('DRILL',role,folder.name))
                loop.save(folder/'invocation.json',{'kind':'simulated_contract_test','failure_kind':'transport'})
                raise RuntimeError('SIMULATED stream disconnected')
            return base(task,m,role,folder,feedback)
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}),patch.object(loop.harness,'run_check',return_value={'status':'passed'}),patch.object(loop.time,'sleep') as sleep:
            folder=Path(tmp);state=loop.run(mission,folder,worker)
            self.assertEqual(state['status'],'complete');self.assertEqual(state['calls'],3)
            self.assertEqual(state['transport_failures'][0]['failure_kind'],'transport')
            self.assertEqual(calls[1][2],'implement_retry_1')
            self.assertEqual(loop.run(mission,folder,worker)['calls'],3)
            sleep.assert_called_once_with(2)

    def test_authentication_never_retries_even_with_retry_budget(self):
        mission=copy.deepcopy(MISSION);mission['transport_retry']={'max_retries':2,'backoff_seconds':1}
        def worker(task,m,role,folder,feedback):
            loop.save(folder/'invocation.json',{'kind':'simulated_contract_test','failure_kind':'authentication'})
            raise RuntimeError('SIMULATED CLI401 token refresh')
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}),patch.object(loop.time,'sleep') as sleep:
            state=loop.run(mission,Path(tmp),worker)
            self.assertEqual(state['calls'],1);self.assertEqual(state['status'],'blocked')
            sleep.assert_not_called()

    def test_cli401_takes_precedence_over_disconnect_and_keeps_raw_events(self):
        # Fake OS process; verifies the real invoke parser without network/model use.
        process=Mock(pid=123,returncode=1)
        def popen(*args,**kwargs):
            kwargs['stdout'].write(json.dumps({'type':'error','message':'SIMULATED HTTP401 token refresh: stream disconnected'})+'\n')
            return process
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop.subprocess,'Popen',side_effect=popen),patch.object(loop.os,'killpg'):
            folder=Path(tmp)
            with self.assertRaisesRegex(RuntimeError,'authentication'):
                loop.invoke(MISSION['tasks'][0],MISSION,'implement',folder,'{}')
            meta=json.loads((folder/'invocation.json').read_text())
            self.assertEqual(meta['failure_kind'],'authentication')
            self.assertEqual(meta['events_sha256'],loop.hashlib.sha256((folder/'events.jsonl').read_bytes()).hexdigest())

    def test_transient_with_source_mutation_is_not_automatically_replayed(self):
        mission=copy.deepcopy(MISSION);mission['transport_retry']={'max_retries':2,'backoff_seconds':1}
        mission['tasks'][0].update(read_only=False,allowed_paths=['tools/sample'],quality_record='fake')
        source={}
        def worker(task,m,role,folder,feedback):
            source['tools/sample']='SIMULATED partial write'
            loop.save(folder/'invocation.json',{'kind':'simulated_contract_test','failure_kind':'transport'})
            raise RuntimeError('SIMULATED interrupted implementation')
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',side_effect=lambda:dict(source)),patch.object(loop.time,'sleep') as sleep:
            state=loop.run(mission,Path(tmp),worker)
            self.assertEqual(state['calls'],1);self.assertEqual(state['status'],'blocked')
            self.assertEqual(source['tools/sample'],'SIMULATED partial write');sleep.assert_not_called()

    def test_retry_exhaustion_stops_at_cap_and_unknown_failure_is_not_retried(self):
        for kind in ('transport','worker_error'):
            mission=copy.deepcopy(MISSION);mission['transport_retry']={'max_retries':2,'backoff_seconds':1}
            def worker(task,m,role,folder,feedback):
                loop.save(folder/'invocation.json',{'kind':'simulated_contract_test','failure_kind':kind})
                raise RuntimeError('SIMULATED failure')
            with self.subTest(kind=kind),tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}),patch.object(loop.time,'sleep') as sleep:
                if kind=='worker_error':
                    with self.assertRaises(RuntimeError):loop.run(mission,Path(tmp),worker)
                    sleep.assert_not_called()
                else:
                    state=loop.run(mission,Path(tmp),worker)
                    self.assertEqual(state['calls'],3);self.assertEqual(state['status'],'blocked')
                    self.assertEqual([c.args[0] for c in sleep.call_args_list],[1,2])

    def interrupted_review(self, folder, expired=False):
        calls=[];base=self.worker(calls)
        def worker(task,m,role,directory,feedback):
            if role=='review' and directory.name=='review':
                request={'schema_version':1,'nonce':'SIMULATED-old','task_id':task['id'],'attempt':'1','role':role,
                         'expires_at':0 if expired else 9999999999}
                request['request_hash']=loop.digest(request)
                loop.save(directory/'host_request.json',request)
                raise KeyboardInterrupt('SIMULATED host interrupted')
            return base(task,m,role,directory,feedback)
        with patch.object(loop.harness,'run_check',return_value={'status':'passed'}):
            with self.assertRaises(KeyboardInterrupt):loop.run(MISSION,folder,worker)
        return worker,calls

    def test_interrupted_review_requires_expiry_or_actual_host_cancellation_receipt(self):
        for expired in (False,True):
            with self.subTest(expired=expired),tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}):
                folder=Path(tmp);worker,calls=self.interrupted_review(folder,expired)
                blocked=loop.run(MISSION,folder,worker)
                self.assertEqual(blocked['status'],'blocked');self.assertEqual(blocked['calls'],2)
                old=folder/'DRILL/1/review'
                if not expired:
                    with self.assertRaisesRegex(ValueError,'interruption receipt'):
                        loop.run(MISSION,folder,worker,recover_interrupted=True)
                    raw=folder/'SIMULATED-host-cancellation.txt';raw.write_text('SIMULATED controller contract, no real agent')
                    request=json.loads((old/'host_request.json').read_text())
                    loop.save(old/'host_cancellation.json',{'request_hash':request['request_hash'],'cancelled':True,
                        'agent_id':'/root/simulated_review','host_evidence':str(raw)})
                state=loop.run(MISSION,folder,worker,recover_interrupted=True)
                self.assertEqual(state['status'],'complete');self.assertEqual(state['calls'],3)
                self.assertEqual(calls,[('DRILL','implement','implement'),('DRILL','review','review_retry_1')])
                self.assertTrue((old/'lease_revoked.json').is_file())
                self.assertEqual(state['tasks']['DRILL']['rounds'],1)
                self.assertEqual(loop.run(MISSION,folder,worker)['calls'],3)

    def test_retry_policy_bounds(self):
        for retry in ({'max_retries':True},{'max_retries':3},{'max_retries':-1},{'backoff_seconds':0},{'backoff_seconds':31},{'unexpected':1}):
            mission=copy.deepcopy(MISSION);mission['transport_retry']=retry
            with self.subTest(retry=retry),self.assertRaises(ValueError):loop.validate(mission)


class CompletedReviewCollectionTests(unittest.TestCase):
    """Real files/Git worktrees/CLI and flock; host data are labelled fixtures, not AI evidence."""

    def setUp(self):
        import os
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.main = Path(self.tmp.name) / 'main'
        self.target = Path(self.tmp.name) / 'frozen'
        self.main.mkdir()
        self.repo = Path(__file__).resolve().parents[1]
        self.git('init', '-q')
        self.git('config', 'user.name', 'SIMULATED contract fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        (self.main / 'tools').mkdir()
        for name in ('production_loop.py', 'harness.py', 'quality.py'):
            (self.main / 'tools' / name).write_bytes((self.repo / 'tools' / name).read_bytes())
        (self.main / '.gitignore').write_text('build/\n__pycache__/\n')
        skill = self.main / '.agents/skills/gameplay-reviewer/SKILL.md'
        skill.parent.mkdir(parents=True)
        skill.write_text('SIMULATED fixture skill, no actual model execution\n')
        (self.main / 'tools/check_fixture.py').write_text('raise RuntimeError("collector must not invoke checks")\n')
        manifest = self.main / 'tools/harness/profiles.json'
        manifest.parent.mkdir()
        loop.save(manifest, {'schema_version': 1, 'profiles': {'docs': ['docs']}, 'checks': {
            'docs': {'argv': ['python3', 'tools/check_fixture.py'], 'timeout_seconds': 1,
                     'success_pattern': '^SIMULATED fixture checks passed$'}}})
        self.git('add', '.')
        self.git('commit', '-qm', 'SIMULATED source fixture')
        self.git('worktree', 'add', '-q', str(self.target))
        vanished = subprocess.Popen([sys.executable, '-c', 'pass'])
        vanished.wait()
        self.vanished_pid = vanished.pid
        self.original_tool = (self.target / 'tools/production_loop.py').read_bytes()

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.main), *args], stderr=subprocess.STDOUT)

    def fixture(self, name='case', verdict='reject'):
        m = copy.deepcopy(MISSION)
        m.update(max_rounds=1, max_calls=2)
        task = m['tasks'][0]
        evidence = self.target / 'build/verification' / name
        impl = evidence / 'DRILL/1/implement'
        review = evidence / 'DRILL/1/review'
        impl.mkdir(parents=True)
        review.mkdir()
        mission_path = evidence / 'mission.json'
        loop.save(mission_path, m)
        with patch.object(loop, 'ROOT', self.target):
            source = loop.digest(loop.snapshot())
        result = {'status': 'ready_for_review', 'summary': 'SIMULATED completed implementation', 'findings': []}
        request = {'schema_version': 1, 'nonce': 'a' * 32, 'task_id': 'DRILL', 'attempt': '1',
                   'role': 'implement', 'source_hash': source, 'expires_at': loop.time.time()+600}
        request['request_hash'] = loop.digest(request)
        response = {'schema_version': 1, 'request_hash': request['request_hash'], 'task_id': 'DRILL',
                    'attempt': '1', 'role': 'implement', 'agent_id': '/root/SIMULATED_author', 'result': result}
        loop.save(impl / 'host_request.json', request)
        loop.save(impl / 'host_response.json', response)
        loop.save(impl / 'result.json', result)
        loop.save(impl / 'invocation.json', {'kind': 'actual_host_codex_agent', 'role': 'implement',
                  'request_hash': request['request_hash'], 'exit_code': 0, 'timed_out': False,
                  'lease_status': 'completed', 'agent_id': response['agent_id'],
                  'response_sha256': loop.hashlib.sha256((impl / 'host_response.json').read_bytes()).hexdigest(),
                  'fixture_only': True})
        log = impl.parent / 'docs.log'
        log.write_text('SIMULATED fixture checks passed\n')
        checks = [{'id': 'docs', 'status': 'passed', 'exit_code': 0}]
        record = {'round': 1, 'evidence': str(impl.parent), 'roles': {'implement': result}, 'checks': checks,
                  'result': result, 'role_directories': {'implement': 'implement'}}
        checkpoint = {'schema_version': 1, 'phase': 'review', 'round_record': record,
                      'before': {'SIMULATED_before_implementation': 'different'}, 'source_hash': source,
                      'role_metadata': {'implement': loop.hashlib.sha256((impl/'invocation.json').read_bytes()).hexdigest()},
                      'check_logs': {'docs': loop.hashlib.sha256(log.read_bytes()).hexdigest()}}
        loop.save(impl.parent / 'checkpoint.json', checkpoint)
        state = {'schema_version': 1, 'mission_hash': loop.digest(m), 'source_hash': source, 'calls': 2,
                 'tasks': {'DRILL': {'status': 'pending', 'rounds': 1, 'history': [], 'checkpoint': {
                     'path': str(impl.parent / 'checkpoint.json'),
                     'sha256': loop.hashlib.sha256((impl.parent/'checkpoint.json').read_bytes()).hexdigest()}}},
                 'status': 'running', 'worker_mode': 'invoke_host', 'content_complete': False,
                 'active_call': {'task_id': 'DRILL', 'round': 1, 'role': 'review', 'evidence': str(review)}}
        loop.save(evidence / 'state.json', state)
        skills = [{'path': '.agents/skills/gameplay-reviewer/SKILL.md', 'sha256': loop.hashlib.sha256(
            (self.target/'.agents/skills/gameplay-reviewer/SKILL.md').read_bytes()).hexdigest()}]
        request = {'schema_version': 1, 'nonce': 'b'*32, 'task_id': 'DRILL', 'attempt': '1', 'role': 'review',
                   'source_hash': source, 'expires_at': loop.time.time()+600, 'task_contract': task,
                   'skills': skills, 'prompt': 'SIMULATED fixture only',
                   'feedback': json.dumps({'dependencies': {}, 'previous_rounds': [], 'implementation': result, 'checks': checks})}
        request['request_hash'] = loop.digest(request)
        loop.save(review / 'host_request.json', request)
        (review / 'prompt.txt').write_text(request['prompt'])
        response = {'schema_version': 1, 'request_hash': request['request_hash'], 'task_id': 'DRILL', 'attempt': '1',
                    'role': 'review', 'agent_id': '/root/SIMULATED_independent', 'result': {
                        'status': verdict, 'summary': 'SIMULATED completed independent review', 'findings': []}}
        loop.save(review / 'host_response.json', response)
        return mission_path, evidence, review

    def cli(self, mission, evidence, *extra):
        return subprocess.run([sys.executable, str(self.main/'tools/production_loop.py'), '--mission', str(mission),
            '--execute', '--worker-mode', 'host', '--evidence-dir', str(evidence), '--collect-completed-review',
            '--collector-worktree', str(self.target), '--controller-pid', str(self.vanished_pid), *extra],
            capture_output=True, text=True, timeout=20)

    def test_actual_cli_collects_reject_without_new_calls_or_target_source_changes(self):
        mission, evidence, review = self.fixture()
        originals = {p: p.read_bytes() for p in (review/'host_request.json', review/'host_response.json')}
        result = self.cli(mission, evidence)
        self.assertEqual(result.returncode, 2, result.stderr)
        state = json.loads((evidence/'state.json').read_text())
        self.assertEqual(state['status'], 'budget_exhausted')
        self.assertEqual(state['calls'], 2)
        self.assertNotIn('active_call', state)
        self.assertEqual(state['tasks']['DRILL']['history'][0]['result']['status'], 'reject')
        self.assertEqual(len(list(evidence.glob('*/*/review*'))), 1)
        self.assertEqual({p: p.read_bytes() for p in originals}, originals)
        self.assertEqual((self.target/'tools/production_loop.py').read_bytes(), self.original_tool)
        meta = json.loads((review/'invocation.json').read_text())
        self.assertTrue(meta['recovered_completed_response'])
        receipt = json.loads(Path(meta['collection_receipt']).read_text())
        self.assertEqual(receipt['new_calls'], 0)
        self.assertEqual(receipt['new_checks'], 0)
        self.assertEqual(receipt['controller_ps']['exit_code'], 1)
        self.assertTrue((Path(meta['collection_receipt']).parent/'state.before.json').is_file())
        self.assertTrue((Path(meta['collection_receipt']).parent/'state.after.json').is_file())
        before = (evidence/'state.json').read_bytes()
        self.assertEqual(self.cli(mission, evidence).returncode, 1)
        self.assertEqual((evidence/'state.json').read_bytes(), before)

    def test_actual_cli_collects_accept_into_existing_scope_finalization(self):
        mission, evidence, review = self.fixture(verdict='accept')
        result = self.cli(mission, evidence)
        self.assertEqual(result.returncode, 0, result.stderr)
        state = json.loads((evidence/'state.json').read_text())
        self.assertEqual(state['status'], 'complete')
        self.assertEqual(state['calls'], 2)
        self.assertFalse(state['content_complete'])

    def test_actual_cli_refuses_expired_revoked_changed_or_nonindependent_inputs(self):
        mutations = ('expired', 'revoked', 'cancelled', 'response-lease', 'same-author', 'response-extra',
                     'nonce', 'task-contract', 'check-log', 'checkpoint', 'source', 'missing-response',
                     'already-invoked', 'result-extra', 'state-budget', 'symlink-response',
                     'infinite-expiry', 'nan-expiry', 'request-extra', 'response-bool-schema', 'prompt-changed')
        for index, mutation in enumerate(mutations):
            with self.subTest(mutation=mutation):
                mission, evidence, review = self.fixture('bad_'+str(index))
                request = json.loads((review/'host_request.json').read_text())
                response = json.loads((review/'host_response.json').read_text())
                if mutation == 'expired': request['expires_at'] = loop.time.time()-1
                elif mutation == 'nonce': request['nonce'] = 'not-a-nonce'
                elif mutation == 'task-contract': request['task_contract']['goal'] = 'changed'
                elif mutation == 'infinite-expiry': request['expires_at'] = float('inf')
                elif mutation == 'nan-expiry': request['expires_at'] = float('nan')
                elif mutation == 'request-extra': request['unexpected'] = True
                if mutation in {'expired', 'nonce', 'task-contract', 'infinite-expiry', 'nan-expiry', 'request-extra'}:
                    request['request_hash'] = loop.digest({k:v for k,v in request.items() if k!='request_hash'})
                    response['request_hash'] = request['request_hash']
                    loop.save(review/'host_request.json', request)
                if mutation == 'revoked': loop.save(review/'lease_revoked.json', {'revoked': True})
                elif mutation == 'cancelled': loop.save(review/'host_cancellation.json', {'cancelled': True})
                elif mutation == 'response-lease': response['request_hash'] = 'old'
                elif mutation == 'same-author': response['agent_id'] = '/root/SIMULATED_author'
                elif mutation == 'response-extra': response['nonce'] = request['nonce']
                elif mutation == 'result-extra': response['result']['fabricated'] = True
                elif mutation == 'response-bool-schema': response['schema_version'] = True
                elif mutation == 'prompt-changed': (review/'prompt.txt').write_text('changed')
                elif mutation == 'check-log': (review.parent/'docs.log').write_text('no completion\n')
                elif mutation == 'checkpoint': (review.parent/'checkpoint.json').write_text('{}')
                elif mutation == 'source': (self.target/'tools/check_fixture.py').write_text('changed source\n')
                elif mutation == 'already-invoked': loop.save(review/'invocation.json', {'exit_code': 0})
                elif mutation == 'state-budget':
                    state=json.loads((evidence/'state.json').read_text());state['calls']=1;loop.save(evidence/'state.json',state)
                loop.save(review/'host_response.json', response)
                if mutation == 'missing-response': (review/'host_response.json').unlink()
                elif mutation == 'symlink-response':
                    original=review/'original-response.json';(review/'host_response.json').rename(original)
                    (review/'host_response.json').symlink_to(original)
                before=(evidence/'state.json').read_bytes()
                result=self.cli(mission,evidence)
                self.assertEqual(result.returncode,1,result.stdout+result.stderr)
                self.assertEqual((evidence/'state.json').read_bytes(),before)
                self.assertFalse((review/'result.json').exists())
                if mutation == 'source':
                    (self.target/'tools/check_fixture.py').write_bytes((self.main/'tools/check_fixture.py').read_bytes())

    def test_actual_cli_exclusive_lock_and_live_controller_refuse(self):
        import fcntl, os
        mission,evidence,review=self.fixture()
        before=(evidence/'state.json').read_bytes()
        with (evidence/'lock').open('a') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
            result=self.cli(mission,evidence)
            self.assertEqual(result.returncode,1)
        result=self.cli(mission,evidence,'--controller-pid',str(os.getpid()))
        self.assertEqual(result.returncode,1)
        self.assertEqual((evidence/'state.json').read_bytes(),before)
        self.assertFalse((review/'invocation.json').exists())

    def test_actual_cli_unrelated_worktree_refuses_without_state_mutation(self):
        mission,evidence,review=self.fixture()
        other=Path(self.tmp.name)/'unrelated';other.mkdir()
        subprocess.check_call(['git','-C',str(other),'init','-q'])
        before=(evidence/'state.json').read_bytes()
        result=self.cli(mission,evidence,'--collector-worktree',str(other))
        self.assertEqual(result.returncode,1)
        self.assertIn('same Git common',result.stderr)
        self.assertEqual((evidence/'state.json').read_bytes(),before)

    def test_revocation_races_are_checked_before_and_after_metadata_publication(self):
        for after in ('receipt.json', 'invocation.json'):
            with self.subTest(after=after):
                mission,evidence,review=self.fixture('race_'+after)
                original_save=loop.save
                def revoke(path,value):
                    original_save(path,value)
                    if path.name==after:original_save(review/'lease_revoked.json',{'revoked':True})
                before=(evidence/'state.json').read_bytes()
                with patch.object(loop,'ROOT',self.main),patch.object(loop,'save',side_effect=revoke):
                    with self.assertRaisesRegex(ValueError,'expired/revoked'):
                        loop.collect_completed_review(mission,evidence,self.target,self.vanished_pid)
                self.assertEqual((evidence/'state.json').read_bytes(),before)
                self.assertEqual(json.loads((evidence/'state.json').read_text())['calls'],2)
                self.assertFalse((review/'result.json').exists())
                self.assertFalse((review/'invocation.json').exists())

    def test_response_source_and_expiry_races_do_not_publish_state(self):
        for mutation in ('response', 'source', 'expiry'):
            with self.subTest(mutation=mutation):
                mission,evidence,review=self.fixture('change_'+mutation)
                original_save=loop.save
                wall=[loop.time.time()]
                def change(path,value):
                    original_save(path,value)
                    if path.name=='invocation.json':
                        if mutation=='response':(review/'host_response.json').write_text('{}')
                        elif mutation=='source':(self.target/'tools/check_fixture.py').write_text('changed')
                        else:wall[0]+=1000
                before=(evidence/'state.json').read_bytes()
                with patch.object(loop,'ROOT',self.main),patch.object(loop,'save',side_effect=change),patch.object(loop.time,'time',side_effect=lambda:wall[0]):
                    with self.assertRaises(ValueError):
                        loop.collect_completed_review(mission,evidence,self.target,self.vanished_pid)
                self.assertEqual((evidence/'state.json').read_bytes(),before)
                self.assertFalse((review/'result.json').exists())
                self.assertFalse((review/'invocation.json').exists())
                if mutation=='source':
                    (self.target/'tools/check_fixture.py').write_bytes((self.main/'tools/check_fixture.py').read_bytes())

    def test_full_finalization_transaction_rolls_back_all_late_guard_failures(self):
        # Original independent R1 counterexamples stay intact. Exercise the
        # actual finalization/quality and every publication boundary here too.
        for phase in ('quality', 'checkpoint', 'state', 'after'):
            for mutation in ('expiry', 'revoked', 'source', 'response'):
                with self.subTest(phase=phase,mutation=mutation):
                    mission,evidence,review=self.fixture('final_'+phase+'_'+mutation,verdict='accept')
                    original_save,original_quality=loop.save,loop.check_task_quality
                    wall=[loop.time.time()];injected=[False]
                    before={p:p.read_bytes() for p in (evidence/'state.json',review.parent/'checkpoint.json')}
                    def inject():
                        if injected[0]:return
                        injected[0]=True
                        if mutation=='expiry':wall[0]+=1000
                        elif mutation=='revoked':original_save(review/'lease_revoked.json',{'revoked':True})
                        elif mutation=='source':(self.target/'tools/check_fixture.py').write_text('changed')
                        else:(review/'host_response.json').write_text('{}')
                    def save(path,value):
                        original_save(path,value)
                        if ((phase=='checkpoint' and path==review.parent/'checkpoint.json')
                                or (phase=='state' and path==evidence/'state.json')
                                or (phase=='after' and path.name=='state.after.json')):inject()
                    def quality(task):
                        value=original_quality(task)
                        if phase=='quality':inject()
                        return value
                    with patch.object(loop,'ROOT',self.main),patch.object(loop,'save',side_effect=save),patch.object(loop,'check_task_quality',side_effect=quality),patch.object(loop.time,'time',side_effect=lambda:wall[0]):
                        with self.assertRaises(ValueError):
                            loop.collect_completed_review(mission,evidence,self.target,self.vanished_pid)
                    self.assertTrue(injected[0])
                    self.assertEqual({p:p.read_bytes() for p in before},before)
                    self.assertFalse((review/'result.json').exists())
                    self.assertFalse((review/'invocation.json').exists())
                    failures=list(evidence.glob('completed_review_collection/*/failure.json'))
                    self.assertEqual(len(failures),1)
                    self.assertEqual(json.loads(failures[0].read_text())['status'],'rejected_and_rolled_back')
                    if mutation=='source':
                        (self.target/'tools/check_fixture.py').write_bytes((self.main/'tools/check_fixture.py').read_bytes())

    def test_final_receipt_boundary_binds_all_exact_published_outputs(self):
        for name in ('state.json','checkpoint.json','invocation.json','result.json'):
            with self.subTest(name=name):
                mission,evidence,review=self.fixture('published_'+name,verdict='accept')
                target={'state.json':evidence/'state.json','checkpoint.json':review.parent/'checkpoint.json',
                        'invocation.json':review/'invocation.json','result.json':review/'result.json'}[name]
                before={p:p.read_bytes() for p in (evidence/'state.json',review.parent/'checkpoint.json')}
                original_save=loop.save
                def change(path,value):
                    original_save(path,value)
                    if path.name=='state.after.json':target.write_text('{}')
                with patch.object(loop,'ROOT',self.main),patch.object(loop,'save',side_effect=change):
                    with self.assertRaisesRegex(ValueError,'changed during collection'):
                        loop.collect_completed_review(mission,evidence,self.target,self.vanished_pid)
                self.assertEqual({p:p.read_bytes() for p in before},before)
                self.assertFalse((review/'result.json').exists())
                self.assertFalse((review/'invocation.json').exists())


class SelectedInputPreflightTests(unittest.TestCase):
    """Actual sparse Git/files; synthetic worker fixtures never certify AI work."""
    setUp = CompletedReviewCollectionTests.setUp
    git = CompletedReviewCollectionTests.git

    def configure(self):
        self.proof = 'docs/evidence/required/proof.txt'
        for name, text in {
            self.proof: 'actual tracked fixture input\n',
            'docs/quality/policy.json': json.dumps({'templates': []}),
            'docs/quality/records/OLD.json': json.dumps({'evidence': [{'path': self.proof}]}),
            'docs/tasks.md': 'SIMULATED fixture index\n',
            'docs/development_quality.md': 'SIMULATED fixture quality version\n',
            'docs/quality/README.md': 'SIMULATED fixture README\n',
            'tools/check_quality.py': 'print("QUALITY fixture")\n',
            'tools/check_docs.py': 'print("DOCS fixture")\n',
            'tests/test_quality.py': 'print("OK")\n',
            'tests/test_visual_director.py': 'print("OK")\n',
            'docs/quality/level_lessons.json': json.dumps({'schema_version': 1, 'lessons': [
                {'evidence': [{'path': self.proof}]}]}),
        }.items():
            path=self.main/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text)
        manifest=json.loads((self.main/'tools/harness/profiles.json').read_text())
        manifest['checks'].update({
            'docs': {'argv':['python3','tools/check_docs.py'],'timeout_seconds':9,'success_pattern':'^DOCS fixture$'},
            'quality': {'argv':['python3','tools/check_quality.py'],'timeout_seconds':9,'success_pattern':'^QUALITY fixture$'},
            'quality-tests': {'argv':['python3','tests/test_quality.py'],'timeout_seconds':11,'success_pattern':'^OK$'},
            'visual-director-tests': {'argv':['python3','tests/test_visual_director.py'],'timeout_seconds':13,'success_pattern':'^OK$'}})
        loop.save(self.main/'tools/harness/profiles.json',manifest)
        self.git('add','.')
        self.git('commit','-qm','SIMULATED tracked evidence and canonical check definitions')
        sha=self.git('rev-parse','HEAD').decode().strip()
        subprocess.check_call(['git','-C',str(self.target),'reset','--hard','-q',sha])
        subprocess.check_call(['git','-C',str(self.target),'sparse-checkout','init','--no-cone'])
        subprocess.run(['git','-C',str(self.target),'sparse-checkout','set','--no-cone','--stdin'],
                       input='/*\n!/docs/evidence/**\n',text=True,check=True)
        subprocess.check_call(['git','-C',str(self.target),'read-tree','-mu','HEAD'])
        self.mission=copy.deepcopy(MISSION)
        self.mission.update(max_calls=2,max_rounds=1)
        self.mission['tasks'][0]['checks']=['quality']
        return self.mission['tasks'][0]

    def test_route_test_entrypoints_preflight_real_knowledge_dependencies_calls_zero(self):
        task=self.configure()
        checks={"production-loop-tests":"tests/test_production_loop.py", "level-design-routing":"tests/test_level_design_routing.py"}
        manifest=json.loads((self.main/'tools/harness/profiles.json').read_text())
        for name,entry in checks.items():
            p=self.main/entry;p.parent.mkdir(parents=True,exist_ok=True);p.write_text('print("OK")\n')
            manifest['checks'][name]={'argv':['python3',entry],'timeout_seconds':5,'success_pattern':'^OK$'}
        loop.save(self.main/'tools/harness/profiles.json',manifest)
        self.git('add','.');self.git('commit','-qm','Actual selected lesson consumer entrypoints')
        subprocess.check_call(['git','-C',str(self.target),'reset','--hard','-q',self.git('rev-parse','HEAD').decode().strip()])
        subprocess.check_call(['git','-C',str(self.target),'read-tree','-mu','HEAD'])
        with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
            for name in checks:
                with self.subTest(check=name):
                    task['checks']=[name]
                    def forbidden(*unused):raise AssertionError('Missing actual knowledge must not dispatch a worker')
                    state=loop.run(self.mission,self.target/('build/verification/'+name),forbidden)
                    self.assertEqual(state['calls'],0)
                    self.assertEqual([item['path'] for item in state['tasks']['DRILL']['input_preflight']['missing_tracked_inputs']],[self.proof])
            (self.target/self.proof).parent.mkdir(parents=True,exist_ok=True)
            (self.target/self.proof).write_bytes(self.git('show','HEAD:'+self.proof))
            for name in checks:
                task['checks']=[name]
                self.assertEqual(loop.required_input_preflight(task)['status'],'passed')

    def test_actual_sparse_cli_blocks_before_any_role_allocation_and_preserves_missing_path(self):
        task=self.configure()
        evidence=self.target/'build/verification/preflight'
        evidence.mkdir(parents=True)
        mission=evidence/'mission.json';loop.save(mission,self.mission)
        result=subprocess.run([sys.executable,str(self.target/'tools/production_loop.py'),'--mission',str(mission),
            '--execute','--worker-mode','host','--evidence-dir',str(evidence)],capture_output=True,text=True,timeout=20)
        self.assertEqual(result.returncode,2,result.stdout+result.stderr)
        state=json.loads((evidence/'state.json').read_text())
        self.assertEqual(state['status'],'blocked');self.assertEqual(state['calls'],0)
        self.assertEqual(state['tasks']['DRILL']['rounds'],0)
        self.assertFalse(any(evidence.glob('*/*/host_request.json')))
        self.assertFalse((self.target/self.proof).exists())
        missing=state['tasks']['DRILL']['input_preflight']['missing_tracked_inputs']
        self.assertEqual([x['path'] for x in missing],[self.proof])
        self.assertEqual(missing[0]['reason'],'sparse_unmaterialized')
        self.assertEqual(missing[0]['git_index_state'].upper(),'S')
        self.assertEqual(state['tasks']['DRILL']['input_preflight']['resolved_checks']['checks'][0]['argv'],
                         ['python3','tools/check_quality.py'])

    def test_exact_trusted_materialization_allows_new_run_but_does_not_retry_old_failure(self):
        task=self.configure();calls=[]
        def worker(task,m,role,*unused):
            calls.append(role)
            return {'status':'ready_for_review' if role=='implement' else 'accept','summary':'SIMULATED worker only','findings':[]}
        with patch.object(loop,'ROOT',self.main):
            with loop._collection_worktree(self.target):
                failed=loop.run(self.mission,self.target/'build/verification/missing',worker)
                self.assertEqual(failed['calls'],0)
                subprocess.run(['git','-C',str(self.target),'sparse-checkout','add','--stdin'],
                               input='/'+self.proof+'\n',text=True,check=True)
                subprocess.check_call(['git','-C',str(self.target),'read-tree','-mu','HEAD'])
                self.assertEqual((self.target/self.proof).read_bytes(),self.git('show','HEAD:'+self.proof))
                with self.assertRaisesRegex(ValueError,'Mission/source changed'):
                    loop.run(self.mission,self.target/'build/verification/missing',worker)
                with patch.object(loop.harness,'run_check',return_value={'status':'passed','exit_code':0}):
                    state=loop.run(self.mission,self.target/'build/verification/materialized',worker)
                self.assertEqual(state['status'],'complete');self.assertEqual(state['calls'],2)
                self.assertEqual(calls,['implement','review'])

    def test_untracked_future_outputs_and_explicit_deleted_repairs_are_not_sparse_waivers(self):
        task=self.configure()
        subprocess.run(['git','-C',str(self.target),'sparse-checkout','add','--stdin'],
                       input='/'+self.proof+'\n',text=True,check=True)
        subprocess.check_call(['git','-C',str(self.target),'read-tree','-mu','HEAD'])
        own=self.target/'docs/quality/records/PLANNED.json'
        loop.save(own,{'evidence':[{'path':'docs/evidence/future/output.json'}]})
        with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
            self.assertEqual(loop.required_input_preflight(task)['status'],'passed')
            (self.target/self.proof).unlink()
            repair={**task,'read_only':False,'allowed_paths':[self.proof]}
            result=loop.required_input_preflight(repair)
            self.assertEqual(result['status'],'passed')
            self.assertEqual(result['explicit_deleted_repairs'][0]['reason'],'explicit_deleted_file_repair')
            self.assertEqual(loop.required_input_preflight({**repair,'allowed_paths':['docs/evidence/']})['status'],'blocked')
            self.assertEqual(loop.required_input_preflight({**repair,'read_only':True})['status'],'blocked')
        # Exact allowed output cannot waive a real sparse missing input.
        subprocess.check_call(['git','-C',str(self.target),'checkout','--',self.proof])
        subprocess.run(['git','-C',str(self.target),'sparse-checkout','set','--no-cone','--stdin'],
                       input='/*\n!/docs/evidence/**\n',text=True,check=True)
        with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
            self.assertEqual(loop.required_input_preflight(repair)['status'],'blocked')

    def test_missing_index_and_current_knowledge_are_precise_and_unselected_globals_do_not_block(self):
        task=self.configure()
        with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
            self.assertEqual(loop.required_input_preflight({**task,'checks':['quality-tests']})['status'],'passed')
            lesson=loop.required_input_preflight({**task,'checks':['visual-director-tests']})
            self.assertEqual([x['path'] for x in lesson['missing_tracked_inputs']],[self.proof])
        subprocess.run(['git','-C',str(self.target),'sparse-checkout','set','--no-cone','--stdin'],
                       input='/*\n!/docs/evidence/**\n!/docs/quality/records/OLD.json\n',text=True,check=True)
        with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
            result=loop.required_input_preflight(task)
            self.assertIn('docs/quality/records/OLD.json',[x['path'] for x in result['missing_tracked_inputs']])

    def test_missing_global_inputs_block_only_their_package(self):
        task=self.configure();m=copy.deepcopy(self.mission);m['max_calls']=4
        m['tasks'].append({**copy.deepcopy(task),'id':'INDEPENDENT','checks':['quality-tests']})
        calls=[]
        def worker(task,m,role,*unused):
            calls.append((task['id'],role))
            return {'status':'ready_for_review' if role=='implement' else 'accept','summary':'SIMULATED independent fixture','findings':[]}
        with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target),patch.object(loop.harness,'run_check',return_value={'status':'passed','exit_code':0}):
            state=loop.run(m,self.target/'build/verification/independent',worker)
        self.assertEqual(state['status'],'blocked');self.assertEqual(state['calls'],2)
        self.assertEqual(state['tasks']['DRILL']['rounds'],0)
        self.assertEqual(state['tasks']['INDEPENDENT']['status'],'complete')
        self.assertEqual(calls,[('INDEPENDENT','implement'),('INDEPENDENT','review')])

    def test_prompt_and_host_request_bind_exact_profile_command_timeout_and_marker(self):
        task=self.configure();task={**task,'checks':['quality-tests']}
        with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
            folder=self.target/'build/verification/command/DRILL/1/implement';folder.mkdir(parents=True)
            original_save=loop.save
            def respond(unused):
                request=json.loads((folder/'host_request.json').read_text())
                response={'schema_version':1,**{k:request[k] for k in ('request_hash','task_id','attempt','role')},
                          'agent_id':'/root/SIMULATED_command_fixture','result':{'status':'ready_for_review',
                          'summary':'SIMULATED transport; no AI or native execution','findings':[]}}
                original_save(folder/'host_response.json',response)
            # Keep the fake host poll local: subprocess waits use stdlib time.sleep.
            with patch.object(loop,'time',wraps=loop.time),patch.object(loop.time,'sleep',side_effect=respond):
                loop.invoke_host(task,self.mission,'implement',folder,'{}')
            request=json.loads((folder/'host_request.json').read_text())
            contract=request['resolved_checks'];entry=contract['checks'][0]
            self.assertEqual(entry,{'id':'quality-tests','argv':['python3','tests/test_quality.py'],
                                  'timeout_seconds':11,'success_pattern':'^OK$'})
            self.assertIn(json.dumps(contract,ensure_ascii=False),(folder/'prompt.txt').read_text())
            self.assertNotIn('run_quality_review_tests.py',(folder/'prompt.txt').read_text())
            self.assertEqual(contract['manifest_sha256'],loop.hashlib.sha256((self.target/'tools/harness/profiles.json').read_bytes()).hexdigest())
            self.assertEqual(request['request_hash'],loop.digest({k:v for k,v in request.items() if k!='request_hash'}))

    def configure_native(self):
        task=self.configure()
        for name in ('assets/ordinary/source.png','assets/own/source.svg','assets/ignored/deep/source.png'):
            path=self.target/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(b'SIMULATED asset; no engine execution')
        (self.target/'assets/ignored/.gdignore').write_text('')
        (self.target/'project.godot').write_text('; SIMULATED native input marker')
        manifest=json.loads((self.target/'tools/harness/profiles.json').read_text())
        manifest['checks']['native-fixture']={'argv':['python3','tests/test_quality.py'],
            'timeout_seconds':17,'success_pattern':'^OK$','inputs':['project.godot','assets/**']}
        loop.save(self.target/'tools/harness/profiles.json',manifest)
        subprocess.check_call(['git','-C',str(self.target),'add','--sparse','assets','project.godot','tools/harness/profiles.json'])
        return {**task,'read_only':False,'checks':['native-fixture'],'quality_record':'docs/quality/records/NEW.json',
                'completion':'content','allowed_paths':['assets/own/']}

    def test_actual_native_input_contract_blocks_unscoped_import_before_worker(self):
        task=self.configure_native();mission=copy.deepcopy(self.mission);mission['tasks']=[task]
        calls=[]
        with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
            state=loop.run(mission,self.target/'build/verification/import-risk',lambda *args:calls.append(args))
        self.assertEqual(state['calls'],0);self.assertEqual(calls,[])
        risks=state['tasks']['DRILL']['input_preflight']['import_metadata_risks']
        self.assertEqual([item['path'] for item in risks],['assets/ordinary/source.png.import'])
        self.assertEqual(risks[0]['required_by'],['native-fixture'])
        self.assertFalse(any((self.target/'build/verification/import-risk').glob('*/*/host_request.json')))

    def test_import_metadata_scope_ancestor_gdignore_and_non_native_are_distinct(self):
        task=self.configure_native()
        with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
            self.assertEqual(loop.required_input_preflight({**task,'checks':['quality-tests']})['status'],'passed')
            scope={**task,'allowed_paths':['assets/own/','assets/ordinary/source.png.import']}
            self.assertEqual(loop.required_input_preflight(scope)['status'],'passed')
            readonly=loop.required_input_preflight({**scope,'read_only':True})
            self.assertEqual(len(readonly['import_metadata_risks']),2)
            (self.target/'assets/ordinary/source.png.import').write_text('; existing metadata')
            self.assertEqual(loop.required_input_preflight(task)['status'],'passed')
            (self.target/'assets/ignored/.gdignore').unlink()
            self.assertEqual([x['path'] for x in loop.required_input_preflight(task)['import_metadata_risks']],
                             ['assets/ignored/deep/source.png.import'])
            # A newly planned untracked output asset is not an existing input.
            new=self.target/'assets/future/source.png';new.parent.mkdir();new.write_bytes(b'future')
            self.assertNotIn(str(new.relative_to(self.target))+'.import',
                [x['path'] for x in loop.required_input_preflight(task)['import_metadata_risks']])

    def test_docs_sparse_missing_markdown_itself_is_input_not_only_existing_links(self):
        task=self.configure()
        subprocess.run(['git','-C',str(self.target),'sparse-checkout','set','--no-cone','--stdin'],
            input='/*\n!/docs/development_quality.md\n',text=True,check=True)
        with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
            result=loop.required_input_preflight({**task,'checks':['docs']})
        self.assertIn('docs/development_quality.md',[x['path'] for x in result['missing_tracked_inputs']])

    def materialize_proof(self):
        subprocess.run(['git','-C',str(self.target),'sparse-checkout','add','--stdin'],
            input='/'+self.proof+'\n',text=True,check=True)
        subprocess.check_call(['git','-C',str(self.target),'read-tree','-mu','HEAD'])

    def test_required_tracked_identity_rejects_broken_external_and_internal_symlinks(self):
        task=self.configure();self.materialize_proof();proof=self.target/self.proof
        for target in ('missing_target','/etc/hostname',str(self.target/'docs/tasks.md')):
            with self.subTest(target=target):
                proof.unlink();proof.symlink_to(target)
                with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
                    result=loop.required_input_preflight(task)
                self.assertEqual(result['status'],'blocked')
                self.assertEqual(result['missing_tracked_inputs'][0]['path'],self.proof)
                self.assertEqual(result['missing_tracked_inputs'][0]['reason'],'symlink_input')

    def test_real_unreadable_index_evidence_directory_and_binary_index_block_unknown(self):
        task=self.configure();self.materialize_proof();proof=self.target/self.proof
        index=self.target/'docs/quality/records/OLD.json';original=index.read_bytes()
        for name,path in (('index',index),('proof',proof),('directory',index.parent)):
            with self.subTest(name=name):
                path.chmod(0)
                try:
                    # Actual uid1000 permission test; root still executes binary
                    # and symlink tests but cannot demonstrate denied reads.
                    if loop.os.geteuid()==0:continue
                    with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
                        result=loop.required_input_preflight(task)
                    self.assertEqual(result['status'],'blocked')
                    self.assertTrue(any(x['reason'].startswith('unreadable:') for x in result['missing_tracked_inputs']))
                finally:path.chmod(0o755 if path.is_dir() else 0o644)
        index.write_bytes(b'\xff\xfe\x00')
        with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
            result=loop.required_input_preflight(task)
        self.assertEqual(result['status'],'blocked')
        self.assertEqual(result['uncertain_inputs'][0]['reason'],'index_dependencies_unknown')
        index.write_bytes(original)
        planned=self.target/'docs/quality/records/PLANNED.json';planned.write_bytes(b'{ incomplete new output')
        with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
            self.assertEqual(loop.required_input_preflight(task)['status'],'passed')

    def test_missing_selected_command_source_gets_calls0_diagnostic(self):
        task=self.configure();self.materialize_proof()
        (self.target/'tools/check_quality.py').unlink()
        with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
            state=loop.run(self.mission,self.target/'build/verification/missing-command',
                           lambda *args:self.fail('No worker may be invoked'))
        self.assertEqual(state['calls'],0)
        self.assertEqual(state['status'],'blocked')
        self.assertIn('tools/check_quality.py',[x['path'] for x in state['tasks']['DRILL']['input_preflight']['missing_tracked_inputs']])

    def test_real_unreadable_source_snapshot_is_calls0_blocked_not_unknown_baseline(self):
        if loop.os.geteuid()==0:self.skipTest('Actual non-root permission proof requires uid1000')
        task=self.configure();self.materialize_proof();index=self.target/'docs/quality/records/OLD.json'
        index.parent.chmod(0)
        try:
            with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
                state=loop.run(self.mission,self.target/'build/verification/unreadable-directory',
                               lambda *args:self.fail('No worker may be invoked'))
            self.assertEqual(state['calls'],0);self.assertEqual(state['status'],'blocked')
            self.assertIsNone(state['source_hash']);self.assertTrue(state['source_snapshot_error'])
            self.assertEqual(state['tasks']['DRILL']['input_preflight']['status'],'blocked')
            folder=self.target/'build/verification/unreadable-cli';folder.mkdir(parents=True)
            mission=folder/'mission.json';loop.save(mission,self.mission)
            result=subprocess.run([sys.executable,str(self.target/'tools/production_loop.py'),'--mission',str(mission),
                '--execute','--worker-mode','host','--evidence-dir',str(folder)],capture_output=True,text=True,timeout=20)
            self.assertEqual(result.returncode,2,result.stdout+result.stderr)
            cli=json.loads((folder/'state.json').read_text())
            self.assertEqual(cli['calls'],0);self.assertEqual(cli['status'],'blocked')
            self.assertIsNone(cli['source_hash'])
            self.assertFalse(any(folder.glob('*/*/host_request.json')))
        finally:index.parent.chmod(0o755)

    def test_native_allowed_sidecar_does_not_waive_existing_asset_readability(self):
        if loop.os.geteuid()==0:self.skipTest('Actual non-root permission proof requires uid1000')
        task=self.configure_native();asset=self.target/'assets/ordinary/source.png';asset.chmod(0)
        try:
            with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
                result=loop.required_input_preflight({**task,'allowed_paths':['assets/']})
            self.assertEqual(result['status'],'blocked')
            self.assertTrue(any(x['path']=='assets/ordinary/source.png' and x['reason'].startswith('unreadable:')
                                for x in result['missing_tracked_inputs']))
        finally:asset.chmod(0o644)

    def test_native_generated_deleted_sidecar_uses_own_scope_but_sparse_still_blocks(self):
        task=self.configure_native();sidecar=self.target/'assets/own/source.svg.import';sidecar.write_text('existing tracked metadata')
        subprocess.check_call(['git','-C',str(self.target),'add','--sparse',str(sidecar)])
        sidecar.unlink();scope={**task,'allowed_paths':['assets/']}
        with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
            result=loop.required_input_preflight(scope)
            self.assertEqual(result['status'],'passed')
            self.assertEqual(result['explicit_deleted_repairs'][0]['reason'],'allowed_generated_import_repair')
            subprocess.check_call(['git','-C',str(self.target),'update-index','--skip-worktree','assets/own/source.svg.import'])
            sparse=loop.required_input_preflight(scope)
            self.assertEqual(sparse['status'],'blocked')
            self.assertEqual(sparse['missing_tracked_inputs'][0]['reason'],'sparse_unmaterialized')

    def test_native_explicit_project_input_cannot_disappear_outside_scope(self):
        task=self.configure_native();(self.target/'project.godot').unlink()
        with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
            result=loop.required_input_preflight({**task,'allowed_paths':['assets/']})
        self.assertEqual(result['status'],'blocked')
        self.assertEqual([x['path'] for x in result['missing_tracked_inputs']],['project.godot'])

    def test_unselected_tracked_runner_is_shared_harness_infrastructure_before_worker(self):
        task=self.configure();task={**task,'checks':['quality-tests']}
        (self.target/'tools/check_quality.py').unlink()
        mission=copy.deepcopy(self.mission);mission['tasks']=[task]
        with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
            state=loop.run(mission,self.target/'build/verification/missing-shared-runner',
                           lambda *args:self.fail('Shared Harness infrastructure must be preflighted'))
        self.assertEqual(state['calls'],0);self.assertEqual(state['status'],'blocked')
        missing=state['tasks']['DRILL']['input_preflight']['missing_tracked_inputs']
        self.assertEqual([x['path'] for x in missing],['tools/check_quality.py'])
        self.assertIn('Harness manifest entry quality',missing[0]['required_by'])


    def configure_actual_forest_contract_inputs(self, declared=True):
        task=self.configure()
        actual=json.loads((self.repo/'tools/harness/profiles.json').read_text())['checks']['level-design-contracts']
        for item in actual['inputs']:
            source=self.repo/item
            paths=sorted(source.rglob('*')) if source.is_dir() else [source]
            for original in paths:
                if original.is_file():
                    target=self.main/original.relative_to(self.repo)
                    target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(original.read_bytes())
        manifest=json.loads((self.main/'tools/harness/profiles.json').read_text())
        manifest['checks']['level-design-contracts']=copy.deepcopy(actual)
        if not declared:manifest['checks']['level-design-contracts'].pop('inputs')
        loop.save(self.main/'tools/harness/profiles.json',manifest)
        self.git('add','.');self.git('commit','-qm','Actual frozen forest fixture materialization inputs')
        subprocess.check_call(['git','-C',str(self.target),'reset','--hard','-q',self.git('rev-parse','HEAD').decode().strip()])
        subprocess.check_call(['git','-C',str(self.target),'read-tree','-mu','HEAD'])
        task['checks']=['level-design-contracts']
        return task

    def test_original_undeclared_forest_fixture_reproduces_missed_sparse_input(self):
        task=self.configure_actual_forest_contract_inputs(declared=False)
        missing=self.target/'docs/evidence/region_production_v3/forest_h_slice/native/positive/capture.json'
        self.assertFalse(missing.exists())
        with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
            result=loop.required_input_preflight(task)
        self.assertEqual(result['status'],'passed')
        self.assertEqual(result['missing_tracked_inputs'],[])
        # This is the actual preflight blind spot, not a successful worker/native run.

    def test_actual_declared_forest_prefix_blocks_calls_zero_until_exact_git_materialization(self):
        task=self.configure_actual_forest_contract_inputs()
        prefix='docs/evidence/region_production_v3/forest_h_slice/'
        required=[prefix+'native/positive/capture.json',prefix+'verification.json',prefix+'round1_reject/host_response.json']
        evidence=self.target/'build/verification/forest-prefix';evidence.mkdir(parents=True)
        mission=evidence/'mission.json';loop.save(mission,self.mission)
        result=subprocess.run([sys.executable,str(self.target/'tools/production_loop.py'),'--mission',str(mission),
            '--execute','--worker-mode','host','--evidence-dir',str(evidence)],capture_output=True,text=True,timeout=20)
        self.assertEqual(result.returncode,2,result.stdout+result.stderr)
        state=json.loads((evidence/'state.json').read_text())
        self.assertEqual(state['status'],'blocked');self.assertEqual(state['calls'],0)
        self.assertFalse(any(evidence.glob('*/*/host_request.json')))
        blocked=state['tasks']['DRILL']['input_preflight']
        self.assertTrue(set(required).issubset({x['path'] for x in blocked['missing_tracked_inputs']}))
        self.assertTrue(all(x['reason']=='sparse_unmaterialized' for x in blocked['missing_tracked_inputs']))
        actual=json.loads((self.target/'tools/harness/profiles.json').read_text())['checks']['level-design-contracts']
        self.assertFalse(actual['cacheable'])
        subprocess.run(['git','-C',str(self.target),'sparse-checkout','add','--stdin'],input='/'+prefix+'**\n',text=True,check=True)
        subprocess.check_call(['git','-C',str(self.target),'read-tree','-mu','HEAD'])
        for name in required:self.assertEqual((self.target/name).read_bytes(),self.git('show','HEAD:'+name))
        with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
            self.assertEqual(loop.required_input_preflight(task)['status'],'passed')
            for name in required:
                with self.subTest(ordinary_missing=name):
                    path=self.target/name;original=path.read_bytes();path.unlink()
                    try:
                        missing=loop.required_input_preflight(task)
                        self.assertEqual(missing['status'],'blocked')
                        self.assertIn(name,[x['path'] for x in missing['missing_tracked_inputs']])
                    finally:path.write_bytes(original)
        # No mock worker, no native execution, no mutation of the old blocked state.
        self.assertEqual(json.loads((evidence/'state.json').read_text()),state)

    def test_declared_directory_input_uses_boundary_and_unknown_untracked_warning(self):
        task=self.configure()
        paths={'fixtures/family/proof.txt':'tracked input','fixtures/family-other/not-required.txt':'outside boundary'}
        for name,body in paths.items():
            p=self.main/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(body)
        manifest=json.loads((self.main/'tools/harness/profiles.json').read_text())
        manifest['checks']['quality-tests']['inputs']=['fixtures/family/','future-untracked/']
        loop.save(self.main/'tools/harness/profiles.json',manifest)
        self.git('add','.');self.git('commit','-qm','Actual directory boundary fixtures')
        subprocess.check_call(['git','-C',str(self.target),'reset','--hard','-q',self.git('rev-parse','HEAD').decode().strip()])
        (self.target/'fixtures/family-other/not-required.txt').unlink()
        with patch.object(loop,'ROOT',self.main),loop._collection_worktree(self.target):
            result=loop.required_input_preflight({**task,'checks':['quality-tests']})
            self.assertEqual(result['status'],'passed')
            self.assertTrue(any(x.get('warning')=='declared_input_has_no_tracked_match' for x in result['index_warnings']))
            (self.target/'fixtures/family/proof.txt').unlink()
            result=loop.required_input_preflight({**task,'checks':['quality-tests']})
            self.assertEqual([x['path'] for x in result['missing_tracked_inputs']],['fixtures/family/proof.txt'])


if __name__=='__main__':unittest.main()
