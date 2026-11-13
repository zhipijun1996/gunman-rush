"""Mechanical native baking; no synthesized/repainted pixels."""
import hashlib
import json
from pathlib import Path
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/kit_reuse'
raw = Image.open(BASE / 'source/arch-raw.png').convert('RGBA')
a = np.array(raw)
bounds = Image.fromarray(np.uint8(a[:, :, 3] >= 128) * 255).getbbox()
crop = np.array(raw.crop(bounds))
# This solid cutout needs hard alpha. Do not apply this to fog or water.
crop[:, :, 3] = np.where(crop[:, :, 3] >= 128, 255, 0)
crop[crop[:, :, 3] == 0] = 0
native = Image.fromarray(crop)
native.thumbnail((640, 640), Image.Resampling.NEAREST)
native.save(BASE / 'native/arch.png')
native.resize((317, 320), Image.Resampling.NEAREST).save(BASE / 'native/arch-half.png')
# Deliberately authored straight-pier repeat, not a purported complete plant.
native.crop((0, 320, 92, 640)).save(BASE / 'native/pier.png')
files = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
         for p in sorted(BASE.rglob('*.png'))}
manifest = {
    'native_size': list(native.size), 'raw_size': list(raw.size),
    'crop': list(bounds), 'alpha_threshold': 128, 'resampling': 'nearest',
    'repeat_stride': 544, 'pier_extension': {'crop': [0, 320, 92, 640], 'overlap': 32},
    'generation_geometry': 'FAILED exact requested silhouette: native pier ~90px vs requested64px; opening ~454px vs512px. Background art only; no collision inferred.',
    'ownership': 'isolated experimental presentation; not a new world-element schema or registry',
    'provenance': 'new arch generated using image_gen with project-owned references; no external stock inputs; original project assets retain their own provenance',
    'references': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in [
        'assets/kit_reuse/source/arch-guide.png',
        'assets/engine_first_2d/native/painting.png',
    ]},
    'files': files,
}
(BASE / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
