"""Pure fake-browser execution of the actual new run(), plus strict-join faults.
No real browser/engine, native output, image view, or current Web claim occurs.
"""
import asyncio
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import time
from types import ModuleType, SimpleNamespace as NS
import unittest
from unittest.mock import patch
import offline_review as review

BASE=Path(__file__).resolve().parent
def sha(raw):return hashlib.sha256(raw).hexdigest()

class Fixture:
    def __init__(self,fault=None):
        self.temp=tempfile.TemporaryDirectory();self.base=Path(self.temp.name);self.root=self.base/'root';self.root.mkdir();self.bundle=self.base/'bundle';self.bundle.mkdir();self.fault=fault;self.clock=0.;self.module_clock=0.;self.closed=False;self.source_calls=0
        spec=importlib.util.spec_from_file_location('actual_automated_driver',BASE/'automated_driver.py');self.m=importlib.util.module_from_spec(spec);spec.loader.exec_module(self.m)
        self.source='d'*40;self.host='a'*64;self.content='b'*64;self.fingerprint='c'*64
        self.output=dict(status='PASS',seed=930007,request_fingerprint=self.fingerprint,instances=43,connections=55,content_entries=43)
        self.identity=dict(source_kind='generated_memory',generation_input_fingerprint=self.fingerprint,map_content_identity=self.content,host_load_identity=self.host,result_receipt_digest='e'*64,host_load=dict(spawn=[474.,974.],selected_instances=['fixture-module']),source_receipt=dict(kind='generated_memory',request=dict(seed=930007),module_archive=dict(sha256='1'*64),algorithm_package=dict(zip_sha256='2'*64)))
        files=['tools/verify_four_line_browser.py','tools/verify_forest_browser.py','tools/studio_gui_pointer.py','tools/verify_ci_artifact_browser.py','tools/check_web_bundle.py','tools/install_mapgen_candidate.py','tools/verify_mapgen_reference.py','experiments/platform/cloud_preview.gd','experiments/generation/runtime_map_slice.gd','experiments/generation/runtime_map_m35_slice.tscn','experiments/generation/runtime_map_generated_slice.gd','experiments/generation/runtime_map_generation_job.gd','experiments/generation/runtime_map_generation_request.gd','game/world/levels/providers/runtime_map_v2_provider.gd','experiments/generation/runtime_map_m35_slice.gd','experiments/generation/runtime_map_generation_profile.gd','experiments/generation/runtime_map_generated_selection.gd']
        for name in files:self.put(name,b'pure fake source')
        self.config=dict(version='0.4.0',implementation='mapgen/gdscript-candidate-0.4.0',module_package=dict(sha256='1'*64),archive=dict(sha256='2'*64),gears_conformance=dict(request=dict(path='resources/request.json')))
        self.put('config/mapgen_candidate.json',json.dumps(self.config).encode());self.put('resources/request.json',json.dumps(dict(seed=930007)).encode())
        for consumer,prefix,path in [('experiments/generation/runtime_map_generated_slice.gd','DEFAULT_BINDINGS','resources/default-binding.json'),('experiments/generation/runtime_map_m35_slice.gd','BINDINGS','resources/gears-binding.json')]:
            raw=b'{"fake_binding":true}';self.put(path,raw);self.put(consumer,f'const {prefix}_PATH := "res://{path}"\nconst {prefix}_SHA256 := "{sha(raw)}"\n'.encode())
        locks={}
        for name in self.m.RAW_NAMES:
            if name=='input-lock.json':continue
            raw=json.dumps(dict(fake_file=name)).encode();self.put(self.m.RAW_ROOT+name,raw);locks[name]=sha(raw)
        self.put(self.m.RAW_ROOT+'input-lock.json',json.dumps(dict(files=locks)).encode())
        pack_raw=b'PURE SYNTHETIC PACK; not a Godot pack';self.pack_sha=sha(pack_raw);(self.bundle/'index.pck').write_bytes(pack_raw)
        self.info=dict(source_commit=self.source,build_id=self.pack_sha[:12],pack='index.pck',pack_bytes=len(pack_raw));(self.bundle/'build-info.json').write_text(json.dumps(self.info))
        self.html='/* cloud-preview-entry */ args: '+json.dumps(['--cloud-preview','--entry=scene','--scene='+self.m.SCENE])+','
        (self.bundle/'index.html').write_text(self.html);(self.bundle/'index.cache-sw.js').write_text('fake worker')
        self.proof=self.base/'native-proof.log';self.proof.write_text('PURE SYNTHETIC NATIVE FIXTURE')
        self.expected=dict(schema='gunman-rush/mapgen04-browser-expected/v1',source=self.source,scene=self.m.SCENE,sdk_implementation=self.config['implementation'],input_profile='gears_conformance',runtime_profile='conformance',host_load_identity=self.host,map_content_identity=self.content,spawn=[474.,974.],selected_instances=['fixture-module'],native_proof_file=str(self.proof),native_proof_sha256=sha(self.proof.read_bytes()),actual_generated_output=self.output,mechanisms=dict(ferry_ids=['ascent_0','ascent_1'],saw_ids=['relay_gear'],static_contact_rect=[428.,1042.,912.,40.]))
        self.expected_path=self.base/'expected.json';self.expected_path.write_text(json.dumps(self.expected));self.report={}
        self.args=NS(source_root=self.root,bundle=self.bundle,source=self.source,url='http://127.0.0.1:9999/',pack_sha256=self.pack_sha,pack_bytes=len(pack_raw),expected_host_load_identity=self.host,expected_observation=self.expected_path,output=self.base/'actual',commands=self.base/'commands',ocr_prefix=self.base,producer_file=[],proxy_from_environment=False)
        self.check_module=ModuleType('check_web_bundle');self.check_module.mapgen_candidate_contract=lambda root:dict(config='config/mapgen_candidate.json',data=['resources/request.json'],addons=[]);self.check_module.check_mapgen_payload=lambda pack,root:dict(scope='pure fake dependency guard')
        for key,value in dict(MAPGEN_GENERATED_SOURCE='experiments/generation/runtime_map_generated_slice.gd',MAPGEN_DEFAULT_BINDINGS='resources/default-binding.json',MAPGEN_M35_SOURCE='experiments/generation/runtime_map_m35_slice.gd',MAPGEN_M35_BINDINGS='resources/gears-binding.json').items():setattr(self.check_module,key,value)
        owner=self
        class FakeGuard:
            def __init__(self,*a):pass
            def snapshot(self):
                owner.source_calls+=1
                if owner.fault=='afterguard-error' and owner.source_calls>1:raise RuntimeError('synthetic final guard fault')
                return dict(source_sha256={'file':'changed' if owner.fault=='source' and owner.source_calls>1 else 'stable'})
        class FakePack:
            def __init__(self,*a):pass
            def read(self,name):return (owner.root/name).read_bytes()
        def locate(*a):
            if owner.fault=='missing-title':raise ValueError('Actual OCR fixture has no Title')
            return [231.,189.]
        self.m.helpers=lambda *a:(locate,lambda *a:dict(source=self.source),lambda:({},None),FakeGuard,FakePack,lambda *a:True)
        self.m.time=NS(monotonic=self.monotonic,time=lambda:1000000+self.clock,time_ns=lambda:int((1000000+self.clock)*1e9))
        self.m.asyncio=NS(sleep=self.sleep)
        self.playwright_module=ModuleType('playwright.async_api');self.playwright_module.async_playwright=lambda:FakePlaywright(self)

    def put(self,name,raw):
        p=self.root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(raw)
    def monotonic(self):self.clock+=.001;return self.clock
    async def sleep(self,delay):
        self.clock+=max(delay,.5)
        if hasattr(self,'page') and not self.closed:self.emit_physics()
    def host_value(self,event):
        c=self.module_clock
        return dict(event=event,host_load_identity=self.host,player=[0,0] if self.fault=='spawn' and event=='loaded' else [474.,974.],carrier=[0.,0.],grounded=True,mechanisms=[dict(instance_id='fixture-module',clock=c,ferries=[dict(id='ascent_0',position=[c*5,1.]),dict(id='ascent_1',position=[c*8,3.])],saws=[dict(id='relay_gear',position=[c*11,7.])])],static_contacts=[dict(id='contact',rect=[428.,1042.,912.,40.],fall_plane=True,enabled=True,shared_policy=True)])
    def emit(self,prefix,value):self.page.handlers['console'](NS(type='log',text=prefix+json.dumps(value),location={}))
    def emit_physics(self):self.module_clock+=.5;self.emit(self.m.HOST_PREFIX,self.host_value('physics'))
    def runtime(self,event):
        return dict(event=event,phase=event,source_kind='generated_memory',profile='conformance',ready=event=='committed',actual_hook_enabled=False,output=self.output,identity=self.identity)
    def opener(self,*a):
        def open_(request,timeout):
            name=request.full_url.split('?')[0].rsplit('/',1)[-1]
            data={'build-info.json':json.dumps(self.info).encode(),'index.html':self.html.encode(),'index.cache-sw.js':b'fake worker'}[name]
            return NS(read=lambda:data)
        return NS(open=open_)
    async def execute(self):
        with patch.dict(sys.modules,{'check_web_bundle':self.check_module,'playwright.async_api':self.playwright_module}),patch('urllib.request.build_opener',self.opener):
            try:await self.m.run(self.args,self.report)
            except BaseException as error:
                self.report['status']='FAILED';self.report['exception']=repr(error)
                if self.args.output.is_dir():(self.args.output/'report.json').write_text(json.dumps(self.report,indent=2)+'\n')
        return self.report

