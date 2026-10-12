"""D082 ordinary rendered practice input; phase entries are explicit fixtures, not earned progression."""
import asyncio,json,os,shutil,sys,subprocess
from pathlib import Path
from playwright.async_api import async_playwright
import verify_random_stage_browser as h
FOLDER=Path('build/verification/plains-cohesion-browser');h.FOLDER=FOLDER
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
   await visible('title','ENTER HOME',45);await click_text('title','ENTER HOME');await visible('home','NOTES',region=(0,0,520,70))
   await page.keyboard.down('Space');await page.wait_for_timeout(100);await page.keyboard.up('Space')
   await page.mouse.move(420,250);await page.mouse.down();await page.mouse.up();await page.wait_for_timeout(100)
   await capture('home-air-shot');home_text=(await asyncio.to_thread(h.ocr,'home-air-shot',(0,70,600,135))).upper()
   if 'ENERGY' not in home_text or '100/100' in home_text:raise RuntimeError('Home real shot did not visibly spend common energy: '+home_text)
   report['checks'].append('Actual Home keyboard jump input and visibly energy-consuming aimed projectile use common controls')
   await page.reload(wait_until='networkidle',timeout=45000);await visible('title','DEVELOPMENT DEMOS',45);await click_text('title','DEVELOPMENT DEMOS')
   await visible('development','MODULE LAB');await click_text('development','MODULE LAB');await visible('lab','MORE TRIALS')
   for index,(label,prefix) in enumerate([('THORN CELLS','cells'),('THORN WALL','wall'),('REMOTE BELL','remote'),('BELL FERRY','ferry'),('WINDKEEPER II','phase2'),('WINDKEEPER III','phase3'),('THORN SLALOM','slalom'),('REMOTE CHAIN','chain')]):
    await page.mouse.click(1010,97);await visible(prefix+'-menu',label,region=(935,124,1110,360));await page.mouse.click(990,140+27*index);await page.wait_for_timeout(400);await capture(prefix+'-initial')
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
     if prefix=='ferry':
      # Ordinary movement keeps the shooting stance inside the safe bank.
      await page.keyboard.down('a');await page.wait_for_timeout(180);await page.keyboard.up('a');await page.wait_for_timeout(200)
      for action,expected in [('park','PARKED'),('resume','MOVING')]:
       await page.mouse.move(130,420);await page.mouse.down();await page.mouse.up();await page.wait_for_timeout(500)
       name='ferry-'+action;await capture(name);sign=FOLDER/(name+'-sign.png')
       h.picture(name).crop((82,320,405,351)).resize((1292,124)).save(sign)
       result=await asyncio.to_thread(subprocess.run,['tesseract',str(sign),'stdout','--psm','7'],capture_output=True,text=True,timeout=8,env={**os.environ,'OMP_THREAD_LIMIT':'1'})
       report[name+'_ocr']=result.stdout.upper()
       if expected not in result.stdout.upper():raise RuntimeError('Actual ferry '+action+' not rendered: '+result.stdout)
       report['checks'].append('Actual ferry shot '+action+' changes labelled motion state')
    elif prefix=='chain':
     await page.keyboard.down('d');await page.wait_for_timeout(310);await page.keyboard.up('d');await page.wait_for_timeout(150)
     await page.mouse.move(100,420);await page.mouse.down();await page.mouse.up();await page.wait_for_timeout(500)
     await capture('chain-first-shot')
     text=(await asyncio.to_thread(h.ocr,'chain-first-shot')).upper()
     if 'CLIMB' not in text or 'RING 2' not in text:raise RuntimeError('Remote first shot did not visibly open path and show second objective: '+text)
     report['checks'].append('Actual remote first projectile opens navigation path and labels distant second ring')
    elif prefix.startswith('phase'):
     await page.keyboard.down('d');await page.wait_for_timeout(700);await page.keyboard.up('d')
     await visible(prefix+'-nameplate','PHASE '+('2' if prefix=='phase2' else '3'),8,region=(130,225,1000,285));await page.wait_for_timeout(1500);await capture(prefix+'-form')
     report['checks'].append(prefix+' actual phase nameplate and distinct painted form render')
   if any('SCRIPT ERROR' in s or 'PAGE ERROR' in s for s in logs):raise RuntimeError('Runtime error: '+str(logs))
   report['failed']=0;await context.close()
  finally:
   await browser.close();(FOLDER/'console.log').write_text('\n'.join(logs));(FOLDER/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps(report,ensure_ascii=False))
if __name__=='__main__':asyncio.run(asyncio.wait_for(main(sys.argv[1]),timeout=240))
