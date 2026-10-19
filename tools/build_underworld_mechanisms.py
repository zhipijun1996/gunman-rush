#!/usr/bin/env python3
"""Measured crop/nearest preparation only. All visible artwork is image source."""
import argparse
import hashlib
import io
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/underworld_plains/mechanisms'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def outputs():
    source = OUT / 'source_carrier.png'
    image = Image.open(source).convert('RGBA')
    # Measured alpha128 bbox, then proportional nearest source-resolution sample.
    carrier = image.crop((70, 272, 2105, 504)).resize((96, 11), Image.Resampling.NEAREST)
    png = io.BytesIO()
    carrier.save(png, format='PNG')
    config = {
        'schema': 'underworld-mechanisms-v1',
        'carrier': {'texture': 'res://assets/underworld_plains/mechanisms/carrier.png',
                    'source': 'assets/underworld_plains/mechanisms/source_carrier.png',
                    'source_sha256': digest(source), 'sha256': hashlib.sha256(png.getvalue()).hexdigest(),
                    'size_px': [96, 11], 'pixel_world_scale': 2,
                    'left_px': 8, 'right_px': 8, 'top_px': 2, 'bottom_px': 2,
                    'middle_x_px': 40, 'middle_width_px': 16,
                    'operation': 'RGBA measured alpha128 bounding crop [70,272,2105,504], proportional nearest to96x11; no recolor, procedural repaint or alpha filling',
                    'prompt_layout_limit': 'Requested logical96x16 not returned exactly; measured slab aspect retained in96x11. Runtime independent cap/body repetition supports authored rectangles.'},
        'bell': {'texture': 'res://assets/underworld_plains/actors/bell.png',
                 'sha256': digest(ROOT/'assets/underworld_plains/actors/bell.png'),
                 'provenance': 'assets/underworld_plains/actors/actors_build.json',
                 'visual_bound_wu': [28,34], 'sampling': 'uniform fit preserving source aspect',
                 'collision_source': 'ShotLatch.setup existing RectangleShape2D28x34, unchanged'},
        'consumers': ['ModuleMovingPlatform.UnderworldCarrierPaint', 'UnderworldTerrain.draw_moving',
                      'ShotLatch main/sequence/access bell and gate/support'],
        'physics_mutation': False,
        'generation_record': 'assets/underworld_plains/mechanisms/generation_call.json'}
    return {OUT/'carrier.png':png.getvalue(), OUT/'mechanisms_build.json':(json.dumps(config,indent=2)+'\n').encode()}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check',action='store_true')
    args = parser.parse_args()
    result = outputs()
    if args.check:
        assert all(path.read_bytes()==data for path,data in result.items()), 'mechanism source derivation drift'
        print('Underworld mechanism sources: byte-identical no-write rebuild')
    else:
        for path,data in result.items(): path.write_bytes(data)
