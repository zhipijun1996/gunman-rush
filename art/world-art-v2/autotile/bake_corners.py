#!/usr/bin/env python3
"""Mechanically cut authored concave quarters and reconnect to approved core.

Input spec: {"regions": {id: {"source": "assets/source/...png", "rects":
  {"NW":[x,y,w,h],"NE":[x,y,w,h],"SE":[x,y,w,h],"SW":[x,y,w,h]}}}}

Crop positions must be visually confirmed against the actual source. An optional
"sourceSha256" pins that review. This is not a terrain painting program.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

BASE = Path(__file__).resolve().parents[1]
ORDER = ("NW", "NE", "SE", "SW")
ORIGINS = ((0, 0), (16, 0), (16, 16), (0, 16))


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", default="autotile/corner-sources.json")
    args = parser.parse_args()
    spec = json.loads((BASE / args.spec).read_text())
    baseline = json.loads((BASE / "assets/pixel/manifest.json").read_text())
    output_dir = BASE / "assets/terrain47/corners"
    output_dir.mkdir(parents=True, exist_ok=True)
    records = {"version": "authored-concave-bake-v2", "quadrants": list(ORDER), "nativeQuarter": 16, "regions": {}}
    for region_id, entry in spec["regions"].items():
        source_path = BASE / entry["source"]
        source_sha = sha256(source_path)
        if entry.get("sourceSha256"):
            assert entry["sourceSha256"] == source_sha, f"Source changed after crop review: {source_path}"
        source = Image.open(source_path).convert("RGBA")
        terrain = baseline["terrains"][region_id]
        core_path = BASE / baseline["sprites"][terrain["asset"]]["file"]
        core = Image.open(core_path).convert("RGBA")
        tx, ty = terrain["coords"]["i"]
        strip = Image.new("RGBA", (64, 16))
        donor_strip = Image.new("RGBA", (64, 16))
        steps = []
        for index, (name, (qx, qy)) in enumerate(zip(ORDER, ORIGINS)):
            rect = entry["rects"][name]
            x, y, w, h = map(int, rect)
            assert 0 <= x < source.width and 0 <= y < source.height and x+w <= source.width and y+h <= source.height
            patch = source.crop((x, y, x+w, y+h))
            alpha = np.asarray(patch)[:, :, 3]
            # Ignore partial fringe pixels only for locating the opaque subject.
            ys, xs = np.where(alpha >= 128)
            assert len(xs), f"Empty source rectangle: {region_id} {name}"
            bbox = [int(xs.min()), int(ys.min()), int(xs.max()+1), int(ys.max()+1)] if entry.get("trim", True) else [0, 0, w, h]
            patch = patch.crop(tuple(bbox)).resize((16, 16), Image.Resampling.NEAREST)
            donor = np.array(patch)
            donor[:, :, 3] = np.where(donor[:, :, 3] >= 128, 255, 0).astype(np.uint8)
            donor[donor[:, :, 3] == 0, :3] = 0
            donor_strip.paste(Image.fromarray(donor), (index*16, 0))
            core_rect = [tx*32 + qx, ty*32 + qy, 16, 16]
            out = np.array(core.crop((core_rect[0], core_rect[1], core_rect[0]+16, core_rect[1]+16)))
            yy, xx = np.indices((16, 16))
            dx = xx if name in ("NW", "SW") else 15-xx
            dy = yy if name in ("NW", "NE") else 15-yy
            # A stable stepped geometry selects original pixels; no new colors,
            # stochastic pixels, blur, gradient, synthetic edge or texture drawing.
            radius = int(entry.get("cornerReach", 10))
            mask = (dx <= radius) & (dy <= radius) & (dx + dy <= radius + 3)
            out[mask] = donor[mask]
            empty_x = 0 if name in ("NW", "SW") else 15
            empty_y = 0 if name in ("NW", "NE") else 15
            assert out[empty_y, empty_x, 3] == 0, f"{region_id}/{name}: authored notch does not reach named corner after crop; revise crop/source."
            far = np.concatenate((out[15-empty_y, :, 3], out[:, 15-empty_x, 3]))
            assert np.all(far >= 128), f"{region_id}/{name}: approved core is not solid at quarter boundary."
            strip.paste(Image.fromarray(out), (index*16, 0))
            steps.append({"quadrant": name, "sourceRect": rect, "subjectTrimRect": bbox, "nearestTarget": [16, 16],
                          "alphaThreshold": 128, "coreSource": str(core_path.relative_to(BASE)), "coreRect": core_rect,
                          "selectionMask": {"rule": "dx<=reach and dy<=reach and dx+dy<=reach+3; dx/dy measure from the named corner", "reach": radius},
                          "sourcePixelsCopied": int(mask.sum()), "corePixelsCopied": int((~mask).sum()),
                          "transparentPixels": int(np.count_nonzero(out[:, :, 3] == 0))})
        out_path = output_dir / (region_id + ".png")
        donor_path = output_dir / (region_id + "_donors.png")
        strip.save(out_path)
        donor_strip.save(donor_path)
        records["regions"][region_id] = {"file": str(out_path.relative_to(BASE)), "sha256": sha256(out_path),
            "source": entry["source"], "sourceSha256": source_sha, "coreSha256": sha256(core_path), "donors": str(donor_path.relative_to(BASE)),
            "operations": "subject crop, nearest16 bake, binary alpha, geometric source-pixel selection over approved core", "quarters": steps}
        print(region_id, "corners baked")
    (output_dir / "manifest.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
    # Diagnostic contact sheet; source and final native16 quarters shown at4x.
    contact = Image.new("RGBA", (850, len(records["regions"]) * 80), (20, 24, 33, 255))
    draw = ImageDraw.Draw(contact)
    font_path = Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
    font = ImageFont.truetype(str(font_path), 11) if font_path.exists() else ImageFont.load_default()
    for row, (region_id, record) in enumerate(records["regions"].items()):
        draw.text((4, row*80+24), region_id, font=font, fill="#d2dfed")
        for column, key in enumerate(("donors", "file")):
            panel = Image.open(BASE / record[key]).resize((256, 64), Image.Resampling.NEAREST)
            contact.alpha_composite(panel, (190+column*320, row*80+12))
        draw.text((190, row*80), "SOURCE donors: NW NE SE SW", font=font, fill="#b8c5d6")
        draw.text((510, row*80), "CORE joined: NW NE SE SW", font=font, fill="#b8c5d6")
    (BASE / "autotile/previews").mkdir(parents=True, exist_ok=True)
    contact.save(BASE / "autotile/previews/corner-source-check.png")


if __name__ == "__main__":
    main()
