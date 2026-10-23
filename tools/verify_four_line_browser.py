"""Bounded real-Godot browser smoke for the integrated four worklines.

Retains R3's desktop/mobile GUI assertions. Reads real WebAudio state/mixed
output, never Godot internals. A mixed signal does not identify all five songs:
Boss-song browser playback remains unverified without actual Boss traversal.
Historical drivers/expectations are left intact. System Chromium is required.
"""
import argparse, re, shutil, urllib.request
from urllib.parse import urljoin, urlparse
import asyncio,sys,os,json,hashlib,time,subprocess,csv,io
from pathlib import Path
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--root-url', required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--expected-source', '--expected-commit', dest='expected_source', required=True)
parser.add_argument('--expected-build', '--expected-build-id', dest='expected_build', required=True)
parser.add_argument('--repo-root', type=Path, default=Path.cwd())
parser.add_argument('--device', choices=['desktop','mobile','both'], default='both')
parser.add_argument('--section', choices=['all','r3','extra'], default='all', help='all is complete smoke; extra is only Home/Forest iteration, never the retained R3 suite')
parser.add_argument('--tessdata-dir', type=Path, help='Directory containing chi_sim.traineddata and eng.traineddata')
parser.add_argument('--proxy-from-environment', action='store_true')
ARGS=parser.parse_args()
if not re.fullmatch('[0-9a-f]{40}', ARGS.expected_source): parser.error('expected-source must be the complete 40-character SHA')
if not re.fullmatch('[0-9a-f]{12}', ARGS.expected_build): parser.error('expected-build must be the complete 12-character build ID')
if urlparse(ARGS.root_url).scheme not in ('http','https'): parser.error('root-url must use HTTP(S)')
ROOT=ARGS.repo_root.resolve()
if not (ROOT/'project.godot').is_file(): parser.error('repo-root must contain the actual source project')
sys.path.insert(0,str(ROOT/'tools'))
TESS_ARGS=['--tessdata-dir',str(ARGS.tessdata_dir.resolve())] if ARGS.tessdata_dir else []
langs=subprocess.run(['tesseract',*TESS_ARGS,'--list-langs'],capture_output=True,text=True,check=True).stdout.splitlines()
if not {'eng','chi_sim'}.issubset(set(langs)): parser.error('Real CJK GUI OCR requires eng and chi_sim; install or provide --tessdata-dir (no English-only success fallback)')
OUT=ARGS.output.resolve()
if not OUT.is_relative_to(ROOT/'build'): parser.error('output must be a fresh directory under repo-root/build')
for ancestor in [ARGS.output,*ARGS.output.parents]:
 if ancestor.is_symlink(): parser.error('output and ancestors must not be symlinks')
OUT.mkdir(parents=True,exist_ok=False)
URL=ARGS.root_url.rstrip('/')+'/'

from verify_forest_browser import locate,locate_original,norm,environment_proxy,validate_identity
from check_web_bundle import Pack
from playwright.async_api import async_playwright
def locate_cjk(path,phrase):
 import re
 normalize=lambda t: ''.join(x for x in t if x.isalnum()).upper()
 for mode in ['11','6']:
  output=subprocess.run(['tesseract',str(path),'stdout',*TESS_ARGS,'-l','chi_sim+eng','--psm',mode,'-c','tessedit_create_tsv=1'],capture_output=True,text=True,check=True,timeout=15,env={**os.environ,'OMP_THREAD_LIMIT':'1'})
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
 from PIL import Image,ImageOps
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
   versions=[roi]
   if cjk:
    binary=roi.with_name(roi.stem+'-binary.png')
    ImageOps.invert(Image.open(roi).convert('L').point(lambda v:255 if v>145 else 0)).save(binary)
    versions.append(binary)
   for observed in versions:
    for psm in (['7','6'] if cjk else ['7']):
     args=['tesseract',str(observed),'stdout','--psm',psm]
     if cjk:args+=[*TESS_ARGS,'-l','chi_sim+eng','-c','tessedit_create_tsv=1']
     else:args+=['tsv']
     result=subprocess.run(args,capture_output=True,text=True,check=True,timeout=10,env={**os.environ,'OMP_THREAD_LIMIT':'1'})
     observed.with_suffix('.psm'+psm+'.tsv').write_text(result.stdout)
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

