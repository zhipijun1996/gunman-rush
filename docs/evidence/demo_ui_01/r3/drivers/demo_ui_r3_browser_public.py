import asyncio,sys,os,json,hashlib,time,subprocess,csv,io
from pathlib import Path
ROOT=Path('/workspace/ui-workline');sys.path.insert(0,str(ROOT/'tools'))
from verify_forest_browser import locate,locate_original,norm,environment_proxy
from playwright.async_api import async_playwright
OUT=Path(sys.argv[2]);OUT.mkdir(parents=True,exist_ok=False)
URL=sys.argv[1]
def locate_cjk(path,phrase):
 import re
 normalize=lambda t: ''.join(x for x in t if x.isalnum()).upper()
 for mode in ['11','6']:
  output=subprocess.run(['tesseract',str(path),'stdout','--tessdata-dir','/workspace/toolchains/tessdata','-l','chi_sim+eng','--psm',mode,'-c','tessedit_create_tsv=1'],capture_output=True,text=True,check=True,timeout=15,env={**os.environ,'OMP_THREAD_LIMIT':'1'})
  path.with_suffix('.cjk'+mode+'.tsv').write_text(output.stdout)
  words=[r for r in csv.DictReader(io.StringIO(output.stdout),delimiter='\t') if normalize(r.get('text',''))];target=normalize(phrase)
  for start in range(len(words)):
   combined=''
   for end in range(start,min(start+18,len(words))):
    combined+=normalize(words[end]['text'])
    if combined==target:
     found=words[start:end+1];left=min(int(w['left']) for w in found);top=min(int(w['top']) for w in found);right=max(int(w['left'])+int(w['width']) for w in found);bottom=max(int(w['top'])+int(w['height']) for w in found)
     return (left+right)/2,(top+bottom)/2
    if not target.startswith(combined):break
 raise ValueError('Rendered CJK text missing: '+phrase)

def locate_primary(path):
 from PIL import Image
 pic=Image.open(path).convert('RGB');w,h=pic.size;points=[]
 for y in range(int(h*.08),int(h*.65)):
  row=[]
  for x in range(int(w*.025),int(w*.50)):
   r,g,b=pic.getpixel((x,y))
   if abs(r-195)<4 and abs(g-163)<4 and abs(b-102)<4:row.append(x)
  if len(row)>w*.12:points.append((y,min(row),max(row)))
 if len(points)<25:raise ValueError('Actual brass primary rectangle not found')
 return (min(x[1] for x in points)+max(x[2] for x in points))/2,(points[0][0]+points[-1][0])/2

def locate_pixel_control(path,phrase):
 from PIL import Image
 import numpy as np,scipy.ndimage as ndi
 pic=Image.open(path).convert('RGB');array=np.asarray(pic).astype(int)
 normalize=lambda t: ''.join(x for x in t if x.isalnum()).upper()
 target=normalize(phrase);cjk=any(0x3400<=ord(x)<=0x9fff for x in phrase)
 for color in [(41,58,59),(59,78,76),(195,163,102),(37,53,56)]:
  labels,_=ndi.label(np.max(np.abs(array-color),axis=2)<3)
  for bounds in ndi.find_objects(labels):
   if bounds is None:continue
   yy,xx=bounds;width=xx.stop-xx.start;height=yy.stop-yy.start
   if width<60 or height<28:continue
   roi=path.with_name(path.stem+'-control-'+str(xx.start)+'-'+str(yy.start)+'.png')
   pic.crop((xx.start,yy.start,xx.stop,yy.stop)).resize((width*3,height*3)).save(roi)
   args=['tesseract',str(roi),'stdout','--psm','7']
   if cjk:args+=['--tessdata-dir','/workspace/toolchains/tessdata','-l','chi_sim+eng','-c','tessedit_create_tsv=1']
   else:args+=['tsv']
   result=subprocess.run(args,capture_output=True,text=True,check=True,timeout=10,env={**os.environ,'OMP_THREAD_LIMIT':'1'})
   roi.with_suffix('.tsv').write_text(result.stdout)
   words=[normalize(r.get('text','')) for r in csv.DictReader(io.StringIO(result.stdout),delimiter='\t') if normalize(r.get('text',''))]
   for start in range(len(words)):
    for end in range(start+1,min(len(words),start+14)+1):
     if ''.join(words[start:end])==target:return (xx.start+xx.stop)/2,(yy.start+yy.stop)/2
 raise ValueError('Actual native button text missing from cropped pixel controls: '+phrase)

