import asyncio,hashlib,io,json,os,shutil,subprocess
from pathlib import Path
from PIL import Image
from playwright.async_api import async_playwright

async def main():
 folder=Path('docs/evidence/style_exploration/delivery/browser_public');folder.mkdir(exist_ok=True)
 report={'status':'failed','url':'https://zhipijun1996.github.io/gunman-rush/?styles=1&v=d2d469f81582','source_commit':'32200d04fe233bda16cf50f678aabee51a9715e5','build_id':'d2d469f81582','checks':[],'logs':[],'http_failures':[],'scope':'HTTPS Chromium loader and canvas pointer smoke; physical device and audio unverified','validator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path=shutil.which('chromium'),headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  ctx=await browser.new_context(viewport={'width':1280,'height':720},has_touch=True);page=await ctx.new_page()
  page.on('console',lambda m:report['logs'].append({'type':m.type,'text':m.text,'location':m.location}))
  page.on('pageerror',lambda m:report['logs'].append({'type':'pageerror','text':str(m),'location':{}}))
  page.on('response',lambda r:report['http_failures'].append({'url':r.url,'status':r.status}) if r.status>=400 else None)
  async def check(stem,style,biome):
   await page.wait_for_timeout(250);image=await page.screenshot(path=str(folder/(stem+'.png')))
   strip=Image.open(io.BytesIO(image)).crop((315,42,1260,70)).resize((2835,84));path=folder/(stem+'-status.png');strip.save(path)
   text=subprocess.check_output(['tesseract',str(path),'stdout','--psm','7'],stderr=subprocess.DEVNULL,text=True,env={**os.environ,'OMP_THREAD_LIMIT':'1'}).strip().lower()
   assert style in text and biome in text,(stem,text)
   report['checks'].append({'action':stem,'accepted_style':style,'accepted_biome':biome,'hud_ocr':text})
  try:
   await page.goto(report['url'],wait_until='domcontentloaded',timeout=60000)
   await page.wait_for_function('window.PLAYTEST_LOADING_DONE===true',timeout=180000)
   info=await page.evaluate("fetch('build-info.json?v=d2d469f81582', {cache:'no-store'}).then(r=>{if(!r.ok)throw new Error('metadata HTTP '+r.status);return r.json()})")
   assert info['source_commit']==report['source_commit'] and info['build_id']==report['build_id'],info
   assert await page.locator('#playtest-version').get_attribute('data-build-id')==report['build_id']
   await check('01-direct-entry','retro','plains')
   await page.touchscreen.tap(430,26);await check('02-cavern-plains','cavern','plains')
   await page.touchscreen.tap(774,26);await check('03-cavern-forest','cavern','forest')
   await page.touchscreen.tap(832,26);await check('04-cavern-gear','cavern','gear')
   errors=[row for row in report['logs'] if row['type'] in ['error','pageerror'] and not row['location'].get('url','').endswith('/favicon.ico')]
   assert not errors,errors
   assert not [row for row in report['http_failures'] if not row['url'].endswith('/favicon.ico')],report['http_failures']
   report['status']='passed'
  finally:
   (folder/'browser_report.json').write_text(json.dumps(report,indent=2)+'\n');await browser.close()
 print(json.dumps(report))

asyncio.run(main())