AUDIO_OBSERVER = r"""(() => {
 const contexts = new Map(), taps = new WeakSet();
 const originalConnect = AudioNode.prototype.connect;
 AudioNode.prototype.connect = function(...args) {
  const result = originalConnect.apply(this,args);
  const destination = args[0];
  if (destination instanceof AudioDestinationNode && !taps.has(this)) {
   const context = this.context;
   if (!contexts.has(context)) {
    const analyser = context.createAnalyser(); analyser.fftSize=2048;
    const sink = context.createGain(); sink.gain.value=0;
    taps.add(analyser); taps.add(sink);
    originalConnect.call(analyser,sink); originalConnect.call(sink,context.destination);
    contexts.set(context,{analyser,states:[{state:context.state,time:performance.now()}]});
    context.addEventListener('statechange',()=>contexts.get(context).states.push({state:context.state,time:performance.now()}));
   }
   originalConnect.call(this,contexts.get(context).analyser);
  }
  return result;
 };
 Object.defineProperty(window,'__fourLineNativeAudio',{value:()=>Array.from(contexts,([context,row])=>{
  const samples=new Float32Array(row.analyser.fftSize);row.analyser.getFloatTimeDomainData(samples);
  let square=0,peak=0;for(const x of samples){square+=x*x;peak=Math.max(peak,Math.abs(x));}
  return {state:context.state,current_time:context.currentTime,sample_rate:context.sampleRate,rms:Math.sqrt(square/samples.length),peak,states:row.states};
 })});
})();"""

async def require_audio(page,report,label,muted=False):
 # Observe the real native graph via a zero-gain analyser branch. Never call
 # AudioContext.resume(), replace PCM, inject gameplay, or fabricate track IDs.
 await page.wait_for_timeout(1200 if not muted else 400)
 snapshots=[]
 for _ in range(5):
  snapshots.append(await page.evaluate('window.__fourLineNativeAudio()'))
  await page.wait_for_timeout(100)
 rows=[row for snapshot in snapshots for row in snapshot]
 running=[row for row in rows if row['state']=='running']
 peak=max((row['peak'] for row in running),default=0)
 passed=bool(running) and (peak<0.00001 if muted else peak>0.00001)
 report.setdefault('audio_observations',[]).append({'label':label,'snapshots':snapshots,'passed':passed,'kind':'actual WebAudio context/mixed-output observation','individual_track_identity':'unverified; mixed output does not identify MP3 filenames'})
 if not passed:raise AssertionError(label+': actual native audio graph did not show '+('muted output' if muted else 'running nonzero output after trusted input'))

def fetch_pack_identity():
 def fetch(path):
  with urllib.request.urlopen(urllib.request.Request(urljoin(URL,path),headers={'Cache-Control':'no-cache'}),timeout=60) as response:
   if response.status!=200:raise AssertionError('Real export identity HTTP '+str(response.status))
   return response.read()
 info=json.loads(fetch('build-info.json?verify='+ARGS.expected_build))
 worker=fetch('index.cache-sw.js').decode()
 html=fetch('index.html?verify='+ARGS.expected_build).decode()
 name='index.'+ARGS.expected_build+'.pck'
 if name not in html or 'new Engine(' not in html:raise AssertionError('Actual export HTML does not reference the expected real Godot engine/PCK')
 digest=hashlib.sha256();size=0
 with urllib.request.urlopen(urllib.request.Request(urljoin(URL,name),headers={'Cache-Control':'no-cache'}),timeout=60) as response, (OUT/name).open('xb') as dest:
  if response.status!=200:raise AssertionError('Real full PCK HTTP '+str(response.status))
  while block:=response.read(1024*1024):digest.update(block);size+=len(block);dest.write(block)
 return validate_identity(info,worker,{'sha256':digest.hexdigest(),'bytes':size},ARGS.expected_source,ARGS.expected_build)

