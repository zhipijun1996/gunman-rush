"""Render fixed-corpus actual SDK terrain and summarize host phase measurements."""
import argparse
import json
import statistics
from collections import Counter
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.collections import PatchCollection
from matplotlib.patches import Rectangle

SEEDS = ['ci-smoke', 'formal-integration-1', 'mapgen-standard-2',
         'plains-review-04', 'plains-review-05', 'plains-review-06']
CONNECTORS = {'game-route-junction', 'junction-j06-0',
              'b31-n14-static-three-sideports', 'idea-spec02-s13-001'}


def describe(row):
    attempts = row['attempts']
    result = {k: row.get(k) for k in ['seed', 'map_index', 'accepted', 'hash',
              'total_wait_ms', 'host_bind_and_assembly_ms', 'modules', 'unique_modules', 'repeated_fraction']}
    result['attempts'] = len(attempts)
    result['preload_wall_ms'] = sum(a.get('preload_wall_ms', 0) for a in attempts)
    result['preload_execution_ms'] = sum(a.get('preload_ms', 0) for a in attempts)
    result['failed_solve_wall_ms'] = sum(a.get('generation_wall_ms', 0) for a in attempts if a['status'] != 'PASS')
    result['accepted_solve_wall_ms'] = sum(a.get('generation_wall_ms', 0) for a in attempts if a['status'] == 'PASS')
    result['solve_execution_ms'] = sum(a.get('generation_execution_ms', 0) for a in attempts)
    result['validation_ms'] = sum(a.get('validate_ms', 0) for a in attempts)
    result['backends'] = sorted({a.get('backend', 'cooperative') for a in attempts})
    result['warmup'] = [a['verified_library_receipt']['warmup'] for a in attempts
                        if a.get('verified_library_receipt', {}).get('warmup')]
    if not row['accepted']:
        result['error'] = row['status']
        return result
    source = row['source']['result']
    world = source['map']
    result['quality'] = world['validation']['source_quality']
    result['top_modules'] = Counter(row['module_counts']).most_common(5)
    result['connector_fraction'] = sum(n for name, n in row['module_counts'].items() if name in CONNECTORS) / row['modules']
    by = {i['id']: i for i in world['instances']}
    result['vertical_seams'] = sum(next(p for p in by[e['a']['instance_id']]['ports']
        if p['id'] == e['a']['port_id'])['face'] in ['TOP', 'BOTTOM'] for e in world['connections'])
    result['goals'] = world['inputs']['config']['goals']
    result['abilities'] = world['inputs']['request']['player']['abilities']
    return result


