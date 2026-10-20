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


def validate_latest(data):
    """Preserve exact old readers; require additional independently expected v12."""
    if data.get('capture_schema') != 4:
        raise ValueError('Woven-trunk version capture schema required')
    if type(data.get('assertions')) is not int or data['assertions'] < 212:
        raise ValueError('All historical and added v12/native replay assertions required')
    cases = data.get('cases', [])
    rows = [r for r in cases if r.get('id') == 'vertical_content_contract']
    if len(cases) != 20 or len(rows) != 2 or {r.get('map') for r in rows} != {1, 2}:
        raise ValueError('Exact historical sixteen, two actual final v11 fixtures and two v12 cases required')
    recorded = dict(data)
    recorded['capture_schema'] = 3
    recorded['cases'] = [r for r in cases if r.get('id') not in {'vertical_content_contract', 'recorded_expedition_layout'}]
    validate_current(recorded)
    actual_v11 = [r for r in cases if r.get('id') == 'recorded_expedition_layout']
    fixture_hashes = {1:'ddd26758ae3d968927a16bfaa94c89366e00a443120b6441fc2a285df615a2ff',
                      2:'85e7ef09f8fbc59a4f0f5f70d2286200bb9e86bb55db6fcc029a08847949cf72'}
    if len(actual_v11) != 2 or {r.get('map') for r in actual_v11} != {1, 2}:
        raise ValueError('Both source-bound original final v11 map fixtures required')
    for row in actual_v11:
        index = row['map']
        if type(index) is not int:
            raise ValueError('Typed original final v11 map identity required')
        p = ROOT / f'tests/fixtures/forest_recorded_layouts/v11_corpus_map{index}.json'
        original = json.loads(p.read_text())
        if (hashlib.sha256(p.read_bytes()).hexdigest() != fixture_hashes[index]
                or row.get('fixture_sha256') != fixture_hashes[index]
                or row.get('original') != original or row.get('rebuilt') != original
                or row.get('current_tuning_mutation_rejected') is not True):
            raise ValueError('Entire final v11 original hash/geometry must exactly replay')
    expected_flights = ['root_spiral_flight', 'lower_fork_flight',
        'thorn_mouth_flight', 'middle_fork_flight', 'broken_arch_flight',
        'upper_spiral_flight', 'canopy_fork_flight']
    expected_hangs = ['root_spiral__rest_ring', 'thorn_mouth__rest_ring',
        'thorn_retry_low_ring', 'thorn_retry_high_ring', 'thorn_retry_exit_ring',
        'upper_spiral__rest_ring']
    for row in rows:
        index = row['map']
        m = row.get('manifest', {})
        boss = 'rootbell_guardian_v2' if index == 1 else 'thorn_queen_canopy'
        if (type(index) is not int or m.get('layout_version') != 'forest-woven-trunk-v12'
                or m.get('version') != 'thorn-forest-region-v2'
                or m.get('region') != 'thorn_forest' or type(m.get('map_index')) is not int
                or m['map_index'] != index or m.get('seed') != f'version-woven-map-{index}'
                or m.get('production_pool') is not False or m.get('requires') != ['grapple']
                or not re.fullmatch(r'[0-9a-f]{64}', str(m.get('manifest_hash', '')))
                or row.get('complete_output_equal') is not True or row.get('default_manifest') != m
                or row.get('boss_scene') != f'res://scenes/bosses/{boss}.tscn'
                or row.get('boss_resource') != f'res://resources/bosses/{boss}.tres'):
            raise ValueError('Exact explicit v12/default identity and Boss pair required')
        if m.get('player_tuning_hash') != hashlib.sha256((ROOT / 'config/player_tuning.json').read_bytes()).hexdigest():
            raise ValueError('Actual current v12 tuning fingerprint required')
        edges = [e for e in m.get('connections', []) if e.get('id') in expected_flights]
        if (len(edges) != 7 or [e['id'] for e in edges] != expected_flights
                or row.get('primary_flights') != expected_flights
                or any(e.get('kind') != 'airborne_chain'
                    or e.get('continuous_airborne') is not True
                    or e.get('optional_lower_alternative') is not False
                    or not isinstance(e.get('action_program'), list)
                    or len(e['action_program']) < 2
                    or e['id'] not in m.get('routes', {}).get('fast', []) for e in edges)):
            raise ValueError('Seven actual distinct primary compound edges required; not playability proof')
        hangs = [a.get('id') for a in m.get('hook_anchors', []) if a.get('hang_enabled') is True]
        if hangs != expected_hangs or row.get('hang_ids') != expected_hangs:
            raise ValueError('Six exact declared hanging objects required')
        rest_ids = [a['id'] for a in m['hook_anchors'] if a.get('hang_enabled') is True
                    and a.get('scene_kind') == 'hanging_growth_ring']
        if rest_ids != ['root_spiral__rest_ring', 'thorn_mouth__rest_ring', 'upper_spiral__rest_ring']:
            raise ValueError('Three original rest-ring declarations must remain distinct')
        recovery_ids = [a['id'] for a in m['hook_anchors'] if a.get('hang_enabled') is True
            and a.get('scene_kind') == 'hanging_root_ring'
            and a.get('tether_host_support_id') == 'thorn_mouth__entry'
            and a.get('recovery_role') == 'deep_catch_return_to_thorn_mouth']
        if recovery_ids != ['thorn_retry_low_ring', 'thorn_retry_high_ring', 'thorn_retry_exit_ring']:
            raise ValueError('Three recovery stages must share the real unchanged one-way host')
        rests = [e for e in m['connections'] if e.get('id') == 'root_spiral_rest_flight']
        if (len(rests) != 1 or rests[0].get('kind') != 'hanging_chain'
                or rests[0].get('a') != 'root_spiral_mouth' or rests[0].get('b') != 'root_spiral_crown'
                or rests[0].get('rest_anchor_id') != 'root_spiral__rest_ring'
                or rests[0].get('hang_observation_frames') != 18
                or not isinstance(rests[0].get('action_program'), list)
                or len(rests[0]['action_program']) < 2):
            raise ValueError('Exact early hanging alternative and declared observation contract required')
        routes = m.get('routes', {})
        if ('root_spiral_rest_flight' in routes.get('fast', [])
                or 'root_spiral_flight' not in routes.get('fast', [])
                or any('root_spiral_rest_flight' not in routes.get(key, [])
                    or 'root_spiral_flight' in routes.get(key, []) for key in ('growth', 'high_return'))):
            raise ValueError('Growth/high routes must actually choose the alternate same-crown path')
        rise = m.get('vertical_contract', {}).get('primary_rise')
        if (type(rise) not in (int, float) or rise != 1528.0
                or m['spawn'][1] - edges[-1]['landing'][1] != 1528.0):
            raise ValueError('Primary rise must match actual starting and final banks')
        hosts = [p for p in m['platforms'] if p.get('id') == 'thorn_mouth__entry']
        recovery = m.get('expedition_recovery', {})
        if (len(hosts) != 1 or hosts[0].get('one_way') is not True
                or recovery.get('support') != 'thorn_mouth__recovery'
                or recovery.get('mouth') != 'thorn_mouth_mouth'):
            raise ValueError('Recovery must use the legitimate bough to return to SAME thorn mouth')
        if index == 2:
            from run_forest_depth_campaign_boss import validate_map2_boss_identity
            validate_map2_boss_identity(m)
        expected = {'relabeled/forest-woven-trunk-v999',
                    'relabeled/forest-expedition-airborne-v11', 'missing_hang', 'missing_flight', 'historical_tuning',
                    'missing_rest_choice', 'wrong_recovery_mouth'}
        negatives = row.get('negative_cases', [])
        if (len(negatives) != 7 or {n.get('kind') for n in negatives} != expected
                or not all(n.get('rejected') is True for n in negatives)):
            raise ValueError('Every typed v12 version/semantic negative must reject')

