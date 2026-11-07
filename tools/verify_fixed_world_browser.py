"""Observe the exported fixed-world title, start, keyboard movement, map and small pause.

Uses Chromium/Playwright, ordinary input and native screenshots, with no engine hooks.
Screenshots need visual review; this is not a complete browser playthrough or physical-device test.
"""
import argparse
import asyncio
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import shutil
import threading
from playwright.async_api import async_playwright

ROOT = Path(__file__).resolve().parents[1]

class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        super().end_headers()

async def observe(url, output):
    output.mkdir(parents=True, exist_ok=True)
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(
            executable_path=shutil.which('chromium'), headless=True,
            args=['--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'])
        try:
            context = await browser.new_context(viewport={'width': 1280, 'height': 720}, device_scale_factor=1)
            page = await context.new_page()
            logs, errors, http_errors = [], [], []
            page.on('console', lambda message: logs.append(message.text))
            page.on('pageerror', lambda error: errors.append(str(error)))
            page.on('response', lambda response: http_errors.append(
                {'url': response.url, 'status': response.status}) if response.status >= 400 else None)
            await page.goto(url, wait_until='domcontentloaded')
            await page.wait_for_function('window.PLAYTEST_LOADING_DONE === true', timeout=120000)
            async def capture(name, delay=600):
                await page.wait_for_timeout(delay)
                await page.screenshot(path=str(output / (name + '.png')))
            await capture('title', 1800)
            await page.keyboard.press('Enter')
            await capture('new-game', 2000)
            await page.keyboard.down('d')
            await page.keyboard.down('Space')
            await page.wait_for_timeout(350)
            await page.keyboard.up('Space')
            await page.keyboard.up('d')
            await capture('jump', 700)
            await page.keyboard.press('m')
            await capture('map')
            await page.keyboard.press('Escape')
            await page.wait_for_timeout(300)
            await page.set_viewport_size({'width': 960, 'height': 540})
            await page.wait_for_timeout(500)
            await page.keyboard.press('Escape')
            await capture('pause-960')
            report = {'build_id': await page.locator('#playtest-version').get_attribute('data-build-id'),
                      'browser': 'Chromium SwiftShader, desktop viewport 1280x720 then 960x540',
                      'scope': 'Ordinary title/start/jump/map/pause input; inspect screenshots. Full Web route and physical mobile unverified.',
                      'logs': logs, 'page_errors': errors, 'http_errors': http_errors}
            (output / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
            if errors or any(any(marker in log for marker in
                    ['SCRIPT ERROR:', 'SHADER ERROR:', 'Parse Error:', 'ERROR: Failed to load']) for log in logs):
                raise RuntimeError('Browser/engine failure; inspect report.json')
            # Chromium requests an optional favicon even when the exported page declares none.
            if any(not error['url'].endswith('/favicon.ico') for error in http_errors):
                raise RuntimeError('Exported resource failure; inspect report.json')
            if not any('Godot Engine v4.7.2' in log for log in logs):
                raise RuntimeError('Locked engine did not start')
            print('WEB FIXED WORLD: engine and resource checks passed; five screenshots await visual review')
        finally:
            await browser.close()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url')
    parser.add_argument('--output', type=Path, default=ROOT / 'build/plains_v07/browser')
    args = parser.parse_args()
    server = None
    try:
        if not args.url:
            server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(ROOT / 'build/web')))
            threading.Thread(target=server.serve_forever, daemon=True).start()
            args.url = f'http://127.0.0.1:{server.server_port}/'
        asyncio.run(observe(args.url, args.output))
    finally:
        if server:
            server.shutdown()
            server.server_close()

if __name__ == '__main__':
    main()