def terrain(ax, row):
    ax.set_facecolor('#14201d')
    ax.set_aspect('equal')
    ax.set_xticks([]); ax.set_yticks([])
    if not row['accepted']:
        ax.text(.5, .5, 'GENERATION FAILED', ha='center', color='#e5b375', transform=ax.transAxes)
        return
    source = row['source']['result']
    world = source['map']
    solids, one_ways = [], []
    markers = []
    for instance in world['instances']:
        x, y = [n * 128 for n in instance['origin_blocks']]
        content = source['content_store'][instance['content_ref']]
        for index, rect in enumerate(content['platforms']):
            a, b, w, h = rect
            (one_ways if index in content['one_way_platform_indices'] else solids).append(Rectangle((x+a, y+b), w, h))
        for seal in instance['seals']:
            a, b, w, h = seal['rect_pixels']; solids.append(Rectangle((x+a, y+b), w, h))
        if instance['role'] in ['start', 'boss', 'target_reward']:
            w, h = instance['size_blocks']
            markers.append((x+w*64, y+h*64, instance['role']))
    ax.add_collection(PatchCollection(solids, facecolor='#91a68d', edgecolor='none'))
    ax.add_collection(PatchCollection(one_ways, facecolor='#d6bb6d', edgecolor='#d6bb6d', linewidth=.3))
    for x, y, role in markers:
        ax.scatter(x, y, s=12, marker={'start':'o', 'boss':'X', 'target_reward':'*'}[role],
                   color={'start':'#ffffff', 'boss':'#f18168', 'target_reward':'#ffe397'}[role], zorder=4)
    x0, y0, x1, y1 = world['bounds_blocks']
    ax.set_xlim(x0*128-64, x1*128+64); ax.set_ylim(y1*128+64, y0*128-64)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=Path, default=Path('build/mapgen_review'))
    parser.add_argument('--after', default='after')
    parser.add_argument('--output', type=Path, default=Path('docs/evidence/mapgen_plains_playtest_fixes'))
    args = parser.parse_args(); args.output.mkdir(parents=True, exist_ok=True)
    corpus = {phase: {(seed, index): json.loads((args.input/(args.after if phase == 'after' else phase)/f'{seed}-map_{index}.json').read_text())
              for seed in SEEDS for index in [1, 2]} for phase in ['before', 'after']}
    report = {'measurement': 'Native headless fixed-fps=60, uncapped wall execution, same real base Pulse controller; map2 explicit fixture, not natural progression. Web wait measured separately. Structural paths are SDK claims, not whole-map Motor proof.',
              'cases': {}, 'aggregate': {}}
    for phase, cases in corpus.items():
        values = [describe(r) for r in cases.values()]
        accepted = [r for r in values if r['accepted']]
        report['cases'][phase] = values
        report['aggregate'][phase] = {'accepted': len(accepted), 'total': len(values),
            'wait_median_ms': statistics.median(r['total_wait_ms'] for r in values),
            'wait_max_ms': max(r['total_wait_ms'] for r in values),
            'repeated_fraction_mean': statistics.mean(r['repeated_fraction'] for r in accepted),
            'connector_fraction_mean': statistics.mean(r['connector_fraction'] for r in accepted),
            'unique_modules_mean': statistics.mean(r['unique_modules'] for r in accepted),
            'vertical_seams_mean': statistics.mean(r['vertical_seams'] for r in accepted),
            'failed_attempts': sum(r['attempts']-int(r['accepted']) for r in values)}
    for index in [1, 2]:
        fig, axes = plt.subplots(6, 2, figsize=(15, 21), facecolor='#14201d', constrained_layout=True)
        for row_index, seed in enumerate(SEEDS):
            for col, phase in enumerate(['before', 'after']):
                row = corpus[phase][seed, index]; ax = axes[row_index, col]
                terrain(ax, row)
                info = describe(row)
                title = f'{phase.upper()} | {seed} | map {index}'
                if row['accepted']:
                    q = info['quality']
                    title += f'\n{row["modules"]} modules / {row["unique_modules"]} unique / {info["vertical_seams"]} vertical / {q["main_paths"]} paths / {q["target_rewards"]} rewards'
                ax.set_title(title, fontsize=10, color='#e9e4cc')
        fig.suptitle('ACTUAL TERRAIN | white: start   red: Boss   gold: reward / one-way platform\nFull map without gameplay fog. Each panel fits its own world bounds.', color='#e9e4cc', fontsize=13)
        fig.savefig(args.output/f'map_{index}_comparison.png', dpi=130); plt.close(fig)
    (args.output/'corpus_report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    failures = [a for row in corpus['after'].values() for a in row['attempts'] if a['status'] != 'PASS']
    if failures:
        a = failures[0]
        repro = {k: a[k] for k in ['request', 'config', 'status', 'error', 'solver_metrics', 'diagnostics']}
        repro['diagnostics'] = {'error': a['diagnostics'].get('error')}
        repro['sdk'] = json.loads(Path('config/mapgen_candidate.json').read_text())
        repro['sdk'] = {k: repro['sdk'][k] for k in ['version', 'release_head', 'source_commit', 'archive', 'module_package']}
        (args.output/'upstream_repro.json').write_text(json.dumps(repro, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(report['aggregate'], indent=2))


if __name__ == '__main__':
    main()
