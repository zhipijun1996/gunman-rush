"""Bounded A/B measurements on the actual exported game diagnostic copy.

No concurrent Godot/browser runs during measurements. Each knockout restores
baseline first, with warmup and paired baselines. Raw samples remain authoritative.
"""
import argparse,asyncio,json,statistics,sys,time
from pathlib import Path
from playwright.async_api import async_playwright
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from verify_mobile_ui_clarity_browser import surfaces

INIT='''(() => {window.FRAME_SAMPLES=[];let previous=0;function frame(now){if(previous)window.FRAME_SAMPLES.push([now,now-previous]);previous=now;if(window.FRAME_SAMPLES.length>40000)window.FRAME_SAMPLES.shift();requestAnimationFrame(frame)}requestAnimationFrame(frame);window.LONG_TASKS=[];try{new PerformanceObserver(list=>{for(const e of list.getEntries())window.LONG_TASKS.push([e.startTime,e.duration]);}).observe({entryTypes:['longtask']})}catch(e){}})();'''

def percentile(values,q):
 values=sorted(values)
 return values[round((len(values)-1)*q)] if values else None

def summarize(row):
 frames=row['frames'];times=[r[0] for r in frames];n=len(times)
 return {'sequence':row['sequence'],'context':row['final']['context'],'mode':row['mode'],'frames':n,'fps':n/(row['elapsed_msec']/1000) if row['elapsed_msec'] else None,'p50_ms':percentile(times,.50),'p95_ms':percentile(times,.95),'process_p50_ms':percentile([r[1] for r in frames],.5),'physics_p50_ms':percentile([r[2] for r in frames],.5),'draw_calls_mean':statistics.mean(r[3] for r in frames) if n else None,'objects_mean':statistics.mean(r[4] for r in frames) if n else None,'primitives_mean':statistics.mean(r[5] for r in frames) if n else None,'top_inclusive_costs':sorted([{'name':k,'ms_per_frame':v[0]/1000/max(1,n),'ms_per_call':v[0]/1000/max(1,v[1]),'calls':v[1],'max_ms':v[2]/1000}for k,v in row['costs'].items()],key=lambda c:-c['ms_per_frame'])[:12],'audio_requests':len(row['audio_events']),'audio_accepted':sum(e['accepted'] for e in row['audio_events']),'audio_drops':{reason:sum(not e['accepted'] and e['reason']==reason for e in row['audio_events'])for reason in set(e['reason'] for e in row['audio_events'] if not e['accepted'])},'fg':row['final']['foreground'],'lights':row['final']['lights_enabled'],'shadows':row['final']['shadows_enabled'],'tree_paused':row['final']['tree_paused']}

