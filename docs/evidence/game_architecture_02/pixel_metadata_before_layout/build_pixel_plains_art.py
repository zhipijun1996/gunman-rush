#!/usr/bin/env python3
"""Original pixel-cluster Windchime Plains material study; no art inputs.

The only inherited input is Blob47Rules' topology and atlas-size contract.
All art is authored below on a 4-source-pixel grid. This is not an image edit,
an extracted game asset, or a recolour of a previous generator.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/pixel_plains"
RULES = ROOT / "scripts/art_foundation/blob47_rules.gd"
PALETTE = {
    "ink": "#111e2b", "deep": "#203b46", "stone": "#365a59",
    "light": "#6e9180", "lichen": "#b0b97b", "cream": "#ead39a",
    "brass": "#a66d45", "rose": "#b47c64",
}


def configuration():
    source = RULES.read_text()
    values = {}
    for key in ("CELL", "SOURCE_SIZE", "GUTTER", "COLUMNS", "VARIANTS"):
        match = re.search(rf"const {key} := (\d+)", source)
        assert match, key
        values[key] = int(match[1])
    assert values == dict(CELL=32, SOURCE_SIZE=64, GUTTER=2, COLUMNS=8, VARIANTS=3)
    return values


def canonical(raw):
    for diagonal, a, b in ((2, 1, 4), (8, 4, 16), (32, 16, 64), (128, 64, 1)):
        if not raw & a or not raw & b:
            raw &= ~diagonal
    return raw


class Pixels:
    def __init__(self, width, height, fill=None):
        self.width, self.height = width, height
        self.rows = [[fill] * width for _ in range(height)]

    def rect(self, x, y, width, height, color):
        assert color in PALETTE
        for py in range(max(0, y), min(self.height, y + height)):
            for px in range(max(0, x), min(self.width, x + width)):
                self.rows[py][px] = color

    def line(self, points, color, thickness=1):
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            count = max(abs(x1-x0), abs(y1-y0))
            for i in range(count + 1):
                t = i / count if count else 0
                self.rect(round(x0+(x1-x0)*t), round(y0+(y1-y0)*t), thickness, thickness, color)

    def svg(self, offset_x=0, offset_y=0):
        result = []
        for y, row in enumerate(self.rows):
            x = 0
            while x < len(row):
                color = row[x]
                end = x+1
                while end < len(row) and row[end] == color:
                    end += 1
                if color:
                    result.append(f'<rect x="{offset_x+x*4}" y="{offset_y+y*4}" width="{(end-x)*4}" height="4" fill="{PALETTE[color]}"/>')
                x = end
        return "\n".join(result)

    def bounds(self):
        cells = [(x,y) for y,row in enumerate(self.rows) for x,c in enumerate(row) if c]
        return [min(x for x,y in cells)*4, min(y for x,y in cells)*4,
                (max(x for x,y in cells)+1)*4, (max(y for x,y in cells)+1)*4]


def stone(mask, variant):
    """Full collision-aligned opaque square; 3-pixel boundary lock for variants.

    Organic interest is in offset stone veins/lichen clusters, never a centred
    stamp on each cell. Only exposed tops receive sparse bright growth.
    """
    p = Pixels(16, 16, "deep")
    # Three quiet interior compositions. Nothing touches the locked boundaries.
    if variant == 0:
        # Predominantly undisturbed body; the silence is intentional.
        pass
    elif variant == 1:
        # An off-centre narrow fracture, with a lit lip on only one side.
        p.line([(3,4),(5,4),(6,5),(6,7),(8,9)],"ink")
        p.rect(3,3,2,1,"stone")
        p.rect(5,5,1,2,"stone")
        p.rect(7,8,1,1,"stone")
    else:
        # A broken mineral seam begins near a boundary, with a quiet lower half.
        p.rect(10,3,3,1,"stone")
        p.rect(9,4,3,1,"stone")
        p.rect(8,5,2,1,"stone")
        p.rect(8,6,1,1,"stone")
        p.rect(7,8,1,1,"stone")
    # Exposed boundaries: directional material structure, not a bright outline.
    if not mask & 1:
        p.rect(0,0,16,1,"light")
        p.rect(0,1,16,1,"stone")
        for x, width in ((0,2),(6,3),(13,3)):
            p.rect(x,0,width,1,"lichen")
        p.rect(3,1,3,1,"light")
        p.rect(9,1,2,2,"light")
        p.rect(10,3,1,1,"stone")
        p.rect(14,2,2,1,"stone")
    if not mask & 64:
        p.rect(0,0,1,16,"stone")
        p.rect(1,3,1,5,"stone")
        p.rect(1,10,1,3,"stone")
        p.rect(0,7,1,2,"light")
    if not mask & 4:
        p.rect(15,0,1,16,"ink")
        p.rect(14,4,1,3,"ink")
        p.rect(14,11,1,3,"ink")
    if not mask & 16:
        p.rect(0,15,16,1,"ink")
        p.rect(3,14,6,1,"ink")
        p.rect(11,14,3,1,"ink")
    # The four diagonal-only absences get an inset, stepped material corner.
    # No translucent chips: even thin cells agree with full-cell collision.
    for diagonal, a, b, corner in ((2,1,4,"ne"),(8,4,16,"se"),(32,16,64,"sw"),(128,64,1,"nw")):
        if mask & a and mask & b and not mask & diagonal:
            if corner == "ne":
                p.rect(14,0,2,1,"stone"); p.rect(15,1,1,2,"stone")
                p.rect(14,1,1,1,"light")
            elif corner == "se":
                p.rect(14,15,2,1,"ink"); p.rect(15,14,1,1,"ink")
            elif corner == "sw":
                p.rect(0,15,2,1,"ink"); p.rect(0,14,1,1,"ink")
            else:
                p.rect(0,0,2,1,"stone"); p.rect(0,1,1,2,"stone")
                p.rect(1,1,1,1,"light")
    return p


def props():
    result = []
    # Wind-combed grain: stems split at differing heights, heads lean right.
    p = Pixels(16,32)
    p.line([(5,31),(4,26),(5,20),(7,14),(10,10)],"light")
    p.line([(7,31),(8,25),(11,20),(13,18)],"stone")
    p.line([(3,31),(2,26),(2,22)],"light")
    p.rect(7,13,2,3,"lichen"); p.rect(9,10,2,3,"lichen")
    p.rect(10,9,2,2,"cream"); p.rect(12,17,2,3,"lichen")
    p.rect(1,21,2,2,"lichen"); p.rect(4,27,2,1,"lichen")
    result.append(("bent_wheat",p))
    # Bellflowers with downward mouths and small warm pollen lights.
    p = Pixels(16,32)
    p.line([(6,31),(6,23),(8,18),(11,17)],"light")
    p.line([(6,25),(3,21),(3,17),(5,15)],"stone")
    p.rect(9,17,4,2,"lichen"); p.rect(10,19,3,2,"cream")
    p.rect(10,21,1,1,"brass"); p.rect(3,15,4,2,"lichen")
    p.rect(4,17,3,2,"cream"); p.rect(5,19,1,1,"brass")
    p.rect(7,26,4,1,"light"); p.rect(9,25,2,1,"light")
    result.append(("bellflowers",p))
    # Ground-mounted chime stand; isolated tubes, no illusory solid platform.
    p=Pixels(16,32)
    p.rect(3,12,1,20,"stone"); p.rect(3,11,10,1,"brass")
    p.rect(4,10,3,1,"lichen")
    for x, top, length in ((6,12,9),(9,12,12),(12,12,8)):
        p.rect(x,top,1,2,"light"); p.rect(x,top+2,1,length,"brass")
        p.rect(x,top+3,1,max(1,length-3),"cream")
    p.rect(7,26,1,2,"brass")
    p.rect(6,28,3,1,"lichen")
    result.append(("short_chime",p))
    # Weathered crooked post with suspended, stepped antique bronze bell.
    p=Pixels(16,32)
    p.rect(2,3,2,29,"deep"); p.rect(3,4,1,28,"stone")
    p.rect(2,3,11,2,"stone"); p.rect(5,5,3,1,"deep")
    p.rect(3,2,3,1,"light"); p.rect(11,5,1,4,"light")
    p.rect(9,9,5,1,"brass"); p.rect(8,10,7,4,"brass")
    p.rect(9,10,2,4,"lichen"); p.rect(7,14,9,2,"brass")
    p.rect(8,14,5,1,"cream"); p.rect(11,16,1,2,"brass")
    p.rect(10,18,3,1,"lichen"); p.rect(2,25,2,2,"light")
    result.append(("bell_post",p))
    # Low, cracked offering urn: centre void and one unbalanced handle.
    p=Pixels(16,32)
    p.rect(5,22,6,1,"brass"); p.rect(4,23,8,2,"rose")
    p.rect(5,23,6,1,"ink"); p.rect(4,25,9,4,"brass")
    p.rect(5,29,7,2,"brass"); p.rect(6,31,5,1,"deep")
    p.rect(4,25,2,3,"rose"); p.rect(5,24,1,1,"cream")
    p.rect(12,24,2,3,"brass"); p.rect(13,25,1,1,"ink")
    p.rect(8,27,1,2,"ink"); p.rect(9,29,1,1,"ink")
    result.append(("offering_urn",p))
    # Fern, two spiralling, non-mirrored fronds and a deep understory.
    p=Pixels(16,32)
    p.line([(7,31),(6,27),(6,22),(8,18),(11,17),(13,18),(12,20)],"light")
    p.line([(7,31),(8,27),(11,24),(13,24)],"stone")
    for x,y,w in ((4,28,3),(3,25,3),(4,22,3),(7,20,3),(9,18,2),(10,25,3),(9,28,4)):
        p.rect(x,y,w,1,"light")
    p.rect(11,17,2,1,"lichen"); p.rect(12,19,1,1,"lichen")
    result.append(("fern",p))
    # Wind marker, chipped shoulder and a stepped spiral carved in its face.
    p=Pixels(16,32)
    p.rect(5,17,6,2,"stone"); p.rect(4,19,8,11,"stone")
    p.rect(3,30,10,2,"deep"); p.rect(5,18,2,1,"light")
    p.rect(4,21,1,7,"light"); p.rect(11,20,1,10,"deep")
    p.line([(6,26),(9,26),(10,25),(10,22),(7,22),(6,23),(6,24),(8,24)],"deep")
    p.rect(7,21,2,1,"lichen"); p.rect(9,29,2,1,"light")
    result.append(("wind_marker",p))
    # A narrow, torn banner. Outer contour bends; no smoothing or big rectangle.
    p=Pixels(16,32)
    p.rect(3,2,1,30,"stone"); p.rect(3,2,9,1,"brass")
    p.rect(6,3,6,9,"brass"); p.rect(7,12,5,8,"brass")
    p.rect(8,20,4,3,"brass"); p.rect(8,23,1,2,"brass")
    p.rect(11,23,1,1,"brass"); p.rect(6,4,1,7,"rose")
    p.rect(7,12,1,7,"rose"); p.rect(8,6,2,5,"lichen")
    p.rect(9,7,2,3,"cream"); p.rect(8,8,2,1,"brass")
    result.append(("cloth_banner",p))
    return result


def document(width,height,body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" shape-rendering="crispEdges">\n{body}\n</svg>\n'


def digest(data):
    return hashlib.sha256(data.encode()).hexdigest()


def build():
    cfg=configuration()
    masks=[m for m in range(256) if canonical(m)==m]
    assert len(masks)==47
    pitch=cfg["SOURCE_SIZE"]+2*cfg["GUTTER"]
    atlas_width=cfg["COLUMNS"]*pitch
    block_rows=(len(masks)+cfg["COLUMNS"]-1)//cfg["COLUMNS"]
    atlas_height=block_rows*cfg["VARIANTS"]*pitch
    terrain=[]
    for variant in range(cfg["VARIANTS"]):
        # Diagonal-only states must remain genuinely different material edges,
        # rather than merely carrying 47 different catalog identifiers.
        images={tuple(tuple(row) for row in stone(mask,variant).rows) for mask in masks}
        assert len(images)==47, ("duplicate visual canonical state",variant)
        for index,mask in enumerate(masks):
            p=stone(mask,variant)
            assert all(c for row in p.rows for c in row)
            for other in range(cfg["VARIANTS"]):
                q=stone(mask,other)
                assert all(p.rows[y][x]==q.rows[y][x]
                           for y in range(16) for x in range(16)
                           if x<3 or y<3 or x>=13 or y>=13), (mask,variant,other)
            terrain.append(p.svg(index%cfg["COLUMNS"]*pitch+cfg["GUTTER"],
                                 (index//cfg["COLUMNS"]+variant*block_rows)*pitch+cfg["GUTTER"]))
    outputs={"stone_blob47.svg":document(atlas_width,atlas_height,"\n".join(terrain))}
    prop_art=props()
    outputs["props.svg"]=document(512,128,"\n".join(p.svg(i*64,0) for i,(_,p) in enumerate(prop_art)))
    manifest={
        "schema_version":1,"task_id":"WINDCHIME-PIXEL-01",
        "family_id":"windchime-pixel-stone-v1","status":"candidate_awaiting_visual_review",
        "style":"original limited-palette pixel clusters; wind-eroded mossy stone and brass ecology",
        "palette":PALETTE,"source_pixel_step":4,"world_pixel_step":2,
        "grid":cfg,"atlas_size":[atlas_width,atlas_height],
        "block_rows":block_rows,"atlas_masks":masks,
        "atlas_mapping":[{"mask":m,"variant":v,"coordinate":[i%cfg["COLUMNS"],i//cfg["COLUMNS"]+v*block_rows]}
                         for v in range(cfg["VARIANTS"]) for i,m in enumerate(masks)],
        "terrain_contract":{
            "collision":"full opaque source square equals full solid occupancy cell; no silhouette chips",
            "variant_boundary_lock_source_px":12,
            "surface":"one muted moss ridge at y=0; scattered lichen; no bright all-edge outline",
            "render":"nearest filtering; logical-pixel viewport; no gradients, blur, strokes, noise overlay",
            "gutter":"transparent 2 source pixels on every edge; atlas margins/separation required",
        },
        "props":[{"id":name,"slot":i,"region":[i*64,0,64,128],"anchor":[32,128],
                  "opaque_bounds_source":p.bounds(),"collision":False}
                 for i,(name,p) in enumerate(prop_art)],
        "provenance":{
            "method":"original AI-authored explicit rectangular pixel-cluster program",
            "generator":"tools/build_pixel_plains_art.py",
            "generator_sha256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "technical_input":"scripts/art_foundation/blob47_rules.gd (grid/topology only)",
            "technical_input_sha256":hashlib.sha256(RULES.read_bytes()).hexdigest(),
            "art_inputs":[],
            "inspiration":"user requested Animal Well-like pixel materials, lighting and environmental life; no source assets copied",
            "model":"Codex agent; exact model identifier not exposed to generator",
            "license":"project-authored source; no third-party asset inputs",
        },
        "assets":[{"path":f"assets/pixel_plains/{name}","sha256":digest(data),
                   "size":[atlas_width,atlas_height] if name.startswith("stone") else [512,128],
                   "collision":False,"generation":"original_pixel_cluster_script"}
                  for name,data in outputs.items()],
    }
    outputs["manifest.json"]=json.dumps(manifest,ensure_ascii=False,indent=2)+"\n"
    return outputs


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check",action="store_true")
    args=parser.parse_args()
    outputs=build()
    stale=[name for name,data in outputs.items() if not (OUT/name).exists() or (OUT/name).read_text()!=data]
    if args.check:
        if stale:
            raise SystemExit("stale pixel material outputs: "+", ".join(stale))
        print("PASS pixel plains: 47 masks × 3 variants; boundary locks; 8 anchored props; exact source/provenance")
    else:
        OUT.mkdir(parents=True,exist_ok=True)
        for name,data in outputs.items():
            (OUT/name).write_text(data)
        print(f"Wrote {len(outputs)} original pixel material outputs to {OUT}")


if __name__=="__main__":
    main()
