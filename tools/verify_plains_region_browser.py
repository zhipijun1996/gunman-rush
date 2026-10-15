"""Real default Title/Home/departure, region map and tutorial motion.
No game-state injection. Full loops and deep challenges use the separate real
Motor trace suite; this browser check does not claim human region completion.
"""
import asyncio
import csv
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import verify_plains_polish_browser as base

def map_chip_center(source, output):
    """Read the compact chip from actual pixels, preserving all GUI assertions.

    The shipped actor-safe layout uses right-top or right-bottom anchors. Sparse
    full-screen OCR misses its 12px light text. These crops are search windows,
    never fallback click positions; an exact observed label supplies the point.
    """
    from PIL import Image, ImageOps
    source, output = Path(source), Path(output)
    output.mkdir(parents=True, exist_ok=True)
    image = Image.open(source).convert('RGB')
    width, height = image.size
    scale = 3
    observations, candidates = [], []
    for name, region in [('top', (max(0, width-360), 0, width, min(170, height))),
                         ('bottom', (max(0, width-360), max(0, height-170), width, height))]:
        crop = ImageOps.invert(ImageOps.grayscale(image.crop(region)))
        crop = crop.resize((crop.width*scale, crop.height*scale))
        path = output / (name+'.ocr.png')
        crop.save(path)
        result = subprocess.run(['tesseract', str(path), 'stdout', '--psm', '6', 'tsv'],
                                capture_output=True, text=True, timeout=8, check=True,
                                env={**os.environ, 'OMP_THREAD_LIMIT': '1'})
        (output/(name+'.tsv')).write_text(result.stdout)
        rows = [row for row in csv.DictReader(io.StringIO(result.stdout), delimiter='\t')
                if row.get('text', '').strip()]
        lines = {}
        for row in rows:
            lines.setdefault(tuple(row[k] for k in ('block_num', 'par_num', 'line_num')), []).append(row)
        observations.append({'region': list(region), 'scale': scale, 'words': rows})
        for words in lines.values():
            labels = [row['text'].strip().upper() for row in words]
            if not {'MAP', '1/2', 'EXPLORE'}.issubset(labels):
                continue
            for row in words:
                if row['text'].strip().upper() == 'EXPLORE':
                    candidates.append([region[0]+(int(row['left'])+int(row['width'])/2)/scale,
                                       region[1]+(int(row['top'])+int(row['height'])/2)/scale])
    observation = {'source': str(source), 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                   'method': 'Actual right-column pixels, inverted grayscale3x OCR; no UI/game state injection',
                   'searches': observations, 'candidates': candidates}
    (output/'observation.json').write_text(json.dumps(observation, indent=2)+'\n')
    if len(candidates) != 1:
        raise RuntimeError('Actual rendered MAP 1/2 EXPLORE label missing or ambiguous: '+str(candidates))
    return candidates[0], observation

async def probe(page, context, capture, report):
    await capture('region-tutorial-spawn')
    text = await asyncio.to_thread(base.h.ocr,'region-tutorial-spawn',(0,0,1100,220))
    if 'WINDCHIME PLAINS' not in text.upper() or '1/2' not in text:
        raise RuntimeError('Shipped formal entrance did not show connected region: '+text)
    # Actual right-upper minimap click; no calls into game state.
    point, observation = await asyncio.to_thread(map_chip_center,
        base.FOLDER/'region-tutorial-spawn.png', base.FOLDER/'map-chip-ocr')
    report['actual_map_chip_locator'] = observation
    await page.touchscreen.tap(*point)
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
