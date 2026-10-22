import sys,asyncio,json,time,re,shutil
from pathlib import Path
sys.path.insert(0,'/workspace/gunman-rush/tools')
from verify_forest_browser import async_playwright,environment_proxy,fetch_identity,locate,validate_region_heading
OUT=Path('/tmp/gunman-forest-variety-03/restored-public');OUT.mkdir(exist_ok=False)
URL='https://zhipijun1996.github.io/gunman-rush/?v=12ac19e2ec02';COMMIT='bbf5b24dc6a27374119f67f11fc2eed92a57ba00';BUILD='12ac19e2ec02'
async def main():
 r={'scope':'Restored old v15 public package: full PCK identity, actual mouse forest map1 entry and pause/resume only; no new v17 coverage','url':URL,'status':'failed','events':[],'errors':[]};start=time.monotonic()
 async with async_playwright() as p:
  proxy,_=environment_proxy();browser=await p.chromium.launch(executable_path=shutil.which('chromium'),headless=True,proxy=proxy,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  try:
   c=await browser.new_context(viewport={'width':1280,'height':720});page=await c.new_page()
   def console(m):
    if 'FOREST_UI_EVENT ' in m.text:r['events'].append(json.loads(m.text.split('FOREST_UI_EVENT ',1)[1]))
    if any(x in m.text for x in ['SCRIPT ERROR:','Parse Error:','SHADER ERROR:']):r['errors'].append(m.text)
   page.on('console',console);page.on('pageerror',lambda e:r['errors'].append(str(e)))
   r['identity']=await fetch_identity(c.request,URL,COMMIT,BUILD)
   response=await page.goto(URL,wait_until='networkidle',timeout=60000)
   assert response.ok
   config=json.loads(re.search(r'const GODOT_CONFIG = (\{[^\n]+\});',await response.text())[1]);assert config['mainPack']==r['identity']['pack']
   await page.wait_for_function('window.PLAYTEST_LOADING_DONE===true',timeout=60000);await page.wait_for_timeout(500)
   assert await page.locator('#playtest-version').get_attribute('data-build-id')==BUILD
   async def click(phrase,name,scroll=False):
    for i in range(9 if scroll else 1):
     path=OUT/f'{name}-{i}.png';await page.screenshot(path=str(path))
     try:point=locate(path,phrase)
     except ValueError:
      if not scroll:raise
      await page.mouse.move(900,580);await page.mouse.wheel(0,230);await page.wait_for_timeout(200);continue
     await page.mouse.click(*point);await page.wait_for_timeout(400);return
    raise RuntimeError('No rendered control '+phrase)
   await click('DEVELOPMENT DEMOS','title',True);await click('SELECT REGION','home',True);await click('THORN_FOREST MAP 1','select')
   await page.wait_for_timeout(900);path=OUT/'forest-entry.png';await page.screenshot(path=str(path));validate_region_heading(path,'thorn_forest',1)
   assembled=[e for e in r['events'] if e.get('event')=='region_assembled'];assert len(assembled)==1 and assembled[0]['layout_version']=='forest-bible-world-v15' and assembled[0]['map_index']==1 and assembled[0]['abilities']==['grapple']
   await click('MENU','menu');await click('RESUME','resume');await page.screenshot(path=str(OUT/'resumed.png'))
   assert not r['errors'];r['status']='passed'
  except BaseException as e:r['error']=str(e);raise
  finally:
   r['seconds']=time.monotonic()-start;(OUT/'report.json').write_text(json.dumps(r,ensure_ascii=False,indent=2));await browser.close();print(json.dumps(r,ensure_ascii=False))
asyncio.run(asyncio.wait_for(main(),180))
