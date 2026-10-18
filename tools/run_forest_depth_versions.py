"""Fresh native version registry/recorded-v1 checks, not forest v2 admission.

Run inside copy_runtime_snapshot.py's guarded runtime snapshot while holding
its host's global engine lock; this wrapper never mutates the author worktree.
"""
import argparse
import contextlib
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import time

import level_formal
from run_tests import run_engine

ROOT = Path(__file__).resolve().parents[1]


def validate(data):
    if data.get('failures') != 0 or not isinstance(data.get('assertions'), int) or data['assertions'] < 60:
        raise ValueError('Complete version runtime assertions required')
    checks = data.get('checks', [])
    if len(checks) != data['assertions'] or not all(r.get('passed') is True for r in checks):
        raise ValueError('Full native assertion ledger required')
    rows = data.get('cases', [])
    delegates = [r for r in rows if r.get('id') == 'delegate']
    expected = {(f'version-contract-{seed:02d}/thorn_forest/map_{map_index}', map_index)
                for seed in range(4) for map_index in (1, 2)}
    if len(delegates) != 8 or {(r.get('seed'), r.get('map')) for r in delegates} != expected:
        raise ValueError('All four seeds and two maps required')
    legacy = 'thorn-forest-region-v1'
    for row in delegates:
        if (row.get('equal_complete_output') is not True or row.get('stage_generator_version') != legacy
                or row.get('enemy_version') != legacy or row.get('manifest', {}).get('version') != legacy):
            raise ValueError('Complete v1 delegate generation mismatch')
    queens = [r for r in rows if r.get('id') == 'v2_map2_experimental']
    if len(queens) != 1:
        raise ValueError('Exactly one current experimental Queen candidate required')
    queen = queens[0]
    contract = queen.get('boss_contract', {})
    if (queen.get('ok') is not True or queen.get('returned_version') != 'thorn-forest-region-v2'
            or queen.get('production_pool') is not False
            or contract.get('version') != 'forest-queen-weave-golden-v2'
            or contract.get('boss_contract') != 'queen-weave-region-experimental'
            or contract.get('admission') != 'experimental_whole_boss_pending'
            or contract.get('entry_mapping', {}).get('new_high_bridge') is not False):
        raise ValueError('Exact experimental Queen geometry/admission required; no fallback or promotion')
    lifecycle = data.get('exit_lifecycle', {})
    for key in ('registry', 'legacy', 'equality', 'tuning'):
        if (lifecycle.get(key, {}).get('before_release_alive') is not True
                or lifecycle[key].get('after_run_return_alive') is not False):
            raise ValueError('Observed runner-local release required: ' + key)
    apps = [r for r in rows if r.get('id') == 'app_legacy']
    if len(apps) != 2 or {r.get('map') for r in apps} != {1, 2}:
        raise ValueError('Both actual legacy DemoApp entry maps required')
    for row in apps:
        expected_scene = 'res://scenes/bosses/' + ('thorn_guardian' if row['map'] == 1 else 'thorn_queen') + '.tscn'
        if row.get('boss_scene') != expected_scene or not row.get('enemies'):
            raise ValueError('Actual old Boss/enemy scenes required')
        output = row.get('recorded_outputs', {})
        if any(output.get(key, {}).get('version') != legacy for key in
               ('generated_layout', 'stage_generator', 'region_map', 'enemy_layout')):
            raise ValueError('Recorded outputs must all retain v1 identity')
        if row['map'] == 1:
            fallback = row.get('fallback', {})
            if (fallback.get('version') != legacy or not fallback.get('hash_before')
                    or fallback.get('hash_before') != fallback.get('hash_after')
                    or not all(fallback.get(key) is True for key in ('same_state', 'claims_retained', 'actors_retained'))):
                raise ValueError('Actual hash-bound v1 state fallback required')
    if len(rows) != 11:
        raise ValueError('Unexpected/missing native cases')


