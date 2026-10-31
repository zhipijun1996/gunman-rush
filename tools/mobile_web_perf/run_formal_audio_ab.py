"""Fresh real demo.tscn main1b audio A/B, with normal touch actions and mixed WAV.

Frame metrics and audio output are independent observations. Does not infer a
physical phone's rendering performance from cloud SwiftShader.
"""
import argparse,asyncio,base64,json,sys
from pathlib import Path
from playwright.async_api import async_playwright
sys.path.insert(0,str(Path(__file__).resolve().parents[1]));from verify_mobile_ui_clarity_browser import surfaces
from run_ab import summarize
from run_minimal import RECORDER_INIT,pcm_wav

async def run(args):
 args.output.mkdir(parents=True,exist_ok=False);all_results=[]
 async with async_playwright() as p:
  for case in args.cases.split(','):
   folder=args.output/case;folder.mkdir();logs=[];results=[]
   browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
   context=await browser.new_context(viewport={'width':853,'height':290},device_scale_factor=2.5,is_mobile=True,has_touch=True)
   await context.add_init_script(RECORDER_INIT);page=await context.new_page();page.on('console',lambda m:logs.append(m.type+':'+m.text));page.on('pageerror',lambda e:logs.append('PAGE ERROR:'+str(e)))
   cdp=await context.new_cdp_session(page)
   async def command(value):
    await page.evaluate('(v)=>window.MOBILE_PERF_COMMAND=v',value);await page.wait_for_function("window.MOBILE_PERF_COMMAND===''",timeout=20000)
   async def observation():return await page.evaluate('({state:window.MOBILE_PERF_STATE.state,audio:window.MOBILE_AUDIO_PROBE.snapshot(),graph:window.MOBILE_AUDIO_GRAPH_PROBE.snapshot(),gpu:window.MOBILE_GPU_PROBE.snapshot()})')
   def save():
    (folder/'report.json').write_text(json.dumps({'case':case,'results':results,'logs':logs,'scope':'fresh original demo.tscn/main1b diagnostic derivative; fixed viewport853x290DPR2.5/plains-run; not physical phone'},indent=2))
    (args.output/'report.json').write_text(json.dumps({'source_main':'1b29932c5333a9dad50759afc635762163ed79f5','baseline_pack':'618eb97114e6','viewport':[853,290],'dpr':2.5,'cases':all_results,'scope':'original/bus-only/pause-only/selected-ambience-off; frame and output observations separate'},indent=2))
   async def capture(scene,phase,seconds):
    start=await observation();n=await page.evaluate('window.MOBILE_PERF_RESULTS.length');await command('seconds:'+str(seconds));await command('capture');await page.wait_for_function('(n)=>window.MOBILE_PERF_RESULTS.length>n',arg=n,timeout=int((seconds+30)*1000));row=await page.evaluate('window.MOBILE_PERF_RESULTS.at(-1)');row.update(case=case,scene=scene,phase=phase,before=start,after=await observation());results.append(row);all_results.append({'case':case,'scene':scene,'phase':phase,'summary':summarize(row)});save();print(json.dumps(all_results[-1]),flush=True)
   async def page_point(projected):
    c=await page.locator('canvas').evaluate('(c)=>({left:c.getBoundingClientRect().left,top:c.getBoundingClientRect().top,width:c.getBoundingClientRect().width,height:c.getBoundingClientRect().height,backing_width:c.width,backing_height:c.height})')
    st=await page.evaluate('window.MOBILE_PERF_STATE.state.viewport_observation.screen_transform')
    physical=[st['origin'][0]+projected[0]*st['scale'][0],st['origin'][1]+projected[1]*st['scale'][1]]
    return {'x':c['left']+physical[0]*c['width']/c['backing_width'],'y':c['top']+physical[1]*c['height']/c['backing_height']}
   async def action_audio(scene):
    before=await observation();key=case+'-'+scene+'-action'
    touch=before['state']['touch_observation'];jump=await page_point(touch['screen_logical']['jump_center']);right=await page_point(touch['screen_logical']['right_center']);radius_point=await page_point([touch['screen_logical']['right_center'][0]+touch['screen_logical']['radius_axes'][0],touch['screen_logical']['right_center'][1]]);radius=abs(radius_point['x']-right['x'])
    await page.evaluate("id=>window.MINIMAL_PCM_TAPS[0].port.postMessage({cmd:'minimal_begin',id,frames:Math.round(window.MINIMAL_PCM_TAPS[0].context.sampleRate*8)})",key);await page.wait_for_function('id=>window.MINIMAL_PCM_READY[id]===true',arg=key,timeout=8000,polling=50)
    await page.touchscreen.tap(jump['x'],jump['y']);await page.wait_for_timeout(650)
    await cdp.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[{'id':11,'x':right['x'],'y':right['y']}]});await cdp.send('Input.dispatchTouchEvent',{'type':'touchMove','touchPoints':[{'id':11,'x':right['x']+radius*.6,'y':right['y']}]});await page.wait_for_timeout(450);await cdp.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]})
    await page.wait_for_function('id=>!!window.MINIMAL_PCM_RECORDINGS[id]',arg=key,timeout=20000)
    raw=await page.evaluate("""id=>{const r=window.MINIMAL_PCM_RECORDINGS[id],data=new Uint8Array(r.samples.buffer);let text='';for(let i=0;i<data.length;i+=32768)text+=String.fromCharCode(...data.subarray(i,i+32768));return {base64:btoa(text),metadata:{sample_rate:r.sample_rate,channels:r.channels,frames:r.frames,begin_audio_frame:r.start_audio_frame??r.begin_audio_frame??(r.end_audio_frame-r.frames),end_audio_frame:r.end_audio_frame}}}""",key)
    wav=pcm_wav(raw['base64'],raw['metadata'],folder/(scene+'-actions.wav'));after=await observation();entry={'case':case,'scene':scene,'phase':'native_touch_jump_shoot','before':before,'after':after,'pcm':wav,'native_input':{'jump':jump,'right':right,'drag_dx':radius*.6,'hold_ms':450}};results.append(entry);save();print('ACTIONS',case,scene,json.dumps({'before':before['state']['action_observation'],'after':after['state']['action_observation'],'pcm_peak':wav['peak_float32']}),flush=True)
   try:
    await page.goto(args.root_url+'?case='+case,wait_until='domcontentloaded');await page.wait_for_function('window.READY===true && window.MOBILE_PERF_READY===true',timeout=180000);await page.wait_for_timeout(1000);await page.screenshot(path=str(folder/'title.png'));b=surfaces(folder/'title.png',[(195,163,102)])[0];await page.touchscreen.tap((b[0]+b[2]/2)/2.5,(b[1]+b[3]/2)/2.5);await page.wait_for_function("window.MOBILE_PERF_STATE?.state?.context==='home'",timeout=45000)
    for scene in ['home','plains']:
     if scene=='plains':
      await command('plains');await page.wait_for_function("window.MOBILE_PERF_STATE?.state?.context==='plains'",timeout=90000)
     await page.wait_for_timeout(args.warm_seconds*1000);await page.screenshot(path=str(folder/(scene+'-idle.png')))
     if not args.action_only:await capture(scene,'idle',args.seconds)
     await action_audio(scene);await page.wait_for_timeout(1500)
     if args.action_only:continue
     state=await page.evaluate('window.MOBILE_PERF_STATE.state');pause=state['touch_observation']['screen_logical']['pause_rect'];center=await page_point([pause[0]+pause[2]/2,pause[1]+pause[3]/2]);await page.touchscreen.tap(center['x'],center['y']);await page.wait_for_timeout(1800);await page.screenshot(path=str(folder/(scene+'-menu.png')));await capture(scene,'menu',6)
     await page.keyboard.press('Escape');await page.wait_for_timeout(1200)
    assert not any('SCRIPT ERROR:' in x or 'SHADER ERROR:' in x or 'PAGE ERROR:' in x for x in logs),logs
    if case=='ambience_off':
     for r in results:
      s=r['after']['state']['selected_ambience'];assert s['configurations']==0 and s['active_context']=='',s
   finally:
    save();(folder/'browser.log').write_text('\n'.join(logs));await browser.close()

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root-url',required=True);p.add_argument('--output',required=True,type=Path);p.add_argument('--cases',default='original,bus_only,pause_only,ambience_off');p.add_argument('--seconds',type=float,default=10);p.add_argument('--warm-seconds',type=float,default=5);p.add_argument('--action-only',action='store_true');asyncio.run(run(p.parse_args()))
