"""Rendered D078 practice entries with ordinary input; no game-state injection.
Does not claim full Boss victory or real-device balance validation.
"""
import asyncio, json, os, shutil, subprocess, sys
from pathlib import Path
from playwright.async_api import async_playwright
from PIL import ImageChops
import numpy as np
import verify_random_stage_browser as h

FOLDER = Path('build/verification/plains-pressure-boss-browser')
h.FOLDER = FOLDER

async def main(url):
    FOLDER.mkdir(parents=True, exist_ok=True)
    report = {'url': url, 'failed': 1, 'checks': [], 'scope': 'Actual practice-entry clicks, rendered attacks and ordinary movement/jump/fire; no full victory claim'}
    logs = []
    async with async_playwright() as p:
        browser = await p.chromium.launch(executable_path=shutil.which('chromium') or shutil.which('chromium-browser'), headless=True, args=['--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'])
        try:
            video = {'record_video_dir': str(FOLDER / 'video'), 'record_video_size': {'width': 1280, 'height': 720}} if os.environ.get('GUNMAN_RECORD_GUI') == '1' else {}
            context = await browser.new_context(viewport={'width':1280,'height':720}, has_touch=True, is_mobile=True, **video)
            page = await context.new_page()
            page.on('console', lambda m: logs.append(m.text))
            page.on('pageerror', lambda e: logs.append('PAGE ERROR: ' + str(e)))
            async def capture(name):
                await page.screenshot(path=str(FOLDER / (name + '.png')))
            async def visible(name, phrase, budget=15, region=None):
                async def poll():
                    while True:
                        await capture(name)
                        text = (await asyncio.to_thread(h.ocr, name, region)).upper()
                        if phrase in text: return text
                        await page.wait_for_timeout(200)
                return await asyncio.wait_for(poll(), timeout=budget)
            await page.goto(url, wait_until='networkidle', timeout=45000)
            report['build_id'] = await page.locator('#playtest-version').get_attribute('data-build-id')
            await visible('title', 'DEVELOPMENT DEMOS', 45)
            await page.touchscreen.tap(*h.text_center('title','DEVELOPMENT DEMOS'))
            await visible('development', 'MODULE LAB')
            await page.touchscreen.tap(*h.text_center('development','MODULE LAB'))
            await visible('lab', 'BELLSTRIDER')
            for label, prefix, hp in [('BELLSTRIDER','mini',16), ('STORM WINDKEEPER','storm',36)]:
                await capture(prefix+'-entry-menu')
                await page.touchscreen.tap(*h.text_center('lab',label))
                text = await visible(prefix+'-dormant','HP '+str(hp),region=(130,225,1000,285))
                report[prefix+'_initial_ocr'] = text
                await page.keyboard.down('d')
                await page.wait_for_timeout(700)
                await page.keyboard.up('d')
                await page.wait_for_timeout(3500)
                await capture(prefix+'-warning')
                await page.keyboard.down('Space')
                await page.wait_for_timeout(500)
                await page.keyboard.up('Space')
                await capture(prefix+'-jump')
                if prefix=='mini':
                    await visible('mini-core-open','NECK',budget=15,region=(130,225,1000,285))
                    # Locate the drawn 18px ring in the real canvas capture.
                    # Read-only pixels, no engine introspection/teleport/HP injection.
                    pixels=np.asarray(h.picture('mini-core-open').convert('RGB'))
                    strip=pixels[480:524,170:820].astype(np.int16)
                    mask=(np.abs(strip[:,:,0]-255)<10)&(np.abs(strip[:,:,1]-229)<12)&(np.abs(strip[:,:,2]-155)<12)
                    ys,xs=np.where(mask);xs=xs+170;ys=ys+480
                    centers=np.arange(175,800)
                    scores=(np.abs(np.hypot(xs[None,:]-centers[:,None],ys[None,:]-501)-18)<2).sum(axis=1)
                    best=int(np.argmax(scores));score=int(scores[best]);cx=int(centers[best])
                    if score<12: raise RuntimeError('actual exposed ring could not be located from pixels')
                    report['mini_core_target_from_pixels']={'x':cx,'y':501,'ring_pixels':score}
                    await page.mouse.move(cx,501)
                    await page.mouse.down()
                    await page.wait_for_timeout(30)
                    await page.mouse.up()
                    await capture('mini-player-shot')
                    await visible('mini-actual-hit','HP 15',budget=5,region=(130,225,1000,285))
                    report['checks'].append('Actual pointer aimed at rendered open bell; ordinary mouse release changes mini HP 16 to 15')
                    await page.wait_for_timeout(350)
                    await capture('mini-flight-before')
                    await page.mouse.move(1040,560)
                    await page.mouse.down()
                    await page.wait_for_timeout(30)
                    await page.mouse.up()
                    flight_visible=False
                    previous_flight=None
                    moving_flight=False
                    for shot_frame in range(3):
                        await page.wait_for_timeout(60)
                        await capture('mini-flight-'+str(shot_frame))
                        before=h.picture('mini-flight-before').crop((345,530,950,590))
                        flying=h.picture('mini-flight-'+str(shot_frame)).crop((345,530,950,590))
                        flight_visible=flight_visible or bool(ImageChops.difference(before,flying).getbbox())
                        if previous_flight is not None:
                            motion_box=ImageChops.difference(previous_flight,flying).getbbox()
                            moving_flight=moving_flight or bool(motion_box and motion_box[2]-motion_box[0]>80)
                        previous_flight=flying
                    if not flight_visible or not moving_flight: raise RuntimeError('ordinary long shot left no rendered flight in clear world strip')
                    report['checks'].append('Ordinary second mouse release produces visible flying shot/trail in clear world strip; flight captures retained')

                else:
                    await page.mouse.move(560,490)
                    await page.mouse.down()
                    await page.wait_for_timeout(120)
                    await page.mouse.up()
                for frame in range(5):
                    await page.wait_for_timeout(700)
                    await capture(prefix+'-action-'+str(frame))
                if not ImageChops.difference(h.picture(prefix+'-warning').crop((50,300,1050,630)), h.picture(prefix+'-action-4').crop((50,300,1050,630))).getbbox():
                    raise RuntimeError(label+' world did not animate')
                report['checks'].append(label+' actual entry shows '+str(hp)+' HP; ordinary movement, held jump and mouse release; changing action captures retained')
            if any('SCRIPT ERROR' in x or 'PAGE ERROR' in x or 'Shader compilation failed' in x for x in logs):
                raise RuntimeError('Runtime errors: '+str(logs))
            report['failed'] = 0
            await context.close()
        finally:
            await browser.close()
            (FOLDER/'console.log').write_text('\n'.join(logs))
            (FOLDER/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(report,ensure_ascii=False))

if __name__ == '__main__':
    server = None
    url = sys.argv[1] if len(sys.argv)>1 else 'http://127.0.0.1:8799/'
    if len(sys.argv)==1:
        server = subprocess.Popen([sys.executable,'-m','http.server','8799','--bind','127.0.0.1','--directory','build/web'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    try:
        asyncio.run(asyncio.wait_for(main(url),timeout=240))
    finally:
        if server:
            server.terminate()
            server.wait(timeout=5)
