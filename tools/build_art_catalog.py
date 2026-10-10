"""Combine agent packs into an engine-neutral demo art manifest."""
from pathlib import Path
import hashlib
import json
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]

def build():
    fragments = sorted((ROOT / 'assets').rglob('manifest_fragment.json'))
    entries, ids = [], set()
    for fragment in fragments:
        pack = json.loads(fragment.read_text())
        for raw in pack.get('assets', pack.get('layers', [])):
            item = dict(raw)
            path = item.get('path', item.get('file'))
            if not path:
                continue
            candidate = ROOT / path
            if not candidate.exists():
                candidate = fragment.parent / path
            if not candidate.is_file():
                raise ValueError(f'Missing asset: {path}')
            item['path'] = candidate.relative_to(ROOT).as_posix()
            item['id'] = item['path'].removeprefix('assets/').rsplit('.', 1)[0].replace('/', '.')
            if item['id'] in ids:
                raise ValueError(f'Duplicate asset: {item["id"]}')
            ids.add(item['id'])
            if candidate.suffix == '.svg':
                svg = ET.parse(candidate).getroot()
                box = [float(n) for n in svg.attrib['viewBox'].split()]
                item['width'], item['height'] = box[2:]
            item['sha256'] = hashlib.sha256(candidate.read_bytes()).hexdigest()
            item['pack_manifest'] = fragment.relative_to(ROOT).as_posix()
            item['status'] = 'demo_candidate_awaiting_device'
            entries.append(item)
    result = {'schema_version': 1, 'content_version': 'plains_demo_v1',
              'style': 'original_hand_drawn_mechanical_plains',
              'generation': 'AI-authored procedural vector runtime assets; AI-image source masters separately recorded',
              'engine_target': 'Godot 4.7.2 Standard', 'assets': entries}
    (ROOT / 'assets/manifest.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(f'Catalog: {len(entries)} assets in {len(fragments)} packs')

if __name__ == '__main__':
    build()
