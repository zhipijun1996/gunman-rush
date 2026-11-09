#!/usr/bin/env python3
"""Inspect one region or a complete Underworld art pack without rendering it.

Only reads the requested pack and the skill's regional catalog. Uses Python stdlib.
File/schema checks do not establish aesthetic, gameplay, or Godot GPU acceptance.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import sys
from pathlib import Path


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def finite(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def integer(value):
    return finite(value) and int(value) == value


def blob47_mask(value):
    value = int(value) & 255
    for diagonal, sides in ((2, 5), (8, 20), (32, 80), (128, 65)):
        if value & sides != sides:
            value &= ~diagonal
    return value


def inspect(args):
    root = Path(args.pack).expanduser().resolve()
    catalog = read_json(Path(__file__).resolve().parent.parent / "references/region-catalog.json")
    aliases = catalog.get("aliases", {})
    canonical = lambda value: aliases.get(value, value)
    expected = {r["id"] for r in catalog["regions"]}
    recipes = {r["id"]: r for r in catalog["regions"]}
    data = read_json(root / "study.json")
    manifest = read_json(root / "assets/pixel/manifest.json")
    terrain47_path = root / "assets/terrain47/manifest.json"
    terrain47 = read_json(terrain47_path) if terrain47_path.is_file() else None
    errors, warnings, checked_files = [], [], {}
    regions = data.get("regions", [])
    available = {canonical(r["id"]): r for r in regions}
    if len(available) != len(regions):
        errors.append("Duplicate regional IDs after alias normalization")
    if args.complete and set(available) != expected:
        errors.append(f"Expected 16 canonical regions; missing={sorted(expected-set(available))}, extra={sorted(set(available)-expected)}")
    selected_id = canonical(args.region) if args.region else None
    if selected_id and selected_id not in available:
        raise ValueError(f"Region {selected_id!r} is absent. Available: {', '.join(available)}")
    selected = [available[selected_id]] if selected_id else regions
    if manifest.get("worldUnitsPerPixel") != 1:
        errors.append("This style contract expects worldUnitsPerPixel=1")
    if data.get("hero", {}).get("bodyHeight") != 44:
        warnings.append("Hero bodyHeight differs from the 44wu approved anchor; verify against the current project")
    expected_masks = sorted({blob47_mask(value) for value in range(256)})
    if terrain47:
        if terrain47.get("tileSize") != 32 or terrain47.get("maskCount") != 47:
            errors.append("terrain47: expected native32 and 47 masks")
        if terrain47.get("masks") != expected_masks:
            errors.append("terrain47: masks must be the47 normalized eight-neighbor configurations in ascending order")
        if terrain47.get("normalizeTable") != [blob47_mask(value) for value in range(256)]:
            errors.append("terrain47: normalization table differs from the diagonal-gating contract")
        if terrain47.get("bitOrder") != dict(zip(("N", "NE", "E", "SE", "S", "SW", "W", "NW"), (1, 2, 4, 8, 16, 32, 64, 128))):
            errors.append("terrain47: incompatible neighbor bit order")
        if args.complete and set(terrain47.get("regions", {})) != expected:
            errors.append("terrain47: complete pack requires47 mappings for all16 canonical regions")
    elif data.get("terrainGrid") or any(region.get("terrainGrid") for region in selected):
        errors.append("Grid-based pack is missing assets/terrain47/manifest.json")

    def asset(label, record, require_hash=False):
        if not isinstance(record, dict) or not record.get("file"):
            errors.append(f"{label}: missing manifest record or file")
            return {"id": label, "missing": True}
        filename = record["file"]
        path = (root / filename).resolve()
        if not path.is_relative_to(root):
            errors.append(f"{label}: asset path leaves the pack: {filename}")
            return {"id": label, "file": filename, "invalid": True}
        if filename not in checked_files:
            check = {"file": filename, "exists": path.is_file()}
            if not path.is_file():
                errors.append(f"{label}: missing {filename}")
            else:
                with path.open("rb") as handle:
                    header = handle.read(24)
                if header[:8] == b"\x89PNG\r\n\x1a\n" and header[12:16] == b"IHDR":
                    check["png_dimensions"] = list(struct.unpack(">II", header[16:24]))
                elif path.suffix.lower() == ".png":
                    errors.append(f"{label}: invalid PNG header")
            checked_files[filename] = check
        check = checked_files[filename]
        if (args.hashes or require_hash) and record.get("sha256") and check.get("exists") and "sha256" not in check:
            check["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        if check.get("png_dimensions") and check["png_dimensions"] != [record.get("w"), record.get("h")]:
            errors.append(f"{label}: native dimensions do not match the PNG")
        if require_hash and not record.get("sha256"):
            errors.append(f"{label}: missing required SHA-256")
        if (args.hashes or require_hash) and record.get("sha256") and check.get("sha256") != record["sha256"]:
            errors.append(f"{label}: SHA-256 differs from the manifest")
        for key in ("pivotX", "pivotY"):
            if key in record and not integer(record[key]):
                errors.append(f"{label}: {key} is not an integer display anchor")
        return {"id": label, **{k: record[k] for k in ("file", "w", "h", "pivotX", "pivotY", "sourceFile", "sourceRect", "sha256") if k in record}}

    sprite_map = manifest.get("sprites", {})
    background_map = manifest.get("backgrounds", {})
    results = []
    for region in selected:
        rid = canonical(region["id"])
        terrain = manifest.get("terrains", {}).get(region["id"]) or manifest.get("terrains", {}).get(rid)
        if terrain is None:
            terrain = next((v for k, v in manifest.get("terrains", {}).items() if canonical(k) == rid), None)
        if terrain is None:
            errors.append(f"{rid}: no terrain mapping")
            terrain = {}
        if terrain.get("tile") != 32:
            errors.append(f"{rid}: expected native32 terrain tile")
        if not integer(terrain.get("surfaceY")):
            errors.append(f"{rid}: surfaceY must be an integer")
        terrain47_record = terrain47.get("regions", {}).get(rid) if terrain47 else None
        terrain47_asset = None
        if terrain47:
            if not isinstance(terrain47_record, dict):
                errors.append(f"{rid}: missing47-neighbor terrain mapping")
            else:
                spec = terrain47_record
                if spec.get("tile") != 32 or spec.get("count") != 47 or spec.get("columns") != 8 or spec.get("rows") != 6:
                    errors.append(f"{rid}: expected47 tiles in an8x6 native32 atlas")
                if not integer(spec.get("surfaceY")) or not 0 <= spec.get("surfaceY", -1) < 32:
                    errors.append(f"{rid}: terrain47 surfaceY must be an integer inset within32px")
                mapping = spec.get("maskToAtlas", {})
                if set(mapping) != {str(mask) for mask in expected_masks}:
                    errors.append(f"{rid}: terrain47 mapping does not contain exactly47 normalized masks")
                coordinates = []
                for mask, coord in mapping.items():
                    if not isinstance(coord, list) or len(coord) != 2 or not all(integer(v) for v in coord) or not (0 <= coord[0] < 8 and 0 <= coord[1] < 6):
                        errors.append(f"{rid}: invalid47 atlas coordinate for mask {mask}")
                    else:
                        coordinates.append(tuple(coord))
                if len(set(coordinates)) != 47:
                    errors.append(f"{rid}: 47 masks must reference47 distinct atlas positions")
                terrain47_asset = asset(f"{rid}/terrain47", {"file": spec.get("atlas"), "w": 256, "h": 192, "sha256": spec.get("sha256")}, require_hash=True)
        grid = region.get("terrainGrid", data.get("terrainGrid"))
        surface_ys = None
        if grid is not None:
            origin, cells = grid.get("origin", [0, 0]), grid.get("cells", [])
            if grid.get("tile") != 32 or len(origin) != 2 or not all(integer(v) for v in origin) or not all(isinstance(c, list) and len(c) == 2 and all(integer(v) for v in c) for c in cells):
                errors.append(f"{rid}: terrainGrid requires32px tile, integer origin and integer cell pairs")
            else:
                occupied = {tuple(c) for c in cells}
                surface_ys = {origin[1] + y * 32 for x, y in occupied if (x, y - 1) not in occupied}
        used = {data.get("hero", {}).get("asset"), terrain.get("asset")}
        instances = region.get("instances", [])
        layers = region.get("layers", [])
        for instance in instances + layers:
            used.add(instance.get("asset"))
            for axis in ("x", "y"):
                if not integer(instance.get(axis)):
                    errors.append(f"{rid}/{instance.get('id')}: {axis} must be an integer display placement")
        kinds = {layer.get("kind") for layer in layers}
        if args.complete and not {"mid", "near"}.issubset(kinds):
            errors.append(f"{rid}: complete expansion requires independent mid and near assets")
        elif not layers:
            warnings.append(f"{rid}: no independent mid/near layer records; a background plate alone is one layer")
        for layer in layers:
            if not finite(layer.get("parallax")) or layer["parallax"] < 0:
                errors.append(f"{rid}/{layer.get('id')}: invalid parallax")
            if not finite(layer.get("opacity", 1)) or not 0 <= layer.get("opacity", 1) <= 1:
                errors.append(f"{rid}/{layer.get('id')}: invalid opacity")
            mask = layer.get("mask")
            if mask is not None:
                if not isinstance(mask, dict):
                    errors.append(f"{rid}/{layer.get('id')}: mask must be an object")
                    continue
                if "surfaceY" in mask:
                    if not integer(mask["surfaceY"]):
                        errors.append(f"{rid}/{layer.get('id')}: mask.surfaceY must be an integer world-platform height")
                    elif surface_ys is not None and mask["surfaceY"] not in surface_ys:
                        errors.append(f"{rid}/{layer.get('id')}: mask.surfaceY does not match an exposed terrainGrid top surface")
                for key in ("above", "below", "edgeFade"):
                    if key in mask and (not finite(mask[key]) or mask[key] < 0 or key == "edgeFade" and mask[key] == 0):
                        errors.append(f"{rid}/{layer.get('id')}: invalid mask.{key}")
                reveal = mask.get("heroReveal")
                if reveal is not None:
                    if not isinstance(reveal, dict) or any(not finite(reveal.get(key)) or reveal[key] <= 0 for key in ("radiusX", "radiusY")) or not finite(reveal.get("minAlpha")) or not 0 <= reveal["minAlpha"] <= 1:
                        errors.append(f"{rid}/{layer.get('id')}: invalid heroReveal ellipse/alpha")
        sprites = []
        for name in sorted(n for n in used if n):
            record = sprite_map.get(name)
            sprites.append(asset(name, record))
            if record and record.get("candidateOnly"):
                errors.append(f"{rid}: candidate-only asset {name!r} is used by the scene")
        terrain_record = sprite_map.get(terrain.get("asset"), {})
        for key, coords in terrain.get("coords", {}).items():
            if len(coords) != 2 or not all(integer(v) and v >= 0 for v in coords):
                errors.append(f"{rid}: invalid terrain coordinates for {key}")
            elif (coords[0]+1)*32 > terrain_record.get("w", 0) or (coords[1]+1)*32 > terrain_record.get("h", 0):
                errors.append(f"{rid}: terrain cell {key} exceeds its source atlas")
        background_id = region.get("background")
        background = asset(f"{rid}/background:{background_id}", background_map.get(background_id))
        background_region = background_map.get(background_id, {}).get("regionId")
        if background_region and canonical(background_region) != rid:
            errors.append(f"{rid}: selected background {background_id!r} belongs to {background_region!r}")
        lights = region.get("lighting", {}).get("lights", [])
        for light in lights:
            if not finite(light.get("energy")) or light["energy"] < 0:
                errors.append(f"{rid}/{light.get('id')}: invalid light energy")
            if not finite(light.get("radius")) or light["radius"] <= 0:
                errors.append(f"{rid}/{light.get('id')}: invalid light radius")
        recipe = recipes.get(rid, {})
        results.append({
            "id": rid, "source_id": region["id"], "name": region.get("name"),
            "material": region.get("materialLabel") or recipe.get("art_recipe", {}).get("material"),
            "art_status": recipe.get("art_recipe", {}).get("status"),
            "terrain": terrain, "terrain47": terrain47_record, "terrain47_asset": terrain47_asset,
            "background_key": background_id, "background": background, "layers": layers,
            "attached_instances": [p for p in instances if p.get("group") == "attached"],
            "lighting": region.get("lighting", {}), "particles": region.get("particles", {}),
            "assets": sprites,
        })
    return {
        "pack": str(root), "data_schema": data.get("schema"), "manifest_schema": manifest.get("schema"),
        "canonical_region_count": len(available), "selected_region_count": len(results),
        "background_record_count": len(background_map),
        "terrain47_region_count": len(terrain47.get("regions", {})) if terrain47 else 0,
        "world_units_per_pixel": manifest.get("worldUnitsPerPixel"), "viewport": data.get("viewport"),
        "hero": data.get("hero"), "regions": results, "checked_file_count": len(checked_files),
        "errors": list(dict.fromkeys(errors)), "warnings": list(dict.fromkeys(warnings)),
        "scope": "Read-only file/configuration checks; no aesthetic, gameplay, seamless-repeat, or Godot GPU acceptance is implied.",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pack", help="Extracted directory containing study.json")
    parser.add_argument("--region", help="Canonical ID, or legacy plains/forest alias")
    parser.add_argument("--complete", action="store_true", help="Require all 16 canonical regions and independent mid/near assets")
    parser.add_argument("--hashes", action="store_true", help="Verify manifest SHA-256 for used assets")
    parser.add_argument("--json", action="store_true", help="Print full selected configuration as JSON")
    args = parser.parse_args()
    if args.complete and args.region:
        parser.error("--complete checks the entire pack; omit --region")
    try:
        report = inspect(args)
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(f"Pack: {report['pack']}")
        print(f"Regions: {report['canonical_region_count']} available; {report['selected_region_count']} selected; {report['checked_file_count']} used files checked")
        print(f"Grid: {report['world_units_per_pixel']} wu/pixel; hero body: {report['hero'].get('bodyHeight')}wu; viewport: {report['viewport']}")
        for region in report["regions"]:
            print(f"{region['id']} · {region['name']} · {region['material']}")
            print(f"  Terrain: {region['terrain'].get('asset')}; layers: {len(region['layers'])}; attached: {len(region['attached_instances'])}; lights: {len(region['lighting'].get('lights', []))}")
            if region["terrain47"]:
                print(f"  47-neighbor atlas: {region['terrain47'].get('atlas')}; background key: {region['background_key']}")
        for label in ("errors", "warnings"):
            for item in report[label]:
                print(f"{label.upper()}: {item}")
        print(report["scope"])
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
