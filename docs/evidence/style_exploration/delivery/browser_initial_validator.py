import argparse, asyncio, hashlib, io, json, re, shutil, subprocess, time
from pathlib import Path
from urllib.parse import urljoin
from PIL import Image
from playwright.async_api import async_playwright


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


async def main():
    p = argparse.ArgumentParser()
    p.add_argument('url')
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--build-id', required=True)
    p.add_argument('--source', required=True)
    a = p.parse_args()
    a.output.mkdir(parents=True, exist_ok=True)
    logs, checks = [], []
    report = {'status': 'failed', 'url': a.url, 'build_id': a.build_id, 'source_commit': a.source,
              'scope': 'real Chromium canvas, mouse/touch pointer and accepted HUD OCR; physical device and audio unverified',
              'validator_sha256': sha(Path(__file__)), 'checks': checks, 'logs': logs}
    async with async_playwright() as pw:
        browser = await pw.chromium.launch(executable_path=shutil.which('chromium'), headless=True,
            args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
        ctx = await browser.new_context(viewport={'width':1280,'height':720}, has_touch=True)
        page = await ctx.new_page()
        page.on('console', lambda m: logs.append(m.text))
        page.on('pageerror', lambda m: logs.append('PAGE ERROR: '+str(m)))

        async def screenshot(name, status=False):
            data = await page.screenshot(path=str(a.output/(name+'.png')))
            if not status:
                return ''
            strip = Image.open(io.BytesIO(data)).crop((315,42,1260,70)).resize((2835,84))
            target = a.output/(name+'-status.png')
            strip.save(target)
            text = subprocess.check_output(['tesseract',str(target),'stdout','--psm','7'],stderr=subprocess.DEVNULL,text=True).strip()
            return text

        async def accepted(name, style, biome='plains', seed=0):
            await page.wait_for_timeout(220)
            text = await screenshot(name, True)
            normalized = text.lower().replace('|','/').replace('seec','seed')
            assert style in normalized and biome in normalized and re.search(r'seed\s*'+str(seed)+r'\b',normalized), (name,text)
            checks.append({'action':name,'accepted_style':style,'accepted_biome':biome,'accepted_seed':seed,'hud_ocr':text})

        try:
            await page.goto(a.url, wait_until='domcontentloaded', timeout=60000)
            await page.wait_for_function('window.PLAYTEST_LOADING_DONE === true', timeout=180000)
            await page.wait_for_timeout(800)
            metadata = await (await page.request.get(urljoin(a.url,'build-info.json'))).json()
            assert metadata['build_id'] == a.build_id and metadata['source_commit'] == a.source, metadata
            report['build_info'] = metadata
            badge = await page.locator('#playtest-version').get_attribute('data-build-id')
            assert badge == a.build_id, (badge,a.build_id)
            # Ordinary title keeps formal gameplay first and exposes this isolated lab second.
            await screenshot('00-title')
            await page.mouse.click(600,499)
            await accepted('01-title-mouse-enters-lab','retro')
            for index,style in enumerate(['retro','basic','scribble','underworld','cavern']):
                await page.touchscreen.tap([70,165,250,340,430][index],26)
                await accepted('style-'+style,style)
            for index,seed in enumerate([0,101,307,911]):
                await page.touchscreen.tap([486,515,544,574][index],26)
                await accepted('seed-'+str(seed),'cavern',seed=seed)
            await page.touchscreen.tap(486,26)
            await accepted('reset-seed-zero','cavern')
            for index,style in [(3,'underworld'),(4,'cavern')]:
                await page.touchscreen.tap([70,165,250,340,430][index],26)
                await accepted(style+'-plains',style)
                for biome,x in [('forest',774),('gear',832),('plains',722)]:
                    await page.touchscreen.tap(x,26)
                    await accepted(style+'-'+biome,style,biome)
            await page.touchscreen.tap(616,26)
            await page.wait_for_timeout(200)
            await screenshot('catalog-open')
            await page.touchscreen.tap(616,26)
            await accepted('catalog-closed-first-input','cavern')
            await page.keyboard.down('KeyD')
            await page.wait_for_timeout(220)
            await page.keyboard.up('KeyD')
            await page.keyboard.press('Space')
            await page.wait_for_timeout(160)
            await screenshot('first-move-jump-after-catalog')
            checks.append({'action':'move and jump after closing catalog','result':'input dispatched and rendered; native Motor acceptance is separately tested'})
            await page.touchscreen.tap(671,26)
            await page.wait_for_timeout(600)
            text=await screenshot('home-after-lab',True)
            assert 'cavern plains' not in text.lower(),text
            checks.append({'action':'Home pointer leaves lab','hud_ocr':text})
            direct_url=a.url+('&' if '?' in a.url else '?')+'styles=1'
            await page.goto(direct_url,wait_until='domcontentloaded',timeout=60000)
            await page.wait_for_function('window.PLAYTEST_LOADING_DONE === true',timeout=180000)
            await accepted('direct-query-entry','retro')
            errors=[line for line in logs if any(x in line for x in ('SCRIPT ERROR:','Parse Error:','SHADER ERROR:','PAGE ERROR:','Failed to load','Resource file not found:'))]
            assert not errors, errors
            assert any('Godot Engine v4.7.2' in x for x in logs), 'Expected Godot engine did not start'
            report['status']='passed'
        finally:
            (a.output/'browser_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
            await browser.close()
    print(json.dumps(report,ensure_ascii=False))


asyncio.run(main())
