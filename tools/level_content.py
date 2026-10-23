#!/usr/bin/env python3
"""Evidence-first content analysis. No runtime consumer or automatic fun rating.

The library is an explicit input, pinned by bytes; mapnote JSON never becomes a
Godot level here. AI reviews are separate signed-by-author inputs, not heuristics.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import html
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
VERSION = 1


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False,
                                    separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + '\n')


def safe_file(root, name):
    path = (root / name).resolve()
    if not path.is_relative_to(root.resolve()) or not path.is_file():
        raise ValueError('Missing or unsafe input: ' + name)
    return path


def features(document):
    objects = document.get('objects', [])
    types = Counter(o['type'] for o in objects)
    translation = document['source'].get('editorTranslation', [0, 0])
    # Geometry ignores labels/IDs and editor translation, includes dynamic tracks
    # and source entity parameters. A renamed object cannot create novelty.
    def reference_key(key):
        return key.endswith('Id') or key.endswith('Ids') or key in ('target', 'bind')

    def normalized(obj):
        clean = {k: v for k, v in obj.items() if k not in
                 ('id', 'label', 'note', 'sourceIndex', 'sourcePort') and not reference_key(k)}
        if 'x' in clean: clean['x'] = round(clean['x'] - translation[0], 4)
        if 'y' in clean: clean['y'] = round(clean['y'] - translation[1], 4)
        if isinstance(clean.get('points'), list):
            points = []
            for point in clean['points']:
                if isinstance(point, dict) and 'x' in point and 'y' in point:
                    points.append({**point, 'x': round(point['x'] - translation[0], 4),
                                   'y': round(point['y'] - translation[1], 4)})
                elif isinstance(point, list) and len(point) >= 2:
                    points.append([round(point[0] - translation[0], 4),
                                   round(point[1] - translation[1], 4), *point[2:]])
                else:
                    raise ValueError('Unsupported trajectory point')
            clean['points'] = points
        return clean

    identities = {o['id']: digest(normalized(o)) for o in objects}
    # Native sourceId aliases resolve to the same geometric endpoint rather
    # than creating an ID-dependent novelty signature.
    aliases = {o['sourceId']: identities[o['id']] for o in objects if 'sourceId' in o}
    geometry = []
    for obj in objects:
        if obj['type'] in ('entry', 'exit', 'anchor', 'label', 'route', 'action'):
            continue
        geometry.append(normalized(obj))
    original = document['source']['original']
    ports = []
    if isinstance(original, dict):
        for key in ('entry_port', 'exit_port', 'entry_ports', 'exit_ports', 'ports'):
            value = original.get(key, [])
            ports.extend(value if isinstance(value, list) else [value])
    routes = document.get('routes', [])
    if isinstance(document.get('route'), dict): routes = [document['route'], *routes]
    routes = [*routes, *(o for o in objects if o['type'] == 'route')]
    actions = [str(p.get('action', '')).strip() for r in routes
               for p in r.get('points', []) if str(p.get('action', '')).strip()]
    original_dict = original if isinstance(original, dict) else {}
    # These are explicit relationships, never inferred player behaviour.
    bindings = []
    for obj in objects:
        for key, value in obj.items():
            if not reference_key(key) or key == 'sourceId': continue
            targets = value if isinstance(value, list) else [value]
            for target in targets:
                endpoint = identities.get(str(target), aliases.get(str(target)))
                bindings.append({'from': identities[obj['id']], 'relation': key,
                                 'to': endpoint or 'unresolved_external_reference',
                                 'resolved': endpoint is not None})
    bindings.sort(key=digest)
    action_program = original_dict.get('action_program', [])
    tokens = set('entity:' + k for k in types)
    tokens.update('action:' + a for a in actions)
    tokens.update('binding:' + b['relation'] for b in bindings)
    if original_dict.get('branch_routes'): tokens.add('topology:branch')
    if original_dict.get('return_route'): tokens.add('topology:return')
    if action_program: tokens.add('route:action_program')
    return {'entity_counts': dict(sorted(types.items())), 'object_count': len(objects),
            'port_count': len(ports), 'ports': ports, 'route_count': len(routes),
            'declared_actions': actions, 'action_program': action_program,
            'bindings': bindings, 'geometry_signature': digest(sorted(geometry, key=lambda x: digest(x))),
            'structural_tokens': sorted(tokens),
            'intent_signature': digest({'tokens': sorted(tokens), 'program': action_program, 'bindings': bindings}),
            'observed_behavior': None,
            'limits': 'Source features and intent only; no executed path, minimum ability or fun inferred.'}


def analyze(library, output):
    library, output = Path(library).resolve(), Path(output)
    catalog_path = safe_file(library, 'library/catalog.json')
    catalog = json.loads(catalog_path.read_text())
    rows, jobs = [], []
    for item in catalog['modules']:
        path = safe_file(library, item['file'].removeprefix('./'))
        actual = sha(path)
        if actual != item['contentSha256']: raise ValueError('Library hash mismatch: ' + item['id'])
        document = json.loads(path.read_text())
        if document['source']['commit'] != catalog['sourceCommit']:
            raise ValueError('Mixed source commits: ' + item['id'])
        feat = features(document)
        row = {'id': item['id'], 'title': item['title'], 'region': item['category'],
               'collection': item['collection'], 'source': {
                   'commit': catalog['sourceCommit'], 'path': document['source']['path'],
                   'kind': document['source']['kind'], 'document_sha256': actual},
               'capabilities': document.get('capabilityRequirements'),
               'difficulty': document.get('difficulty'),
               'historical_integration': item['integration'], 'features': feat,
               'technical': {'status': 'unverified', 'reason': 'Import is not physical evidence'},
               'ai_design': {'status': 'pending'}, 'human': {'status': 'unverified'}}
        rows.append(row)
        jobs.append({'id': item['id'], 'document': str(path), 'document_sha256': actual,
                     'features': feat,
                     'questions': ['玩家观察什么、选择什么、承担什么风险、如何恢复？',
                                   '最便宜合法打法会使设计意图失效吗？',
                                   '与近邻区别来自决策关系还是几何参数？',
                                   '技术、AI判断、真人认可分别有什么证据？'],
                     'required_output': ['decision:retain|improve|reconstruct|retire|needs_evidence',
                                         'role', 'strengths', 'problems', 'improvement', 'counterfactual',
                                         'evidence_paths', 'uncertainty'],
                     'prohibition': 'Do not infer success/fun/novelty from counts, labels, thumbnails or import.'})
    duplicates = defaultdict(list)
    for row in rows: duplicates[row['features']['geometry_signature']].append(row['id'])
    for row in rows:
        tokens = set(row['features']['structural_tokens'])
        nearest = []
        for other in rows:
            if other is row: continue
            theirs = set(other['features']['structural_tokens'])
            similarity = len(tokens & theirs) / max(1, len(tokens | theirs))
            nearest.append({'id': other['id'], 'structural_jaccard': round(similarity, 4),
                            'same_geometry': row['features']['geometry_signature'] == other['features']['geometry_signature']})
        row['similarity'] = sorted(nearest, key=lambda v: (-v['same_geometry'], -v['structural_jaccard'], v['id']))[:5]
    report = {'schema_version': VERSION, 'artifact_kind': 'level_library_analysis',
              'catalog_sha256': sha(catalog_path), 'source_commit': catalog['sourceCommit'],
              'count': len(rows), 'modules': rows,
              'exact_geometry_groups': [ids for ids in duplicates.values() if len(ids) > 1],
              'limits': ['Structural similarity is a triage aid, never behavioral novelty.',
                         'Historical integration is pinned to its original commit; use consumer audit before reuse.',
                         'All absent physical/human evidence stays unverified.']}
    write(output / 'analysis.json', report)
    (output / 'review_jobs.jsonl').parent.mkdir(parents=True, exist_ok=True)
    (output / 'review_jobs.jsonl').write_text(''.join(json.dumps(j, ensure_ascii=False) + '\n' for j in jobs))
    print(f'ANALYSIS: {len(rows)} source records, {len(report["exact_geometry_groups"])} exact geometry groups; no fun claims')
    return report


def merge_reviews(analysis_path, reviews_path, output):
    report, bundle = json.loads(Path(analysis_path).read_text()), json.loads(Path(reviews_path).read_text())
    if bundle.get('schema_version') != 1 or not bundle.get('reviewer'):
        raise ValueError('Missing review version/author')
    reviews = {r['id']: r for r in bundle['reviews']}
    if len(reviews) != len(bundle['reviews']): raise ValueError('Duplicate reviews')
    ids = {r['id'] for r in report['modules']}
    if set(reviews) - ids: raise ValueError('Review refers to absent content')
    for row in report['modules']:
        if row['id'] not in reviews: continue
        review = reviews[row['id']]
        if review.get('document_sha256') != row['source']['document_sha256']:
            raise ValueError('Stale AI review: ' + row['id'])
        if review.get('decision') not in ('retain', 'improve', 'reconstruct', 'retire', 'needs_evidence'):
            raise ValueError('Invalid AI decision')
        for key in ('role', 'strengths', 'problems', 'improvement', 'counterfactual', 'evidence_paths', 'uncertainty'):
            if key not in review: raise ValueError('Missing AI reasoning: ' + key)
        row['ai_design'] = {'status': 'reviewed', 'reviewer': bundle['reviewer'], **review}
    write(output, report)
    print(f'REVIEWS: {len(reviews)} attributed AI design judgments; human acceptance unchanged')


def behavior(frames):
    """Measured descriptor; names/design labels never enter this signature."""
    if not frames: raise ValueError('Empty physical trace')
    xs, ys, events, rejections, grounded_changes = [], [], [], [], 0
    last_grounded = None
    last_direction = 0
    reversals = 0
    for f in frames:
        pos = f['position']; xs.append(float(pos[0])); ys.append(float(pos[1]))
        v = f.get('velocity', [0, 0]); direction = (v[0] > 1) - (v[0] < -1)
        if direction and last_direction and direction != last_direction: reversals += 1
        if direction: last_direction = direction
        ground = f.get('grounded')
        if ground is not None and last_grounded is not None and ground != last_grounded: grounded_changes += 1
        if ground is not None: last_grounded = ground
        for event in f.get('accepted_actions', []):
            kind = event.get('type', '') if isinstance(event, dict) else str(event)
            if kind == 'router_rejected':
                rejections.append(event)
            elif kind:
                events.append(kind)
    compressed = [e for i, e in enumerate(events) if i == 0 or e != events[i-1]]
    return {'ticks': len(frames), 'horizontal_span': round(max(xs)-min(xs), 2),
            'vertical_span': round(max(ys)-min(ys), 2), 'direction_reversals': reversals,
            'grounded_transitions': grounded_changes, 'accepted_action_sequence': compressed,
            'observed_rejections': rejections,
            'behavior_family': digest({'reversals': min(reversals, 4), 'grounded': min(grounded_changes, 8),
                                       'actions': compressed}),
            'limits': 'A bounded policy trajectory, not the full solution space or human success rate.'}


def feedback(receipt, parent):
    errors = receipt.get('errors', [])
    reason = 'swept_hazard' if any('hazard' in str(e) for e in errors) else 'driver_or_route_failure'
    return {'parent': parent, 'receipt_sha256': digest(receipt), 'observed_errors': errors,
            'failure_class': reason, 'status': 'rework' if not receipt.get('ok') else 'review',
            'recommendation': ('Adjust host-surface/approach clearance; preserve hazard and Motor rules.'
                               if reason == 'swept_hazard' else
                               'Inspect first failed transition and strong legal alternative; failure is not proof of impossibility.'),
            'requires_new_version': True, 'human_fun': 'unverified'}


def archive(receipts_path, output):
    report = json.loads(Path(receipts_path).read_text())
    results = report['results']
    cells, failures, candidates = {}, [], []
    for result in results:
        if not result.get('frames'):
            failures.append(feedback(result, result.get('id'))); continue
        descriptor = behavior(result['frames'])
        # Nonempty coordinates and an `ok` label are not physical evidence.
        # Only the original native/log/source-bound receipt can supply this bit.
        verified = verified_result(report, result, Path(receipts_path))
        item = {'id': result['id'], 'condition': result.get('condition'),
                'receipt_sha256': digest(result), 'descriptor': descriptor,
                'technical_ok': verified, 'declared_ok': result.get('ok') is True,
                'evidence_status': 'bound_native_pass' if verified else 'unverified_or_failed', 'fun': 'unverified'}
        candidates.append(item)
        if not verified:
            failures.append(feedback(result, result['id'])); continue
        # A diversity archive, no static score maximizing and no fun promotion.
        key = descriptor['behavior_family']
        cells.setdefault(key, []).append(item)
    value = {'schema_version': 1, 'artifact_kind': 'measured_diversity_archive',
             'receipt_sha256': sha(receipts_path), 'cells': list(cells.values()),
             'candidates': candidates, 'failure_feedback': failures,
             'selection_policy': 'Keep distinct measured families for AI review; equivalent policies share a cell. No automatic formal admission.',
             'search_status': 'bounded_experiment', 'human': 'unverified'}
    write(output, value)
    print(f'ARCHIVE: {len(cells)} observed families, {len(failures)} retained failures; no novelty/fun certification')


def verified_result(report, result, report_path):
    # Imported lazily: the runner uses archive only after its native execution.
    from level_content_pilot import cached_valid, snapshot
    root = report_path.resolve().parent
    while not (root / 'project.godot').is_file() and root != root.parent:
        root = root.parent
    if not (root / 'project.godot').is_file(): return False
    candidates = [r for r in report.get('receipts', []) if
                  r.get('raw_path') == result.get('raw_path') and
                  r.get('request', {}).get('candidate') == result.get('id') and
                  r.get('request', {}).get('strategy') == result.get('condition') and
                  r.get('request', {}).get('variant') == result.get('variant')]
    if len(candidates) != 1: return False
    receipt = candidates[0]
    try:
        raw_path = safe_file(root, receipt['raw_path'])
        raw = json.loads(raw_path.read_text())
        request, source = receipt['request'], receipt['runtime_source']
        if (not isinstance(source, dict) or source != snapshot(root, request.get('catalog'))
                or receipt.get('identity') != digest({'request': request, 'runtime_bytes': source})
                or receipt.get('source_fingerprint') != digest(source)
                or report.get('source_fingerprint') != digest(source)
                or any(sha(safe_file(root, name)) != expected for name, expected in source.items())
                or result.get('frames') != raw.get('frames')
                or result.get('raw_sha256') != sha(raw_path)
                or result.get('ok') is not True or receipt.get('technical_pass') is not True):
            return False
        if not cached_valid(receipt, raw_path, raw_path.with_name('native.log'), receipt['identity'], request, root):
            return False
        from level_content_contract import make_content, _physics_receipt, PILOT_SCOPE
        content = make_content(result['id'], 'module', 'pilot', 'tools/level_pilot_validate.gd',
                               report['source_commit'], sha(root / 'tools/level_pilot_validate.gd'))
        content['runtime']['consumer'] = raw['runtime_consumer']
        return _physics_receipt(raw_path, content, {'scope': PILOT_SCOPE}, root)
    except (KeyError, ValueError, OSError, TypeError):
        return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    p = commands.add_parser('analyze'); p.add_argument('--library', required=True); p.add_argument('--output', required=True)
    p = commands.add_parser('review'); p.add_argument('--analysis', required=True); p.add_argument('--reviews', required=True); p.add_argument('--output', required=True)
    p = commands.add_parser('archive'); p.add_argument('--receipts', required=True); p.add_argument('--output', required=True)
    args = parser.parse_args()
    if args.command == 'analyze': analyze(args.library, args.output)
    elif args.command == 'review': merge_reviews(args.analysis, args.reviews, args.output)
    elif args.command == 'archive': archive(args.receipts, args.output)


if __name__ == '__main__':
    try: main()
    except (ValueError, KeyError, OSError, json.JSONDecodeError) as error:
        print('CONTENT REJECTED: ' + str(error), file=sys.stderr); sys.exit(1)
