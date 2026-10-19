"""Check new work against a Git base without grandfathering new false completion."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from quality import ROOT, read_json, validate_record, validate_asset
from check_web_bundle import runtime_contract, resource_path, CONNECTED, CONNECTED_ROOT, LANDSCAPE

PRODUCTION = ('scripts/', 'scenes/', 'resources/', 'config/', 'assets/', 'shaders/')
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


def known_asset_consumers(root):
    """Conservative finite adapters/literal references, not GDScript reachability.

    All production source is considered, including dormant branches. Existing
    legacy directory-based loaders conservatively consume their finite local
    family files. New dynamic forms require an adapter instead of guessing.
    """
    root = Path(root)
    manifests, textures, _absent_adapters = runtime_contract(root)
    known = set(manifests) | set(textures) | style_asset_consumers(root)
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
    for directory in ('scripts', 'scenes', 'resources', 'config', 'assets'):
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
