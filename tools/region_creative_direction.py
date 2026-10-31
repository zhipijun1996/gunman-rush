"""Versioned creative input to the existing production loop; never a quality gate substitute."""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COVERAGE = ('intent', 'emotion', 'player_behavior', 'space', 'ecology', 'boss',
            'visual', 'motion_audio', 'memory', 'exclusions', 'commercial', 'slice')
HANDOFF = ('contribution', 'collaboration', 'experience_delta', 'theme_conflicts', 'runtime_validation')


BIBLE_REGISTRY = 'docs/creative_direction/bibles/registry.json'
BIBLE_FIELDS = {'registry_path', 'registry_sha256', 'path', 'sha256', 'bible_id',
                'version', 'region_id', 'status', 'selection_evidence_path', 'selection_evidence_sha256'}

SUPPLEMENT_FIELDS = {'supplemental_authority_path', 'supplemental_authority_sha256'}

# Explicit direct consumers of the current formal UnderworldPlayer body, not a
# general resource crawler. A script-only hash cannot bind the pixels it draws.
PLAYER_STYLE_DEPENDENCIES = {
    'player_animation_build': 'assets/underworld_plains/player_animation/animation_build.json',
    'player_run_pixels': 'assets/underworld_plains/player_animation/run_sheet.png',
    'player_state_pixels': 'assets/underworld_plains/player_animation/states_sheet.png',
}


class MissingBible(ValueError):
    """Only absence permits proposed-Bible preproduction; corruption never does."""


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate JSON key: ' + key)
        result[key] = value
    return result


def repository_file(path, root=ROOT):
    relative = Path(path)
    base = Path(root).resolve()
    target = base / relative
    if relative.is_absolute() or '..' in relative.parts or not relative.parts:
        raise ValueError('Bible source must be repository relative')
    if any(p.is_symlink() for p in [target, *target.parents[:len(relative.parts)]]):
        raise ValueError('Bible source and ancestors must not be symlinks')
    if not target.resolve().is_relative_to(base) or not target.is_file():
        raise ValueError('Missing/unsafe Bible source: ' + str(path))
    return target


def strict_json(path, root=ROOT):
    return json.loads(repository_file(path, root).read_bytes(), object_pairs_hook=unique_object)


def load_bible_registry(root=ROOT):
    data = strict_json(BIBLE_REGISTRY, root)
    if (not isinstance(data, dict) or type(data.get('schema_version')) is not int
            or data['schema_version'] != 1 or data.get('kind') != 'region_bible_registry_direction_only'
            or not isinstance(data.get('regions'), list)):
        raise ValueError('Invalid Bible registry schema')
    catalog = strict_json('docs/world_regions.json', root)
    expected = {row['id'] for row in catalog['regions']}
    ids = [row.get('region_id') for row in data['regions'] if isinstance(row, dict)]
    if len(ids) != len(data['regions']) or len(ids) != len(set(ids)) or set(ids) != expected:
        raise ValueError('Bible registry must contain each catalog region exactly once')
    return data


