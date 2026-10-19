import asyncio,json
from pathlib import Path
from playwright.async_api import async_playwright
OUT=Path('build/pixel-review/formal-enemy-gui');OUT.mkdir(parents=True,exist_ok=True)
async def main():
 logs=[];observations=[]
 async with async_playwright() as p:
  b=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  for m in [1,2]:
   c=await b.new_context(viewport={'width':1280,'height':720})
   page=await c.new_page();page.on('console',lambda msg:logs.append(msg.text));page.on('pageerror',lambda e:logs.append('PAGE ERROR '+str(e)))
   await page.goto(f'http://127.0.0.1:8770/?plains=1&pixel_inspect={m}',wait_until='networkidle',timeout=90000)
   await page.wait_for_function('window.PLAYTEST_LOADING_DONE === true',timeout=90000)
   await page.wait_for_timeout(1400)
   await page.mouse.click(630,58)
   for i in range(6):
    await page.wait_for_timeout(350 if i==0 else 220)
    await page.screenshot(path=str(OUT/f'map{m}-enemy-{i:02d}.png'))
   observations.append({'map':m,'build':await page.locator('#playtest-version').get_attribute('data-build-id'),'url':page.url})
   await c.close()
  await b.close()
 errors=[x for x in logs if any(s in x for s in ['SCRIPT ERROR','SHADER ERROR','ERROR:','PAGE ERROR','WebGL: INVALID_'])]
 (OUT/'console.log').write_text('\n'.join(logs));(OUT/'report.json').write_text(json.dumps({'observations':observations,'errors':errors,'scope':'fresh explicit Enemy positioned fixture, damage enabled; six consecutive observed samples per map, not route completion'},indent=2))
 print(json.dumps({'observations':observations,'errors':errors}))
asyncio.run(main())
