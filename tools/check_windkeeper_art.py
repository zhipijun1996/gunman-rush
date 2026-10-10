#!/usr/bin/env python3
"""Check untouched original Windkeeper source and measured atlas contracts."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / 'assets/plains_v4/windkeeper'
manifest = json.loads((PACK / 'manifest.json').read_text())
count = 0
for name, entry in manifest['textures'].items():
    source = PACK / name
    assert hashlib.sha256(source.read_bytes()).hexdigest() == entry['sha256'], name
    image = Image.open(source)
    assert image.mode == 'RGBA' and list(image.size) == entry['size'], name
    assert image.getchannel('A').getextrema()[0] == 0, name
    seen = set()
    for frame in entry['frames']:
        x, y, width, height = frame['region_xywh']
        assert min(x, y) >= 0 and min(width, height) > 0
        assert x + width <= image.width and y + height <= image.height
        crop = image.crop((x, y, x + width, y + height))
        digest = hashlib.sha256(crop.tobytes()).hexdigest()
        assert digest == frame['source_frame_sha256'] and digest not in seen
        seen.add(digest)
        alpha = crop.getchannel('A')
        bounds = alpha.point(lambda a: 255 if a > 128 else 0).getbbox()
        assert list(bounds) == frame['visible_bounds_alpha128_xyxy']
        ax, ay = frame['anchor_px']
        assert 0 <= ax <= width and 0 <= ay <= height
        assert alpha.getextrema()[0] == 0 and alpha.getextrema()[1] > 128
        count += 1
    imported = source.with_suffix('.png.import').read_text()
    assert 'compress/mode=1' in imported and 'compress/lossy_quality=0.85' in imported
assert {f['id'] for f in manifest['textures']['body_actions.png']['frames']} == {
    'idle', 'stomp', 'charge', 'exposed', 'blades', 'dead'}
assert {f['id'] for f in manifest['textures']['parts.png']['frames']} == {
    'rotor', 'bell', 'mast', 'broken_bell'}
print(f'PASS: Windkeeper art: 2 original sources, {count} distinct parts/poses, SHA/alpha/crops/anchors/import. Visual/device acceptance separate.')
