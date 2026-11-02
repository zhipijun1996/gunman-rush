#!/usr/bin/env python3
"""Export evidence-bound design sidecars and source/trace SVGs, never game levels."""
import argparse
from collections import Counter, defaultdict
import copy
import html
import json
from pathlib import Path
import re
import subprocess

from level_content import sha, write, verified_result
from level_content_contract import make_content, validate_bundle, PILOT_SCOPE

ROOT = Path(__file__).resolve().parents[1]
REVIEWS = 'docs/ai_level_design_v1/library_reviews.json'
PRODUCER = 'tools/level_pilot_validate.gd'
PILOTS = ('plains_overlook_choice', 'plains_backlook_cache',
          'forest_crown_root_choice', 'forest_basin_homecoming')


def artifact(path):
    path = Path(path)
    absolute = path if path.is_absolute() else ROOT / path
    absolute = absolute.resolve()
    if not absolute.is_relative_to(ROOT) or not absolute.is_file():
        raise ValueError('Missing/unsafe evidence artifact: ' + str(path))
    return {'path': str(absolute.relative_to(ROOT)), 'sha256': sha(absolute)}


def requirements(value=None):
    value = value or {}
    return {'status': value.get('status', 'unspecified'),
            'all_of': value.get('allOf', []), 'any_of_groups': value.get('anyOfGroups', []),
            'resources': {}, 'note': value.get('note', '')}


def legacy_content(row):
    source = row['source']
    source_file = source['path'].removeprefix('res://')
    content = make_content(row['id'], 'module', row['region'], source_file,
                           source['commit'], artifact(source_file)['sha256'])
    content['identity']['name'] = row['title']
    content['identity']['elements'] = [
        {'id': 'import_summary', 'kind': 'source_feature_summary', 'parameters': {
            'entity_counts': row['features']['entity_counts'],
            'source_document_sha256': source['document_sha256'],
            'raw_port_contracts': row['features']['ports'],
            'not_cell_decomposition': True}}]
    content['requirements'] = requirements(row.get('capabilities'))
    difficulty = row.get('difficulty') or {}
    content['design']['difficulty'].update(score=difficulty.get('score'), basis=difficulty.get('note', ''))
    kind = source['kind']
    consumer = {'resource': 'game/world/components/platforming_module.gd',
                'forest': 'game/world/generation/thorn_forest_region_assembler.gd',
                'foundry': 'game/world/generation/foundry_world.gd'}.get(kind, source_file)
    content['runtime'].update(consumer=consumer, format='source_' + kind,
                              binding=source_file, integration='unverified',
                              note='保留原消费者；旧接入签名已漂移。此sidecar不反写mapnote，也不声明新准入。')
    content['provenance']['artifacts'].append(artifact(REVIEWS))
    content['provenance']['license_note'] = '原项目参考内容；原始mapnote文档SHA和旧提交保留在import_summary，未重新许可或授予准入。'
    review = row.get('ai_design', {})
    if review.get('status') == 'reviewed':
        findings = [*review.get('strengths', []), *review.get('problems', []),
                    *['待反证：' + t for t in review.get('counterfactual', [])],
                    *['局限：' + t for t in review.get('uncertainty', [])]]
        content['identity']['player_experience'] = review.get('role', '源码意图待核实')
        content['design']['goals'] = [review.get('role', '待取证')]
        content['design']['recovery'] = '源码设计初审，真实失败回收仍待匹配消费者取证。'
        content['evidence']['ai'].update(status='reviewed', reviewer=review['reviewer'],
                                        findings=findings, artifacts=[artifact(REVIEWS)])
        decision = review['decision']
        content['quality'].update(admission={'retain': 'review', 'improve': 'rework',
                                            'reconstruct': 'rework', 'retire': 'discard',
                                            'needs_evidence': 'candidate'}[decision],
                                  reason='AI源码初审：' + decision + '；不授予物理、真人或正式池认可。')
    return content


def factory_marks(blueprint):
    """Narrow extraction of explicit factory metadata; drift refuses, not guessed."""
    source = (ROOT / PRODUCER).read_text()
    match = re.search(r'(?:if|elif) blueprint == "' + re.escape(blueprint) + r'":(.*?)(?=\n\telif blueprint|\n\telse:)', source, re.S)
    if not match:
        raise ValueError('Pilot factory metadata not extractable: ' + blueprint)
    text = match.group(1)
    one_way = re.search(r'one_way_platform_indices\.assign\((\[[^\]]*\])\)', text)
    reward = re.search(r'reward_index = (\d+); return_index = (\d+)', text)
    if not one_way or not reward:
        raise ValueError('Explicit pilot platform/reward metadata missing: ' + blueprint)
    return set(json.loads(one_way.group(1))), int(reward.group(1)), int(reward.group(2))


