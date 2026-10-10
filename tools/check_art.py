"""Validate manifest paths, pivots, SVG safety and deterministic source hashes."""
from pathlib import Path
import hashlib
import json
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
errors = []
manifest = json.loads((ROOT / 'assets/manifest.json').read_text())
ids = set()
for item in manifest['assets']:
    path = ROOT / item['path']
    if item['id'] in ids:
        errors.append(f'Duplicate {item["id"]}')
    ids.add(item['id'])
    if not path.is_file():
        errors.append(f'Missing {item["path"]}')
        continue
    if hashlib.sha256(path.read_bytes()).hexdigest() != item['sha256']:
        errors.append(f'Stale hash: {item["path"]}')
    if path.suffix != '.svg':
        continue
    try:
        svg = ET.parse(path).getroot()
        box = [float(n) for n in svg.attrib['viewBox'].split()]
        if len(box) != 4 or box[2] <= 0 or box[3] <= 0:
            raise ValueError('invalid viewBox')
        if [item['width'], item['height']] != box[2:]:
            raise ValueError('manifest dimensions differ')
        anchor = item.get('anchor_px', item.get('pivot_px'))
        if anchor and not (0 <= anchor[0] <= box[2] and 0 <= anchor[1] <= box[3]):
            raise ValueError('pivot outside canvas')
        for node in svg.iter():
            tag = node.tag.split('}')[-1]
            if tag in {'script', 'foreignObject', 'text'}:
                raise ValueError(f'nonportable SVG tag {tag}')
            for attr, value in node.attrib.items():
                if attr.split('}')[-1] in {'href', 'src'} and not value.startswith('#'):
                    raise ValueError('external SVG dependency')
                if re.search(r'url\((?!#)', value):
                    raise ValueError('external style dependency')
    except (ET.ParseError, ValueError, KeyError) as exc:
        errors.append(f'{item["path"]}: {exc}')
for required in ['characters', 'terrain', 'props', 'backgrounds', 'objects', 'ui', 'vfx', 'enemies']:
    if not any(item['path'].startswith(f'assets/{required}/') for item in manifest['assets']):
        errors.append(f'No {required} assets')
if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print(f'PASS: {len(ids)} assets, hashes, dimensions, pivots, self-contained SVGs. Device visuals not verified.')
