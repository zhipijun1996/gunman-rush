import asyncio,json
from pathlib import Path
from playwright.async_api import async_playwright
OUT=Path('build/pixel-review/formal-gui');OUT.mkdir(parents=True,exist_ok=True)
async def main():
 logs=[];observations=[]
 async with async_playwright() as p:
  b=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  for mode in ['ordinary',1,2]:
   c=await b.new_context(viewport={'width':1280,'height':720})
   page=await c.new_page();page.on('console',lambda m:logs.append(m.text));page.on('pageerror',lambda e:logs.append('PAGE ERROR '+str(e)))
   suffix='' if mode=='ordinary' else f'?plains=1&pixel_inspect={mode}'
   await page.goto('http://127.0.0.1:8770/'+suffix,wait_until='networkidle',timeout=90000)
   await page.wait_for_function('window.PLAYTEST_LOADING_DONE === true',timeout=90000)
   await page.wait_for_timeout(1800)
   if mode=='ordinary':
    await page.screenshot(path=str(OUT/'ordinary-title.png'))
    await page.keyboard.press('Enter');await page.wait_for_timeout(2000)
    await page.screenshot(path=str(OUT/'ordinary-entry.png'))
    await page.keyboard.down('d');await page.wait_for_timeout(350)
    await page.keyboard.down('Space');await page.wait_for_timeout(180);await page.keyboard.up('Space');await page.wait_for_timeout(450);await page.keyboard.up('d')
    await page.screenshot(path=str(OUT/'ordinary-jump.png'))
    await page.keyboard.press('Escape');await page.wait_for_timeout(200)
    await page.screenshot(path=str(OUT/'ordinary-pause.png'))
    await page.keyboard.press('Escape');await page.wait_for_timeout(200)
   else:
    await page.mouse.click(440,58);await page.wait_for_timeout(1200)
    await page.screenshot(path=str(OUT/f'map{mode}-boss-01.png'))
    await page.wait_for_timeout(1600)
    await page.screenshot(path=str(OUT/f'map{mode}-boss-02.png'))
    await page.mouse.click(630,58);await page.wait_for_timeout(1100)
    await page.screenshot(path=str(OUT/f'map{mode}-enemy.png'))
   observations.append({'mode':mode,'build':await page.locator('#playtest-version').get_attribute('data-build-id'),'url':page.url})
   await c.close()
  await b.close()
 errors=[x for x in logs if any(s in x for s in ['SCRIPT ERROR','SHADER ERROR','ERROR:','PAGE ERROR','WebGL: INVALID_'])]
 (OUT/'console.log').write_text('\n'.join(logs));(OUT/'report.json').write_text(json.dumps({'observations':observations,'errors':errors,'scope':'ordinary title route/input plus explicit position-fixture samples; not campaign traversal','gpu':[x for x in logs if x.startswith('PIXEL_GPU')]},indent=2))
 print(json.dumps({'observations':observations,'errors':errors}))
asyncio.run(main())
