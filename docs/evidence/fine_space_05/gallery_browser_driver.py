import asyncio,json,shutil,sys
from pathlib import Path
sys.path.insert(0,'/workspace/gunman-art/tools')
from verify_forest_browser import environment_proxy
from playwright.async_api import async_playwright
async def run():
 out=Path('/workspace/gunman-art/build/fine_space_05/public_gallery');out.mkdir(exist_ok=True)
 launch={'executable_path':shutil.which('chromium'),'headless':True,'args':['--no-sandbox']};launch['proxy'],safe=environment_proxy()
 async with async_playwright() as p:
  b=await p.chromium.launch(**launch);page=await b.new_page(viewport={'width':1280,'height':900})
  errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
  url='https://zhipijun1996.github.io/gunman-rush-previews/reviews/FINE-SPACE-05/efd7843/'
  r=await page.goto(url,wait_until='domcontentloaded',timeout=60000);assert r.status==200
  await page.locator('video').evaluate('v=>{v.muted=true;return v.play()}')
  await page.wait_for_function('document.querySelector("video").currentTime>1',timeout=30000)
  await page.locator('video').scroll_into_view_if_needed();await page.screenshot(path=str(out/'actual-public-video.png'))
  observed=await page.locator('video').evaluate('v=>({time:v.currentTime,duration:v.duration,width:v.videoWidth,height:v.videoHeight,ready:v.readyState,src:v.currentSrc})')
  assert observed['width']==1280 and observed['height']==720 and 24<observed['duration']<25
  await page.locator('img').first.wait_for(state='visible');assert await page.locator('img').evaluate_all('xs=>xs.every(x=>x.complete&&x.naturalWidth>0)')
  report={'status':'passed','url':url,'observed':observed,'errors':errors,'scope':'Public review page actual video playback >1s, all original images loaded; not a playable game or full visual/audio review'}
  assert not errors
  (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');await b.close();print(json.dumps(report))
asyncio.run(run())