def validate_recorded_current(data):
    """Keep the original legacy reader intact; current CLI also requires new evidence."""
    if data.get('capture_schema') != 2:
        raise ValueError('Current recorded-layout and canopy evidence schema required')
    cases = data.get('cases', [])
    counts = {name: sum(row.get('id') == name for row in cases)
              for name in ('delegate', 'v2_map2_experimental', 'app_legacy',
                           'recorded_depth_layout', 'canopy_content_contract')}
    if counts != {'delegate': 8, 'v2_map2_experimental': 1, 'app_legacy': 2,
                  'recorded_depth_layout': 2, 'canopy_content_contract': 1} or len(cases) != 14:
        raise ValueError('Exact old eleven and new three cases required; no ignored rows')
    # Original reader deliberately rejects anything beyond its eleven cases.
    # Feed that exact domain, then independently require every new row below.
    legacy = dict(data)
    legacy['cases'] = [row for row in cases if row.get('id') in
                       ('delegate', 'v2_map2_experimental', 'app_legacy')]
    validate(legacy)
    fixtures = {
        'v7_root00_map2.json': '7c61e9c844c36d021630ae6614d5521b602fb49d8c43c17bcfe6e66e5b2499fd',
        'v9_root00_map2_before_north.json': '843c85d5be23f04a340e0f8d604af48be7fa42c8c079b462112e33316bfecca6',
    }
    rows = [row for row in data.get('cases', []) if row.get('id') == 'recorded_depth_layout']
    if len(rows) != 2 or {row.get('fixture') for row in rows} != set(fixtures):
        raise ValueError('Both actual recorded v7/v9 layouts required')
    for row in rows:
        path = ROOT / 'tests/fixtures/forest_recorded_layouts' / row['fixture']
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        original = json.loads(path.read_text())
        if (digest != fixtures[row['fixture']] or row.get('fixture_sha256') != digest
                or row.get('original') != original or row.get('rebuilt') != original
                or row.get('boss_resource') != 'res://resources/bosses/thorn_queen_v2.tres'):
            raise ValueError('Actual entire old layout/hash/Boss changed: ' + row['fixture'])
    current = [row for row in data.get('cases', []) if row.get('id') == 'canopy_content_contract']
    if len(current) != 1:
        raise ValueError('One explicit new canopy contract required')
    row = current[0]
    manifest = row.get('manifest', {})
    fixed_path = ROOT / 'tests/fixtures/forest_recorded_layouts/expected_canopy_v10.json'
    if (hashlib.sha256(fixed_path.read_bytes()).hexdigest() != '06b98b7e95ae39ffa23a4dcd6cf6a64d794e51ce5ef50f1048a3b8b6f700686c'
            or json.dumps(manifest, sort_keys=True, allow_nan=False, separators=(',', ':'))
            != json.dumps(json.loads(fixed_path.read_text()), sort_keys=True, allow_nan=False, separators=(',', ':'))
            or manifest.get('region') != 'thorn_forest'
            or manifest.get('version') != 'thorn-forest-region-v2'
            or manifest.get('map_index') != 2
            or manifest.get('seed') != 'version-canopy-current'):
        raise ValueError('Exact fixed native canopy manifest identity/hash/content required')
    expected = {'contract': 'forest-queen-canopy-v3',
                'scene': 'res://scenes/bosses/thorn_queen_canopy.tscn',
                'resource': 'res://resources/bosses/thorn_queen_canopy.tres'}
    if (manifest.get('layout_version') != 'shared-tree-canopy-hunt-v10'
            or manifest.get('boss_content') != expected
            or manifest.get('production_pool') is not False
            or row.get('boss_scene') != expected['scene']
            or row.get('boss_resource') != expected['resource']
            or json.dumps(manifest.get('boss_geometry'), sort_keys=True, allow_nan=False, separators=(',', ':'))
            != json.dumps(row.get('geometry_from_resource'), sort_keys=True, allow_nan=False, separators=(',', ':'))
            or manifest.get('boss_geometry', {}).get('version') != expected['contract']):
        raise ValueError('Exact single-source canopy contract required; no legacy fallback')
    geometry = manifest['boss_geometry']
    platforms = geometry.get('platforms', [])
    if len({item.get('id') for item in platforms}) != len(platforms):
        raise ValueError('Unique physical canopy supports required')
    supports = {item['id']: item['rect'] for item in platforms}
    for key, support in (('safe_return', 'central_rib'), ('reward_position', 'floor')):
        point = geometry.get(key, [])
        rect = supports.get(support, [])
        if len(point) != 2 or len(rect) != 4:
            raise ValueError('Explicit physical entry/reward support required')
        if not all(type(value) in (int, float) and math.isfinite(value) for value in point + rect):
            raise ValueError('Finite physical entry/reward geometry required')
        x, y = point
        if (abs(y + 18 - rect[1]) > .001 or x - 12 < rect[0] - .001
                or x + 12 > rect[0] + rect[2] + .001):
            raise ValueError('Full Player body is unsupported: ' + key)
        for item in platforms:
            rx, ry, width, height = item['rect']
            if (min(x + 12, rx + width) - max(x - 12, rx) > .001
                    and min(y + 18, ry + height) - max(y - 18, ry) > .001):
                raise ValueError('Entry/reward body intersects solid terrain: ' + key)



