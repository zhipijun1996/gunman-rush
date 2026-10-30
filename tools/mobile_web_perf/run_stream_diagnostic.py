"""Observe real Home/menu Stream underruns with identical pack and two buffers."""
import argparse, asyncio, json, sys
from pathlib import Path
from playwright.async_api import async_playwright
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from verify_mobile_ui_clarity_browser import surfaces, fitted_rect
from verify_forest_browser import locate_original, environment_proxy

async def run(args):
    args.output.mkdir(parents=True,exist_ok=False)
    async with async_playwright() as p:
        for latency in args.latencies:
            folder=args.output/str(latency);folder.mkdir();logs=[];rows=[]
            options = {'proxy': environment_proxy()[0]} if args.proxy_from_environment else {}
            browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'],**options)
            context=await browser.new_context(viewport={'width':853,'height':290},device_scale_factor=2.5,is_mobile=True,has_touch=True)
            page=await context.new_page()
            def log(value):
                logs.append(value)
                (folder/'browser.log').write_text('\n'.join(logs))
            page.on('console',lambda m:log(m.type+':'+m.text))
            page.on('pageerror',lambda e:log('PAGE ERROR:'+str(e)))
            def save():
                (folder/'report.json').write_text(json.dumps({'latency_ms':latency,'threaded':args.threaded,'url':args.url,'rows':rows,'logs':logs,'scope':'Cloud SwiftShader only; real Home/menu and optional natural Plains, same pack and diagnostic engine/worklet; no physical phone claim'},indent=2))
                (folder/'browser.log').write_text('\n'.join(logs))
            try:
                entry='audio-threaded/' if args.threaded else 'audio-stream-test.html'
                await page.goto(args.url+entry+'?latency='+str(latency)+'&audio_probe=1',wait_until='domcontentloaded')
                ready='window.THREADED_DIAGNOSTIC_READY===true' if args.threaded else 'window.PLAYTEST_LOADING_DONE===true'
                await page.wait_for_function(ready,timeout=180000)
                await page.wait_for_timeout(1500);await page.screenshot(path=str(folder/'title.png'))
                b=surfaces(folder/'title.png',[(195,163,102)])[0]
                await page.touchscreen.tap((b[0]+b[2]/2)/2.5,(b[1]+b[3]/2)/2.5)
                await page.wait_for_timeout(6000)
                phases=('game','menu','plains','plains_menu') if args.plains else ('game','menu')
                for phase in phases:
                    if phase=='plains':
                        if args.seed:
                            # Use the real Home navigation's existing RUN SEED
                            # field, never replace the scene or game RNG.
                            await page.mouse.move(540,180)
                            await page.mouse.wheel(0,1200)
                            await page.wait_for_timeout(2000)
                            seed_shot=folder/'seed-field.png'
                            await page.screenshot(path=str(seed_shot))
                            field=locate_original(seed_shot,'Optional')
                            await page.mouse.click(field[0]/2.5,field[1]/2.5)
                            await page.keyboard.type(args.seed,delay=40)
                            await page.keyboard.press('Tab')
                            await page.wait_for_timeout(1000)
                            await page.screenshot(path=str(folder/'seed-entered.png'))
                            await page.mouse.wheel(0,-1600)
                            await page.wait_for_timeout(2000)
                            await page.screenshot(path=str(folder/'menu.png'))
                        explore=locate_original(folder/'menu.png','Explore')
                        await page.touchscreen.tap(explore[0]/2.5,explore[1]/2.5)
                        await page.wait_for_timeout(8000)
                        if args.seed:
                            region=[json.loads(line.split('FOREST_UI_EVENT ',1)[1]) for line in logs if 'FOREST_UI_EVENT ' in line and 'region_assembled' in line]
                            assert region and region[-1]['seed']==args.seed,region
                    if phase in ('menu','plains_menu'):
                        await page.touchscreen.tap((422.0555555556+1288.888888889*1202/1280)/2.5,725*42/720/2.5)
                        await page.wait_for_timeout(2000)
                    if args.threaded:
                        before=await page.evaluate('window.MOBILE_THREADED_DIAGNOSTIC.snapshot()')
                        await page.wait_for_timeout(10000)
                        after=await page.evaluate('window.MOBILE_THREADED_DIAGNOSTIC.snapshot()')
                        def normalize(x):
                            return {'audio':x['audio'],'sfx':x['selected_sfx'],'ambience':x['selected_ambience'],'timing':x['timing']}
                        row={'phase':phase,'before':normalize(before),'after':normalize(after)}
                    else:
                        await page.evaluate('(phase)=>audioRecord(phase)',phase)
                        row=await page.evaluate('window.AUDIO_STREAM_DIAGNOSTIC.observations.at(-1)')
                    await page.screenshot(path=str(folder/(phase+'.png')))
                    row['canvas']=await page.evaluate('(()=>{const c=document.querySelector("canvas"),r=c.getBoundingClientRect();return {width:c.width,height:c.height,css:{x:r.x,y:r.y,width:r.width,height:r.height},dpr:devicePixelRatio}})()')
                    if args.threaded:
                        actual=await page.evaluate('window.MOBILE_THREADED_DIAGNOSTIC.snapshot()')
                        row['threaded_runtime']=actual
                        assert actual['cross_origin_isolated'] and actual['threads'] and actual['shared_ring_observed'],actual
                    assert row['after']['sfx']['validation_ok'] and row['after']['sfx']['audio_profile']=='selected',row['after']['sfx']
                    # Home's ordinary menu blocks Home input but does not pause
                    # SceneTree. Only the in-run pause menu freezes the tree.
                    assert row['after']['ambience']['tree_paused']==(phase=='plains_menu'),row['after']['ambience']
                    rows.append(row);save()
                    stats=[]
                    for before,after in zip(row['before']['audio']['streams'],row['after']['audio']['streams']):
                        a,b=before.get('underrun_stats'),after.get('underrun_stats')
                        if a and b:
                            requested=b['total_requested_frames']-a['total_requested_frames'];missing=b['underrun_frames']-a['underrun_frames']
                            stats.append({'requested_frames':requested,'underrun_frames':missing,'underrun_fraction':missing/requested if requested else None})
                    print(json.dumps({'latency_ms':latency,'phase':phase,'stats':stats}),flush=True)
                    assert stats, 'No actual render-thread underrun counter'
                assert not any(any(s in line for s in ('SCRIPT ERROR:','SHADER ERROR:','PAGE ERROR:'))for line in logs),logs
            except Exception:
                try:
                    state=await page.evaluate('''async()=>({url:location.href,isolated:crossOriginIsolated,controller:navigator.serviceWorker.controller?.scriptURL,missing:typeof Engine==='undefined'?null:Engine.getMissingFeatures({threads:true}),registrations:await navigator.serviceWorker.getRegistrations().then(rs=>rs.map(r=>({scope:r.scope,active:r.active?.state,waiting:r.waiting?.state,installing:r.installing?.state}))),notice:document.getElementById('status-notice')?.textContent})''')
                    (folder/'failure-state.json').write_text(json.dumps(state,indent=2))
                    await page.screenshot(path=str(folder/'failure.png'))
                except Exception as error:
                    log('Failure artifact unavailable: '+str(error))
                raise
            finally:
                save();await browser.close()

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--url',required=True);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--threaded',action='store_true');p.add_argument('--plains',action='store_true')
    p.add_argument('--latencies',type=int,nargs='+',choices=(50,200),default=[50,200]);p.add_argument('--proxy-from-environment',action='store_true')
    p.add_argument('--seed',help='Fill the real Home menu RUN SEED before Explore')
    asyncio.run(run(p.parse_args()))
