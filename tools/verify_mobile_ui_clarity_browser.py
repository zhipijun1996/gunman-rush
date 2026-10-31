"""Actual exported canvas GUI checks; browser simulation cannot certify a phone.

Uses rendered native button surfaces and ordinary mouse/touch input. No engine
state changes, fixture hooks, FPS claims or replacement gameplay are involved.
"""
import argparse, asyncio, json, urllib.request
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from playwright.async_api import async_playwright
from verify_forest_browser import environment_proxy, locate_original


def surfaces(path, colors):
    pixels = np.array(Image.open(path).convert('RGB')).astype(int)
    result = []
    for color in colors:
        labels, _ = ndi.label(np.max(np.abs(pixels - color), axis=2) < 3)
        for bounds in ndi.find_objects(labels):
            if bounds is None:
                continue
            yy, xx = bounds
            if xx.stop - xx.start > 60 and yy.stop - yy.start > 15:
                result.append([xx.start, yy.start, xx.stop - xx.start, yy.stop - yy.start])
    return sorted(result, key=lambda box: box[2] * box[3], reverse=True)


def fitted_rect(path):
    width, height = Image.open(path).size
    scale = min(width / 1280, height / 720)
    return [(width - 1280 * scale) / 2, (height - 720 * scale) / 2, 1280 * scale, 720 * scale]


async def run(args):
    args.output.mkdir(parents=True, exist_ok=False)
    url = args.root_url.rstrip('/') + '/'
    with urllib.request.urlopen(url + 'build-info.json?verify=' + args.expected_build, timeout=90) as response:
        info = json.load(response)
    assert info['build_id'] == args.expected_build and info['source_commit'] == args.expected_source, info
    report = {'scope': 'Actual exported Web GUI; Chromium SwiftShader screen/DPR simulation. Physical device, audio and performance acceptance unverified.', 'url': url, 'build_info': info, 'devices': []}
    async with async_playwright() as playwright:
        options = {'proxy': environment_proxy()[0]} if args.proxy_from_environment else {}
        browser = await playwright.chromium.launch(executable_path='/usr/bin/chromium', headless=True, args=['--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'], **options)
        try:
            devices = [('desktop',1280,720,1,False), ('mobile',853,290,2.5,True)]
            for name, width, height, dpr, touch in devices:
                if args.device != 'both' and name != args.device:
                    continue
                context = await browser.new_context(viewport={'width':width,'height':height}, device_scale_factor=dpr, is_mobile=touch, has_touch=touch)
                page = await context.new_page()
                logs, errors = [], []
                page.on('console', lambda message: logs.append(message.type + ': ' + message.text))
                page.on('pageerror', lambda error: errors.append(str(error)))
                try:
                    await page.goto(url, wait_until='domcontentloaded')
                    await page.wait_for_function('window.PLAYTEST_LOADING_DONE===true', timeout=180000)
                    await page.wait_for_timeout(2000)
                    async def shot(phase):
                        path = args.output / (name + '-' + phase + '.png')
                        await page.screenshot(path=str(path))
                        return path
                    async def tap(point):
                        if touch:
                            await page.touchscreen.tap(point[0]/dpr, point[1]/dpr)
                        else:
                            await page.mouse.click(point[0]/dpr, point[1]/dpr)
                        await page.wait_for_timeout(1500)
                    def center(box):
                        return box[0]+box[2]/2, box[1]+box[3]/2
                    title = await shot('title')
                    rect = fitted_rect(title)
                    primary = surfaces(title, [(195,163,102)])[0]
                    scale = rect[2]/1280
                    normalized = [(primary[0]-rect[0])/scale, (primary[1]-rect[1])/scale, primary[2]/scale, primary[3]/scale]
                    row = {'device':name,'viewport':[width,height],'dpr':dpr,'game_rect_device_px':rect,'primary_device_px':primary,'primary_logical':normalized,'canvas':await page.locator('canvas').evaluate('(c)=>({width:c.width,height:c.height,css:[c.getBoundingClientRect().width,c.getBoundingClientRect().height]})'),'checks':[]}
                    assert row['canvas']['width'] >= (width-1)*dpr - 1, row
                    # Locate the third real title row in the same measured column.
                    buttons = [box for box in surfaces(title, [(195,163,102),(41,58,59),(59,78,76)]) if abs(box[0]-primary[0])<3 and abs(box[2]-primary[2])<4]
                    buttons.sort(key=lambda box:box[1])
                    assert len(buttons)>=4, buttons
                    await tap(center(buttons[2]));await shot('settings')
                    await page.keyboard.press('Escape');await page.wait_for_timeout(1000)
                    returned = await shot('title-returned')
                    assert surfaces(returned,[(195,163,102)]), 'Settings did not return to title'
                    row['checks'].append('actual title Settings click and Escape return')
                    await tap(center(primary));await shot('home')
                    assert not surfaces(args.output/(name+'-home.png'),[(195,163,102)]), 'Start still shows title primary'
                    await tap((rect[0]+rect[2]*1202/1280,rect[1]+rect[3]*42/720))
                    menu = await shot('home-menu')
                    home = locate_original(menu,'HOME')
                    row['checks'].append('actual Home menu click; rendered HOME located with OCR')
                    await tap(home);resumed=await shot('home-resumed')
                    assert len(surfaces(resumed,[(41,58,59)])) < len(surfaces(menu,[(41,58,59)])), 'Home menu did not close'
                    row['checks'].append('actual HOME button closes navigation')
                    if touch:
                        await page.set_viewport_size({'width':844,'height':390});await page.wait_for_timeout(1500);await shot('home-resized')
                        row['checks'].append('non-16:9 resize to 844x390')
                    assert not errors, errors
                    assert not any('SCRIPT ERROR:' in line or 'SHADER ERROR:' in line or 'Parse Error:' in line for line in logs), logs
                    row['page_errors']=errors;report['devices'].append(row)
                    (args.output/'report.json').write_text(json.dumps(report,indent=2))
                finally:
                    (args.output/(name+'-browser.log')).write_text('\n'.join(logs+errors))
                    await context.close()
        finally:
            await browser.close()
    if len(report['devices']) == 2:
        report['primary_max_logical_delta']=max(abs(a-b) for a,b in zip(report['devices'][0]['primary_logical'],report['devices'][1]['primary_logical']))
        assert report['primary_max_logical_delta']<2, report
    report['failed']=0
    (args.output/'report.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report))


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root-url',required=True)
    parser.add_argument('--expected-source',required=True)
    parser.add_argument('--expected-build',required=True)
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--device',choices=['both','desktop','mobile'],default='both')
    parser.add_argument('--proxy-from-environment',action='store_true')
    asyncio.run(run(parser.parse_args()))