def validate_interwoven(data):
    """Additional v13 layer; all original v1-v12 readers remain unchanged."""
    if data.get('capture_schema') != 5:
        raise ValueError('Interwoven version capture schema 5 required')
    if type(data.get('assertions')) is not int or data['assertions'] < 290:
        raise ValueError('All historical assertions plus both complete v13 contracts required')
    cases = data.get('cases', [])
    rows = [r for r in cases if r.get('id') == 'interwoven_content_contract']
    if len(cases) != 22 or len(rows) != 2 or {r.get('map') for r in rows} != {1, 2}:
        raise ValueError('Exact twenty historical cases and both v13 maps required')
    historical = dict(data)
    historical['capture_schema'] = 4
    historical['cases'] = [r for r in cases if r.get('id') != 'interwoven_content_contract']
    validate_latest(historical)
    edges_expected = ['root_bay_approach', 'root_bay_lesson_flight', 'inner_hollow_HH',
        'upper_root_RH', 'upper_root_crown_H', 'inner_thorn_HR',
        'crown_inner_return', 'inner_bay_return']
    supports_expected = ['interwoven_root_bridge', 'interwoven_lesson_bough',
        'interwoven_inner_bough', 'interwoven_upper_launch']
    negative_expected = {'relabel_v12', 'relabel_future', 'missing_support', 'missing_branch',
        'wrong_route', 'wrong_return', 'hang_refill', 'historical_tuning',
        'capability/double_jump', 'capability/wall_climb',
        'capability/weapon_evolution_1', 'capability/weapon_evolution_2'}
    for row in rows:
        index = row['map']
        m = row.get('manifest', {})
        boss = 'rootbell_guardian_v2' if index == 1 else 'thorn_queen_canopy'
        if (type(index) is not int or m.get('map_index') != index
                or type(m.get('map_index')) is not int
                or m.get('layout_version') != 'forest-interwoven-canopy-v13'
                or m.get('version') != 'thorn-forest-region-v2'
                or m.get('region') != 'thorn_forest'
                or m.get('seed') != f'version-interwoven-map-{index}'
                or m.get('production_pool') is not False or m.get('requires') != ['grapple']
                or not re.fullmatch(r'[0-9a-f]{64}', str(m.get('manifest_hash', '')))
                or m.get('player_tuning_hash') != hashlib.sha256((ROOT / 'config/player_tuning.json').read_bytes()).hexdigest()
                or row.get('complete_output_equal') is not True
                or row.get('default_manifest') != m or row.get('frozen_manifest') != m
                or row.get('boss_scene') != f'res://scenes/bosses/{boss}.tscn'
                or row.get('boss_resource') != f'res://resources/bosses/{boss}.tres'):
            raise ValueError('Exact v13 pinned/frozen registry identity and Boss pair required')
        edges = [e for e in m.get('connections', []) if e.get('id') in edges_expected]
        supports = [p for p in m.get('platforms', []) if p.get('id') in supports_expected]
        if ([e['id'] for e in edges] != edges_expected or row.get('added_edges') != edges_expected
                or [p['id'] for p in supports] != supports_expected
                or row.get('added_supports') != supports_expected
                or any(p.get('one_way') is not True or len(p.get('rect', [])) != 4
                    or type(p['rect'][2]) not in (int, float) or p['rect'][2] < 100 for p in supports)):
            raise ValueError('Exact actual added v13 approach, supports, branches and returns required')
        entry = m.get('entry_contract', {})
        contract = m.get('interwoven_contract', {})
        if (entry.get('selected') != 'root_bay' or entry.get('optional_skill_route') != 'root_spiral'
                or contract.get('held_hang_resets_focus') is not False
                or contract.get('splits', [])[:2] != ['arrival', 'interwoven_inner']
                or contract.get('rejoins', [])[:2] != ['root_spiral_crown', 'thorn_mouth_mouth']):
            raise ValueError('Explicit short grounded entry, early split/rejoin and no hanging refill required')
        branch = m.get('choices', {}).get('interwoven_first_branch')
        if branch not in ('inner', 'upper') or m.get('streams', {}).get('interwoven') != 'forest_interwoven':
            raise ValueError('Finite v13 branch choice and isolated RNG stream required')
        inner = ['root_bay_approach', 'root_bay_lesson_flight', 'inner_hollow_HH', 'inner_thorn_HR']
        upper = ['root_bay_approach', 'root_bay_lesson_flight', 'inner_hollow_HH', 'upper_root_RH', 'upper_root_crown_H']
        fast, growth = (inner, upper) if branch == 'inner' else (upper, inner)
        routes = m.get('routes', {})
        if (routes.get('fast', [])[:len(fast)] != fast or routes.get('growth', [])[:len(growth)] != growth
                or 'root_spiral_rest_flight' not in routes.get('high_return', [])
                or 'root_bay_approach' in routes.get('high_return', [])):
            raise ValueError('Actual route prefixes must select distinct early physical paths; optional skill line retained')
        validate_interwoven_expansion(m)
        negatives = row.get('negative_cases', [])
        if (len(negatives) != 12 or {n.get('kind') for n in negatives} != negative_expected
                or not all(n.get('rejected') is True for n in negatives)):
            raise ValueError('All typed v13 semantic and ungranted-capability negatives must reject')


