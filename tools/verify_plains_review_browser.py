"""Record the explicit Boss8 fixture with real normal input and damage.
This is separate from formal Home/eight-room and real-device verification.
"""
import asyncio,json,subprocess,shutil
from pathlib import Path
from playwright.async_api import async_playwright
ROOT=Path(__file__).resolve().parents[1]/'build/verification/polish-review'
async def main():
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path=shutil.which('chromium'),headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  context=await browser.new_context(viewport={'width':1280,'height':720},record_video_dir=str(ROOT/'videos'),record_video_size={'width':1280,'height':720})
  page=await context.new_page(); logs=[]
  page.on('console',lambda m: logs.append(m.text))
  page.on('pageerror',lambda e: logs.append('PAGE ERROR: '+str(e)))
  await page.goto('http://127.0.0.1:8791',wait_until='networkidle',timeout=60000)
  saw=set(); paused_once=False
  for i in range(90):
   await page.wait_for_timeout(1000)
   for phase in [1,2,3]:
    if any(f'phase={phase}' in x for x in logs) and phase not in saw:
     saw.add(phase);await page.screenshot(path=str(ROOT/f'phase-{phase}.png'))
   if not paused_once and any('mode=pier_open' in x for x in logs):
    await page.keyboard.press('Escape');await page.wait_for_timeout(300);await page.screenshot(path=str(ROOT/'paused-pier.png'))
    await page.keyboard.press('Escape');paused_once=True
   if i in [3,10,20,40,60,80]:
    await page.screenshot(path=str(ROOT/f'frame-{i}.png'));print('REVIEW',i,logs[-1:] ,flush=True)
   if any('bossHP=0' in x for x in logs):
    await page.wait_for_timeout(1200);await page.screenshot(path=str(ROOT/'defeat.png'));break
   if any('SCRIPT ERROR:' in x or 'PAGE ERROR:' in x for x in logs):break
  video=page.video
  await context.close(); await video.save_as(str(ROOT/'boss-motion.webm'))
  (ROOT/'review-report.json').write_text(json.dumps({'scope':'explicit Boss8 fixture; actual input/projectiles/HP; not eight-room traversal','phases':sorted(saw),'paused_via_keyboard':paused_once,'logs':logs},ensure_ascii=False,indent=2)+'\n')
  await browser.close()
  if saw != {1,2,3} or not paused_once or not any('bossHP=0' in x for x in logs):
   raise RuntimeError('Boss review did not finish all three phases and keyboard pause')
  if any('SCRIPT ERROR:' in x or 'PAGE ERROR:' in x for x in logs):
   raise RuntimeError('Boss review has script/page errors')
server=subprocess.Popen(['python3','-m','http.server','8791','--bind','127.0.0.1','--directory',str(ROOT)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
try:asyncio.run(asyncio.wait_for(main(),timeout=180))
finally:server.terminate();server.wait()
