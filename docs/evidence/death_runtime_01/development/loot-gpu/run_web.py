import asyncio, gzip, hashlib, json, shutil, time
from pathlib import Path
from playwright.async_api import async_playwright

OUT=Path('/workspace/refactor-evidence/death-runtime-01/loot-gpu')
TMP=Path('/tmp/loot-gpu-02')
OBSERVER=Path('/workspace/refactor-evidence/first-use-stutter-01/canvas-preparation-browser/gl-observer.js').read_text()
report={'scope':'one corrected isolated technical fixture context per A/B; initial and exactly two spawn commands; passive existing WebGL wrappers only; no extra GL queries; software-rendered Chromium, no phone FPS or natural-death causal claim','variants':{},'observer_sha256':hashlib.sha256(OBSERVER.encode()).hexdigest(),'context_deadline_seconds':120,'worker_evaluation_deadline_seconds':3}

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
    row={'console':[],'errors':[],'phases':[],'worker_installs':[],'steps':[]}
    report['variants'][mode]=row
    page.on('console',lambda m:row['console'].append({'type':m.type,'text':m.text}))
    page.on('pageerror',lambda e:row['errors'].append(str(e)))
    workers=[]; tasks=[]
    async def install(worker):
     item={'url':worker.url,'coverage':'pending'}; row['worker_installs'].append(item)
     try:
      item['installation']=await asyncio.wait_for(worker.evaluate(OBSERVER),3)
      item['coverage']='installed';workers.append(worker)
     except Exception as e:item['error']=repr(e);item['coverage']='uncovered, not evidence of zero GL work'
    page.on('worker',lambda worker:tasks.append(asyncio.create_task(install(worker))))
    async def stage(name):
     await asyncio.wait_for(page.evaluate('(s)=>COLD_GL.setStage(s)',name),5)
     for worker in workers:
      try:await asyncio.wait_for(worker.evaluate('(s)=>globalThis.COLD_GL?.setStage(s)',name),3)
      except Exception as e:row.setdefault('worker_stage_errors',[]).append({'stage':name,'error':repr(e),'coverage':'uncovered'})
    async def snapshot(label):
     state=await page.evaluate('window.LOOT_FIXTURE_STATE')
     gl={'window':await page.evaluate('COLD_GL.snapshot()'),'workers':[]}
     for worker in workers:
      try:gl['workers'].append(await asyncio.wait_for(worker.evaluate('globalThis.COLD_GL?.snapshot()'),3))
      except Exception as e:row.setdefault('worker_snapshot_errors',[]).append({'label':label,'error':repr(e),'coverage':'uncovered'})
     file=TMP/mode/(label+'-gl.json.gz')
     file.write_bytes(gzip.compress(json.dumps(gl).encode(),mtime=0))
     row['phases'].append({'label':label,'state':state,'gl_path':str(file),'raf':await page.evaluate('window.LOOT_RAF')})
     await stage('outside-timing-'+label)
     await page.locator('canvas').screenshot(path=str(OUT/(mode+'-'+label+'.png')),timeout=15000)
     save()
    def step(name):
     row['step']=name;row['steps'].append({'step':name,'epoch_ms':time.time()*1000});save()
     print(mode,name,flush=True)
    try:
     async with asyncio.timeout(120):
      step('navigate')
      await page.goto('http://127.0.0.1:8821/'+mode+'/web/engine-debug/',wait_until='load',timeout=60000)
      step('wait-fixture')
      await page.wait_for_function('window.LOOT_FIXTURE_READY===true',timeout=90000)
      step('worker-observers');row['ready_state']=await page.evaluate('window.LOOT_FIXTURE_STATE');save()
      await asyncio.wait_for(asyncio.gather(*tasks),5)
      step('initial-snapshot')
      await page.wait_for_timeout(500)
      await snapshot('initial')
      for batch in [1,2]:
       step('spawn-'+str(batch))
       await stage('spawn-'+str(batch))
       row.setdefault('commands',[]).append(await page.evaluate("(()=>{const epoch_ms=performance.timeOrigin+performance.now();window.LOOT_FIXTURE_COMMAND='spawn';return{batch:"+str(batch)+",epoch_ms}})()"))
       await page.wait_for_function('(batch)=>window.LOOT_FIXTURE_STATE.batch===batch',arg=batch,timeout=10000)
       await page.wait_for_timeout(650)
       await snapshot('spawn-'+str(batch))
      row['status']='CAPTURED';step('complete')
    except Exception as e:
     row['status']='FAILED';row['exception']=repr(e);save();raise
    finally:
     # Preserve the main realm even when an idle worker cannot be evaluated.
     try:
      partial=await asyncio.wait_for(page.evaluate('globalThis.COLD_GL?.snapshot()'),5)
      file=TMP/mode/'finally-main-gl.json.gz';file.write_bytes(gzip.compress(json.dumps(partial).encode(),mtime=0));row['finally_main_gl_path']=str(file)
     except Exception as e:row['finally_main_gl_error']=repr(e)
     save()
     await asyncio.wait_for(context.close(),10)
    save()
  finally:
   try:await asyncio.wait_for(browser.close(),10)
   finally:report['browser_closed']=True;save()
 report['status']='CAPTURED_PENDING_ANALYSIS';save()

try:asyncio.run(run())
except Exception as e:report['status']='FAILED';report['exception']=repr(e);save();raise