def check_music_pack(path):
 # Presence and imported-resource bytes are separate from original source
 # hashes and actual browser playback. Do not sign five songs from metadata.
 pack=Pack(path);source=json.loads((ROOT/'assets/audio/bgm/provenance.json').read_text());rows=[]
 if len(source['tracks'])!=5:raise AssertionError('Expected the five user-provided source songs')
 for item in source['tracks']:
  name=item['runtime_path'];raw=(ROOT/name).read_bytes()
  if hashlib.sha256(raw).hexdigest()!=item['sha256']:raise AssertionError('User MP3 source drift: '+name)
  imported=pack.read(name+'.import').decode()
  if not re.search(r'^importer="mp3"$',imported,re.M):raise AssertionError('PCK is not a real MP3 import: '+name)
  target=re.search(r'^path="res://([^"\n]+)"$',imported,re.M)
  if not target:raise AssertionError('PCK lacks the imported stream target: '+name)
  payload=pack.read(target[1])
  if not payload:raise AssertionError('Empty MP3 stream resource: '+name)
  rows.append({'source_path':name,'source_mp3_sha256':item['sha256'],'imported_path':target[1],'imported_sha256':hashlib.sha256(payload).hexdigest(),'pack_presence':'passed','browser_individual_song_playback':'unverified','expected_context':item['context']})
 return rows

def heart_pixels(path):
 from PIL import Image
 import numpy as np
 a=np.asarray(Image.open(path).convert('RGB')).astype(int);h,w=a.shape[:2]
 return int((np.max(np.abs(a[:int(h*.25),:int(w*.42)]-(217,120,96)),axis=2)<=5).sum())

def ring_candidates(path):
 from PIL import Image
 import numpy as np,scipy.ndimage as ndi
 a=np.asarray(Image.open(path).convert('RGB')).astype(int);h,w=a.shape[:2]
 mask=np.max(np.abs(a-(216,177,107)),axis=2)<=7
 mask[:int(h*.25)]=False;mask[:,int(w*.85):]=False
 labels,_=ndi.label(mask);found=[]
 for index,bounds in enumerate(ndi.find_objects(labels),1):
  if bounds is None:continue
  yy,xx=bounds;ww=xx.stop-xx.start;hh=yy.stop-yy.start
  if min(ww,hh)<18 or max(ww,hh)>160 or not .65<ww/hh<1.55:continue
  ys,xs=np.where(labels[yy,xx]==index);cx=(ww-1)/2;cy=(hh-1)/2
  rr=np.hypot(xs-cx,ys-cy);median=float(np.median(rr))
  if len(rr)<25 or median<8 or float(np.std(rr))/median>.28:continue
  found.append({'bounds':[xx.start,yy.start,ww,hh],'pixels':len(rr),'radius_median':median,'radius_relative_std':float(np.std(rr))/median})
 return found