def sample_port(name, frame):
    return {'id': name, 'direction': 'entry' if name == 'observed_entry' else 'exit',
            'position': frame['position'], 'velocity_x': [frame['velocity'][0]] * 2,
            'velocity_y': [frame['velocity'][1]] * 2,
            'states': ['grounded' if frame['grounded'] else 'airborne'],
            'resources': {'air_shots': [frame['shots']] * 2, 'stamina': [frame['stamina']] * 2},
            'capabilities': [], 'phase': 'single_observed_policy_sample', 'coordinate_frame': 'module_world'}


def pilot_content(item, entries, commit, verified_conditions):
    # Prefer a successful reward trace for diagram; a failed definition remains
    # inspectable as a failed candidate, never replaced by invented geometry.
    ordered = sorted(entries, key=lambda v: (not v[1].get('passed'), v[1].get('strategy') != 'reward'))
    raw_path, raw = ordered[0]
    one_way, reward_index, return_index = factory_marks(raw['blueprint'])
    content = make_content(item['id'], 'module', item['region'], PRODUCER, commit, artifact(PRODUCER)['sha256'])
    content['version'] = int(item.get('definition_version', 1))
    content['identity'].update(name=item['id'], player_experience=item['gene']['decision'],
                               gameplay_genes=item['gene'].get('relations', []), composition_status='decomposed')
    content['runtime'].update(consumer=raw['runtime_consumer'], format='PlatformingModuleDefinition',
                              binding=PRODUCER + '#' + raw['blueprint'], integration='development_source',
                              note='隔离fixture；未接正式地图。端口为真实单轨迹状态样本，不能当全入口容错包络。')
    content['provenance']['artifacts'].append(artifact('config/level_pilot_candidates.json'))
    content['lineage'].update(parents=[item['parent']], variant_family=raw['blueprint'],
                              changes=['本轮有限工厂关系组合；非新移动原语。'])
    content['design'].update(goals=[item['gene']['decision']],
                             tolerance='未测完整输入扰动包络；单策略成功不等于真人成功率。',
                             recovery='仅证明所列奖励位置与回程标记；没有正式奖励实体或交易。',
                             rhythm=['观察出发支持', '主路或自愿奖励路线', '稳定接收'],
                             alternative_solutions=['main', 'reward', 'direct：有限强替代采样', 'no_jump：动作消融'])
    cells = []
    for index, rect in enumerate(raw['geometry']):
        cell_id = item['id'] + '/surface-' + str(index)
        cell = make_content(cell_id, 'cell', item['region'], PRODUCER, commit, artifact(PRODUCER)['sha256'])
        cell['identity'].update(name=('单向支承' if index in one_way else '实体支承') + str(index),
                                player_experience='提供源工厂声明的接触面，不独立宣称挑战价值。',
                                composition_status='decomposed', elements=[{
                                    'id': 'surface', 'kind': 'one_way' if index in one_way else 'solid',
                                    'parameters': {'rect': [0, 0, rect[2], rect[3]],
                                                   'source_rect_index': index}}])
        cell['runtime'].update(consumer=raw['runtime_consumer'], format='PlatformingModuleDefinition.platforms',
                               binding=PRODUCER + '#' + raw['blueprint'] + '/platforms/' + str(index),
                               note='从该次真实definition几何与同SHA工厂的显式one_way数组提取；未独立物理准入。')
        cells.append(cell)
        content['parts'].append({'id': 'surface-' + str(index), 'content_id': cell_id,
                                  'layer': 'cell', 'version': 1, 'offset': rect[:2]})
    content['identity']['elements'] = [{'id': 'reward_location', 'kind': 'reachability_marker',
        'parameters': {'position': raw['anchors'][reward_index], 'actual_claim': False}}]
    for role in ('main', 'reward'):
        route = raw['routes'][role]
        for index in route:
            node = 'anchor-' + str(index)
            if node not in content['topology']['nodes']: content['topology']['nodes'].append(node)
        for start, end in zip(route, route[1:]):
            edge_role = 'main' if role == 'main' else ('return' if start == reward_index else 'branch')
            content['topology']['edges'].append({'from': 'anchor-' + str(start), 'to': 'anchor-' + str(end),
                 'role': edge_role, 'requirements': {**requirements(), 'status': 'defined'}, 'grants': [],
                 'risk_reward': '源路线顺序；reward仅位置标记，不是领取事件。'})
    content['topology'].update(entry=['anchor-' + str(raw['routes']['main'][0])],
                               goals=['anchor-' + str(raw['routes']['main'][-1])],
                               return_policy='按reward路线回返标记；末次原生轨迹核验，非正式交易。')
    content['ports'] = [sample_port('observed_entry', raw['frames'][0]), sample_port('observed_exit', raw['frames'][-1])]
    by_strategy = {r['strategy']: (p, r) for p, r in entries}
    positives = [by_strategy[s] for s in ('main', 'reward') if s in by_strategy]
    complete = len(positives) == 2 and all(r.get('passed') is True and r['strategy'] in verified_conditions
                                          for _, r in positives)
    content['evidence']['technical'].update(status='passed' if complete else 'failed', method='real_motor',
                                            scope=PILOT_SCOPE, artifacts=[a for p, r in positives
                                                for a in (artifact(p), artifact(p.with_name('receipt.json')))])
    content['lineage']['failure_refs'] = [artifact(p) for p, r in entries if not r.get('passed')]
    content['quality'].update(admission='review' if complete else 'rework',
                              reason='主路及奖励位置往返均有同源原生证明；仍待设计与真人评价。' if complete else
                                     '本轮正向路线仍失败，保留失败并停止扩产；不从driver失败推断物理无解。')
    return cells, content, raw, one_way, reward_index, return_index


