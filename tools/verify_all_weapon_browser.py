"""Actual canvas GUI / keyboard / CDP touch, read-only accepted-event evidence."""
import asyncio,json,shutil,sys,time
from pathlib import Path
from playwright.async_api import async_playwright
from studio_gui_pointer import select_weapon, weapon_row_y, enter_action_studio
out=Path('build/weapons/browser');out.mkdir(parents=True,exist_ok=True)
async def main():
 events=[];errors=[];checks={}
 async with async_playwright() as p:
  b=await p.chromium.launch(executable_path=shutil.which('chromium'),args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  async def launch(touch=False):
   c=await b.new_context(viewport={'width':844 if touch else 1280,'height':390 if touch else 720},has_touch=touch,is_mobile=touch)
   page=await c.new_page()
   def log(m):
    s=m.text
    if 'STUDIO_EVENT 'in s:
     try:events.append(json.loads(s.split('STUDIO_EVENT ',1)[1]))
     except json.JSONDecodeError:errors.append('bad event JSON')
    if any(x in s for x in ['SCRIPT ERROR','Parse Error','ERROR:']):errors.append(s)
   page.on('console',log);page.on('pageerror',lambda e:errors.append(str(e)))
   await page.goto(sys.argv[1] if len(sys.argv)>1 else 'http://127.0.0.1:8765',wait_until='networkidle')
   await page.wait_for_function('window.PLAYTEST_LOADING_DONE === true',timeout=60000);await page.wait_for_timeout(400)
   await enter_action_studio(page,touch=touch,between_clicks_ms=250)
   await page.wait_for_timeout(700)
   return c,page
  c,page=await launch()
  # Controlled-weapon cases use the explicitly selectable stationary target mode.
  await page.mouse.click(710,150);await page.wait_for_timeout(250)
  assert any(e['action']=='training_mode'and e['detail'].get('static')for e in events), 'stationary target mode was not accepted'
  async def wait_event(predicate,timeout=5):
   end=time.monotonic()+timeout
   while time.monotonic()<end:
    if predicate():return True
    await page.wait_for_timeout(100)
   return False
  async def choose(index):
   expected=['pulse_gun','shadow_shuriken','recoil_bomb','triple_machine_gun','sustained_laser','fan_shuriken','remote_boomerang','magnetic_mine','collapse_singularity','machine_storm'][index]
   n=len(events);await select_weapon(page,index)
   assert await wait_event(lambda:any(e['action']=='weapon_equipped'and e['weapon']==expected for e in events[n:])),f'GUI selected wrong loadout for {expected}'
   await page.mouse.click(330,await weapon_row_y(page));await page.wait_for_timeout(220)
   assert any(e['action']=='practice_reset'and e['weapon']==expected for e in events[-8:]),f'GUI did not reset {expected}'
  await choose(4);n=len(events);await page.mouse.move(790,510);await page.mouse.down();await page.wait_for_timeout(450);await page.screenshot(path=str(out/'desktop-laser-held.png'));await page.mouse.up();await page.wait_for_timeout(220)
  phases=[e['detail'].get('phase') for e in events[n:] if e['action']=='weapon_phase' and e['weapon']=='sustained_laser'];checks['desktop_laser_hold_release']='beam'in phases and phases[-1:] == ['idle']
  await choose(6);n=len(events);await page.mouse.move(790,510);await page.mouse.down();await page.wait_for_timeout(60);await page.mouse.up();await page.wait_for_timeout(450);await page.screenshot(path=str(out/'desktop-controlled-blade.png'));await page.keyboard.press('f');await page.wait_for_timeout(450)
  rows=[e for e in events[n:] if e['action']=='weapon_entity_transition' and e['weapon']=='remote_boomerang'];checks['desktop_blade_recall_catch']=any(e['detail']['state']=='returning'for e in rows)and any(e['detail']['state']=='caught'and abs(e['recoil_speed']-(84.7*.5/.14))<1 for e in rows)
  await choose(7);n=len(events);await page.mouse.move(790,510);await page.mouse.down();await page.wait_for_timeout(60);await page.mouse.up();await page.wait_for_timeout(430);await page.keyboard.press('f');await page.wait_for_timeout(180);await page.screenshot(path=str(out/'desktop-mine-trigger.png'))
  rows=[e for e in events[n:] if e['action']=='weapon_entities'and e['weapon']=='magnetic_mine'];checks['desktop_mine_attach_trigger']=any(any(x['phase']=='attached'for x in e['detail']['entities'])for e in rows)and any(not e['detail']['entities']for e in rows)
  await choose(8);n=len(events);await page.mouse.move(790,420);await page.mouse.down();await page.wait_for_timeout(50);await page.mouse.up();await wait_event(lambda:any(e['action']=='weapon_phase'and e['weapon']=='collapse_singularity'and e['detail'].get('phase')=='idle'for e in events[n:]))
  phases=[e['detail'].get('phase')for e in events[n:]if e['action']=='weapon_phase'and e['weapon']=='collapse_singularity'];checks['desktop_singularity_cycle']='singularity'in phases and phases[-1:]==['idle']
  await choose(9);n=len(events);await page.keyboard.press('q');await page.wait_for_timeout(120);checks['insufficient_skill_does_not_start']=any(e['action']=='attack_rejected'and e['detail'].get('reason')=='combat_energy'for e in events[n:])and not any(e['action']=='weapon_phase'and e['detail'].get('phase')=='charge'for e in events[n:])
  await page.screenshot(path=str(out/'desktop-lv3-controls.png'));await c.close()
  c,page=await launch(True);session=await c.new_cdp_session(page)
  async def touch(kind,points):await session.send('Input.dispatchTouchEvent',{'type':kind,'touchPoints':[{'id':i,'x':x,'y':y}for i,x,y in points]})
  # Upward hook from the public practice checkpoint to the overhead anchor.
  await page.touchscreen.tap(350,54);await page.wait_for_timeout(300);n=len(events)
  await touch('touchStart',[(3,694,232)]);await touch('touchMove',[(3,694,192)]);await page.wait_for_timeout(70);await touch('touchEnd',[]);await page.wait_for_timeout(700);await page.screenshot(path=str(out/'touch-upward-hook.png'))
  rows=[e for e in events[n:]if e['action']=='hook_pull'];checks['touch_360_upward_hook']=bool(rows)and any(e['position'][1]<350 for e in events[n:]if e['action']=='hook_kick')
  # Skill touch area exists for an actual Lv3 selection. Popup selection uses actual pointer input.
  n=len(events);await select_weapon(page,9,True);await page.wait_for_timeout(180);await page.screenshot(path=str(out/'touch-lv3-controls.png'));checks['touch_lv3_selected']=any(e['action']=='weapon_equipped'and e['weapon']=='machine_storm'for e in events[n:]);n=len(events)
  await touch('touchStart',[(4,694,168)]);await touch('touchMove',[(4,727,168)]);await touch('touchEnd',[]);await page.wait_for_timeout(180)
  checks['touch_insufficient_skill_does_not_shoot']=any(e['action']=='attack_rejected'and e['detail'].get('reason')=='combat_energy'for e in events[n:])and not any(e['action']=='shot'or (e['action']=='weapon_phase'and e['detail'].get('phase')=='charge')for e in events[n:])
  await c.close();await b.close()
 report={'checks':checks,'errors':errors,'failed':len(errors)+sum(not v for v in checks.values()),'scope':'actual GUI/keyboard/CDP touchscreen; accepted-event logs are read-only; no engine-state injection, physical device or subjective acceptance'}
 (out/'events.json').write_text(json.dumps(events,ensure_ascii=False,indent=2)+'\n');(out/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False));raise SystemExit(bool(report['failed']))
asyncio.run(main())