def native_surfaces(path,colors):
 from PIL import Image
 import numpy as np,scipy.ndimage as ndi
 pic=Image.open(path).convert('RGB');a=np.asarray(pic).astype(int);result=[]
 for color in colors:
  labels,_=ndi.label(np.max(np.abs(a-color),axis=2)<3)
  for bounds in ndi.find_objects(labels):
   if bounds is None:continue
   yy,xx=bounds;w=xx.stop-xx.start;h=yy.stop-yy.start
   if w>=60 and h>=28:result.append((xx.start,yy.start,xx.stop,yy.stop))
 return pic.size,result

def title_surface(path,index):
 (w,h),rectangles=native_surfaces(path,[(41,58,59),(59,78,76),(195,163,102)])
 rectangles=[r for r in rectangles if r[0]<w*.5 and r[2]-r[0]>w*.23 and r[3]-r[1]<h*.23 and r[1]<h*.86]
 rectangles.sort(key=lambda r:r[1])
 if len(rectangles)<4:raise ValueError('Four actual native title surfaces are not rendered')
 r=rectangles[index];return (r[0]+r[2])/2,(r[1]+r[3])/2

def touch_menu_surface(path):
 (w,h),rectangles=native_surfaces(path,[(37,53,56)])
 rectangles=[r for r in rectangles if r[0]>w*.5 and r[1]<h*.2 and r[2]-r[0]<w*.25]
 if not rectangles:raise ValueError('Actual top-right touch MENU surface not found')
 r=min(rectangles,key=lambda r:r[1]);return (r[0]+r[2])/2,(r[1]+r[3])/2

def locate_any(path,phrase):
 if phrase=="设定":return title_surface(path,2)
 if phrase=="新手教程":return title_surface(path,3)
 if phrase=="菜单":return touch_menu_surface(path)
 if phrase=="开始游戏":return locate_primary(path)
 try:return locate_pixel_control(path,phrase)
 except ValueError:pass
 if any(0x3400<=ord(x)<=0x9fff for x in phrase):return locate_cjk(path,phrase)
 try:return locate(path,phrase)
 except ValueError as first:
  output=subprocess.run(['tesseract',str(path),'stdout','--psm','6','tsv'],capture_output=True,text=True,check=True,timeout=10,env={**os.environ,'OMP_THREAD_LIMIT':'1'})
  path.with_suffix('.psm6.tsv').write_text(output.stdout)
  words=[r for r in csv.DictReader(io.StringIO(output.stdout),delimiter='\t') if norm(r.get('text',''))];target=norm(phrase)
  for start in range(len(words)):
   combined=''
   for end in range(start,min(start+12,len(words))):
    combined+=norm(words[end]['text'])
    if combined==target:
     found=words[start:end+1];left=min(int(w['left']) for w in found);top=min(int(w['top']) for w in found);right=max(int(w['left'])+int(w['width']) for w in found);bottom=max(int(w['top'])+int(w['height']) for w in found)
     return (left+right)/2,(top+bottom)/2
    if not target.startswith(combined):break
  from PIL import Image,ImageOps
  binary=path.with_suffix('.binary.png');original=Image.open(path).convert('L');ImageOps.invert(original.point(lambda v:255 if v>140 else 0)).save(binary)
  try:return locate_original(binary,phrase)
  except ValueError:pass
  # Isolate the rendered navigation label from the noisy gameplay background for OCR.
  if phrase == 'EXPLORE':
   from PIL import Image,ImageOps
   pic=Image.open(path);left=int(pic.width*.7);crop=path.with_suffix('.nav.png');pic.crop((left,0,pic.width,int(pic.height*.2))).resize((int((pic.width-left)*3),int(pic.height*.2)*3)).save(crop)
   processed=Image.open(crop).convert('L');ImageOps.invert(processed.point(lambda v:255 if v>140 else 0)).save(crop)
   try:
    x,y=locate(crop,phrase);return left+x/3,y/3
   except ValueError:pass
  raise first
