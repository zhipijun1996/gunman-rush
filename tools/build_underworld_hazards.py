#!/usr/bin/env python3
"""Build an integrated hazard surface from one generated reference and original rock.

The generated reference is deliberately not accepted as a tile atlas. Its measured
opaque bramble region is snapped to the source 16px grid and a frozen small palette;
the embedded material is copied from the same Underworld rock as the formal terrain.
No geometry or damage configuration is authored here.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/underworld_plains/hazards'
SOURCE = ROOT / 'assets/style_exploration/underworld/source/TileSet.png'
REFERENCE = OUT / 'generated_reference.png'
PALETTE = [(32, 13, 25, 255), (65, 22, 34, 255), (104, 39, 42, 255),
           (157, 75, 50, 255), (202, 129, 68, 255), (237, 185, 107, 255)]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build():
    source = Image.open(SOURCE).convert('RGBA')
    reference = Image.open(REFERENCE).convert('RGBA')
    # Frozen after inspecting the actual alpha>=128 silhouette, not equal slicing.
    # Bottom rock is discarded; its material belongs to the original platform.
    band = reference.crop((30, 272, 2144, 450)).resize((128, 16), Image.Resampling.NEAREST)
    # Preserve a pre-quantization red-root mask from the *actual* generated roots.
    roots = {(x, y) for y in range(12, 16) for x in range(128)
             if (lambda p: p[3] >= 128 and p[0] > p[2] * 1.3 and p[0] > 20)(band.getpixel((x, y)))}
    for y in range(16):
        for x in range(128):
            r, g, b, a = band.getpixel((x, y))
            if a < 128:
                band.putpixel((x, y), (0, 0, 0, 0))
            else:
                light = (r * 0.299 + g * 0.587 + b * 0.114)
                band.putpixel((x, y), PALETTE[min(5, int(light / 36))])
    atlas = Image.new('RGBA', (64, 16))
    root = source.crop((32, 16, 48, 20))
    for column, offset in enumerate([0, 32, 64, 96]):
        tile = Image.new('RGBA', (16, 16))
        tile.paste(root, (0, 12))
        tile.paste(band.crop((offset, 0, offset + 16, 12)), (0, 0))
        # Composite actual reference root pixels into the original rock substrate.
        # No procedurally invented roots, tip shapes or alpha gap filling.
        for x in range(16):
            for y in range(12, 16):
                if (offset + x, y) in roots:
                    tile.putpixel((x, y), band.getpixel((offset + x, y)))
        atlas.paste(tile, (column * 16, 0))
    atlas_path = OUT / 'hazard_surface.png'
    buffer = io.BytesIO()
    atlas.save(buffer, format='PNG')
    atlas_bytes = buffer.getvalue()
    metadata = {
        'schema_version': 1,
        'consumer_script': 'game/presentation/world/underworld_plains/underworld_hazard_tiles.gd',
        'source_image': {'path': str(SOURCE.relative_to(ROOT)), 'sha256': sha(SOURCE),
                         'license': 'custom publisher permission; not CC0', 'publisher': 'Asouris'},
        'generated_reference': {'path': str(REFERENCE.relative_to(ROOT)), 'sha256': sha(REFERENCE),
                                'prompt_record': 'assets/underworld_plains/hazards/generation_call.json',
                                'model_status': 'unknown; tool exposes no model identifier'},
        'atlas': {'path': str(atlas_path.relative_to(ROOT)), 'sha256': hashlib.sha256(atlas_bytes).hexdigest(),
                  'tileset': 'assets/underworld_plains/hazards/hazard_tileset.tres', 'source_id': 0,
                  'tile_size_px': [16, 16], 'columns': ['start', 'middle', 'end', 'single'],
                  'external_depth_px': 12, 'embedded_root_px': 4},
        'world': {'tile_width': 32, 'embedded_root_depth': 8},
        'semantics': {'damage_source': 'PlatformThornDefinition.danger',
                      'orientation': ['top', 'left', 'right', 'bottom'], 'one_way': False,
                      'collision_mutation': False},
        'connection': {'material_family': 'underworld_green_rock',
                       'root_source': 'same_underworld_platform', 'floating_base': False},
        'processing': {'command': 'python tools/build_underworld_hazards.py',
                       'reference_crop_px': [30, 272, 2144, 450], 'alpha_cutoff': 128,
                       'resample': 'nearest', 'palette_rgba': PALETTE,
                       'palette_mapping': 'generated reference luma floor(luma/36), clamped 0..5; original rock unchanged',
                       'root_composite': 'Actual generated pixels in normalized y12..15 with alpha>=128, red>blue*1.3, red>20 overlay original rock; no procedural roots or alpha gap fill',
                       'variant_offsets_px': [0, 32, 64, 96],
                       'substrate_source_region_px': [32, 16, 16, 4],
                       'limits': 'Generated reference adapted to pixel grid; not native 47-blob tile art. '
                                 'Orientation uses exact rectangular source mapping; root clipped to real host.'}}
    tileset = ('[gd_resource type="TileSet" format=3]\n\n'
               '[ext_resource type="Texture2D" path="res://assets/underworld_plains/hazards/hazard_surface.png" id="1"]\n\n'
               '[sub_resource type="TileSetAtlasSource" id="Atlas"]\n'
               'texture = ExtResource("1")\ntexture_region_size = Vector2i(16, 16)\n'
               '0:0/0 = 0\n1:0/0 = 0\n2:0/0 = 0\n3:0/0 = 0\n\n'
               '[resource]\ntile_size = Vector2i(16, 16)\nsources/0 = SubResource("Atlas")\n')
    return {atlas_path: atlas_bytes, OUT / 'hazard_tileset.tres': tileset.encode(),
            OUT / 'hazard_build.json': (json.dumps(metadata, indent=2) + '\n').encode()}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    outputs = build()
    if args.check:
        assert all(p.read_bytes() == data for p, data in outputs.items()), 'hazard derivation drift'
        print('Underworld hazard atlas: byte-identical deterministic rebuild')
    else:
        for path, data in outputs.items():
            path.write_bytes(data)
