"""Controller contract tests with an explicit fake worker, never proof of AI review."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
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

if __name__=='__main__':unittest.main()