async def run(args):
 args.output.mkdir(parents=True,exist_ok=False);logs=[];results=[];summaries=[];snapshots=[]
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  context=await browser.new_context(viewport={'width':853,'height':290},device_scale_factor=2.5,is_mobile=True,has_touch=True)
  await context.add_init_script(INIT);page=await context.new_page()
  page.on('console',lambda m:logs.append(m.type+': '+m.text));page.on('pageerror',lambda e:logs.append('PAGE ERROR:'+str(e)))
  try:
   await page.goto(args.root_url,wait_until='domcontentloaded');await page.wait_for_function('window.READY===true && window.MOBILE_PERF_READY===true',timeout=180000)
   await page.wait_for_timeout(1500);title=args.output/'title.png';await page.screenshot(path=str(title));box=surfaces(title,[(195,163,102)])[0]
   await page.touchscreen.tap((box[0]+box[2]/2)/2.5,(box[1]+box[3]/2)/2.5)
   await page.wait_for_function("window.MOBILE_PERF_STATE?.state?.context==='home' && window.MOBILE_PERF_STATE.state.foreground.effective_drawn>0",timeout=45000)
   gpu=await page.locator('canvas').evaluate('''c=>{const g=c.getContext('webgl2');if(!g)return {unavailable:true};const d=g.getExtension('WEBGL_debug_renderer_info');return {renderer:d?g.getParameter(d.UNMASKED_RENDERER_WEBGL):g.getParameter(g.RENDERER),gpu_timer_supported:!!g.getExtension('EXT_disjoint_timer_query_webgl2'),gpu_time_ms:null,canvas:[c.width,c.height],note:'Draw counters via Godot; GPU time not inferred from FPS'}}''')
   cdp=await context.new_cdp_session(page);await cdp.send('Performance.enable')
   async def command(value):
    await page.evaluate('(v)=>window.MOBILE_PERF_COMMAND=v',value)
    await page.wait_for_function("window.MOBILE_PERF_COMMAND===''",timeout=20000)
   async def audio():return await page.evaluate('window.MOBILE_AUDIO_PROBE?.snapshot()||null')
   schedule=['baseline','ambience_off','baseline','foreground_render_off','baseline','foreground_update_off','baseline','shadows_off','baseline','hud_avoidance_off','baseline','lights_off','baseline','menu','baseline']
   if args.schedule:schedule=args.schedule.split(',')
   if args.quick:schedule=['baseline','foreground_update_off','baseline','shadows_off','baseline','lights_off','baseline']
   for scene in args.scenes.split(','):
    if scene=='plains':
     await command('plains');await page.wait_for_function("window.MOBILE_PERF_STATE?.state?.context==='plains' && window.MOBILE_PERF_STATE.state.foreground.effective_drawn>0",timeout=90000)
    if args.lamp_view and scene=='plains':
     await command('lamp_view');await page.wait_for_timeout(5000)
    for index,mode in enumerate(schedule):
     await command('mode:'+mode)
     await page.wait_for_function('(m)=>window.MOBILE_PERF_STATE?.state?.mode===m',arg=mode,timeout=20000)
     await page.wait_for_timeout(args.warm_seconds*1000)
     state=await page.evaluate('window.MOBILE_PERF_STATE.state')
     if mode=='foreground_update_off':assert state['foreground']['effective_drawn']>0,state
     begin_audio=await audio();begin_cdp=await cdp.send('Performance.getMetrics');start=await page.evaluate('performance.now()');before=await page.evaluate('window.MOBILE_PERF_RESULTS.length')
     await command('seconds:'+str(args.seconds));await command('capture')
     await page.wait_for_timeout(2200);await command('cue_coin')
     await page.wait_for_function('(n)=>window.MOBILE_PERF_RESULTS.length>n',arg=before,timeout=int((args.seconds+30)*1000))
     row=await page.evaluate('window.MOBILE_PERF_RESULTS.at(-1)');row['audio_begin']=begin_audio;row['audio_end']=await audio();row['browser_raf']=await page.evaluate('(t)=>window.FRAME_SAMPLES.filter(v=>v[0]>=t)',start);row['long_tasks']=await page.evaluate('(t)=>window.LONG_TASKS.filter(v=>v[0]>=t)',start);row['cdp_begin']=begin_cdp;row['cdp_end']=await cdp.send('Performance.getMetrics');row['gpu']=gpu;row['gpu_timers']=await page.evaluate('window.MOBILE_GPU_PROBE?.snapshot()||null');row['cue_fixture']='one explicit audio-only coin request, no wallet/pickup mutation'
     assert row['final']['context']==scene,row['final']
     results.append(row);summaries.append(summarize(row));print(json.dumps(summaries[-1]),flush=True)
     (args.output/'report.json').write_text(json.dumps({'scope':'Cloud Chromium SwiftShader; screen/DPR simulation, NOT Honor/Huawei timing','source':'4707b9ef15fa7e89b09d3e33ef8206c0b12f64af','gpu':gpu,'results':results,'summary':summaries,'logs':logs},indent=2))
     if mode not in ['ambience_off','baseline']:await page.screenshot(path=str(args.output/(scene+'-'+str(index)+'-'+mode+'.png')))
   assert not any('SCRIPT ERROR:' in x or 'Parse Error:' in x or 'SHADER ERROR:' in x or 'PAGE ERROR:' in x for x in logs),logs
  finally:
   (args.output/'browser.log').write_text('\n'.join(logs));await browser.close()

if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--root-url',required=True);parser.add_argument('--output',required=True,type=Path);parser.add_argument('--seconds',type=float,default=10);parser.add_argument('--scenes',default='home,plains');parser.add_argument('--schedule');parser.add_argument('--warm-seconds',type=float,default=3);parser.add_argument('--lamp-view',action='store_true');parser.add_argument('--quick',action='store_true');asyncio.run(run(parser.parse_args()))
