import asyncio,json,pathlib,sys,traceback,subprocess
from playwright.async_api import async_playwright
ROOT=pathlib.Path.cwd();sys.path.insert(0,str(ROOT/'tools'))
from verify_mobile_ui_clarity_browser import surfaces
OUT=ROOT/'build/audio_feedback_06/web-qa-03';OUT.mkdir(exist_ok=False)
OBSERVER="(() => {\n  const contexts=new Map(), taps=new WeakSet(), connect=AudioNode.prototype.connect;\n  AudioNode.prototype.connect=function(...args){\n    if(args[0] instanceof AudioDestinationNode && !taps.has(this)){\n      const context=this.context;\n      if(!contexts.has(context)){\n        const analyser=context.createAnalyser();analyser.fftSize=2048;taps.add(analyser);\n        connect.call(analyser,args[0]);\n        const row={analyser,states:[{state:context.state,time:performance.now()}]};\n        contexts.set(context,row);context.addEventListener('statechange',()=>row.states.push({state:context.state,time:performance.now()}));\n      }\n      return connect.call(this,contexts.get(context).analyser,...args.slice(1));\n    }\n    return connect.apply(this,args);\n  };\n  window.__fourLineNativeAudio=()=>Array.from(contexts,([context,row])=>{\n    const a=new Float32Array(row.analyser.fftSize);row.analyser.getFloatTimeDomainData(a);\n    let sum=0,peak=0;for(const v of a){sum+=v*v;peak=Math.max(peak,Math.abs(v));}\n    return {state:context.state,current_time:context.currentTime,sample_rate:context.sampleRate,rms:Math.sqrt(sum/a.length),peak,states:row.states};\n  });\n})();"
report={'status':'failed','source_commit':'d8a894c28957aca4f5b7ab1bd55827d4f93259c7','build':'80377273a40d','scope':'CDP Runtime.evaluate userGesture=false before any trusted input; passive inline analyser only (no MediaRecorder or MediaStream destination); real local Chromium, exact staged chunk-only package over normal HTTP; explicit allowed/blocked autoplay policies, trusted touches. No private deployed-origin/physical-phone/aesthetic claim.','checks':[]};logs=[]
def save():
 (OUT/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');(OUT/'console.log').write_text('\n'.join(logs)+'\n')
def check(ok,name,data=None):
 report['checks'].append({'name':name,'passed':bool(ok),'data':data});save();assert ok,name
async def main():
 async with async_playwright() as p:
  for allowed in [True,False]:
   label='allowed' if allowed else 'blocked'
   policy='no-user-gesture-required' if allowed else 'document-user-activation-required'
   browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader','--autoplay-policy='+policy,'--disable-features=PreloadMediaEngagementData,MediaEngagementBypassAutoplayPolicies'])
   context=await browser.new_context(viewport={'width':960,'height':540},device_scale_factor=1,has_touch=True)
   await context.add_init_script(OBSERVER);page=await context.new_page();cdp=await context.new_cdp_session(page);page.on('console',lambda m:logs.append(label+':'+m.type+':'+m.text));page.on('pageerror',lambda e:logs.append('PAGE ERROR:'+str(e)))
   async def passive(expression):
    r=await cdp.send('Runtime.evaluate',{'expression':expression,'returnByValue':True,'userGesture':False})
    if 'exceptionDetails' in r:raise RuntimeError(str(r['exceptionDetails']))
    return r.get('result',{}).get('value')
   async def snap():return await passive('({ready:window.PLAYTEST_LOADING_DONE===true,sfx:window.SELECTED_SFX_SNAPSHOT,ambience:window.SELECTED_AMBIENCE_SNAPSHOT,pcm:window.__fourLineNativeAudio?.()||[],coi:crossOriginIsolated,sab:typeof SharedArrayBuffer!=="undefined",activation:{active:navigator.userActivation.isActive,ever:navigator.userActivation.hasBeenActive}})')
   async def window_pcm(seconds=2):
    rows=[]
    for i in range(int(seconds*5)):
     rows.append(await passive('window.__fourLineNativeAudio?.()||[]'));await asyncio.sleep(.2)
    return rows
   try:
    candidate='A' if allowed else 'B'
    await page.goto('http://127.0.0.1:8830/game/?audio_probe=1&audio_hurt='+candidate,wait_until='domcontentloaded')
    for attempt in range(360):
     state=await snap()
     if state and state.get('ready') and state.get('sfx',{}).get('validation_ok'):break
     await asyncio.sleep(.5)
    else:raise RuntimeError('Cold game did not become ready within180s')
    await page.wait_for_timeout(1200);before=await snap();title=OUT/(label+'-title.png');await page.screenshot(path=str(title))
    check(not before['activation']['ever'] and not before['activation']['active'],label+' initial observation has no browser user activation',before['activation'])
    check(before['coi'] and before['sab'],label+' cold chunk-only game obtains COI/SAB',before)
    check(before['sfx']['candidate_revisions']['hurt']['id']=='hurt_feedback_06_'+candidate.lower(),label+' actual Web assembly uses explicit new hurt direction '+candidate,before['sfx'])
    pcm=await window_pcm(3)
    if allowed:
     check(any(v.get('peak',0)>1e-5 for row in pcm for v in row),'Allowed autoplay: title produces real BGM PCM before any user input',pcm)
    else:
     check(bool(before['pcm']) and all(v['state']=='suspended' for v in before['pcm']) and all(v.get('peak',0)==0 for row in pcm for v in row),'Blocked autoplay: real suspended context remains silent before trusted input',pcm)
     await page.touchscreen.tap(22,480)
     resumed=await window_pcm(3)
     check(any(v.get('peak',0)>1e-5 and v.get('state')=='running' for row in resumed for v in row),'Blocked autoplay: first real background touch resumes original title BGM',resumed)
    check((await snap())['ambience']['active_context']=='',label+' stays on title without a dedicated music enable button')
    shot=OUT/(label+'-title-ready.png');await page.screenshot(path=str(shot));primary=surfaces(shot,[(195,163,102)])[0]
    await page.touchscreen.tap(primary[0]+primary[2]/2,primary[1]+primary[3]/2)
    await page.wait_for_function('window.SELECTED_AMBIENCE_SNAPSHOT?.active_context==="home"',timeout=45000)
    home=await window_pcm(3);await page.screenshot(path=str(OUT/(label+'-home.png')))
    check(any(v.get('peak',0)>1e-5 for row in home for v in row),label+' same title session reaches Home with actual native audio',home)
    if allowed:
     await page.keyboard.press('Space');await page.wait_for_timeout(900);await page.mouse.move(470,300);await page.mouse.down();await page.wait_for_timeout(300);await page.mouse.move(470,480);await page.mouse.up();await page.wait_for_timeout(1800)
     state=await snap();check(any(e.get('id')=='shot_pulse' and e.get('candidate')=='shot_pulse_a' for e in state['sfx']['director_events']),'Real Home action retains selected pulse A',state['sfx']['director_events'])
    check(not any('SCRIPT ERROR:' in x or 'SHADER ERROR:' in x or 'PAGE ERROR:' in x for x in logs),label+' no script/shader/page errors')
   except Exception as e:
    report['error']=label+': '+str(e);report['traceback']=traceback.format_exc();await page.screenshot(path=str(OUT/(label+'-failure.png')),full_page=True);save();await context.close();await browser.close();return False
   await context.close();await browser.close()
  report['status']='passed';save();return True
sys.exit(0 if asyncio.run(main()) else 1)
