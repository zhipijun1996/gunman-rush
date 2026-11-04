"""Final generated preview with exact initial spawn; one original total300s budget."""
import argparse, ast, asyncio, csv, gzip, hashlib, io, json, math, os
import re, subprocess, sys, time, urllib.request
from pathlib import Path
from urllib.parse import urljoin, urlparse
sys.dont_write_bytecode = True
SCENE = 'res://experiments/generation/runtime_map_generated_slice.tscn'
HOST_PREFIX = 'MAPGEN_HOST_V2 '
RUNTIME_PREFIX = 'MAPGEN_RUNTIME '
RAW_ROOT = 'resources/levels/mapgen_host_v2_01/'
RAW_NAMES = ['input-lock.json','map.json','bindings.json','selection.json','content/M16.json','content/M18.json','content/M21.json']
BUDGET = 300

def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream,'sha256').hexdigest()

def arguments():
    p = argparse.ArgumentParser(description=__doc__)
    for flag in ['source-root','bundle','output','commands','ocr-prefix']:
        p.add_argument('--'+flag,type=Path,required=True)
    for flag in ['source','url','pack-sha256']:
        p.add_argument('--'+flag,required=True)
    p.add_argument('--pack-bytes',type=int,required=True)
    p.add_argument('--expected-host-load-identity',required=True)
    p.add_argument('--producer-file',type=Path,action='append',default=[])
    p.add_argument('--proxy-from-environment',action='store_true')
    a=p.parse_args()
    assert re.fullmatch('[0-9a-f]{40}',a.source)
    assert re.fullmatch('[0-9a-f]{64}',a.pack_sha256) and a.pack_bytes>0
    if a.expected_host_load_identity: assert re.fullmatch('[0-9a-f]{64}',a.expected_host_load_identity)
    assert urlparse(a.url).scheme in ('http','https')
    if urlparse(a.url).hostname not in ('127.0.0.1','localhost','::1'): assert a.proxy_from_environment
    return a
def helpers(root, ocr_prefix):
    sys.path.insert(0, str(root/'tools'))
    from verify_forest_browser import locate, locate_original, norm, validate_identity, environment_proxy
    from studio_gui_pointer import locate_pixel_control, native_surfaces, title_surface, touch_menu_surface
    from verify_ci_artifact_browser import SourceRoot
    from check_web_bundle import Pack
    from style_exploration_delivery import resource
    os.environ['TESSDATA_PREFIX'] = str(ocr_prefix)
    ns = dict(csv=csv, io=io, os=os, subprocess=subprocess, locate=locate,
              locate_original=locate_original, norm=norm, locate_pixel_control=locate_pixel_control,
              native_surfaces=native_surfaces, title_surface=title_surface,
              touch_menu_surface=touch_menu_surface,
              TESS_ARGS=['--tessdata-dir','/workspace/toolchains/tessdata-4.1.0-fast'])
    tree = ast.parse((root/'tools/verify_four_line_browser.py').read_text())
    nodes = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in {'locate_cjk','locate_primary','locate_any'}]
    assert len(nodes) == 3
    exec(compile(ast.Module(body=nodes,type_ignores=[]),'existing_GUI_helpers','exec'),ns)
    return ns['locate_any'], validate_identity, environment_proxy, SourceRoot, Pack, resource


