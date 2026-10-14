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
        with patch.object(loop.quality,'local_file',return_value=Path('fake')),patch.object(loop.quality,'read_json',return_value=record),patch.object(loop.quality,'validate_record',side_effect=lambda r:copy.deepcopy(validation)),patch.object(loop,'snapshot',return_value={}):
            result=loop.check_task_quality(task)
            self.assertTrue(result['scope_complete']);self.assertFalse(result['content_complete'])
            record['gates']['G0']['status']='unverified'
            self.assertFalse(loop.check_task_quality(task)['scope_complete'])
            record['gates']['G0']['status']='passed';record['production_snapshot']='stale'
            self.assertFalse(loop.check_task_quality(task)['scope_complete'])

if __name__=='__main__':unittest.main()