async def home_and_forest_smoke(browser,report):
 # Extra real desktop journey; original desktop/mobile R3 checks stay intact.
 context=await browser.new_context(viewport={'width':1280,'height':720},device_scale_factor=1)
 await context.add_init_script(AUDIO_OBSERVER)
 page=await context.new_page();events=[];console=[]
 report['contexts']['desktop-extra']={'console':console,'events':events,'console_entries':[]}
 def log(message):
  text=message.text;console.append(text)
  report['contexts']['desktop-extra']['console_entries'].append({'type':message.type,'text':text,'location':message.location})
  if 'FOREST_UI_EVENT ' in text:
   try:events.append(json.loads(text.split('FOREST_UI_EVENT ',1)[1]))
   except json.JSONDecodeError:report['errors'].append('invalid actual region event JSON')
  if any(s in text for s in ['SCRIPT ERROR','Parse Error','ERROR:']):report['errors'].append('home-forest: '+text)
 page.on('console',log);page.on('pageerror',lambda error:report['errors'].append(str(error)))
 async def capture(label):
  path=OUT/('home-forest-'+label+'.png');await page.screenshot(path=str(path));return path
 async def click(text,label,scroll=False):
  for attempt in range(12 if scroll else 1):
   pic=await capture(label+'-'+str(attempt))
   try:point=locate_any(pic,text)
   except ValueError:
    if not scroll or attempt==11:raise
    await page.mouse.move(640,530);await page.mouse.wheel(0,240);await page.wait_for_timeout(180);continue
   await page.mouse.click(*point);await page.wait_for_timeout(300);return
 async def has(text,label):
  try:locate_any(await capture(label),text);return True
  except ValueError:return False
 def check(ok,label):
  report['checks'].append({'device':'desktop-extra','passed':bool(ok),'assertion':label})
  print('desktop-extra: '+label+' '+str(bool(ok)),flush=True)
  if not ok:raise AssertionError(label)
 async def load_title():
  await page.goto(URL,wait_until='networkidle',timeout=60000)
  await page.wait_for_function('window.PLAYTEST_LOADING_DONE===true',timeout=60000)
  await page.wait_for_timeout(500)
 await load_title()
 await click('开发入口','development-entry',True)
 check(await has('HOME','development-open'),'actual new development entry opens original menu')
 await click('HOME','enter-home',True)
 home_capture=await capture('actual-home')
 from PIL import Image,ImageOps
 home_image=Image.open(home_capture).convert('L');ww,hh=home_image.size
 box=(round(ww*350/1280),round(hh*16/720),round(ww*800/1280),round(hh*64/720))
 crop=home_image.crop(box);crop=crop.resize((crop.width*4,crop.height*4),Image.Resampling.NEAREST)
 header=OUT/'home-actual-header-binary.png';ImageOps.invert(crop.point(lambda x:255 if x>145 else 0)).save(header)
 try:locate_original(header,'WINDCHIME HOME');home_heading=True
 except ValueError:home_heading=False
 check(home_heading,'real Home world has complete actual WINDCHIME HOME heading')
 await capture('default-body-before-walking')
 # Ordinary accepted keys reach the nearby authored NPC, never a teleport/hook.
 await page.keyboard.down('d');await page.wait_for_timeout(600);await page.keyboard.up('d');await page.wait_for_timeout(200)
 await require_audio(page,report,'actual-new-Home-App-after-real-direction-input')
 await page.keyboard.press('w');await page.wait_for_timeout(300)
 check(await has('Timeweaver','timeweaver-open'),'actual Home movement/interact opens Timeweaver')
 check(await has('新信使','initial-selection'),'real default selected option is new Courier')
 await click('新信使','appearance-picker')
 await click('经典信使','select-classic')
 check(await has('经典信使','classic-selected'),'actual native option selection chooses classic Courier')
 await click('BACK TO HOME','close-classic')
 classic=await capture('classic-body')
 await page.keyboard.press('w');await page.wait_for_timeout(300)
 await click('经典信使','appearance-picker-again')
 await click('新信使','restore-new')
 check(await has('新信使','new-selected'),'actual option selection restores new Courier')
 await click('BACK TO HOME','close-new')
 new=await capture('new-body')
 from PIL import Image,ImageChops
 region=(190,360,400,535)
 difference=ImageChops.difference(Image.open(classic).convert('RGB').crop(region),Image.open(new).convert('RGB').crop(region))
 difference.save(OUT/'home-body-selection-difference.png')
 check(difference.getbbox() is not None,'actual Home body-region pixels change across native avatar selection; captures retained for review')
 # Fresh actual title, no old in-game state or injection, then explicit Forest.
 await load_title();await click('开发入口','forest-development',True)
 await click('DEBUG / SELECT REGION + MAP','debug-regions',True)
 await click('THORN_FOREST / MAP 1','forest-map1',True)
 deadline=time.monotonic()+30
 while time.monotonic()<deadline and not any(e.get('event')=='region_assembled' and e.get('region')=='thorn_forest' for e in events):await page.wait_for_timeout(100)
 check(any(e.get('event')=='region_assembled' and e.get('region')=='thorn_forest' for e in events),'real debug click assembles the actual forest')
 await capture('forest-hud')
 await require_audio(page,report,'actual-forest-after-accepted-debug-entry')
 report['extra_region_events']=events
 await context.close()

