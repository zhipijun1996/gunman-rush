import asyncio,sys,json,shutil
from pathlib import Path
sys.path.insert(0,'tools')
import verify_random_stage_browser as h
from playwright.async_api import async_playwright
out=Path('build/verification/quality-review-final-formal-gui');out.mkdir(parents=True,exist_ok=True);h.FOLDER=out
async def main():
 logs=[]
 async with async_playwright() as p:
  b=await p.chromium.launch(executable_path=shutil.which('chromium'),headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  c=await b.new_context(viewport={'width':1280,'height':720},record_video_dir=str(out/'video'))
  page=await c.new_page();page.on('console',lambda m:logs.append(m.text))
  async def snap(n):
   await page.screenshot(path=str(out/(n+'.png')))
   return (await asyncio.to_thread(h.ocr,n)).upper()
  async def wait(n,phrase):
   for i in range(60):
    t=await snap(n)
    if phrase in t:return t
    await page.wait_for_timeout(500)
   raise RuntimeError('missing '+phrase+' '+t)
  try:
   await page.goto('http://127.0.0.1:8765',wait_until='networkidle',timeout=60000)
   await wait('title','ENTER HOME');await page.mouse.click(*h.text_center('title','ENTER HOME'))
   await wait('home','NOTES')
   for i in range(30):
    await page.keyboard.down('d');await page.wait_for_timeout(200);await page.keyboard.up('d');await page.wait_for_timeout(80)
    t=await snap('approach')
    if 'ENTER PLAINS' in t or 'PLAINS /' in t or ('PLAINS' in t and 'INTERACT' in t):break
   await page.keyboard.press('w');await wait('departure','THE PLAINS AWAIT')
   await page.mouse.click(*h.text_center('departure','WINDCHIME PLAINS'));await wait('formal-entry','CONNECTED REGION')
   for i in range(6):
    await page.keyboard.down('d')
    if i%2==1: await page.keyboard.down('Space')
    await page.wait_for_timeout(350);await page.keyboard.up('Space');await page.keyboard.up('d');await page.wait_for_timeout(120)
    await snap('formal-motion-'+str(i))
   await page.keyboard.press('Escape');await snap('formal-pause')
  finally:
   (out/'console.log').write_text('\n'.join(logs));await c.close();await b.close()
asyncio.run(main())
