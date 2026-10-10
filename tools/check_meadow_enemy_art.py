#!/usr/bin/env python3
"""Validate generated candidate art without claiming gameplay/device approval."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / 'assets/plains_v3/enemies/meadow_actions'
manifest = json.loads((PACK / 'manifest.json').read_text())
frames_checked = 0
for name, entry in manifest['species'].items():
    path = PACK / entry['texture']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], name
    image = Image.open(path)
    assert image.mode == 'RGBA' and list(image.size) == entry['size'], name
    assert image.getchannel('A').getextrema()[0] == 0, name
    seen = set()
    for frame in entry['frames']:
        x, y, width, height = frame['region_xywh']
        assert min(x, y) >= 0 and min(width, height) > 0
        assert x + width <= image.width and y + height <= image.height
        pixels = image.crop((x, y, x + width, y + height))
        digest = hashlib.sha256(pixels.tobytes()).hexdigest()
        assert digest == frame['source_frame_sha256'] and digest not in seen
        seen.add(digest)
        assert list(pixels.getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox()) == frame['visible_bounds_alpha128_xyxy']
        ax, ay = frame['anchor_px']
        assert 0 <= ax <= width and 0 <= ay <= height
        assert ay == frame['visible_bounds_alpha128_xyxy'][3]
        frames_checked += 1
    assert {f['id'] for f in entry['frames']} == {'idle_a', 'idle_b', 'telegraph', 'attack', 'recovery', 'death'}
    imported = path.with_suffix('.png.import').read_text()
    assert 'compress/mode=1' in imported and 'compress/lossy_quality=0.85' in imported
print(f'PASS: meadow enemy art: {len(manifest["species"])} sources, {frames_checked} distinct poses, SHA/alpha/crops/feet/import. Runtime and device pending.')
