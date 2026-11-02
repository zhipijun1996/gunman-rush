import asyncio, gzip, hashlib, json, shutil, time
from pathlib import Path
from playwright.async_api import async_playwright

OUT=Path('/workspace/refactor-evidence/death-runtime-01/loot-gpu')
TMP=Path('/tmp/loot-gpu-02')
OBSERVER=Path('/workspace/refactor-evidence/first-use-stutter-01/canvas-preparation-browser/gl-observer.js').read_text()
report={'scope':'one isolated technical fixture context per A/B; initial and exactly two spawn commands; passive existing WebGL wrappers only; no extra GL queries; software-rendered Chromium, no phone FPS or natural-death causal claim','variants':{}}

def save(): (OUT/'web-result.json').write_text(json.dumps(report,indent=2)+'\n')

async def run():
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path=shutil.which('chromium'),headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'],timeout=30000)
  try:
   for mode in ['baseline','candidate']:
    context=await browser.new_context(viewport={'width':1280,'height':720},device_scale_factor=1)
    await context.add_init_script(OBSERVER)
    await context.add_init_script("window.LOOT_RAF=[];{let last=0;function frame(t){if(last&&window.LOOT_RAF.length<2000)window.LOOT_RAF.push({t,dt:t-last,stage:window.COLD_GL?.data.stage});last=t;requestAnimationFrame(frame)}requestAnimationFrame(frame)}")
    page=await context.new_page()
    row={'console':[],'errors':[],'phases':[],'worker_installs':[]}
    report['variants'][mode]=row
    page.on('console',lambda m:row['console'].append({'type':m.type,'text':m.text}))
    page.on('pageerror',lambda e:row['errors'].append(str(e)))
    workers=[]; tasks=[]
    async def install(worker):
     item={'url':worker.url}; row['worker_installs'].append(item); workers.append(worker)
     try:item['installation']=await worker.evaluate(OBSERVER)
     except Exception as e:item['error']=repr(e)
    page.on('worker',lambda worker:tasks.append(asyncio.create_task(install(worker))))
    async def stage(name):
     await page.evaluate('(s)=>COLD_GL.setStage(s)',name)
     for worker in workers:
      try:await worker.evaluate('(s)=>globalThis.COLD_GL?.setStage(s)',name)
      except Exception:pass
    async def snapshot(label):
     state=await page.evaluate('window.LOOT_FIXTURE_STATE')
     gl={'window':await page.evaluate('COLD_GL.snapshot()'),'workers':[]}
     for worker in workers:
      try:gl['workers'].append(await worker.evaluate('globalThis.COLD_GL?.snapshot()'))
      except Exception:pass
     file=TMP/mode/(label+'-gl.json.gz')
     file.write_bytes(gzip.compress(json.dumps(gl).encode(),mtime=0))
     row['phases'].append({'label':label,'state':state,'gl_path':str(file),'raf':await page.evaluate('window.LOOT_RAF')})
     await stage('outside-timing-'+label)
     await page.locator('canvas').screenshot(path=str(OUT/(mode+'-'+label+'.png')))
     save()
    try:
     await page.goto('http://127.0.0.1:8821/'+mode+'/web/engine-debug/',wait_until='load',timeout=120000)
     await page.wait_for_function('window.LOOT_FIXTURE_READY===true',timeout=120000)
     await asyncio.gather(*tasks)
     await page.wait_for_timeout(500)
     await snapshot('initial')
     for batch in [1,2]:
      await stage('spawn-'+str(batch))
      row.setdefault('commands',[]).append(await page.evaluate("(()=>{const epoch_ms=performance.timeOrigin+performance.now();window.LOOT_FIXTURE_COMMAND='spawn';return{batch:"+str(batch)+",epoch_ms}})()"))
      await page.wait_for_function('(batch)=>window.LOOT_FIXTURE_STATE.batch===batch',arg=batch,timeout=10000)
      await page.wait_for_timeout(650)
      await snapshot('spawn-'+str(batch))
     row['status']='CAPTURED'
    except Exception as e:
     row['status']='FAILED';row['exception']=repr(e);save();raise
    finally:
     await context.close()
    save()
  finally:await browser.close()
 report['status']='CAPTURED_PENDING_ANALYSIS';save()

try:asyncio.run(run())
except Exception as e:report['status']='FAILED';report['exception']=repr(e);save();raise