def validate_interwoven_expansion(m):
    c = m.get('interwoven_contract', {})
    if (c.get('splits') != ['arrival', 'interwoven_inner', 'broken_arch_crown']
            or c.get('rejoins') != ['root_spiral_crown', 'thorn_mouth_mouth', 'interwoven_root_landing', 'M']):
        raise ValueError('Exact expanded v13 split/rejoin identities required')
    def exact_row(category, identity):
        rows = [r for r in m.get(category, []) if r.get('id') == identity]
        if len(rows) != 1:
            raise ValueError('Exactly one actual v13 object required: ' + identity)
        return rows[0]
    node = exact_row('areas', 'interwoven_root_landing')
    ascent = exact_row('connections', 'interwoven_deep_ascent')
    walk = exact_row('connections', 'interwoven_root_to_D')
    support = exact_row('platforms', 'hollow__inner_root')
    if node.get('position') != [400., 802.] or node.get('role') != 'junction':
        raise ValueError('Actual v13 landing node must describe root lip')
    if (ascent.get('a') != 'interwoven_deep_basin' or ascent.get('b') != 'interwoven_root_landing'
            or ascent.get('landing') != [400., 802.] or ascent.get('landing_support_id') != 'hollow__inner_root'):
        raise ValueError('Actual ascent must land at the root lip, not relabeled D')
    if (walk.get('a') != 'interwoven_root_landing' or walk.get('b') != 'D'
            or walk.get('kind') != 'walk' or walk.get('path') != [[400., 802.], [720., 802.]]
            or support.get('rect') != [290., 820., 500., 40.] or support.get('one_way') is not False):
        raise ValueError('Exact lip-to-D walk and real shared root support required')
    camps = [e for e in m.get('connections', []) if e.get('id') == 'interwoven_root_to_camp']
    at_lip = m.get('merchant_position') == [360., 802.]
    if at_lip:
        if (len(camps) != 1 or camps[0].get('a') != 'interwoven_root_landing'
                or camps[0].get('b') != 'camp' or camps[0].get('kind') != 'walk'
                or camps[0].get('path') != [[400., 802.], [360., 802.]]):
            raise ValueError('Actual merchant360 requires exact camp walk')
    elif camps:
        raise ValueError('Camp lip edge forbidden when merchant is elsewhere')
    choices = m.get('choices', {})
    west = choices.get('west_reward')
    if (type(west) is not bool
            or choices.get('interwoven_midroute') != ('upper_west_reward_existing_order' if west else 'deep_root_camp_first')
            or choices.get('interwoven_midroute_basis') != 'actual_existing_west_reward; no additional random draw'):
        raise ValueError('Exact existing seed-west policy required')
    growth = m.get('routes', {}).get('growth', [])
    descent, ascent_id = 'interwoven_deep_descent', 'interwoven_deep_ascent'
    if west:
        if descent in growth or ascent_id in growth:
            raise ValueError('West-reward growth must preserve existing upper order')
    elif (descent not in growth or ascent_id not in growth or 'broken_arch_flight' not in growth
            or growth.index(descent) + 1 != growth.index(ascent_id)
            or growth.index('broken_arch_flight') >= growth.index(descent)):
        raise ValueError('Non-west growth requires real contiguous deep route after broken arch')


