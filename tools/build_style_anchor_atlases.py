#!/usr/bin/env python3
"""Rebuild style anchor atlases from checked-in pixels and immutable crop recipes.

Requires Pillow. Run from any cwd. No network, image generation, painting, or
external workspace files are used. ``--check`` performs no filesystem writes.
The source recipes in anchors.json and scenery_source_map.json are never edited.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[1]
ASSET_REL = Path("assets/style_exploration")
SOURCE_FILES = {
    "retro": "Environment.png",
    "basic": "sTileset.png",
    "scribble": "spritesheet_default.png",
    "underworld": "TileSet.png",
    "cavern": "tiles.png",
}
PUBLISHER_URLS = {
    "retro": "https://v3x3d.itch.io/retro-lines",
    "basic": "https://ariel-pinana.itch.io/platformer-tileset-character-and-monsters",
    "scribble": "https://kenney-assets.itch.io/scribble-platformer",
    "underworld": "https://asouris.itch.io/underworld-tileset",
    "cavern": "https://opengameart.org/content/cavern-tile-set",
}
EXPECTED_BITS = {"N": 1, "NE": 2, "E": 4, "SE": 8, "S": 16, "SW": 32, "W": 64, "NW": 128}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_mask(mask: int) -> int:
    for diagonal, first, second in (("NE", "N", "E"), ("SE", "S", "E"), ("SW", "S", "W"), ("NW", "N", "W")):
        if not (mask & EXPECTED_BITS[first] and mask & EXPECTED_BITS[second]):
            mask &= ~EXPECTED_BITS[diagonal]
    return mask


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def rebuild(root: Path, check: bool) -> dict:
    assets = root / ASSET_REL
    recipe_path = assets / "anchors.json"
    recipes_bytes = recipe_path.read_bytes()
    recipes = json.loads(recipes_bytes)
    masks = sorted({canonical_mask(mask) for mask in range(256)})
    require(recipes["bits"] == EXPECTED_BITS, "Recipe bit order differs from project Blob47Rules")
    require(recipes["masks"] == masks and len(masks) == 47, "Recipe does not enumerate the canonical 47 masks")
    require(recipes["atlas_columns"] == 8 and recipes["atlas_rows"] == 6, "Expected an 8 by 6 atlas")
    manifest = {
        "schema": "windchime-anchor-local-build-v1",
        "builder": "tools/build_style_anchor_atlases.py",
        "recipes": str(ASSET_REL / "anchors.json"),
        "recipes_sha256": sha256(recipes_bytes),
        "operations": ["source rectangle crop", "Basic horizontal flip", "lossless RGBA patch paste"],
        "scope": "Source provenance and exact atlas reconstruction; not GPU, aesthetic, or AI generation approval",
        "styles": {},
    }
    pending = []
    for style, filename in SOURCE_FILES.items():
        spec = recipes["styles"][style]
        source_rel = ASSET_REL / style / "source" / filename
        source_data = (root / source_rel).read_bytes()
        require(sha256(source_data) == spec["source_sha256"], f"{style}: source SHA256 mismatch")
        source = Image.open(io.BytesIO(source_data)).convert("RGBA")
        tile_px = spec["px"]
        atlas = Image.new("RGBA", (tile_px * 8, tile_px * 6))
        tile_hashes = []
        for index, mask in enumerate(masks):
            tile = Image.new("RGBA", (tile_px, tile_px))
            covered = Image.new("1", (tile_px, tile_px))
            for patch_recipe in spec["recipes"][str(mask)]:
                left, top, right, bottom = patch_recipe["source"]
                require(0 <= left < right <= source.width and 0 <= top < bottom <= source.height,
                        f"{style}/{mask}: source crop exceeds image bounds")
                x1, y1, x2, y2 = patch_recipe["destination"]
                require(0 <= x1 < x2 <= tile_px and 0 <= y1 < y2 <= tile_px,
                        f"{style}/{mask}: destination exceeds tile bounds")
                require((right - left, bottom - top) == (x2 - x1, y2 - y1),
                        f"{style}/{mask}: crop would require scaling")
                require(not covered.crop((x1, y1, x2, y2)).getbbox(), f"{style}/{mask}: overlapping crop recipes")
                patch = source.crop((left, top, right, bottom))
                if patch_recipe.get("horizontal_flip", False):
                    patch = patch.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                tile.paste(patch, (x1, y1))
                covered.paste(1, (x1, y1, x2, y2))
            require(covered.histogram()[0] == 0, f"{style}/{mask}: crop recipe leaves pixels undefined")
            tile_hashes.append(sha256(tile.tobytes()))
            coordinate = [index % 8, index // 8]
            require(spec["mask_to_atlas"][str(mask)] == coordinate, f"{style}/{mask}: atlas coordinate mismatch")
            atlas.paste(tile, (coordinate[0] * tile_px, coordinate[1] * tile_px))
        encoded = io.BytesIO()
        atlas.save(encoded, format="PNG")
        output_data = encoded.getvalue()
        require(sha256(output_data) == spec["atlas_sha256"], f"{style}: rebuilt PNG SHA256 differs from frozen atlas")
        output_rel = ASSET_REL / style / "terrain.png"
        output_path = root / output_rel
        if check:
            require(output_path.exists() and sha256(output_path.read_bytes()) == spec["atlas_sha256"],
                    f"{style}: checked-in terrain.png differs from rebuilt output")
        license_dir = root / ASSET_REL / style / "source" / "licenses"
        evidence = [{"path": str(path.relative_to(root)), "sha256": sha256(path.read_bytes()), "bytes": path.stat().st_size}
                    for path in sorted(license_dir.iterdir()) if path.is_file()]
        require(any(item["path"].endswith("publisher_page.txt") for item in evidence), f"{style}: publisher license evidence missing")
        manifest["styles"][style] = {
            "source": str(source_rel),
            "original_recipe_source": spec["source"],
            "source_sha256": spec["source_sha256"],
            "output": str(output_rel),
            "output_sha256": spec["atlas_sha256"],
            "tile_px": tile_px,
            "world_tile_size": recipes["world_tile_size"],
            "mask_count": len(masks),
            "distinct_pixel_tiles": len(set(tile_hashes)),
            "license": spec["license"],
            "publisher_url": PUBLISHER_URLS[style],
            "publisher_page_retrieved": "2026-10-19",
            "license_evidence": evidence,
            "adaptation": spec["adaptation"],
            "exact_rebuild": True,
        }
        pending.append((output_path, output_data))
    # All five outputs must validate before any write takes place.
    if not check:
        for output_path, output_data in pending:
            output_path.write_bytes(output_data)
        (assets / "atlas_build_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="reconstruct in memory and compare all frozen hashes; do not write")
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT, help="repository root (defaults to this script's parent repository)")
    args = parser.parse_args()
    manifest = rebuild(args.repo_root.resolve(), args.check)
    for style, spec in manifest["styles"].items():
        print(f"{style}: exact source/PNG hashes match; {spec['mask_count']} masks, {spec['distinct_pixel_tiles']} pixel variants; {spec['license']}")
    print("CHECK PASSED (no writes)" if args.check else "BUILT: five terrain.png files and atlas_build_manifest.json")


if __name__ == "__main__":
    main()
