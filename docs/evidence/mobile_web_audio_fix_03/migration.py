import asyncio,json,sys
from pathlib import Path
from playwright.async_api import async_playwright
HERE=Path(__file__).resolve().parent
async def main():
 report={'scope':'Desktop real Chromium with old production service worker, same-origin host without isolation headers; no phone claim','status':'failed'}
 errors=[];urls=[]
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  context=await browser.new_context(viewport={'width':1280,'height':720},device_scale_factor=1)
  page=await context.new_page();page.on('pageerror',lambda e:errors.append(str(e)));page.on('framenavigated',lambda f:urls.append(f.url) if f==page.main_frame else None)
  try:
   (HERE/'serve-old-worker').touch()
   await page.goto('http://127.0.0.1:8810/seed-old.html')
   await page.evaluate("async()=>{localStorage.setItem('migration-preserve-fixture','keep');await navigator.serviceWorker.register('index.cache-sw.js',{updateViaCache:'none'});await navigator.serviceWorker.ready;}")
   await page.wait_for_function('navigator.serviceWorker.controller!==null')
   report['before']=await page.evaluate('({isolated:crossOriginIsolated,controller:navigator.serviceWorker.controller.scriptURL})')
   assert not report['before']['isolated']
   (HERE/'serve-old-worker').unlink()
   await page.goto('http://127.0.0.1:8810/?migration=1',wait_until='domcontentloaded')
   await page.wait_for_function('window.PLAYTEST_LOADING_DONE===true',timeout=180000)
   report['after']=await page.evaluate("({isolated:crossOriginIsolated,sab:typeof SharedArrayBuffer!=='undefined',threads:GODOT_THREADS_ENABLED,canvas:[document.querySelector('canvas').width,document.querySelector('canvas').height],saved:localStorage.getItem('migration-preserve-fixture'),controller:navigator.serviceWorker.controller.scriptURL})")
   await page.screenshot(path=str(HERE/'migration-title.png'))
   assert report['after']['isolated'] and report['after']['sab'] and report['after']['threads'] and report['after']['saved']=='keep',report
   assert not errors,errors
   assert len([u for u in urls if '?migration=1' in u])<=2,urls
   report['status']='passed'
  finally:
   (HERE/'serve-old-worker').unlink(missing_ok=True)
   report.update(errors=errors,navigations=urls)
   (HERE/'migration.json').write_text(json.dumps(report,indent=2))
   await browser.close()
 print(json.dumps(report))
asyncio.run(main())
