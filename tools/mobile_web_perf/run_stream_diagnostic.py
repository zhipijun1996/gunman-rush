"""Observe real Home/menu Stream underruns with identical pack and two buffers."""
import argparse, asyncio, json, sys
from pathlib import Path
from playwright.async_api import async_playwright
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from verify_mobile_ui_clarity_browser import surfaces

async def run(args):
    args.output.mkdir(parents=True,exist_ok=False)
    async with async_playwright() as p:
        for latency in (50,200):
            folder=args.output/str(latency);folder.mkdir();logs=[];rows=[]
            browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
            context=await browser.new_context(viewport={'width':853,'height':290},device_scale_factor=2.5,is_mobile=True,has_touch=True)
            page=await context.new_page()
            page.on('console',lambda m:logs.append(m.type+':'+m.text))
            page.on('pageerror',lambda e:logs.append('PAGE ERROR:'+str(e)))
            def save():
                (folder/'report.json').write_text(json.dumps({'latency_ms':latency,'rows':rows,'logs':logs,'scope':'Cloud SwiftShader only; real Home/menu, same pack and counter worklet; no physical phone claim'},indent=2))
                (folder/'browser.log').write_text('\n'.join(logs))
            try:
                await page.goto(args.url+'audio-stream-test.html?latency='+str(latency)+'&audio_probe=1',wait_until='domcontentloaded')
                await page.wait_for_function('window.PLAYTEST_LOADING_DONE===true',timeout=180000)
                await page.wait_for_timeout(1500);await page.screenshot(path=str(folder/'title.png'))
                b=surfaces(folder/'title.png',[(195,163,102)])[0]
                await page.touchscreen.tap((b[0]+b[2]/2)/2.5,(b[1]+b[3]/2)/2.5)
                await page.wait_for_timeout(6000)
                for phase in ('game','menu'):
                    if phase=='menu':
                        await page.touchscreen.tap((422.0555555556+1288.888888889*1202/1280)/2.5,725*42/720/2.5)
                        await page.wait_for_timeout(2000)
                    await page.evaluate('(phase)=>audioRecord(phase)',phase)
                    row=await page.evaluate('window.AUDIO_STREAM_DIAGNOSTIC.observations.at(-1)')
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
            finally:
                save();await browser.close()

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--url',required=True);p.add_argument('--output',type=Path,required=True);asyncio.run(run(p.parse_args()))
