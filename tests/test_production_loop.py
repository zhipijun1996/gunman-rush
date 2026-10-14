"""Controller contract tests with an explicit fake worker, never proof of AI review."""
import copy
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
    def test_independent_role_and_resume(self):
        state,calls=self.run_case(['ready_for_review','accept'])
        self.assertEqual(calls,['implement','review']); self.assertEqual(state['status'],'complete')
    def test_reject_no_progress(self):
        state,_=self.run_case(['ready_for_review','reject'])
        self.assertEqual(state['status'],'blocked')
        self.assertIn('No source progress',state['tasks']['DRILL']['history'][0]['stop_reason'])
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
        state={'mission_hash':loop.digest(MISSION),'source_hash':loop.digest({}),'worker_mode':'invoke','calls':1,'tasks':{},'status':'running','active_call':{'role':'implement'}}
        with tempfile.TemporaryDirectory() as tmp,patch.object(loop,'snapshot',return_value={}):
            (Path(tmp)/'state.json').write_text(json.dumps(state))
            resumed=loop.run(MISSION,Path(tmp))
            self.assertEqual(resumed['status'],'blocked');self.assertEqual(resumed['calls'],1)

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
        with patch.object(loop.quality,'local_file',return_value=Path('fake')),patch.object(loop.quality,'read_json',return_value=record),patch.object(loop.quality,'validate_record',side_effect=lambda r:copy.deepcopy(validation)),patch.object(loop,'snapshot',return_value={}):
            result=loop.check_task_quality(task)
            self.assertTrue(result['scope_complete']);self.assertFalse(result['content_complete'])
            record['gates']['G0']['status']='unverified'
            self.assertFalse(loop.check_task_quality(task)['scope_complete'])
            record['gates']['G0']['status']='passed';record['production_snapshot']='stale'
            self.assertFalse(loop.check_task_quality(task)['scope_complete'])

if __name__=='__main__':unittest.main()
