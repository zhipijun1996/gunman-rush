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
    if 'WINDCHIME PLAINS' not in text.upper() or '1/2' not in text:
        raise RuntimeError('Shipped formal entrance did not show connected region: '+text)
    # Actual right-upper minimap click; no calls into game state.
    await page.touchscreen.tap(*base.h.text_center('region-tutorial-spawn','EXPLORE'))
    await page.wait_for_timeout(400)
    await capture('region-map-open')
    map_text=(await asyncio.to_thread(base.h.ocr,'region-map-open')).upper()
    if 'EXPLORATION MAP' not in map_text or 'FOG' not in map_text:
        raise RuntimeError('Minimap click did not show the exploration modal: '+map_text)
    if any(hidden in map_text for hidden in ['WINDKEEPER','BELLSTRIDER','BELL WARDEN','CAMP / MERCHANT','DEEP TRIAL']):
        raise RuntimeError('Unexplored destination leaked into the initial large map: '+map_text)
    await page.touchscreen.tap(*base.h.text_center('region-map-open','FIND ME'))
    await page.wait_for_timeout(200)
    await capture('region-map-centered')
    await page.mouse.move(640,360)
    await page.mouse.wheel(0,-250)
    await page.wait_for_timeout(250)
    await capture('region-map-zoomed')
    await page.mouse.down()
    await page.mouse.move(780,420,steps=12)
    await page.mouse.up()
    await page.wait_for_timeout(200)
    await capture('region-map-dragged')
    from PIL import ImageChops
    region=(60,140,1200,600)
    if ImageChops.difference(base.h.picture('region-map-centered').crop(region),base.h.picture('region-map-zoomed').crop(region)).getbbox() is None:
        raise RuntimeError('Actual wheel input did not change the map image')
    if ImageChops.difference(base.h.picture('region-map-zoomed').crop(region),base.h.picture('region-map-dragged').crop(region)).getbbox() is None:
        raise RuntimeError('Actual drag input did not change the map image')
    await page.keyboard.press('Escape')
    await page.wait_for_timeout(200)
    await capture('region-map-closed')
    closed_text=(await asyncio.to_thread(base.h.ocr,'region-map-closed',(0,0,1100,220))).upper()
    if 'WINDCHIME PLAINS' not in closed_text or '1/2' not in closed_text:
        raise RuntimeError('Map close did not return to the first of two actual worlds: '+closed_text)
    report['checks'].append('Right-upper minimap opens fogged large map; unseen destinations hidden; actual focus, wheel zoom, drag and Escape close verified')
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