class FakePlaywright:
    def __init__(self,o):self.o=o;self.chromium=self
    async def __aenter__(self):return self
    async def __aexit__(self,*a):pass
    async def launch(self,**kwargs):return FakeBrowser(self.o)
class FakeBrowser:
    version='PURE_FAKE_BROWSER'
    def __init__(self,o):self.o=o
    async def new_context(self,**kwargs):return FakeContext(self.o)
    async def close(self):pass
class FakeContext:
    def __init__(self,o):self.o=o
    async def new_page(self):self.o.page=FakePage(self.o);return self.o.page
    async def close(self):pass
class FakePage:
    def __init__(self,o):self.o=o;self.handlers={};self.keyboard=NS(press=self.press)
    def on(self,event,fn):self.handlers[event]=fn
    async def goto(self,*a,**kwargs):
        o=self.o
        for event in ['started','preload','generate','validate','ready','committed']:
            if not(o.fault=='missing-marker' and event=='ready'):o.emit(o.m.RUNTIME_PREFIX,o.runtime(event))
        if o.fault=='latecommit':o.emit(o.m.RUNTIME_PREFIX,o.runtime('committed'))
        o.emit(o.m.HOST_PREFIX,o.host_value('loaded'));o.emit_physics();o.emit_physics()
        if o.fault=='page':self.handlers['pageerror']('synthetic page failure')
        if o.fault=='timeout':o.clock=301.
    async def screenshot(self,path,**kwargs):
        if self.o.fault!='missing-image':Path(path).write_bytes(('PURE FAKE CAPTURE '+Path(path).name).encode())
        self.o.clock+=.05
    async def press(self,key):
        o=self.o;assert key=='Escape';o.closed=True
        o.emit(o.m.HOST_PREFIX,dict(event='closed',audio_released=o.fault!='cleanup',lifetime_active=False,stage_detached=True))
        o.emit(o.m.RUNTIME_PREFIX,dict(event='source_closed',closed=True))
        self.handlers['console'](NS(type='log',text='CLOUD PREVIEW: returned to full game menu; persistence=false',location={}))