async def main():
 report={'source_commit':ARGS.expected_source,'build_id':ARGS.expected_build,'driver_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'observed_at_unix':time.time(),'section':ARGS.section,'url':URL,'checks':[],'errors':[],'contexts':{},'scope':'Real exported Godot canvas via desktop mouse and emulated mobile DOM touch. No engine hooks or physical-device claim. Main title and touch MENU coordinates use native material component bounds after actual pixel inspection and native exact-label/route checks. Latin button OCR uses isolated rendered controls. No engine hooks, synthetic click signals or decorative-logo OCR.'}
 globals()['LAST_REPORT']=report
 report['identity']=await asyncio.to_thread(fetch_pack_identity)
 report['music_inventory']=check_music_pack(OUT/report['identity']['pack'])
 report['legacy_driver_limits']='Historical quick-demo/default-region/Studio OCR scripts expect old title/HUD labels. This additive tool preserves the R3 GUI assertions while binding this actual source/build; it does not rewrite old expectations.'
 async with async_playwright() as p:
  browser=await p.chromium.launch(proxy=environment_proxy()[0] if ARGS.proxy_from_environment else None, executable_path=shutil.which('chromium'),headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'],timeout=30000)
  report['browser_version']=browser.version
  for mobile in ([] if ARGS.section=='extra' else [True] if ARGS.device=='mobile' else [False] if ARGS.device=='desktop' else [False,True]):
   name='mobile' if mobile else 'desktop';w,h=(844,390) if mobile else (1280,720)
   context=await browser.new_context(viewport={'width':w,'height':h},has_touch=mobile,is_mobile=mobile,device_scale_factor=1)
   await context.add_init_script(AUDIO_OBSERVER)
   page=await context.new_page();events=[];console=[];report['contexts'][name]={'console':console,'events':events,'console_entries':[]}
   def log(m):
    s=m.text;console.append(s)
    report['contexts'][name]['console_entries'].append({'type':m.type,'text':s,'location':m.location})
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
    print(name+': '+msg+' '+str(bool(value)),flush=True)
    if not value:raise AssertionError(name+': '+msg)
   check(await has('设定','title') and await has('新手教程','title-tutorial') and await has('开始游戏','title-primary'),'four rendered native title surfaces and primary match inspected source-bound menu; actual subsequent click verifies route')
   await click('设定','settings-entry',True)
   check(await has('Touch movement','settings'),'actual settings page opened')
   await require_audio(page,report,name+'-home-after-first-real-settings-click')
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
   await page.wait_for_timeout(500)
   hud=await capture('actual-hud')
   check(heart_pixels(hud)>12,'real heart-colored HUD pixels are rendered')
   await require_audio(page,report,name+'-plains-after-actual-entry')
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
    ring=await capture('actual-time-energy-ring')
    candidates=ring_candidates(ring)
    report.setdefault('ring_pixels',{})[name]=candidates
    check(bool(candidates),'actual slow-aim ring forms a visible circular arc outside the HUD')
    await page.mouse.up();await page.wait_for_timeout(120)
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
  if ARGS.section!='r3': await home_and_forest_smoke(browser,report)
  await browser.close()
 report['unverified']=['Individual five-song identity cannot be inferred from the browser mixed waveform; the two Boss-song Web transitions need actual Boss traversal.','Natural full routes, listening/music seam quality, physical devices and complete Release acceptance.']
 report['failed']=len(report['errors'])+sum(not c['passed'] for c in report['checks']);(OUT/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False))
 raise SystemExit(bool(report['failed']))
try:asyncio.run(main())
except Exception as e:
 (OUT/'partial-report.json').write_text(json.dumps(globals().get('LAST_REPORT',{}),ensure_ascii=False,indent=2)+'\n')
 (OUT/'failure.json').write_text(json.dumps({'error':str(e),'scope':'Browser run failed; no broader GUI PASS'},ensure_ascii=False,indent=2)+'\n');raise
