#!/usr/bin/env python3
"""Verify original meadow material atlas, regions and transparency contract."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets/plains_v4/ground"
manifest = json.loads((PACK / "manifest.json").read_text())
path = PACK / manifest["source_file"]
assert hashlib.sha256(path.read_bytes()).hexdigest() == manifest["source_sha256"]
image = Image.open(path)
assert image.mode == manifest["source_mode"] == "RGBA"
assert list(image.size) == manifest["source_dimensions"]
assert list(image.getchannel("A").getextrema()) == manifest["alpha_range"]
assert manifest["alpha_range"][0] == 0
assert 0 < manifest["uniform_scale"] <= 0.2
for name, region in manifest["regions"].items():
    x, y, width, height = region
    assert min(x, y) >= 0 and min(width, height) > 0
    assert x + width <= image.width and y + height <= image.height
    alpha = image.crop((x, y, x + width, y + height)).getchannel("A")
    bounds = alpha.point(lambda a: 255 if a > 128 else 0).getbbox()
    assert bounds is not None and alpha.getextrema()[0] == 0
    actual = [bounds[0] + x, bounds[1] + y, bounds[2] + x, bounds[3] + y]
    assert actual == manifest["visible_bounds_alpha128_xyxy"][name]
    assert width / height > 9, "Material band must remain shallow, not a platform."
    composition = manifest["composition"][name]
    assert abs(composition["world_height"] - height * manifest["uniform_scale"]) < 0.001
    for part in ("left_cap", "middle", "right_cap"):
        px, py, pw, ph = composition[part]
        assert px >= x and py >= y and px + pw <= x + width and py + ph <= y + height
upper = manifest["regions"]["soil_roots"]
lower = manifest["regions"]["thorn_root_bed"]
assert upper[1] + upper[3] < lower[1]
gutter = image.getchannel("A").crop((0, upper[1] + upper[3], image.width, lower[1]))
assert sum(gutter.histogram()[129:]) == 0
imported = path.with_suffix(".png.import").read_text()
assert "compress/mode=1" in imported and "compress/lossy_quality=0.85" in imported
print("PASS: meadow ground art: original SHA/RGBA, 2 shallow isolated bands, alpha bounds, uniform scale/crops and import. Runtime/device acceptance separate.")
