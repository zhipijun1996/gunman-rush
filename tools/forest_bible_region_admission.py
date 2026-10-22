"""V15 additions over a separately generated, unchanged v14 reference.

Supplements the original physical assertions without projecting/relabeling v15.
"""
import hashlib
import copy
import json
import math
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
LAYOUT = 'forest-bible-world-v15'
REFERENCE = 'forest-fruit-routes-v14'
THORN_VERSION = 'forest-bible-thorn-covered-platforms-v1'


def thorn_retirement(m, reference=None):
    """One source-bound v15 retirement, never a generic danger exemption."""
    source = (ROOT / 'scripts/generation/forest_bible_thorn_surfaces.gd').read_text()
    local = _literal_after(source, 'const RETIRED_LOCAL := ')
    version = _literal_after(source, 'const VERSION := ')
    reason = _literal_after(source, 'const RETIRE_REASON := ')
    if (m.get('layout_version') != LAYOUT or version != THORN_VERSION
            or local != [82, 100, 790, 18]
            or reason != 'unhosted_prototype_strip_210wu_below_broken_arch'):
        raise ValueError('Only the explicit v15 thorn retirement is allowed')
    vertical = (ROOT / 'scripts/generation/forest_vertical_expedition.gd').read_text()
    placement = re.findall(r'\["broken_arch",Vector2\(([^)]+)\),"arch_four",', vertical)
    if len(placement) != 1:
        raise ValueError('Unique literal old broken-arch placement required')
    offset = json.loads('[' + placement[0] + ']')
    global_rect = [offset[0] + local[0], offset[1] + local[1], *local[2:]]
    instance = _rows(m['geometry_instances'])['broken_arch']
    index = len(m['dangers'])
    if reference is not None:
        old = _rows(reference['geometry_instances'])['broken_arch']
        index = len(reference['dangers']) - 1
        if (reference.get('layout_version') != REFERENCE or old['translation'] != offset
                or old['local_geometry']['dangers'] != [local] or old['danger_indices'] != [index]
                or reference['dangers'][index] != global_rect
                or len(reference['danger_presentations']) != len(reference['dangers'])):
            raise ValueError('The actual v14 reference must own precisely the retired last strip')
    retired = dict(instance_id='broken_arch', reason=reason, source_local_dangers=[local],
                   source_global_dangers=[global_rect], source_danger_indices=[index])
    contract = dict(version=version, retired_prototype=retired,
                    physical_delta='remove_exact_unhosted_prototype_strip_only', existing_supports_unchanged=True)
    if (type(index) is not int or index != len(m['dangers'])
            or instance.get('translation') != offset
            or instance.get('factory') != 'res://scripts/generation/forest_air_chain_geometry.gd'
            or instance.get('local_geometry', {}).get('id') != 'arch_four'
            or instance.get('local_geometry', {}).get('dangers') != [] or instance.get('danger_indices') != []
            or instance.get('thorn_surface_derivation') != retired or m.get('thorn_surface_contract') != contract
            or m['thorn_surface_contract']['existing_supports_unchanged'] is not True
            or global_rect in m['dangers']):
        raise ValueError('Exact retired source/last index/global/local derivation required')
    for metadata in (instance['thorn_surface_derivation'], m['thorn_surface_contract']['retired_prototype']):
        if (len(metadata['source_danger_indices']) != 1
                or type(metadata['source_danger_indices'][0]) is not int):
            raise ValueError('Typed original danger index required')
    return retired


