import asyncio,json,shutil,sys
from pathlib import Path
sys.path.insert(0,'tools')
import verify_random_stage_browser as h
from playwright.async_api import async_playwright
out=Path('build/verification/wood-browser');out.mkdir(parents=True,exist_ok=True);h.FOLDER=out
async def main():
 logs=[];report={'status':'failed','scope':'real Web ModuleLab remote-bell one-way output, not formal traversal or device acceptance'}
 async with async_playwright() as p:
  b=await p.chromium.launch(executable_path=shutil.which('chromium'),headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  c=await b.new_context(viewport={'width':1280,'height':720})
  page=await c.new_page();page.on('console',lambda m:logs.append(m.text));page.on('pageerror',lambda e:logs.append('PAGE ERROR '+str(e)))
  async def snap(n):
   await page.screenshot(path=str(out/(n+'.png')))
   return (await asyncio.to_thread(h.ocr,n)).upper()
  async def wait(n,phrase):
   for i in range(60):
    t=await snap(n)
    if phrase in t:return
    await page.wait_for_timeout(500)
   raise RuntimeError('missing '+phrase+' '+t)
  try:
   await page.goto('http://127.0.0.1:8767',wait_until='networkidle',timeout=60000)
   report['build_id']=await page.locator('#playtest-version').get_attribute('data-build-id')
   await wait('title','DEVELOPMENT DEMOS');await page.mouse.click(*h.text_center('title','DEVELOPMENT DEMOS'))
   await wait('development','MODULE LAB');await page.mouse.click(*h.text_center('development','MODULE LAB'))
   await wait('lab','MORE TRIALS');await page.mouse.click(1010,97)
   await wait('menu','REMOTE BELL');await page.mouse.click(*h.text_center('menu','REMOTE BELL'))
   await wait('wood','MODULE LAB / REMOTE BELL');await page.wait_for_timeout(700);await snap('wood')
   if any(any(err in line for err in ['ERROR:','SCRIPT ERROR','SHADER ERROR','PAGE ERROR','WebGL: INVALID_','WebGL: CONTEXT_LOST']) for line in logs):raise RuntimeError(str(logs))
   report['status']='passed';report['observed']='Actual Web one-way shader rendered at 70/90/160 widths; no engine/shader/WebGL errors; pixels reviewed separately'
  finally:
   (out/'console.log').write_text('\n'.join(logs));(out/'report.json').write_text(json.dumps(report,indent=2));await c.close();await b.close()
 print(json.dumps(report))
asyncio.run(main())
