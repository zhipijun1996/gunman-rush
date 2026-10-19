"""Versioned creative input to the existing production loop; never a quality gate substitute."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COVERAGE = ('intent', 'emotion', 'player_behavior', 'space', 'ecology', 'boss',
            'visual', 'motion_audio', 'memory', 'exclusions', 'commercial', 'slice')
HANDOFF = ('contribution', 'collaboration', 'experience_delta', 'theme_conflicts', 'runtime_validation')


def validate_direction(data):
    errors = []
    if not isinstance(data, dict):
        return ['Creative direction must be an object']
    if data.get('schema_version') != 1:
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
    if not isinstance(candidates, list) or not 2 <= len(candidates) <= 3:
        errors.append('Compare two or three complete directions')
    else:
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
    from level_design import read
    data = read(target)
    errors = validate_direction(data)
    if region_id is not None and data.get('region_id') != region_id:
        errors.append('Creative direction belongs to another region')
    for source in data.get('authority_sources', []):
        if not isinstance(source, dict) or not isinstance(source.get('path'), str):
            errors.append('Invalid authority source'); continue
        source_path = Path(root) / source['path']
        if not source_path.resolve().is_relative_to(Path(root).resolve()) or not source_path.is_file():
            errors.append('Missing authority source: ' + source['path']); continue
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
    args = parser.parse_args(argv)
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
