#!/usr/bin/env python3
"""Rebuild the complete generated opened-chest crop; never paints new artwork."""
import hashlib
import json
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
DIRECTORY = ROOT / 'assets/underworld_plains/objects'

def main():
    spec = json.loads((DIRECTORY / 'objects_build.json').read_text())
    request = json.loads((DIRECTORY / 'generation_request.json').read_text())
    reference = ROOT / request['reference']
    if hashlib.sha256(reference.read_bytes()).hexdigest() != request['reference_sha256']:
        raise RuntimeError('Reference changed; do not silently regenerate a different family')
    original = DIRECTORY / 'opened_chest_original.png'
    if hashlib.sha256(original.read_bytes()).hexdigest() != spec['generation']['source_sha256']:
        raise RuntimeError('Original generated image SHA differs from recorded actual source')
    with Image.open(original) as image:
        image = image.convert('RGBA')
        threshold = spec['opened_chest']['crop_alpha_threshold']
        if spec['opened_chest']['crop_alpha_comparison'] != 'strictly_greater':
            raise RuntimeError('Unknown comparison; do not silently substitute >= for >')
        box = image.getchannel('A').point(lambda alpha:255 if alpha>threshold else 0).getbbox()
        if list(box) != spec['opened_chest']['crop']:
            raise RuntimeError('Measured complete object crop changed')
        cropped = image.crop(box)
        width, height = spec['opened_chest']['size_px']
        if round(cropped.height*width/cropped.width) != height:
            raise RuntimeError('Expected proportional crop, refusing arbitrary sprite distortion')
        output = DIRECTORY / 'opened_chest.png'
        cropped.resize((width,height),Image.Resampling.NEAREST).save(output)
    if hashlib.sha256(output.read_bytes()).hexdigest() != spec['opened_chest']['sha256']:
        raise RuntimeError('Deterministic derived image differs from actual approved source record')
    print('PASS: actual opened chest source/reference/crop/nearest-size/SHA reproduce exactly')

if __name__ == '__main__': main()
