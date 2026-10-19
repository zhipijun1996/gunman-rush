"""Repack complete source objects without painting, recoloring or resampling.

Uses the three large alpha components as seeds, assigning tiny detached source
pixels to their nearest real object. This handles overlapping x projections.
Requires Pillow, NumPy and SciPy only for offline regeneration.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(style, biome):
    folder = ROOT / 'assets/style_exploration' / style / biome
    path = folder / 'generated/source_props.png'
    source = np.array(Image.open(path).convert('RGBA'))
    labels, _ = ndimage.label(source[:, :, 3] > 32)
    sizes = np.bincount(labels.ravel())
    sizes[0] = 0
    main_labels = np.argsort(sizes)[-3:]
    if len(main_labels) != 3 or sizes[main_labels].min() < 1000:
        raise ValueError('Expected three complete large alpha objects')
    objects = ndimage.find_objects(labels)
    main_labels = sorted(main_labels, key=lambda n: objects[n-1][1].start)
    seeds = np.zeros(labels.shape, np.uint8)
    for i, value in enumerate(main_labels):
        seeds[labels == value] = i+1
    nearest = ndimage.distance_transform_edt(seeds == 0, return_distances=False, return_indices=True)
    assignment = seeds[tuple(nearest)]
    isolated = []
    for i in range(3):
        selected = (assignment == i+1) & (source[:, :, 3] > 0)
        ys, xs = np.where(selected)
        box = [int(xs.min()), int(ys.min()), int(xs.max()+1), int(ys.max()+1)]
        crop = source[box[1]:box[3], box[0]:box[2]].copy()
        mask = selected[box[1]:box[3], box[0]:box[2]]
        crop[~mask] = 0
        isolated.append((Image.fromarray(crop), box))
    gutter = 16
    canvas = Image.new('RGBA', (sum(im.width for im, _ in isolated) + gutter*4, max(im.height for im, _ in isolated) + gutter*2))
    x = gutter
    regions = {}
    adjustments_path = folder / 'anchor_adjustments.json'
    adjustments = json.loads(adjustments_path.read_text()) if adjustments_path.is_file() else {}
    for (image, original_box), name, height in zip(isolated, ('tree', 'tower', 'flowers'), (200, 186, 28)):
        canvas.paste(image, (x, gutter))
        alpha = image.getchannel('A').point(lambda v: 255 if v > 96 else 0)
        bottom = alpha.getbbox()[3]
        band = alpha.crop((0, max(0, bottom-12), image.width, bottom)).getbbox()
        data = {'region': [x, gutter, image.width, image.height], 'foot': [(band[0]+band[2])*0.5, bottom],
                'world_height': height, 'source_box': original_box,
                'support_width': max(32, (band[2]-band[0])*height/image.height*0.9)}
        data.update(adjustments.get('props', {}).get(name, {}))
        regions[name] = data
        x += image.width + gutter
    canvas.save(folder / 'chime_props.png')
    metadata = {'schema': 'style-chime-props-v1', 'source_sha256': sha(path), 'regions': regions,
                'processing': 'exact source RGBA assigned to nearest of three principal connected alpha objects and repacked with 16px gutter; no repaint/recolor/resize'}
    (folder / 'chime_props.json').write_text(json.dumps(metadata, indent=2)+'\n')
    return {'style': style, 'biome': biome, 'source': str(path.relative_to(ROOT)), 'source_sha256': sha(path),
            'derived_sha256': sha(folder / 'chime_props.png'), 'regions': regions}


if __name__ == '__main__':
    records = [prepare(s, b) for s, b in [('underworld', 'forest'), ('underworld', 'gear'), ('cavern', 'forest'), ('cavern', 'gear'), ('cavern', 'plains')]]
    (ROOT / 'assets/style_exploration/region_extraction_manifest.json').write_text(json.dumps(records, indent=2)+'\n')
    print('Prepared 5 region families / 15 complete source objects with preserved source pixels')