def svg(path, content, raw, one_way, reward_index, return_index):
    width, height = 1120, 700
    sx, ox, oy = 1.18, 60, 215
    def point(p): return f'{ox+p[0]*sx:.2f},{oy+p[1]*sx:.2f}'
    def text(x, y, value, size=15, color='#e2e8f0'):
        return f'<text x="{x}" y="{y}" fill="{color}" font-size="{size}" font-family="sans-serif">{html.escape(str(value))}</text>'
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
             '<rect width="100%" height="100%" fill="#111827"/>', text(30, 36, content['id'], 24),
             text(30, 64, 'SOURCE GEOMETRY + AUTHORED ROUTES + ONE REAL MOTOR TRACE'),
             text(30, 88, 'Prototype only. Reward location is not a claim transaction. No visual / human fun acceptance.', 13)]
    for index, r in enumerate(raw['geometry']):
        x,y,w,h = r
        color = '#6366f1' if index in one_way else '#475569'
        parts.append(f'<rect x="{ox+x*sx:.2f}" y="{oy+y*sx:.2f}" width="{w*sx:.2f}" height="{h*sx:.2f}" fill="{color}" stroke="#cbd5e1"/>')
        parts.append(text(ox+x*sx+4, oy+y*sx+15, 'C'+str(index), 11))
    for name, color in (('main', '#38bdf8'), ('reward', '#fbbf24')):
        route = raw['routes'][name]
        points = ' '.join(point(raw['anchors'][i]) for i in route)
        parts.append(f'<polyline points="{points}" fill="none" stroke="{color}" stroke-width="2" stroke-dasharray="7 5" opacity="0.9"/>')
    positions = raw['frames'][::3] + [raw['frames'][-1]]
    parts.append(f'<polyline points="{" ".join(point(f["position"]) for f in positions)}" fill="none" stroke="#34d399" stroke-width="2.2"/>')
    for i, at in enumerate(raw['anchors']):
        px,py = map(float, point(at).split(','))
        parts.append(f'<circle cx="{px}" cy="{py}" r="4" fill="#f8fafc"/>')
        parts.append(text(px+6,py-7,i,11))
    for index, label in ((reward_index,'reward location'), (return_index,'return marker')):
        px,py = map(float, point(raw['anchors'][index]).split(','))
        parts.append(text(px-24,py-29,label,12,'#fbbf24'))
    parts.extend([text(30, 628, 'Blue dashed: authored main | Gold dashed: authored branch/return | Green: recorded trajectory', 14),
                  text(30, 653, f"Trace: {raw['strategy']} / frames={len(raw['frames'])} / passed={raw['passed']} / max_air_shots={raw['tuning']['max_air_shots']}", 14),
                  text(30, 678, 'Cell labels preserve source dimensions; dashed segments are intent, not physical motion.', 13), '</svg>'])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('\n'.join(parts))


