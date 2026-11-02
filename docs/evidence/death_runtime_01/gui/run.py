import argparse,ast,asyncio,csv,hashlib,io,json,os,shutil,subprocess,sys,time,urllib.request
from pathlib import Path
from urllib.parse import urljoin,urlparse
sys.dont_write_bytecode=True
parser=argparse.ArgumentParser(description='One fresh ordinary final Web GUI smoke; requires explicit root lease before invocation.')
parser.add_argument('--url',required=True)
parser.add_argument('--source',default='10dcd39abd8dd8be57cf838167989dd0ca93502b')
parser.add_argument('--pack-sha256',required=True)
parser.add_argument('--pack-bytes',type=int,required=True)
parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--commands',type=Path,required=True)
parser.add_argument('--bundle',type=Path,help='Optional exact local exported bundle to hash before/after; not copied.')
parser.add_argument('--proxy-from-environment',action='store_true')
ARGS=parser.parse_args()
assert len(ARGS.source)==40 and all(c in '0123456789abcdef' for c in ARGS.source)
assert len(ARGS.pack_sha256)==64 and all(c in '0123456789abcdef' for c in ARGS.pack_sha256) and ARGS.pack_bytes>0
assert urlparse(ARGS.url).scheme in ['http','https']
if urlparse(ARGS.url).hostname not in ['127.0.0.1','localhost','::1']:assert ARGS.proxy_from_environment
R=Path('/workspace/gunman-rush-refactor');E=ARGS.output;E.mkdir(parents=True,exist_ok=False);T=ARGS.commands;T.mkdir(parents=True,exist_ok=True)
DRIVER=Path(__file__).resolve()

