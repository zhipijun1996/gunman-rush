"""Decode the authored palette-index pixels; no geometric drawing or resampling.
This scoped original-pixel production method was explicitly authorized for this
spider prototype. It is not an imagegen edit or a rule for future art sources.
"""
from pathlib import Path
import json
from PIL import Image

root = Path(__file__).resolve().parent
rows = (root / 'spider-authored.rows').read_text().splitlines()
palette = json.loads((root / 'spider.palette.json').read_text())['palette']
assert len(rows) == 32 and all(len(row) == 32 for row in rows)
assert set(''.join(rows)) <= set(palette)
image = Image.new('RGBA', (32, 32))
image.putdata([tuple(palette[symbol]) for row in rows for symbol in row])
image.save(root / 'spider.native.png')
