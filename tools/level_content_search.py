#!/usr/bin/env python3
"""Small offline search over executable relationship genes, not runtime invention.

Uses the existing pilot factory and Godot validator. A finite family and bounded
mutation are explicit: there is no claim of general AI creativity or a verified
continuous parameter domain. AI judgments enter through level_content review.
"""
import argparse
import copy
import json
from pathlib import Path
import random
from types import SimpleNamespace

from level_content import digest, sha, write
from level_content_pilot import execute

ROOT = Path(__file__).resolve().parents[1]


def propose(catalog, seed, feedback=None):
    rng = random.Random(seed)
    eligible = [copy.deepcopy(c) for c in catalog['candidates'] if c['id'] in
                ('plains_overlook_choice', 'plains_backlook_cache', 'forest_crown_root_choice', 'forest_basin_homecoming')]
    rng.shuffle(eligible)
    # Reject already failed backlook; historical observations constrain selection.
    failed = {r.get('id') for r in (feedback or {}).get('candidates', [])
              if r.get('technical_ok') is False and r.get('condition') in ('main', 'reward')}
    candidates = []
    for parent in eligible:
        if parent['id'] in failed: continue
        child = copy.deepcopy(parent)
        child['blueprint'] = parent['id']
        child['parent'] = parent['id']
        child['id'] = parent['id'] + '-search-' + digest({'seed': seed, 'parent': parent['id']})[:8]
        child['search_seed'] = str(seed)
        child['strategies'] = ['main', 'reward']
        if parent['id'] == 'forest_basin_homecoming':
            # Consumed by make_definition: genuinely removes the return-to-home
            # leg while retaining collision geometry. Compare measured motion.
            child['gene']['route_order'] = 'reward_then_progress'
            child['mutation'] = 'remove_redundant_homecoming_leg'
        else:
            child['mutation'] = 'same_relationship_geometry_control'
        candidates.append(child)
    return {'schema_version': 1, 'scope': 'offline_bounded_quality_diversity_experiment',
            'pilot_revision': catalog.get('pilot_revision'), 'candidates': candidates,
            'search': {'seed': str(seed), 'operations': ['route_order', 'one_way_height_8wu_control'],
                       'new_primitive_claim': False, 'online_generation': False,
                       'feedback_hash': digest(feedback) if feedback else None,
                       'selection': 'Measured diversity plus AI judgment; physical success alone never promotes.'}}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--seed', type=int, default=20261023)
    p.add_argument('--catalog', default='config/level_pilot_candidates.json')
    p.add_argument('--feedback')
    p.add_argument('--output', default='build/ai_level_design_v1/search')
    p.add_argument('--execute', action='store_true')
    args = p.parse_args()
    baseline = json.loads((ROOT / args.catalog).read_text())
    history = json.loads((ROOT / args.feedback).read_text()) if args.feedback else None
    proposal = propose(baseline, args.seed, history)
    path = ROOT / args.output / 'candidates.json'
    write(path, proposal)
    write(ROOT / args.output / 'search_manifest.json', {
        'schema_version': 1, 'parent_catalog': {'path': args.catalog, 'sha256': sha(ROOT / args.catalog)},
        'generated_catalog': {'path': str(path.relative_to(ROOT)), 'sha256': sha(path)},
        'seed': args.seed, 'evaluation': 'not_run' if not args.execute else 'see experiment.json',
        'limits': 'Finite executable family; sampled policies only; no runtime pool or subjective admission.'})
    if args.execute:
        execute(SimpleNamespace(output=args.output + '/physics', catalog=str(path.relative_to(ROOT)),
                                only=None, strategies=None, variants=[0, 1], reuse=True))
    else:
        print('SEARCH: proposed bounded relationship/geometry controls; no physics executed')


if __name__ == '__main__':
    main()
