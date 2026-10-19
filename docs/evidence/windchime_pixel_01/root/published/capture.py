import asyncio,json,urllib.request
from pathlib import Path
from playwright.async_api import async_playwright
OUT=Path('build/pixel-browser/published');BASE='https://zhipijun1996.github.io/gunman-rush/'
EXPECTED='d2c684ef8fc0';SOURCE='c0f8e50770145795db5affd4afdbffff2479f1ea'
async def main():
 info=json.load(urllib.request.urlopen(BASE+'build-info.json?v='+EXPECTED,timeout=30));assert info['build_id']==EXPECTED and info['source_commit']==SOURCE
 logs=[];requests=[]
 async with async_playwright() as p:
  b=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  c=await b.new_context(viewport={'width':1280,'height':720})
  page=await c.new_page();page.on('console',lambda m:logs.append(m.text));page.on('pageerror',lambda e:logs.append('PAGE ERROR '+str(e)));page.on('requestfailed',lambda r:requests.append({'url':r.url,'failure':r.failure}))
  await page.goto(BASE+'?plains=1&v='+EXPECTED,wait_until='domcontentloaded',timeout=60000)
  await page.wait_for_function('window.PLAYTEST_LOADING_DONE === true',timeout=180000)
  await page.wait_for_timeout(2200)
  actual=await page.locator('#playtest-version').get_attribute('data-build-id');assert actual==EXPECTED
  await page.screenshot(path=str(OUT/'01-published-entry.png'))
  await page.keyboard.down('d');await page.wait_for_timeout(450);await page.keyboard.down('Space');await page.wait_for_timeout(180);await page.keyboard.up('Space');await page.wait_for_timeout(650);await page.keyboard.up('d');await page.screenshot(path=str(OUT/'02-published-moved.png'))
  errors=[s for s in logs if any(x in s for x in ['SCRIPT ERROR','SHADER ERROR','ERROR:','PAGE ERROR','WebGL: INVALID_'])]
  report={'url':BASE+'?plains=1&v='+EXPECTED,'build_id':actual,'build_info':info,'errors':errors,'request_failures':requests,'scope':'Published HTTPS actual formal map1 entry and ordinary keyboard jump/movement; software WebGL, not physical device or complete campaign'}
  (OUT/'console.log').write_text('\n'.join(logs));(OUT/'report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report));await c.close();await b.close()
  assert not errors
asyncio.run(main())