def validate_fruit_version(data):
    """Schema6 adds candidate/default v14; schema5's full old reader is retained."""
    if data.get('capture_schema') != 6:
        raise ValueError('Fruit version capture schema6 required')
    cases = data.get('cases', [])
    rows = [row for row in cases if row.get('id') == 'fruit_candidate_and_public_layout']
    if len(cases) != 24 or len(rows) != 2 or {row.get('map') for row in rows} != {1, 2}:
        raise ValueError('All twenty-two historical cases plus both v14 maps required')
    previous = dict(data)
    previous['capture_schema'] = 5
    previous['cases'] = [row for row in cases if row.get('id') != 'fruit_candidate_and_public_layout']
    validate_interwoven(previous)
    from run_forest_depth_region import validate_fruit_presentation
    source = (ROOT / 'tests/forest_depth_version_runner.gd').read_text()
    expected_default = re.search(r'^const EXPECTED_PUBLIC_LAYOUT := "([^"]+)"$', source, re.M).group(1)
    if expected_default not in ('forest-interwoven-canopy-v13', 'forest-fruit-routes-v14'):
        raise ValueError('Independently selected known public layout required')
    for row in rows:
        index = row['map']
        manifest = row.get('candidate_manifest', {})
        current = row.get('default_manifest', {})
        if (manifest.get('version') != 'thorn-forest-region-v2'
                or manifest.get('layout_version') != 'forest-fruit-routes-v14'
                or manifest.get('map_index') != index
                or manifest.get('seed') != f'version-fruit-map-{index}'
                or manifest.get('requires') != ['grapple']
                or manifest.get('production_pool') is not False
                or row.get('dedicated_complete_equal') is not True
                or row.get('expected_public_layout') != expected_default
                or current.get('layout_version') != expected_default
                or current.get('map_index') != index
                or current.get('seed') != manifest.get('seed')
                or validate_fruit_presentation(manifest)):
            raise ValueError('Complete registered v14 candidate, typed defaults and exact presentation required')
        if expected_default == 'forest-fruit-routes-v14' and current != manifest:
            raise ValueError('New public default must equal the complete explicit v14 output')