class ExecutionTests(unittest.TestCase):
    def run_case(self,fault=None):
        f=Fixture(fault);self.addCleanup(f.temp.cleanup);r=asyncio.run(f.execute());return f,r
    def test_complete_is_pending_not_passed_and_ignores_late_ack(self):
        f=Fixture();self.addCleanup(f.temp.cleanup);f.args.commands.mkdir();(f.args.commands/'command.json').write_text(json.dumps(dict(seq=3,action='confirm-title',passed=True)))
        r=asyncio.run(f.execute());self.assertEqual(r['status'],review.PENDING);self.assertTrue(r['source_stable']);self.assertEqual(len(r['sessions'][0]['screenshots']),7);self.assertNotIn('operator_visual_review',r['sessions'][0]);review.validate_report(f.args.output/'report.json')
    def test_original_failure_assertions_and_budget(self):
        for fault in ['timeout','source','afterguard-error','page','spawn','missing-title','cleanup','latecommit','missing-marker','missing-image']:
            with self.subTest(fault=fault):
                f,r=self.run_case(fault);self.assertNotEqual(r['status'],review.PENDING)
                with self.assertRaises(ValueError):review.validate_report(f.args.output/'report.json')

class JoinTests(unittest.TestCase):
    def setUp(self):
        self.f=Fixture();self.addCleanup(self.f.temp.cleanup);asyncio.run(self.f.execute());self.report=self.f.args.output/'report.json';self.review=self.f.base/'review.json';self.output=self.f.base/'acceptance.json'
        review.begin(self.report,self.review,'PURE_TEST_INDEPENDENT_REVIEWER')
    def complete_synthetic_review(self):
        value=review.read(self.review);now=time.time()*1000
        value['records']=[dict(file=item['file'],capture_sha256=item['sha256'],decision='pass',method=review.ACTUAL_VIEW_METHOD,notes='PURE_SYNTHETIC_REVIEW_FIXTURE only; no actual view or real acceptance',started_epoch_ms=now,finished_epoch_ms=now) for item in value['captures']]
        self.review.write_text(json.dumps(value))
    def test_strict_join_positive_fixture_and_no_overwrite(self):
        self.complete_synthetic_review();value=review.finish(self.report,self.review,self.output);self.assertTrue(value['status'].startswith('PASSED'))
        for path in [self.report,self.review,self.output,self.f.args.output/review.FILES[0]]:
            before=path.read_bytes()
            with self.assertRaises(ValueError):review.finish(self.report,self.review,path)
            self.assertEqual(path.read_bytes(),before)
    def test_missing_review_empty_pass_wrong_sha_nan_and_late_ack_rejected(self):
        initial=self.review.read_bytes()
        for fault in ['missing','empty-notes','empty-method','automatic-method','wrong-sha','nan-time','late-ack','failed-auto','nan-budget','capture-change','missing-capture']:
            with self.subTest(fault=fault):
                self.review.write_bytes(initial);self.complete_synthetic_review();v=review.read(self.review);raw_report=self.report.read_bytes();pic=self.f.args.output/review.FILES[0];raw_pic=pic.read_bytes()
                if fault=='missing':v['records'].pop()
                if fault=='empty-notes':v['records'][0]['notes']=''
                if fault=='empty-method':v['records'][0]['method']=''
                if fault=='automatic-method':v['records'][0]['method']='automatic-unseen-approval'
                if fault=='wrong-sha':v['records'][0]['capture_sha256']='0'*64
                if fault=='nan-time':v['records'][0]['finished_epoch_ms']=float('nan')
                if fault=='late-ack':v=dict(seq=3,action='confirm-title',passed=True)
                if fault in ['failed-auto','nan-budget']:
                    r=json.loads(raw_report)
                    if fault=='failed-auto':r['status']='FAILED'
                    else:r['elapsed_seconds']=float('nan')
                    self.report.write_text(json.dumps(r))
                if fault=='capture-change':pic.write_bytes(b'wrong bytes')
                if fault=='missing-capture':pic.unlink()
                self.review.write_text(json.dumps(v))
                with self.assertRaises(ValueError):review.finish(self.report,self.review,self.output)
                self.report.write_bytes(raw_report);pic.write_bytes(raw_pic)
    def test_begin_refuses_report_or_capture_alias(self):
        for path in [self.report,self.f.args.output/review.FILES[0]]:
            before=path.read_bytes()
            with self.assertRaises(ValueError):review.begin(self.report,path,'PURE_TEST_INDEPENDENT_REVIEWER')
            self.assertEqual(path.read_bytes(),before)
    def test_empty_or_author_reviewer_rejected(self):
        for identity in ['', '/root/browser_verify']:
            with self.assertRaises(ValueError):review.begin(self.report,self.f.base/'other-review.json',identity)
    def test_missing_or_changed_normal_source_vector_rejected(self):
        vector=self.f.args.output/'source-after.json.gz';original=vector.read_bytes()
        vector.unlink()
        with self.assertRaises(ValueError):review.validate_report(self.report)
        vector.write_bytes(original)
        import gzip
        vector.write_bytes(gzip.compress(b'{"wrong_source":true}'))
        with self.assertRaises(ValueError):review.validate_report(self.report)

if __name__=='__main__':unittest.main()
