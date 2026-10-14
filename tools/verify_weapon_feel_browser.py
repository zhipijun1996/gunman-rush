"""Real canvas weapon inputs; readonly accepted-event evidence, no gameplay injection."""
import asyncio,json,math,shutil,sys,time
from pathlib import Path
from playwright.async_api import async_playwright
from studio_gui_pointer import select_weapon,weapon_row_y
OUT=Path('build/weapon_feel/browser');OUT.mkdir(parents=True,exist_ok=True)
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
  await page.screenshot(path=str(OUT/'mouse-blink.png'))
  await choose(2);n=len(events);await fire();await page.wait_for_timeout(100)
  packets=[e for e in events[n:]if e['action']=='weapon_packet'and e['detail']['state']=='started'];blasts=[e for e in events[n:]if e['action']=='weapon_blast']
  checks['mouse_bomb_release_tick']=len(packets)==1 and len(blasts)==1 and packets[0]['physics_tick']==blasts[0]['physics_tick']
  await page.screenshot(path=str(OUT/'mouse-blast.png'))
  await choose(5);n=len(events);await fire();await page.wait_for_timeout(100);await page.mouse.move(180,450);await page.mouse.down();await wait(lambda:sum(e['action']=='weapon_blink'for e in events[n:])==2);await page.mouse.up()
  rows=[e for e in events[n:]if e['action']=='weapon_blink'];checks['mouse_two_blade_flashes']=len(rows)==2
  checks['mouse_second_flash_has_delay']=len(rows)==2 and (rows[1]['physics_tick']-rows[0]['physics_tick'])/60>=.29
  checks['mouse_second_flash_reaim']=len(rows)==2 and rows[0]['detail']['finish'][0]<rows[0]['detail']['start'][0]and rows[1]['detail']['finish'][0]>rows[1]['detail']['start'][0]
  await choose(6);n=len(events);await fire(790,510);await page.wait_for_timeout(900)
  rows=[e for e in events[n:]if e['action']=='weapon_motion'and e['detail']['entities']];checks['mouse_slow_outbound']=len(rows)>3 and all(e['detail']['entities'][0]['phase']=='outbound'for e in rows)
  await page.keyboard.press('f');await page.wait_for_timeout(150)
  returned=[e for e in events[n:]if e['action']=='weapon_entity_transition'];ret=[e for e in returned if e['detail']['state']=='returning'];caught=[e for e in returned if e['detail']['state']=='caught']
  checks['mouse_instant_recall_same_tick']=len(ret)==1 and len(caught)==1 and ret[0]['physics_tick']==caught[0]['physics_tick']and abs(caught[0]['recoil_speed']-(84.7*.5/.14))<1
  await page.screenshot(path=str(OUT/'mouse-recall.png'))
  await choose(4);n=len(events);await page.keyboard.down(' ');await page.wait_for_timeout(160);await page.keyboard.up(' ');await page.mouse.move(480,670);await page.mouse.down();await page.wait_for_timeout(1400)
  rows=[e for e in events[n:]if e['action']=='weapon_motion'and e['detail']['phase']=='beam'];speeds=[e['recoil_speed']for e in rows];checks['mouse_air_laser_accumulates']=len(speeds)>=3 and speeds[-1]>speeds[0]+80
  await page.mouse.up();await page.wait_for_timeout(150);checks['mouse_laser_release']=any(e['action']=='weapon_phase'and e['detail']['phase']=='idle'for e in events[n:])
  await page.screenshot(path=str(OUT/'mouse-laser.png'))
  await choose(6)
  await page.mouse.click(500,100);await page.wait_for_timeout(350);n=len(events)
  await page.keyboard.press(' ')
  await page.mouse.click(432,230,button='right')
  assert await wait(lambda:any(e['action']=='hook_kick'for e in events[n:])), 'real upward hook did not launch'
  assert await wait(lambda:any(e['action']=='free'for e in events[n:])), 'hook recovery never returned to free'
  await fire(650,670)
  assert await wait(lambda:any(e['action']=='weapon_entities'and e['detail']['entities']for e in events[n:])), 'air blade never released'
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
  await context.close();await browser.close()
 report={'url':sys.argv[1]if len(sys.argv)>1 else'local','checks':checks,'failed':[k for k,v in checks.items()if not v],'browser_errors':errors,'scope':'actual desktop mouse/menu/keyboard canvas; browser-touch menu and weapon regression separate; not physical devices'}
 (OUT/'events.json').write_text(json.dumps(events,ensure_ascii=False,indent=2)+'\n');(OUT/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False));raise SystemExit(bool(report['failed']or errors))
asyncio.run(main())
