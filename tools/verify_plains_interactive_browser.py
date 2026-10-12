"""D081 ordinary rendered practice input; phase entries are explicit fixtures, not earned progression."""
import asyncio,json,os,shutil,sys,subprocess
from pathlib import Path
from playwright.async_api import async_playwright
import verify_random_stage_browser as h
FOLDER=Path('build/verification/plains-interactive-browser');h.FOLDER=FOLDER
async def main(url):
 FOLDER.mkdir(parents=True,exist_ok=True)
 report={'url':url,'failed':1,'checks':[],'scope':'Ordinary menu/movement/aim/shoot. Stage II/III are named practice fixtures; no full Boss victory claim.'};logs=[]
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path=shutil.which('chromium'),headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  try:
   context=await browser.new_context(viewport={'width':1280,'height':720},record_video_dir=str(FOLDER/'video') if os.environ.get('GUNMAN_RECORD_GUI')=='1' else None)
   page=await context.new_page();page.on('console',lambda m:logs.append(m.text));page.on('pageerror',lambda e:logs.append('PAGE ERROR '+str(e)))
   async def capture(name):await page.screenshot(path=str(FOLDER/(name+'.png')))
   async def visible(name,text,timeout=20,region=None):
    async def poll():
     while True:
      await capture(name)
      if text in (await asyncio.to_thread(h.ocr,name,region)).upper():return
      await page.wait_for_timeout(150)
    await asyncio.wait_for(poll(),timeout)
   async def click_text(name,text):await page.mouse.click(*h.text_center(name,text))
   await page.goto(url,wait_until='networkidle',timeout=45000);report['build_id']=await page.locator('#playtest-version').get_attribute('data-build-id')
   await visible('title','DEVELOPMENT DEMOS',45);await click_text('title','DEVELOPMENT DEMOS')
   await visible('development','MODULE LAB');await click_text('development','MODULE LAB');await visible('lab','MORE TRIALS')
   for index,(label,prefix) in enumerate([('THORN CELLS','cells'),('THORN WALL','wall'),('REMOTE BELL','remote'),('BELL FERRY','ferry'),('WINDKEEPER II','phase2'),('WINDKEEPER III','phase3')]):
    await page.mouse.click(1010,97);await visible(prefix+'-menu',label,region=(935,124,1095,292));await page.mouse.click(990,140+27*index);await page.wait_for_timeout(400);await capture(prefix+'-initial')
    report['checks'].append('Actual MORE TRIALS menu opens '+label)
    if prefix in ['remote','ferry']:
     await page.keyboard.down('d');await page.wait_for_timeout(420);await page.keyboard.up('d');await page.wait_for_timeout(150)
     await page.mouse.move(130,420);await page.mouse.down();await page.mouse.up();await page.wait_for_timeout(500)
     await capture(prefix+'-shot')
     sign=FOLDER/(prefix+'-shot-sign.png');h.picture(prefix+'-shot').crop((82,320,405,351)).resize((1292,124)).save(sign)
     result=await asyncio.to_thread(subprocess.run,['tesseract',str(sign),'stdout','--psm','7'],capture_output=True,text=True,timeout=8,env={**os.environ,'OMP_THREAD_LIMIT':'1'})
     text=result.stdout.upper();report[prefix+'_ocr']=text
     if prefix=='remote' and 'OPEN' not in text:raise RuntimeError('Remote shot did not visibly open linked door: '+text)
     if prefix=='ferry' and 'MOVING' not in text:raise RuntimeError('Ferry shot did not visibly start platform: '+text)
     report['checks'].append(prefix+' actual aimed projectile changes labelled mechanism')
    elif prefix.startswith('phase'):
     await page.keyboard.down('d');await page.wait_for_timeout(700);await page.keyboard.up('d')
     await visible(prefix+'-intro','WINDKEEPER',5);await page.wait_for_timeout(1500);await capture(prefix+'-form')
     report['checks'].append(prefix+' named intro and distinct painted form render')
   if any('SCRIPT ERROR' in s or 'PAGE ERROR' in s for s in logs):raise RuntimeError('Runtime error: '+str(logs))
   report['failed']=0;await context.close()
  finally:
   await browser.close();(FOLDER/'console.log').write_text('\n'.join(logs));(FOLDER/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps(report,ensure_ascii=False))
if __name__=='__main__':asyncio.run(asyncio.wait_for(main(sys.argv[1]),timeout=240))