PHASES = ('data', 'world')
PHASE_SCRIPTS = {'data': 'tests/forest_depth_version_runner.gd',
                 'world': 'tests/forest_depth_version_world_runner.gd'}
PHASE_COUNTS = {'data': 280, 'world': 47}
# Independently frozen complete original ledgers, preserving duplicate labels too.
PHASE_LABEL_SHA256 = {
    'data': '2a3cd81345d66c75bf6af12f4fa5390b3ce854fb860ebb7a86877a0dd6d5081d',
    'world': '8f2e7fd257fd6eed1b63887317f3f7587fbeeda2e2cb6ae071cc1c9884622c41',
}
VERIFIER_PATHS = (str(Path(__file__).resolve().relative_to(ROOT)), *PHASE_SCRIPTS.values(),
                  'tests/forest_depth_version_app_case.gd', 'tools/test_forest_depth_versions.py')


def file_sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def verifier_identity():
    return {name: file_sha(ROOT / name) for name in VERIFIER_PATHS}


def case_signature(row):
    if not isinstance(row, dict):
        raise ValueError('Native case must be a dictionary')
    for name in ('map',):
        if name in row and type(row[name]) is not int:
            raise ValueError('Typed case map required')
    return (row.get('id'), row.get('map'), row.get('seed'), row.get('fixture'))


def expected_case_signatures(phase):
    if phase == 'world':
        return [('app_legacy', 1, None, None), ('app_legacy', 2, None, None)]
    return [('delegate', index, f'version-contract-{seed:02d}/thorn_forest/map_{index}', None)
            for seed in range(4) for index in (1, 2)] + [
        ('v2_map2_experimental', None, None, None),
        ('recorded_depth_layout', None, None, 'v7_root00_map2.json'),
        ('recorded_depth_layout', None, None, 'v9_root00_map2_before_north.json'),
        ('canopy_content_contract', None, None, None),
        *[(name, index, None, None) for name in (
            'expedition_content_contract', 'vertical_content_contract',
            'recorded_expedition_layout', 'interwoven_content_contract',
            'fruit_candidate_and_public_layout') for index in (1, 2)],
    ]



def same_native_identity(left, right):
    """Native identity is flat: strings and exact int PID, never equal floats/bools."""
    return (type(left) is dict and type(right) is dict and left.keys() == right.keys()
            and all(type(left[key]) is type(right[key]) and left[key] == right[key] for key in left))


