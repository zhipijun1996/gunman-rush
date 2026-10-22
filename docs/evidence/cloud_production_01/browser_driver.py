import asyncio,json,os,re,shutil,subprocess,sys,time
from pathlib import Path
from playwright.async_api import async_playwright
url,out=sys.argv[1],Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
async def main():
 logs=[];errors=[];report={'url':url,'status':'failed','scope':'actual browser WASM boot, keyboard action and OCR-clicked full menu; no device/player approval'}
 started=time.monotonic()
 try:
  async with async_playwright() as p:
   opts={'executable_path':shutil.which('chromium'),'args':['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader']}
   if os.environ.get('HTTPS_PROXY'):opts['proxy']={'server':os.environ['HTTPS_PROXY'],'bypass':'localhost,127.0.0.1'}
   browser=await p.chromium.launch(**opts)
   context=await browser.new_context(viewport={'width':1280,'height':720})
   page=await context.new_page()
   page.on('console',lambda m:logs.append(m.text))
   page.on('pageerror',lambda e:errors.append(str(e)))
   await page.goto(url,wait_until='domcontentloaded',timeout=45000)
   await page.wait_for_function('window.PLAYTEST_LOADING_DONE === true',timeout=90000)
   for _ in range(100):
    if any('CLOUD PREVIEW:' in x and 'entry=actions' in x for x in logs):break
    await page.wait_for_timeout(100)
   if not any('CLOUD PREVIEW:' in x and 'entry=actions' in x and 'persistence=false' in x for x in logs):raise RuntimeError('Actual preview bootstrap did not log isolated actions entry')
   await page.screenshot(path=str(out/'entry.png'))
   await page.keyboard.down('d');await page.wait_for_timeout(300);await page.keyboard.up('d')
   await page.keyboard.press('Space');await page.wait_for_timeout(350)
   await page.mouse.move(800,500);await page.mouse.down();await page.wait_for_timeout(100);await page.mouse.up();await page.wait_for_timeout(450)
   await page.screenshot(path=str(out/'input.png'))
   text=subprocess.check_output(['tesseract',str(out/'input.png'),'stdout','--psm','11','tsv'],stderr=subprocess.DEVNULL,text=True)
   (out/'ocr.tsv').write_text(text)
   words=[r.split('\t') for r in text.splitlines()[1:]]
   full=[r for r in words if len(r)>11 and r[11].strip().upper()=='FULL']
   if not full:raise RuntimeError('Real FULL GAME button not found by screenshot OCR')
   r=full[0];point=[int(r[6])+int(r[8])/2,int(r[7])+int(r[9])/2];report['actual_button_click']=point
   await page.mouse.click(*point)
   for _ in range(50):
    if any('returned to full game menu' in x for x in logs):break
    await page.wait_for_timeout(100)
   if not any('returned to full game menu; persistence=false' in x for x in logs):raise RuntimeError('Actual menu button did not recreate isolated full App')
   await page.screenshot(path=str(out/'full-menu.png'))
   errors.extend(x for x in logs if any(m in x for m in ('SCRIPT ERROR','Parse Error','ERROR:','Failed to load script')))
   if errors:raise RuntimeError('Engine/browser errors observed')
   report.update(status='passed',checks=['real Godot WASM boot','actual actions entry','keyboard and pointer submitted','OCR-derived actual menu click','isolated full menu callback'],persistence='disabled for preview and recreated full App')
   await browser.close()
 except BaseException as e:report['error']=str(e)
 finally:
  report.update(seconds=time.monotonic()-started,errors=errors,console=logs)
  (out/'report.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
  print(json.dumps({k:v for k,v in report.items() if k!='console'},ensure_ascii=False))
 if report['status']!='passed':raise SystemExit(1)
asyncio.run(main())
