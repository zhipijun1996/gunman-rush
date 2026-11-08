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


def core_point(frame, reference, pivot):
    """Locate the existing gold weakpoint; records geometry, edits no pixels."""
    pixels = np.array(frame).astype(float)
    bbox = frame.getbbox()
    left, top, right, bottom = bbox
    width, height = right - left, bottom - top
    bell = reference == 'bellstrider'
    phase2 = reference == 'windkeeper_phase2'
    roi = (.34, .17, .72, .63) if bell else (.50, .48 if phase2 else .25, .97, .96)
    mask = ((pixels[:,:,0] > 135) & (pixels[:,:,0] > pixels[:,:,1] * 1.12)
            & (pixels[:,:,1] > pixels[:,:,2] * 1.8) & (pixels[:,:,3] > 128))
    ys, xs = np.indices(mask.shape)
    mask &= ((xs >= left + width * roi[0]) & (xs < left + width * roi[2])
             & (ys >= top + height * roi[1]) & (ys < top + height * roi[3]))
    labels, count = ndimage.label(mask)
    areas = np.bincount(labels.ravel()); areas[0] = 0
    if not count or areas.max() < 3:
        return [round(left + width * (.52 if bell else .75) - pivot[0]),
                round(top + height * (.42 if bell else .70 if phase2 else .58) - pivot[1])]
    y, x = np.nonzero(labels == areas.argmax())
    return [round(float(np.mean(x)) - pivot[0], 2), round(float(np.mean(y)) - pivot[1], 2)]


def mortar_point(frame, pivot):
    """Measure the dark opening inside the painted rear copper barrel."""
    a = np.array(frame).astype(float)
    left, top, right, bottom = frame.getbbox()
    ys, xs = np.indices(a.shape[:2])
    mask = ((a[:,:,3] > 128) & (a[:,:,0] < 100)
            & (a[:,:,0] > a[:,:,1] * 1.05) & (a[:,:,1] > a[:,:,2] * 1.15)
            & (xs > left + (right-left)*.05) & (xs < left + (right-left)*.35)
            & (ys > top + (bottom-top)*.18) & (ys < top + (bottom-top)*.6))
    labels, count = ndimage.label(mask)
    areas = np.bincount(labels.ravel())
    candidates = []
    for k in range(1, count+1):
        if areas[k] < 50: continue
        y, x = np.nonzero(labels == k)
        candidates.append((float(y.mean()), float(x.mean())))
    if not candidates: raise ValueError('No painted mortar opening found')
    y, x = min(candidates)
    return [round(x-pivot[0], 2), round(y-pivot[1], 2)]


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
    boss = reference.startswith(('bellstrider', 'windkeeper'))
    registration_x = 0
    if boss:
        # Calibrate physical body size, not the changing height of rotating
        # sails. One chest/bell-to-floor distance is shared by every sheet.
        first, floor = cells[0]
        calibration_reference = 'windkeeper_phase1' if name == 'windkeeper_transition' else reference
        core = core_point(first, calibration_reference, [first.width / 2, floor])
        target_y = 150 if reference == 'bellstrider' else 95
        scale = spec.get('scale', target_y / abs(core[1]))
        target_x = 10 if reference == 'bellstrider' else 39
        registration_x = round(target_x - core[0] * scale)
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
    core_points = [core_point(f, reference, pivot) for f in frames] if reference.startswith(('bellstrider', 'windkeeper')) else []
    muzzle_points = [mortar_point(f, pivot) for f in frames] if name == 'bellstrider_lob' else []
    barrel_pivots, barrel_regions = [], []
    if name == 'bellstrider_lob':
        for f, mouth in zip(frames, muzzle_points):
            left, top, right, bottom = f.getbbox()
            joint = [round(left+(right-left)*.26), round(top+(bottom-top)*.50)]
            mouth_xy = [mouth[0]+pivot[0],mouth[1]+pivot[1]]
            margin = 12
            x0 = round(min(joint[0],mouth_xy[0])-margin)
            y0 = round(mouth_xy[1]-margin)
            x1 = round(max(joint[0],mouth_xy[0])+margin)
            y1 = joint[1]-3
            barrel_regions.append([x0,y0,x1-x0,y1-y0])
            barrel_pivots.append([joint[0]-pivot[0],joint[1]-pivot[1]])
    if 'release_offset_from_core_source' in spec:
        offset = spec['release_offset_from_core_source']
        muzzle_points = [[round(p[0]+offset[0]*scale,2),round(p[1]+offset[1]*scale,2)] for p in core_points]
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
