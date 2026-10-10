"""Render the actual module lab through visible menus; no engine state injection.
Complements formal-room touch/browser checks with terrain, gear, ferry and Boss
art inspection captures. This is visual coverage, not a gameplay completion test.
"""
import asyncio
import json
import shutil
import subprocess
import sys
from pathlib import Path
from playwright.async_api import async_playwright
import verify_random_stage_browser as ui

FOLDER = Path('build/verification/plains-v3-browser')

async def main(url):
    FOLDER.mkdir(parents=True, exist_ok=True)
    ui.FOLDER = FOLDER
    logs, checks = [], []
    async with async_playwright() as p:
        browser = await p.chromium.launch(executable_path=shutil.which('chromium'), headless=True,
            args=['--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'])
        try:
            context = await browser.new_context(viewport={'width': 1280, 'height': 720}, has_touch=True, is_mobile=True)
            page = await context.new_page()
            page.on('console', lambda message: logs.append(message.text))
            page.on('pageerror', lambda error: logs.append('PAGE ERROR: ' + str(error)))
            await page.goto(url, wait_until='networkidle', timeout=45000)
            async def capture(name):
                await page.screenshot(path=str(FOLDER / (name + '.png')), timeout=10000)
            for _ in range(12):
                await capture('title')
                if 'DEVELOPMENT' in ui.ocr('title').upper(): break
                await page.wait_for_timeout(400)
            await page.touchscreen.tap(*ui.text_center('title', 'DEVELOPMENT DEMOS'))
            await page.wait_for_timeout(300)
            await capture('entries')
            await page.touchscreen.tap(*ui.text_center('entries', 'MODULE LAB'))
            await page.wait_for_timeout(300)
            for name, x, label in [('safe', 83, 'SAFE'), ('shaft', 467, 'RECOIL'), ('gear', 595, 'TIMED'), ('ferry', 723, 'MOVING'), ('boss', 979, 'BOSS')]:
                await page.touchscreen.tap(x, 184)
                await page.wait_for_timeout(350)
                await capture(name)
                text = ui.ocr(name, (0, 0, 1065, 155)).upper()
                if label not in text:
                    raise RuntimeError('Visible module selection failed: ' + name + ': ' + text)
                checks.append('Actual rendered module: ' + name)
            await page.touchscreen.tap(1170, 349)
            await page.wait_for_timeout(450)
            await capture('windchime')
            text = ui.ocr('windchime', (0, 0, 1065, 155)).upper()
            if 'WINDCHIME' not in text:
                raise RuntimeError('Visible windchime module selection failed: ' + text)
            checks.append('Actual rendered module: windchime, visual capture only')
            errors = [m for m in logs if any(key in m for key in ['SCRIPT ERROR', 'SHADER ERROR', 'PAGE ERROR', 'Parse Error'])]
            if errors: raise RuntimeError(str(errors))
            report = {'checks': checks, 'errors': errors, 'logs': logs, 'build_id': await page.locator('#playtest-version').get_attribute('data-build-id'), 'scope': 'Module visual capture via GUI, not complete traversal or device acceptance'}
            (FOLDER / 'report.json').write_text(json.dumps(report, indent=2))
            print(json.dumps(report))
        finally:
            await browser.close()

if __name__ == '__main__':
    server = None
    if len(sys.argv) == 1:
        server = subprocess.Popen([sys.executable, '-m', 'http.server', '8788', '--bind', '127.0.0.1', '--directory', 'build/web'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        asyncio.run(asyncio.wait_for(main(sys.argv[1] if len(sys.argv) > 1 else 'http://127.0.0.1:8788/'), timeout=150))
    finally:
        if server:
            server.terminate()
            server.wait(timeout=5)
