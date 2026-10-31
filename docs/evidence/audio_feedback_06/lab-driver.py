import asyncio,json,pathlib,traceback
from playwright.async_api import async_playwright
OUT=pathlib.Path('build/audio_feedback_06/lab-qa-01');OUT.mkdir(exist_ok=False)
report={'status':'failed','scope':'Real local Chromium phone-sized GUI, staged exact06 portal; no physical device or hearing approval','checks':[]};logs=[]
def save():
 (OUT/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');(OUT/'console.log').write_text('\n'.join(logs)+'\n')
def check(ok,name,data=None):
 report['checks'].append({'name':name,'passed':bool(ok),'data':data});save();assert ok,name
async def main():
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox']);context=await browser.new_context(viewport={'width':390,'height':844},has_touch=True,accept_downloads=True);page=await context.new_page();page.on('pageerror',lambda e:logs.append('PAGE ERROR:'+str(e)))
  try:
   await page.goto('http://127.0.0.1:8830/feedback06/',wait_until='domcontentloaded');await page.wait_for_function('window.FEEDBACK06_STATS?.ready===true');await page.screenshot(path=str(OUT/'phone.png'),full_page=True)
   check(await page.locator('#new audio').count()==3 and await page.locator('audio').count()==7,'Phone portal renders three new and four comparison WAVs')
   async def delayed(route):await asyncio.sleep(1);await route.continue_()
   await page.route('**/feedback06/feedback.mp4',delayed)
   await page.locator('[data-chapter="hurt_a"]').click();await page.locator('#stop').click();await page.wait_for_timeout(1800)
   check(await page.locator('#reel').evaluate('(v)=>v.paused'),'Stop during MP4 fetch cannot start late playback')
   await page.unroute('**/feedback06/feedback.mp4',delayed)
   for letter,start,end in [('a',8.06,12.07),('b',12.06,16.07),('c',16.06,20.07)]:
    await page.locator('[data-chapter="hurt_'+letter+'"]').click();await page.wait_for_timeout(400);v=await page.locator('#reel').evaluate('(v)=>({paused:v.paused,time:v.currentTime,width:v.videoWidth,height:v.videoHeight,source:v.currentSrc,error:v.error?.code})')
    check(not v['paused'] and start<=v['time']<end and v['width']==960 and v['source'].startswith('blob:'),'Real native MP4 plays exact candidate chapter '+letter,v)
   await page.locator('#stop').click()
   for letter in ['a','b','c']:
    box=page.locator('[data-candidate-id="hurt_feedback_06_'+letter+'"]');await box.locator('input[type=checkbox]').check();await box.get_by_role('button',name='播放',exact=True).click();await page.wait_for_timeout(200);a=await box.locator('audio').evaluate('(a)=>({paused:a.paused,time:a.currentTime,loop:a.loop,duration:a.duration,error:a.error?.code})');active=await page.locator('audio').evaluate_all('(xs)=>xs.filter(a=>!a.paused).length');check(not a['paused'] and a['loop'] and a['duration']>0 and active==1,'Actual WAV loops with one active source '+letter,a)
   await page.locator('[data-chapter="hurt_b"]').click();await page.wait_for_timeout(250);check(await page.locator('audio').evaluate_all('(xs)=>xs.every(a=>a.paused)'),'Scene video stops all single-sound loops')
   await page.locator('#stop').click();check(await page.locator('#reel').evaluate('(v)=>v.paused') and await page.locator('audio').evaluate_all('(xs)=>xs.every(a=>a.paused)'),'Stop stops scene and every WAV')
   links=await page.locator('#new a.button').evaluate_all('(xs)=>xs.map(a=>a.getAttribute("href"))');check(links==['http://127.0.0.1:8830/game/?audio_hurt=A','http://127.0.0.1:8830/game/?audio_hurt=B','http://127.0.0.1:8830/game/?audio_hurt=C'],'A/B/C real-game links select the implemented presentation query',links)
   await page.locator('#choice').select_option('B');await page.locator('#notes').fill('phone browser QA fixture');d=await page.evaluate('JSON.parse(localStorage.getItem("audio-feedback-06-v1"))');check(d['candidate_id']=='hurt_feedback_06_b' and d['version']=='audio-feedback-06-v1' and len(d['candidate_sha256'])==64,'Choice stores exact candidate/version/SHA',d)
   async with page.expect_download() as download:await page.locator('#export').click()
   file=await download.value;await file.save_as(str(OUT/'choices.json'));choice=json.loads((OUT/'choices.json').read_text());check(choice['candidate_id']=='hurt_feedback_06_b','Actual JSON download preserves candidate identity')
   check(not logs and not (await page.evaluate('window.FEEDBACK06_STATS.mediaErrors')),'No page or media errors')
   report['status']='passed'
  except Exception as e:
   report['error']=str(e);report['traceback']=traceback.format_exc();await page.screenshot(path=str(OUT/'failure.png'),full_page=True)
  finally:save();await context.close();await browser.close()
 return report['status']=='passed'
raise SystemExit(0 if asyncio.run(main()) else 1)