async def run(a, report):
    started=time.monotonic();out=a.output
    out.mkdir(parents=True,exist_ok=False);a.commands.mkdir(parents=True,exist_ok=True)
    root=a.source_root.resolve();bundle=a.bundle.resolve()
    guard=None;before=None;frozen=None
    def save(): (out/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    def compressed(name,value):
        raw=json.dumps(value,separators=(',',':')).encode()
        (out/name).write_bytes(gzip.compress(raw,mtime=0));return hashlib.sha256(raw).hexdigest()
    def remaining(maximum):
        left=BUDGET-(time.monotonic()-started)
        if left<=0: raise TimeoutError('Original total300s budget exhausted')
        return min(maximum,max(1,int(left*1000)))
    report.update(status='RUNNING',source=a.source,url=a.url,sessions=[],browser_closed=False,
                  scope='Real generated source and cancellation through real keyboard/mouse, original OCR helpers, and passive console only. Zero init scripts, page.evaluate calls, FPS04, GL/RAF observers, game resource/state writes or teleport. Exact first-loaded player [-448,846] is required; the prior 5b0 run omitted this assertion and loaded [0,0]. Software SwiftShader; no phone/FPS/seam/full-map acceptance. Total300s includes both fresh contexts and guards.')
    save()
    try:
        locate_any,validate_identity,environment_proxy,SourceRoot,Pack,resource=helpers(root,a.ocr_prefix)
        from check_web_bundle import mapgen_candidate_contract,check_mapgen_payload
        from playwright.async_api import async_playwright
        guard=SourceRoot(root,a.source);before=guard.snapshot()
        report['source_before_raw_sha256']=compressed('source-before.json.gz',before)
        report['source_before_file_count']=len(before['source_sha256'])
        info=json.loads((bundle/'build-info.json').read_text());pack_path=bundle/info['pack']
        assert info['source_commit']==a.source and info['build_id']==a.pack_sha256[:12]
        assert info['pack_bytes']==a.pack_bytes==pack_path.stat().st_size
        assert sha(pack_path)==a.pack_sha256
        pack=Pack(pack_path);assert resource(pack,SCENE.removeprefix('res://'))
        assert resource(pack,'experiments/platform/entries/cloud_preview.tscn')
        contract=mapgen_candidate_contract(root);assert contract
        report['installed_PCK_dependencies']=check_mapgen_payload(pack,root)
        report['locked_byte_readback']=[]
        for name in [contract['config'],*contract['data']]:
            raw=pack.read(name);assert raw==(root/name).read_bytes()
            report['locked_byte_readback'].append(dict(path=name,bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest()))
        config=json.loads(pack.read(contract['config']))
        report['frozen_JSON_readback']=[]
        for name in RAW_NAMES:
            path=RAW_ROOT+name;raw=pack.read(path);assert raw==(root/path).read_bytes()
            report['frozen_JSON_readback'].append(dict(path=path,bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest()))
        lock=json.loads(pack.read(RAW_ROOT+'input-lock.json'))
        assert set(lock['files'])==set(RAW_NAMES)-{'input-lock.json'}
        for name,digest in lock['files'].items(): assert hashlib.sha256(pack.read(RAW_ROOT+name)).hexdigest()==digest
        frozen=[Path(__file__).resolve(),root/'tools/verify_four_line_browser.py',root/'tools/verify_forest_browser.py',root/'tools/studio_gui_pointer.py',root/'tools/verify_ci_artifact_browser.py',root/'tools/check_web_bundle.py',root/'tools/install_mapgen_candidate.py',root/'tools/verify_mapgen_reference.py',root/'experiments/platform/cloud_preview.gd',root/'experiments/generation/runtime_map_slice.gd',root/SCENE.removeprefix('res://'),root/'experiments/generation/runtime_map_generated_slice.gd',root/'experiments/generation/runtime_map_generation_job.gd',root/'experiments/generation/runtime_map_generation_request.gd',root/'game/world/levels/providers/runtime_map_v2_provider.gd',pack_path]
        frozen += [root/name for name in [contract['config'],*contract['data'],*contract['addons']]]
        frozen += [bundle/name for name in ['index.html','build-info.json','index.cache-sw.js','build_report.json','preview.json'] if (bundle/name).is_file()]
        frozen += [path.resolve() for path in a.producer_file]
        report['producer_helpers_source_before']={str(path):sha(path) for path in dict.fromkeys(frozen)}
        opener=urllib.request.build_opener() if a.proxy_from_environment else urllib.request.build_opener(urllib.request.ProxyHandler({}))
        base=urljoin(a.url,'./')
        def served_identity():
            nonce=str(time.time_ns())
            def read(name):
                return opener.open(urllib.request.Request(base+name+'?gui='+nonce,headers={'Cache-Control':'no-cache'}),timeout=remaining(30000)/1000).read()
            metadata=json.loads(read('build-info.json'));worker=read('index.cache-sw.js').decode();html=read('index.html').decode()
            identity=validate_identity(metadata,worker,{'sha256':a.pack_sha256,'bytes':a.pack_bytes},a.source,a.pack_sha256[:12])
            match=re.search(r'/\* cloud-preview-entry \*/ args: (\[[^\n]*\]),',html)
            assert match,'Expected original root-produced preview; no driver argument injection fallback'
            flags=json.loads(match.group(1))
            assert '--cloud-preview' in flags and '--entry=scene' in flags and '--scene='+SCENE in flags
            return dict(identity=identity,html_sha256=hashlib.sha256(html.encode()).hexdigest(),launch_flags=flags)
        report['served_before']=served_identity();save()
        sequence=0
        async def checkpoint(label,pic,row,action):
            nonlocal sequence
            sequence+=1;report['waiting']=dict(seq=sequence,label=label,screenshot=pic.name,session=row['label'],expected_action=action)
            save();print('WAIT',sequence,label,pic.name,flush=True)
            while True:
                remaining(300000);command=a.commands/'command.json'
                if command.exists():
                    value=json.loads(command.read_text())
                    if value.get('seq')==sequence:
                        assert value['action']==action and value.get('passed') is True
                        row.setdefault('operator_visual_review',[]).append(value);return
                await asyncio.sleep(.1)
        async with async_playwright() as p:
            browser=await p.chromium.launch(executable_path='/usr/bin/chromium',proxy=environment_proxy()[0] if a.proxy_from_environment else None,headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'],timeout=remaining(30000))
            report['browser_version']=browser.version
            try:
                for label in ['generated-escape','cancel-generate']:
                    row=dict(label=label,console=[],page_errors=[],request_failures=[],http_errors=[],runtime_observations=[],host_observations=[],parse_errors=[],screenshots=[],inputs=[])
                    report['sessions'].append(row);save()
                    context=await browser.new_context(viewport={'width':1280,'height':720},device_scale_factor=1,has_touch=True)
                    page=await context.new_page()
                    def console(message,row=row):
                        message_text=message.text;stamp=time.time()*1000
                        row['console'].append(dict(type=message.type,text=message_text,location=message.location,epoch_ms=stamp))
                        for prefix,key in [(HOST_PREFIX,'host_observations'),(RUNTIME_PREFIX,'runtime_observations')]:
                            if message_text.startswith(prefix):
                                try: row[key].append(dict(epoch_ms=stamp,value=json.loads(message_text[len(prefix):])))
                                except Exception as error: row['parse_errors'].append(repr(error))
                        save()
                    page.on('console',console)
                    page.on('pageerror',lambda error,row=row:(row['page_errors'].append(str(error)),save()))
                    page.on('requestfailed',lambda request,row=row:(row['request_failures'].append(dict(url=request.url,failure=request.failure)),save()))
                    page.on('response',lambda response,row=row:(row['http_errors'].append(dict(url=response.url,status=response.status)),save()) if response.status>=400 else None)
                    def events(key,event): return [item for item in row[key] if item['value'].get('event')==event]
                    def physics(): return [item['value'] for item in events('host_observations','physics')]
                    async def wait_for(predicate):
                        while not predicate():
                            failures=events('runtime_observations','failed')
                            if failures: raise RuntimeError('Actual source reported failure: '+json.dumps(failures[-1]))
                            if row['parse_errors']: raise RuntimeError('Source console JSON parse failed')
                            remaining(300000);await asyncio.sleep(.05)
                    async def screen(name):
                        path=out/(label+'-'+name+'.png');await page.screenshot(path=str(path),timeout=remaining(15000))
                        row['screenshots'].append(dict(file=path.name,sha256=sha(path),epoch_ms=time.time()*1000));save();return path
                    async def real_key(key,duration):
                        begin=time.time()*1000
                        await page.keyboard.down(key)
                        try: await asyncio.sleep(duration/1000)
                        finally: await page.keyboard.up(key)
                        row['inputs'].append(dict(action=key+str(duration),begin_epoch_ms=begin,end_epoch_ms=time.time()*1000));save()
                    try:
                        await page.goto(a.url,wait_until='domcontentloaded',timeout=remaining(60000))
                        if label=='generated-escape':
                            await wait_for(lambda:bool(events('runtime_observations','committed')))
                            trace=row['runtime_observations'];phases=[item['value'].get('phase') for item in trace]
                            required=['preload','generate','validate','ready','committed'];position=-1
                            for phase in required:
                                position=phases.index(phase,position+1)
                            assert events('runtime_observations','started') and len(events('runtime_observations','committed'))==1
                            committed=events('runtime_observations','committed')[0]['value'];row['generation_receipt']=committed
                            assert committed['source_kind']=='generated_memory' and committed['profile']=='conformance930001' and committed['ready'] is True
                            assert committed['actual_hook_enabled'] is False
                            output=committed['output'];row['actual_generated_output']=output
                            assert output['status']=='PASS' and output['seed']==930001
                            assert output['instances']==46 and output['connections']==55 and output['content_entries']==46
                            identity=committed['identity'];assert identity['source_kind']=='generated_memory'
                            for key in ['generation_input_fingerprint','map_content_identity','host_load_identity','result_receipt_digest']:
                                assert re.fullmatch('[0-9a-f]{64}',identity[key])
                            assert output['request_fingerprint']==identity['generation_input_fingerprint']
                            source_receipt=identity['source_receipt'];assert source_receipt['kind']=='generated_memory' and 'files' not in source_receipt
                            assert source_receipt['request']['seed']==930001
                            assert source_receipt['module_archive']['sha256']==config['module_package']['sha256']
                            assert source_receipt['algorithm_package']['zip_sha256']==config['archive']['sha256']
                            if a.expected_host_load_identity: assert identity['host_load_identity']==a.expected_host_load_identity
                            row['host_load_identity']=identity['host_load_identity']
                            await wait_for(lambda:len(physics())>=2)
                            loaded=events('host_observations','loaded');assert len(loaded)==1
                            row['first_loaded_observation']=loaded[0]
                            assert loaded[0]['value']['player']==[-448,846], 'First loaded body must equal actual Plan.spawn before Motor steps'
                            assert identity['host_load']['spawn']==[-448,846]
                            assert set(identity['host_load']['selected_instances'])=={'M16','M18','M21'}
                            assert {module['instance_id'] for module in loaded[0]['value']['mechanisms']}=={'M16','M18','M21'}
                            for item in [loaded[0]['value'],*physics()]:
                                assert item['host_load_identity']==identity['host_load_identity'] and isinstance(item['grounded'],bool)
                                assert all(isinstance(item[field],list) and len(item[field])==2 and all(isinstance(x,(int,float)) and math.isfinite(x) for x in item[field]) for field in ['player','carrier'])
                            pic=await screen('01-committed');await checkpoint('view-real-generated-slice',pic,row,'move-d')
                            for key,number,next_action in [('d','02','move-a'),('a','03','escape')]:
                                baseline=physics()[-1];await real_key(key,180);count=len(physics())
                                await wait_for(lambda:len(physics())>=count+2)
                                after=physics()[-1];delta=after['player'][0]-baseline['player'][0]
                                row.setdefault('movement',[]).append(dict(key=key,baseline=baseline,after=after,directional_x_delta=delta))
                                assert delta*(1 if key=='d' else -1)>1.0
                                pic=await screen(number+'-after-'+key);await checkpoint('view-after-real-'+key,pic,row,next_action)
                            points=[value['carrier'] for value in physics()]
                            row['carrier_max_displacement']=max(math.dist(points[0],point) for point in points)
                            assert row['carrier_max_displacement']>.01 and any(value['grounded'] for value in physics())
                            begin=time.time()*1000;await page.keyboard.press('Escape')
                            row['inputs'].append(dict(action='actual-Escape-after-committed',begin_epoch_ms=begin,end_epoch_ms=time.time()*1000))
                        else:
                            # No screenshot/visual checkpoint delays cancellation. This is
                            # a real key delivered immediately after the passive generate log.
                            await wait_for(lambda:bool(events('runtime_observations','generate')))
                            row['committed_before_cancel_input']=bool(events('runtime_observations','committed'))
                            begin=time.time()*1000;await page.keyboard.press('Escape')
                            row['inputs'].append(dict(action='actual-Escape-during-observed-generate',begin_epoch_ms=begin,end_epoch_ms=time.time()*1000));save()
                            await screen('01-after-cancel-key')
                        await wait_for(lambda:bool(events('host_observations','closed')))
                        closed=events('host_observations','closed');assert len(closed)==1
                        row['closed_observation']=closed[0];value=closed[0]['value']
                        assert value['audio_released'] is True and value['lifetime_active'] is False and value['stage_detached'] is True
                        source_closed=events('runtime_observations','source_closed');assert source_closed
                        assert source_closed[0]['value']['closed'] is True
                        if label=='cancel-generate':
                            assert row['committed_before_cancel_input'] is False
                            assert not events('runtime_observations','committed') and not events('host_observations','loaded') and not physics()
                            assert source_closed[0]['value']['phase']=='cancelled'
                            assert row['inputs'][-1]['begin_epoch_ms']<=source_closed[0]['epoch_ms']
                        await wait_for(lambda:any('CLOUD PREVIEW: returned to full game menu; persistence=false' in item['text'] for item in row['console']))
                        returned=next(item for item in row['console'] if 'CLOUD PREVIEW: returned to full game menu; persistence=false' in item['text'])
                        row['cleanup_precedes_return_log']=closed[0]['epoch_ms']<=returned['epoch_ms'];assert row['cleanup_precedes_return_log']
                        await asyncio.sleep(.3);pic=await screen('returned-title')
                        row['actual_title_start_pixel_point']=locate_any(pic,'开始游戏')
                        await checkpoint('view-real-returned-title',pic,row,'confirm-title')
                        row['script_errors']=[item for item in row['console'] if any(token in item['text'] for token in ['SCRIPT ERROR','Parse Error','Shader compilation','ERROR:'])]
                        assert not row['page_errors'] and not row['parse_errors'] and not row['script_errors']
                        row['console_errors_retained']=[item for item in row['console'] if item['type']=='error']
                        row['status']='PASSED_ACTUAL_GENERATED_ESCAPE' if label=='generated-escape' else 'PASSED_ACTUAL_GENERATE_CANCELLATION'
                    except BaseException as error:
                        row['exception']=repr(error);row['status']='FAILED';save()
                        try: await screen('failure-preserved')
                        except BaseException as image_error: row['failure_screenshot_error']=repr(image_error)
                        raise
                    finally:
                        await context.close();row['context_closed']=True;save()
            finally:
                await browser.close();report['browser_closed']=True;save()
        report['served_after']=served_identity();assert report['served_after']==report['served_before']
        report['status']='PASSED_GENERATED_INPUT_ESCAPE_AND_GENERATE_CANCELLATION';report.pop('waiting',None)
    finally:
        # Preserve the actual partial observations even when an engine long frame,
        # screenshot, navigation or the single total budget prevents completion.
        if guard is not None and before is not None:
            try:
                remaining(300000);after=guard.snapshot()
                report['source_after_raw_sha256']=compressed('source-after.json.gz',after)
                report['source_stable']=after==before
                if not report['source_stable']: report['status']='FAILED_SOURCE_CHANGED'
            except BaseException as error: report['source_after_guard_error']=repr(error)
        if frozen is not None and 'producer_helpers_source_before' in report:
            try:
                remaining(300000)
                report['producer_helpers_source_after']={name:sha(Path(name)) for name in report['producer_helpers_source_before']}
                report['producer_helpers_stable']=report['producer_helpers_source_after']==report['producer_helpers_source_before']
                if not report['producer_helpers_stable']: report['status']='FAILED_PRODUCER_CHANGED'
            except BaseException as error: report['producer_after_guard_error']=repr(error)
        report['elapsed_seconds']=time.monotonic()-started
        if report['status'].startswith('PASSED'):
            assert report.get('source_stable') is True and report.get('producer_helpers_stable') is True and report['elapsed_seconds']<=BUDGET
        save()

if __name__=='__main__':
    args=arguments();result={}
    try: asyncio.run(asyncio.wait_for(run(args,result),BUDGET))
    except BaseException as error:
        result['status']='FAILED';result['exception']=repr(error)
        if args.output.is_dir(): (args.output/'report.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
        raise
