#!/usr/bin/env python3
"""FIXTURE: real publisher subprocess, fake gh, and a local HTTP fault server.
These tests do not dispatch GitHub workflows or claim a real deployment.
"""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest
import zipfile

import publish_playtest as publisher

ROOT = Path(__file__).resolve().parents[1]
SHA = 'a' * 40
PACK = b'fixture-native-pack' * 8
BUILD = hashlib.sha256(PACK).hexdigest()[:12]
INFO = {'source_commit': SHA, 'build_id': BUILD, 'pack': 'game.pck', 'pack_bytes': len(PACK)}
FAKE_GH = '''#!/usr/bin/env python3
import json,os,pathlib,sys
p=pathlib.Path(os.environ['PUBLISH_FIXTURE_STATE']);s=json.loads(p.read_text());a=sys.argv[1:];s.setdefault('calls',[]).append(a)
def done(value=None,code=0,error=''):
 p.write_text(json.dumps(s))
 if value is not None:print(value if isinstance(value,str) else json.dumps(value))
 if error:print(error,file=sys.stderr)
 sys.exit(code)
def run(identity=77):
 return {'id':identity,'head_sha':s['sha'],'head_branch':s.get('branch','feature/test'),'event':'workflow_dispatch','path':'.github/workflows/environment.yml','run_attempt':s.get('attempt',1),'html_url':'https://example.invalid/run/77','status':'completed' if s.get('complete') else 'in_progress','conclusion':s.get('conclusion','success') if s.get('complete') else None}
if a[:2]==['repo','view']:done({'nameWithOwner':'fixture/repo'})
if a[:2]==['workflow','run']:
 s['dispatched']=True
 if s.get('lost_dispatch_response'):done(code=1,error='network connection reset after dispatch')
 done('')
if a[:2]==['run','download']:
 if s.get('download_forbidden'):done(code=1,error='HTTP 403 forbidden')
 d=pathlib.Path(a[a.index('--dir')+1]);d.mkdir(parents=True,exist_ok=True);(d/'build-info.json').write_text(json.dumps(s.get('artifact_info',s['info'])));done('')
if a[0]=='api':
 route=a[1]
 if '/commits/' in route:done(s['sha'])
 if route.endswith('/pages'):done(s['url'])
 if '/workflows/' in route:
  values=[run()] if s.get('dispatched') else []
  if s.get('ambiguous') and s.get('dispatched'):values.append(run(78))
  done({'workflow_runs':values})
 if '/attempts/' in route and '/jobs?' in route:done({'total_count':2,'jobs':[{'id':101,'name':'deploy_web','status':'completed','conclusion':'skipped' if s.get('no_deployment') else 'success'},{'id':102,'name':'verify_public','status':'completed','conclusion':'success'}]})
 if '/artifacts?' in route:done({'artifacts':[{'id':9,'name':'gunman-rush-web-playtest','expired':False,'digest':s.get('artifact_digest'),'workflow_run':{'id':77,'head_sha':s.get('artifact_sha',s['sha'])}}]})
 if route.endswith('/actions/runs/77'):
  s['run_reads']=s.get('run_reads',0)+1
  if s.get('switch_attempt_after') and s['run_reads']>=s['switch_attempt_after']:s['attempt']=2
  if s.get('read_fault_remaining',0)>0:
   s['read_fault_remaining']-=1;done(code=1,error=s.get('read_fault','HTTP 502 service unavailable'))
  done(run())
done(code=1,error='unexpected fixture gh argv: '+str(a))
'''


class Public(BaseHTTPRequestHandler):
    owner = None
    def log_message(self, *args): pass
    def do_GET(self):
        owner = type(self).owner; owner.http_calls += 1
        if owner.http_mode == 'forbidden': self.send_error(403); return
        if owner.http_mode == 'unavailable_once' and owner.http_calls == 1: self.send_error(503); return
        info = {**INFO, 'build_id': 'badbadbadbad'} if owner.http_mode == 'stale' else INFO
        data = json.dumps(info).encode()
        self.send_response(200); self.send_header('Content-Type','application/json'); self.send_header('Content-Length',str(len(data))); self.end_headers(); self.wfile.write(data)


