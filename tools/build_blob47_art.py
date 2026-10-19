#!/usr/bin/env python3
"""Author the new vector tile family. No historical images are inputs.

SVG is the editable source, not an AI-generated painting or a final art approval.
Only Python's standard library is required. --check detects stale outputs.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/art_foundation_v1"
RULES = (ROOT / 'scripts/art_foundation/blob47_rules.gd').read_text()


def rule_int(name):
    return int(re.search(r'^const ' + name + r' := (\d+)$', RULES, re.M).group(1))


SIZE, PAD, COLS = rule_int('SOURCE_SIZE'), rule_int('GUTTER'), rule_int('COLUMNS')
CELL, VARIANTS = rule_int('CELL'), rule_int('VARIANTS')
PITCH = SIZE + PAD * 2


def canonical(raw):
    mask = raw & 255
    for diagonal, a, b in ((2, 1, 4), (8, 4, 16), (32, 16, 64), (128, 64, 1)):
        if not mask & a or not mask & b:
            mask &= ~diagonal
    return mask


MASKS = [mask for mask in range(256) if canonical(mask) == mask]


def svg(width, height, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">{body}</svg>\n'


def tile(mask, variant):
    # Continuous neutral fill at EVERY joined edge. All texture marks stay clear
    # of the 4px connection band; variants never alter connection interfaces.
    p = ['<rect width="64" height="64" fill="#c68e57"/>']
    p += ['<path d="M8 25 Q21 16 38 23 L56 19 M13 46 Q29 40 49 45" fill="none" stroke="#b47c4b" stroke-width="2"/>']
    rocks = [(12, 34, 13, 6), (36, 9, 17, 7), (39, 52, 11, 5)]
    for i, (x, y, w, h) in enumerate(rocks):
        x += (variant * 7 + i * 3) % 9 - 4
        p.append(f'<path d="M{x} {y} l{w-4} -2 4 {h//2} -3 {h//2} -{w-4} 1z" fill="#{["dba66b", "d2a06a", "ad7449"][(variant+i)%3]}"/>')
    for bit, path, color in (
        (1, 'M0 2H64', '#3d403d'), (4, 'M62 0V64', '#59433d'),
        (16, 'M0 62H64', '#59433d'), (64, 'M2 0V64', '#3d403d')):
        if not mask & bit:
            p.append(f'<path d="{path}" fill="none" stroke="{color}" stroke-width="4"/>')
    if not mask & 1:
        p += ['<path d="M2 4H62V11L54 10 48 13 37 10 29 12 20 9 12 12 2 10Z" fill="#719f65"/>',
              '<path d="M3 4H61" stroke="#c4d48a" stroke-width="3"/>',
              '<path d="M8 16H27 M36 17H56" stroke="#ecc18a" stroke-width="3" stroke-linecap="round"/>']
    if not mask & 64:
        p.append('<path d="M5 14V57" stroke="#e9b77d" stroke-width="2"/>')
    # Each missing gated diagonal is a visible inside corner; no generic
    # four-neighbour substitute. Marks stay inside physical solid squares.
    for diag, a, b, path in (
        (2, 1, 4, 'M54 0Q54 10 64 10'), (8, 4, 16, 'M64 54Q54 54 54 64'),
        (32, 16, 64, 'M10 64Q10 54 0 54'), (128, 64, 1, 'M0 10Q10 10 10 0')):
        if mask & a and mask & b and not mask & diag:
            p.append(f'<path d="{path}" fill="none" stroke="#59433d" stroke-width="4"/>')
    return ''.join(p)


def atlas():
    groups = []
    for variant in range(VARIANTS):
        for index, mask in enumerate(MASKS):
            x, y = (index % COLS) * PITCH + PAD, (index // COLS + variant * 6) * PITCH + PAD
            groups.append(f'<g transform="translate({x} {y})">{tile(mask, variant)}</g>')
    return svg(COLS * PITCH, 6 * VARIANTS * PITCH, ''.join(groups))


def backgrounds():
    sky = '''<defs><linearGradient id="sky" x2="0" y2="1"><stop stop-color="#a6d6d6"/><stop offset=".7" stop-color="#e2e9cb"/><stop offset="1" stop-color="#f5e6b8"/></linearGradient></defs>
<path d="M0 0H2560V720H0Z" fill="url(#sky)"/>
<circle cx="982" cy="158" r="72" fill="#fbefbc"/><circle cx="982" cy="158" r="91" fill="#fbefbc" opacity=".16"/>
<g fill="#f4f4d9" opacity=".72"><path d="M140 165q20-25 52-14 15-30 45-19 29 6 29 30h58q17 11 0 16H148q-24 0-8-13Z"/><path d="M1200 112q24-23 46-10 20-22 48-8 19-5 27 16h60q12 13-4 14h-175q-20-1-2-12Z"/><path d="M1850 220q20-25 52-14 15-30 45-19 29 6 29 30h58q17 11 0 16h-176q-24 0-8-13Z"/></g>'''
    far = '''<path d="M0 475 90 430 200 447 320 365 440 402 566 327 684 380 770 352 900 401 1032 337 1170 422 1320 385 1440 454 1570 371 1690 407 1800 332 1910 400 2030 361 2180 417 2320 386 2450 452 2560 475V720H0Z" fill="#93b9b0"/>
<path d="m320 365-52 70 70-26 32 12 70-19-85-10Z M566 327l-49 68 49-15 33 12 40-11Z M1032 337l-38 68 33-17 37 13 41-10Z M1800 332l-48 68 49-14 35 13 36-11Z" fill="#b2cbb9"/>
<path d="M0 530q140-115 290-28t310-27 300 19 310-30 340 20 330-23 350 35 330 34V720H0Z" fill="#7ea79b"/>
<g fill="#86aca2"><path d="M714 459V306h19v-19h30v19h19v153h-20v-68q-14-22-28 0v68Z"/><path d="M705 306h86l-43-32Z"/><path d="M2078 466V333h20v-18h28v18h20v133h-22v-61q-12-20-24 0v61Z"/><path d="M2067 333h90l-45-31Z"/></g>'''
    middle = '''<path d="M0 610q130-110 270-63t280 22 270-33 260 27 300-20 300 21 280-41 310 69 290 18V720H0Z" fill="#608e81"/>
<g fill="#719789" stroke="#6a9185" stroke-width="4"><path d="M340 606V436h40v22h36v-45h40v45h36v-22h40v170h-51v-88q-44-55-88 0v88Z"/><path d="M1560 615V426h42v35h37v-61h43v61h38v-35h42v189h-48v-93q-55-53-108 0v93Z"/></g>
<g fill="#507c70"><path d="M1070 586v-92l-30 22 27-49-20 8 34-55 28 58-18-9 25 49-33-20v88Z"/><path d="M2260 608v-112l-30 22 27-49-20 8 34-55 28 58-18-9 25 49-33-20v108Z"/></g>
<g fill="#9ab092" opacity=".5"><ellipse cx="422" cy="567" rx="44" ry="10"/><ellipse cx="1650" cy="577" rx="54" ry="9"/></g>'''
    return {'sky.svg': svg(2560, 720, sky), 'far.svg': svg(2560, 720, far), 'middle.svg': svg(2560, 720, middle)}


def props():
    # All anchors are (32,88). Independent small silhouettes share the palette.
    stem = '#4b7858'
    drawings = [
        '<path d="M32 88Q17 59 10 64L24 85Q20 50 28 48L34 82Q42 55 50 61L39 88Z" fill="#5b8b57" stroke="#3d5947" stroke-width="2"/><path d="M31 80 27 56M36 81 46 66" stroke="#b5ce7d" stroke-width="2"/>',
        f'<path d="M31 88V58M33 78 45 68M30 75 19 64" stroke="{stem}" stroke-width="3"/><g fill="#fff0c3" stroke="#b8875d" stroke-width="1"><circle cx="31" cy="51" r="9"/><circle cx="18" cy="61" r="7"/><circle cx="46" cy="64" r="7"/></g><g fill="#dcaa4e"><circle cx="31" cy="51" r="4"/><circle cx="18" cy="61" r="3"/><circle cx="46" cy="64" r="3"/></g>',
        '<path d="M25 88V73h9v15M40 88V79h7v9" fill="#f5d7a1" stroke="#654e42" stroke-width="2"/><path d="M13 74q3-25 23-13 10 6 9 13ZM33 80q4-17 16-10 7 4 6 10Z" fill="#b96c53" stroke="#654e42" stroke-width="2"/><circle cx="26" cy="66" r="3" fill="#f7dcad"/><circle cx="45" cy="75" r="2" fill="#f7dcad"/>',
        '<path d="M32 88Q10 78 9 65q16 0 23 19Q13 63 17 52q15 5 16 29Q30 55 39 48q10 13-3 36Q48 62 57 65q0 16-22 23Z" fill="#6d9a61" stroke="#41654b" stroke-width="2"/>',
        '<path d="M32 88V25q0-9 9-9h5" fill="none" stroke="#4d4b42" stroke-width="4"/><path d="M40 24h14l-2 21H42Z" fill="#f7d781" stroke="#665340" stroke-width="3"/><path d="M38 23h18l-8-8Z" fill="#678079"/><path d="M44 29v10" stroke="#fff6cb" stroke-width="3"/>',
        '<path d="M23 88q-8-15-5-25h29q3 10-5 25Z" fill="#b47854" stroke="#624c42" stroke-width="3"/><path d="M20 68h25M25 79h14" stroke="#dbab71" stroke-width="2"/><path d="M29 62Q12 49 18 39q15 5 14 22 0-25 12-30 8 19-8 31" fill="#6e955d" stroke="#41654b" stroke-width="2"/>',
    ]
    return svg(384, 96, ''.join(f'<g transform="translate({i*64} 0)">{body}</g>' for i, body in enumerate(drawings)))


def outputs():
    files = {'sandstone_blob47.svg': atlas(), 'props.svg': props(), **backgrounds()}
    manifest = {
        'version': 'blob47-v1', 'status': 'candidate; user visual acceptance unverified',
        'authoring': 'Original editable SVG geometry authored in tools/build_blob47_art.py; no historical art input; no image model used.',
        'license': 'Project-authored source; follows repository license (no new third-party license claim).',
        'configuration_source': 'scripts/art_foundation/blob47_rules.gd',
        'tile_world_size': CELL, 'tile_source_size': SIZE, 'gutter': PAD, 'pitch': PITCH, 'columns': COLS,
        'rows_per_variant': 6, 'variants': VARIANTS, 'material': 'sandstone',
        'bit_order': ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'],
        'tiles': [{'mask': m, 'index': i, 'atlas': [i % COLS, i // COLS]} for i, m in enumerate(MASKS)],
        'props': [{'id': name, 'region': [i*64, 0, 64, 96], 'anchor': [32, 88], 'layer': 'decoration', 'collision': False} for i, name in enumerate(('grass', 'flowers', 'mushrooms', 'fern', 'lantern', 'pot'))],
        'sha256': {name: hashlib.sha256(data.encode()).hexdigest() for name, data in files.items()},
        'references': ['Spelunky 2 (readable modular silhouettes)', 'Rogue Legacy 2 (consistent shapes and reusable props)', 'Super Mario Maker 2 (terrain grammar)', 'https://www.gamedeveloper.com/art/the-art-of-rogue-legacy-or-quot-why-less-is-more-quot-'],
    }
    files['manifest.json'] = json.dumps(manifest, ensure_ascii=False, indent=2) + '\n'
    return files


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--check', action='store_true')
    args = p.parse_args()
    assert len(MASKS) == 47
    assert SIZE == 64 and COLS == 8, 'Editable art was drawn for the frozen V1 source grid; redraw before changing it'
    OUT.mkdir(parents=True, exist_ok=True)
    stale = []
    produced = outputs()
    for name, data in produced.items():
        path = OUT / name
        if args.check:
            if not path.is_file() or path.read_text() != data: stale.append(name)
        else:
            path.write_text(data)
    # Register only this independently authored family. Existing packages remain
    # historical consumers and are not inputs to these new assets.
    registry_path = ROOT / 'assets/manifest.json'
    registry = json.loads(registry_path.read_text())
    records = {entry['id']: entry for entry in registry['assets']}
    for name, data in produced.items():
        if not name.endswith('.svg'):
            continue
        width, height = map(int, re.search(r'width="(\d+)" height="(\d+)"', data).groups())
        entry = {'id': 'foundation.v1.' + Path(name).stem,
                 'path': str((OUT / name).relative_to(ROOT)),
                 'width': width, 'height': height,
                 'sha256': hashlib.sha256(data.encode()).hexdigest(),
                 'style_family': 'blob47-garden-v1', 'scope': 'Blob47Lab candidate',
                 'collision': False}
        if args.check:
            if records.get(entry['id']) != entry:
                stale.append('assets/manifest.json:' + entry['id'])
        elif entry['id'] in records:
            records[entry['id']].clear()
            records[entry['id']].update(entry)
        else:
            registry['assets'].append(entry)
    if not args.check:
        registry_path.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + '\n')
    if stale:
        raise SystemExit('STALE blob47 art: ' + ', '.join(stale))
    print('BLOB47 ART OK: 47 canonical tiles x 3 variants; 3 background layers; 6 props')


if __name__ == '__main__':
    main()