def validate_current(data):
    """Exact original recorded rows plus independently expected v11/default rows."""
    if data.get('capture_schema') != 3:
        raise ValueError('Explicit current expedition capture schema required')
    if type(data.get('assertions')) is not int or data['assertions'] < 148:
        raise ValueError('Original 126 and at least 22 added native expedition assertions required')
    cases = data.get('cases', [])
    rows = [row for row in cases if row.get('id') == 'expedition_content_contract']
    if len(cases) != 16 or len(rows) != 2 or {row.get('map') for row in rows} != {1, 2}:
        raise ValueError('Exact original fourteen and two expedition rows required')
    recorded = dict(data)
    recorded['capture_schema'] = 2
    recorded['cases'] = [row for row in cases if row.get('id') != 'expedition_content_contract']
    validate_recorded_current(recorded)
    for row in rows:
        index = row['map']
        m = row.get('manifest', {})
        boss = 'rootbell_guardian_v2' if index == 1 else 'thorn_queen_canopy'
        if (type(index) is not int or m.get('version') != 'thorn-forest-region-v2'
                or m.get('layout_version') != 'forest-expedition-airborne-v11'
                or m.get('region') != 'thorn_forest' or type(m.get('map_index')) is not int
                or m['map_index'] != index or m.get('seed') != f'version-expedition-map-{index}'
                or m.get('production_pool') is not False or m.get('requires') != ['grapple']
                or not re.fullmatch(r'[0-9a-f]{64}', str(m.get('manifest_hash', '')))
                or row.get('complete_output_equal') is not True or row.get('default_manifest') != m
                or row.get('boss_scene') != f'res://scenes/bosses/{boss}.tscn'
                or row.get('boss_resource') != f'res://resources/bosses/{boss}.tres'):
            raise ValueError('Exact independently expected expedition/default identity required')
        if index == 2:
            from run_forest_depth_campaign_boss import validate_map2_boss_identity
            validate_map2_boss_identity(m)
        expected = {'relabeled/forest-expedition-airborne-v999',
                    'relabeled/shared-tree-canopy-hunt-v10', 'future_generation', 'corrupt_hash'}
        if index == 2:
            expected |= {'boss/scene', 'boss/resource', 'boss/contract', 'missing_boss'}
        negatives = row.get('negative_cases', [])
        if (len(negatives) != len(expected) or {n.get('kind') for n in negatives} != expected
                or not all(n.get('rejected') is True for n in negatives)):
            raise ValueError('Every typed current-layout negative must actually reject')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', default='build/forest_depth/versions/native')
    parser.add_argument('--verbose', action='store_true', help='Preserve engine verbose exit diagnostics; strict guards unchanged')
    args = parser.parse_args()
    out = (ROOT / args.output_dir).resolve()
    if not out.is_relative_to(ROOT / 'build/forest_depth/versions') or out.exists():
        parser.error('Fresh output below build/forest_depth/versions required')
    out.mkdir(parents=True)
    before = level_formal.source_files()
    verifier = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in (Path(__file__).resolve(), ROOT / 'tests/forest_depth_version_runner.gd')}
    receipt = {'scope': 'Runtime registry/legacy compatibility, NOT v2 gameplay admission',
               'base_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
               'source_before': before, 'verifier_before': verifier, 'passed': False}
    snapshot = ROOT / 'build/snapshot-receipt.json'
    if snapshot.is_file():
        receipt['runtime_snapshot_receipt_sha256'] = hashlib.sha256(snapshot.read_bytes()).hexdigest()
    started = time.monotonic()
    try:
        with (out / 'import.log').open('w') as log, contextlib.redirect_stdout(log):
            import_text = run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
        if re.search(r'(^|\n)(?:SCRIPT )?ERROR:', import_text):
            raise RuntimeError('Unexpected native import ERROR')
        with (out / 'native.log').open('w') as log, contextlib.redirect_stdout(log):
            text = run_engine((['--verbose'] if args.verbose else []) + ['--headless', '--fixed-fps', '60', '--path', '.', '--script',
                'tests/forest_depth_version_runner.gd', '--',
                '--output=res://' + str((out / 'capture.json').relative_to(ROOT))], 90)
        if not re.search(r'^FOREST DEPTH VERSIONS: [1-9]\d* assertions, 0 failures$', text, re.M):
            raise RuntimeError('Complete native version result missing')
        if re.search(r'(^|\n)(?:SCRIPT )?ERROR:', text):
            raise RuntimeError('Unexpected native engine ERROR')
        validate_current(json.loads((out / 'capture.json').read_text()))
        receipt['passed'] = True
    finally:
        receipt['source_after'] = level_formal.source_files()
        receipt['verifier_after'] = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in verifier}
        receipt['source_guard'] = before == receipt['source_after'] and verifier == receipt['verifier_after']
        receipt['elapsed_seconds'] = time.monotonic() - started
        receipt['logs'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                           for p in out.iterdir() if p.is_file()}
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        if not receipt['source_guard']:
            raise RuntimeError('Source changed during native version check')
    print('PASS: forest depth runtime registry and actual legacy entry/state; v2 gameplay NOT covered')


if __name__ == '__main__':
    main()
