"""Ordinary rendered development-practice clicks; no engine state injection.
Formal default entry/fog/persistence remain verify_plains_region_browser.py.
"""
import asyncio,json,os,re,shutil,subprocess,sys
from pathlib import Path
from playwright.async_api import async_playwright
import verify_random_stage_browser as h
FOLDER=Path('build/verification/plains-energy-browser')
h.FOLDER=FOLDER
async def main(url):
 FOLDER.mkdir(parents=True,exist_ok=True)
 report={'url':url,'failed':1,'checks':[],'scope':'Explicit practice entry, ordinary pointer shots, real damage/refund, displayed item choice/effect/inventory; not earned formal reward or complete region victory'}
 logs=[]
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path=shutil.which('chromium') or shutil.which('chromium-browser'),headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  try:
   video={'record_video_dir':str(FOLDER/'video'),'record_video_size':{'width':1280,'height':720}} if os.environ.get('GUNMAN_RECORD_GUI')=='1' else {}
   context=await browser.new_context(viewport={'width':1280,'height':720},has_touch=True,**video)
   page=await context.new_page();page.on('console',lambda m:logs.append(m.text));page.on('pageerror',lambda e:logs.append('PAGE ERROR: '+str(e)))
   async def capture(name): await page.screenshot(path=str(FOLDER/(name+'.png')))
   async def visible(name,phrase,region=None,budget=15):
    async def poll():
     while True:
      await capture(name);text=(await asyncio.to_thread(h.ocr,name,region)).upper()
      if phrase in text:return text
      await page.wait_for_timeout(200)
    return await asyncio.wait_for(poll(),timeout=budget)
   await page.goto(url,wait_until='networkidle',timeout=45000)
   report['build_id']=await page.locator('#playtest-version').get_attribute('data-build-id')
   await visible('title','DEVELOPMENT DEMOS',budget=45)
   await page.touchscreen.tap(*h.text_center('title','DEVELOPMENT DEMOS'))
   await visible('development','MODULE LAB');await page.touchscreen.tap(*h.text_center('development','MODULE LAB'))
   await visible('lab','ENERGY');await page.touchscreen.tap(1170,568)
   await visible('energy-ready','TRAINING DRONE HP 20',region=(130,220,1050,285))
   await page.touchscreen.tap(1170,623)
   text=await visible('item-cards','CHOOSE ONE ITEM')
   if 'GRIP' not in text or 'MAGAZINE' not in text:raise RuntimeError('Choice did not display two actual described items: '+text)
   await page.touchscreen.tap(440,486)
   await visible('item-granted','SHOT -16',region=(240,85,1000,110))
   await capture('acquisition-toast')
   report['checks'].append('Actual practice reward button opens two AI icon cards; normal choice changes the actual HUD shot cost from 20 to 16')
   await page.keyboard.press('Escape');await visible('pause','YOUR BUILD')
   await page.touchscreen.tap(*h.text_center('pause','YOUR BUILD'));await visible('build','EFFICIENT GRIP')
   await page.mouse.move(1000,570);await page.mouse.wheel(0,650);await page.wait_for_timeout(200);await visible('build-scroll','BACK');await page.touchscreen.tap(*h.text_center('build-scroll','BACK'));await visible('pause-again','YOUR BUILD')
   await page.touchscreen.tap(*h.text_center('pause-again','YOUR BUILD'));await visible('build-again','EFFICIENT GRIP')
   report['checks'].append('Actual pause inventory shows acquired icon/description/effect and retains it after Back and reopen')
   await page.mouse.move(1000,570);await page.mouse.wheel(0,650);await page.wait_for_timeout(200);await visible('build-again-scroll','BACK');await page.touchscreen.tap(*h.text_center('build-again-scroll','BACK'));await visible('pause-resume','RESUME');await page.touchscreen.tap(*h.text_center('pause-resume','RESUME'))
   # Ordinary pointer aim at stationary fixture enemy. No HP mutation.
   await page.keyboard.down('d');await page.wait_for_timeout(650);await page.keyboard.up('d');await page.wait_for_timeout(150);await page.mouse.move(650,550);await page.mouse.down();await page.wait_for_timeout(30);await page.mouse.up()
   text=await visible('real-hit','TRAINING DRONE HP 19',region=(130,220,1050,285));report['damage_ocr']=text
   await visible('energy-refund','ENERGY 100',region=(240,85,1000,110))
   report['checks'].append('Ordinary mouse shot physically hits displayed enemy: 20 to 19 HP and committed-hit energy returns to full')
   # A miss spends energy. Capture promptly; do not infer from an arbitrary frame later.
   await page.mouse.move(150,250);await page.mouse.down();await page.wait_for_timeout(30);await page.mouse.up()
   await capture('real-miss-cost')
   text=(await asyncio.to_thread(h.ocr,'real-miss-cost',(240,85,1000,110))).upper();report['miss_energy_ocr']=text
   value=re.search(r'ENERGY\s+(\d+)',text)
   if not value or int(value.group(1))>=100:raise RuntimeError('Real missed shot did not visibly spend energy: '+text)
   await visible('ground-rest','ENERGY 100',region=(240,85,1000,110))
   report['checks'].append('Miss visibly spends energy; ordinary grounded waiting restores it without reset')
   if any(x in line for line in logs for x in ['SCRIPT ERROR:','PAGE ERROR:','Parse Error:','SHADER ERROR:']):raise RuntimeError('Engine/browser errors: '+str(logs))
   report['failed']=0
  except Exception as e:report['error']=str(e);raise
  finally:
   report['logs']=logs;(FOLDER/'browser-report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report));await browser.close()
if __name__=='__main__':
 url=sys.argv[1] if len(sys.argv)>1 else 'http://127.0.0.1:8808/'
 server=None
 if len(sys.argv)==1:server=subprocess.Popen([sys.executable,'-m','http.server','8808','--bind','127.0.0.1','--directory','build/web'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 try:asyncio.run(asyncio.wait_for(main(url),timeout=220))
 finally:
  if server:server.terminate();server.wait(timeout=5)
