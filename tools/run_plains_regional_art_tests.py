"""Actual complete-region contract. Identity strings cannot prove topology variety."""
import fcntl
import hashlib
import json
import re
import subprocess
import time
from collections import Counter
from pathlib import Path

from level_formal import source_files
from run_root_bell_ecology import godot_lock_path
from run_tests import run_engine

ROOT = Path(__file__).resolve().parents[1]


def graph(manifest):
    adjacency = {area['id']: set() for area in manifest['areas']}
    for edge in manifest['connections']:
        a, b = edge['a'], edge['b']
        if a not in adjacency or b not in adjacency or a == b:
            raise ValueError('Malformed actual formal graph')
        adjacency[a].add(b)
        adjacency[b].add(a)
    return adjacency


def isomorphic(first, second):
    """Exact undirected connectivity check, ignoring names, geometry and edge kind.

    A reported difference therefore cannot be manufactured by renaming places,
    changing phase, vertical distance or swapping a module recipe.
    """
    a, b = graph(first), graph(second)
    if len(a) != len(b) or sorted(map(len, a.values())) != sorted(map(len, b.values())):
        return False
    colors_a = {node: len(neighbors) for node, neighbors in a.items()}
    colors_b = {node: len(neighbors) for node, neighbors in b.items()}
    # Joint refinement keeps the same color IDs across both actual graphs.
    for _ in range(len(a)):
        signatures_a = {node: (colors_a[node], tuple(sorted(colors_a[n] for n in neighbors))) for node, neighbors in a.items()}
        signatures_b = {node: (colors_b[node], tuple(sorted(colors_b[n] for n in neighbors))) for node, neighbors in b.items()}
        palette = {signature: i for i, signature in enumerate(sorted(set(signatures_a.values()) | set(signatures_b.values())))}
        next_a = {node: palette[signature] for node, signature in signatures_a.items()}
        next_b = {node: palette[signature] for node, signature in signatures_b.items()}
        if Counter(next_a.values()) != Counter(next_b.values()):
            return False
        if next_a == colors_a and next_b == colors_b:
            break
        colors_a, colors_b = next_a, next_b
    mapping, used = {}, set()

    def search():
        if len(mapping) == len(a):
            return True
        choices = []
        for node in a.keys() - mapping.keys():
            candidates = [other for other in b.keys() - used
                          if colors_a[node] == colors_b[other]
                          and all((prior in a[node]) == (target in b[other]) for prior, target in mapping.items())]
            if not candidates:
                return False
            choices.append((len(candidates), -sum(n in mapping for n in a[node]), node, candidates))
        _, _, node, candidates = min(choices)
        for other in candidates:
            mapping[node] = other
            used.add(other)
            if search():
                return True
            used.remove(other)
            del mapping[node]
        return False

    return search()


def graph_summary(manifest):
    adjacency = graph(manifest)
    edges = sum(map(len, adjacency.values())) // 2
    return {'vertices': len(adjacency), 'undirected_edges': edges,
            'degree_sequence': sorted(map(len, adjacency.values())),
            'cycle_rank_assuming_connected': edges - len(adjacency) + 1}


def main():
    folder = ROOT / 'build/plains_regional_art/contract' / time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())
    folder.mkdir(parents=True, exist_ok=False)
    report = {'status': 'failed', 'scope': 'Actual full formal map generation and art-plan contract only; no Motor, art, release or device admission'}
    started = time.monotonic()
    try:
        lock_path = godot_lock_path(ROOT)
        lock_path.parent.mkdir(parents=True, exist_ok=True)
        with lock_path.open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            report['engine_lock_wait_seconds'] = time.monotonic() - started
            imported = run_engine(['--headless', '--path', '.', '--editor', '--quit'], 120)
            (folder / 'import.log').write_text(imported)
            if re.search(r'(^|\n)ERROR:', imported):
                raise RuntimeError('Native import emitted an error')
            baseline_bytes = subprocess.check_output(['git', 'show', '148d9251da2a457944213ba73b082525edf5e729:game/world/generation/plains_region_generator.gd'], cwd=ROOT)
            original = folder / 'pr85_generator_original.gd'
            original.write_bytes(baseline_bytes)
            baseline = folder / 'pr85_generator_loadable.gd'
            relative_baseline = baseline.relative_to(ROOT).as_posix()
            adapted = baseline_bytes.decode().replace('class_name PlainsRegionGenerator\n', '')
            adapted = adapted.replace('var gen := PlainsRegionGenerator.new()', 'var gen = load("res://' + relative_baseline + '").new()')
            baseline.write_text(adapted)
            report['legacy_baseline'] = {'git_commit': '148d9251da2a457944213ba73b082525edf5e729',
                                         'original_path': str(original.relative_to(ROOT)), 'original_sha256': hashlib.sha256(baseline_bytes).hexdigest(),
                                         'loadable_path': relative_baseline, 'loadable_sha256': hashlib.sha256(adapted.encode()).hexdigest(),
                                         'adaptation': 'Only remove global class registration and redirect its local static helper constructor to this same preserved script; generation logic untouched'}
            before = source_files()
            args = ['--headless', '--path', '.', '--script', 'tests/plains_regional_art_plan_runner.gd', '--', '--output=' + str(folder / 'actual.json'), '--baseline-script=res://' + relative_baseline]
            output = run_engine(args, 180)
            (folder / 'contract.log').write_text(output)
            report['command'] = ['bash', 'tools/godot.sh', *args]
            report['log_sha256'] = hashlib.sha256(output.encode()).hexdigest()
            if not re.search(r'^PLAINS REGIONAL ART CONTRACT: [1-9]\d* assertions, 0 failures$', output, re.M) or re.search(r'(^|\n)ERROR:', output):
                raise RuntimeError('Incomplete native contract or native error')
            actual = json.loads((folder / 'actual.json').read_text())
            rows = actual['actual']
            if len(rows) != len(actual['root_seeds']):
                raise RuntimeError('Incomplete preregistered native Seed corpus')
            classes = []
            summaries = []
            for row in rows:
                representative = next((i for i, manifest in enumerate(classes) if isomorphic(row['manifest'], manifest)), None)
                if representative is None:
                    representative = len(classes)
                    classes.append(row['manifest'])
                summaries.append({'root_seed': row['root_seed'], 'connectivity_class': representative, **graph_summary(row['manifest'])})
            report['topology'] = {'method': 'Exact backtracking undirected graph isomorphism, excluding area names, physical coordinates, phase, module recipes and hashes',
                                  'distinct_connectivity_classes': len(classes), 'actual': summaries,
                                  'first_two_nonisomorphic': not isomorphic(rows[0]['manifest'], rows[1]['manifest'])}
            if len(classes) < 2:
                raise RuntimeError('Actual Seed corpus has no proven connectivity difference')
            report['source_before'] = before
            report['source_after'] = source_files()
            if report['source_after'] != before:
                raise RuntimeError('Source drift during frozen native contract')
            report['status'] = 'passed'
    except (OSError, RuntimeError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        report['error'] = type(error).__name__ + ': ' + str(error)
    report['elapsed_seconds'] = time.monotonic() - started
    (folder / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('PLAINS REGIONAL ART SUITE: ' + report['status'] + ' ' + str(folder.relative_to(ROOT)))
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