def supplemental_authority(bible, region_id, root=ROOT):
    ref = load_bible_registry(root).get('shared_style_authority')
    if not isinstance(ref, dict) or set(ref) != {'path', 'sha256'}:
        raise ValueError('Invalid supplemental authority binding')
    path = repository_file(ref['path'], root)
    if hashlib.sha256(path.read_bytes()).hexdigest() != ref['sha256']:
        raise ValueError('Supplemental authority SHA changed; impact analysis/rebind required')
    data = strict_json(ref['path'], root)
    source = data.get('source', {})
    dimensions = data.get('shared_dimensions', {})
    if (data.get('schema_version') != 1 or data.get('authority_id') != 'project_shared_regional_style'
            or not isinstance(data.get('version'), str) or not data['version'].strip()
            or data.get('applies_to') != 'all_region_create_optimize_and_proposed_bibles'
            or data.get('mode') != 'shared_project_style_with_regional_variation'
            or any(not isinstance(source.get(k), str) or not source[k].strip() for k in ('source','quote','additional_quote','scope'))
            or any(not isinstance(dimensions.get(k), str) or not dimensions[k].strip()
                   for k in ('pixel_scale','adjacency_and_boundary','lighting_outline_material','regional_variation'))):
        raise ValueError('Supplement must retain original user quote, region scope and shared style requirements')
    runtime = data.get('runtime_reference', {})
    references = runtime.get('references', [])
    roles = {'formal_entry','terrain_consumer','terrain_renderer','material_shader','tile_build',
             'tileset','atlas','source_pixels','adjacency','boundary','license','player_style_reference',
             *PLAYER_STYLE_DEPENDENCIES}
    if (not isinstance(runtime.get('region_id'), str) or not isinstance(references, list)
            or any(not isinstance(row, dict) for row in references)
            or not roles <= {row.get('role') for row in references}
            or len({row.get('role') for row in references}) != len(references)
            or len({row.get('path') for row in references}) != len(references)):
        raise ValueError('Complete actual formal Plains runtime/style reference family required')
    by_role = {row['role']: row for row in references}
    player = by_role['player_style_reference']
    # Frozen styles1-25 retain their exact former consumer; style26 onward binds
    # the sole relocated implementation. Never accept either path indiscriminately.
    player_path = ('scripts/underworld_plains/underworld_player.gd'
                   if data['version'] in {str(version) for version in range(1, 26)}
                   else 'game/presentation/actors/underworld_plains/underworld_player.gd')
    if (player.get('path') != player_path
            or any(by_role[role].get('path') != path for role,path in PLAYER_STYLE_DEPENDENCIES.items())):
        raise ValueError('Actual UnderworldPlayer body dependencies must retain their explicit consumer paths')
    player_source = repository_file(player['path'],root).read_text()
    if any('"res://' + path + '"' not in player_source for path in PLAYER_STYLE_DEPENDENCIES.values()):
        raise ValueError('Shared player references differ from the actual direct body consumer; impact analysis/rebind required')
    for row in references:
        if (not isinstance(row.get('sha256'), str) or not re.fullmatch(r'[0-9a-f]{64}',row['sha256'])
                or hashlib.sha256(repository_file(row.get('path'),root).read_bytes()).hexdigest() != row['sha256']):
            raise ValueError('Shared Plains style reference SHA changed; impact analysis and revalidation required: ' + str(row.get('path')))
    build = strict_json(next(row['path'] for row in references if row['role']=='tile_build'),root)
    if any(runtime.get(key) != build.get(key) for key in ('tile_px','world_tile_wu')) or runtime.get('terrain_mode') != build.get('mode'):
        raise ValueError('Shared style scale/boundary metadata differs from the actual runtime build')
    return {'path':ref['path'],'sha256':ref['sha256'],'content':data}


