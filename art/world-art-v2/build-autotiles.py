#!/usr/bin/env python3
"""Bake authored native-pixel sources into real 47-neighbor terrain atlases.

Only crops, exact quarter composition and atlas packing happen here. No material
texture, bevel, grass, root, ice or regional detail is painted by this program.

python3 build-autotiles.py
python3 build-autotiles.py --regions windchime_plains
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

BASE = Path(__file__).resolve().parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(BASE / "autotile"))
from mask47 import MASKS, MASK_TO_ATLAS, NEIGHBORS, QUADRANTS, all_mask_fixture, feature_fixture, mask_at, normalize, quarter_recipes

REGIONS = [
    ("windchime_plains", "风铃平原"), ("thorn_forest", "荆棘森林"),
    ("mushroom_caverns", "蕈灯地穴"), ("firefly_marsh", "萤雾沼泽"),
    ("windswept_canyon", "风蚀峡谷"), ("frostmirror_glacier", "霜镜冰川"),
    ("moonshadow_cemetery", "月影墓园"), ("moon_crown_castle", "月冠古堡"),
    ("gear_city", "齿轮工城"), ("echo_mines", "回声矿井"),
    ("ember_depths", "熔火腹地"), ("root_sanctuary", "根脉圣殿"),
    ("sunken_ruins", "沉水遗迹"), ("shattered_isles", "破碎浮岛"),
    ("starbridge_gate", "星桥天门"), ("world_clockheart", "世界钟心"),
]


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_json(path, data):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def source_record(path):
    im = Image.open(path)
    return {"file": str(Path(path).relative_to(BASE)), "sha256": sha256(path), "size": list(im.size), "mode": im.mode}


def get_font(size=14):
    for candidate in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf"):
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


def crop(im, rect):
    x, y, w, h = rect
    return im.crop((x, y, x + w, y + h))


def bake_region(region_id, baseline):
    terrain = baseline["terrains"][region_id]
    sprite = baseline["sprites"][terrain["asset"]]
    source_path = BASE / sprite["file"]
    source = Image.open(source_path).convert("RGBA")
    records = [source_record(source_path)]
    atlas = Image.new("RGBA", (256, 192))
    tiles, recipes = {}, {}
    if region_id == "windchime_plains":
        old_path = BASE / "references/underworld-origin/formal-fine32-terrain_build.json"
        old = json.loads(old_path.read_text())
        assert records[0]["sha256"] == old["atlas_sha256"], "The approved plains atlas changed; review before rebaking."
        assert set(map(int, old["mask_to_atlas"])) == set(MASKS)
        for mask in MASKS:
            x, y = map(int, old["mask_to_atlas"][str(mask)])
            rect = [x * 32, y * 32, 32, 32]
            tiles[mask] = crop(source, rect)
            recipes[str(mask)] = {"mode": "approved-plains-bank0-pixel-identical", "source": records[0]["file"], "sourceRect": rect,
                                  "originalRecipe": old.get("source_regions", {}).get(str(mask), [])}
    else:
        corner_path = BASE / "assets/terrain47/corners" / (region_id + ".png")
        if not corner_path.exists():
            raise FileNotFoundError(f"Missing authored concave corners: {corner_path}. No placeholder tiles are emitted.")
        corners = Image.open(corner_path).convert("RGBA")
        if corners.size != (64, 16):
            raise ValueError(f"{corner_path}: expected NW/NE/SE/SW 16px quarters in a 64x16 strip, got {corners.size}.")
        records.append(source_record(corner_path))
        for mask in MASKS:
            tile = Image.new("RGBA", (32, 32))
            steps = []
            for i, step in enumerate(quarter_recipes(mask)):
                x, y, w, h = step["destination"]
                if step["state"] == "concave":
                    patch_rect = [i * 16, 0, 16, 16]
                    patch = crop(corners, patch_rect)
                    source_file = records[1]["file"]
                else:
                    tx, ty = terrain["coords"][step["tile"]]
                    patch_rect = [tx * 32 + x, ty * 32 + y, 16, 16]
                    patch = crop(source, patch_rect)
                    source_file = records[0]["file"]
                # Copy RGBA bytes directly. Alpha compositing here would multiply
                # already authored partial alpha and corrupt source equality.
                tile.paste(patch, (x, y))
                steps.append({**step, "source": source_file, "sourceRect": patch_rect})
            tiles[mask] = tile
            recipes[str(mask)] = {"mode": "authored-quarter-assembly", "quarters": steps}
    for mask, im in tiles.items():
        x, y = MASK_TO_ATLAS[mask]
        atlas.paste(im, (x * 32, y * 32))
    return atlas, tiles, recipes, records


def render_map(tiles, fixture, show_masks=False):
    image = Image.new("RGBA", (fixture["widthCells"] * 32, fixture["heightCells"] * 32), (16, 20, 30, 255))
    cells = {tuple(c) for c in fixture["cells"]}
    for x, y in cells:
        image.alpha_composite(tiles[mask_at(cells, x, y)], (x * 32, y * 32))
    if show_masks:
        draw = ImageDraw.Draw(image)
        font = get_font(12)
        for entry in fixture["centers"]:
            x, y = entry["cell"]
            draw.rectangle((x * 32 - 1, y * 32 - 1, x * 32 + 32, y * 32 + 32), outline=(223, 186, 107))
            draw.text((x * 32 - 1, (y + 2) * 32 + 2), str(entry["mask"]), font=font, fill=(222, 226, 230))
    return image


def focused_validation(region_id, atlas, tiles, recipes, records, fixture):
    """Structural acceptance plus visible-surface statistics, never aesthetic scoring."""
    assert atlas.size == (256, 192)
    assert len(tiles) == 47
    tile_hashes = {mask: hashlib.sha256(im.tobytes()).hexdigest() for mask, im in tiles.items()}
    unique_count = len(set(tile_hashes.values()))
    assert unique_count == 47, f"{region_id}: {unique_count}/47 unique tiles: possible duplicated topology."
    assert not np.asarray(atlas)[160:192, 224:256, 3].any(), "Unused 48th slot must remain transparent."
    sources = {r["file"]: Image.open(BASE / r["file"]).convert("RGBA") for r in records}
    source_copy_count = 0
    for mask in MASKS:
        recipe = recipes[str(mask)]
        if "quarters" in recipe:
            for step in recipe["quarters"]:
                expected = crop(sources[step["source"]], step["sourceRect"])
                actual = crop(tiles[mask], step["destination"])
                assert actual.tobytes() == expected.tobytes()
                source_copy_count += 1
        else:
            assert tiles[mask].tobytes() == crop(sources[recipe["source"]], recipe["sourceRect"]).tobytes()
            source_copy_count += 1
    # A connected cell must retain a central material bridge. Surface decoration
    # can make edge alpha differ near the outer contour; no RGB seam claims are made.
    missing_bridges = []
    bridge_samples = []
    for mask, im in tiles.items():
        alpha = np.asarray(im)[:, :, 3]
        for name, bit, _, _, _, _ in NEIGHBORS:
            if name not in ("N", "E", "S", "W") or not mask & bit:
                continue
            strip = {"N": alpha[0, 12:20], "S": alpha[-1, 12:20], "E": alpha[12:20, -1], "W": alpha[12:20, 0]}[name]
            coverage = int(np.count_nonzero(strip >= 128))
            bridge_samples.append(coverage)
            if coverage == 0:
                missing_bridges.append({"mask": mask, "side": name})
    assert not missing_bridges, f"{region_id}: disconnected occupied sides: {missing_bridges}"
    cells = {tuple(c) for c in fixture["cells"]}
    assert all(mask_at(cells, *r["cell"]) == r["mask"] for r in fixture["centers"])
    # Compare actual paired shared edges from the fixture. The outermost pixels
    # can differ because of authored chips; full joint discontinuities are errors.
    shared_edges, disconnected_edges, edge_alpha_mismatches = 0, [], 0
    for x, y in cells:
        here = np.asarray(tiles[mask_at(cells, x, y)])[:, :, 3] >= 128
        for dx, dy in ((1, 0), (0, 1)):
            if (x + dx, y + dy) not in cells:
                continue
            there = np.asarray(tiles[mask_at(cells, x + dx, y + dy)])[:, :, 3] >= 128
            left, right = (here[:, -1], there[:, 0]) if dx else (here[-1, :], there[0, :])
            overlap = left & right
            shared_edges += 1
            edge_alpha_mismatches += int(np.count_nonzero(left ^ right))
            if not overlap.any():
                disconnected_edges.append([x, y, dx, dy])
    assert not disconnected_edges, f"{region_id}: fixture has fully open shared edges: {disconnected_edges}"
    corner_stats = {}
    if region_id != "windchime_plains":
        corner_strip = sources[records[1]["file"]]
        for i, q in enumerate(QUADRANTS):
            data = np.asarray(crop(corner_strip, [i * 16, 0, 16, 16]))
            alpha = data[:, :, 3]
            inner = crop(tiles[255], q[1:3] + (16, 16))
            assert data.tobytes() != inner.tobytes(), f"{region_id} {q[0]} concave corner is a duplicate interior."
            corner_x = 0 if q[0] in ("NW", "SW") else 15
            corner_y = 0 if q[0] in ("NW", "NE") else 15
            transparent = int(np.count_nonzero(alpha == 0))
            assert alpha[corner_y, corner_x] == 0, f"{region_id} {q[0]}: concavity must open to its named corner."
            assert 1 <= transparent <= 96, f"{region_id} {q[0]}: excessive or missing corner air ({transparent}/256 pixels)."
            far_edges = np.concatenate((alpha[15-corner_y, :], alpha[:, 15-corner_x]))
            assert np.all(far_edges >= 128), f"{region_id} {q[0]}: concave source breaks interior-facing edges."
            corner_stats[q[0]] = {"transparentPixels": transparent, "opaquePixels": int(np.count_nonzero(alpha >= 128)),
                                  "opensToNamedCorner": True, "interiorFacingEdgesSolid": True}
    return {"region": region_id, "tileCount": len(tiles), "uniquePixelTiles": unique_count,
            "sourceCopiesVerified": source_copy_count, "fixtureCenters": 47,
            "sharedOccupiedEdges": shared_edges, "disconnectedSharedEdges": disconnected_edges,
            "edgeAlphaMismatchPixels": edge_alpha_mismatches,
            "minimumCentralBridgePixels": min(bridge_samples), "cornerAlpha": corner_stats,
            "note": "Authored chips can differ at paired edge pixels. No fully broken occupied joins. Visual review is separate.",
            "tilePixelSha256": {str(k): v for k, v in tile_hashes.items()}}


def overview(panels, filename, panel_size, column_count=4, title=""):
    pad, header = 16, 28
    pw, ph = panel_size
    rows = (len(panels) + column_count - 1) // column_count
    im = Image.new("RGB", (pad + column_count * (pw + pad), 50 + rows * (ph + header + pad)), (14, 18, 27))
    draw = ImageDraw.Draw(im)
    draw.text((pad, 13), title, fill=(220, 225, 235), font=get_font(19))
    for idx, (region_id, panel) in enumerate(panels):
        x = pad + (idx % column_count) * (pw + pad)
        y = 50 + (idx // column_count) * (ph + header + pad)
        draw.text((x, y + 3), f"{idx+1:02d}  {region_id}", fill=(191, 202, 219), font=get_font(13))
        if panel.mode == "RGBA":
            bg = Image.new("RGBA", panel.size, (23, 27, 38, 255))
            bg.alpha_composite(panel)
            panel = bg.convert("RGB")
        im.paste(panel.resize(panel_size, Image.Resampling.NEAREST), (x, y + header))
    im.save(filename)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--regions", nargs="+", choices=[r[0] for r in REGIONS], help="Explicit partial bake for focused work; normal delivery uses all16.")
    args = parser.parse_args()
    regions = [r for r in REGIONS if not args.regions or r[0] in args.regions]
    baseline = json.loads((BASE / "assets/pixel/manifest.json").read_text())
    terrain_dir, auto_dir, godot_dir = BASE / "assets/terrain47", BASE / "autotile", BASE / "godot/terrain47"
    for folder in (terrain_dir, auto_dir / "previews", auto_dir / "recipes", godot_dir / "textures"):
        folder.mkdir(parents=True, exist_ok=True)
    fixture, features = all_mask_fixture(), feature_fixture()
    write_json(auto_dir / "all47-fixture.json", fixture)
    write_json(auto_dir / "features-fixture.json", features)
    mapping = {str(k): list(v) for k, v in MASK_TO_ATLAS.items()}
    contract = {
        "version": "underworld-blob47-v2", "tileSize": 32, "worldUnitsPerPixel": 1, "columns": 8, "rows": 6,
        "maskCount": 47, "bitOrder": {n: b for n, b, *_ in NEIGHBORS},
        "normalization": "Clear each diagonal unless its two adjacent cardinal neighbors are both present.",
        "normalizeTable": [normalize(m) for m in range(256)], "masks": list(MASKS), "maskToAtlas": mapping,
        "godotPeeringBits": {n: {"enum": e, "property": p} for n, _, _, _, e, p in NEIGHBORS},
        "godotTerrainMode": "MATCH_CORNERS_AND_SIDES", "godotTerrainSet": 0, "godotTerrain": 0,
        "alphaPolicy": "Copy authored source RGBA without filtering, resampling or re-thresholding.",
        "surfaceAlignment": "For art-only map preview, translate the whole TileMap layer by [0,-surfaceY]. Keep greybox collision at origin; disable TileMap collision. Standalone resource physics covers all32px cells.",
        "collision": "Each tile has a full32x32 cell collision; decorative alpha and inner bevels do not reshape gameplay geometry.",
        "regions": {},
    }
    reports, atlas_panels, feature_panels = [], [], []
    for region_id, chinese_name in regions:
        atlas, tiles, recipes, records = bake_region(region_id, baseline)
        report = focused_validation(region_id, atlas, tiles, recipes, records, fixture)
        atlas_path = terrain_dir / f"{region_id}.png"
        atlas.save(atlas_path)
        shutil.copy2(atlas_path, godot_dir / "textures" / atlas_path.name)
        write_json(auto_dir / "recipes" / f"{region_id}.json", {"region": region_id, "sources": records, "recipes": recipes})
        render_map(tiles, fixture, show_masks=True).save(auto_dir / "previews" / f"{region_id}_all47.png")
        feature_im = render_map(tiles, features)
        feature_im.save(auto_dir / "previews" / f"{region_id}_features.png")
        atlas_panels.append((region_id, atlas))
        feature_panels.append((region_id, feature_im))
        terrain = baseline["terrains"][region_id]
        contract["regions"][region_id] = {
            "name": chinese_name, "atlas": str(atlas_path.relative_to(BASE)), "sha256": sha256(atlas_path),
            "tile": 32, "columns": 8, "rows": 6, "count": 47, "surfaceY": terrain["surfaceY"],
            "maskToAtlas": mapping, "sourceId": 0, "terrainSet": 0, "terrain": 0,
            "godotResource": f"res://terrain47/{region_id}.tres", "godotTexture": f"res://terrain47/textures/{region_id}.png",
            "originalAsset": terrain["asset"], "recipe": f"autotile/recipes/{region_id}.json",
        }
        reports.append(report)
    write_json(terrain_dir / "manifest.json", contract)
    write_json(godot_dir / "manifest.json", contract)
    write_json(godot_dir / "all47-fixture.json", fixture)
    write_json(godot_dir / "features-fixture.json", features)
    overview(atlas_panels, auto_dir / "previews/all-regions-atlas.png", (512, 384), title="UNDERWORLD / 47 NEIGHBOR TERRAIN / native 32px / 2x nearest")
    overview(feature_panels, auto_dir / "previews/all-regions-features.png", (592, 272), title="REAL TILE ASSEMBLY / holes, thin ledges, columns, T and cross junctions")
    write_json(auto_dir / "validation-report.json", {
        "status": "passed", "scope": "native pixel packing, source provenance and occupancy topology; separate Godot validation follows",
        "regionCount": len(regions), "tileCount": len(regions) * 47, "normalizedRawMasks": 256,
        "normalizationIsIdempotent": all(normalize(normalize(i)) == normalize(i) for i in range(256)),
        "normalizedMaskCount": len(MASKS), "regionReports": reports,
    })
    print(json.dumps({"regions": len(regions), "tiles": len(regions) * 47, "manifest": str(terrain_dir / "manifest.json"), "status": "passed"}))


if __name__ == "__main__":
    main()