def build(args):
    analysis_path, pilot_path = Path(args.analysis).resolve(), Path(args.pilot).resolve()
    analysis, pilot = json.loads(analysis_path.read_text()), json.loads(pilot_path.read_text())
    output = Path(args.output).resolve()
    if not output.is_relative_to(ROOT / 'build'):
        raise ValueError('Generated artifacts must remain under build/')
    contents = [legacy_content(r) for r in analysis['modules']]
    commit = pilot['source_commit']
    catalog = json.loads((ROOT / 'config/level_pilot_candidates.json').read_text())
    grouped = defaultdict(list)
    verified = defaultdict(set)
    for result in pilot['results']:
        if result['id'] not in PILOTS or result.get('variant') != 0: continue
        raw_path = ROOT / result['raw_path']
        if sha(raw_path) != result['raw_sha256']: raise ValueError('Raw receipt byte mismatch')
        if result.get('ok') is True:
            if not verified_result(pilot, result, pilot_path):
                raise ValueError('Claimed positive native proof rejected: ' + result['id'] + '/' + result['condition'])
            verified[result['id']].add(result['condition'])
        grouped[result['id']].append((raw_path, json.loads(raw_path.read_text())))
    diagrams = []
    for item in catalog['candidates']:
        if item['id'] not in PILOTS: continue
        if not grouped[item['id']]: raise ValueError('Missing real pilot: ' + item['id'])
        cells, content, raw, one_way, reward_index, return_index = pilot_content(item, grouped[item['id']], commit, verified[item['id']])
        contents.extend(cells); contents.append(content)
        target = output / 'diagrams' / (item['id'] + '.svg')
        svg(target, content, raw, one_way, reward_index, return_index)
        diagrams.append({'id': item['id'], 'file': str(target.relative_to(output)),
                         'sha256': sha(target), 'trace_strategy': raw['strategy'], 'physical_pass': raw['passed']})
    batch_path = 'resources/foundry/batch.json'
    itinerary = json.loads((ROOT / batch_path).read_text())['itineraries'][0]
    macro = make_content('example/' + itinerary['id'], 'macro_module', '工坊', batch_path, commit, artifact(batch_path)['sha256'])
    macro['identity'].update(name='现有Foundry连续路线的Macro解释',
                              player_experience='连续资源与接缝责任；各模块分别通过不能推出整段通过。', composition_status='decomposed')
    macro['parts'] = [{'id': 'node-' + str(i), 'content_id': n['module_id'], 'layer': 'module',
                      'version': 1, 'offset': n['offset']} for i,n in enumerate(itinerary['nodes'])]
    macro['identity']['elements'] = [{'id': 'manifest', 'kind': 'existing_foundry_itinerary',
                                      'parameters': {'id': itinerary['id'], 'hash': itinerary['hash'],
                                                     'boundaries': itinerary['boundaries'], 'capability_profile': itinerary['capability_profile']}}]
    macro['runtime'].update(consumer='game/world/generation/foundry_world.gd', format='Foundry itinerary schema1',
                            binding=batch_path + '#' + itinerary['id'], integration='development_source',
                            note='只解释现有扁平nodes，不新增Macro消费者；旧batch证据不重签为本轮fresh物理。')
    macro['quality']['reason'] = 'Macro设计映射样例；当前仅来源/结构提取，连续Motor与趣味仍未验。'
    contents.append(macro)
    map_path = 'game/world/generation/plains_region_generator.gd'
    area = make_content('example/windchime_plains_map', 'map', '风铃平原', map_path, commit, artifact(map_path)['sha256'])
    area['identity'].update(name='现有风铃平原Map消费者绑定',
                             player_experience='完整地区的探索拓扑、能力锁与区域节奏；保留既有生成器负责。')
    area['runtime'].update(consumer='game/world/generation/plains_region_assembler.gd', format='PlainsRegionGenerator Manifest',
                           binding=map_path + '#generate', integration='formal_source',
                           note='此导出未运行整图生成器，故不伪造Seed、拓扑或Map物理。Map可直接引用Module/Cell；不强制经过Macro。')
    area['quality']['reason'] = '仅真实生成器/装配器绑定；未提取某个Map实例，拓扑留空，不作运行验收。'
    contents.append(area)
    capabilities = sorted({a for c in contents for a in c['requirements']['all_of']} |
                          {a for c in contents for group in c['requirements']['any_of_groups'] for a in group})
    bundle = {'schema_version': 1, 'artifact_kind': 'level_content_bundle',
              'capability_catalog': capabilities, 'contents': contents, 'connections': []}
    errors = validate_bundle(bundle, ROOT)
    write(output / 'bundle.json', bundle)
    report = {'schema_version': 1, 'status': 'valid_design_declaration' if not errors else 'invalid',
              'errors': errors, 'counts': dict(Counter(c['layer'] for c in contents)),
              'legacy_source_records': len(analysis['modules']), 'diagrams': diagrams,
              'inputs': [artifact(analysis_path), artifact(pilot_path)],
              'limits': ['Source/trace diagrams are not recordings.', 'Map instance topology was not extracted.',
                         'No new runtime consumer, formal pool admission, reward transaction or human acceptance.']}
    write(output / 'export_report.json', report)
    if errors: raise ValueError('Design declaration rejected: ' + '; '.join(errors[:5]))
    print(f'CONTENT EXPORT: {len(contents)} evidence-bound declarations, {len(diagrams)} source/trace diagrams; human unverified')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--analysis', required=True)
    parser.add_argument('--pilot', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    try: build(args)
    except (OSError, ValueError, KeyError) as error:
        parser.exit(1, 'CONTENT EXPORT REJECTED: ' + str(error) + '\n')


if __name__ == '__main__': main()
