import asyncio,os,sys,json,time
from pathlib import Path
from playwright.async_api import async_playwright
sys.path.insert(0,'/workspace/ui-workline/tools')
from verify_forest_browser import environment_proxy
out=Path('/workspace/ui-workline/build/verification/demo-ui-r3/public-ring');out.mkdir()
url='https://zhipijun1996.github.io/gunman-rush-previews/previews/DEMO-UI-01/8dc2f4e6a2c6f511c22004784cb71b5f3d0d7a96/5e9adddb1662/'
async def main():
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,proxy=environment_proxy()[0],args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  context=await browser.new_context(viewport={'width':1280,'height':720});page=await context.new_page();events=[];errors=[]
  page.on('console',lambda m: events.append(m.text));page.on('pageerror',lambda e:errors.append(str(e)))
  await page.goto(url,wait_until='networkidle',timeout=60000);await page.wait_for_function('window.PLAYTEST_LOADING_DONE===true',timeout=60000)
  await page.mouse.click(230,190) # Inspected real native BeginAdventure bounds.
  for _ in range(100):
   if any('region_assembled' in e for e in events):break
   await page.wait_for_timeout(100)
  assert any('region_assembled' in e for e in events)
  await page.wait_for_timeout(1000);await page.screenshot(path=str(out/'ground.png'))
  await page.mouse.move(700,600);await page.mouse.down();await page.wait_for_timeout(100)
  await page.keyboard.down('Space')
  for i in range(4):
   await page.wait_for_timeout(100);await page.screenshot(path=str(out/f'held-{i}.png'))
  await page.keyboard.up('Space');await page.mouse.up();await page.wait_for_timeout(150);await page.screenshot(path=str(out/'released.png'))
  (out/'report.json').write_text(json.dumps({'url':url,'browser':browser.version,'source_commit':'8dc2f4e6a2c6f511c22004784cb71b5f3d0d7a96','build_id':'5e9adddb1662','method':'Actual inspected BeginAdventure pointer; real ground aim held before Space jump; four held frames then actual release. No engine hook. Pixel inspection separate.','events':events,'errors':errors},ensure_ascii=False,indent=2)+'\n')
  await browser.close()
asyncio.run(main())
