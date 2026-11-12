#!/usr/bin/env python3
"""Reproduce the route's rear architecture from recorded source pixels."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true')
    parser.add_argument('--provenance', default='assets/plains_v07/source/clockheart-route-provenance.json')
    args = parser.parse_args()
    provenance = json.loads((ROOT / args.provenance).read_text())
    for row in provenance['assets']:
        source = ROOT / row['source']
        if hashlib.sha256(source.read_bytes()).hexdigest() != row['source_sha256']:
            raise ValueError(f'Source changed: {source}')
        image = Image.open(source).convert('RGBA')
        threshold = row.get('alpha_zero_at_or_below', 0)
        if threshold:
            image.putalpha(image.getchannel('A').point(lambda a: 0 if a <= threshold else a))
        x, y, width, height = row['source_rect']
        image = image.crop((x, y, x + width, y + height)).resize(tuple(row['size']), Image.Resampling.NEAREST)
        if row.get('alpha_threshold'):
            cutoff = row['alpha_threshold']
            image.putalpha(image.getchannel('A').point(lambda a: 0 if a < cutoff else 255))
        target = ROOT / row['image']
        if args.verify:
            actual = Image.open(target).convert('RGBA')
            if image.size != actual.size or ImageChops.difference(image, actual).getbbox(alpha_only=False):
                raise ValueError(f'Native pixels differ: {target}')
            if hashlib.sha256(target.read_bytes()).hexdigest() != row['sha256']:
                raise ValueError(f'Native hash differs: {target}')
        else:
            image.save(target)
        print(('VERIFIED ' if args.verify else 'BAKED ') + row['image'])

if __name__ == '__main__':
    main()
