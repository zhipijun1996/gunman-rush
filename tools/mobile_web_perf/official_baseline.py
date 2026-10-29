"""Observe the unchanged official exported PCK with browser-only meters.

No Godot state, pause policy, playback type, draw resources or scripts are changed.
Script/physics function costs are unavailable in this uninstrumented package.
"""
import asyncio,json,statistics,sys
from pathlib import Path
from playwright.async_api import async_playwright
sys.path.insert(0,str(Path(__file__).resolve().parents[1]));from verify_mobile_ui_clarity_browser import surfaces
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/mobile_web_perf_01/official-02'
INIT='''window.MOBILE_AUDIO_PROBE_WORKLET_URL='/mobile-perf-pcm.js';window.BASELINE_FRAMES=[];let previous=0;function sample(now){if(previous)window.BASELINE_FRAMES.push([now,now-previous]);previous=now;requestAnimationFrame(sample)}requestAnimationFrame(sample);'''
async def main():
 OUT.mkdir(exist_ok=False);logs=[];results=[]
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  context=await browser.new_context(viewport={'width':853,'height':290},device_scale_factor=2.5,is_mobile=True,has_touch=True);await context.add_init_script(INIT);await context.add_init_script(path=str(ROOT/'tools/mobile_web_perf/audio_probe.js'));await context.add_init_script(path=str(ROOT/'tools/mobile_web_perf/gpu_probe.js'))
  page=await context.new_page();page.on('console',lambda m:logs.append(m.type+': '+m.text));page.on('pageerror',lambda e:logs.append('PAGE ERROR:'+str(e)))
  try:
   await page.goto('http://127.0.0.1:8800/',wait_until='domcontentloaded');await page.wait_for_function('window.PLAYTEST_LOADING_DONE===true',timeout=180000);await page.wait_for_timeout(1500);await page.screenshot(path=str(OUT/'title.png'));b=surfaces(OUT/'title.png',[(195,163,102)])[0];await page.touchscreen.tap((b[0]+b[2]/2)/2.5,(b[1]+b[3]/2)/2.5);await page.wait_for_timeout(5000)
   cdp=await context.new_cdp_session(page);await cdp.send('Performance.enable')
   for phase in ['home_idle','home_menu','home_resumed']:
    if phase=='home_menu':await page.touchscreen.tap(653,17)
    if phase=='home_resumed':await page.keyboard.press('Escape')
    await page.wait_for_timeout(3000);start=await page.evaluate('performance.now()');audio0=await page.evaluate('window.MOBILE_AUDIO_PROBE.snapshot()');cdp0=await cdp.send('Performance.getMetrics');await page.wait_for_timeout(12000);times=await page.evaluate('(t)=>window.BASELINE_FRAMES.filter(x=>x[0]>=t).map(x=>x[1])',start);audio1=await page.evaluate('window.MOBILE_AUDIO_PROBE.snapshot()');gpu=await page.evaluate('window.MOBILE_GPU_PROBE.snapshot()');cdp1=await cdp.send('Performance.getMetrics');await page.screenshot(path=str(OUT/(phase+'.png')))
    row={'phase':phase,'frames':times,'fps':1000/statistics.mean(times),'p50_ms':statistics.median(times),'p95_ms':sorted(times)[round((len(times)-1)*.95)],'audio_begin':audio0,'audio_end':audio1,'gpu':gpu,'cdp_begin':cdp0,'cdp_end':cdp1,'godot_script_physics_costs':'unavailable in unchanged PCK; measured separately in diagnostic copy'};results.append(row);print(json.dumps({k:v for k,v in row.items()if k in ['phase','fps','p50_ms','p95_ms']}),flush=True)
    (OUT/'report.json').write_text(json.dumps({'scope':'unchanged official PCK2caa023125bd, browser meters injected; not physical device','results':results,'logs':logs},indent=2))
   assert not any('SCRIPT ERROR:' in x or 'SHADER ERROR:' in x or 'PAGE ERROR:' in x for x in logs),logs
  finally:
   (OUT/'browser.log').write_text('\n'.join(logs));await browser.close()
asyncio.run(main())
