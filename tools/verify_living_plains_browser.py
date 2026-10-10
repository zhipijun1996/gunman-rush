"""Actual default Home departure and first-room bell interaction via visible GUI.
No engine injection: aim is located from the rendered label and its authored
visual offset. This verifies the shipped Web consumer, not all random routes.
"""
import asyncio
import csv
import io
import os
import subprocess
import sys
from pathlib import Path
import verify_plains_polish_browser as base

SIGN_REGION = (600, 210, 900, 300)

def sign_location(name, phrase):
    # Limit OCR to the visible sign; psm6 on a whole painted landscape treats
    # rock/grass detail as text. This is the same screenshot, not game state.
    text = base.h.ocr(name, SIGN_REGION)
    if phrase not in text.upper():
        raise RuntimeError('Expected visible sign ' + phrase + ': ' + text)
    result = subprocess.run(['tesseract', str(base.FOLDER / (name + '-ocr.png')), 'stdout', '--psm', '6', 'tsv'], capture_output=True, text=True, timeout=8, check=True, env={**os.environ, 'OMP_THREAD_LIMIT':'1'})
    words = [r for r in csv.DictReader(io.StringIO(result.stdout), delimiter='\t') if r.get('text','').strip().upper() in phrase.split()]
    if not words:
        raise RuntimeError('Visible sign has no OCR location')
    left = min(int(r['left']) for r in words)
    right = max(int(r['left']) + int(r['width']) for r in words)
    top = min(int(r['top']) for r in words)
    bottom = max(int(r['top']) + int(r['height']) for r in words)
    return (SIGN_REGION[0] + (left + right)/4, SIGN_REGION[1] + (top + bottom)/4)

async def probe(page, context, capture, report):
    await capture('formal-first-bell')
    first = await asyncio.to_thread(base.h.ocr, 'formal-first-bell', SIGN_REGION)
    if 'SHOOT BELL' not in first.upper():
        raise RuntimeError('Default first room does not visibly introduce its windchime: ' + first)
    report['checks'].append('Default formal room 1 shows SHOOT BELL without opening a development menu')
    # Leave the extreme left edge before firing: grounded recoil must have room.
    await page.keyboard.down('d')
    await page.wait_for_timeout(600)
    await page.keyboard.up('d')
    await page.wait_for_timeout(200)
    await capture('formal-bell-aim')
    center = await asyncio.to_thread(sign_location, 'formal-bell-aim', 'SHOOT BELL')
    # Label origin is bell + (-37,-78), 16px font; CameraRig zoom is 1.95.
    aim = (center[0] - 10 * 1.95, center[1] + 84 * 1.95)
    if not (0 < aim[0] < 1280 and 180 < aim[1] < 690):
        raise RuntimeError('Observed bell target is outside the playable viewport: ' + str(aim))
    await page.mouse.move(*aim)
    await page.mouse.down()
    await page.wait_for_timeout(180)
    await page.mouse.up()
    for attempt in range(12):
        await page.wait_for_timeout(150)
        await capture('formal-bell-open')
        text = await asyncio.to_thread(base.h.ocr, 'formal-bell-open', SIGN_REGION)
        if 'OPEN' in text.upper() and 'SHOOT BELL' not in text.upper():
            break
    else:
        raise RuntimeError('Real mouse release did not visibly open the formal bell gate: ' + text)
    report['formal_bell_aim_screen'] = aim
    report['formal_bell_open_ocr'] = text
    report['checks'].append('Real mouse aim/release sends projectile and changes first-room SHOOT BELL to OPEN')
    report['scope'] += '; first formal windchime visible and actually shot open'

if __name__ == '__main__':
    base.FOLDER = Path('build/verification/living-plains-browser')
    base.h.FOLDER = base.FOLDER
    server = None
    url = sys.argv[1] if len(sys.argv) > 1 else 'http://127.0.0.1:8788/'
    if len(sys.argv) == 1:
        server = subprocess.Popen([sys.executable, '-m', 'http.server', '8788', '--bind', '127.0.0.1', '--directory', 'build/web'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        asyncio.run(asyncio.wait_for(base.main(url, probe), timeout=260))
    finally:
        if server:
            server.terminate()
            server.wait(timeout=5)
