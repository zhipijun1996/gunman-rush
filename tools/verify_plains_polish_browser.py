"""Bounded rendered GUI check of PR33 Home and the polished plains.
Ordinary keyboard/touch only. Seeded 9-note browser save is a purchase fixture,
not evidence of earning notes. Optional first positional argument is a URL.
"""
import asyncio,json,re,shutil,subprocess,sys
from pathlib import Path
from playwright.async_api import async_playwright
from PIL import ImageChops
import verify_random_stage_browser as h
from verify_plains_ten_browser import storage_fixture,WEB_KEY
FOLDER=Path('build/verification/plains-polish-browser')
h.FOLDER=FOLDER
async def main(url,touch_probe=None):
 FOLDER.mkdir(parents=True,exist_ok=True)
 report={'url':url,'failed':1,'checks':[],'scope':'Real GUI Home purchase, reload, departure and first-room movement only','device':'Chromium mobile touch emulation; real Android and iPhone unverified','storage_fixture':'9 notes installed once in isolated profile; not earned through gameplay'}
 logs=[]
 async with async_playwright() as p:
  b=await p.chromium.launch(executable_path=shutil.which('chromium') or shutil.which('chromium-browser'),headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'],timeout=30000)
  try:
   c=await b.new_context(viewport={'width':1280,'height':720},has_touch=True,is_mobile=True)
   await c.add_init_script('if(localStorage.getItem(%s)===null)localStorage.setItem(%s,%s);'%(json.dumps(WEB_KEY),json.dumps(WEB_KEY),json.dumps(storage_fixture())))
   pg=await c.new_page();pg.on('console',lambda m:logs.append(m.text));pg.on('pageerror',lambda e:logs.append('PAGE ERROR: '+str(e)))
   async def capture(name):
    await pg.screenshot(path=str(FOLDER/(name+'.png')),timeout=10000)
   async def hold(key,ms):
    await pg.keyboard.down(key);await pg.wait_for_timeout(ms);await pg.keyboard.up(key);await pg.wait_for_timeout(150)
   async def approach(label,name,max_steps=18):
    # Drive to an observed interaction prompt, not a wall-clock position:
    # software-rendered browser frame rates vary across reloads.
    for attempt in range(max_steps):
     await capture(name)
     prompt=(await asyncio.to_thread(h.ocr,name,(300,540,1050,620))).upper()
     if label in prompt:return prompt
     await hold('d',180)
    raise RuntimeError('Real Home walk never reached '+label+' after bounded input: '+prompt)
   async def visible(name,predicate,region=None,budget=10):
    async def poll():
     while True:
      await capture(name)
      text=(await asyncio.to_thread(h.ocr,name,region)).upper()
      if predicate(text):return text
      await pg.wait_for_timeout(150)
    try:return await asyncio.wait_for(poll(),timeout=budget)
    except asyncio.TimeoutError:raise RuntimeError('Actual visual state not ready within %ss: '%budget+name)
   async def enter_home(name):
    # networkidle means downloads settled, not that Godot has drawn its UI.
    await visible(name,lambda t:'ENTER HOME' in t,(254,418,1018,463),45)
    await pg.touchscreen.tap(*h.text_center(name,'ENTER HOME'))
    await visible(name+'-home-ready',lambda t:'NOTES' in t,(319,29,437,59),10)
   await pg.goto(url,wait_until='networkidle',timeout=45000)
   report['build_id']=await pg.locator('#playtest-version').get_attribute('data-build-id')
   await enter_home('title');await capture('home-initial')
   top=h.ocr('home-initial',(319,29,437,59)).upper();report['home_initial_ocr']=top
   if 'NOTES 9' not in top:raise RuntimeError('Home fixture not shown: '+top)
   report['checks'].append('Rendered Title enters real Home with separately seeded 9-note profile')
   prompt=await asyncio.wait_for(approach('ARTISAN','artisan-approach'),timeout=30);report['artisan_prompt']=prompt
   if 'ARTISAN' not in prompt:raise RuntimeError('Real Motor walking did not reach artisan: '+prompt)
   await pg.keyboard.press('w');await visible('upgrade-panel',lambda t:'CLOCKWORK ARTISAN' in t)
   if 'CLOCKWORK ARTISAN' not in h.ocr('upgrade-panel').upper():raise RuntimeError('Actual NPC interaction did not open upgrade panel')
   await pg.touchscreen.tap(*h.text_center('upgrade-panel','SPEND NOTES'));await visible('purchased-upgrade',lambda t:'NOTES 4' in t and 'VITALITY 1' in t)
   text=h.ocr('purchased-upgrade').upper()
   if 'NOTES 4' not in text or 'VITALITY 1' not in text:raise RuntimeError('Actual upgrade did not spend 5 fixture notes: '+text)
   report['checks'].append('Actual Home locomotion and NPC interaction open panel; real button buys vitality 1 for 5 fixture notes')
   await pg.reload(wait_until='networkidle',timeout=45000);await enter_home('reload-title')
   report['reload_artisan_prompt']=await asyncio.wait_for(approach('ARTISAN','reload-artisan-approach'),timeout=30)
   await pg.keyboard.press('w');await visible('reloaded-upgrade',lambda t:'CLOCKWORK ARTISAN' in t)
   text=h.ocr('reloaded-upgrade').upper()
   if 'NOTES 4' not in text or 'VITALITY 1' not in text:raise RuntimeError('Reloaded actual artisan panel did not show persisted purchase: '+text)
   if await pg.locator('#playtest-version').get_attribute('data-build-id')!=report['build_id']:raise RuntimeError('Reload changed build')
   report['checks'].append('Actual reload retains game-written 4 notes and vitality 1 in same package')
   await pg.touchscreen.tap(*h.text_center('reloaded-upgrade','BACK TO HOME'));await pg.wait_for_timeout(150)
   prompt=await asyncio.wait_for(approach('PLAINS','gate-approach'),timeout=30);report['gate_prompt']=prompt
   if 'PLAINS' not in prompt:raise RuntimeError('Real Home walking did not reach gate: '+prompt)
   await pg.keyboard.press('w');await visible('departure-panel',lambda t:'THE PLAINS AWAIT' in t)
   await pg.touchscreen.tap(*h.text_center('departure-panel','WINDCHIME PLAINS'));await visible('room-entry',lambda t:'ROOM 1 OF 8' in t,(0,0,1100,220))
   text=h.ocr('room-entry',(0,0,1100,220)).upper();report['room_entry_ocr']=text
   if 'ROOM 1 OF 8' not in text:raise RuntimeError('Departure did not enter formal room 1/8: '+text)
   report['checks'].append('Real Home departure gate starts formal generated plains room 1/8')
   if touch_probe is not None:
    await touch_probe(pg,c,capture,report)
   # Physical movement and normal jump: screenshots serve as observations of
   # grayscale far scenery, magnification and event-driven dust, not subjective
   # approval or proof of all generated layouts.
   await hold('d',600);await capture('room-moved')
   await pg.keyboard.down('d');await pg.keyboard.down('Space');await pg.wait_for_timeout(100);await pg.keyboard.up('Space');await capture('room-jump');await pg.keyboard.up('d')
   diff=ImageChops.difference(h.picture('room-entry').crop((0,240,1280,630)),h.picture('room-moved').crop((0,240,1280,630)))
   if not diff.getbbox():raise RuntimeError('Ordinary movement did not change rendered world')
   report['checks'].append('Ordinary keyboard movement and short jump produce visibly changing world; before/after captures retained')
   jump_text=h.ocr('room-jump',(15,40,600,68)).upper()
   earned=re.search(r'NOTES\s+(\d+)',jump_text)
   report['actual_note_pickup_ocr']=jump_text
   if earned and int(earned[1])>4:
    earned_notes=int(earned[1]);report['actual_earned_notes']=earned_notes
    report['checks'].append('Ordinary gameplay walk/short jump visibly increases notes beyond the post-purchase 4')
    await pg.keyboard.press('Escape')
    await visible('earned-note-pause',lambda t:'RETURN TO HOME' in t)
    await pg.touchscreen.tap(*h.text_center('earned-note-pause','RETURN TO HOME'))
    await visible('earned-note-confirm',lambda t:'LEAVE RUN' in t)
    await pg.touchscreen.tap(*h.text_center('earned-note-confirm','LEAVE RUN'))
    await visible('home-earned-note',lambda t:'NOTES %s'%earned_notes in t,(319,29,437,59))
    await pg.reload(wait_until='networkidle',timeout=45000)
    await enter_home('earned-note-reload-title')
    await visible('reloaded-earned-note-home',lambda t:'NOTES %s'%earned_notes in t,(319,29,437,59))
    if await pg.locator('#playtest-version').get_attribute('data-build-id')!=report['build_id']:raise RuntimeError('Earned-note reload changed package')
    report['checks'].append('Confirmed return Home and real reload retain actually earned notes in same package')
   else:
    report['earned_note_reload']='unverified: this ordinary movement did not visibly increase notes'

   if any(x in line for line in logs for x in ['SCRIPT ERROR:','PAGE ERROR:','Parse Error:','SHADER ERROR:']):raise RuntimeError('Engine/browser errors: '+str(logs))
   report['checks'].append('No browser, script or shader errors during actual GUI path')
   report['failed']=0
  except Exception as e:
   report['error']=str(e);raise
  finally:
   report['logs']=logs;(FOLDER/'browser-report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report));await b.close()
if __name__=='__main__':
 target=sys.argv[1] if len(sys.argv)>1 else 'http://127.0.0.1:8778/'
 server=None
 if len(sys.argv)==1:
  server=subprocess.Popen([sys.executable,'-m','http.server','8778','--bind','127.0.0.1','--directory','build/web'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 try:asyncio.run(asyncio.wait_for(main(target),timeout=240))
 finally:
  if server:server.terminate();server.wait(timeout=5)