def _thorn_surfaces(platforms, dangers, presentations):
    """Derive real faces from unchanged reference solids, not candidate labels."""
    supports = _rows(platforms)
    result = []
    if len(dangers) != len(presentations):
        raise ValueError('Every surviving physical danger needs its exact presentation')
    for index, (rect, display) in enumerate(zip(dangers, presentations)):
        x, y, w, h = rect
        if any(type(n) not in (int, float) or not math.isfinite(n) for n in rect) or min(w, h) <= 0:
            raise ValueError('Finite actual hazard rectangle required')
        structure, face = display['host_structure_id'], display['facing']
        segments = []
        if structure == 'hollow' and face in ('up', 'down'):
            seam = y if face == 'down' else y + h
            for row in platforms:
                if row.get('structure_id') != 'hollow' or row['one_way'] is not False:
                    continue
                sx, sy, sw, sh = row['rect']
                if (sy + sh if face == 'down' else sy) != seam:
                    continue
                left, right = max(x, sx), min(x + w, sx + sw)
                if right > left:
                    segments.append(dict(support_id=row['id'], start=[left, seam], end=[right, seam]))
            segments.sort(key=lambda r: r['start'][0])
            cursor = x
            for segment in segments:
                if segment['start'][0] != cursor:
                    raise ValueError('Solid union must cover every point without gaps or duplicate faces')
                cursor = segment['end'][0]
            if cursor != x + w:
                raise ValueError('Incomplete actual solid union')
        elif structure == 'thorn_mouth':
            host_id = display['host_support_id']
            host = supports[host_id]
            if host['one_way'] is not False or host.get('structure_id') != structure:
                raise ValueError('Actual solid thorn-mouth host required')
            sx, sy, sw, sh = host['rect']
            if host_id == 'thorn_mouth__root_arch' and sx <= x < x + w <= sx + sw and y <= sy + sh < y + h:
                face = 'down'
                segments = [dict(support_id=host_id, start=[x, sy + sh], end=[x + w, sy + sh])]
            elif host_id == 'thorn_mouth__crown' and sy <= y < y + h <= sy + sh and x < sx <= x + w:
                face = 'left'
                segments = [dict(support_id=host_id, start=[sx, y], end=[sx, y + h])]
            else:
                raise ValueError('No genuine embedded thorn-mouth face')
        if not segments:
            raise ValueError('No supported actual thorn face')
        result.append(dict(danger_index=index, face=face, hazard_rect=rect, segments=segments))
    return result


def _literal_after(source, token):
    return json.JSONDecoder().raw_decode(source.split(token, 1)[1].lstrip())[0]


def _rows(rows):
    if not isinstance(rows, list) or any(not isinstance(r, dict) or not isinstance(r.get('id'), str) for r in rows):
        raise ValueError('typed unique rows required')
    result = {r['id']: r for r in rows}
    if len(result) != len(rows):
        raise ValueError('duplicate row identity')
    return result


def _platforms(source, raw, outside):
    # Read finite authored geometry, not the candidate's own rectangles.
    root = source.split('static func _install_root_connection(', 1)[1].split('\nstatic func ', 1)[0]
    before, branch = root.split('\n\tif outside:', 1)
    east, branch = branch.split('\n\telse:', 1)
    west, after = branch.split('\n\tAPI._edge(m,"bible_root_mouth_return"', 1)
    source = source.replace(root, before + (east if outside else west) + after)
    # The other-exit's mouth is shared with inner or added only for outer.
    source = source.replace('_p(m,spiral_mouth,', '_p(m,"bible_spiral_mouth",' if outside else '_unused(m,spiral_mouth,')
    result = {}
    pattern = r'_p\(m,"([^"]+)",Rect2\(([^)]+)\),(true|false),"([^"]+)","([^"]+)"\)'
    for identity, rect, one_way, structure, role in re.findall(pattern, source):
        coordinates = json.loads('[' + rect + ']')
        if len(coordinates) != 4 or any(type(n) not in (int, float) or not math.isfinite(n) for n in coordinates):
            raise ValueError('literal rectangle required')
        result[identity] = dict(id=identity, rect=coordinates, one_way=one_way == 'true',
                                scene_kind='living_bough' if one_way == 'true' else 'root_earth',
                                structure_id=structure, surface_role=role)
    for row in raw['platforms']:
        identity = 'bible_backbranch__' + row['id']
        kind = ('hollow_bark' if row['id'].startswith(('broken', 'west_')) else
                'canopy_perch' if row['id'] == 'crown' else 'living_bough' if row['one_way'] else 'root_earth')
        result[identity] = dict(id=identity, rect=row['rect'], one_way=row['one_way'], scene_kind=kind,
                                structure_id='bible_backbranch', surface_role=row['id'])
    if len(result) != (22 if outside else 23):
        raise ValueError('unknown Bible platform construction')
    return result


def _literal_edge(source, identity, mouth):
    """Five JSON arguments of an authored ordinary edge; no script execution."""
    value = source.split('API._edge(m,' + json.dumps(identity) + ',', 1)[1]
    value = value.replace(':spiral_mouth', ':' + json.dumps(mouth))
    arguments = []
    for index in range(5):
        item, end = json.JSONDecoder().raw_decode(value.lstrip())
        arguments.append(item)
        value = value.lstrip()[end:].lstrip()
        if index < 4:
            if not value.startswith(','):
                raise ValueError('unknown authored ordinary edge')
            value = value[1:]
    return dict(zip(('a', 'b', 'kind', 'path', 'steps'), arguments))


