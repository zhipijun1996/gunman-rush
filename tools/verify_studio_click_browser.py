"""Actual mouse and CDP touch item selection, with screenshot-derived popup bounds."""
import asyncio,io,json,math,shutil,sys,time
from pathlib import Path
from PIL import Image
from studio_gui_pointer import weapon_row_y, select_weapon, open_weapon_picker, enter_action_studio
from playwright.async_api import async_playwright
IDS=['pulse_gun','shadow_shuriken','recoil_bomb','triple_machine_gun','sustained_laser','fan_shuriken','remote_boomerang','magnetic_mine','collapse_singularity','machine_storm','laser_cannon','blade_bloom','moon_boomerang','magnetic_storm','star_collapse']
OUT=Path('build/studio_input/browser');OUT.mkdir(parents=True,exist_ok=True)
async def main():
 events=[];errors=[];checks={}
 for part in ['report.json','events.json']:(OUT/part).unlink(missing_ok=True)
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path=shutil.which('chromium'),args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  for touch in [False,True]:
   name='touch'if touch else'desktop';w,h=(844,390)if touch else(1280,720);scale=min(w/1280,h/720);pad=(w-1280*scale)/2
   context=await browser.new_context(viewport={'width':w,'height':h},has_touch=touch,is_mobile=touch)
   page=await context.new_page()
   def log(m):
    s=m.text
    if 'STUDIO_EVENT 'in s:
     try:events.append({'context_device':name,**json.loads(s.split('STUDIO_EVENT ',1)[1])})
     except json.JSONDecodeError:errors.append('bad event JSON')
    if any(x in s for x in ['SCRIPT ERROR','Parse Error','ERROR:']):errors.append(s)
   page.on('console',log);page.on('pageerror',lambda e:errors.append(str(e)))
   await page.goto(sys.argv[1]if len(sys.argv)>1 else'http://127.0.0.1:8765',wait_until='networkidle');await page.wait_for_function('window.PLAYTEST_LOADING_DONE===true',timeout=60000);await page.wait_for_timeout(500)
   async def click(x,y):
    if touch:await page.touchscreen.tap(x,y)
    else:await page.mouse.click(x,y)
   await enter_action_studio(page,touch=touch,between_clicks_ms=300);await page.wait_for_timeout(800)
   async def wait(predicate):
    end=time.monotonic()+5
    while time.monotonic()<end:
     if predicate():return True
     await page.wait_for_timeout(100)
    return False
   for index in list(range(1,15))+[0]:
    n=len(events);await select_weapon(page,index,touch)
    accepted=await wait(lambda:any(e['context_device']==name and e['action']=='weapon_equipped'and e['weapon']==IDS[index]for e in events[n:]))
    checks[f'{name}_click_{IDS[index]}']=accepted
    await page.wait_for_timeout(100)
    count=sum(e['context_device']==name and e['action']=='weapon_equipped'and e['weapon']==IDS[index]for e in events[n:])
    print(name,index,count,flush=True)
    if count!=1:
     (OUT/'duplicate_events.json').write_text(json.dumps(events,indent=2));await page.screenshot(path=str(OUT/'duplicate_selection.png'))
     raise AssertionError(f'{name} {IDS[index]} equipment count {count}')
    if not accepted:
     await page.screenshot(path=str(OUT/f'{name}-selection-failed.png'));(OUT/'failed_events.json').write_text(json.dumps(events,indent=2));raise AssertionError(f'{name} pointer selection did not equip {IDS[index]}')
   await page.screenshot(path=str(OUT/f'{name}-all-selected.png'))
   n=len(events);await page.wait_for_timeout(1400)
   rows=[e for e in events[n:]if e['context_device']==name and e['action']=='training_motion'];
   if len(rows)<2:await wait(lambda:sum(e['context_device']==name and e['action']=='training_motion'for e in events[n:])>=2);rows=[e for e in events[n:]if e['context_device']==name and e['action']=='training_motion']
   checks[name+'_default_enemies_move']=len(rows)>=2 and all(math.dist(a,b)>3 for a,b in zip(rows[0]['detail']['positions'],rows[-1]['detail']['positions']))and not rows[-1]['detail']['static']
   y=await weapon_row_y(page);n=len(events);await click(pad+710*scale,y)
   checks[name+'_static_mode_accepted']=await wait(lambda:any(e['context_device']==name and e['action']=='training_mode'and e['detail']['static']for e in events[n:]))
   n=len(events);await wait(lambda:sum(e['context_device']==name and e['action']=='training_motion'for e in events[n:])>=2)
   rows=[e for e in events[n:]if e['context_device']==name and e['action']=='training_motion'];checks[name+'_static_enemies_stop']=len(rows)>=2 and all(math.dist(a,b)<.01 for a,b in zip(rows[0]['detail']['positions'],rows[-1]['detail']['positions']))
   await page.screenshot(path=str(OUT/f'{name}-stationary-targets.png'));y=await weapon_row_y(page);n=len(events);await click(pad+710*scale,y)
   checks[name+'_patrol_restored']=await wait(lambda:any(e['context_device']==name and e['action']=='training_mode'and not e['detail']['static']for e in events[n:]))
   n=len(events);x,rows=await open_weapon_picker(page,touch)
   if touch:
    session=await context.new_cdp_session(page)
    await session.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[{'id':20,'x':x,'y':rows[4]}]})
    await session.send('Input.dispatchTouchEvent',{'type':'touchCancel','touchPoints':[]})
   else:await click(pad+1100*scale,380*scale)
   await page.wait_for_timeout(300)
   checks[name+'_cancel_no_equip_or_shot']=not any(e['context_device']==name and e['action']in ['weapon_equipped','shot']for e in events[n:])
   await context.close()
  await browser.close()
 report={'checks':checks,'errors':errors,'failed':len(errors)+sum(not v for v in checks.values()),'scope':'all15 items each by real mouse/touch click, no keyboard item selection; actual read-only enemy position samples and native Motor tests; no engine state injection or physical-device acceptance'}
 (OUT/'events.json').write_text(json.dumps(events,ensure_ascii=False,indent=2)+'\n');(OUT/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False));raise SystemExit(bool(report['failed']))
asyncio.run(main())