class PublisherRecovery(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.transcripts=[]
        self.root = Path(self.temp.name); self.fixture = self.root/'fixture.json'; self.checkpoint = self.root/'checkpoint.json'
        (self.root/'gh').write_text(FAKE_GH); (self.root/'gh').chmod(0o755)
        self.http_mode = 'ok'; self.http_calls = 0; Public.owner = self
        self.server = ThreadingHTTPServer(('127.0.0.1',0),Public)
        self.thread=threading.Thread(target=self.server.serve_forever,daemon=True); self.thread.start()
        self.addCleanup(self.close_server)
        self.update(sha=SHA,info=INFO,url=f'http://127.0.0.1:{self.server.server_port}/',calls=[])
    def tearDown(self):
        destination=os.environ.get('PUBLISH_FIXTURE_EVIDENCE_DIR')
        if destination:
            folder=Path(destination);folder.mkdir(parents=True,exist_ok=True)
            (folder/(self._testMethodName+'.json')).write_text(json.dumps({'scope':'isolated fixture; fake gh and local HTTP, no real dispatch','transcripts':self.transcripts,'fake_gh_state':self.data(),'checkpoint':self.state() if self.checkpoint.exists() else None,'http_calls':self.http_calls},indent=2)+'\n')
    def close_server(self): self.server.shutdown(); self.server.server_close(); self.thread.join()
    def update(self, **values):
        data=json.loads(self.fixture.read_text()) if self.fixture.exists() else {}; data.update(values); self.fixture.write_text(json.dumps(data))
    def data(self): return json.loads(self.fixture.read_text())
    def state(self): return json.loads(self.checkpoint.read_text())
    def bound(self):
        self.checkpoint.write_text(json.dumps({'schema':1,'repo':'fixture/repo','ref':'feature/test','commit':SHA,'url':self.data()['url'],'run_id':77,'attempt':1,'phase':'waiting_ci','events':[]}))
    def invoke(self, *extra, timeout='1'):
        env={**os.environ,'PATH':str(self.root)+os.pathsep+os.environ['PATH'],'PUBLISH_FIXTURE_STATE':str(self.fixture)}
        result=subprocess.run(['python3','tools/publish_playtest.py','--ref','feature/test','--timeout',timeout,'--poll-interval','0.01','--checkpoint',str(self.checkpoint),*extra],cwd=ROOT,env=env,capture_output=True,text=True,timeout=15)
        self.transcripts.append({'exit_code':result.returncode,'stdout':result.stdout,'stderr':result.stderr})
        return result, json.loads(result.stdout.splitlines()[-1])
    def dispatched(self): return sum(v[:2]==['workflow','run'] for v in self.data()['calls'])
    def test_interrupt_then_resume_binds_run_and_exact_public_artifact(self):
        result,output=self.invoke(timeout='0.2'); self.assertEqual(result.returncode,1); self.assertEqual(output['failure_kind'],'poll_timeout')
        self.update(complete=True)
        result,output=self.invoke('--resume'); self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(self.dispatched(),1); self.assertTrue(output['live_verified']); self.assertEqual(output['build_id'],BUILD)
        self.assertEqual((self.state()['run_id'],self.state()['attempt'],self.state()['artifact_id']),(77,1,9))
        result,_=self.invoke('--resume'); self.assertEqual(result.returncode,0); self.assertEqual(self.dispatched(),1)
    def test_lost_dispatch_response_resumes_without_second_mutation(self):
        self.update(lost_dispatch_response=True,complete=True)
        result,output=self.invoke(); self.assertEqual(output['failure_kind'],'network_or_service'); self.assertEqual(self.state()['phase'],'dispatch_uncertain')
        result,output=self.invoke('--resume'); self.assertEqual(result.returncode,0,result.stdout+result.stderr); self.assertEqual(self.dispatched(),1)
    def test_sha_ref_and_attempt_mismatch_are_refused(self):
        for change in ['sha','ref','attempt']:
            with self.subTest(change=change):
                self.update(sha=SHA,attempt=1,complete=True); self.bound()
                if change=='sha':self.update(sha='b'*40)
                elif change=='ref':
                    state=self.state();state['ref']='other';self.checkpoint.write_text(json.dumps(state))
                else:self.update(attempt=2)
                result,output=self.invoke('--resume');self.assertEqual(result.returncode,1);self.assertEqual(output['failure_kind'],'identity_mismatch')
        self.assertEqual(self.dispatched(),0)
    def test_auth_permission_and_network_are_distinct_and_bounded(self):
        for fault,kind,count in [('HTTP 401 bad credentials','authentication',1),('HTTP 403 forbidden','permission_or_policy',1),('HTTP 502 service unavailable','network_or_service',3)]:
            with self.subTest(fault=fault):
                self.bound();self.update(read_fault=fault,read_fault_remaining=5,calls=[])
                result,output=self.invoke('--resume');self.assertEqual(output['failure_kind'],kind)
                reads=[v for v in self.data()['calls'] if v[0]=='api' and v[1].endswith('/actions/runs/77')]
                self.assertEqual(len(reads),count)
    def test_concurrent_rerun_before_final_verification_is_refused(self):
        self.bound();self.update(complete=True,switch_attempt_after=2)
        result,output=self.invoke('--resume');self.assertEqual(output['failure_kind'],'identity_mismatch');self.assertFalse(self.state().get('live_verified',False))
    def test_failed_ci_is_terminal_without_automatic_rerun(self):
        self.bound();self.update(complete=True,conclusion='failure')
        result,output=self.invoke('--resume');self.assertEqual(result.returncode,1);self.assertEqual(output['failure_kind'],'ci_failed');self.assertEqual(self.state()['phase'],'ci_failed');self.assertEqual(self.dispatched(),0)
    def test_public_service_failure_recovers_but_permission_does_not(self):
        self.bound();self.update(complete=True);self.http_mode='unavailable_once'
        result,output=self.invoke('--resume');self.assertEqual(result.returncode,0,result.stdout+result.stderr);self.assertEqual(self.http_calls,2)
        self.http_mode='forbidden'
        result,output=self.invoke('--resume');self.assertEqual(output['failure_kind'],'permission_or_policy')
        downloads=[v for v in self.data()['calls'] if v[:2]==['run','download']];self.assertEqual(len(downloads),1)
    def test_explicit_api_digest_bound_zip_recovers_403_without_dispatch(self):
        self.bound();self.update(complete=True,download_forbidden=True)
        result,output=self.invoke('--resume');self.assertEqual(output['failure_kind'],'permission_or_policy')
        archive=self.root/'recovered.zip'
        with zipfile.ZipFile(archive,'w') as target:
            target.writestr('build-info.json',json.dumps(INFO));target.writestr(INFO['pack'],PACK)
        digest=hashlib.sha256(archive.read_bytes()).hexdigest();self.update(artifact_digest='sha256:'+digest)
        result,output=self.invoke('--resume','--artifact-zip',str(archive));self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(self.state()['artifact_archive']['zip_sha256'],digest)
        self.assertEqual(self.state()['artifact_archive']['pack_sha256'],hashlib.sha256(PACK).hexdigest())
        self.assertEqual(self.dispatched(),0)
        self.assertEqual(sum(v[:2]==['run','download'] for v in self.data()['calls']),1)
    def test_green_ci_without_actual_deploy_jobs_is_refused(self):
        self.bound();self.update(complete=True,no_deployment=True)
        result,output=self.invoke('--resume');self.assertEqual(output['failure_kind'],'deployment_receipt');self.assertEqual(self.http_calls,0)
    def test_public_same_source_wrong_build_is_never_verified(self):
        self.bound();self.update(complete=True);self.http_mode='stale'
        result,output=self.invoke('--resume',timeout='0.3');self.assertEqual(output['failure_kind'],'poll_timeout');self.assertFalse(self.state().get('live_verified',False));self.assertEqual(self.state()['last_public_error']['kind'],'stale_or_wrong_public_build')
    def test_wrong_artifact_and_ambiguous_dispatch_are_refused(self):
        self.bound();self.update(complete=True,artifact_sha='b'*40)
        result,output=self.invoke('--resume');self.assertEqual(output['failure_kind'],'artifact_identity');self.assertEqual(self.http_calls,0)
        self.checkpoint.unlink();self.update(lost_dispatch_response=True,ambiguous=True,artifact_sha=SHA)
        result,_=self.invoke();self.assertEqual(result.returncode,1)
        # Prior list already contained both fixture runs; emulate no prior run
        # at initial dispatch so the lost-response recovery sees ambiguity.
        state=self.state();state['prior_run_ids']=[];self.checkpoint.write_text(json.dumps(state))
        result,output=self.invoke('--resume');self.assertEqual(output['failure_kind'],'ambiguous_run');self.assertEqual(self.dispatched(),1)


class ArtifactArchiveValidation(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
    def archive(self,name='artifact.zip',info=None,pack=PACK,extra=None):
        target=self.root/name
        with zipfile.ZipFile(target,'w') as output:
            output.writestr('build-info.json',json.dumps(INFO if info is None else info))
            output.writestr('game.pck',pack)
            for path,data in (extra or {}).items():output.writestr(path,data)
        return target,{'id':9,'digest':'sha256:'+hashlib.sha256(target.read_bytes()).hexdigest()}
    def test_real_archive_stream_validation_and_bound_identity(self):
        archive,artifact=self.archive()
        info,receipt=publisher.verify_artifact_zip(archive,artifact,SHA,[])
        self.assertEqual(info,INFO);self.assertEqual(receipt['pack_bytes'],len(PACK));self.assertEqual(receipt['artifact_id'],9)
    def test_archive_corruption_identity_duplicate_metadata_and_pack_negatives(self):
        cases=[]
        archive,artifact=self.archive('wrong-digest.zip');cases.append((archive,{**artifact,'digest':'sha256:'+'0'*64},'archive_integrity'))
        wrong_zip=self.root/'wrong.zip';wrong_zip.write_bytes(b'not the API archive');cases.append((wrong_zip,artifact,'archive_integrity'))
        archive,artifact=self.archive('wrong-source.zip',info={**INFO,'source_commit':'b'*40});cases.append((archive,artifact,'artifact_identity'))
        archive,artifact=self.archive('duplicate-info.zip',extra={'nested/build-info.json':json.dumps(INFO)});cases.append((archive,artifact,'archive_integrity'))
        archive,artifact=self.archive('wrong-size.zip',info={**INFO,'pack_bytes':len(PACK)+1});cases.append((archive,artifact,'archive_integrity'))
        archive,artifact=self.archive('wrong-pack.zip',pack=b'X'*len(PACK));cases.append((archive,artifact,'archive_integrity'))
        archive,artifact=self.archive('unsafe-path.zip',extra={'../escape':b'unsafe'});cases.append((archive,artifact,'archive_integrity'))
        for archive,artifact,kind in cases:
            with self.subTest(archive=archive.name):
                with self.assertRaises(publisher.PublishError) as caught:publisher.verify_artifact_zip(archive,artifact,SHA,[])
                self.assertEqual(caught.exception.kind,kind)


if __name__ == '__main__': unittest.main()