def bind_region_bible(region_id, root=ROOT):
    data = load_bible_registry(root)
    row = next((row for row in data['regions'] if row['region_id'] == region_id), None)
    if row is None or row.get('current_bible') is None:
        raise MissingBible('Missing Bible for ' + str(region_id) + '; author a proposed Bible in preproduction before production')
    bible = row['current_bible']
    if not isinstance(bible, dict) or any(not isinstance(bible.get(k), str) or not bible[k].strip()
            for k in ('path', 'sha256', 'bible_id', 'version', 'status', 'direction_path')):
        raise ValueError('Incomplete current Bible identity')
    if (bible['status'] != 'user_selected_direction_only'
            or bible.get('music_status') != 'deferred_user_supplied'
            or bible.get('operations') != ['create', 'optimize']):
        raise ValueError('Bible must have selected direction status and explicit production/audio scope')
    major = bible['version'].split('.')[0]
    if (not re.fullmatch(r'[1-9][0-9]*\.[0-9]+', bible['version'])
            or bible['version'] != major + '.0'  # Original _vN attachment is version N.0.
            or bible['bible_id'] != str(region_id) + '_v' + major
            or not Path(bible['path']).name.endswith(str(region_id) + '_region_bible_v' + major + '.md')):
        raise ValueError('Bible version/region identity must agree with the registered original document name')
    raw = repository_file(bible['path'], root).read_bytes()
    if hashlib.sha256(raw).hexdigest() != bible['sha256']:
        raise ValueError('Bible SHA256 changed; impact analysis, versioned rebind and independent review required')
    raw.decode('utf-8')  # Never normalize or replace original attachment bytes.
    evidence = bible.get('selection_evidence', {})
    if not isinstance(evidence, dict) or not isinstance(evidence.get('path'), str):
        raise ValueError('Bible selection requires original user instruction evidence')
    source = repository_file(evidence['path'], root)
    if hashlib.sha256(source.read_bytes()).hexdigest() != evidence.get('sha256'):
        raise ValueError('Bible selection evidence SHA256 mismatch')
    request = strict_json(evidence['path'], root)
    if any(not isinstance(request.get(k), str) or not request[k].strip() for k in ('source', 'quote', 'authorization_scope')):
        raise ValueError('Bible selection requires original user source/quote/scope')
    attachments = request.get('attachments', [])
    canonical_name = Path(bible['path']).name
    if not isinstance(attachments, list):
        raise ValueError('Bible original attachment identity list is invalid')
    originals = [a for a in attachments if isinstance(a, dict)
                 and isinstance(a.get('original_attachment_path'), str)
                 and Path(a['original_attachment_path']).name == canonical_name]
    if len(originals) != 1:
        raise ValueError('Bible region/document identity requires one matching original attachment basename')
    original = originals[0]
    staged = original.get('staged_path')
    if (not isinstance(staged, str) or Path(staged).is_absolute() or '..' in Path(staged).parts
            or Path(staged).name != canonical_name
            or original.get('sha256') != bible['sha256']
            or original.get('bytes') != len(raw) or original.get('copied_verbatim') is not True):
        raise ValueError('Bible canonical region/document must match its original/staged attachment identity and exact bytes')
    supplement = supplemental_authority(bible, region_id, root)
    ref = {k:bible[k] for k in ('path', 'sha256', 'bible_id', 'version', 'status')}
    if supplement:
        ref.update(supplemental_authority_path=supplement['path'], supplemental_authority_sha256=supplement['sha256'])
    ref.update(region_id=region_id, registry_path=BIBLE_REGISTRY,
               registry_sha256=hashlib.sha256(repository_file(BIBLE_REGISTRY, root).read_bytes()).hexdigest(),
               selection_evidence_path=evidence['path'], selection_evidence_sha256=evidence['sha256'])
    return bible, ref


def validate_bible_binding(ref, region_id=None, root=ROOT):
    if not isinstance(ref, dict) or set(ref) not in (BIBLE_FIELDS, BIBLE_FIELDS | SUPPLEMENT_FIELDS):
        raise ValueError('Complete region_bible binding required before region production')
    if region_id is not None and ref.get('region_id') != region_id:
        raise ValueError('Bible binding belongs to another region')
    bible, current = bind_region_bible(ref.get('region_id'), root)
    if current != ref:
        raise ValueError('Bible binding changed; impact analysis and independent review/rebind required; do not refresh downstream hashes')
    return bible, current


