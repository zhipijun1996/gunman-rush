import asyncio,json,traceback
from pathlib import Path
from playwright.async_api import async_playwright
OUT=Path('build/pixel-review/final-gui');OUT.mkdir(parents=True,exist_ok=True)
EXPECTED=json.loads(Path('build/web/build-info.json').read_text())
async def main():
 logs=[];observations=[];errors=[]
 async with async_playwright() as p:
  b=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  try:
   for mode in ['ordinary',1,2]:
    seen=[]
    c=await b.new_context(viewport={'width':1280,'height':720})
    page=await c.new_page()
    def log(msg):logs.append(msg.text);seen.append(msg.text)
    page.on('console',log);page.on('pageerror',lambda e:logs.append('PAGE ERROR '+str(e)))
    suffix='' if mode=='ordinary' else f'?plains=1&pixel_inspect={mode}'
    await page.goto('http://127.0.0.1:8770/'+suffix,wait_until='networkidle',timeout=90000)
    await page.wait_for_function('window.PLAYTEST_LOADING_DONE === true',timeout=90000)
    build=await page.locator('#playtest-version').get_attribute('data-build-id')
    assert build==EXPECTED['build_id'],f'Wrong build {build}, expected {EXPECTED["build_id"]}'
    if mode=='ordinary':
     await page.wait_for_timeout(900)
     await page.screenshot(path=str(OUT/'ordinary-title.png'))
     await page.keyboard.press('Enter')
     for _ in range(150):
      if any(x.startswith('PLAINS REGION:') for x in seen):break
      await page.wait_for_timeout(200)
     assert any(x.startswith('PLAINS REGION:') for x in seen),'Ordinary title did not enter formal stage'
     await page.wait_for_timeout(1200)
     await page.screenshot(path=str(OUT/'ordinary-entry.png'))
     await page.keyboard.down('d');await page.wait_for_timeout(350)
     await page.keyboard.down('Space');await page.wait_for_timeout(180);await page.keyboard.up('Space');await page.wait_for_timeout(450);await page.keyboard.up('d')
     await page.screenshot(path=str(OUT/'ordinary-jump.png'))
     await page.keyboard.press('Escape');await page.wait_for_timeout(200)
     await page.screenshot(path=str(OUT/'ordinary-pause.png'))
     await page.keyboard.press('Escape')
    else:
     for _ in range(200):
      if any(x.startswith('PIXEL_INSPECT ') and '"point":"spawn"' in x for x in seen):break
      await page.wait_for_timeout(200)
     assert any(x.startswith('PIXEL_INSPECT ') and '"point":"spawn"' in x for x in seen),'Inspector never collected actual spawn'
     await page.mouse.click(630,58)
     await page.wait_for_timeout(300)
     assert any(x.startswith('PIXEL_INSPECT ') and '"point":"enemy/' in x for x in seen),'Enemy fixture not accepted'
     for i in range(6):
      await page.wait_for_timeout(220)
      await page.screenshot(path=str(OUT/f'map{mode}-enemy-{i:02d}.png'))
     await page.mouse.click(440,58)
     await page.wait_for_timeout(1300)
     await page.screenshot(path=str(OUT/f'map{mode}-boss-01.png'))
     await page.wait_for_timeout(1400)
     await page.screenshot(path=str(OUT/f'map{mode}-boss-02.png'))
    observations.append({'mode':mode,'build':build,'source_commit':EXPECTED['source_commit'],'url':page.url})
    await c.close()
  except Exception as exc:
   errors.append(str(exc));(OUT/'exception.log').write_text(traceback.format_exc())
  finally:await b.close()
 errors.extend(x for x in logs if any(s in x for s in ['SCRIPT ERROR','SHADER ERROR','ERROR:','PAGE ERROR','WebGL: INVALID_']))
 (OUT/'console.log').write_text('\n'.join(logs));(OUT/'report.json').write_text(json.dumps({'expected':EXPECTED,'observations':observations,'errors':errors,'scope':'ordinary title/input + explicitly positioned enemy/Boss samples; not campaign traversal','gpu':[x for x in logs if x.startswith('PIXEL_GPU')]},indent=2))
 print(json.dumps({'observations':observations,'errors':errors}))
 if errors:raise RuntimeError('Final GUI failed')
asyncio.run(main())
