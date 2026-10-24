import asyncio,argparse,csv,io,json,os,re,shutil,statistics,subprocess,sys,time,urllib.request
from pathlib import Path
from urllib.parse import urlparse,urljoin
from PIL import Image
from playwright.async_api import async_playwright
p=argparse.ArgumentParser();p.add_argument('--url',required=True);p.add_argument('--source',required=True);p.add_argument('--build',required=True);p.add_argument('--output',required=True);p.add_argument('--cases',default='desktop1,desktop2,mobile3');a=p.parse_args()
OUT=Path(a.output);OUT.mkdir(parents=True,exist_ok=False)
with urllib.request.urlopen(urljoin(a.url,'build-info.json'),timeout=20) as r:info=json.load(r)
assert info['source_commit']==a.source and info['build_id']==a.build,info
(OUT/'public-build-info.json').write_text(json.dumps(info,indent=2)+'\n')
def norm(x):return re.sub('[^A-Z0-9]','',x.upper())
def locate(path,phrase):
 pic=Image.open(path)
 for factor in [1,3]:
  target=path
  if factor!=1:
   target=path.with_name(path.stem+'-ocr3.png');pic.resize((pic.width*factor,pic.height*factor)).save(target)
  for psm in ['11','6']:
   result=subprocess.run(['tesseract',str(target),'stdout','--psm',psm,'tsv'],capture_output=True,text=True,check=True,timeout=15,env={**os.environ,'OMP_THREAD_LIMIT':'1'})
   (path.with_suffix('.ocr'+str(factor)+'-'+psm+'.tsv')).write_text(result.stdout)
   words=[x for x in csv.DictReader(io.StringIO(result.stdout),delimiter='\t') if norm(x.get('text',''))]
   for start in range(len(words)):
    combined=''
    for end in range(start,min(start+12,len(words))):
     combined+=norm(words[end]['text'])
     if combined==norm(phrase):
      rows=words[start:end+1];left=min(int(w['left']) for w in rows);top=min(int(w['top']) for w in rows);right=max(int(w['left'])+int(w['width']) for w in rows);bottom=max(int(w['top'])+int(w['height']) for w in rows)
      return (left+right)/2/factor,(top+bottom)/2/factor
     if not norm(phrase).startswith(combined):break
 raise ValueError('Actual rendered text not located: '+phrase)
def primary(path):
 pic=Image.open(path).convert('RGB');w,h=pic.size;points=[]
 for y in range(int(h*.08),int(h*.65)):
  xs=[]
  for x in range(int(w*.025),int(w*.50)):
   r,g,b=pic.getpixel((x,y))
   if abs(r-195)<4 and abs(g-163)<4 and abs(b-102)<4:xs.append(x)
  if len(xs)>w*.12:points.append((y,min(xs),max(xs)))
 assert len(points)>=20,'Actual rendered brass Start button not found'
 return (min(x[1] for x in points)+max(x[2] for x in points))/2,(points[0][0]+points[-1][0])/2
async def density(page,dpr):
 observed=await page.evaluate('''() => {const c=document.querySelector('canvas'),g=c.getContext('webgl2'),ext=g.getExtension('WEBGL_debug_renderer_info');return {dpr:devicePixelRatio,css:[c.clientWidth,c.clientHeight],buffer:[g.drawingBufferWidth,g.drawingBufferHeight],filter:getComputedStyle(c).imageRendering,renderer:ext?g.getParameter(ext.UNMASKED_RENDERER_WEBGL):g.getParameter(g.RENDERER)};}''')
 assert observed['dpr']==dpr and observed['css']==observed['buffer'] and observed['filter']=='pixelated',observed
 return observed
