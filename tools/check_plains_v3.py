#!/usr/bin/env python3
"""Read-only art catalog validation. Never changes source PNG pixels."""
import hashlib
import json
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]
def read(p):
    return json.loads((root/p).read_text())
def validate_region(file,r):
    x,y,w,h=r
    iw,ih=Image.open(root/file).size
    assert x>=0 and y>=0 and w>0 and h>0 and x+w<=iw and y+h<=ih,(file,r)
m=read('assets/plains_v3/manifest.json')
for e in m['assets']:
    p=root/e['path']
    assert hashlib.sha256(p.read_bytes()).hexdigest()==e['sha256'],p
    assert list(Image.open(p).size)==e['size'],p
    assert e['source_unchanged'] and not e['default_runtime_consumer'],p
catalog=read('preview/plains_v3_catalog.json')
assert len(catalog)==78
for e in catalog:validate_region(e['file'],e['region'])
h=read('assets/plains_v3/hero/preview_manifest.json')
assert len(h['frames'])==16
assert {f['state'] for f in h['frames']}=={'idle','run','jump','fall','recoil','death'}
for f in h['frames']:
    validate_region(f['path'],f['region'])
    x,y=f['pivot_px']; assert 0<=x<=f['region'][2] and 0<=y<=f['region'][3]
ui=read('assets/plains_v3/ui/manifest.json')
assert set(ui['stage_type_mapping'])=={'combat','item_reward','coin_reward','health_reward','shop','boss'}
assert read('assets/plains_v3/hero/manifest.json')['body_contains_weapon'] is False
print(f"PASS: {len(m['assets'])} source PNG hashes/dimensions, 78 sprite regions, 16 body frames/six states, independent weapon, six exit mappings. Runtime/device not tested.")
