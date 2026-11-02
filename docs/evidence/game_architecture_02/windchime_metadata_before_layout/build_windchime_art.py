#!/usr/bin/env python3
"""Author the original Windchime Plains SVG family; no legacy art inputs.

The only shared input is Blob47Rules' technical atlas contract. The user's
2026-10-19 reference supplies mood, hierarchy, and materials, not traced pixels.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/windchime_plains"
RULES = ROOT / "scripts/art_foundation/blob47_rules.gd"
PALETTE = {"stone": "#676b55", "recess": "#485543", "face": "#85866a",
           "masonry": "#74795e", "edge": "#a4ab80", "grass": "#9fa66c",
           "cream": "#efe0ab", "gold": "#a98949", "dark_gold": "#74623e",
           "ink": "#37483e", "quiet_chip": "#6a6e58", "quiet_crack": "#636751"}
PROP_NAMES = ["flower_cluster", "grass", "urn", "lantern", "windchime",
              "banner", "flower_tall", "brass_ring"]


def settings() -> dict[str, int]:
    text = RULES.read_text()
    result = {}
    for name in ("CELL", "SOURCE_SIZE", "GUTTER", "COLUMNS", "VARIANTS"):
        match = re.search(rf"const {name} := (\d+)", text)
        if not match:
            raise RuntimeError(f"Missing technical atlas constant {name}")
        result[name] = int(match[1])
    if result["SOURCE_SIZE"] != 64:
        raise RuntimeError("Authored source geometry requires a reviewed 64px contract")
    return result


def masks() -> list[int]:
    result = []
    for value in range(256):
        canonical = value
        for diagonal, a, b in ((2, 1, 4), (8, 4, 16), (32, 16, 64), (128, 64, 1)):
            if not value & a or not value & b:
                canonical &= ~diagonal
        if canonical == value:
            result.append(value)
    assert len(result) == 47
    return result


def svg(width: int, height: int, body: str) -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}">{body}</svg>\n')


def tile(mask: int, variant: int) -> str:
    p = PALETTE
    elements = [f'<path fill="{p["stone"]}" d="M-2-2H66V66H-2Z"/>']
    # Quiet broad, low-contrast chips. Never draw a regular per-tile brick grid.
    # Most of each tile is intentionally unmarked. Edge signatures never vary.
    if variant == 1:
        elements += [f'<path fill="{p["quiet_chip"]}" d="M47 39h9v11h-5l-4-4Z"/>']
    elif variant == 2:
        elements += [f'<path fill="{p["quiet_crack"]}" d="m8 43 5 1 1 7 4 3-6-1-1-7-3-1Z"/>']
    if not mask & 16:
        elements += [f'<path fill="{p["recess"]}" d="M-2 58H66V66H-2Z"/>']
    if not mask & 64:
        elements += [f'<path fill="{p["edge"]}" d="M-2-2H3V58L0 66H-2Z"/>']
    if not mask & 4:
        elements += [f'<path fill="{p["recess"]}" d="M60-2H66V66H60Z"/>']
    # The cream lip coincides with the solid's exact collision y; no floating cap.
    if not mask & 1:
        elements += [f'<path fill="{p["grass"]}" d="M-2-2H66V9H-2Z"/>',
                     f'<path fill="{p["cream"]}" d="M-2-2H66V4H-2Z"/>',
                     f'<path fill="{p["edge"]}" d="M-2 9H66V13H-2Z"/>']
    # Concave junctions have small inward corner shadows; the tile stays opaque.
    if mask & 1 and mask & 64 and not mask & 128:
        elements += [f'<path fill="{p["edge"]}" d="M-2-2H9V2H3V11H-2Z"/>']
    if mask & 1 and mask & 4 and not mask & 2:
        elements += [f'<path fill="{p["recess"]}" d="M55-2H66V11H61V3H55Z"/>']
    if mask & 16 and mask & 64 and not mask & 32:
        elements += [f'<path fill="{p["recess"]}" d="M-2 53H3V61H10V66H-2Z"/>']
    if mask & 16 and mask & 4 and not mask & 8:
        elements += [f'<path fill="{p["recess"]}" d="M60 53H66V66H54V61H60Z"/>']
    return "".join(elements)


def atlas(s: dict[str, int]) -> str:
    pitch = s["SOURCE_SIZE"] + s["GUTTER"] * 2
    rows = (47 + s["COLUMNS"] - 1) // s["COLUMNS"]
    body = []
    for variant in range(s["VARIANTS"]):
        for index, mask in enumerate(masks()):
            x = index % s["COLUMNS"] * pitch + s["GUTTER"]
            y = (index // s["COLUMNS"] + rows * variant) * pitch + s["GUTTER"]
            ident = f"tile_{mask}_{variant}"
            body.append(f'<defs><clipPath id="{ident}"><path d="M-2-2H66V66H-2Z"/></clipPath></defs>')
            body.append(f'<g transform="translate({x} {y})" clip-path="url(#{ident})">{tile(mask, variant)}</g>')
    return svg(s["COLUMNS"] * pitch, rows * s["VARIANTS"] * pitch, "".join(body))


def props() -> str:
    p = PALETTE
    shapes = []
    # Source slots are generous; all roots share y120. Nothing reaches a neighbor.
    shapes.append(f'<g stroke="{p["grass"]}" stroke-width="2" fill="none"><path d="M22 120q-2-17-8-29m20 29V80m9 40q3-14 10-20"/></g>'
                  f'<g fill="{p["cream"]}"><circle cx="13" cy="88" r="6"/><circle cx="34" cy="78" r="8"/><circle cx="54" cy="98" r="5"/></g>'
                  f'<g fill="{p["gold"]}"><circle cx="13" cy="88" r="2"/><circle cx="34" cy="78" r="3"/><circle cx="54" cy="98" r="2"/></g>'
                  f'<path fill="{p["grass"]}" d="M30 120q-16-14-21-10 5 9 21 10m4 0q7-19 15-17-2 12-15 17Z"/>')
    shapes.append(f'<path fill="{p["grass"]}" d="M8 120q1-20-7-28 14 5 16 25-2-30 5-36 1 18 4 36 4-23 13-30-5 17-6 31 10-18 23-17-13 8-17 19Z"/>')
    shapes.append(f'<path fill="{p["ink"]}" d="M20 73h25v8l-4 5q15 24 4 34H18Q7 109 23 86l-3-5Z"/>'
                  f'<path fill="{p["face"]}" d="M19 74h26v6H19Zm2 20h22l4 6H17Z"/>'
                  f'<path fill="{p["gold"]}" d="M20 91h23v3H20Z"/><path fill="{p["recess"]}" d="M28 101h9v12h-9Z"/>')
    shapes.append(f'<path fill="none" stroke="{p["dark_gold"]}" stroke-width="3" d="M32 120V48q0-10 9-10t9 9v10"/>'
                  f'<path fill="{p["dark_gold"]}" d="M41 57h18l-3 8v24l3 6H40l4-6V65Z"/>'
                  f'<path fill="{p["cream"]}" d="M45 65h10v23H45Z"/><path fill="{p["gold"]}" d="M47 68h3v17h-3Z"/>')
    # The stand roots on a solid; the delicate hanging chimes are atmosphere only.
    shapes.append(f'<path fill="none" stroke="{p["ink"]}" stroke-width="4" d="M10 120V13h47M10 37l20-24"/>'
                  f'<path fill="none" stroke="{p["gold"]}" stroke-width="1.7" d="M34 14v25m15-25v32"/>'
                  f'<path fill="{p["gold"]}" d="M30 39h5v42h-5Zm8 0h4v33h-4Zm8 7h4v48h-4Zm8 0h4v39h-4Z"/>'
                  f'<path fill="none" stroke="{p["cream"]}" stroke-width="1.2" d="M32 41v35m16-27v40"/>'
                  f'<path fill="none" stroke="{p["gold"]}" stroke-width="2" d="M40 73v18m-4 5 4-5 4 5-4 6Z"/>')
    shapes.append(f'<path fill="none" stroke="{p["ink"]}" stroke-width="4" d="M12 120V18h43"/>'
                  f'<path fill="{p["cream"]}" d="M25 21h29v77L25 85Z"/>'
                  f'<path fill="{p["gold"]}" d="m25 68 29 13v7L25 75Z"/>'
                  f'<g fill="none" stroke="{p["gold"]}" stroke-width="2"><circle cx="40" cy="47" r="8"/><path d="M40 34v34"/></g>'
                  f'<path stroke="{p["dark_gold"]}" stroke-width="3" d="M29 18v9m20-9v9"/>')
    shapes.append(f'<path fill="none" stroke="{p["grass"]}" stroke-width="2" d="M33 120V57m0 42L20 88m13 24 13-13"/>'
                  f'<path fill="{p["grass"]}" d="M32 104Q14 105 14 92q11 0 18 12m2 11q1-18 17-18-2 12-17 18Z"/>'
                  f'<g fill="{p["cream"]}"><circle cx="33" cy="53" r="11"/><circle cx="20" cy="85" r="5"/></g>'
                  f'<g fill="{p["gold"]}"><circle cx="33" cy="53" r="4"/><circle cx="20" cy="85" r="2"/></g>')
    shapes.append(f'<path fill="{p["dark_gold"]}" d="M16 120v-5h32v5Z"/>'
                  f'<path fill="none" stroke="{p["gold"]}" stroke-width="5" d="M32 116V88m-3-35h6v10m-23 18h10m21 0h10"/>'
                  f'<circle fill="none" stroke="{p["gold"]}" stroke-width="6" cx="32" cy="82" r="18"/>'
                  f'<path fill="none" stroke="{p["cream"]}" stroke-width="1.5" d="M20 72q9-12 23 0"/>')
    return svg(64 * len(shapes), 128, "".join(f'<g id="{PROP_NAMES[i]}" transform="translate({i * 64} 0)">{shape}</g>' for i, shape in enumerate(shapes)))


def outputs() -> dict[str, str]:
    s = settings()
    result = {"limestone_blob47.svg": atlas(s), "props.svg": props()}
    metadata = {
        "family_id": "windchime-plains-warm-limestone-v2", "task_id": "WINDCHIME-STYLE-01",
        "method": "Original SVG path authoring in tools/build_windchime_art.py; no legacy art read or transformed",
        "author": "Codex", "license": "project-original-authored", "generative_image_model": None,
        "reference": {"source": "User supplied 1000057721.jpg on 2026-10-19", "license": "unknown",
                      "use": "Mood, limited palette and material hierarchy; no tracing or embedded reference pixels",
                      "sha256": "87afc39797133337b1cf23b775f6f8fae81a7a42da021420ece2f2d048e4e9e8"},
        "palette": PALETTE, "lighting": "wheat-cream top lip; sage upper-left edge; warm olive recesses",
        "regional_identity": {"region": "windchime_plains", "palette_status": "candidate",
                              "materials": ["warm limestone", "sage grass", "wheat", "aged brass", "dark green wooden stands"],
                              "scope": "Windchime Plains regional palette; not a shared palette for all 16 regions",
                              "source_texture": "Quiet tile cores; world-coordinate cross-cell weathering supplied by the terrain consumer"},
        "atlas": {"path": "limestone_blob47.svg", "source_size": s["SOURCE_SIZE"], "world_cell": s["CELL"],
                  "gutter": s["GUTTER"], "columns": s["COLUMNS"], "variants": s["VARIANTS"],
                  "masks": masks(), "bit_order": ["N", "NE", "E", "SE", "S", "SW", "W", "NW"],
                  "semantics": "solid-only; occupancy controls collision; alpha opaque inside every occupied cell",
                  "variant_scope": "small quiet internal patches only; identical boundary signatures"},
        "props": {"path": "props.svg", "slot_size": [64, 128], "root": [32, 120], "scale": 0.43,
                  "bounds_xywh_with_one_pixel_guard": [[6, 69, 54, 53], [0, 80, 57, 41], [12, 72, 39, 49],
                                                      [29, 35, 31, 86], [7, 10, 52, 111], [9, 15, 47, 106],
                                                      [13, 41, 39, 80], [10, 49, 44, 72]],
                  "names": PROP_NAMES, "semantics": "decoration-only; zero collision; lantern is local decorative glow"},
        "files": {name: hashlib.sha256(text.encode()).hexdigest() for name, text in result.items()},
        "acceptance": {"technical": "requires actual import/tests", "visual": "requires game-scale composite review",
                       "user": "unverified", "device": "unverified"},
    }
    result["manifest.json"] = json.dumps(metadata, ensure_ascii=False, indent=2) + "\n"
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail on absent or stale generated SVG/manifest")
    args = parser.parse_args()
    failures = []
    for name, content in outputs().items():
        path = DEST / name
        if args.check:
            if not path.is_file() or path.read_text() != content:
                failures.append(str(path.relative_to(ROOT)))
        else:
            DEST.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
    if failures:
        print("FAIL stale Windchime outputs: " + ", ".join(failures))
        return 1
    print(f"PASS Windchime art {'checked' if args.check else 'built'}: 47 masks × 3 variants; 8 original props")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
