"""Actual GUI and GPU partition equivalence; does not approve art or formal integration."""
import asyncio,sys,json,shutil
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import verify_random_stage_browser as h
from playwright.async_api import async_playwright
from PIL import ImageChops,Image
out=Path('build/verification/terrain-tile-gallery');out.mkdir(parents=True,exist_ok=True);h.FOLDER=out
async def main():
 logs=[];report={'scope':'Actual ordinary GUI; candidate gallery and opt-in actual region consumer; default art unchanged','status':'failed'}
 async with async_playwright() as p:
  b=await p.chromium.launch(executable_path=shutil.which('chromium'),headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  c=await b.new_context(viewport={'width':1280,'height':720},record_video_dir=str(out/'video'))
  page=await c.new_page();page.on('console',lambda m:logs.append(m.text));page.on('pageerror',lambda e:logs.append('PAGE ERROR '+str(e)))
  async def snap(n):
   await page.screenshot(path=str(out/(n+'.png')))
   return (await asyncio.to_thread(h.ocr,n)).upper()
  async def wait(n,phrase):
   for i in range(90):
    t=await snap(n)
    if phrase in t:return t
    await page.wait_for_timeout(350)
   raise RuntimeError('missing '+phrase+' '+t)
  try:
   await page.goto(sys.argv[1] if len(sys.argv)>1 else 'http://127.0.0.1:8765',wait_until='networkidle',timeout=60000)
   report['build_id']=await page.locator('#playtest-version').get_attribute('data-build-id')
   await wait('title','DEVELOPMENT DEMOS');await page.mouse.click(*h.text_center('title','DEVELOPMENT DEMOS'))
   await wait('development','MODULE LAB');await page.mouse.click(*h.text_center('development','MODULE LAB'))
   await wait('lab','MORE TRIALS');await page.mouse.click(1010,97);await wait('menu','TERRAIN TILES');await page.mouse.click(*h.text_center('menu','TERRAIN TILES'))
   await wait('shapes-macro','TERRAIN MATERIAL STUDY');await page.wait_for_timeout(800);await snap('shapes-macro')
   await page.mouse.click(920,150);await page.wait_for_timeout(700);await snap('shapes-single')
   a=Image.open(out/'shapes-macro.png').convert('RGB').crop((0,210,1280,635));z=Image.open(out/'shapes-single.png').convert('RGB').crop((0,210,1280,635));delta=ImageChops.difference(a,z)
   report['partition_pixel_difference_bbox']=delta.getbbox()
   if delta.getbbox() is not None:raise RuntimeError('GPU partition invariance failed '+str(delta.getbbox()))
   await page.mouse.click(1080,150);await page.wait_for_timeout(1000);await snap('all-47')
   await page.mouse.click(1080,150);await page.wait_for_timeout(900);await snap('exact-split')
   await page.mouse.click(920,150);await page.wait_for_timeout(700);await snap('exact-unsplit')
   a=Image.open(out/'exact-split.png').convert('RGB').crop((0,210,1280,635));z=Image.open(out/'exact-unsplit.png').convert('RGB').crop((0,210,1280,635))
   report['exact_partition_difference_bbox']=ImageChops.difference(a,z).getbbox()
   if report['exact_partition_difference_bbox'] is not None:raise RuntimeError('Exact-boundary GPU partition invariance failed '+str(report['exact_partition_difference_bbox']))
   await page.mouse.click(1120,674);await wait('region-candidate','ART STUDY: CANDIDATE');await page.wait_for_timeout(800);await snap('region-candidate')
   await page.mouse.click(170,674);await page.wait_for_timeout(300);await wait('region-baseline','ART STUDY: BASELINE')
   await page.mouse.click(170,674);await page.wait_for_timeout(300);await wait('region-candidate-restored','ART STUDY: CANDIDATE')
   for step in range(3):
    await page.keyboard.down('d');await page.keyboard.down('Space');await page.wait_for_timeout(350);await page.keyboard.up('Space');await page.keyboard.up('d');await page.wait_for_timeout(180);await snap('region-input-'+str(step))
   report['region_consumer']='Actual PlainsRegionStage through opt-in development study; ordinary movement/jump; no whole-route completion claim'
   if any('SCRIPT ERROR' in s or 'SHADER ERROR' in s for s in logs):raise RuntimeError(str(logs[-10:]))
   if any('SCRIPT ERROR' in s or 'SHADER ERROR' in s or 'PAGE ERROR' in s for s in logs):raise RuntimeError(str(logs))
   report['status']='passed';report['art_acceptance']='unverified'
  finally:
   (out/'console.log').write_text('\n'.join(logs));(out/'report.json').write_text(json.dumps(report,indent=2));await c.close();await b.close()
 print(json.dumps(report))
asyncio.run(main())
