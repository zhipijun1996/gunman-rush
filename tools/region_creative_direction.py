"""Versioned creative input to the existing production loop; never a quality gate substitute."""
import argparse
import hashlib
import json
import os
import stat
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COVERAGE = ('intent', 'emotion', 'player_behavior', 'space', 'ecology', 'boss',
            'visual', 'motion_audio', 'memory', 'exclusions', 'commercial', 'slice')
HANDOFF = ('contribution', 'collaboration', 'experience_delta', 'theme_conflicts', 'runtime_validation')


BIBLE_REGISTRY = 'docs/data/creative_direction/bibles/registry.json'
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


class _ValidationFiles:
    """One public validation only; never retain mutable repository state between calls."""
    def __init__(self, root):
        self.root = Path(root).resolve()
        self._bytes = {}

    def path(self, path):
        relative = Path(path)
        if relative.anchor or '..' in relative.parts or not relative.parts:
            raise ValueError('Bible source must be repository relative')
        # With absolute/parent paths forbidden, checking every component without
        # following symlinks proves containment; no second full resolve is needed.
        # Do not cache stat results: even another leaf in this call rechecks parents.
        current = str(self.root)
        for index, part in enumerate(('', *relative.parts)):
            if part:
                current = os.path.join(current, part)
            try:
                mode = os.lstat(current).st_mode
            except (FileNotFoundError, NotADirectoryError):
                raise ValueError('Missing/unsafe Bible source: ' + str(path)) from None
            if stat.S_ISLNK(mode):
                raise ValueError('Bible source and ancestors must not be symlinks')
            if not (stat.S_ISREG(mode) if index == len(relative.parts) else stat.S_ISDIR(mode)):
                raise ValueError('Missing/unsafe Bible source: ' + str(path))
        return Path(current)

    def read(self, path):
        target = self.path(path)
        if target not in self._bytes:
            self._bytes[target] = target.read_bytes()
        return self._bytes[target]

    def json(self, path):
        return json.loads(self.read(path), object_pairs_hook=unique_object)


def repository_file(path, root=ROOT):
    return _ValidationFiles(root).path(path)


def strict_json(path, root=ROOT):
    return _ValidationFiles(root).json(path)


def load_bible_registry(root=ROOT):
    return _load_bible_registry(_ValidationFiles(root))


def _load_bible_registry(files):
    data = files.json(BIBLE_REGISTRY)
    if (not isinstance(data, dict) or type(data.get('schema_version')) is not int
            or data['schema_version'] != 1 or data.get('kind') != 'region_bible_registry_direction_only'
            or not isinstance(data.get('regions'), list)):
        raise ValueError('Invalid Bible registry schema')
    catalog = files.json('docs/bible/world_regions.json')
    expected = {row['id'] for row in catalog['regions']}
    ids = [row.get('region_id') for row in data['regions'] if isinstance(row, dict)]
    if len(ids) != len(data['regions']) or len(ids) != len(set(ids)) or set(ids) != expected:
        raise ValueError('Bible registry must contain each catalog region exactly once')
    return data


def supplemental_authority(bible, region_id, root=ROOT):
    files = _ValidationFiles(root)
    return _supplemental_authority(files, _load_bible_registry(files))


def _supplemental_authority(files, registry):
    ref = registry.get('shared_style_authority')
    if not isinstance(ref, dict) or set(ref) != {'path', 'sha256'}:
        raise ValueError('Invalid supplemental authority binding')
    if hashlib.sha256(files.read(ref['path'])).hexdigest() != ref['sha256']:
        raise ValueError('Supplemental authority SHA changed; impact analysis/rebind required')
    data = files.json(ref['path'])
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
    player_source = files.read(player['path']).decode('utf-8')
    if any('"res://' + path + '"' not in player_source for path in PLAYER_STYLE_DEPENDENCIES.values()):
        raise ValueError('Shared player references differ from the actual direct body consumer; impact analysis/rebind required')
    for row in references:
        if (not isinstance(row.get('sha256'), str) or not re.fullmatch(r'[0-9a-f]{64}',row['sha256'])
                or hashlib.sha256(files.read(row.get('path'))).hexdigest() != row['sha256']):
            raise ValueError('Shared Plains style reference SHA changed; impact analysis and revalidation required: ' + str(row.get('path')))
    build = files.json(next(row['path'] for row in references if row['role']=='tile_build'))
    if any(runtime.get(key) != build.get(key) for key in ('tile_px','world_tile_wu')) or runtime.get('terrain_mode') != build.get('mode'):
        raise ValueError('Shared style scale/boundary metadata differs from the actual runtime build')
    return {'path':ref['path'],'sha256':ref['sha256'],'content':data}


