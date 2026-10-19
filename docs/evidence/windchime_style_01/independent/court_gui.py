import asyncio,json
from pathlib import Path
from playwright.async_api import async_playwright
OUT=Path('build/windchime-review/gui-warm');OUT.mkdir(parents=True,exist_ok=True)
async def main():
 logs=[];errors=[]
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  context=await browser.new_context(viewport={'width':1280,'height':720},record_video_dir=str(OUT/'video'),record_video_size={'width':1280,'height':720})
  page=await context.new_page();page.on('console',lambda m:logs.append(m.text));page.on('pageerror',lambda e:errors.append(str(e)))
  await page.goto('http://127.0.0.1:8770/?windchime=1',wait_until='networkidle',timeout=90000)
  await page.wait_for_function('window.PLAYTEST_LOADING_DONE===true',timeout=90000)
  await page.wait_for_timeout(700)
  version=await page.locator('#playtest-version').get_attribute('data-build-id')
  await page.keyboard.down('d')
  for step in range(19):
   await page.keyboard.down('Space');await page.wait_for_timeout(170);await page.keyboard.up('Space');await page.wait_for_timeout(300)
   if step in (6,10,15,18): await page.screenshot(path=str(OUT/f'route-{step:02}.png'))
  await page.keyboard.up('d')
  await page.mouse.move(880,450);await page.mouse.down();await page.wait_for_timeout(120);await page.mouse.up();await page.wait_for_timeout(30)
  await page.screenshot(path=str(OUT/'shot.png'))
  await page.mouse.click(194,107);await page.wait_for_timeout(300);await page.mouse.click(52,107);await page.wait_for_timeout(400)
  await page.screenshot(path=str(OUT/'restart.png'))
  (OUT/'console.log').write_text('\n'.join(logs));(OUT/'result.json').write_text(json.dumps({'build':version,'page_errors':errors},indent=2))
  await context.close();await browser.close()
asyncio.run(main())
