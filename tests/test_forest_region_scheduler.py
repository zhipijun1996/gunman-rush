"""Real small-process scheduling checks; no Godot or player simulation substitutes."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('forest_region_scheduler',ROOT/'tools/run_forest_depth_region.py')
region=importlib.util.module_from_spec(spec)
spec.loader.exec_module(region)
REAL_RUN=subprocess.run
FIXTURE=r'''
import fcntl,json,os,sys,time
from pathlib import Path
folder=Path(sys.argv[1]);index=int(sys.argv[2]);delay=float(sys.argv[3]);mode=sys.argv[4]
(folder/f'pid-{index}').write_text(str(os.getpid()))
def update(delta):
 with (folder/'state.lock').open('a') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX)
  p=folder/'state.json';s=json.loads(p.read_text()) if p.exists() else {'active':0,'peak':0,'started':[],'finished':[]}
  s['active']+=delta;s['peak']=max(s['peak'],s['active']);s['started' if delta>0 else 'finished'].append(index)
  p.write_text(json.dumps(s));fcntl.flock(lock,fcntl.LOCK_UN)
update(1)
time.sleep(delay)
if len(sys.argv)>5:
 capture=Path(sys.argv[5]);capture.write_text(json.dumps({'manifest':{'layout_version':'fixture'},'env':{k:os.environ.get(k) for k in ['GUNMAN_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','GUNMAN_CHECK_TOKEN']}}))
 print('FOREST DEPTH ROUTE: fixture / 0 failures',flush=True)
 if mode=='leak':print('ERROR: 2 resources still in use at exit',flush=True)
update(-1)
sys.exit(3 if mode=='nonzero' else 0)
'''


class RegionSchedulerTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.folder=Path(self.temp.name)
        self.script=self.folder/'process.py';self.script.write_text(FIXTURE)

    def tearDown(self):self.temp.cleanup()

    def worker(self,delays,fail=None):
        def run(i,case):
            result=REAL_RUN([sys.executable,str(self.script),str(self.folder),str(i),str(delays[i]),'nonzero' if i==fail else 'ok'],capture_output=True,timeout=3)
            return {'status':'passed' if result.returncode==0 else 'failed','exit_code':result.returncode,'case':case}
        return run

    def test_two_real_processes_ordered_receipts_and_full_coverage(self):
        observations=[];cases=[('seed',1,str(i)) for i in range(8)]
        result=region.schedule_cases(cases,self.worker([.25]+[.03]*7),lambda i,row,ordered:observations.append([j for j,_ in ordered]),2)
        state=json.loads((self.folder/'state.json').read_text())
        self.assertEqual(state['peak'],2);self.assertEqual(state['active'],0)
        self.assertEqual(sorted(state['started']),list(range(8)))
        self.assertEqual(sorted(state['finished']),list(range(8)))
        self.assertEqual(sorted(result),list(range(8)))
        self.assertTrue(all(xs==sorted(xs) for xs in observations))
        self.assertEqual(observations[-1],list(range(8)))
        self.assertEqual(observations[0],[1])  # completion order really differed

    def test_failure_stops_new_work_and_waits_for_actual_active_exit(self):
        cases=[('seed',1,str(i)) for i in range(6)]
        result=region.schedule_cases(cases,self.worker([.25,.02,0,0,0,0],fail=1),lambda *_:None,2)
        state=json.loads((self.folder/'state.json').read_text())
        self.assertEqual(set(result),{0,1});self.assertEqual(result[1]['exit_code'],3)
        self.assertEqual(state['active'],0);self.assertEqual(sorted(state['finished']),[0,1])
        self.assertEqual(sorted(state['started']),[0,1])

    def test_worker_exception_is_failed_and_other_process_is_reaped(self):
        original=self.worker([.15,0,0]);cases=[('seed',1,str(i)) for i in range(3)]
        def run(i,case):
            if i==1:raise RuntimeError('actual fixture error')
            return original(i,case)
        result=region.schedule_cases(cases,run,lambda *_:None,2)
        self.assertEqual(set(result),{0,1});self.assertEqual(result[1]['status'],'failed')
        self.assertIn('case_worker_exception/RuntimeError',result[1]['errors'][0])
        self.assertEqual(json.loads((self.folder/'state.json').read_text())['active'],0)

    def test_serial_modes_preserve_one_at_a_time_and_fail_fast(self):
        cases=[('seed',1,str(i)) for i in range(4)]
        result=region.schedule_cases(cases,self.worker([.02]*4,fail=1),lambda *_:None,1)
        self.assertEqual(list(result),[0,1])
        self.assertEqual(json.loads((self.folder/'state.json').read_text())['peak'],1)

    def test_original_corpus_is_unique80_with_original_first16(self):
        cases=region.corpus_cases()
        self.assertEqual(len(cases),80);self.assertEqual(len(set(cases)),80)
        self.assertEqual(cases[:16],[(seed,index,r) for seed,index in [('forest-depth-hollow-00',1),('forest-depth-hollow-02',1),('forest-depth-hollow-00',2),('forest-depth-hollow-02',2)] for r in region.ROUTES[:4]])
        self.assertEqual(set(cases),{(f'forest-depth-hollow-{i:02d}',m,r) for i in range(10) for m in (1,2) for r in region.ROUTES[:4]})
        rows=region.schedule_cases(cases,lambda i,c:{'status':'passed','case':c},lambda *_:None,2)
        self.assertEqual([rows[i]['case'] for i in sorted(rows)],cases)

    def run_native_fixture(self,mode='ok',timeout=False):
        native_args=[]
        def invoke(argv,**kwargs):
            native_args.append((argv,kwargs.copy()))
            capture=next(x.split('=',1)[1] for x in argv if x.startswith('--output='))
            return REAL_RUN([sys.executable,str(self.script),str(self.folder),'0','.5' if timeout else '0',mode,capture],**{**kwargs,'timeout':.05 if timeout else 3})
        with mock.patch.object(region.subprocess,'run',side_effect=invoke),mock.patch.object(region,'validate',return_value=[]),mock.patch.dict(os.environ,{'GUNMAN_CHECK_TOKEN':'fixture-parent-token'}):
            row=region.run_region_case(0,('fixture-seed',2,'fast'),self.folder,layout='fixture')
        self.assertEqual(native_args[0][1]['timeout'],240)
        self.assertIn('--fixed-fps',native_args[0][0]);self.assertIn('--layout=fixture',native_args[0][0])
        return row

    def test_actual_native_fixture_env_output_and_success(self):
        row=self.run_native_fixture();self.assertEqual(row['status'],'passed')
        data=json.loads((self.folder/'00-map2-fast/capture.json').read_text())
        env=data['env'];self.assertEqual(env['GUNMAN_CHECK_TOKEN'],'fixture-parent-token')
        self.assertEqual(len(set(env[k] for k in ('GUNMAN_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME'))),3)
        self.assertEqual(env['GUNMAN_DATA_HOME'],str(self.folder/'00-map2-fast/user-data'))

    def test_actual_native_nonzero_is_failure_despite_completion(self):
        row=self.run_native_fixture('nonzero');self.assertEqual(row['status'],'failed')
        self.assertEqual(row['exit_code'],3);self.assertIn('native_nonzero',row['errors'])

    def test_actual_native_leak_is_failure_despite_completion(self):
        row=self.run_native_fixture('leak');self.assertEqual(row['status'],'failed')
        self.assertIn('native_script_error_or_leak',row['errors'])

    def test_actual_fixture_timeout_kills_and_waits(self):
        row=self.run_native_fixture(timeout=True);self.assertEqual(row['status'],'timeout')
        self.assertEqual(row['errors'],['original_240s_native_cap'])
        # subprocess.run's TimeoutExpired is raised only after killing/reaping its child.
        self.assertFalse((self.folder/'00-map2-fast/capture.json').exists())
        pid=int((self.folder/'pid-0').read_text())
        with self.assertRaises(ProcessLookupError):os.kill(pid,0)

    def test_concurrent_native_cases_keep_actual_env_and_files_independent(self):
        observed=[]
        def invoke(argv,**kwargs):
            capture=next(x.split('=',1)[1] for x in argv if x.startswith('--output='))
            index=int(Path(capture).parent.name[:2])
            return REAL_RUN([sys.executable,str(self.script),str(self.folder),str(index),'.04','ok',capture],**kwargs)
        def run(i,case):return region.run_region_case(i,case,self.folder)
        with mock.patch.object(region.subprocess,'run',side_effect=invoke),mock.patch.object(region,'validate',return_value=[]):
            rows=region.schedule_cases([('s0',1,'fast'),('s1',2,'growth')],run,lambda *args:observed.append(args),2)
        self.assertTrue(all(r['status']=='passed' for r in rows.values()))
        envs=[json.loads((self.folder/name/'capture.json').read_text())['env'] for name in ['00-map1-fast','01-map2-growth']]
        for key in ['GUNMAN_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:self.assertNotEqual(envs[0][key],envs[1][key])
        self.assertEqual(json.loads((self.folder/'state.json').read_text())['active'],0)

    def test_more_than_two_workers_refused(self):
        with self.assertRaises(ValueError):region.schedule_cases([],lambda *_:None,lambda *_:None,3)


if __name__=='__main__':unittest.main()
