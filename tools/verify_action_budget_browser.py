"""Real canvas weapon inputs; readonly accepted-event evidence, no gameplay injection."""
import asyncio,json,math,shutil,sys,time
from pathlib import Path
from playwright.async_api import async_playwright
from studio_gui_pointer import select_weapon,weapon_row_y
OUT=Path('build/action_budget/browser');OUT.mkdir(parents=True,exist_ok=True)
async def main():
 events=[];errors=[];checks={}
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path=shutil.which('chromium'),args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  context=await browser.new_context(viewport={'width':1280,'height':720})
  page=await context.new_page()
  def log(m):
   if 'STUDIO_EVENT 'in m.text:
    try:events.append(json.loads(m.text.split('STUDIO_EVENT ',1)[1]))
    except json.JSONDecodeError:errors.append(m.text)
   if any(x in m.text for x in ['SCRIPT ERROR','Parse Error','ERROR:']):errors.append(m.text)
  page.on('console',log);page.on('pageerror',lambda e:errors.append(str(e)))
  await page.goto(sys.argv[1]if len(sys.argv)>1 else'http://127.0.0.1:8765',wait_until='networkidle')
  await page.wait_for_function('window.PLAYTEST_LOADING_DONE===true',timeout=60000)
  await page.wait_for_timeout(600);await page.mouse.click(640,500);await page.wait_for_timeout(300);await page.mouse.click(335,285);await page.wait_for_timeout(600)
  await page.mouse.click(710,await weapon_row_y(page));await page.wait_for_timeout(250)
  async def wait(pred,seconds=5):
   end=time.monotonic()+seconds
   while time.monotonic()<end:
    if pred():return True
    await page.wait_for_timeout(50)
   return False
  async def choose(i):
   n=len(events);await select_weapon(page,i)
   assert await wait(lambda:any(e['action']=='weapon_equipped'for e in events[n:])),f'no real equip {i}'
   await page.mouse.click(330,await weapon_row_y(page));await page.wait_for_timeout(300)
  async def fire(x=790,y=590):
   await page.mouse.move(x,y);await page.mouse.down();await page.wait_for_timeout(40);await page.mouse.up()
  await choose(1);n=len(events);await fire();await wait(lambda:any(e['action']=='weapon_blink'for e in events[n:]));await page.wait_for_timeout(100)
  rows=[e for e in events[n:]if e['action']=='weapon_blink'];checks['mouse_instant_blade_once']=len(rows)==1 and rows[0]['recoil_speed']==0
  checks['mouse_instant_blade_distance']=bool(rows)and abs(math.dist(rows[0]['detail']['start'],rows[0]['detail']['finish'])-84.7)<1
  checks['mouse_blink_clears_all_speed_and_pauses']=bool(rows)and rows[0]['velocity']==[0,0]and rows[0]['normal_velocity']==[0,0]and rows[0]['blink_pause']>=.074
  await page.screenshot(path=str(OUT/'mouse-blink.png'))
  await choose(2);n=len(events);await fire();await page.wait_for_timeout(100)
  packets=[e for e in events[n:]if e['action']=='weapon_packet'and e['detail']['state']=='started'];blasts=[e for e in events[n:]if e['action']=='weapon_blast']
  checks['mouse_bomb_release_tick']=len(packets)==1 and len(blasts)==1 and packets[0]['physics_tick']==blasts[0]['physics_tick']
  await page.screenshot(path=str(OUT/'mouse-blast.png'))
  await choose(5);n=len(events);await fire();await page.wait_for_timeout(100);await page.mouse.move(180,670);await page.mouse.down();await wait(lambda:sum(e['action']=='weapon_blink'for e in events[n:])==2);await page.mouse.up()
  rows=[e for e in events[n:]if e['action']=='weapon_blink'];checks['mouse_two_blade_flashes']=len(rows)==2
  checks['mouse_second_flash_has_delay']=len(rows)==2 and (rows[1]['physics_tick']-rows[0]['physics_tick'])/60>=.29
  checks['mouse_second_stage_half_budget']=len(rows)==2 and abs(math.dist(rows[1]['detail']['start'],rows[1]['detail']['finish'])-84.7*.5)<1
  checks['mouse_second_flash_reaim']=len(rows)==2 and rows[0]['detail']['finish'][0]<rows[0]['detail']['start'][0]and rows[1]['detail']['finish'][0]>rows[1]['detail']['start'][0]
  await choose(6);n=len(events);await fire(790,510);await page.wait_for_timeout(900)
  blinks=[e for e in events[n:]if e['action']=='weapon_blink'];checks['mouse_boomerang_first_is_shared_blink']=len(blinks)==1 and abs(math.dist(blinks[0]['detail']['start'],blinks[0]['detail']['finish'])-84.7)<1 and blinks[0]['blink_pause']>=.074
  rows=[e for e in events[n:]if e['action']=='weapon_motion'and e['detail']['entities']];checks['mouse_slow_outbound']=len(rows)>3 and all(e['detail']['entities'][0]['phase']=='outbound'for e in rows)
  await page.keyboard.press('f');await page.wait_for_timeout(150)
  returned=[e for e in events[n:]if e['action']=='weapon_entity_transition'];ret=[e for e in returned if e['detail']['state']=='returning'];caught=[e for e in returned if e['detail']['state']=='caught']
  checks['mouse_instant_recall_same_tick']=len(ret)==1 and len(caught)==1 and ret[0]['physics_tick']==caught[0]['physics_tick']and abs(caught[0]['recoil_speed']-(84.7*.5/.14))<1
  await page.screenshot(path=str(OUT/'mouse-recall.png'))
  await choose(4);n=len(events);await page.keyboard.down(' ');await page.wait_for_timeout(160);await page.keyboard.up(' ');await page.mouse.move(480,670);await page.mouse.down();await wait(lambda:any(e['action']=='weapon_phase'and e['detail']['phase']=='idle'for e in events[n:]),6)
  rows=[e for e in events[n:]if e['action']=='weapon_motion'and e['detail']['phase']=='beam'];checks['mouse_accelerating_laser_stays_on_muzzle']=len(rows)>=3 and all(len(e['beam_visual'])==2 and math.dist(e['beam_visual'][0],e['beam_muzzle'])<.1 and math.dist(*e['beam_visual'])<=680.1 for e in rows)
  speeds=[e['recoil_speed']for e in rows];checks['mouse_air_laser_accumulates']=len(speeds)>=3 and speeds[-1]>speeds[0]+80
  phases=[e for e in events[n:]if e['action']=='weapon_phase'];start_beam=next((e for e in phases if e['detail']['phase']=='beam'),None);end_beam=next((e for e in phases if e['detail']['phase']=='idle'),None)
  checks['mouse_laser_starts_at_zero']=start_beam is not None and start_beam['velocity']==[0,0]and start_beam['normal_velocity']==[0,0]
  checks['mouse_laser_auto_closes_within_limit']=start_beam is not None and end_beam is not None and 0<end_beam['game_seconds']-start_beam['game_seconds']<=.66
  await page.wait_for_timeout(300);checks['mouse_held_laser_no_auto_repeat']=sum(e['action']=='weapon_phase'and e['detail']['phase']=='beam'for e in events[n:])==1
  await page.mouse.up();await page.wait_for_timeout(150);checks['mouse_laser_release']=any(e['action']=='weapon_phase'and e['detail']['phase']=='idle'for e in events[n:])
  await page.screenshot(path=str(OUT/'mouse-laser.png'))
  await choose(6)
  await page.mouse.click(500,100);await page.wait_for_timeout(350);n=len(events)
  await page.keyboard.press(' ')
  await page.mouse.click(432,230,button='right')
  assert await wait(lambda:any(e['action']=='hook_kick'for e in events[n:])), 'real upward hook did not launch'
  kick=next(e for e in events[n:]if e['action']=='hook_kick');checks['mouse_hook_fixed_45']=kick['recoil'][1]<0 and abs(abs(kick['recoil'][0])+kick['recoil'][1])<1 and math.copysign(1,kick['recoil'][0])==kick['kick_side']
  assert await wait(lambda:any(e['action']=='free'for e in events[n:])), 'hook recovery never returned to free'
  await fire(650,670)
  released=await wait(lambda:any(e['action']=='weapon_entities'and e['detail']['entities']for e in events[n:]))
  if not released:
   (OUT/'failed_events.json').write_text(json.dumps(events,ensure_ascii=False,indent=2)+'\n');await page.screenshot(path=str(OUT/'failed-air-blade.png'))
  assert released, 'air blade never released'
  await page.mouse.move(790,250);await page.mouse.down();await page.wait_for_timeout(1300)
  await page.keyboard.press(' ');await page.wait_for_timeout(1300)
  rows=[e for e in events[n:]if e['action']=='weapon_motion'and e['detail']['entities']]
  scaled=[e for e in rows if e['time_scale']<.5]
  checks['mouse_jump_does_not_reset_practice']=not any(e['action']=='practice_reset'for e in events[n:])
  checks['mouse_air_controlled_blade_slowtime']=len(scaled)>=3
  checks['mouse_controlled_blade_continues_slowtime']=len(scaled)>=3 and scaled[-1]['real_usec']-scaled[0]['real_usec']>2000000
  positions=[e['detail']['entities'][0]['position']for e in scaled]
  checks['mouse_controlled_blade_turns_up']=len(positions)>=3 and positions[-1][1]<positions[0][1]-20
  await page.screenshot(path=str(OUT/'mouse-air-blade-focus.png'))
  await page.keyboard.press('f');await page.mouse.up();await page.wait_for_timeout(200)
  await context.close()
  context=await browser.new_context(viewport={'width':844,'height':390},has_touch=True,is_mobile=True);page=await context.new_page();page.on('console',log);page.on('pageerror',lambda e:errors.append(str(e)))
  await page.goto(sys.argv[1]if len(sys.argv)>1 else'http://127.0.0.1:8765',wait_until='networkidle');await page.wait_for_function('window.PLAYTEST_LOADING_DONE===true',timeout=60000);await page.wait_for_timeout(500)
  await page.touchscreen.tap(420,270);await page.wait_for_timeout(300);await page.touchscreen.tap(275,150);await page.wait_for_timeout(600)
  await select_weapon(page,11,True);await page.wait_for_timeout(200);session=await context.new_cdp_session(page)
  async def touch(kind,points):await session.send('Input.dispatchTouchEvent',{'type':kind,'touchPoints':[{'id':i,'x':x,'y':y}for i,x,y in points]})
  n=len(events)
  await touch('touchStart',[(3,550,315)]);await touch('touchMove',[(3,505,285)]);await page.wait_for_timeout(80)
  await touch('touchStart',[(3,505,285),(4,694,168)]);await touch('touchMove',[(3,505,285),(4,712,168)]);# CDP touchEnd points identify the fingers that END, not the remaining fingers.
  await touch('touchEnd',[(4,712,168)]);await page.wait_for_timeout(160)
  rejects=[e for e in events[n:]if e['action']=='attack_rejected'];checks['touch_skill_trigger_retains_main_rod_aim']=len(rejects)==1 and rejects[0]['detail']['reason']=='combat_energy'and rejects[0]['aim'][0]<-.6 and rejects[0]['aim'][1]<-.3
  await page.screenshot(path=str(OUT/'touch-shared-skill-aim.png'));await touch('touchEnd',[]);await page.wait_for_timeout(200)
  checks['touch_skill_aim_release_has_no_primary']=not any(e['action']=='shot'or e['action']=='weapon_blink'or (e['action']=='weapon_packet'and e['detail']['state']=='started')for e in events[n:])
  await context.close();await browser.close()
 report={'url':sys.argv[1]if len(sys.argv)>1 else'local','checks':checks,'failed':[k for k,v in checks.items()if not v],'browser_errors':errors,'scope':'actual desktop canvas + CDP multitouch; touch skill insufficient-resource request uses shared rod; accepted skill boundary separately native; not physical devices'}
 (OUT/'events.json').write_text(json.dumps(events,ensure_ascii=False,indent=2)+'\n');(OUT/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False));raise SystemExit(bool(report['failed']or errors))
asyncio.run(main())