async def main():
 report={'source_commit':'8dc2f4e6a2c6f511c22004784cb71b5f3d0d7a96','build_id':'5e9adddb1662','driver_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'observed_at_unix':time.time(),'url':URL,'checks':[],'errors':[],'contexts':{},'scope':'Real exported Godot canvas via desktop mouse and emulated mobile DOM touch. No engine hooks or physical-device claim. Main title and touch MENU coordinates use native material component bounds after actual pixel inspection and native exact-label/route checks. Latin button OCR uses isolated rendered controls. No engine hooks, synthetic click signals or decorative-logo OCR.'}
 globals()['LAST_REPORT']=report
 async with async_playwright() as p:
  browser=await p.chromium.launch(proxy=environment_proxy()[0] if '127.0.0.1' not in URL and 'localhost' not in URL else None, executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'],timeout=30000)
  report['browser_version']=browser.version
  for mobile in ([True] if len(sys.argv)>3 and sys.argv[3]=="mobile" else [False] if len(sys.argv)>3 and sys.argv[3]=="desktop" else [False,True]):
   name='mobile' if mobile else 'desktop';w,h=(844,390) if mobile else (1280,720)
   context=await browser.new_context(viewport={'width':w,'height':h},has_touch=mobile,is_mobile=mobile,device_scale_factor=1)
   page=await context.new_page();events=[];console=[];report['contexts'][name]={'console':console,'events':events}
   def log(m):
    s=m.text;console.append(s)
    if 'FOREST_UI_EVENT ' in s:
     try:events.append(json.loads(s.split('FOREST_UI_EVENT ',1)[1]))
     except:pass
    if any(x in s for x in ['SCRIPT ERROR','Parse Error','ERROR:']):report['errors'].append(name+': '+s)
   page.on('console',log);page.on('pageerror',lambda e:report['errors'].append(name+': '+str(e)))
   await page.goto(URL,wait_until='networkidle',timeout=60000)
   await page.wait_for_function('window.PLAYTEST_LOADING_DONE===true',timeout=60000)
   await page.wait_for_timeout(500)
   async def capture(label):
    path=OUT/(name+'-'+label+'.png')
    from PIL import Image,ImageStat
    for retry in range(4):
     await page.screenshot(path=str(path))
     mean=ImageStat.Stat(Image.open(path).convert('L').crop((w*.15,h*.12,w*.85,h*.85))).mean[0]
     if mean>=5:break
     path.rename(path.with_name(path.stem+'-empty-buffer-'+str(retry)+'.png'));await page.wait_for_timeout(200)
    if not path.exists():await page.screenshot(path=str(path))
    return path
   async def tap_point(point):
    if mobile:await page.touchscreen.tap(*point)
    else:await page.mouse.click(*point)
    await page.wait_for_timeout(250)
   async def scroll(down=True):
    if mobile:
     client=await context.new_cdp_session(page);x=w*.125;y0=h*.70 if down else h*.30;y1=h*.30 if down else h*.70
     pic=await capture('swipe-origin')
     for label in ['Movement sensitivity','Aim sensitivity','Touch deadzone','Game volume','Touch movement','Touch movement']:
      try:
       x,y0=locate_any(pic,label);y1=max(h*.12,y0-h*.4) if down else min(h*.85,y0+h*.4);break
      except ValueError:pass
     await client.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[{'x':x,'y':y0,'id':70}]})
     for i in range(1,7):
      await client.send('Input.dispatchTouchEvent',{'type':'touchMove','touchPoints':[{'x':x,'y':y0+(y1-y0)*i/6,'id':70}]});await page.wait_for_timeout(20)
     await client.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]});await client.detach()
    else:
     await page.mouse.move(w*.5,h*.7);await page.mouse.wheel(0,240 if down else -240)
    await page.wait_for_timeout(180)
    if mobile:
     count=len(list(OUT.glob('mobile-scroll-*.png')));await capture('scroll-'+str(count))
     state=await page.evaluate('({scrollY,scrollX,dpr:devicePixelRatio,canvas:(()=>{const c=document.getElementById("canvas");return {rect:c.getBoundingClientRect().toJSON(),width:c.width,height:c.height}})(),viewport:{width:visualViewport.width,height:visualViewport.height,scale:visualViewport.scale,offsetLeft:visualViewport.offsetLeft,offsetTop:visualViewport.offsetTop}})')
     (OUT/('mobile-scroll-'+str(count)+'.json')).write_text(json.dumps(state))
   async def click(phrase,label,scrolling=False):
    error=None
    for attempt in range(12 if scrolling else 1):
     path=await capture(label+'-'+str(attempt))
     try:point=locate_any(path,phrase)
     except ValueError as e:
      error=e
      if not scrolling:raise
      await scroll(True);continue
     await tap_point(point);return
    raise error
   async def has(phrase,label):
    try:locate_any(await capture(label),phrase);return True
    except ValueError:return False
   def check(value,msg):
    report['checks'].append({'device':name,'passed':bool(value),'assertion':msg})
    if not value:raise AssertionError(name+': '+msg)
   check(await has('设定','title') and await has('新手教程','title-tutorial') and await has('开始游戏','title-primary'),'four rendered native title surfaces and primary match inspected source-bound menu; actual subsequent click verifies route')
   await click('设定','settings-entry',True)
   check(await has('Touch movement','settings'),'actual settings page opened')
   # Scroll and native popup item selection use actual OCR text coordinates.
   await click('Walk Run','movement-picker',True)
   await click('Analog speed','analog-option')
   check(await has('Analog speed','selected-mode') and not await has('Walk Run','popup-closed'),'actual popup item accepted by pointer and popup closed')
   # APPLY also occurs in the explanatory paragraph; scroll to the actual footer button.
   for _ in range(8):
    if await has('RESTORE DEFAULTS','footer-search'):break
    await scroll(True)
   await click('APPLY','apply',True)
   check(await has('Applied','applied'),'actual validated settings Apply feedback')
   await click('BACK','back',True)
   # Title focus restoration may retain a scrolled caller; scroll upward to primary.
   for _ in range(8):
    if await has('开始游戏','primary-search'):break
    await scroll(False)
   await click('开始游戏','begin')
   end=time.monotonic()+30
   while time.monotonic()<end and not any(e.get('event')=='region_assembled' and e.get('region')=='plains' for e in events):await page.wait_for_timeout(100)
   check(any(e.get('event')=='region_assembled' and e.get('region')=='plains' for e in events),'primary assembled actual formal Plains')
   await page.wait_for_timeout(500);await capture('actual-hud')
   await click('菜单' if mobile else 'MENU','menu')
   check(await has('RESUME','pause'),'real MENU opened pause')
   await click('SETTINGS','pause-settings',True)
   await page.keyboard.press('Escape');await page.wait_for_timeout(300)
   check(await has('RESUME','pause-return'),'settings Escape returns to pause')
   await click('RESUME','resume',True)
   await click('EXPLORE','map-chip')
   check(await has('FIND ME','map'),'real fog map opened')
   await click('ZOOM +','zoom',True)
   await click('CLOSE MAP','map-close',True)
   check(await has('菜单' if mobile else 'MENU','resumed'),'map close returns actual HUD')
   if not mobile:
    await page.keyboard.down('Space');await page.wait_for_timeout(120);await page.keyboard.up('Space')
    await page.mouse.move(w*.5,h*.86);await page.mouse.down();await page.wait_for_timeout(350)
    await capture('actual-time-energy-ring');await page.mouse.up();await page.wait_for_timeout(120)
    await capture('actual-shot-after-ring')
   await page.keyboard.press('Space');await page.wait_for_timeout(200)
   check(not await has('FIND ME','post-map-jump'),'first post-map Space does not reopen UI')
   if mobile:
    # DOM cancellation through the existing adapter; canceled menu touch must not activate.
    await click('菜单' if mobile else 'MENU','cancel-menu');await page.wait_for_timeout(200)
    pic=await capture('before-touchcancel');point=locate_any(pic,'RESUME')
    client=await context.new_cdp_session(page)
    await client.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[{'x':point[0],'y':point[1],'id':91}]})
    await client.send('Input.dispatchTouchEvent',{'type':'touchCancel','touchPoints':[]});await client.detach();await page.wait_for_timeout(300)
    check(await has('RETURN TO HOME','after-touchcancel') and await has('CONTROLS','after-touchcancel-controls'),'DOM touchcancel retains actual pause menu without activating Resume')
   (OUT/(name+'-console.json')).write_text(json.dumps(console,ensure_ascii=False,indent=2)+'\n')
   (OUT/(name+'-events.json')).write_text(json.dumps(events,ensure_ascii=False,indent=2)+'\n')
   await context.close()
  await browser.close()
 report['failed']=len(report['errors'])+sum(not c['passed'] for c in report['checks']);(OUT/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False))
 raise SystemExit(bool(report['failed']))
try:asyncio.run(main())
except Exception as e:
 (OUT/'partial-report.json').write_text(json.dumps(globals().get('LAST_REPORT',{}),ensure_ascii=False,indent=2)+'\n')
 (OUT/'failure.json').write_text(json.dumps({'error':str(e),'scope':'Browser run failed; no broader GUI PASS'},ensure_ascii=False,indent=2)+'\n');raise