sys.path[:0]=[str(R/'tools')]
from playwright.async_api import async_playwright
from verify_forest_browser import locate,locate_original,norm,validate_identity,environment_proxy
from studio_gui_pointer import locate_pixel_control,native_surfaces,title_surface,touch_menu_surface
TESS_ARGS=['--tessdata-dir','/workspace/toolchains/tessdata-4.1.0-fast'];os.environ['TESSDATA_PREFIX']='/tmp/first-use-stutter-01/canvas-preparation-browser/ocr-data'
source=(R/'tools/verify_four_line_browser.py').read_text();nodes=[n for n in ast.parse(source).body if isinstance(n,ast.FunctionDef) and n.name in {'locate_cjk','locate_primary','locate_any'}];exec(compile(ast.Module(body=nodes,type_ignores=[]),'original_helpers','exec'),globals())
F=ARGS.source;S=ARGS.pack_sha256;PACK_BYTES=ARGS.pack_bytes;URL=ARGS.url;BASE=urljoin(URL,'./');report={'status':'RUNNING','scope':'One fresh ordinary final Web GUI smoke only, local or public URL as explicitly authorized. No init scripts, instrumentation, FPS observer, GL queries, gameplay state writes or performance acceptance. 300s total budget. Real keyboard/mouse only.','console':[],'page_errors':[],'screenshots':[],'actions':[],'checkpoints':[]}
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def save():(E/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
async def main():
 start=time.monotonic()
 opener=urllib.request.build_opener() if ARGS.proxy_from_environment else urllib.request.build_opener(urllib.request.ProxyHandler({}))
 def identity_now():
  nonce=str(time.time_ns());info=json.loads(opener.open(urllib.request.Request(BASE+'build-info.json?gui='+nonce,headers={'Cache-Control':'no-cache'}),timeout=30).read());worker=opener.open(urllib.request.Request(BASE+'index.cache-sw.js?gui='+nonce,headers={'Cache-Control':'no-cache'}),timeout=30).read().decode();return validate_identity(info,worker,{'sha256':S,'bytes':PACK_BYTES},F,S[:12])
 report['identity']=identity_now();report['url']=URL;report['expected_pack_sha256']=S;report['expected_pack_bytes']=PACK_BYTES
 if ARGS.bundle:
  pack=ARGS.bundle/report['identity']['pack'];assert pack.stat().st_size==PACK_BYTES and sha(pack)==S;report['local_pack_before_sha256']=S
 report['remote_pack_SHA_scope']='GUI checks actual served metadata/worker against expected PCK SHA/size. Local bundle bytes verified when --bundle supplied. Public full-PCK stream verification is separate root evidence.';report['helpers_before']={str(p):sha(p) for p in [R/'tools/verify_four_line_browser.py',R/'tools/verify_forest_browser.py',R/'tools/studio_gui_pointer.py',DRIVER]};save()

 async with async_playwright() as p:
  browser=await p.chromium.launch(proxy=environment_proxy()[0] if ARGS.proxy_from_environment else None,executable_path=shutil.which('chromium'),headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'],timeout=30000);context=await browser.new_context(viewport={'width':1280,'height':720},device_scale_factor=1,has_touch=True);page=await context.new_page();report['browser_version']=browser.version
  page.on('console',lambda m:report['console'].append({'type':m.type,'text':m.text,'location':m.location}));page.on('pageerror',lambda x:report['page_errors'].append(str(x)))
  async def screen(name):
   path=E/(name+'.png');await page.screenshot(path=str(path));report['screenshots'].append({'file':path.name,'sha256':sha(path),'host_epoch_ms':time.time()*1000});save();return path
  async def hold(key,ms):
   assert key in ['d','a'] and 0<ms<=1500
   await page.keyboard.down(key);await page.wait_for_timeout(ms);await page.keyboard.up(key);await page.wait_for_timeout(250)
  seq=0
  async def checkpoint(name,pic):
   nonlocal seq
   seq+=1;report['checkpoints'].append({'seq':seq,'name':name,'screenshot':pic.name});report['waiting_seq']=seq;save();print('WAIT',seq,name,pic.name,flush=True)
   while time.monotonic()-start<295:
    path=T/'command.json'
    if path.exists():
     cmd=json.loads(path.read_text())
     if cmd.get('seq')==seq:return cmd
    await asyncio.sleep(.1)
   raise TimeoutError('300s total GUI smoke budget')
  try:
   await page.goto(URL,wait_until='networkidle',timeout=60000);await page.wait_for_function('window.PLAYTEST_LOADING_DONE===true',timeout=60000);await page.wait_for_timeout(600)
   report['no_FPS04_injection']=await page.evaluate("typeof window.FPS04_READY==='undefined' && typeof window.FPS04_STATE==='undefined' && typeof window.FPS04_RESULTS==='undefined'");assert report['no_FPS04_injection']
   title=await screen('01-title');point=locate_any(title,'开始游戏');report['actions'].append({'action':'actual-title-start','point':point});await page.mouse.click(*point);await page.wait_for_timeout(1800);pic=await screen('02-home')
   while True:
    cmd=await checkpoint('visual-ordinary-input',pic);action=cmd['action'];row={'seq':seq,'action':action,'command':cmd};report['actions'].append(row);save()
    if action=='hold':await hold(cmd['key'],int(cmd['ms']));pic=await screen(f'{seq+2:02d}-after-{cmd["key"]}-{cmd["ms"]}')
    elif action=='walk-segments':
     assert 1<=int(cmd['count'])<=6
     for i in range(int(cmd['count'])):await hold(cmd['key'],int(cmd['ms']));pic=await screen(f'{seq+2:02d}-segment-{i+1}-{cmd["key"]}')
    elif action=='gate-W':await page.keyboard.press('w');await page.wait_for_timeout(650);pic=await screen(f'{seq+2:02d}-after-W')
    elif action=='begin':
     point=locate_any(pic,'BEGIN / WINDCHIME PLAINS');row['actual_BEGIN_point']=point;await page.mouse.click(*point);await page.wait_for_timeout(2200);pic=await screen(f'{seq+2:02d}-plains-entry');report['actual_BEGIN_clicked']=True;save()
    elif action=='finish':report['operator_visual_review']=cmd['review'];report['status']='GUI_SMOKE_PASSED' if cmd.get('passed') else 'GUI_SMOKE_INCOMPLETE';break
    else:raise ValueError(action)
  finally:
   await context.close();await browser.close();report['browser_closed']=True;save()
 report['identity_after']=identity_now();
 if ARGS.bundle:report['local_pack_after_sha256']=sha(pack);assert report['local_pack_after_sha256']==S
 report['helpers_after']={p:sha(Path(p)) for p in report['helpers_before']};report['stable']=report['identity_after']==report['identity'] and report['helpers_before']==report['helpers_after'];report['elapsed_seconds']=time.monotonic()-start;save();assert report['stable'] and not report['page_errors']

try:asyncio.run(asyncio.wait_for(main(),300))
except Exception as error:report['status']='FAILED';report['exception']=repr(error);save();raise
