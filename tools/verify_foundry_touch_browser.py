"""Touch-only Foundry regression; browser emulation is not a physical phone."""
import asyncio
import json
import shutil
import sys
import io
from PIL import Image
from pathlib import Path
from playwright.async_api import async_playwright

async def main():
    url = sys.argv[1] if len(sys.argv) > 1 else 'http://127.0.0.1:8765'
    folder = Path(sys.argv[2]) if len(sys.argv) > 2 else Path('build/verification/foundry-touch')
    folder.mkdir(parents=True, exist_ok=True)
    logs, screenshots = [], []
    async with async_playwright() as p:
        browser = await p.chromium.launch(executable_path=shutil.which('chromium'), args=[
            '--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'])
        for width, height in [(1280, 720), (844, 390)]:
            page = await browser.new_page(viewport={'width': width, 'height': height}, has_touch=True, is_mobile=True)
            page.on('console', lambda m: logs.append(m.text))
            page.on('pageerror', lambda e: logs.append('PAGE ERROR: ' + str(e)))
            await page.goto(url, wait_until='networkidle', timeout=90000)
            await page.wait_for_function('window.PLAYTEST_LOADING_DONE === true', timeout=90000)
            await page.wait_for_timeout(900)
            canvas = await page.locator('#canvas').bounding_box()
            # Godot keeps the logical 16:9 viewport inside the browser canvas.
            scale = min(canvas["width"] / 1280, canvas["height"] / 720)
            origin_x = canvas["x"] + (canvas["width"] - 1280 * scale) / 2
            origin_y = canvas["y"] + (canvas["height"] - 720 * scale) / 2
            async def tap(x, y):
                await page.touchscreen.tap(origin_x + x * scale,
                                          origin_y + y * scale)
                await page.wait_for_timeout(650)
            async def shot(name):
                filename = f'{width}-{name}.png'
                await page.screenshot(path=str(folder / filename))
                screenshots.append(filename)
            await tap(640, 500)
            await tap(345, 615)
            await shot('base')
            await tap(1073, 216)
            await shot('double-jump')
            await tap(1148, 216)
            await shot('four-shot')
            await tap(998, 216)
            await tap(1060, 323)
            await shot('other-level')
            # Explicit pages work with mouse emulation disabled; test final page.
            for unused in range(7):
                await tap(1200, 426)
            await tap(1060, 388)
            await shot('last-page-level')
            await tap(1000, 426)
            await shot('previous-page')
            await tap(185, 153)  # pause
            await shot('paused')
            def title_pixels(data):
                return Image.open(io.BytesIO(data)).crop((int(origin_x + 16*scale), int(origin_y + 12*scale), int(origin_x + 650*scale), int(origin_y + 60*scale))).tobytes()
            paused_title = title_pixels(await page.screenshot())
            await page.wait_for_timeout(700)
            if title_pixels(await page.screenshot()) != paused_title:
                raise RuntimeError('Touch pause did not freeze visible elapsed title')
            await tap(1060, 280)  # new level while paused
            await shot('paused-switch')
            resumed_title = title_pixels(await page.screenshot())
            await page.wait_for_timeout(700)
            if title_pixels(await page.screenshot()) == resumed_title:
                raise RuntimeError('Selecting level while paused did not resume elapsed title')
            await tap(106, 153)  # replay
            await page.wait_for_timeout(18000)
            await shot('replay-end')
            await tap(1220, 497)  # inline sources (never modal)
            await shot('sources')
            for unused in range(10):
                await tap(1200, 426)
            await shot('last-source-page')
            await tap(1220, 497)
            await tap(1060, 325)
            await shot('sources-closed-switch')
            await page.close()
        await browser.close()
    errors = [line for line in logs if any(t in line for t in ('SCRIPT ERROR', 'Parse Error', 'PAGE ERROR', 'Failed to load script'))]
    report = {'url': url, 'touch_only': True, 'viewports': [[1280, 720], [844, 390]],
              'errors': errors, 'failed': len(errors), 'screenshots': screenshots,
              'scope': 'actual_browser_touch_taps_and_paging_visible_gui; pair with foundry_touch_runner state assertions',
              'physical_android_device': 'awaiting-device'}
    (folder / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    (folder / 'console.txt').write_text('\n'.join(logs))
    print(json.dumps(report, ensure_ascii=False))
    if errors:
        raise RuntimeError('Foundry emitted Web errors')

if __name__ == '__main__':
    asyncio.run(main())