def validate_phase(phase, data, raw, run_id, sources):
    if phase not in PHASES or not isinstance(run_id, str) or not re.fullmatch(r'[0-9a-f]{32}', run_id):
        raise ValueError('Explicit current native run identity required')
    starts = re.findall(r'^FOREST VERSION PHASE: (.+)$', raw, re.M)
    if len(starts) != 1:
        raise ValueError('Missing or ambiguous native phase identity')
    identity = json.loads(starts[0])
    expected = {'phase': phase, 'run_id': run_id, 'script': 'res://' + PHASE_SCRIPTS[phase],
                'script_sha256': sources[PHASE_SCRIPTS[phase]]}
    if (not isinstance(identity, dict) or set(identity) != set(expected) | {'engine_pid'}
            or any(identity.get(k) != v for k, v in expected.items())
            or type(identity.get('engine_pid')) is not int or identity['engine_pid'] <= 0
            or not same_native_identity(data.get('identity'), identity)):
        raise ValueError('Stale, mixed-source or foreign native identity')
    if (type(data.get('capture_schema')) is not int or data['capture_schema'] != 6
            or type(data.get('assertions')) is not int or data['assertions'] != PHASE_COUNTS[phase]
            or type(data.get('failures')) is not int or data['failures'] != 0):
        raise ValueError('Exact original phase assertions/schema required')
    engine = data.get('engine')
    engine_fields = {'major': int, 'minor': int, 'patch': int, 'hex': int, 'timestamp': int,
                     'status': str, 'build': str, 'hash': str, 'string': str}
    if (type(engine) is not dict or set(engine) != set(engine_fields)
            or any(type(engine[key]) is not kind for key, kind in engine_fields.items())
            or any(not engine[key] for key in ('status', 'build', 'hash', 'string'))):
        raise ValueError('Complete typed actual Engine.get_version_info identity required')
    checks = data.get('checks')
    if (not isinstance(checks, list) or len(checks) != PHASE_COUNTS[phase]
            or any(not isinstance(r, dict) or set(r) != {'label', 'passed'}
                   or not isinstance(r['label'], str) or type(r['passed']) is not bool
                   or not r['passed'] for r in checks)):
        raise ValueError('Complete original typed native assertion ledger required')
    labels = json.dumps([r['label'] for r in checks], ensure_ascii=False, separators=(',', ':')).encode()
    if hashlib.sha256(labels).hexdigest() != PHASE_LABEL_SHA256[phase]:
        raise ValueError('Original native labels changed, omitted, duplicated or reordered')
    if (not isinstance(data.get('cases'), list)
            or [case_signature(r) for r in data['cases']] != expected_case_signatures(phase)):
        raise ValueError('Complete original phase case identities/order required')
    summary = f'FOREST DEPTH VERSION {phase.upper()}: {PHASE_COUNTS[phase]} assertions, 0 failures'
    if len(re.findall('^' + re.escape(summary) + '$', raw, re.M)) != 1:
        raise ValueError('Missing or ambiguous complete native phase summary')
    if re.search(r'(^|\n)(?:SCRIPT )?ERROR:|ObjectDB.*leaked|resources? still in use at exit', raw):
        raise ValueError('Native error or teardown failure cannot be aggregated')
    return identity