def validate_direction(data):
    errors = []
    if not isinstance(data, dict):
        return ['Creative direction must be an object']
    if type(data.get('schema_version')) is not int or data.get('schema_version') != 1:
        errors.append('Unsupported creative direction schema')
    for name in ('region_id', 'version', 'direction_id', 'title', 'selection_rationale'):
        if not isinstance(data.get(name), str) or not data[name].strip():
            errors.append('Missing creative identity: ' + name)
    if data.get('decision') != 'selected':
        errors.append('Direction has not been selected')
    if data.get('acceptance') not in {'professional_recommendation', 'user_confirmed'}:
        errors.append('Selection must distinguish recommendation from user confirmation')
    if data.get('acceptance') == 'user_confirmed':
        evidence = data.get('user_evidence')
        if not isinstance(evidence, dict) or not all(isinstance(evidence.get(k), str) and evidence[k].strip() for k in ('source', 'quote', 'scope')):
            errors.append('User confirmation requires original user evidence source/quote/scope')
    for name in COVERAGE:
        if not isinstance(data.get(name), dict) or not data[name]:
            errors.append('Missing creative coverage: ' + name)
    candidates = data.get('candidates', [])
    supplied = data.get('selection_basis') == 'user_supplied_bible'
    if supplied:
        if data.get('acceptance') != 'user_confirmed' or not isinstance(data.get('region_bible'), dict):
            errors.append('User-supplied Bible requires selected binding and original user evidence')
        if data.get('user_acceptance') != 'direction_only_not_art_gameplay_or_device':
            errors.append('Bible selection cannot imply art, gameplay or device acceptance')
        if candidates:
            errors.append('Already selected user Bible must not invent election candidates')
    elif not isinstance(candidates, list) or not 2 <= len(candidates) <= 3:
        errors.append('Compare two or three complete directions')
    elif not supplied:
        ids = set()
        for row in candidates:
            if not isinstance(row, dict):
                errors.append('Invalid direction candidate'); continue
            candidate_id = row.get('id')
            if not isinstance(candidate_id, str) or candidate_id in ids:
                errors.append('Candidate identities must be distinct strings')
            if isinstance(candidate_id, str): ids.add(candidate_id)
            for name in ('experience', 'space', 'ecology_boss', 'art_emotion', 'originality', 'feasibility', 'player_appeal', 'risk'):
                if not isinstance(row.get(name), str) or not row[name].strip():
                    errors.append('Candidate lacks comparison: ' + name)
        if data.get('direction_id') not in ids:
            errors.append('Selected direction is outside compared candidates')
    sources = data.get('authority_sources', [])
    if not isinstance(sources, list) or not sources:
        errors.append('Missing actual design authority sources')
    return errors


def load_direction(path, region_id=None, root=ROOT):
    relative = Path(path)
    if relative.is_absolute() or '..' in relative.parts:
        raise ValueError('Creative direction must be a repository relative input')
    target = Path(root) / relative
    if target.is_symlink() or not target.resolve().is_relative_to(Path(root).resolve()):
        raise ValueError('Creative direction cannot escape the repository')
    data = strict_json(relative.as_posix(), root)
    errors = validate_direction(data)
    if region_id is not None and data.get('region_id') != region_id:
        errors.append('Creative direction belongs to another region')
    if data.get('selection_basis') == 'user_supplied_bible':
        _, selected = validate_bible_binding(data.get('region_bible'), data.get('region_id'), root)
        original = strict_json(selected['selection_evidence_path'], root)
        evidence = data.get('user_evidence', {})
        if (evidence.get('source') != selected['selection_evidence_path']
                or evidence.get('quote') != original['quote']):
            errors.append('Selected Bible user confirmation must quote the actual original instruction evidence')
    for source in data.get('authority_sources', []):
        if not isinstance(source, dict) or not isinstance(source.get('path'), str):
            errors.append('Invalid authority source'); continue
        try:
            source_path = repository_file(source['path'], root)
        except ValueError:
            errors.append('Missing/unsafe authority source: ' + source['path']); continue
        if hashlib.sha256(source_path.read_bytes()).hexdigest() != source.get('sha256'):
            errors.append('Authority changed; rethink direction: ' + source['path'])
    if errors:
        raise ValueError('; '.join(errors))
    return data, {'path': relative.as_posix(), 'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                  'region_id': data['region_id'], 'version': data['version']}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('paths', nargs='*')
    parser.add_argument('--directory')
    parser.add_argument('--check-bibles', action='store_true')
    args = parser.parse_args(argv)
    if args.check_bibles:
        registry = load_bible_registry()
        for row in registry['regions']:
            if row.get('current_bible') is not None:
                bind_region_bible(row['region_id'])
        print('PASS: Bible registry and selected original bytes; direction only, production/audio/device outcomes unverified')
        return 0
    paths = [Path(p) for p in args.paths]
    if args.directory:
        paths.extend(sorted((ROOT / args.directory).glob('*.json')))
    if not paths:
        raise ValueError('No creative direction artifact; a plan is not selected direction')
    for path in paths:
        load_direction(path.relative_to(ROOT) if path.is_absolute() else path)
    print(f'PASS: {len(paths)} versioned creative directions; no runtime, art or player acceptance inferred')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, OSError, KeyError, TypeError) as error:
        raise SystemExit(str(error))
