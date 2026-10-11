"""Real default Title/Home/departure, region map and tutorial motion.
No game-state injection. Full loops and deep challenges use the separate real
Motor trace suite; this browser check does not claim human region completion.
"""
import asyncio
import os
from pathlib import Path
import subprocess
import sys
import verify_plains_polish_browser as base

async def probe(page, context, capture, report):
    await capture('region-tutorial-spawn')
    text = await asyncio.to_thread(base.h.ocr,'region-tutorial-spawn',(0,0,1100,220))
    if 'CONNECTED REGION' not in text.upper():
        raise RuntimeError('Shipped formal entrance did not show connected region: '+text)
    await page.keyboard.down('d')
    await page.wait_for_timeout(250)
    await page.keyboard.down('Space')
    await page.wait_for_timeout(420)
    await page.keyboard.up('Space')
    await page.wait_for_timeout(350)
    await page.keyboard.up('d')
    await capture('region-held-jump')
    # Actual aim/release anywhere in visible space exercises the shipped recoil
    # and pooled sound consumers. This does not claim a gate opening or a long gap.
    await page.mouse.move(200,650)
    await page.mouse.down()
    await page.wait_for_timeout(120)
    await page.mouse.up()
    await page.wait_for_timeout(300)
    await capture('region-recoil-input')
    report['checks'].append('Default connected-region tutorial receives ordinary held jump, movement and real mouse release; captures retained')
    report['scope']='Actual default Home purchase/persistence/departure and region tutorial movement/recoil input; full region traversal remains a separate physics test'

if __name__ == '__main__':
    base.FOLDER=Path('build/verification/plains-region-browser')
    base.h.FOLDER=base.FOLDER
    server=None
    url=sys.argv[1] if len(sys.argv)>1 else 'http://127.0.0.1:8798/'
    if len(sys.argv)==1:
        server=subprocess.Popen([sys.executable,'-m','http.server','8798','--bind','127.0.0.1','--directory','build/web'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    try:
        asyncio.run(asyncio.wait_for(base.main(url,probe),timeout=260))
    finally:
        if server:
            server.terminate()
            server.wait(timeout=5)