def aggregate(reports, receipts, run_id, sources, directory):
    """Bind both fresh native consumers, then restore the entire original order."""
    if list(reports) != list(PHASES) or list(receipts) != list(PHASES):
        raise ValueError('Both native consumers in original phase order required')
    pids, prior_end = [], 0.0
    for ordinal, phase in enumerate(PHASES):
        receipt = receipts[phase]
        if (receipt.get('status') != 'passed' or type(receipt.get('exit_code')) is not int
                or receipt['exit_code'] != 0 or receipt.get('phase') != phase
                or type(receipt.get('sequence')) is not int or receipt['sequence'] != ordinal or receipt.get('run_id') != run_id
                or receipt.get('source_sha256') != sources):
            raise ValueError('Missing, stale or failed actual native receipt')
        raw_path, report_path = directory / f'{phase}.log', directory / f'{phase}.json'
        original_args = ['--headless', '--fixed-fps', '60', '--path', '.', '--script',
                         PHASE_SCRIPTS[phase], '--',
                         '--output=res://' + str(report_path.relative_to(ROOT)), '--run-id=' + run_id]
        prefix = ['bash', str(ROOT / 'tools/godot.sh')]
        if receipt.get('argv') not in (prefix + original_args, prefix + ['--verbose'] + original_args):
            raise ValueError('Exact original native argv required; successful phase cannot be a failure probe')
        if (receipt.get('rawlog') != str(raw_path.relative_to(ROOT))
                or receipt.get('report') != str(report_path.relative_to(ROOT))
                or file_sha(raw_path) != receipt.get('rawlog_sha256')
                or file_sha(report_path) != receipt.get('report_sha256')):
            raise ValueError('Original native raw/report identity changed')
        # Caller-provided report cannot substitute for the exact fresh native file.
        if json.dumps(json.loads(report_path.read_text()), sort_keys=True, allow_nan=False) != json.dumps(reports[phase], sort_keys=True, allow_nan=False):
            raise ValueError('In-memory report differs from actual native bytes')
        identity = validate_phase(phase, reports[phase], raw_path.read_text(), run_id, sources)
        if (not same_native_identity(identity, receipt.get('native_identity')) or type(receipt.get('engine_pid')) is not int
                or receipt['engine_pid'] != identity['engine_pid']):
            raise ValueError('Actual native process identity differs across evidence channels')
        pids.append(identity['engine_pid'])
        start, end = receipt.get('shared_elapsed_start'), receipt.get('shared_elapsed_end')
        remaining = receipt.get('timeout_seconds')
        duration = receipt.get('duration_seconds')
        if (any(type(v) not in (int, float) or not math.isfinite(v) for v in (start, end, remaining, duration))
                or not 0 <= prior_end <= start < end <= 90
                or remaining <= 0 or abs(start + remaining - 90) > 1e-5
                or duration <= 0 or abs(duration - (end - start)) > 1e-6):
            raise ValueError('Original shared 90-second budget or actual phase ordering violated')
        prior_end = end
    if len(set(pids)) != 2:
        raise ValueError('Data and App require two distinct native processes')
    data, world = reports['data'], reports['world']
    if not same_native_identity(data.get('engine'), world.get('engine')):
        raise ValueError('Native engine versions differ')
    result = {'capture_schema': 6,
              'scope': 'Two independent native consumers, data then actual App. Original 276+47+4 ledger preserved; not one native process or v2 gameplay admission.',
              'assertions': 327, 'failures': 0, 'engine': data['engine'],
              'cases': data['cases'] + world['cases'],
              'checks': data['checks'][:-4] + world['checks'] + data['checks'][-4:],
              'exit_lifecycle': data['exit_lifecycle'], 'run_id': run_id,
              'native_consumer_count': 2, 'phases': receipts, 'verifier_sources': sources}
    # Keep every existing schema6→schema5→... historical/typed/Boss/fruit validator.
    validate_fruit_version(result)
    return result


def run_phase(phase, directory, run_id, native_start, deadline, sources, verbose, failure_probe):
    start = time.monotonic()
    remaining = deadline - start
    if remaining <= 0:
        raise RuntimeError('Original shared90 native budget exhausted')
    report_path, raw_path = directory / f'{phase}.json', directory / f'{phase}.log'
    if report_path.exists() or raw_path.exists():
        raise RuntimeError('Fresh phase paths required; never reuse or overwrite native evidence')
    argv = (['--verbose'] if verbose else []) + ['--headless', '--fixed-fps', '60', '--path', '.',
            '--script', PHASE_SCRIPTS[phase], '--',
            '--output=res://' + str(report_path.relative_to(ROOT)), '--run-id=' + run_id]
    if phase == 'world' and failure_probe:
        argv.append('--failure-probe')
    receipt = {'phase': phase, 'sequence': PHASES.index(phase), 'run_id': run_id,
               'argv': ['bash', str(ROOT / 'tools/godot.sh'), *argv],
               'timeout_seconds': remaining, 'shared_elapsed_start': start - native_start,
               'source_sha256': sources, 'status': 'failed', 'exit_code': None,
               'rawlog': str(raw_path.relative_to(ROOT)), 'report': str(report_path.relative_to(ROOT))}
    try:
        with raw_path.open('x') as log, contextlib.redirect_stdout(log):
            text = run_engine(argv, remaining)
        receipt['exit_code'] = 0
        data = json.loads(report_path.read_text())
        identity = validate_phase(phase, data, text, run_id, sources)
        receipt.update(status='passed', native_identity=identity, engine_pid=identity['engine_pid'])
        return data, receipt
    except BaseException as error:
        receipt['error'] = type(error).__name__ + ': ' + str(error)
        match = re.fullmatch(r'Godot returned (-?\d+)', str(error))
        if match:
            receipt['exit_code'] = int(match[1])
        raise
    finally:
        receipt['shared_elapsed_end'] = time.monotonic() - native_start
        receipt['duration_seconds'] = receipt['shared_elapsed_end'] - receipt['shared_elapsed_start']
        if raw_path.is_file():
            receipt['rawlog_sha256'] = file_sha(raw_path)
            starts = re.findall(r'^FOREST VERSION PHASE: (.+)$', raw_path.read_text(), re.M)
            if len(starts) == 1:
                receipt['native_identity'] = json.loads(starts[0])
                receipt['engine_pid'] = receipt['native_identity']['engine_pid']
        if report_path.is_file():
            receipt['report_sha256'] = file_sha(report_path)
        (directory / f'{phase}-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')


