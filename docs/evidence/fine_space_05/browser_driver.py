import asyncio,json,shutil,sys,re
from pathlib import Path
sys.path.insert(0,'/workspace/gunman-art/tools')
from playwright.async_api import async_playwright
from verify_forest_browser import locate,fetch_identity,validate_region_heading
OUT=Path('/workspace/gunman-art/build/fine_space_05/browser');OUT.mkdir(exist_ok=True)
URL='http://127.0.0.1:8765/'
INFO=json.load(open('/workspace/gunman-art/build/web/build-info.json'))
async def main():
 report={'status':'failed','source_commit':INFO['source_commit'],'build_id':INFO['build_id'],'scope':'real local Web Home keyboard and mouse map1/map2/forest1 plus DOM touch map2 entry/pause; no full route or physical-device acceptance','checks':[],'events':[],'errors':[]}
 async with async_playwright() as p:
  b=await p.chromium.launch(executable_path=shutil.which('chromium'),headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  try:
   for case,region,index,touch in [('home',None,0,False),('plains1','plains',1,False),('plains2','plains',2,False),('forest1','thorn_forest',1,False),('touch_plains2','plains',2,True)]:
    c=await b.new_context(viewport={'width':1280,'height':720},has_touch=touch,is_mobile=touch)
    page=await c.new_page();logs=[]
    def log(m):
     t=m.text;logs.append(t)
     if 'FOREST_UI_EVENT ' in t:
      report['events'].append({'case':case,**json.loads(t.split('FOREST_UI_EVENT ',1)[1])})
     if any(x in t for x in ['ERROR:','SCRIPT ERROR','SHADER ERROR','Shader compilation failed','WebGL: INVALID_','CONTEXT_LOST']):report['errors'].append({'case':case,'error':t})
    page.on('console',log);page.on('pageerror',lambda e:report['errors'].append({'case':case,'error':str(e)}))
    if case=='home':report['identity']=await fetch_identity(c.request,URL,INFO['source_commit'],INFO['build_id'])
    await page.goto(URL,wait_until='networkidle',timeout=60000)
    await page.wait_for_function('window.PLAYTEST_LOADING_DONE===true',timeout=60000)
    await page.wait_for_timeout(350)
    assert await page.locator('#playtest-version').get_attribute('data-build-id')==INFO['build_id']
    async def snap(name):
     path=OUT/(case+'-'+name+'.png');await page.screenshot(path=str(path));return path
    async def click(text,name,scroll=False):
     for attempt in range(7 if scroll else 1):
      path=await snap(name+str(attempt))
      try:x,y=locate(path,text)
      except ValueError:
       if not scroll or attempt==6:raise
       await page.mouse.move(900,580);await page.mouse.wheel(0,230);await page.wait_for_timeout(180);continue
      if touch:await page.touchscreen.tap(x,y)
      else:await page.mouse.click(x,y)
      await page.wait_for_timeout(400);return
    if case=='home':
     await click('ENTER HOME','title',True);await page.wait_for_timeout(700);await snap('entered')
     await page.keyboard.down('d');await page.wait_for_timeout(450);await page.keyboard.press('Space');await page.wait_for_timeout(400);await page.keyboard.up('d');await snap('walk-jump')
     report['checks'].append('Home: actual rendered entry plus keyboard right and jump; screenshot observation, not full station traversal')
    else:
     await click('DEVELOPMENT DEMOS','title',True);await click('SELECT REGION','demos',True);await click(f'{region.upper()} MAP {index}','regions',True)
     for i in range(60):
      if any(e.get('case')==case and e.get('event')=='region_assembled' for e in report['events']):break
      await page.wait_for_timeout(250)
     events=[e for e in report['events'] if e.get('case')==case and e.get('event')=='region_assembled']
     assert len(events)==1 and events[0]['region']==region and events[0]['map_index']==index,events
     await page.wait_for_timeout(500);path=await snap('entered');validate_region_heading(path,region,index)
     await click('MENU','menu');await click('RESUME','pause');await snap('resumed')
     report['checks'].append(case+': exact real assembled map and complete HUD, actual click/tap pause/resume')
    (OUT/(case+'-console.log')).write_text('\n'.join(logs))
    await c.close()
   assert not report['errors'],report['errors']
   report['status']='passed'
  finally:
   (OUT/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');await b.close()
 print(json.dumps(report,ensure_ascii=False))
asyncio.run(main())
