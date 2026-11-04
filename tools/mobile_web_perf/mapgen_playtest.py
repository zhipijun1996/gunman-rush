"""Desktop real-GUI mapgen wait and runtime capture using the shared RAF observer.

No engine memory/state writes. --prepare waits for the real Home solve event;
this Home dwell and click-to-world wait are separate observations.
"""
import argparse
import asyncio
import json
import os
from pathlib import Path
import time
from playwright.async_api import async_playwright
from run_frame_profile import FRAME_OBSERVER, browser_summary

async def run(args):
    args.output.mkdir(parents=True, exist_ok=False)
    logs, errors, events = [], [], []
    async with async_playwright() as p:
        browser = await p.chromium.launch(executable_path='/usr/bin/chromium', headless=True,
            args=['--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'])
        options = dict(viewport={'width':1280,'height':720}, device_scale_factor=1)
        if args.url.startswith('https:'):
            options['proxy']={'server':os.environ.get('HTTPS_PROXY','http://proxy:8080'),'bypass':'localhost,127.0.0.1'}
        context = await browser.new_context(**options)
        await context.add_init_script(FRAME_OBSERVER)
        page = await context.new_page()
        def console(msg):
            line=msg.text;logs.append(line)
            (args.output/'console.log').write_text('\n'.join(logs)+'\n')
            for prefix in ['MAPGEN_HOME ','FOREST_UI_EVENT ','MAPGEN_TIMING ']:
                if line.startswith(prefix):events.append((prefix,json.loads(line[len(prefix):])))
        page.on('console',console)
        page.on('pageerror',lambda e:errors.append(str(e)))
        await page.goto(args.url,wait_until='domcontentloaded',timeout=90000)
        await page.wait_for_function('window.PLAYTEST_LOADING_DONE===true',timeout=180000)
        await page.wait_for_timeout(1400)
        metadata=await page.evaluate("fetch('build-info.json',{cache:'no-store'}).then(r=>r.json())")
        await page.mouse.click(220,190);await page.wait_for_timeout(1600)
        await page.keyboard.press('Escape');await page.wait_for_timeout(600)
        await page.mouse.move(850,550);await page.mouse.wheel(0,1200);await page.wait_for_timeout(600)
        await page.mouse.click(750,265);await page.keyboard.press('Control+A');await page.keyboard.type(args.seed)
        await page.mouse.move(850,450);await page.mouse.wheel(0,-1500);await page.wait_for_timeout(600)
        home_start=time.monotonic()
        if args.prepare:
            while not any(prefix=='MAPGEN_HOME ' and e.get('event')=='prepared' and e.get('seed')==args.seed for prefix,e in events):
                if time.monotonic()-home_start>180:raise RuntimeError('Home did not finish the requested real solve')
                await page.wait_for_timeout(100)
        home_dwell=time.monotonic()-home_start
        await page.screenshot(path=str(args.output/'departure.png'))
        before=time.monotonic();await page.mouse.click(750,300)
        while not any(prefix=='FOREST_UI_EVENT ' and e.get('event')=='region_assembled' for prefix,e in events):
            if time.monotonic()-before>240:raise RuntimeError('No actual formal region entry')
            await page.wait_for_timeout(100)
        wait=time.monotonic()-before
        await page.wait_for_timeout(1500)
        samples=[]
        for index in range(args.repeats):
            await page.evaluate('window.FPS04_BROWSER.begin()')
            await page.wait_for_timeout(10000)
            capture=await page.evaluate('window.FPS04_BROWSER.end()')
            samples.append({'browser':capture,'summary':browser_summary(capture)})
        await page.screenshot(path=str(args.output/'plains.png'))
        await page.mouse.move(528,348);await page.mouse.down();await page.wait_for_timeout(100);await page.mouse.up();await page.wait_for_timeout(300)
        await page.keyboard.down('d');await page.wait_for_timeout(900);await page.keyboard.up('d')
        await page.screenshot(path=str(args.output/'start_crossed.png'))
        await page.keyboard.press('m');await page.wait_for_timeout(500);await page.screenshot(path=str(args.output/'map.png'))
        assert not errors and not any('SCRIPT ERROR:' in line for line in logs),errors
        report={'url':args.url,'metadata':metadata,'seed':args.seed,'prepare':args.prepare,'home_dwell_seconds':home_dwell,'click_to_world_seconds':wait,'events':events,'samples':samples,'page_errors':errors,'scope':'Desktop Chromium SwiftShader, 1280x720 DPR1, real title/Home/seed/Explore UI; idle at actual formal spawn. No phone FPS or whole-route proof. Observation-only shared RAF/LongTask collector.'}
        (args.output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps({k:report[k] for k in ['home_dwell_seconds','click_to_world_seconds','seed','prepare']}),flush=True)
        for sample in samples:print(json.dumps(sample['summary']),flush=True)
        await browser.close()

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url',required=True)
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--seed',default='ci-smoke')
    parser.add_argument('--prepare',action='store_true')
    parser.add_argument('--repeats',type=int,choices=range(1,4),default=2)
    asyncio.run(run(parser.parse_args()))
