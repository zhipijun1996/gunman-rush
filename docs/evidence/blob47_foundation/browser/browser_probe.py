import asyncio, csv, io, json, subprocess
from pathlib import Path
from PIL import Image
from playwright.async_api import async_playwright
OUT=Path('build/blob47-browser/final'); OUT.mkdir(parents=True,exist_ok=True)
URL='http://127.0.0.1:8766/'
def words(path):
 result=subprocess.run(['tesseract',str(path),'stdout','tsv'],capture_output=True,text=True,check=True)
 return list(csv.DictReader(io.StringIO(result.stdout),delimiter='\t'))
def contains(path,phrase):
 return phrase.upper() in ' '.join(r['text'] for r in words(path)).upper()
async def main():
 report={'scope':'Actual Chromium WebGL GUI on frozen source; candidate only','checks':{},'status':'failed'}; logs=[]
 async with async_playwright() as p:
  b=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  c=await b.new_context(viewport={'width':1280,'height':720},record_video_dir=str(OUT/'video'))
  page=await c.new_page();page.on('console',lambda m:logs.append(m.text));page.on('pageerror',lambda e:logs.append('PAGE ERROR '+str(e)))
  async def snap(name):
   path=OUT/(name+'.png');await page.screenshot(path=str(path));return path
  try:
   await page.goto(URL+'?foundation=1',wait_until='networkidle',timeout=60000)
   await page.wait_for_function('window.PLAYTEST_LOADING_DONE === true',timeout=60000)
   await page.wait_for_timeout(1500)
   report['build_id']=await page.locator('#playtest-version').get_attribute('data-build-id')
   assert report['build_id']=='45c1a10f8767'
   img=await snap('01-playable');assert contains(img,'NEW ART FOUNDATION');report['checks']['direct_entry']=True
   await page.mouse.click(212,90);await page.wait_for_timeout(250)
   img=await snap('02-catalog');assert contains(img,'canonical masks');report['checks']['catalog_visible']=True
   await page.mouse.click(52,90);await page.wait_for_timeout(250)
   img=await snap('03-restart');assert not contains(img,'canonical masks');report['checks']['restart_dismisses_catalog']=True
   await page.mouse.click(212,90);await page.wait_for_timeout(150);await page.mouse.click(128,90);await page.wait_for_timeout(350)
   img=await snap('04-new-seed');assert contains(img,'foundation-02') and not contains(img,'canonical masks');report['checks']['seed_dismisses_catalog']=True
   await page.mouse.click(322,90);await page.wait_for_timeout(200);await snap('05-decoration-off');await page.mouse.click(322,90)
   await page.mouse.click(382,90);await page.wait_for_timeout(200);await snap('06-depth-off');await page.mouse.click(382,90)
   await page.mouse.click(434,90);await page.wait_for_timeout(200);await snap('07-light-off');await page.mouse.click(434,90)
   report['checks']['layer_controls_clicked']=True
   await page.keyboard.down('d');await page.wait_for_timeout(900)
   for i in range(4):
    await page.keyboard.down('Space');await page.wait_for_timeout(130);await page.keyboard.up('Space');await page.wait_for_timeout(650)
   await page.keyboard.up('d');await page.wait_for_timeout(300)
   await snap('08-moving-camera');report['checks']['real_keyboard_move_jump']=True
   await page.mouse.click(550,90);await page.wait_for_timeout(700)
   # Return to ordinary title, then enter through the new menu button rather
   # than relying exclusively on the query parameter.
   await page.goto(URL,wait_until='networkidle',timeout=60000)
   await page.wait_for_function('window.PLAYTEST_LOADING_DONE === true',timeout=60000);await page.wait_for_timeout(700)
   title=await snap('09-title-entry');rows=words(title)
   found=next(r for r in rows if 'FOUNDATION' in r['text'].upper())
   await page.mouse.click(int(found['left'])+int(found['width'])/2,int(found['top'])+int(found['height'])/2)
   await page.wait_for_timeout(700);img=await snap('10-menu-entered');assert contains(img,'TILE GARDEN');report['checks']['ordinary_title_menu_entry']=True
   bad=[m for m in logs if any(s in m for s in ['SCRIPT ERROR','SHADER ERROR','PAGE ERROR','WebGL: INVALID_','WebGL: CONTEXT_LOST','ERROR:'])]
   assert not bad,bad
   report['status']='passed';report['limitations']=['Software WebGL, not physical device performance','No full campaign, enemy golden or user visual acceptance','Screenshots and video show candidate study only']
  finally:
   (OUT/'console.log').write_text('\n'.join(logs));(OUT/'report.json').write_text(json.dumps(report,indent=2));await c.close();await b.close()
 print(json.dumps(report))
asyncio.run(main())
