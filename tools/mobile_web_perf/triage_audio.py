"""Actual single/threaded Web audio path and same-picture before/after probes."""
import argparse,asyncio,json,sys
from pathlib import Path
from playwright.async_api import async_playwright
sys.path.insert(0,str(Path(__file__).resolve().parents[1]));from verify_mobile_ui_clarity_browser import surfaces
from run_ab import summarize
async def main(args):
 args.output.mkdir(parents=True,exist_ok=False);logs=[];results=[]
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  context=await browser.new_context(viewport={'width':853,'height':290},device_scale_factor=2.5,is_mobile=True,has_touch=True);page=await context.new_page()
  page.on('console',lambda m:logs.append(m.type+':'+m.text));page.on('pageerror',lambda e:logs.append('PAGE ERROR:'+str(e)))
  async def cmd(value):
   await page.evaluate('(v)=>window.MOBILE_PERF_COMMAND=v',value);await page.wait_for_function("window.MOBILE_PERF_COMMAND===''",timeout=20000)
  async def snapshot():return await page.evaluate('({audio:window.MOBILE_AUDIO_PROBE.snapshot(),graph:window.MOBILE_AUDIO_GRAPH_PROBE.snapshot(),buses:window.MOBILE_PERF_NATIVE_BUS_INFO?.(),isolated:crossOriginIsolated,sab:typeof SharedArrayBuffer,state:window.MOBILE_PERF_STATE.state})')
  async def capture(label,seconds=8):
   await page.wait_for_timeout(2500);start=await snapshot();n=await page.evaluate('window.MOBILE_PERF_RESULTS.length');await cmd('seconds:'+str(seconds));await cmd('capture');await page.wait_for_timeout(1500);await cmd('cue_coin');await page.wait_for_function('(n)=>window.MOBILE_PERF_RESULTS.length>n',arg=n,timeout=(seconds+30)*1000);row=await page.evaluate('window.MOBILE_PERF_RESULTS.at(-1)');row['label']=label;row['before']=start;row['after']=await snapshot();results.append(row);(args.output/'report.json').write_text(json.dumps({'runtime':args.runtime,'url':args.root_url,'results':results,'logs':logs,'scope':'official paired template engines, same instrumented public-PCK derivative, cloud SwiftShader not phone'},indent=2));print(label,json.dumps(summarize(row)),flush=True)
  try:
   await page.goto(args.root_url,wait_until='domcontentloaded');await page.wait_for_function('window.READY===true && window.MOBILE_PERF_READY===true',timeout=180000);await page.wait_for_timeout(1000);await page.screenshot(path=str(args.output/'title.png'));b=surfaces(args.output/'title.png',[(195,163,102)])[0];await page.touchscreen.tap((b[0]+b[2]/2)/2.5,(b[1]+b[3]/2)/2.5);await page.wait_for_function("window.MOBILE_PERF_STATE?.state?.context==='home' && window.MOBILE_PERF_STATE.state.foreground.effective_drawn>0",timeout=45000)
   if args.runtime=='single':
    await cmd('mode:sample_only');await capture('sample_original_bus',6)
    await page.evaluate('window.MOBILE_PERF_MASTER_ROUTING(true)');await capture('sample_master_root',6)
    await page.evaluate('window.MOBILE_PERF_MASTER_ROUTING(false)');await capture('sample_original_bus_repeat',6)
   await cmd('mode:audio_bus_fix');await capture('home_bus_fix',12);await page.screenshot(path=str(args.output/'home.png'))
   await cmd('plains');await page.wait_for_function("window.MOBILE_PERF_STATE?.state?.context==='plains' && window.MOBILE_PERF_STATE.state.foreground.effective_drawn>0",timeout=90000);await cmd('mode:audio_bus_fix');await capture('plains_bus_fix',12);await page.screenshot(path=str(args.output/'plains.png'))
   if args.runtime=='threaded':
    for r in results:
     stats=[s.get('underrun_stats') for s in r['after']['audio']['streams']];assert any(s and s.get('threads') for s in stats),stats
   assert not any('SCRIPT ERROR:' in x or 'SHADER ERROR:' in x or 'PAGE ERROR:' in x for x in logs),logs
  finally:
   (args.output/'browser.log').write_text('\n'.join(logs));await browser.close()
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--root-url',required=True);p.add_argument('--output',required=True,type=Path);p.add_argument('--runtime',choices=['single','threaded'],required=True);asyncio.run(main(p.parse_args()))
