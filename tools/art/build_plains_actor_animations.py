#!/usr/bin/env python3
"""Bake generated pose sheets: alpha cleanup, fixed-scale nearest sampling only.

Never draws or reconstructs character pixels. A common scale and registration
are retained across each actor's frames; source sheets remain reproducible.
"""
from pathlib import Path
import argparse
import json
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'assets/plains_actors_142'
STATES = ['idle', 'move', 'anticipation', 'attack', 'recovery', 'hurt', 'death']


def bands(mask):
    active = np.flatnonzero(mask.sum(axis=1) > 5)
    groups = np.split(active, np.flatnonzero(np.diff(active) > 8) + 1)
    return [(int(g[0]), int(g[-1]) + 1) for g in groups if len(g) > 12]


def bake_motion(name, spec, clean, rows):
    """Interleave painted in-betweens with untouched original keyframe pixels."""
    base = spec['interleave_from']
    out = ASSETS / 'atlases'
    meta = json.loads((out / f'{base}.json').read_text())
    original = Image.open(out / f'{base}.png').convert('RGBA')
    cw, ch = meta['frame_size']
    pivot = meta['pivot']
    frames = []
    registrations = []
    for row, (top, bottom) in enumerate(rows):
        keys = [original.crop((i*cw,row*ch,(i+1)*cw,(row+1)*ch)) for i in range(4)]
        for col in range(4):
            frames.append(keys[col])
            cell = clean.crop((round(col*clean.width/4),top,round((col+1)*clean.width/4),bottom))
            a, b = keys[col].getbbox(), keys[(col+1)%4].getbbox()
            target = tuple(round((x+y)/2) for x,y in zip(a,b))
            # Registration/resampling only; the image model painted all new pixels.
            painted = cell.crop(cell.getbbox()).resize((target[2]-target[0],target[3]-target[1]),Image.Resampling.NEAREST)
            frame = Image.new('RGBA',(cw,ch))
            frame.paste(painted,target[:2])
            frames.append(frame)
            registrations.append(target)
    atlas = Image.new('RGBA',(cw*8,ch*len(rows)))
    for i, frame in enumerate(frames): atlas.paste(frame,((i%8)*cw,(i//8)*ch))
    atlas.save(out / f'{name}.png')
    points = []
    result = dict(frame_size=[cw,ch],pivot=pivot,columns=8,states=spec['states'],core_points=points,
                  reference=base,interleave_from=base,registration_boxes=registrations,
                  source_rows=rows,source_size=list(clean.size))
    (out / f'{name}.json').write_text(json.dumps(result,indent=2)+'\n')
    (out / f'{name}.tres').write_text(
        '[gd_resource type="Resource" script_class="PlainsActorAnimation" load_steps=3 format=3]\n'
        '[ext_resource type="Script" path="res://game/presentation/actors/art/plains_actor_animation.gd" id="1"]\n'
        f'[ext_resource type="Texture2D" path="res://assets/plains_actors_142/atlases/{name}.png" id="2"]\n'
        '[resource]\nscript = ExtResource("1")\natlas = ExtResource("2")\n'
        f'frame_size = Vector2i({cw}, {ch})\npivot = Vector2({pivot[0]}, {pivot[1]})\ncolumns = 8\n'
        f'clips = Array[String]({json.dumps(spec["states"])})\n'
        + ('core_points = PackedVector2Array('+', '.join(str(v) for p in points for v in p)+')\n' if points else ''))
    print(f'{name}: {len(frames)} registered frames; original even frames unchanged')


def bake(name):
    source = ASSETS / 'source' / f'{name}.png'
    spec_path = source.with_suffix('.json')
    spec = json.loads(spec_path.read_text()) if spec_path.exists() else {}
    reference = spec.get('reference', name)
    raw = np.array(Image.open(source).convert('RGBA'))
    mask = raw[:, :, 3] >= 128
    labels, count = ndimage.label(mask)
    areas = np.bincount(labels.ravel())
    mask &= areas[labels] >= 20
    raw[:, :, 3] = mask.astype(np.uint8) * 255
    raw[~mask] = 0
    clean = Image.fromarray(raw)
    rows = bands(mask)
    states = spec.get('states', STATES)
    if len(rows) != len(states):
        raise ValueError(f'{name}: expected {len(states)} pose bands, found {rows}')
    if 'interleave_from' in spec:
        bake_motion(name, spec, clean, rows)
        return
    width, height = clean.size
    columns = spec.get('columns', 4)
    cells = []
    anchors = []
    for row, (top, bottom) in enumerate(rows):
        limits = []
        for col in range(columns):
            x0, x1 = round(col * width / columns), round((col + 1) * width / columns)
            box = clean.crop((x0, top, x1, bottom)).getbbox()
            if box is None:
                raise ValueError(f'{name}: empty {row}/{col}')
            limits.append(box)
        # One common floor per row; feet can lift during a stride.
        floor = int(np.median([b[3] for b in limits])) + top
        anchors.append(floor)
        for col in range(columns):
            x0, x1 = round(col * width / columns), round((col + 1) * width / columns)
            cells.append((clean.crop((x0, top, x1, bottom)), floor - top))
    native = Image.open(ASSETS / 'static' / f'{reference}.png')
    calibration = spec.get('calibration_row', 0)
    scale = spec.get('scale', native.height / (rows[calibration][1] - rows[calibration][0]))
    registration_x = 0
    cw = int(np.ceil(width / columns * scale)) + 8 + abs(registration_x) * 2
    above = int(np.ceil(max(floor for cell, floor in cells) * scale))
    below = int(np.ceil(max(cell.height - floor for cell, floor in cells) * scale))
    ch = above + max(0, below) + 12
    pivot = [cw // 2, above + 6]
    atlas = Image.new('RGBA', (cw * columns, ch * len(rows)))
    frames = []
    for index, (cell, floor) in enumerate(cells):
        resized = cell.resize((round(cell.width * scale), round(cell.height * scale)), Image.Resampling.NEAREST)
        frame = Image.new('RGBA', (cw, ch))
        xy = (pivot[0] - resized.width // 2 + registration_x, pivot[1] - round(floor * scale))
        if xy[1] < 2:
            raise ValueError(f'{name}: insufficient upper gutter')
        frame.alpha_composite(resized, xy)
        bbox = frame.getbbox()
        if bbox[0] < 2 or bbox[1] < 2 or bbox[2] > cw - 2 or bbox[3] > ch - 2:
            raise ValueError(f'{name}: clipped frame {index}: {bbox}')
        atlas.paste(frame, ((index % columns) * cw, (index // columns) * ch))
        frames.append(frame)
    out = ASSETS / 'atlases'
    out.mkdir(exist_ok=True)
    atlas.save(out / f'{name}.png')
    core_points, muzzle_points, barrel_pivots, barrel_regions = [], [], [], []
    meta = dict(frame_size=[cw, ch], pivot=pivot, columns=columns, states=states, core_points=core_points, muzzle_points=muzzle_points, barrel_pivots=barrel_pivots, barrel_regions=barrel_regions,
                scale=scale, registration_x=registration_x, source_size=[width, height], source_rows=rows,
                source_floors=anchors, reference=reference)
    (out / f'{name}.json').write_text(json.dumps(meta, indent=2) + '\n')
    (out / f'{name}.tres').write_text(
        '[gd_resource type="Resource" script_class="PlainsActorAnimation" load_steps=3 format=3]\n'
        '[ext_resource type="Script" path="res://game/presentation/actors/art/plains_actor_animation.gd" id="1"]\n'
        f'[ext_resource type="Texture2D" path="res://assets/plains_actors_142/atlases/{name}.png" id="2"]\n'
        '[resource]\nscript = ExtResource("1")\natlas = ExtResource("2")\n'
        f'frame_size = Vector2i({cw}, {ch})\npivot = Vector2({pivot[0]}, {pivot[1]})\n'
        f'columns = {columns}\nclips = Array[String]({json.dumps(states)})\n'
        + ('core_points = PackedVector2Array(' + ', '.join(str(v) for p in core_points for v in p) + ')\n' if core_points else '')
        + ('muzzle_points = PackedVector2Array(' + ', '.join(str(v) for p in muzzle_points for v in p) + ')\n' if muzzle_points else '')
        + ('barrel_pivots = PackedVector2Array(' + ', '.join(str(v) for p in barrel_pivots for v in p) + ')\n' if barrel_pivots else '')
        + ('barrel_regions = Array[Rect2]([' + ', '.join('Rect2('+', '.join(map(str,r))+')' for r in barrel_regions) + '])\n' if barrel_regions else ''))
    preview = ROOT / 'build/plains_actors_142'
    preview.mkdir(parents=True, exist_ok=True)
    enlarged = [f.resize((cw * 4, ch * 4), Image.Resampling.NEAREST) for f in frames]
    enlarged[0].save(preview / f'{name}.gif', save_all=True, append_images=enlarged[1:],
                     duration=140, loop=0, disposal=2)
    atlas.resize((atlas.width * 3, atlas.height * 3), Image.Resampling.NEAREST).save(preview / f'{name}-sheet.png')
    print(f'{name}: {len(frames)} poses, {cw}x{ch}, scale={scale:.4f}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('names', nargs='*')
    args = parser.parse_args()
    for name in args.names or sorted(p.stem for p in (ASSETS / 'source').glob('*.png')):
        bake(name)
