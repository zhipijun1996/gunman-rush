"""Check painted source integrity and engine atlas regions; no image mutation."""
from pathlib import Path
import hashlib
import json
import sys
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
data=json.loads((ROOT/'assets/painterly_v2/manifest.json').read_text())
errors=[]
paths=set()
for asset in data['assets']:
    path=ROOT/asset['path']
    paths.add(asset['path'])
    if not path.is_file():
        errors.append(f'Missing {path}')
        continue
    with Image.open(path) as image:
        if image.size!=(asset['width'],asset['height']):
            errors.append(f'Dimensions changed: {path}')
    if hashlib.sha256(path.read_bytes()).hexdigest()!=asset['sha256']:
        errors.append(f'Source hash changed: {path}')
states=set()
for frame in data['frames']:
    states.add(frame['state'])
    if frame['path'] not in paths:
        errors.append(f'Unregistered sheet: {frame["path"]}')
        continue
    with Image.open(ROOT/frame['path']) as image:
        x,y,w,h=frame['region']
        if not (0<=x and 0<=y and w>0 and h>0 and x+w<=image.width and y+h<=image.height):
            errors.append(f'Out of bounds atlas: {frame}')
        px,py=frame['pivot_px']
        if not (0<=px<=w and 0<=py<=h):
            errors.append(f'Invalid pivot: {frame}')
if states!={'idle','run','jump','fall','recoil','death'}:
    errors.append(f'Six actions required; got {states}')
if data['independent_aim_approved']:
    errors.append('Baked gun sheets must not be labeled independent-aim approved')
if errors:
    print('\n'.join(errors),file=sys.stderr);sys.exit(1)
print(f'PASS: {len(paths)} painted images, {len(data["frames"])} atlas regions, six states, source hashes. Visual/device approval remains pending.')
