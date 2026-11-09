#!/usr/bin/env python3
"""Mechanically cut v2 source sheets and bake native, independent PNG assets.

No new texture or silhouette is painted here. All RGB pixels come from recorded
source PNGs. The map locks measured source boundaries to SHA-256 hashes, and
each result retains its crop, component labels, sizing, and alpha policy.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "assets/pixel/v2"
MANIFEST = ROOT / "assets/pixel/manifest.json"
MAP = ROOT / "v2-assets-map.json"
REPORT = ROOT / "v2-assets-report.json"
PREVIEWS = ROOT / "previews"
ALPHA_MIN = 128


def sha(path_or_bytes):
    blob = path_or_bytes.read_bytes() if isinstance(path_or_bytes, Path) else path_or_bytes
    return hashlib.sha256(blob).hexdigest()


def dump(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def relative(path):
    return str(path.relative_to(ROOT))


def source_info(path, minimum_area=8):
    image = Image.open(path).convert("RGBA")
    array = np.array(image)
    labels, count = ndimage.label(array[..., 3] >= ALPHA_MIN, np.ones((3, 3)))
    objects = ndimage.find_objects(labels)
    areas = np.bincount(labels.ravel())
    components = []
    for label, slices in enumerate(objects, 1):
        if slices is None or int(areas[label]) < minimum_area:
            continue
        yy, xx = slices
        ys, xs = np.where(labels[yy, xx] == label)
        components.append({
            "label": label,
            "area": int(areas[label]),
            "bbox": [xx.start, yy.start, xx.stop, yy.stop],
            "centroid": [float(xs.mean() + xx.start), float(ys.mean() + yy.start)],
        })
    return {
        "image": image,
        "array": array,
        "labels": labels,
        "components": components,
        "sha256": sha(path),
        "width": image.width,
        "height": image.height,
        "alpha": {
            "transparentPixels": int(np.sum(array[..., 3] == 0)),
            "opaquePixels": int(np.sum(array[..., 3] == 255)),
            "partialPixels": int(np.sum((array[..., 3] > 0) & (array[..., 3] < 255))),
        },
        "minimumComponentArea": minimum_area,
        "totalComponents": int(count),
        "retainedComponents": len(components),
        "discardedPixels": int(sum(areas[i] for i in range(1, len(areas)) if areas[i] < minimum_area)),
    }


def serial_info(info):
    return {k: v for k, v in info.items() if k not in ("image", "array", "labels")}


def font(size):
    candidates = [
        Path("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
    ]
    for path in candidates:
        if path.is_file():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def inspect_source(path, output=None):
    info = source_info(path)
    data = serial_info(info)
    if output:
        output.parent.mkdir(parents=True, exist_ok=True)
        dump(output.with_suffix(".json"), data)
        background = Image.new("RGBA", info["image"].size, (38, 45, 53, 255))
        background.alpha_composite(info["image"])
        draw = ImageDraw.Draw(background)
        for component in info["components"]:
            if component["area"] < 200:
                continue
            x1, y1, x2, y2 = component["bbox"]
            draw.rectangle([x1, y1, x2 - 1, y2 - 1], outline=(255, 158, 80), width=2)
            draw.text((x1 + 2, y1 + 2), str(component["label"]), font=font(16), fill=(255, 230, 170))
        background.convert("RGB").save(output.with_suffix(".png"))
    return data


def measured_edges(job, axis, length, count):
    edges = job.get(axis + "Edges")
    if edges is None:
        return [round(length * n / count) for n in range(count + 1)]
    if len(edges) != count + 1 or edges[0] != 0 or edges[-1] != length:
        raise ValueError(f"{job['file']}: {axis}Edges must be pixel coordinates spanning 0..{length}")
    if any(a >= b for a, b in zip(edges[:-1], edges[1:])):
        raise ValueError("Non-increasing grid edges")
    return edges


def group_components(info, job):
    rows, cols = job["rows"], job["cols"]
    xe = measured_edges(job, "column", info["width"], cols)
    ye = measured_edges(job, "row", info["height"], rows)
    grouped = {(y, x): [] for y in range(rows) for x in range(cols)}
    for component in info["components"]:
        cx, cy = component["centroid"]
        col = int(np.searchsorted(xe, cx, side="right") - 1)
        row = int(np.searchsorted(ye, cy, side="right") - 1)
        grouped[row, col].append(component)
    return grouped, xe, ye


def fit(rect, max_size):
    width, height = rect[2] - rect[0], rect[3] - rect[1]
    scale = min(max_size[0] / width, max_size[1] / height)
    return [max(1, round(width * scale)), max(1, round(height * scale))]


def silhouette_report(image):
    mask = np.array(image)[..., 3] >= ALPHA_MIN
    return {
        "alphaValues": sorted(int(v) for v in np.unique(np.array(image)[..., 3])),
        "opaquePixels": int(mask.sum()),
        "occupancy": round(float(mask.mean()), 5),
        "opaqueEdgePixels": {
            "top": int(mask[0, :].sum()), "bottom": int(mask[-1, :].sum()),
            "left": int(mask[:, 0].sum()), "right": int(mask[:, -1].sum()),
        },
    }


def bake_entry(job, entry, info, pieces, xe=None, ye=None):
    background = job["kind"] == "background"
    if background:
        rect = entry.get("sourceRect", [0, 0, info["width"], info["height"]])
        array = info["array"][rect[1]:rect[3], rect[0]:rect[2]].copy()
        size = entry.get("nativeSize", [640, 360])
        if (array[..., 3] < ALPHA_MIN).any():
            raise ValueError(f"{entry['key']}: far background unexpectedly contains transparent pixels")
    else:
        if not pieces:
            raise ValueError(f"{entry['key']}: no retained components in its measured cell")
        if "componentLabels" in entry:
            chosen = set(entry["componentLabels"])
            pieces = [p for p in info["components"] if p["label"] in chosen]
            if {p["label"] for p in pieces} != chosen:
                raise ValueError(f"{entry['key']}: requested source labels are missing")
        rect = [min(p["bbox"][0] for p in pieces), min(p["bbox"][1] for p in pieces),
                max(p["bbox"][2] for p in pieces), max(p["bbox"][3] for p in pieces)]
        if any((rect[0] == 0, rect[1] == 0, rect[2] == info["width"], rect[3] == info["height"])):
            raise ValueError(f"{entry['key']}: source object touches the sheet border; review or redraw")
        array = info["array"][rect[1]:rect[3], rect[0]:rect[2]].copy()
        # Preserve only the measured original components, avoiding a neighbouring
        # object's pixels when natural silhouettes have overlapping bounding boxes.
        labels = info["labels"][rect[1]:rect[3], rect[0]:rect[2]]
        keep = np.isin(labels, [p["label"] for p in pieces])
        array[~keep] = 0
        size = entry.get("nativeSize") or fit(rect, entry["maxSize"])
    opaque = array[..., 3] >= ALPHA_MIN
    array[~opaque] = 0
    array[opaque, 3] = 255
    image = Image.fromarray(array, "RGBA").resize(tuple(size), Image.Resampling.NEAREST)
    gutter = 0 if background else entry.get("gutter", 1)
    if gutter:
        padded = Image.new("RGBA", (size[0] + 2 * gutter, size[1] + 2 * gutter))
        padded.paste(image, (gutter, gutter))
        image = padded
    path = OUT / (entry["key"] + ".png")
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)
    source_rect = {"left": rect[0], "top": rect[1], "width": rect[2] - rect[0], "height": rect[3] - rect[1]}
    item = {
        "file": relative(path), "w": image.width, "h": image.height,
        "regionId": entry["regionId"], "role": entry["role"],
        "sourceFile": job["file"], "sourceSha256": info["sha256"], "sourceRect": source_rect,
        "sha256": sha(path), "worldUnitsPerPixel": 1, "filter": "nearest", "alphaMode": "binary",
        "processing": {"method": "source crop, original-component isolation, nearest-neighbor native bake, alpha>=128 threshold, transparent gutter",
                       "contentSize": size, "gutter": gutter, "alphaThreshold": ALPHA_MIN,
                       "minimumComponentArea": info["minimumComponentArea"]},
        "label": entry.get("label", entry["key"]),
        "artVersion": "v2-47-depth-expansion",
    }
    if not background:
        item["pivotX"] = entry.get("pivotX", round(image.width / 2))
        item["pivotY"] = entry.get("pivotY", image.height - gutter)
        item["sourceGrid"] = {"rows": job["rows"], "cols": job["cols"], "row": entry["row"], "col": entry["col"],
                              "columnEdges": xe, "rowEdges": ye, "review": job.get("gridReview", "measured component grouping")}
        item["extraction"] = {"componentLabels": [p["label"] for p in pieces],
                              "componentAreas": [p["area"] for p in pieces],
                              "method": "8-connected alpha components, measured cell centroid assignment, union bounding box"}
        item["aspectRatioPreserved"] = "nativeSize" not in entry
        item["collisionStatus"] = "visual asset only; no collision or gameplay behaviour added"
    else:
        item["resampling"] = "full recorded plate to native 640x360, nearest-neighbor"
    if "placementScope" in entry:
        item["placementScope"] = entry["placementScope"]
    return item, {**copy.deepcopy(item), "nativeAlpha": silhouette_report(image)}


def make_boards(manifest, report):
    PREVIEWS.mkdir(exist_ok=True)
    region_ids = manifest["regionIds"]
    names = {r["id"]: r.get("name_zh", r.get("name", r["id"])) for r in json.loads((ROOT / "region-plan.json").read_text())["regions"]}
    hero = Image.open(ROOT / manifest["sprites"]["hero"]["file"]).convert("RGBA")
    for category, predicate in [
        ("props", lambda x: x["role"] == "regional-feature-prop"),
        ("depth", lambda x: x["role"] in ("independent-mid-background", "platform-height-near-foreground")),
    ]:
        regions = [(rid, [item for item in report["sprites"].values() if item["regionId"] == rid and predicate(item)]) for rid in region_ids]
        regions = [(rid, items) for rid, items in regions if items]
        if not regions:
            continue
        # All samples share a native scale. Labels are separate from source art.
        scale = 2
        cols = 4 if category == "props" else 2
        cell_w = 360 if category == "props" else 520
        row_h = max(250, max(item["h"] for _, items in regions for item in items) * scale + 104)
        board = Image.new("RGBA", (cols * cell_w, 82 + len(regions) * row_h), (24, 32, 40, 255))
        draw = ImageDraw.Draw(board)
        draw.text((22, 16), "V2 REGIONAL " + category.upper() + " / native pixels ×2", fill=(230, 235, 231), font=font(24))
        draw.text((22, 48), "Transparent independent PNGs · 1px = 1 world unit · hero body 44wu", fill=(153, 174, 176), font=font(15))
        for row, (rid, items) in enumerate(regions):
            top = 82 + row * row_h
            draw.rectangle([0, top, board.width, top + 38], fill=(33, 44, 51))
            draw.text((20, top + 6), str(names.get(rid, rid)), fill=(227, 230, 214), font=font(18))
            for col, item in enumerate(items[:cols]):
                x = col * cell_w
                sprite = Image.open(ROOT / item["file"]).convert("RGBA")
                large = sprite.resize((sprite.width * scale, sprite.height * scale), Image.Resampling.NEAREST)
                baseline = top + row_h - 57
                draw.line((x + 14, baseline, x + cell_w - 14, baseline), fill=(63, 77, 82), width=1)
                board.alpha_composite(large, (x + (cell_w - large.width) // 2, baseline - large.height))
                draw.text((x + 15, top + row_h - 48), str(item.get("label", item["role"])), fill=(215, 220, 209), font=font(16))
                draw.text((x + 15, top + row_h - 25), f"{sprite.width}×{sprite.height}px / pivot {item.get('pivotX')},{item.get('pivotY')}", fill=(143, 164, 170), font=font(13))
        board.convert("RGB").save(PREVIEWS / f"v2-assets-{category}.png", optimize=True)
        for group in range((len(regions) + 3) // 4):
            count = min(4, len(regions) - group * 4)
            panel = Image.new("RGB", (board.width, 82 + count * row_h), (24, 32, 40))
            panel.paste(board.crop((0, 0, board.width, 82)).convert("RGB"), (0, 0))
            panel.paste(board.crop((0, 82 + group * 4 * row_h, board.width, 82 + (group * 4 + count) * row_h)).convert("RGB"), (0, 82))
            panel.save(PREVIEWS / f"v2-assets-{category}-{group + 1}.png", optimize=True)
    backgrounds = list(report.get("backgrounds", {}).values())
    if backgrounds:
        board = Image.new("RGB", (1280, len(backgrounds) * 780), (24, 32, 40))
        draw = ImageDraw.Draw(board)
        for i, item in enumerate(backgrounds):
            y = i * 780
            draw.text((18, y + 14), str(names.get(item["regionId"], item["regionId"])) + " · v2 far plate", fill=(230, 235, 231), font=font(24))
            background = Image.open(ROOT / item["file"]).convert("RGB").resize((1280, 720), Image.Resampling.NEAREST)
            board.paste(background, (0, y + 60))
        board.save(PREVIEWS / "v2-assets-backgrounds.png", optimize=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inspect", type=Path)
    parser.add_argument("--inspect-output", type=Path)
    parser.add_argument("--sources", nargs="*", help="Only bake named source basenames (report is merged).")
    parser.add_argument("--boards-only", action="store_true")
    args = parser.parse_args()
    if args.inspect:
        data = inspect_source(args.inspect, args.inspect_output)
        print(json.dumps({k: v for k, v in data.items() if k != "components"}, ensure_ascii=False, indent=2))
        return
    manifest = json.loads(MANIFEST.read_text())
    report = json.loads(REPORT.read_text()) if REPORT.exists() else {
        "schema": "clock-world-art-v2-native-assets-report", "worldUnitsPerPixel": 1, "filter": "nearest",
        "sprites": {}, "backgrounds": {}, "sources": {},
        "scope": "Independent v2 source-derived regional props, platform-height near foreground, mid layers, and revised plains/forest far plates",
    }
    if args.boards_only:
        make_boards(manifest, report)
        return
    mapping = json.loads(MAP.read_text())
    jobs = [j for j in mapping["sources"] if not args.sources or Path(j["file"]).name in args.sources]
    if not jobs:
        raise ValueError("No matching source jobs")
    allowed_keys = {entry["key"] for job in mapping["sources"] for entry in job["entries"]}
    before_sprites = {k: copy.deepcopy(v) for k, v in manifest["sprites"].items() if k not in allowed_keys}
    before_backgrounds = {k: copy.deepcopy(v) for k, v in manifest["backgrounds"].items() if k not in allowed_keys}
    for job in jobs:
        source = ROOT / job["file"]
        info = source_info(source, job.get("minimumComponentArea", 8))
        if info["sha256"] != job["sha256"]:
            raise ValueError(f"{job['file']}: SHA mismatch; inspect source before changing the recorded geometry")
        serial = serial_info(info)
        report["sources"][job["file"]] = {**serial, "visualReview": job.get("sourceReview"),
                                          "gridReview": job.get("gridReview")}
        manifest["sourceFiles"][Path(job["file"]).name] = {"sha256": info["sha256"], "width": info["width"], "height": info["height"]}
        if job["kind"] == "background":
            groups, xe, ye = None, None, None
        else:
            if not info["alpha"]["transparentPixels"]:
                raise ValueError(f"{job['file']}: sprite source has no transparent pixels")
            groups, xe, ye = group_components(info, job)
        for entry in job["entries"]:
            pieces = [] if groups is None else groups[entry["row"], entry["col"]]
            item, record = bake_entry(job, entry, info, pieces, xe, ye)
            category = "backgrounds" if job["kind"] == "background" else "sprites"
            manifest[category][entry["key"]] = item
            report[category][entry["key"]] = record
    if before_sprites != {k: v for k, v in manifest["sprites"].items() if k not in allowed_keys}:
        raise AssertionError("A preserved sprite record changed")
    if before_backgrounds != {k: v for k, v in manifest["backgrounds"].items() if k not in allowed_keys}:
        raise AssertionError("A preserved background record changed")
    report["counts"] = {
        "sprites": len(report["sprites"]), "backgrounds": len(report["backgrounds"]),
        "props": sum(v["role"] == "regional-feature-prop" for v in report["sprites"].values()),
        "midLayers": sum(v["role"] == "independent-mid-background" for v in report["sprites"].values()),
        "nearLayers": sum(v["role"] == "platform-height-near-foreground" for v in report["sprites"].values()),
        "sources": len(report["sources"]),
    }
    manifest["v2ArtExpansion"] = {"script": "bake-v2-assets.py", "map": "v2-assets-map.json", "report": "v2-assets-report.json",
                                  "counts": report["counts"], "preservesPreviousKeys": True,
                                  "sourceFiles": list(report["sources"]), "spriteKeys": list(report["sprites"]),
                                  "backgroundKeys": list(report["backgrounds"])}
    dump(MANIFEST, manifest)
    dump(REPORT, report)
    make_boards(manifest, report)
    print(json.dumps({"counts": report["counts"], "report": relative(REPORT), "preservedOldSpriteKeys": len(before_sprites),
                      "preservedOldBackgroundKeys": len(before_backgrounds)}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
