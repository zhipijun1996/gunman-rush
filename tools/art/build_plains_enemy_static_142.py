#!/usr/bin/env python3
"""Reproduce the final approved static references from their retained masters."""
import argparse
import hashlib
import io
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'assets/plains_actors_142/source/static'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Verify reproducibility without changing assets')
    args = parser.parse_args()
    manifest = json.loads((SOURCE / 'manifest.json').read_text())
    for name, digest in manifest['sources'].items():
        assert hashlib.sha256((SOURCE / name).read_bytes()).hexdigest() == digest, name
    for name, spec in manifest['assets'].items():
        data = np.array(Image.open(SOURCE / spec['source']).convert('RGBA').crop(spec['crop_xyxy']))
        labels, _ = ndimage.label(data[:, :, 3] >= 128)
        sizes = np.bincount(labels.ravel())
        sizes[0] = 0
        keep = sizes[labels] >= 20
        data[:, :, 3] = np.where(keep, 255, 0)
        data[~keep] = 0
        native = Image.fromarray(data).resize(spec['native_size'], Image.Resampling.NEAREST)
        encoded = io.BytesIO()
        native.save(encoded, format='PNG')
        raw = encoded.getvalue()
        assert hashlib.sha256(raw).hexdigest() == spec['sha256'], name
        target = ROOT / spec['output']
        if args.check:
            assert target.read_bytes() == raw, name
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
    print(f"{len(manifest['assets'])} final static references verified; no review variants generated")


if __name__ == '__main__':
    main()