def main():
    import uuid
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', default='build/forest_depth/versions/native')
    parser.add_argument('--verbose', action='store_true', help='Preserve engine verbose exit diagnostics; strict guards unchanged')
    parser.add_argument('--failure-probe', action='store_true', help='Real final-world check fails after all original business checks; never produces successful aggregate')
    args = parser.parse_args()
    out = (ROOT / args.output_dir).resolve()
    if not out.is_relative_to(ROOT / 'build/forest_depth/versions') or out.exists():
        parser.error('Fresh output below build/forest_depth/versions required')
    out.mkdir(parents=True)
    before = level_formal.source_files(extra_paths=VERIFIER_PATHS)
    verifier = verifier_identity()
    run_id = uuid.uuid4().hex
    receipt = {'scope': 'Two independent native consumers; all original runtime registry/legacy compatibility checks. NOT one-native or v2 gameplay admission',
               'base_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
               'source_before': before, 'verifier_before': verifier, 'run_id': run_id,
               'original_shared_native_cap_seconds': 90, 'original_import_cap_seconds': 90,
               'native_consumer_count': 2, 'passed': False, 'phases': {}}
    snapshot = ROOT / 'build/snapshot-receipt.json'
    if snapshot.is_file():
        receipt['runtime_snapshot_receipt_sha256'] = file_sha(snapshot)
    started = time.monotonic()
    try:
        with (out / 'import.log').open('x') as log, contextlib.redirect_stdout(log):
            import_text = run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
        if re.search(r'(^|\n)(?:SCRIPT )?ERROR:', import_text):
            raise RuntimeError('Unexpected native import ERROR')
        native_start = time.monotonic()
        deadline = native_start + 90
        reports, phases = {}, {}
        for phase in PHASES:
            reports[phase], phases[phase] = run_phase(phase, out, run_id, native_start, deadline, verifier, args.verbose, args.failure_probe)
            receipt['phases'] = phases
        if time.monotonic() > deadline:
            raise RuntimeError('Original shared90 native budget exceeded')
        receipt['native_elapsed_seconds'] = time.monotonic() - native_start
        result = aggregate(reports, phases, run_id, verifier, out)
        if before != level_formal.source_files(extra_paths=VERIFIER_PATHS) or verifier != verifier_identity():
            raise RuntimeError('Source changed during version consumers')
        (out / 'capture.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
        receipt['passed'] = True
    except BaseException as error:
        receipt['error'] = type(error).__name__ + ': ' + str(error)
        raise
    finally:
        receipt['source_after'] = level_formal.source_files(extra_paths=VERIFIER_PATHS)
        receipt['verifier_after'] = verifier_identity()
        receipt['source_guard'] = before == receipt['source_after'] and verifier == receipt['verifier_after']
        if not receipt['source_guard']:
            receipt['passed'] = False
            if (out / 'capture.json').is_file():
                (out / 'capture.json').rename(out / 'source-invalid-aggregate.json')
        receipt['elapsed_seconds'] = time.monotonic() - started
        receipt['logs'] = {p.name: file_sha(p) for p in out.iterdir() if p.is_file()}
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        if not receipt['source_guard']:
            raise RuntimeError('Source changed during native version check')
    print('FOREST DEPTH VERSIONS: 327 assertions, 0 failures across 2 native consumers')
    print('PASS: forest depth runtime registry and actual legacy entry/state; v2 gameplay NOT covered')


if __name__ == '__main__':
    main()
