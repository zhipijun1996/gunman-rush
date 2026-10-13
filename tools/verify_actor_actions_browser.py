"""Verify actual desktop/touchscreen GUI. Requires a served Web export; not device approval."""
import asyncio,shutil,json,io,math,sys
from pathlib import Path
from PIL import Image,ImageChops,ImageStat
from playwright.async_api import async_playwright
out=Path('build/actor_actions/browser-final');out.mkdir(exist_ok=True)
def scarf(blob):
 im=Image.open(io.BytesIO(blob)).convert('RGB');p=[]
 for y in range(int(im.height*.25),im.height):
  for x in range(60,im.width-60):
   r,g,b=im.getpixel((x,y))
   if r>90 and r>g*1.8 and r>b*1.6:p.append((x,y))
 return [sum(a[i] for a in p)/len(p) for i in [0,1]] if p else None
def camera_shift(before,after):
 # Compare the same static terrain texture. The camera follows the Courier,
 # so screen-space scarf coordinates alone do not measure world movement.
 a=Image.open(io.BytesIO(before)).convert('RGB');b=Image.open(io.BytesIO(after)).convert('RGB')
 box=(450,610,800,660);sample=a.crop(box);scores=[]
 for dx in range(-300,301,4):
  shifted=b.crop((box[0]+dx,box[1],box[2]+dx,box[3]))
  scores.append((sum(ImageStat.Stat(ImageChops.difference(sample,shifted)).mean),dx))
 score,dx=min(scores);zero=sum(ImageStat.Stat(ImageChops.difference(sample,b.crop(box))).mean)
 return {'pixels':dx,'match_error':score,'unshifted_error':zero,'valid':score<max(1,zero*.6) or (abs(dx)<=4 and score<1)}
async def main():
 logs=[];checks={}
 async with async_playwright() as p:
  b=await p.chromium.launch(executable_path=shutil.which('chromium'),args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  c=await b.new_context(viewport={'width':1280,'height':720})
  page=await c.new_page();page.on('console',lambda m:logs.append(m.text));page.on('pageerror',lambda e:logs.append('PAGE ERROR:'+str(e)))
  await page.goto((sys.argv[1] if len(sys.argv)>1 else 'http://127.0.0.1:8765'),wait_until='networkidle');await page.wait_for_function('window.PLAYTEST_LOADING_DONE === true',timeout=60000);await page.wait_for_timeout(500)
  await page.mouse.click(640,500);await page.wait_for_timeout(300);await page.mouse.click(335,285);await page.wait_for_timeout(900)
  first_image=await page.screenshot(path=str(out/'desktop-studio.png'));first=scarf(first_image)
  await page.keyboard.down('d');await page.wait_for_timeout(200);await page.keyboard.up('d');second_image=await page.screenshot(path=str(out/'desktop-move.png'));second=scarf(second_image)
  movement=camera_shift(first_image,second_image)
  checks['desktop_move']=first is not None and second is not None and movement['valid'] and abs(second[0]-first[0]-movement['pixels'])>3
  await page.keyboard.press('Space');await page.wait_for_timeout(160);await page.keyboard.press('Space');await page.wait_for_timeout(80);await page.screenshot(path=str(out/'desktop-wings.png'))
  await page.mouse.click(180,100);await page.mouse.move(540,615);await page.mouse.down();await page.wait_for_timeout(80);await page.mouse.up();await page.wait_for_timeout(240);await page.screenshot(path=str(out/'desktop-machine-gun.png'))
  await page.keyboard.press('Escape');await page.wait_for_timeout(500);pause_a=scarf(await page.screenshot());await page.wait_for_timeout(350);pause_b=scarf(await page.screenshot(path=str(out/'desktop-pause.png')));checks['desktop_pause']=pause_a==pause_b
  await page.keyboard.press('Escape');await page.wait_for_timeout(100)
  await page.mouse.click(810,100);await page.wait_for_timeout(450);home_image=await page.screenshot(path=str(out/'desktop-home.png'));checks['desktop_return']=scarf(home_image)!=pause_b
  await c.close()
  c=await b.new_context(viewport={'width':844,'height':390},has_touch=True,is_mobile=True)
  page=await c.new_page();page.on('console',lambda m:logs.append(m.text));page.on('pageerror',lambda e:logs.append('PAGE ERROR:'+str(e)))
  await page.goto((sys.argv[1] if len(sys.argv)>1 else 'http://127.0.0.1:8765'),wait_until='networkidle');await page.wait_for_function('window.PLAYTEST_LOADING_DONE === true',timeout=60000);await page.wait_for_timeout(500)
  await page.touchscreen.tap(420,270);await page.wait_for_timeout(300);await page.touchscreen.tap(275,150);await page.wait_for_timeout(700)
  initial=scarf(await page.screenshot(path=str(out/'touch-studio.png')))
  session=await c.new_cdp_session(page)
  async def touches(kind,points):
   await session.send('Input.dispatchTouchEvent',{'type':kind,'touchPoints':[{'x':x,'y':y,'id':i} for i,x,y in points]})
  await touches('touchStart',[(0,175,320)]);await touches('touchMove',[(0,235,320)]);await page.wait_for_timeout(220)
  await touches('touchStart',[(0,235,320),(1,693,327)]);await page.wait_for_timeout(90);await touches('touchEnd',[(0,235,320)]);await page.wait_for_timeout(120)
  moved=scarf(await page.screenshot(path=str(out/'touch-move-jump.png')));await touches('touchEnd',[])
  checks['touch_move_jump']=initial is not None and moved is not None and math.dist(initial,moved)>5
  await page.touchscreen.tap(175,54);await page.wait_for_timeout(250)
  await touches('touchStart',[(2,530,310)]);await touches('touchMove',[(2,570,335)]);await page.wait_for_timeout(90);await touches('touchEnd',[]);await page.wait_for_timeout(300);await page.screenshot(path=str(out/'touch-machine-gun.png'))
  await page.touchscreen.tap(350,54);await page.wait_for_timeout(450)
  hook_start=scarf(await page.screenshot(path=str(out/'touch-hook-ready.png')))
  await page.touchscreen.tap(694,232);await page.wait_for_timeout(360)
  hook_end=scarf(await page.screenshot(path=str(out/'touch-hook-pull.png')));checks['touch_hook']=hook_start is not None and hook_end is not None and math.dist(hook_start,hook_end)>6
  await page.touchscreen.tap(738,20);await page.wait_for_timeout(500)
  pa=scarf(await page.screenshot());await page.wait_for_timeout(300);pb=scarf(await page.screenshot(path=str(out/'touch-pause.png')));checks['touch_pause']=pa==pb
  await page.touchscreen.tap(738,20);await page.wait_for_timeout(100)
  await page.touchscreen.tap(514,54);await page.wait_for_timeout(350);await page.screenshot(path=str(out/'touch-home.png'))
  await c.close();await b.close()
 errors=[x for x in logs if any(s in x for s in ['SCRIPT ERROR','Parse Error','PAGE ERROR','Failed to load script'])]
 report={'movement_measurement':movement,'checks':checks,'errors':errors,'failed':len(errors)+sum(not v for v in checks.values()),'scope':'actual GUI and keyboard/CDP touchscreen adapter behavior; no engine state injection, no physical device/subjective approval'}
 (out/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False));raise SystemExit(bool(report['failed']))
asyncio.run(main())
