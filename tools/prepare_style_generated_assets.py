"""Extract isolated, image-generated sprites; no painting or texture synthesis.

Source sheets are preserved. Bounding boxes follow the four actual alpha-separated
objects, rather than assuming the generator obeyed its equal-column prompt.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/style_exploration'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(style):
    folder = ASSETS / style
    adjustment_file = ASSETS / 'generated_anchor_adjustments.json'
    adjustments = json.loads(adjustment_file.read_text()).get('styles', {}).get(style, {}) if adjustment_file.is_file() else {}
    source = folder / 'generated/source_props.png'
    image = Image.open(source).convert('RGBA')
    alpha = image.getchannel('A')
    runs = []
    start = None
    for x in range(image.width + 1):
        present = x < image.width and alpha.crop((x, 0, x + 1, image.height)).getextrema()[1] > 16
        if present and start is None:
            start = x
        elif not present and start is not None:
            if x - start > 2:
                runs.append((start, x))
            start = None
    if len(runs) != 4:
        raise RuntimeError(f'{style}: expected four real separated objects, got {runs}')
    regions = {}
    for (left, right), name, height in zip(runs, ('tree', 'tower', 'flowers', 'player'), (186, 178, 30, 40)):
        crop_alpha = alpha.crop((left, 0, right, image.height))
        box = crop_alpha.point(lambda p: 255 if p > 16 else 0).getbbox()
        x0, y0, x1, y1 = left + box[0], box[1], left + box[2], box[3]
        # Whole source objects including anti-aliased perimeter remain inside padded regions.
        x0, y0, x1, y1 = max(0, x0 - 3), max(0, y0 - 3), min(image.width, x1 + 3), min(image.height, y1 + 3)
        crop = image.crop((x0, y0, x1, y1))
        root_band = crop.getchannel('A').point(lambda p: 255 if p > 96 else 0)
        opaque_box = root_band.getbbox()
        bottom = opaque_box[3]
        band_box = root_band.crop((0, max(0, bottom - 12), crop.width, bottom)).getbbox()
        foot_x = (band_box[0] + band_box[2]) * 0.5
        data = {'region': [x0, y0, x1-x0, y1-y0], 'foot': [foot_x, bottom], 'world_height': height}
        data.update(adjustments.get('props', {}).get(name, {}))
        regions[name] = data
        if name == 'player':
            crop.save(folder / 'player.png')
            player_metadata = {'foot': data['foot'], 'world_height': height}
            player_metadata.update(adjustments.get('player', {}))
            (folder / 'player.json').write_text(json.dumps(player_metadata, indent=2) + '\n')
    # Runtime uses original sheet bytes as the texture, exact atlas rectangles as regions.
    (folder / 'chime_props.png').write_bytes(source.read_bytes())
    meta = {'schema': 'style-chime-props-v1', 'source_sha256': sha(source), 'regions': regions,
            'processing': 'alpha-separated complete-object rectangular extraction only; no repainting, resampling or color changes'}
    (folder / 'chime_props.json').write_text(json.dumps(meta, indent=2) + '\n')
    return {'style': style, 'source': str(source.relative_to(ROOT)), 'source_sha256': sha(source), 'regions': regions}


if __name__ == '__main__':
    records = [prepare(s) for s in ('retro', 'basic', 'scribble', 'underworld', 'cavern')]
    (ASSETS / 'generated_extraction_manifest.json').write_text(json.dumps(records, indent=2) + '\n')
    print('Extracted 5 sheets / 20 complete objects from preserved generated source images')
