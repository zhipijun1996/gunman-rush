"""Optional real Web renderer smoke: needs Playwright, Pillow and Chromium.
Run from the repository root: python3 tools/verify_demo_browser.py URL
The default URL starts a temporary local build/web server. Mobile emulation
is deliberately reported separately from real Android/iPhone validation.
"""
import asyncio,json,sys,subprocess,shutil
from pathlib import Path
from playwright.async_api import async_playwright
async def main():
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path=shutil.which('chromium') or shutil.which('chromium-browser'),headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'],timeout=30000)
  ctx=await browser.new_context(viewport={'width':1280,'height':720},is_mobile=True,has_touch=True)
  page=await ctx.new_page();logs=[];packs=[]
  page.on('console',lambda m:logs.append(m.text))
  page.on('pageerror',lambda e:logs.append('PAGE ERROR: '+str(e)))
  page.on('response',lambda r:packs.append({'url':r.url,'status':r.status}) if '.pck' in r.url else None)
  await page.goto(sys.argv[1],wait_until='networkidle',timeout=45000)
  await page.wait_for_timeout(1000)
  folder=Path('build/verification/demo');folder.mkdir(parents=True,exist_ok=True)
  await page.screenshot(path=str(folder/'home.png'))
  await page.touchscreen.tap(620,478)
  await page.wait_for_timeout(1000)
  await page.screenshot(path=str(folder/'stage1.png'))
  client=await ctx.new_cdp_session(page)
  await client.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[{'x':160,'y':565,'id':1}]})
  await client.send('Input.dispatchTouchEvent',{'type':'touchMove','touchPoints':[{'x':220,'y':565,'id':1}]})
  await page.wait_for_timeout(300)
  await client.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]})
  await page.screenshot(path=str(folder/'touch-move.png'))
  await client.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[{'x':965,'y':657,'id':1},{'x':1131,'y':571,'id':2}]})
  await client.send('Input.dispatchTouchEvent',{'type':'touchMove','touchPoints':[{'x':965,'y':657,'id':1},{'x':1131,'y':635,'id':2}]})
  await page.wait_for_timeout(240)
  await page.screenshot(path=str(folder/'focus.png'))
  await client.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]})
  await page.wait_for_timeout(1000)
  for i in range(5):
   await client.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[{'x':1131,'y':571,'id':2}]})
   await client.send('Input.dispatchTouchEvent',{'type':'touchMove','touchPoints':[{'x':1200,'y':571,'id':2}]})
   await page.wait_for_timeout(70)
   await client.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]})
   await page.wait_for_timeout(650)
  await page.screenshot(path=str(folder/'after-shots.png'))
  await page.touchscreen.tap(1220,35)
  await page.wait_for_timeout(150)
  await page.screenshot(path=str(folder/'paused.png'))
  await page.touchscreen.tap(650,205)
  await page.wait_for_timeout(300)
  await page.screenshot(path=str(folder/'returned-home.png'))
  if not any('Godot Engine v4.7.2' in x for x in logs):raise RuntimeError('Engine not started')
  if any('SHADER ERROR:' in x or 'Shader compilation failed' in x or 'SCRIPT ERROR:' in x or 'Parse Error:' in x or 'PAGE ERROR:' in x for x in logs):raise RuntimeError(str(logs))
  from PIL import Image
  def picture(name):return Image.open(folder/(name+'.png')).convert('RGB')
  start=picture('stage1');moved=picture('touch-move');focus=picture('focus');shot=picture('after-shots');home=picture('returned-home')
  def body_center(im):
   points=[x for y in range(560,604) for x in range(280) if 169<im.getpixel((x,y))[0]<196 and 204<im.getpixel((x,y))[1]<230 and 214<im.getpixel((x,y))[2]<240]
   if len(points)<300:raise RuntimeError('Real player body not rendered')
   return sum(points)/len(points)
  if body_center(moved)-body_center(start)<50:raise RuntimeError('Touch move did not move player')
  def enemy_pixels(im):return sum(1 for y in range(564,600) for x in range(350,650) if 195<im.getpixel((x,y))[0]<225 and 90<im.getpixel((x,y))[1]<160 and 40<im.getpixel((x,y))[2]<120)
  if enemy_pixels(start)<200 or enemy_pixels(shot)>10:raise RuntimeError('Release shots did not defeat rendered drone')
  if focus.getpixel((20,300))[0]-start.getpixel((20,300))[0]<30 or focus.getpixel((640,300))!=start.getpixel((640,300)):raise RuntimeError('Focus edge/transparent center regressed')
  if max(abs(a-b) for a,b in zip(start.getpixel((20,300)),shot.getpixel((20,300))))>3:raise RuntimeError('Focus did not stop')
  if home.getpixel((100,82))[0]>180:raise RuntimeError('Run did not return Home and remove HP HUD')
  report={'checks':['home start','touch movement','air focus yellow edge and clear center','physical release shots defeat drone','pause then cancel run returns Home'], 'url':page.url,'build_id':await page.locator('#playtest-version').get_attribute('data-build-id'),'packs':packs,'logs':logs,'browser':'Chromium mobile touch emulation','real_device':'unverified'}
  (folder/'browser-report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
  await browser.close()
if len(sys.argv)==1:sys.argv.append('http://127.0.0.1:8769/')
server=None
if sys.argv[1].startswith('http://127.0.0.1:8769'):
 server=subprocess.Popen([sys.executable,'-m','http.server','8769','--bind','127.0.0.1','--directory','build/web'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
try:asyncio.run(main())
finally:
 if server:server.terminate();server.wait(timeout=5)