def bind_region_bible(region_id, root=ROOT):
    files = _ValidationFiles(root)
    data = _load_bible_registry(files)
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
    origin = bible.get('source_document')
    canonical = bible['path'] == 'docs/bible/regions/' + str(region_id) + '.md'
    if (not re.fullmatch(r'[1-9][0-9]*\.[0-9]+', bible['version'])
            or bible['version'] != major + '.0'
            or bible['bible_id'] != str(region_id) + '_v' + major):
        raise ValueError('Bible version/region identity must agree with the registered document')
    if origin is not None:
        if (not isinstance(origin, dict) or bible['path'] != 'docs/bible/regions/' + str(region_id) + '.md'
                or not isinstance(origin.get('path'), str)
                or not Path(origin['path']).name.endswith(str(region_id) + '_region_bible_v' + major + '.md')):
            raise ValueError('Canonical Bible path and source region identity must agree')
    elif not canonical and not Path(bible['path']).name.endswith(str(region_id) + '_region_bible_v' + major + '.md'):
        raise ValueError('Bible version/region identity must agree with the registered original document name')
    raw = files.read(bible['path'])
    if hashlib.sha256(raw).hexdigest() != bible['sha256']:
        raise ValueError('Bible SHA256 changed; update the reviewed canonical binding')
    title = raw.decode('utf-8').splitlines()[0]
    if canonical:
        catalog = files.json('docs/bible/world_regions.json')
        expected_name = next(row['working_name'] for row in catalog['regions'] if row['id'] == region_id)
        if expected_name not in title:
            raise ValueError('Canonical Bible title/region identity differs from its registered region')
    evidence = bible.get('selection_evidence', {})
    if not isinstance(evidence, dict) or not isinstance(evidence.get('path'), str):
        raise ValueError('Bible selection requires original user instruction evidence')
    if hashlib.sha256(files.read(evidence['path'])).hexdigest() != evidence.get('sha256'):
        raise ValueError('Bible selection evidence SHA256 mismatch')
    request = files.json(evidence['path'])
    if any(not isinstance(request.get(k), str) or not request[k].strip() for k in ('source', 'quote', 'authorization_scope')):
        raise ValueError('Bible selection requires original user source/quote/scope')
    if origin is not None or not canonical:
        attachments = request.get('attachments', [])
        canonical_name = Path(origin['path'] if origin else bible['path']).name
        if not isinstance(attachments, list):
            raise ValueError('Bible original attachment identity list is invalid')
        originals = [a for a in attachments if isinstance(a, dict)
                     and isinstance(a.get('original_attachment_path'), str)
                     and Path(a['original_attachment_path']).name == canonical_name]
        if len(originals) != 1:
            raise ValueError('Bible region/document identity requires one matching original attachment basename')
        original = originals[0]
        staged = original.get('staged_path')
        expected_sha = origin.get('sha256') if origin else bible['sha256']
        expected_bytes = origin.get('bytes') if origin else len(raw)
        if (not isinstance(staged, str) or Path(staged).is_absolute() or '..' in Path(staged).parts
                or Path(staged).name != canonical_name
                or original.get('sha256') != expected_sha or original.get('bytes') != expected_bytes
                or original.get('copied_verbatim') is not True):
            raise ValueError('Bible source must match its original/staged attachment identity and exact bytes')
    migration = bible.get('migration_authority')
    if migration:
        raw_migration = files.read(migration['path'])
        if hashlib.sha256(raw_migration).hexdigest() != migration['sha256']:
            raise ValueError('Migration authority hash mismatch')
        decision = json.loads(raw_migration)
        if not decision.get('authorization_scope') or not decision.get('quote'):
            raise ValueError('Migration authority needs explicit scope and quote')
        if hashlib.sha256(files.read(decision['handoff'])).hexdigest() != decision['sha256']:
            raise ValueError('Migration handoff source hash mismatch')
    supplement = _supplemental_authority(files, data)
    ref = {k:bible[k] for k in ('path', 'sha256', 'bible_id', 'version', 'status')}
    if supplement:
        ref.update(supplemental_authority_path=supplement['path'], supplemental_authority_sha256=supplement['sha256'])
    ref.update(region_id=region_id, registry_path=BIBLE_REGISTRY,
               registry_sha256=hashlib.sha256(files.read(BIBLE_REGISTRY)).hexdigest(),
               selection_evidence_path=evidence['path'], selection_evidence_sha256=evidence['sha256'])
    return bible, ref


def validate_bible_binding(ref, region_id=None, root=ROOT):
    if not isinstance(ref, dict) or set(ref) not in (BIBLE_FIELDS, BIBLE_FIELDS | SUPPLEMENT_FIELDS):
        raise ValueError('Complete region_bible binding required before region production')
    if region_id is not None and ref.get('region_id') != region_id:
        raise ValueError('Bible binding belongs to another region')
    bible, current = bind_region_bible(ref.get('region_id'), root)
    if current != ref:
        raise ValueError('Bible binding changed; reload current canonical sources and update the planned mission')
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
