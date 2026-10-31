"""Check new work against a Git base without grandfathering new false completion."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import struct
import zlib
from quality import ROOT, read_json, validate_record, validate_asset
from check_web_bundle import runtime_contract, resource_path, CONNECTED, CONNECTED_ROOT, LANDSCAPE

PRODUCTION = ('scripts/', 'scenes/', 'resources/', 'config/', 'assets/', 'shaders/', 'game/')
# Exact reviewed finite loader. Any source change requires adapter review;
# the hash does not replace runtime_contract's manifest/path/PNG/SHA checks.
CONNECTED_CONSUMER_SHA256 = {
    CONNECTED: '2ed6debb226892b29be4988a9355357be4020780fe6bdd25a82b10aa0eefa65d',
    'scripts/art/plains_region_composition.gd': '0849d8ccffac023150f73d3f701c5878c5badc49883d6fdf3857fe4d6cdeb745',
    'scripts/art/plains_landscape_observer.gd': '19cdab9eed2c620931fbf248599dd1df72a4705935d6b1f37235f77a4322080e',
}


# PR93 dynamic loading is bound to exact reviewed sources, independently of the
# existing connected adapter. A changed loader requires finite-adapter review.
STYLE_CONSUMER_SHA256 = {
    'scripts/style_exploration/style_terrain.gd': 'cb7d47f17554e91e0decfcbd0c143d3234a0aa302e3fe6a61f78ce659ff25b64',
    'scripts/style_exploration/style_actor_visual.gd': '1f3806605ef56a9ef473f8d54002ea0688d811cd07e0a7bdbcf80a2aff8a0f16',
    'scripts/style_exploration/style_scenery.gd': '55cbdfd22ac193162cae6ab6a14b27e8c6a88aad9de0d4e5991744fd97a365b7',
}
STYLE_ROOT = 'assets/style_exploration/'
STYLE_IDS = ('retro', 'basic', 'scribble', 'underworld', 'cavern')
STYLE_ORIGINALS = {
    'retro': ('Environment.png', 'Player.png'),
    'basic': ('sTileset.png',),
    'scribble': ('background_cloudA.png', 'background_cloudB.png', 'background_tree.png',
                 'background_treeLarge.png', 'character_roundPurple.png',
                 'character_handPurple.png', 'tile_grass.png', 'tile_bush.png'),
    'underworld': ('backgroundShapes.png', 'TileSet.png'),
    'cavern': ('background.png', 'back-walls.png', 'tiles.png'),
}


def style_asset_inventory():
    """Exact possible assets, including dormant fallbacks; no directory glob."""
    required = set()
    for style in STYLE_IDS:
        base = STYLE_ROOT + style + '/'
        required.update(base + name for name in ('terrain.png', 'terrain.tres', 'player.png', 'player.json'))
        required.update(base + 'original/' + name for name in STYLE_ORIGINALS[style])
    art_roots = [STYLE_ROOT + style + '/' for style in STYLE_IDS]
    art_roots += [STYLE_ROOT + style + '/' + biome + '/'
                  for style, biome in (('cavern', 'plains'), ('cavern', 'forest'),
                                       ('cavern', 'gear'), ('underworld', 'forest'),
                                       ('underworld', 'gear'))]
    required.update(base + name for base in art_roots
                    for name in ('background_sky.png', 'chime_props.png', 'chime_props.json'))
    optional = {base + name for base in art_roots for name in ('background_far.png', 'background_mid.png')}
    return required, optional


def style_asset_consumers(root):
    root = Path(root).resolve()
    present = [name for name in STYLE_CONSUMER_SHA256 if (root / name).is_file()]
    if not present:
        return set()
    if len(present) != len(STYLE_CONSUMER_SHA256):
        raise ValueError('Style finite adapter requires all three reviewed consumers')
    for name in present:
        if hashlib.sha256((root / name).read_bytes()).hexdigest() != STYLE_CONSUMER_SHA256[name]:
            raise ValueError('Style consumer changed; review finite adapter: ' + name)
    required, optional = style_asset_inventory()
    found = set()
    for name in sorted(required | optional):
        path = (root / resource_path(name)).resolve()
        if not path.is_relative_to(root):
            raise ValueError('Style resource escapes project: ' + name)
        if not path.is_file():
            if name in required:
                raise ValueError('Style finite consumer lacks resource: ' + name)
            continue
        found.add(name)
    return found


# Exact reviewed loader; registry contents may grow without admitting siblings.
ITEM_ART_LOADER = 'scripts/items/v5/item_art_library.gd'
ITEM_ART_LOADER_SHA256 = '14021adaaf43cc82e25c54c8d6e862a53fbe20e317b35b1be393468a91e4c85d'
ITEM_ART_ROOT = 'assets/items/v5/'


def item_art_png_size(data):
    """Validate the PNG container/CRCs without an optional imaging dependency."""
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('Invalid item-art PNG signature')
    offset, dimensions, has_data, ended = 8, None, False, False
    while offset < len(data):
        if len(data) - offset < 12:
            raise ValueError('Truncated item-art PNG chunk')
        length = struct.unpack_from('>I', data, offset)[0]
        kind = data[offset+4:offset+8]
        finish = offset + 12 + length
        if finish > len(data) or zlib.crc32(data[offset+4:finish-4]) & 0xffffffff != struct.unpack_from('>I', data, finish-4)[0]:
            raise ValueError('Invalid item-art PNG chunk/CRC')
        payload = data[offset+8:finish-4]
        if dimensions is None:
            if kind != b'IHDR' or length != 13:
                raise ValueError('Missing item-art PNG IHDR')
            width, height, depth, color, compression, filtering, interlace = struct.unpack('>IIBBBBB', payload)
            legal = {0: (1, 2, 4, 8, 16), 2: (8, 16), 3: (1, 2, 4, 8), 4: (8, 16), 6: (8, 16)}
            if not 0 < width <= 0x7fffffff or not 0 < height <= 0x7fffffff or depth not in legal.get(color, ()) or compression or filtering or interlace not in (0, 1):
                raise ValueError('Invalid item-art PNG IHDR')
            dimensions = (width, height)
        elif kind == b'IHDR':
            raise ValueError('Duplicate item-art PNG IHDR')
        if kind == b'IDAT':
            has_data = has_data or length > 0
        if kind == b'IEND':
            if length or finish != len(data) or not has_data:
                raise ValueError('Invalid item-art PNG end')
            ended = True
            break
        offset = finish
    if not ended:
        raise ValueError('Incomplete item-art PNG')
    return dimensions


def item_art_consumers(root):
    """Enumerate registered PNGs only, checked against their source-family manifest."""
    root = Path(root).resolve()
    loader = root / ITEM_ART_LOADER
    if not loader.is_file():
        return set()
    if hashlib.sha256(loader.read_bytes()).hexdigest() != ITEM_ART_LOADER_SHA256:
        raise ValueError('Item-art loader changed; review finite adapter')

    def local(name):
        path = (root / resource_path(name)).resolve()
        if not path.is_relative_to(root) or not path.is_file():
            raise ValueError('Item-art resource missing or escapes project: ' + name)
        return path

    def source_name(value):
        if not isinstance(value, str) or not value.startswith('res://' + ITEM_ART_ROOT) or not value.endswith('.png') or '%' in value:
            raise ValueError('Invalid item-art PNG reference')
        return resource_path(value)

    config_name = 'config/item_v5_art.json'
    manifest_name = ITEM_ART_ROOT + 'manifest.json'
    config = json.loads(local(config_name).read_text())
    manifest = json.loads(local(manifest_name).read_text())
    if not isinstance(config, dict) or type(config.get('schema_version')) not in (int, float) or config['schema_version'] != 1:
        raise ValueError('Invalid item-art registry schema')
    if any(not isinstance(config.get(key), dict) for key in ('icons', 'clips', 'entities', 'cues')):
        raise ValueError('Invalid item-art registry dictionaries')
    if not isinstance(manifest, dict) or manifest.get('schema_version') != 1 or not isinstance(manifest.get('assets'), list):
        raise ValueError('Invalid item-art source-family manifest')
    family = {}
    for entry in manifest['assets']:
        if not isinstance(entry, dict):
            raise ValueError('Invalid item-art source-family entry')
        name = source_name('res://' + entry.get('path', '') if isinstance(entry.get('path'), str) else None)
        if name in family or not re.fullmatch('[0-9a-f]{64}', str(entry.get('sha256'))):
            raise ValueError('Duplicate/invalid item-art source-family identity')
        family[name] = entry['sha256']
    # Provenance manifest is checker input, never loaded by the Godot consumer.
    known, sizes = set(), {}
    for group in ('icons', 'clips'):
        for key, row in config[group].items():
            if not isinstance(key, str) or not key or not isinstance(row, dict):
                raise ValueError('Invalid item-art recipe')
            if group == 'clips':
                def pair(value, maximum, zero=False):
                    return isinstance(value, list) and len(value) == 2 and all(type(n) in (int, float) and (0 <= n if zero else 0 < n) and n <= maximum for n in value)
                fps = row.get('fps')
                if type(fps) not in (int, float) or not 0 < fps <= 120 or type(row.get('loop')) is not bool or not pair(row.get('world_size'), 640) or not pair(row.get('pivot'), 1, True):
                    raise ValueError('Invalid item-art clip timing/geometry')
                if row.get('timing', 'clip') not in ('clip', 'event') or row.get('orientation', 'fixed') not in ('fixed', 'aim', 'travel') or row.get('geometry', 'fixed') not in ('fixed', 'radius', 'segment'):
                    raise ValueError('Invalid item-art clip pose')
                if row.get('geometry', 'fixed') == 'radius' or 'reference_radius' in row:
                    radius = row.get('reference_radius')
                    if row.get('geometry', 'fixed') not in ('radius', 'segment') or type(radius) not in (int, float) or not 0 < radius <= 640:
                        raise ValueError('Invalid item-art reference radius')
            name = source_name(row.get('texture'))
            if name not in family:
                raise ValueError('Item-art texture missing from source-family manifest: ' + name)
            if name not in sizes:
                path = local(name)
                if hashlib.sha256(path.read_bytes()).hexdigest() != family[name]:
                    raise ValueError('Item-art PNG differs from source-family SHA: ' + name)
                sizes[name] = item_art_png_size(path.read_bytes())
                known.add(name)
            regions = [row.get('region')] if group == 'icons' else row.get('regions')
            if not isinstance(regions, list) or not 1 <= len(regions) <= 128:
                raise ValueError('Invalid item-art regions')
            for region in regions:
                if not isinstance(region, list) or len(region) != 4 or any(type(n) not in (int, float) or not float(n).is_integer() for n in region):
                    raise ValueError('Invalid item-art region')
                x, y, width, height = region
                if x < 0 or y < 0 or width <= 0 or height <= 0 or x + width > sizes[name][0] or y + height > sizes[name][1]:
                    raise ValueError('Item-art region exceeds source PNG')
    def entity_entry(entry):
        return (isinstance(entry, str) and entry in config['clips']) or (isinstance(entry, dict) and set(entry) == {'variants'} and isinstance(entry['variants'], dict) and set(entry['variants']) == {'0', '1', '2'} and all(isinstance(v, str) and v in config['clips'] for v in entry['variants'].values()))
    for mapping in config['entities'].values():
        if not (entity_entry(mapping) or isinstance(mapping, dict) and all(entity_entry(v) for v in mapping.values())):
            raise ValueError('Unknown item-art entity clip')
    for mapping in config['cues'].values():
        if not isinstance(mapping, dict) or any(not isinstance(v, str) or (not v.isidentifier() if k == 'source' else v not in config['clips']) for k, v in mapping.items()):
            raise ValueError('Unknown item-art cue clip')
    if sum(w*h*4 for w, h in sizes.values()) > 64*1024*1024:
        raise ValueError('Item-art PNGs exceed original 64MiB RGBA budget')
    # Every claimed source must be registered, not a sibling admitted by directory.
    if set(family) != set(sizes):
        raise ValueError('Item-art source-family manifest differs from registered PNGs')
    return known



# AUDIO-AMBIENCE-01: finite reviewed loader and the eight authored outputs only.
# This is an asset-identity adapter, not an audio decoder or quality verdict.
AMBIENCE_LOADER = 'scripts/audio/game_ambience.gd'
# MOBILE-WEB-PERF-01: reviewed pause-state-only fix. Asset loading, authored
# paths, manifest parsing and source selection remain unchanged. Keep an exact
# binding so any future loader edit still requires a finite-adapter review.
AMBIENCE_LOADER_SHA256 = 'baa8c204405361bab1f13f3439a4732ddaac744d588c80cf21607586dfca9e48'
AMBIENCE_ROOT = 'assets/audio/ambience_v1/'
AMBIENCE_BEDS = {'plains_a': ('plains', 'A'), 'plains_b': ('plains', 'B'),
                 'forest_a': ('forest', 'A'), 'forest_b': ('forest', 'B')}
AMBIENCE_DETAIL_RULES = {
    'plains_chime_a': ('plains_chime', ['plains'], ['A'], 9, 720),
    'plains_chime_b': ('plains_chime', ['plains'], ['B'], 9, 720),
    'forest_wood': ('forest_wood', ['forest'], ['A', 'B'], 13, 600),
    'forest_leaf': ('forest_leaf', ['forest'], ['A', 'B'], 6, 320),
}
AMBIENCE_DETAILS = set(AMBIENCE_DETAIL_RULES)


def ambience_asset_consumers(root):
    """Bind runtime/catalog/render closure to exact ordinary files, never siblings."""
    root = Path(root).absolute()

    def ordinary(name):
        name = resource_path(name)
        path = root / name
        for ancestor in (path, *path.parents):
            if ancestor.is_symlink():
                raise ValueError('Ambience resource or ancestor is a symlink: ' + name)
            if ancestor == root:
                break
        if not path.is_file() or not path.resolve().is_relative_to(root.resolve()):
            raise ValueError('Ambience resource missing or escapes project: ' + name)
        return path

    loader = root / AMBIENCE_LOADER
    if not loader.exists() and not loader.is_symlink():
        return set()
    if hashlib.sha256(ordinary(AMBIENCE_LOADER).read_bytes()).hexdigest() != AMBIENCE_LOADER_SHA256:
        raise ValueError('Ambience loader changed; review finite adapter')

    def pairs(entries):
        result = {}
        for key, value in entries:
            if key in result:
                raise ValueError('Duplicate ambience JSON key: ' + key)
            result[key] = value
        return result

    def read(name):
        def constant(value):
            raise ValueError('Nonfinite ambience JSON value: ' + value)
        return json.loads(ordinary(name).read_text(), object_pairs_hook=pairs, parse_constant=constant)

    def same(left, right):
        # JSON booleans must never compare equal to numeric IDs/gains/bytes.
        if type(left) in (int, float) or type(right) in (int, float):
            return type(left) in (int, float) and type(right) in (int, float) and left == right
        if type(left) is not type(right):
            return False
        if isinstance(left, dict):
            return left.keys() == right.keys() and all(same(left[k], right[k]) for k in left)
        if isinstance(left, list):
            return len(left) == len(right) and all(same(a, b) for a, b in zip(left, right))
        return left == right

    manifest_name = AMBIENCE_ROOT + 'manifest.json'
    manifest = read(manifest_name)
    if not isinstance(manifest, dict) or type(manifest.get('schema_version')) is not int or manifest['schema_version'] != 1 or manifest.get('version') != 'audio-ambience-v1' or manifest.get('runtime_default') != 'original' or manifest.get('task') != 'AUDIO-AMBIENCE-01' or type(manifest.get('sample_rate')) is not int or manifest['sample_rate'] != 48000 or type(manifest.get('channels')) is not int or manifest['channels'] != 2:
        raise ValueError('Invalid ambience manifest identity/version')
    bindings = {'recipe_sha256': 'config/audio_director/ambience/recipes.json',
                'sources_sha256': 'config/audio_director/ambience/sources.json',
                'pipeline_sha256': 'tools/audio_ambience_design.py'}
    for key, name in bindings.items():
        if manifest.get(key) != hashlib.sha256(ordinary(name).read_bytes()).hexdigest():
            raise ValueError('Ambience input fingerprint drift: ' + key)
    recipe = read(bindings['recipe_sha256'])
    if not isinstance(recipe, dict) or recipe.get('version') != manifest['version'] or recipe.get('task') != 'AUDIO-AMBIENCE-01':
        raise ValueError('Invalid ambience recipe version')
    beds, details = recipe.get('beds'), recipe.get('details')
    if not isinstance(beds, list) or len(beds) != 4 or any(not isinstance(r, dict) or not isinstance(r.get('id'), str) for r in beds) or {r.get('id') for r in beds} != set(AMBIENCE_BEDS):
        raise ValueError('Ambience finite bed inventory changed')
    if not isinstance(details, list) or len(details) != 4 or any(not isinstance(r, dict) or not isinstance(r.get('id'), str) for r in details) or {r.get('id') for r in details} != AMBIENCE_DETAILS:
        raise ValueError('Ambience finite detail inventory changed')
    if type(recipe.get('loop_seconds')) not in (int, float) or not 0 < recipe['loop_seconds'] <= 120:
        raise ValueError('Invalid ambience loop duration')
    for row in beds:
        layers = row.get('layers')
        if not isinstance(row.get('title'), str) or not isinstance(layers, list) or not layers or any(not isinstance(layer, dict) or not isinstance(layer.get('source'), str) for layer in layers):
            raise ValueError('Invalid ambience bed recipe')
    for row in details:
        rule = AMBIENCE_DETAIL_RULES[row['id']]
        actual = [row.get(key) for key in ('event', 'regions', 'profiles', 'min_interval', 'max_distance')]
        if not same(actual, list(rule)) or not isinstance(row.get('title'), str) or not isinstance(row.get('source'), str):
            raise ValueError('Ambience finite detail routing changed')
    renders = manifest.get('renders')
    if not isinstance(renders, list) or len(renders) != 8 or any(not isinstance(r, dict) for r in renders):
        raise ValueError('Invalid ambience render inventory')
    indexed = {}
    known = {manifest_name}
    for row in renders:
        identifier = row.get('id')
        if not isinstance(identifier, str) or identifier in indexed or identifier not in set(AMBIENCE_BEDS) | AMBIENCE_DETAILS:
            raise ValueError('Unknown/duplicate ambience render ID')
        extension = '.ogg' if identifier in AMBIENCE_BEDS else '.wav'
        expected = 'res://' + AMBIENCE_ROOT + identifier + extension
        if row.get('path') != expected or not re.fullmatch('[0-9a-f]{64}', str(row.get('sha256'))) or type(row.get('bytes')) is not int or row['bytes'] <= 0:
            raise ValueError('Invalid ambience render identity/path')
        path = ordinary(expected)
        if path.stat().st_size != row['bytes'] or hashlib.sha256(path.read_bytes()).hexdigest() != row['sha256']:
            raise ValueError('Ambience output fingerprint drift: ' + identifier)
        indexed[identifier] = row
        known.add(resource_path(expected))
    expected_regions = {region: {'profiles': {}} for region in ('plains', 'forest')}
    expected_events = {region: {'id': 'ambience_' + region, 'region': region, 'candidates': []} for region in expected_regions}
    for row in beds:
        region, profile = AMBIENCE_BEDS[row['id']]
        if (row.get('region'), row.get('profile')) != (region, profile):
            raise ValueError('Ambience bed identity/profile changed')
        take = indexed[row['id']]
        source_ids = list(dict.fromkeys(layer['source'] for layer in row['layers']))
        if take.get('source_ids') != source_ids:
            raise ValueError('Ambience bed source IDs changed')
        expected_events[region]['candidates'].append({'id': row['id'], 'profile': profile,
            'title': row['title'], 'path': take['path'], 'loop': True,
            'duration': recipe['loop_seconds'], 'source_ids': source_ids, 'renders': [take]})
        detail_rows = [{'id': detail['event'], 'path': indexed[detail['id']]['path'], 'gain_db': 0.0,
                        'min_interval': detail['min_interval'], 'max_distance': detail['max_distance']}
                       for detail in details if region in detail['regions'] and profile in detail['profiles']]
        expected_regions[region]['profiles'][profile] = {'candidate_id': row['id'], 'bed': take['path'],
                                                        'gain_db': 0.0, 'details': detail_rows}
    expected_points = []
    for row in details:
        take = indexed[row['id']]
        if take.get('source_ids') != [row['source']]:
            raise ValueError('Ambience detail source IDs changed')
        expected_points.append({**take, 'event': row['event'], 'title': row['title']})
    if not same(manifest.get('regions'), expected_regions) or not same(manifest.get('events'), list(expected_events.values())) or not same(manifest.get('point_events'), expected_points):
        raise ValueError('Ambience runtime/catalog/render closure differs')
    return known


def known_asset_consumers(root):
    """Conservative finite adapters/literal references, not GDScript reachability.

    All production source is considered, including dormant branches. Existing
    legacy directory-based loaders conservatively consume their finite local
    family files. New dynamic forms require an adapter instead of guessing.
    """
    root = Path(root)
    manifests, textures, _absent_adapters = runtime_contract(root)
    known = set(manifests) | set(textures) | style_asset_consumers(root) | item_art_consumers(root) | ambience_asset_consumers(root)
    legacy = {
        ('scripts/art/plains_actor_assets.gd', 'res://assets/plains_v3/%s/manifest.json'): 'assets/plains_v3/',
        ('scripts/art/plains_actor_assets.gd', 'res://assets/plains_v3/%s/%s'): 'assets/plains_v3/',
        ('scripts/art/plains_v3_assets.gd', 'res://assets/plains_v3/'): 'assets/plains_v3/',
        ('scripts/art/plains_v3_assets.gd', 'res://assets/plains_v3/ui/%s.png'): 'assets/plains_v3/ui/',
        ('scripts/art/plains_background.gd', 'res://assets/plains_v3/background_layers/'): 'assets/plains_v3/background_layers/',
        ('scripts/audio/game_audio.gd', 'res://assets/audio/kenney/%s.ogg'): 'assets/audio/kenney/',
        ('scripts/enemies/enemy_presentation.gd', 'res://assets/plains_v3/enemies/meadow_actions/'): 'assets/plains_v3/enemies/meadow_actions/',
    }
    suffixes = {'.gd', '.tscn', '.tres', '.json', '.cfg', '.gdshader', '.gdshaderinc'}
    quoted = re.compile(r'''"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\#[^\n]*''')
    for directory in ('scripts', 'scenes', 'resources', 'config', 'assets', 'game'):
        folder = root / directory
        if not folder.is_dir():
            continue
        def walk_error(error):
            raise error
        # os.walk(onerror=...) does not silently lose inaccessible subtrees.
        import os
        for base, _dirs, files in os.walk(folder, onerror=walk_error):
            for filename in files:
                source = Path(base) / filename
                if source.suffix not in suffixes or (directory == 'assets' and source.suffix != '.gd'):
                    continue
                relative = source.relative_to(root).as_posix()
                text = source.read_text()
                connected_reference = re.search(r'\bPlainsConnectedLandscape\b|plains_connected_landscape\.gd', text)
                family_reference = re.search(r'\bread_family\b', text) and relative != LANDSCAPE
                if source.suffix == '.gd' and (connected_reference or family_reference):
                    # Include the public API's complete explicit caller surface.
                    # New callers, aliases and reflection literals fail closed;
                    # even benign source edits require adapter review. This is
                    # a finite adapter, not a general GDScript reachability proof.
                    if hashlib.sha256(source.read_bytes()).hexdigest() != CONNECTED_CONSUMER_SHA256.get(relative):
                        raise ValueError('Connected consumer/caller changed; review and update finite asset adapter: ' + relative)
                for match in quoted.finditer(text):
                    token = match.group()
                    if token.startswith('#'):
                        continue
                    value = token[1:-1]
                    if not value.startswith('res://assets/'):
                        continue
                    if relative == AMBIENCE_LOADER and value == 'res://' + AMBIENCE_ROOT:
                        continue # Exact loader SHA and finite manifest closure validated above.
                    if relative == ITEM_ART_LOADER and value == 'res://' + ITEM_ART_ROOT:
                        continue # Exact SHA-bound loader; finite registry validated above.
                    if relative in STYLE_CONSUMER_SHA256 and value in {
                        'res://' + STYLE_ROOT,
                        'res://' + STYLE_ROOT + '%s/terrain.png',
                        'res://' + STYLE_ROOT + '%s/terrain.tres',
                    }:
                        # Hash-bound loader resolved to exact finite files above.
                        continue
                    if relative == 'scripts/art/plains_semantic_landscape.gd' and value == 'res://assets/region_production_v3/spaces/':
                        continue # Exact dynamic families were validated by runtime_contract.
                    if relative == CONNECTED and value == 'res://' + CONNECTED_ROOT:
                        # This exact directory literal was resolved to the
                        # validated family manifest and raw PNG above; it is not
                        # itself a file and does not consume all sibling assets.
                        continue
                    prefix = legacy.get((relative, value))
                    if prefix is not None:
                        family = root / prefix
                        if not family.is_dir():
                            raise ValueError('Known legacy asset family missing: ' + prefix)
                        for family_base, _family_dirs, family_files in os.walk(family, onerror=walk_error):
                            for family_file in family_files:
                                known.add((Path(family_base) / family_file).relative_to(root).as_posix())
                        continue
                    name = resource_path(value)
                    path = (root / name).resolve()
                    if '%' in value or not path.is_relative_to(root.resolve()) or not path.is_file():
                        raise ValueError('Unresolved asset reference needs finite consumer adapter: ' + relative + ': ' + value)
                    known.add(name)
    return known


def git(root, *args):
    return subprocess.check_output(['git', *args], cwd=root, text=True)


def weakened_checks(before, after):
    """Conservative signal, not proof of semantic equivalence of arbitrary test code."""
    pattern = re.compile(r'assert|expect|success_pattern|error_patterns|failure_pattern|SUITES\s*=|timeout_seconds|timeout=|Parse Error|SCRIPT ERROR', re.I)
    old = {s.strip() for s in before.splitlines() if pattern.search(s) and not s.lstrip().startswith('#')}
    new = {s.strip() for s in after.splitlines() if pattern.search(s) and not s.lstrip().startswith('#')}
    return sorted(old - new)


def removed_checks(before, after):
    old, new = json.loads(before), json.loads(after)
    removed = [f'check:{name}' for name in old['checks'] if name not in new['checks']]
    for profile, checks in old['profiles'].items():
        removed.extend(f'{profile}:{c}' for c in checks if c not in new['profiles'].get(profile, []))
    return removed


def task_states(text):
    result = {}
    for line in text.splitlines():
        cells = [c.strip() for c in line.split('|')[1:-1]]
        # Match the IDs accepted by production_loop, including routed lower-case IDs.
        if len(cells) == 5 and re.fullmatch(r'[A-Za-z0-9_-]+', cells[0]):
            result[cells[0]] = cells[3]
    return result


def validate(base, root=ROOT):
    # Validate revision as an object before using it; base never becomes shell code.
    sha = git(root, 'rev-parse', '--verify', f'{base}^{{commit}}').strip()
    changed = set(git(root, 'diff', '--name-only', sha, '--').splitlines())
    changed.update(git(root, 'ls-files', '--others', '--exclude-standard').splitlines())
    errors = []
    records = [read_json(p) for p in (root / 'docs/quality/records').glob('*.json')]
    for path in sorted(changed):
        if path.startswith('docs/quality/records/') and path.endswith('.json') and (root / path).is_file():
            prior = subprocess.run(['git', 'cat-file', '-e', f'{sha}:{path}'], cwd=root, capture_output=True)
            record = read_json(root / path)
            if prior.returncode != 0 and record.get('formal_impact') and 'consumer_coverage' not in record:
                errors.append(f'New formal record must declare consumer_coverage (null until observed): {path}')
    valid_records = [r for r in records if not validate_record(r, root)['errors']]
    assets = [read_json(p) for p in (root / 'docs/quality/asset_records').glob('*.json')]
    # Coverage is granted only after the entire record validates, including all
    # explicitly named offline production files and their actual byte hashes.
    valid_assets = [a for a in assets if not validate_asset(a, root)]
    provenance_paths = {name for a in valid_assets for name in
                        [a['source_path'], *a['runtime_paths'],
                         *(item['path'] for item in a.get('associated_files', []))]}
    runtime_provenance_paths = {name for a in valid_assets if a['runtime_paths'] for name in
                                [a['source_path'], *a['runtime_paths']]}
    try:
        known_runtime_assets = known_asset_consumers(root)
    except (OSError, ValueError, KeyError, TypeError) as error:
        errors.append('Asset consumer audit unresolved: ' + str(error))
        known_runtime_assets = set()
    for name in sorted(changed):
        runtime = name.startswith(PRODUCTION) or name in {'project.godot', 'export_presets.cfg'}
        covering = [r for r in valid_records if name in r['affected_paths']]
        if runtime and not any(r['task_type'] != 'process' for r in covering):
            errors.append(f'Production change lacks non-process task record: {name}')
        if runtime and covering and not any(r['task_type'] != 'process' and (r['task_type'] != 'small_fix' or r['formal_impact']) for r in covering):
            errors.append(f'Runtime small_fix must declare formal_impact: {name}')
        # Freeze executable/skill/policy claims to their actual reviewed Git contents.
        # Handoff/task/evidence wrappers may be added after that implementation commit.
        implementation = runtime or name.startswith(('tools/', 'tests/', '.agents/', '.github/')) or name == 'docs/quality/policy.json'
        if implementation and covering and all(r['workflow'] == 'done' for r in covering):
            current = (root / name).read_bytes() if (root / name).is_file() else None
            fresh = False
            for record in covering:
                prior = subprocess.run(['git', 'show', f'{record["reviewed_commit"]}:{name}'], cwd=root, capture_output=True)
                fresh |= (prior.stdout == current if prior.returncode == 0 else current is None)
            if not fresh:
                errors.append(f'Completed record is stale for current implementation: {name}')
        if name.startswith('assets/') and (root / name).is_file() and not name.endswith(('.import', '.uid')):
            if name not in provenance_paths:
                errors.append(f'Changed asset lacks provenance metadata: {name}')
            if name in known_runtime_assets and name not in runtime_provenance_paths:
                errors.append(f'Known runtime asset lacks runtime provenance (offline disposition/associated role cannot cover): {name}')
        if name.startswith(('tests/', 'tools/')) and name.endswith(('.gd', '.py', '.json', '.mjs', '.sh')):
            exists = subprocess.run(['git', 'cat-file', '-e', f'{sha}:{name}'], cwd=root, capture_output=True).returncode == 0
            if not exists:
                continue
            before = git(root, 'show', f'{sha}:{name}')
            after = (root / name).read_text() if (root / name).is_file() else ''
            sensitive = name.startswith('tests/') or 'run_' in name or name in {'tools/harness.py', 'tools/harness/profiles.json'}
            weakened = weakened_checks(before, after) if sensitive else []
            removed = removed_checks(before, after) if name == 'tools/harness/profiles.json' and after else []
            if not after or weakened or removed:
                reviewed = any(r['dimensions']['independent_review']['status'] == 'passed' and r.get('test_change_justification') for r in covering)
                if not reviewed:
                    errors.append(f'Test/check deletion or changed guard needs independent review and test_change_justification: {name}; removed guards={weakened + removed}')
    old_tasks = task_states(git(root, 'show', f'{sha}:docs/tasks.md'))
    new_tasks = task_states((root / 'docs/tasks.md').read_text())
    for task, state in new_tasks.items():
        if state == 'done' and old_tasks.get(task) != 'done':
            if not any(r['task_id'] == task and r['workflow'] == 'done' and validate_record(r, root)['task_complete'] for r in valid_records):
                errors.append(f'New done task lacks complete quality record: {task}')
    return errors, sorted(changed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', required=True)
    args = parser.parse_args()
    errors, changed = validate(args.base)
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    print(f'PASS: diff scope, new completion and test guard preservation ({len(changed)} files); semantic review still required.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(f'Diff validation failed: {error}', file=sys.stderr)
        sys.exit(1)
