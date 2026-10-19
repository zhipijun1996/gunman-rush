import asyncio,json
from pathlib import Path
from playwright.async_api import async_playwright
OUT=Path('build/windchime-review/gui-draft');OUT.mkdir(parents=True,exist_ok=True)
async def main():
 logs=[]; errors=[]
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  context=await browser.new_context(viewport={'width':1280,'height':720})
  page=await context.new_page();page.on('console',lambda m:logs.append(m.text));page.on('pageerror',lambda e:errors.append(str(e)))
  await page.goto('http://127.0.0.1:8770/?windchime=1',wait_until='networkidle',timeout=90000)
  await page.wait_for_function('window.PLAYTEST_LOADING_DONE===true',timeout=90000)
  await page.wait_for_timeout(800)
  await page.mouse.click(194,107);await page.wait_for_timeout(300)
  await page.screenshot(path=str(OUT/'01-catalog.png'))
  await page.mouse.click(52,107);await page.wait_for_timeout(300)
  await page.screenshot(path=str(OUT/'02-catalog-restart.png'))
  await page.mouse.click(259,107);await page.keyboard.down('d');await page.wait_for_timeout(700)
  await page.screenshot(path=str(OUT/'03-paused-input.png'))
  await page.keyboard.up('d');await page.mouse.click(259,107);await page.wait_for_timeout(300)
  await page.mouse.click(122,107);await page.wait_for_timeout(500)
  await page.mouse.click(194,107);await page.wait_for_timeout(200)
  await page.mouse.click(122,107);await page.wait_for_timeout(500)
  await page.screenshot(path=str(OUT/'04-switch-under-catalog.png'))
  await page.mouse.click(312,107);await page.wait_for_timeout(600)
  await page.screenshot(path=str(OUT/'05-home.png'))
  (OUT/'console.log').write_text('\n'.join(logs))
  print(json.dumps({'source':'provisional draft','build':await page.locator('#playtest-version').get_attribute('data-build-id'),'page_errors':errors}))
  await browser.close()
asyncio.run(main())