async def case(browser,label,w,h,dpr,mobile):
 folder=OUT/label;folder.mkdir();logs=[];errors=[];http=[];events=[];clicks=[];start=time.monotonic();report={'case':label,'source_commit':a.source,'build_id':a.build,'status':'failed','viewport_css':[w,h],'device_scale_factor':dpr,'input':'native touchscreen tap' if mobile else 'native mouse click'}
 context=await browser.new_context(viewport={'width':w,'height':h},device_scale_factor=dpr,is_mobile=mobile,has_touch=mobile)
 page=await context.new_page()
 def console(m):
  logs.append({'type':m.type,'text':m.text})
  if m.text.startswith('FOREST_UI_EVENT '):
   try:events.append(json.loads(m.text.split(' ',1)[1]))
   except ValueError:pass
 page.on('console',console);page.on('pageerror',lambda e:errors.append(str(e)));page.on('response',lambda r:http.append({'status':r.status,'url':r.url}) if r.status>=400 else None)
 async def shot(name):
  path=folder/(name+'.png');await page.screenshot(path=str(path),scale='css');return path
 async def click(point,label):
  clicks.append({'action':label,'actual_css_point':point})
  if mobile:await page.touchscreen.tap(*point)
  else:await page.mouse.click(*point)
 try:
  await page.goto(a.url,wait_until='domcontentloaded',timeout=45000)
  await page.wait_for_function('window.PLAYTEST_LOADING_DONE === true',timeout=150000)
  await page.wait_for_timeout(1200);report['title_density']=await density(page,dpr)
  path=await shot('title');await click(primary(path),'Start game')
  await page.wait_for_timeout(1500);home=await shot('home')
  assert not any(x.get('event')=='region_assembled' for x in events),'Start bypassed Home and assembled a region'
  # Both the Home heading and its native navigation button must be rendered.
  locate(home,'HOME')
  menu_point=None
  for phrase in ['MENU SETTINGS','MENU']:
   try:menu_point=locate(home,phrase);break
   except ValueError:pass
  assert menu_point is not None,'Home navigation button missing'
  report['home_density']=await density(page,dpr)
  await click(menu_point,'Home menu');await page.wait_for_timeout(600);navigation=await shot('home-navigation')
  locate(navigation,'Choose your next run')
  # Native focus wrapping moves from the first Home navigation control to
  # its last LineEdit. The accepted region event below verifies the result.
  await page.keyboard.press('Shift+Tab');await page.keyboard.press('Control+A')
  await page.keyboard.type('level-design-v2-baseline/08',delay=15)
  await page.wait_for_timeout(250);await shot('seed-entered')
  await page.mouse.move(w*.65,h*.45);await page.mouse.wheel(0,-2400)
  await page.wait_for_timeout(400);navigation=await shot('home-navigation-seeded')
  explore=None
  for phrase in ['Explore Windchime Plains','Windchime Plains']:
   try:explore=locate(navigation,phrase);break
   except ValueError:pass
  assert explore is not None,'Actual Explore menu choice missing'
  await click(explore,'Explore Windchime Plains')
  for _ in range(300):
   if any(x.get('event')=='region_assembled' and x.get('region')=='plains' and not x.get('debug_entry',True) for x in events):break
   await page.wait_for_timeout(100)
  assert any(x.get('event')=='region_assembled' and x.get('region')=='plains' and not x.get('debug_entry',True) for x in events),'Real menu input did not enter formal Plains'
  assert any(x.get('event')=='region_assembled' and x.get('seed')=='level-design-v2-baseline/08' for x in events),'Native seed input was not accepted'
  await page.wait_for_timeout(1500)
  if not mobile:
   await page.keyboard.down('d');await page.wait_for_timeout(250);await page.keyboard.up('d')
  await shot('plains');report['plains_density']=await density(page,dpr)
  frames=await page.evaluate('''() => new Promise(resolve=>{const frames=[];let prior=0;const start=performance.now();function tick(now){if(prior)frames.push(now-prior);prior=now;if(performance.now()-start<5000)requestAnimationFrame(tick);else resolve(frames);}requestAnimationFrame(tick);})''')
  report['raf_ms']=frames;report['fps']=1000/statistics.mean(frames);report['p95_frame_ms']=sorted(frames)[int(len(frames)*.95)]
  report['performance_scope']='Observed SwiftShader CSS-density run; no target-device or same-physical-resolution speedup claim'
  errors.extend(x['text'] for x in logs if any(token in x['text'] for token in ['SCRIPT ERROR','Parse Error','SHADER ERROR','ERROR:','Failed to load script']))
  failures=[x for x in http if not x['url'].endswith('/favicon.ico')]
  assert not errors and not failures,{'errors':errors,'http':failures}
  report['status']='passed'
 except Exception as e:report['error']=str(e)
 finally:
  report.update(seconds=time.monotonic()-start,clicks=clicks,events=events,console=logs,page_errors=errors,http_failures=http)
  (folder/'report.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
  print(json.dumps({k:v for k,v in report.items() if k not in ['console','raf_ms']},ensure_ascii=False),flush=True)
  await context.close()
 return report
async def main():
 opts={'executable_path':shutil.which('chromium'),'headless':True,'args':['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'],'env':{**os.environ,'XDG_CONFIG_HOME':str(OUT/'config'),'XDG_CACHE_HOME':str(OUT/'cache')}}
 if urlparse(a.url).hostname not in ['localhost','127.0.0.1'] and os.environ.get('HTTPS_PROXY'):opts['proxy']={'server':os.environ['HTTPS_PROXY'],'bypass':'localhost,127.0.0.1'}
 cases={'desktop1':(1280,720,1,False),'desktop2':(1280,720,2,False),'mobile3':(960,540,3,True)}
 async with async_playwright() as p:
  browser=await p.chromium.launch(**opts);results=[]
  for label in a.cases.split(','):
   results.append(await case(browser,label,*cases[label]))
   if results[-1]['status']!='passed':break
  await browser.close()
 summary={'status':'passed' if len(results)==len(a.cases.split(',')) and all(x['status']=='passed' for x in results) else 'failed','url':a.url,'source_commit':a.source,'build_id':a.build,'scope':'Real new Godot Web, native pointer/touch title->Home->menu->formal Plains, CSS buffer and compositing checks; SwiftShader emulation, not entity-device/player acceptance','cases':[{'case':r['case'],'status':r['status'],'fps':r.get('fps'),'error':r.get('error')} for r in results]}
 (OUT/'report.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)
 if summary['status']!='passed':raise SystemExit(1)
asyncio.run(main())