def validate_bible_admission(data):
    errors = []

    def need(ok, reason):
        if not ok:
            errors.append('bible_' + reason)

    try:
        from run_forest_depth_region import validate_fruit_presentation
        m = data['manifest']
        evidence = data['bible_admission']
        old = evidence['reference_manifest']
        need(evidence.get('strategy') == 'original_fixed_fps_Router_no_human_hold'
             and evidence.get('actual_validated') is True and evidence.get('reference_validated') is True,
             'actual_native_validation_and_strategy')
        need(m.get('layout_version') == LAYOUT and old.get('layout_version') == REFERENCE
             and m.get('version') == old.get('version') == 'thorn-forest-region-v2', 'distinct_actual_versions')
        need(all(m.get(k) == old.get(k) for k in ('seed', 'map_index', 'player_tuning_hash')),
             'same_reference_seed_map_tuning')
        need(type(m.get('map_index')) is int and m['map_index'] in (1, 2), 'typed_actual_map')
        need(not validate_fruit_presentation(old), 'separate_v14_fruit_reference')
        retired = thorn_retirement(m, old)
        inherited_geometry = copy.deepcopy(old['geometry_instances'])
        retired_instance = _rows(inherited_geometry)['broken_arch']
        retired_instance['local_geometry']['dangers'] = []
        retired_instance['danger_indices'] = []
        retired_instance['thorn_surface_derivation'] = retired
        need(m.get('dangers') == old['dangers'][:-1]
             and m.get('danger_presentations') == old['danger_presentations'][:-1], 'exact_one_thorn_retirement')
        expected_surfaces = _thorn_surfaces(old['platforms'], old['dangers'][:-1], old['danger_presentations'][:-1])
        need(m.get('thorn_surfaces') == expected_surfaces
             and all(type(r.get('danger_index')) is int for r in m.get('thorn_surfaces', [])),
             'actual_thorn_solid_union_faces')
        # Every dynamic check below the caller still consumes m with new bodies.
        append_categories = ('platforms', 'hook_anchors', 'areas', 'connections', 'enemies',
                             'rewards', 'geometry_instances', 'fruit_boughs', 'scene_structures')
        actual = {}
        added = {}
        for category in append_categories:
            original = _rows(old[category])
            actual[category] = _rows(m[category])
            retained = [row for row in m[category] if row['id'] in original]
            need(retained == (inherited_geometry if category == 'geometry_instances' else old[category]), 'inherited_' + category)
            added[category] = {k: v for k, v in actual[category].items() if k not in original}
        for category in ('enemy_drops', 'streams', 'stream_positions', 'routes', 'choices', 'scene_structure_kinds'):
            need(isinstance(m[category], dict) and all(m[category].get(k) == v for k, v in old[category].items()),
                 'inherited_' + category)
        changed = set(append_categories) | {'layout_version', 'manifest_hash', 'world_bounds', 'topology_signature',
                  'enemy_drops', 'streams', 'stream_positions', 'routes', 'choices', 'scene_structure_kinds',
                  'dangers', 'danger_presentations'}
        need(all(m.get(k) == v for k, v in old.items() if k not in changed), 'inherited_other_fields')
        need(set(m) - set(old) == ({'forest_discoveries', 'bible_world_contract', 'training_bells', 'forest_shortcuts',
                                  'thorn_surface_contract', 'thorn_surfaces'}
             | ({'practice_bell_contract'} if m['map_index'] == 1 else set())), 'finite_added_fields')
        need(m['production_pool'] is False and m['requires'] == ['grapple'], 'pending_H_only_admission')
        need(all(re.fullmatch(r'[0-9a-f]{64}', str(value)) for value in (m.get('manifest_hash'), old.get('manifest_hash')))
             and m['manifest_hash'] != old['manifest_hash'], 'distinct_recorded_hashes')

        source = (ROOT / 'scripts/generation/forest_bible_v2_layout.gd').read_text()
        factory_source = (ROOT / 'scripts/generation/forest_bible_backbranch_geometry.gd').read_text()
        version = re.search(r'^const VERSION := "([^"]+)"$', factory_source, re.M).group(1)
        raw = _literal_after(factory_source.replace('"version":VERSION', '"version":' + json.dumps(version)),
                             'static func build() -> Dictionary:\n\treturn ')
        variant = m['choices'].get('bible_root_connection')
        need(variant in ('outer_root_east_mouth', 'inner_root_lower_mouth'), 'finite_connection_variant')
        outside = variant == 'outer_root_east_mouth'
        need(added['platforms'] == _platforms(source, raw, outside), 'actual_added_platforms')
        instance = dict(id='bible_backbranch', factory='res://scripts/generation/forest_bible_backbranch_geometry.gd',
                        geometry_version=version, local_geometry=raw, translation=[0, 0],
                        platform_id_map={r['id']: 'bible_backbranch__' + r['id'] for r in raw['platforms']},
                        anchor_id_map={'side_fruit': 'bible_backbranch__side_fruit'}, danger_indices=[])
        need(added['geometry_instances'] == {'bible_backbranch': instance}, 'actual_added_factory')
        anchor = _rows(raw['hook_anchors'])['side_fruit']
        stem = json.loads('[' + re.search(r'_anchor\(m,"bible_backbranch__side_fruit",Vector2\([^)]+\),"bible_backbranch","bible_backbranch__entry",Vector2\(([^)]+)\)\)', source).group(1) + ']')
        need(added['hook_anchors'] == {'bible_backbranch__side_fruit': dict(id='bible_backbranch__side_fruit',
             position=anchor['position'], scene_kind='copper_growth_ring', structure_id='bible_backbranch',
             fruit_role='optional', fruit_role_basis='Bible_backbranch_optional_skill',
             fruit_route_bindings=['available:bible_backbranch_flight:H'], fruit_presentation='rooted_fruit',
             fruit_host_support_id='bible_backbranch__entry', fruit_stem_root=stem)},
             'actual_added_fruit')

        expected_edges = set(re.findall(r'API\._(?:air_)?edge\(m,"([^"]+)"', source))
        expected_edges -= {'bible_north_approach', 'bible_north_return'} if m['map_index'] == 1 else {'bible_live_bell_crossing'}
        need(set(added['connections']) == expected_edges, 'finite_added_edges')
        expected_areas = {}
        for identity, position, label, role in re.findall(r'API\._area\(m,"([^"]+)",Vector2\(([^)]+)\),"([^"]+)","([^"]+)"\)', source):
            expected_areas[identity] = dict(id=identity, position=json.loads('[' + position + ']'), label=label, role=role)
        need(added['areas'] == expected_areas, 'actual_added_areas')
        need(set(added['scene_structures']) == {'bible_backbranch', 'bible_root_tunnel', 'bible_weaver_hollow'},
             'finite_added_structures')
        for identity, structure in added['scene_structures'].items():
            need(structure.get('member_support_ids') == [r['id'] for r in m['platforms'] if r.get('structure_id') == identity],
                 'actual_structure_members/' + identity)
        mouth = actual['connections']['bible_root_mouth_exit']
        need(mouth['a'] == 'bible_root_fork' and mouth['b'] == ('R' if outside else 'D')
             and mouth['kind'] == 'ordinary_sequence', 'actual_connection_receiver')
        for identity in ('bible_spiral_other_exit',):
            binding = _literal_edge(source, identity, 'bible_spiral_mouth' if outside else 'bible_inner_mouth')
            need(all(actual['connections'][identity].get(k) == v for k, v in binding.items()),
                 'actual_authored_edge/' + identity)
        for route, edge_ids in m['routes'].items():
            need(isinstance(edge_ids, list) and bool(edge_ids) and all(e in actual['connections'] for e in edge_ids),
                 'actual_route_edges/' + route)
            edges = [actual['connections'][e] for e in edge_ids]
            need(all(a['b'] == b['a'] for a, b in zip(edges, edges[1:])), 'actual_route_continuity/' + route)
        new_routes = set(re.findall(r'm.routes\.([a-z_]+)\s*=', source))
        new_routes -= ({'bible_badge_approach', 'bible_badge_return', 'bible_map_approach', 'bible_map_return', 'bible_spiral_journey'}
                       if m['map_index'] == 1 else {'bible_bell_approach', 'bible_bell_return', 'bible_cache_approach',
                       'bible_cache_return', 'bible_letter_approach', 'bible_letter_return'})
        need(set(m['routes']) - set(old['routes']) == new_routes, 'finite_added_routes')

        reward = _literal_after(source, 'm.rewards.append(')
        shortcut = _literal_after(source, 'm.forest_shortcuts.append(')
        need(added['rewards'] == {reward['id']: reward}, 'actual_new_reward')
        need(m['forest_shortcuts'] == [shortcut], 'actual_claim_opened_gate')
        gate_edge = actual['connections']['bible_backbranch_shortcut']
        need(gate_edge.get('condition') == 'opened:' + shortcut['opened_key']
             and gate_edge.get('shortcut_id') == shortcut['id'] and gate_edge.get('claim_before_edge') is True
             and gate_edge.get('claim_id') == shortcut['unlock_reward_id']
             and gate_edge.get('claim_area') == reward['area'] and gate_edge['a'] == shortcut['from_area']
             and gate_edge['b'] == shortcut['to_area'], 'actual_gate_claim_binding')
        need(m['routes'][shortcut['return_route']][0] == gate_edge['id']
             and m['routes'][shortcut['long_return_route']][0] == 'bible_backbranch_other_exit', 'actual_distinct_returns')
        need(m['forest_shortcuts'][0]['rect'] == next(w['clear_rect'] for w in raw['windows'] if w['id'] == 'reward_opened_west_mouth'),
             'gate_matches_actual_opening')
        flight = actual['connections']['bible_backbranch_flight']
        descent = float(re.search(r'm.connections\[-1\].first_hook_requires_descent_below = ([0-9.]+)', source).group(1))
        need(flight.get('action_program') == raw['action_program'] and flight.get('departure') == raw['departure']
             and flight.get('first_hook_requires_descent_below') == descent, 'actual_F05_program')
        enemy_path = re.search(r'var path := "(res://resources/enemies/[^"]+)"', source).group(1)
        enemy_source = source.replace('FileAccess.get_sha256(path)', json.dumps(hashlib.sha256((ROOT / enemy_path[6:]).read_bytes()).hexdigest()))
        enemy_source = enemy_source.replace('"definition_path":path', '"definition_path":' + json.dumps(enemy_path))
        enemy = _literal_after(enemy_source, 'm.enemies.append(')
        need(added['enemies'] == {enemy['id']: enemy}, 'actual_new_enemy_and_windows')
        need(set(m['enemy_drops']) - set(old['enemy_drops']) == {enemy['id']}
             and m['enemy_drops'][enemy['id']].get('enemy_id') == enemy['id']
             and m['enemy_drops'][enemy['id']].get('stream_namespace') == 'enemy_drops', 'actual_new_enemy_drop')
        sites = _rows(m['forest_discoveries'])
        expected_sites = ({'forest_voiceless_bell', 'forest_root_cache', 'forest_unsent_letter'} if m['map_index'] == 1 else
                          {'forest_old_badge', 'forest_spiral_core', 'forest_branch_ring_map'})
        need(set(sites) == expected_sites, 'actual_three_discoveries')
        for site in sites.values():
            need(site['support_id'] in actual['platforms'] and site['area_id'] in actual['areas']
                 and site['host_support_id'] == site['support_id'] and site['approach_route'] in m['routes']
                 and site['return_route'] in m['routes'] and site['approach_route'] != site['return_route'],
                 'discovery_actual_host_and_returns')
        if m['map_index'] == 1:
            bell = _literal_after(source, 'm.training_bells.append(')
            bough = _literal_after(source, 'm.fruit_boughs.append(')
            need(m['training_bells'] == [bell] and added['fruit_boughs'] == {bough['id']: bough}, 'actual_practice_bell')
            need(m['practice_bell_contract'] == _literal_after(source, 'm.practice_bell_contract = '),
                 'actual_practice_bell_contract')
        else:
            need(m['training_bells'] == [] and added['fruit_boughs'] == {}, 'no_map2_practice_bell')
        contract_source = source.replace('"version":VERSION', '"version":' + json.dumps(LAYOUT))
        for constant, value in re.findall(r'^const ([A-Z_]+) := ("[^"\n]+")$', source, re.M):
            contract_source = re.sub(r'(?<=:)' + constant + r'(?=[,}])', lambda _: value, contract_source)
        contract_source = contract_source.replace('"connection_variant":m.choices.bible_root_connection',
                                                   '"connection_variant":' + json.dumps(variant))
        contract_source = contract_source.replace('"R" if outside else "D"', json.dumps('R' if outside else 'D'))
        need(m['bible_world_contract'] == _literal_after(contract_source, 'm.bible_world_contract = '),
             'explicit_pending_world_contract')
    except (OSError, KeyError, ValueError, TypeError, AttributeError, IndexError, StopIteration):
        errors.append('bible_malformed_manifest_or_authority')
    return list(dict.fromkeys(errors))
