"""Actual browser canvas mouse inputs; read-only STUDIO_EVENT observations."""
import asyncio, hashlib, json, math, shutil, subprocess, time
from pathlib import Path
from playwright.async_api import async_playwright
OUT=Path('build/grapple_fix/browser');OUT.mkdir(parents=True,exist_ok=True)
async def main():
 events=[];errors=[];checks={};failure=None
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path=shutil.which('chromium'),args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  context=await browser.new_context(viewport={'width':1280,'height':720},record_video_dir=str(OUT/'video'))
  page=await context.new_page()
  def log(msg):
   if 'STUDIO_EVENT ' in msg.text:
    try:events.append(json.loads(msg.text.split('STUDIO_EVENT ',1)[1]))
    except json.JSONDecodeError:errors.append(msg.text)
   if any(x in msg.text for x in ['SCRIPT ERROR','Parse Error','ERROR:']):errors.append(msg.text)
  page.on('console',log);page.on('pageerror',lambda e:errors.append(str(e)))
  async def wait(predicate,seconds=5):
   end=time.monotonic()+seconds
   while time.monotonic()<end:
    if predicate():return True
    await page.wait_for_timeout(20)
   return False
  async def reset():
   n=len(events);await page.mouse.click(500,100)
   assert await wait(lambda:any(e['action']=='practice_reset' and e['detail']['section']==2 for e in events[n:])), 'hook checkpoint button did not accept section 2'
   await page.wait_for_timeout(700)
  try:
   await page.goto('http://127.0.0.1:8765',wait_until='networkidle')
   await page.wait_for_function('window.PLAYTEST_LOADING_DONE===true',timeout=60000)
   await page.wait_for_timeout(600);await page.mouse.click(640,500)
   await page.wait_for_timeout(300);await page.mouse.click(335,285);await page.wait_for_timeout(700)
   await reset();checks['actual_hook_checkpoint_button']=True
   await page.screenshot(path=str(OUT/'before-up-hook.png'))
   n=len(events);await page.mouse.click(432,230,button='right')
   assert await wait(lambda:any(e['action']=='hook_kick' for e in events[n:])), 'real upward hook never launched'
   kick=next(e for e in events[n:] if e['action']=='hook_kick')
   assert await wait(lambda:any(e['action']=='free' and e['physics_tick']>kick['physics_tick'] for e in events[n:])), 'upward hook never recovered'
   free=next(e for e in events[n:] if e['action']=='free' and e['physics_tick']>kick['physics_tick'])
   dx=free['position'][0]-kick['position'][0];dy=free['position'][1]-kick['position'][1]
   checks['mouse_upward_hook_contacts_then_launches']=any(e['action']=='hook_contact_kick' for e in events[n:])
   checks['actual_browser_hop_is_24px_per_axis']=abs(abs(dx)-24)<.2 and abs(dy+24)<.2
   checks['browser_launch_keeps_incoming_45_degrees']=kick['recoil'][1]<0 and abs(abs(kick['recoil'][0])+kick['recoil'][1])<.1 and math.copysign(1,kick['recoil'][0])==kick['kick_side']
   await page.screenshot(path=str(OUT/'after-up-hook.png'))
   await reset();n=len(events);await page.mouse.click(880,510,button='right')
   assert await wait(lambda:any(e['action']=='hook_miss' for e in events[n:])), 'far hook did not miss'
   cast=next(e for e in events[n:] if e['action']=='hook_cast');miss=next(e for e in events[n:] if e['action']=='hook_miss')
   origin=[cast['position'][0],cast['position'][1]-6]
   checks['actual_browser_far_hook_caps_at_231px']=abs(math.dist(origin,miss['hook_tip'])-231)<.2
   assert await wait(lambda:any(e['action']=='free' and e['physics_tick']>miss['physics_tick'] for e in events[n:])), 'far hook never retracted'
   checks['far_target_cannot_start_pull_or_kick']=not any(e['action'] in ['hook_pull','hook_contact_kick','hook_kick'] for e in events[n:])
   await page.screenshot(path=str(OUT/'after-far-hook.png'))
  except Exception as exc:
   failure=str(exc);await page.screenshot(path=str(OUT/'failure.png'))
  await context.close();await browser.close()
 info=json.loads(Path('build/web/build-info.json').read_text())
 report={'scope':'actual mouse canvas + normal browser physics; no gameplay injection; moving-target matrices separately native; no physical device/audio/player acceptance','source_commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'build_info':info,'pack_sha256':hashlib.sha256((Path('build/web')/info['pack']).read_bytes()).hexdigest(),'checks':checks,'failed':[k for k,v in checks.items() if not v],'browser_errors':errors,'failure':failure}
 (OUT/'events.json').write_text(json.dumps(events,ensure_ascii=False,indent=2)+'\n');(OUT/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps(report,ensure_ascii=False));raise SystemExit(bool(report['failed'] or errors or failure))
asyncio.run(main())
