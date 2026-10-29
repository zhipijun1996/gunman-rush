#!/usr/bin/env python3
"""Append immutable plains recordings to a monster-workshop catalog.

Data/poster preparation only: no Godot, network, API, database or deployment.
The source catalog is read-only unless the caller explicitly chooses it as the
output. Existing clip IDs/revisions/actions remain available for saved reviews.
"""
from __future__ import annotations

import argparse
import copy
from fractions import Fraction
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


GAME = Path('/workspace/gunman-rush')
SITE = Path('/workspace/sites/monster-workshop')
SPECIES = ('patrol_drone', 'plains_charger', 'plains_diver', 'plains_hopper',
           'plains_sentry', 'plains_fan_sentry', 'plains_root_bell')
BEHAVIOR_TO_SPECIES = dict(zip(('patrol', 'charger', 'diver', 'hopper', 'sentry',
                              'fan_sentry', 'root_bell'), SPECIES))
PERSISTENT = {'plains_charger', 'plains_diver'}
CORE = [('living_body', '待机／移动'), ('telegraph', '蓄势'), ('attack', '出手'),
        ('attack_recovery', '收招'), ('nonlethal_hurt', '受伤'),
        ('hurt_recovery', '受伤恢复'), ('death', '死亡'),
        ('terminal_observation', '终态／留尸')]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def load(path):
    return json.loads(Path(path).read_text())


def atomic_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    pending = path.with_suffix(path.suffix + '.tmp')
    pending.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    pending.replace(path)


def number(value):
    return type(value) in (int, float) and math.isfinite(value)


def integer(value, label):
    require(number(value) and float(value).is_integer() and value >= 0,
            'Expected nonnegative frame integer: ' + label)
    return int(value)


def probe(movie):
    data = json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json',
        str(movie)], timeout=30))
    video = next(row for row in data['streams'] if row['codec_type'] == 'video')
    duration = float(data['format']['duration'])
    require(Fraction(video['avg_frame_rate']) == 60 and duration > 0,
            'Expected normal-speed 60fps original MP4')
    frames = integer(int(video['nb_frames']), 'ffprobe.nb_frames')
    require(abs(frames / 60 - duration) <= 1 / 60 + 1e-6,
            'Movie frame count/duration mismatch')
    require(any(row['codec_type'] == 'audio' for row in data['streams']),
            'Original movie audio stream missing')
    return {'duration': duration, 'frames': frames, 'fps': 60,
            'width': video['width'], 'height': video['height'], 'probe': data}


def git_commit(commit):
    require(re.fullmatch(r'[0-9a-f]{40}', commit) is not None,
            'Exact 40-character Git commit required')
    subprocess.run(['git', '-C', str(GAME), 'cat-file', '-e', commit + '^{commit}'],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


def committed_media_matches(commit, repository_path, movie):
    require(repository_path.startswith('docs/evidence/') and
            repository_path.endswith('.mp4') and
            '..' not in Path(repository_path).parts and
            not Path(repository_path).is_absolute(), 'Unsafe repository media path')
    process = subprocess.Popen(['git', '-C', str(GAME), 'show', commit + ':' + repository_path],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    checksum = hashlib.sha256()
    size = 0
    while chunk := process.stdout.read(1024 * 1024):
        checksum.update(chunk)
        size += len(chunk)
    error = process.stderr.read()
    require(process.wait(timeout=30) == 0,
            'Media does not exist in exact publication commit: ' + error.decode(errors='replace')[:300])
    require(size == movie.stat().st_size and checksum.hexdigest() == sha(movie),
            'Published Git media bytes differ from local original MP4')


def movie_identity(movie, game_commit, media_commit, repository_path, prefix):
    info = probe(movie)
    checksum = sha(movie)
    committed_media_matches(media_commit, repository_path, movie)
    media_id = prefix + '-' + checksum[:12]
    return {**info, 'media_id': media_id, 'media_sha256': checksum,
            'source_video_url': 'https://raw.githubusercontent.com/zhipijun1996/gunman-rush/' + media_commit + '/' + repository_path,
            'video_url': '/media/' + media_id, 'game_commit': game_commit,
            'media_commit': media_commit, 'local_movie': str(movie),
            'repository_path': repository_path}


def capture_report(trace_path, movie, game_commit):
    path = trace_path.with_name('report.json')
    require(path.is_file(), 'Original recording wrapper report.json is required beside trace')
    report = load(path)
    require(report.get('source_stable') is True and
            report.get('source', {}).get('commit') == game_commit and
            not report.get('source', {}).get('git_status') and
            not report.get('source', {}).get('working_files'),
            'Recording must have clean, stable source at the supplied exact game commit')
    require(report.get('status') in ('recorded_complete_coverage', 'recorded_with_coverage_gaps') and
            report.get('execution', {}).get('exit_code') == 0 and
            report.get('execution', {}).get('failure_reason') is None,
            'Original engine recording did not complete successfully')
    require(report.get('mp4_sha256') == sha(movie) and report.get('trace_sha256') == sha(trace_path),
            'MP4/trace bytes differ from original wrapper report')
    return {'path': str(path), 'sha256': sha(path), 'status': report['status'],
            'source_stable': True, 'clean_source_commit': game_commit}


def process_frame(row):
    require('movie_process_frame_after_draw' in row and 'visual_after_draw' in row,
            'Actual post-draw frame receipts required; active frame number is not movie time')
    return integer(row['movie_process_frame_after_draw'], 'movie_process_frame_after_draw')


def time_of(row):
    return process_frame(row) / 60


def visual(row):
    return row['visual_after_draw']


def body_visible(row):
    receipt = visual(row)
    return receipt.get('host_visible') is True and receipt.get('host_alpha', 0) > 0.05


def remains_visible(row):
    receipt = visual(row).get('remains', {})
    return receipt.get('visible') is True and receipt.get('alpha', 0) > 0.05


def settled_visible(row):
    return remains_visible(row) and visual(row)['remains'].get('settled') is True


def first_run(rows, predicate):
    selected = []
    for row in rows:
        if predicate(row):
            selected.append(row)
        elif selected:
            break
    return selected


def span(rows, note):
    return (time_of(rows[0]), time_of(rows[-1]) + 1 / 60, note) if rows else None


def action(key, label, bounds, segment=None, na=False):
    start, end = (max(bounds[0], segment[0]), min(bounds[1], segment[1])) if segment else (None, None)
    if start is not None and end <= start:
        segment = None
        start = end = None
    return {'id': key, 'label': label,
            'status': 'not_applicable' if na else 'recorded' if segment else 'missing',
            'start': None if na else start, 'end': None if na else end,
            'note': '持续接触型没有独立蓄势／攻击收招。' if na else
            segment[2] if segment else '本录片没有足够真实事件／绘制证据；不推断实现已完成。'}


def action_segments(case, rows, bounds):
    events = case.get('events', [])
    require(all(event.get('amount', 0) < 0 and event.get('event_id') for event in events),
            'Only actual accepted damage event receipts are allowed')
    death = next((event for event in events if event.get('terminal') is True), None)
    hit = next((event for event in events if event.get('terminal') is False), None)
    alive = [row for row in rows if row['HP'] > 0 and row.get('player_HP', 1) > 0 and
             (death is None or row['frame'] < death['frame'])]
    living = next((row for row in alive if body_visible(row)), None)
    require(living is not None, 'No actual visible living sample for ' + case['id'])
    segments = {'living_body': (time_of(living), min(time_of(living) + 1, time_of(alive[-1]) + 1 / 60),
                               '真实活体初始绘制；根体／悬停体不以平移作为完成条件。')}
    for key, states in [('telegraph', {'telegraph'}),
                        ('attack', {'patrol'} if case['id'] == 'patrol_drone' else {'attack'}),
                        ('attack_recovery', {'recovery', 'blocked'})]:
        segments[key] = span(first_run(alive, lambda row: row['state'] in states),
                             '真实活态 AI 相位；不代表全部方向、攻击分支或命中组合已验。')
    hurt_rows = []
    exit_row = None
    if hit:
        for row in alive:
            if row['frame'] < hit['frame']:
                continue
            value = visual(row).get('hurt_remaining')
            if number(value) and value > 0:
                hurt_rows.append(row)
            elif hurt_rows and number(value) and value <= 0:
                exit_row = row
                break
    segments['nonlethal_hurt'] = span(hurt_rows, '实际接受非致死 HP 事件＋postdraw hurt_remaining>0；连续身体关节，不以H素材格计数。')
    if exit_row:
        segments['hurt_recovery'] = (time_of(exit_row), min(bounds[1], time_of(exit_row) + 0.5,
            time_of(next(row for row in rows if row['frame'] >= death['frame'])) if death else bounds[1]),
            'postdraw hurt_remaining 真实归零、HP仍存活，返回当时真实AI相位。')
    death_rows = [row for row in rows if death is not None and row['frame'] >= death['frame']]
    settled = next((row for row in death_rows if settled_visible(row)), None)
    faded = next((row for row in death_rows if settled is not None and
                  row['frame'] > settled['frame'] and not remains_visible(row) and
                  not body_visible(row)), None)
    persistent = case['id'] in PERSISTENT
    finished = settled if persistent else faded
    if death_rows and finished:
        segments['death'] = (time_of(death_rows[0]), time_of(finished) + 1 / 60,
            '真实致死提交→失力／落地→稳定留尸。连续骨骼/网格姿态，报告frame_index不是D素材格。' if persistent else
            '真实致死提交→失力／落地→稳定短留→实际绘制消失；终点来自postdraw回执，不套固定死亡秒数。')
    elif death_rows and not any(visual(row).get('remains') for row in death_rows):
        # This fallback is solely for retained old traces used to check the
        # converter. New rig traces always have their own remains component.
        hidden = next((row for row in death_rows if not body_visible(row)), None)
        if hidden:
            segments['death'] = (time_of(death_rows[0]), time_of(hidden) + 1 / 60,
                                 '旧身体真实致死到隐藏；没有新rig落位/淡出的证据，不代签新动作。')
    terminal_start = settled if persistent else faded
    if terminal_start:
        tail = [row for row in rows if row['frame'] >= terminal_start['frame']]
        if len(tail) >= 2:
            stable_tail = rows[-210:] if persistent else tail
            transforms = [(visual(row).get('remains', {}).get('position'),
                           visual(row).get('remains', {}).get('rotation'),
                           visual(row).get('remains', {}).get('scale')) for row in stable_tail]
            stable = (len(stable_tail) == 210 and all(settled_visible(row) for row in stable_tail) and
                      all(value == transforms[0] for value in transforms)) if persistent else False
            if persistent:
                note = ('实际接地settled后连续210帧可见，尸体位置／旋转／缩放恒定；仍待像素与用户审查。'
                        if stable else '真实settled尸体观察；本片不足以证明稳定留尸210帧。')
            else:
                note = '短留和淡出完成后的实际隐藏终态；不生成持久尸体。'
            segments['terminal_observation'] = (time_of(stable_tail[0]), bounds[1], note)
    actions = [action(key, label, bounds, segments.get(key),
                      na=case['id'] == 'patrol_drone' and key in ('telegraph', 'attack_recovery'))
               for key, label in CORE]
    observations = {'accepted_nonlethal_event': hit, 'accepted_lethal_event': death,
                    'first_settled_movie_process_frame': process_frame(settled) if settled else None,
                    'first_hidden_after_settled_movie_process_frame': process_frame(faded) if faded else None,
                    'action_basis': 'Actual accepted HP/AI/postdraw receipts; no inferred authored H/D cells'}
    return actions, living, observations


def common_variant(identity, variant_id, revision, label, bounds, context, actions):
    return {'id': variant_id, 'label': label, 'revision': revision,
            'game_commit': identity['game_commit'], 'is_current': True,
            'capture_status': 'recorded',
            **{key: identity[key] for key in ('media_id', 'media_sha256', 'source_video_url', 'video_url')},
            'poster_url': '/posters/' + variant_id + '.jpg', 'in': bounds[0], 'out': bounds[1],
            'duration': identity['duration'], 'fps': 60, 'context': context, 'actions': actions}


def combat_variants(trace, identity):
    require(trace.get('complete') is True and not trace.get('failures'), 'Incomplete/failed combat trace')
    require(trace.get('conditions', {}).get('fps') == 60 and
            trace.get('conditions', {}).get('source_HP_state_AI_injection') is False,
            'Expected original real-AI/InputRouter recording conditions')
    selected = [case for case in trace['cases'] if case['id'] in SPECIES and case['chain'] == 'underworld']
    require(len(selected) == 7 and {case['id'] for case in selected} == set(SPECIES),
            'Exactly one real Underworld combat case per seven plains species required')
    by_case = {}
    for row in trace['frames']:
        by_case.setdefault(row['case'], []).append(row)
    variants, posters, proofs = [], [], []
    for case in selected:
        require(case.get('fixture', {}).get('production_AI_enabled') is True,
                'Disabled combat AI cannot be published as an action chain')
        rows = by_case[case['case']]
        start = integer(case['movie_start_process_frame'], 'case.start')
        end = integer(case['movie_end_process_frame'], 'case.end')
        bounds = (start / 60, end / 60)
        require(abs(case['start_seconds'] - bounds[0]) < 1e-8 and
                abs(case['end_seconds'] - bounds[1]) < 1e-8,
                'Case movie-process-frame timestamps disagree')
        require(0 <= bounds[0] < bounds[1] <= identity['duration'] + 1e-6,
                'Original chapter lies outside MP4')
        require(all(start <= process_frame(row) <= end for row in rows),
                'Row movie timestamps escaped original chapter')
        require([row['frame'] for row in rows] == list(range(rows[0]['frame'], rows[-1]['frame'] + 1)),
                'Combat active frame trace has gaps')
        require(all(process_frame(a) < process_frame(b) for a, b in zip(rows, rows[1:])),
                'Postdraw movie-frame trace is not strictly increasing')
        actions, living, observations = action_segments(case, rows, bounds)
        variant_id = case['id'] + '-plains-revision-' + identity['game_commit'][:12] + '-' + identity['media_sha256'][:12] + '-' + str(case['case'])
        revision = identity['game_commit'] + ':' + identity['media_sha256'] + ':case=' + str(case['case']) + ':chain=underworld:entry=' + case['id']
        context = ('当前用户意见返工实录；明示初始实验场地／站位，真实AI、InputRouter、弹体与接受伤害；不是自然全关。'
                   '除俯冲沿原身体帧外，其余为同一中性母版的连续骨骼/网格，不把frame_index计成H/D素材。'
                   '0个basic coverage缺口也不等于完整动作、全部方向、像素或用户验收。')
        if case.get('coverage_gaps'):
            context += ' 本章保留实际缺口：' + '；'.join(case['coverage_gaps'])
        variant = common_variant(identity, variant_id, revision, '当前 · 平原逐怪返工实录', bounds, context, actions)
        variants.append((case['id'], variant))
        posters.append({'variant': variant_id, 'frame': process_frame(living), 'species': case['id'],
                        'basis': 'First real alive, host-visible alpha-positive postdraw frame'})
        proofs.append({'species': case['id'], 'case': case['case'], 'chain': 'underworld',
                       'movie_start_process_frame': start, 'movie_end_process_frame': end,
                       'coverage': case.get('coverage', {}), 'coverage_gaps': case.get('coverage_gaps', []),
                       **observations})
    return variants, posters, proofs


def comparison_variants(trace, identity, game_commit):
    require(trace.get('kind') == 'staged_scale_comparison' and trace.get('complete') is True and
            not trace.get('failures') and trace.get('source_stable') is True and
            trace.get('source_before') == trace.get('source_after'), 'Comparison source/trace failed')
    require(trace.get('git_before') == trace.get('git_after') and
            trace.get('git_before', {}).get('head') == game_commit and
            not trace.get('git_before', {}).get('status'), 'Comparison requires same exact clean game commit')
    require(trace.get('fps') == 60 and trace.get('entry') == 'DemoApp.start_plains' and
            trace.get('original_manifest_unchanged') is True, 'Not an unchanged real plains comparison')
    pages = trace['pages']
    require(len(pages) == 6 and {page['species'] for page in pages} == set(BEHAVIOR_TO_SPECIES) - {'diver'},
            'Expected the six revised species compared against retained diver')
    variants, posters, proofs = [], [], []
    for page in pages:
        species = BEHAVIOR_TO_SPECIES[page['species']]
        rows = [row for row in trace['frames'] if row['page'] == page['page']]
        require(len(rows) == page['observed_frames'] and len(rows) >= 2, 'Comparison page incomplete')
        require(page.get('revised', {}).get('comparison_AI_disabled') is True and
                page.get('reference', {}).get('comparison_AI_disabled') is True,
                'Comparison disclosure must match actual disabled sample AI')
        start = integer(page['start_movie_process_frame'], 'comparison.start')
        end = integer(page['end_movie_process_frame'], 'comparison.end')
        bounds = (start / 60, end / 60)
        require(0 <= bounds[0] < bounds[1] <= identity['duration'] + 1e-6, 'Comparison page outside movie')
        require(all(start <= row['movie_process_frame'] <= end for row in rows), 'Comparison row escaped page')
        variant_id = species + '-scale-comparison-' + game_commit[:12] + '-' + identity['media_sha256'][:12]
        revision = game_commit + ':' + identity['media_sha256'] + ':page=' + str(page['page']) + ':chain=staged_scale_comparison:entry=' + species
        note = ('实际DemoApp平原、原玩家与保留俯冲怪同屏；该展示样本AI／玩家输入被明确held，'
                '仅身体比例与配色观察，不是战斗、自然路线或碰撞自动验收。')
        actions = [action('scale_comparison', '真实平原同屏比例', bounds,
                          (bounds[0], bounds[1], note))]
        variant = common_variant(identity, variant_id, revision, '当前 · 真实平原同屏比例（静态展示）',
                                 bounds, note + ' 没有本页八项战斗动作证据；认可只针对这段同屏比例。', actions)
        variants.append((species, variant))
        posters.append({'variant': variant_id,
                        'frame': integer(rows[0]['movie_process_frame'], 'comparison.poster'),
                        'species': species, 'basis': 'First actual comparison-page movie process frame'})
        proofs.append({'species': species, 'page': page['page'],
                       'movie_start_process_frame': start, 'movie_end_process_frame': end,
                       'observed_frames': page['observed_frames'], 'combat_evidence': False})
    return variants, posters, proofs


def make_posters(movie, identity, selections, folder):
    folder.mkdir(parents=True, exist_ok=True)
    indices = sorted({row['frame'] for row in selections})
    require(all(0 <= frame < identity['frames'] for frame in indices), 'Poster frame outside decoded movie')
    with tempfile.TemporaryDirectory(prefix='plains-workshop-posters-') as temporary:
        template = Path(temporary) / 'frame-%04d.jpg'
        expression = '+'.join('eq(n\\,' + str(frame) + ')' for frame in indices)
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(movie),
                        '-vf', 'select=' + expression, '-vsync', '0', '-frames:v', str(len(indices)),
                        '-q:v', '3', str(template)], check=True, timeout=180,
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        extracted = sorted(Path(temporary).glob('frame-*.jpg'))
        require(len(extracted) == len(indices) and all(path.stat().st_size > 0 for path in extracted),
                'Could not decode every actual poster frame')
        by_frame = dict(zip(indices, extracted))
        result = []
        for selection in selections:
            path = folder / (selection['variant'] + '.jpg')
            shutil.copyfile(by_frame[selection['frame']], path)
            result.append({**selection, 'path': str(path), 'sha256': sha(path),
                           'timestamp_seconds': selection['frame'] / 60,
                           'processing': 'Single original decoded movie frame; JPEG only; no crop, resize, repaint or composite'})
    return result


def validate_catalog(catalog):
    require(catalog.get('schema_version') == 1 and len(catalog.get('monsters', [])) == 25,
            'Expected exact existing 25-entry Site catalog')
    ids, revisions, media = set(), set(), {}
    for monster in catalog['monsters']:
        require(any(variant.get('is_current') is True for variant in monster['variants']), 'Missing current monster version')
        for variant in monster['variants']:
            require(variant['id'] not in ids and variant['revision'] not in revisions, 'Duplicate immutable clip identity')
            ids.add(variant['id']); revisions.add(variant['revision'])
            require(variant['capture_status'] == 'recorded' and variant['video_url'] == '/media/' + variant['media_id'],
                    'Every retained recorded clip must remain playable')
            require(0 <= variant['in'] < variant['out'] <= variant['duration'] + 1 / 60, 'Invalid clip bounds')
            fingerprint = (variant['source_video_url'], variant['media_sha256'], variant['duration'])
            require(variant['media_id'] not in media or media[variant['media_id']] == fingerprint, 'Ambiguous media ID')
            media[variant['media_id']] = fingerprint
            actions = set()
            for row in variant['actions']:
                require(row['id'] not in actions, 'Duplicate action ID')
                actions.add(row['id'])
                require(row['status'] in ('recorded', 'missing', 'not_applicable'), 'Unknown action status')
                if row['status'] == 'recorded':
                    require(number(row['start']) and number(row['end']) and
                            variant['in'] <= row['start'] < row['end'] <= variant['out'], 'Action escaped clip')
                else:
                    require(row['start'] is None and row['end'] is None, 'Missing/N/A actions cannot have fake ranges')
    return {'monsters': 25, 'variants': len(ids), 'media': len(media)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--trace', type=Path, required=True)
    parser.add_argument('--movie', type=Path, required=True)
    parser.add_argument('--game-commit', required=True)
    parser.add_argument('--media-commit', required=True)
    parser.add_argument('--output-catalog', type=Path, required=True)
    parser.add_argument('--posters-dir', type=Path, required=True)
    parser.add_argument('--source-catalog', type=Path, default=SITE / 'data/catalog.json')
    parser.add_argument('--media-path', default='docs/evidence/plains_monster_revision_01/media/plains.mp4')
    parser.add_argument('--comparison-trace', type=Path)
    parser.add_argument('--comparison-movie', type=Path)
    parser.add_argument('--comparison-media-path', default='docs/evidence/plains_monster_revision_01/media/comparison.mp4')
    parser.add_argument('--output-proof', type=Path)
    args = parser.parse_args()
    require(bool(args.comparison_trace) == bool(args.comparison_movie), 'Supply both comparison trace and movie, or neither')
    for commit in (args.game_commit, args.media_commit): git_commit(commit)
    catalog = load(args.source_catalog)
    original = copy.deepcopy(catalog)
    validate_catalog(catalog)
    identity = movie_identity(args.movie, args.game_commit, args.media_commit, args.media_path, 'plains-revision')
    wrapper = capture_report(args.trace, args.movie, args.game_commit)
    variants, poster_requests, proofs = combat_variants(load(args.trace), identity)
    poster_groups = [(args.movie, identity, poster_requests)]
    comparison_proofs = []
    identities = [identity]
    if args.comparison_trace:
        comparison_identity = movie_identity(args.comparison_movie, args.game_commit, args.media_commit,
                                             args.comparison_media_path, 'plains-revision-comparison')
        more_variants, more_posters, comparison_proofs = comparison_variants(load(args.comparison_trace), comparison_identity, args.game_commit)
        variants.extend(more_variants)
        poster_groups.append((args.comparison_movie, comparison_identity, more_posters))
        identities.append(comparison_identity)
    existing_ids = {variant['id'] for monster in catalog['monsters'] for variant in monster['variants']}
    existing_revisions = {variant['revision'] for monster in catalog['monsters'] for variant in monster['variants']}
    require(not existing_ids.intersection(variant['id'] for _, variant in variants),
            'Source catalog already contains these immutable variants; use the original input catalog')
    require(not existing_revisions.intersection(variant['revision'] for _, variant in variants),
            'These exact recording revisions already exist; refusing to duplicate an old capture as a new revision')
    for monster in catalog['monsters']:
        if monster['id'] not in SPECIES: continue
        for variant in monster['variants']:
            if variant.get('is_current'):
                variant['is_current'] = False
                variant['label'] = variant['label'].replace('当前', '历史 ' + variant['game_commit'][:8], 1)
        # Combat remains the default. Scale-only material is a separate choice.
        monster['variants'] = [variant for species, variant in variants if species == monster['id']] + monster['variants']
        monster['terminal_policy'] = ('冲锋／俯冲先完成失力、真实接地及稳定留尸；尸体无伤害。'
                                      if monster['id'] in PERSISTENT else
                                      '先失力并真实落地，稳定短留后淡出；死亡身体与碎片无伤害。')
    catalog['game_commit'] = args.game_commit
    counts = validate_catalog(catalog)
    old_by_id = {variant['id']: variant for monster in original['monsters'] for variant in monster['variants']}
    new_by_id = {variant['id']: variant for monster in catalog['monsters'] for variant in monster['variants']}
    for key, before in old_by_id.items():
        require(key in new_by_id, 'An existing clip was lost')
        require({k:v for k,v in before.items() if k not in ('is_current','label')} ==
                {k:v for k,v in new_by_id[key].items() if k not in ('is_current','label')},
                'Existing revision/media/actions changed; old comments would lose exact meaning')
    poster_proofs = []
    for movie, info, selections in poster_groups:
        poster_proofs.extend(make_posters(movie, info, selections, args.posters_dir))
    proof = {'scope': 'Catalog/poster data only; no browser/API/DB/deployment/user acceptance claim',
             'source_catalog': str(args.source_catalog), 'source_catalog_sha256': sha(args.source_catalog),
             'game_commit': args.game_commit, 'media_commit': args.media_commit,
             'combat_trace': str(args.trace), 'combat_trace_sha256': sha(args.trace), 'wrapper': wrapper,
             'comparison_trace_sha256': sha(args.comparison_trace) if args.comparison_trace else None,
             'counts': counts, 'new_combat_variants': 7, 'new_comparison_variants': len(comparison_proofs),
             'existing_clip_ids_revisions_and_actions_preserved': len(old_by_id),
             'combat_cases': proofs, 'comparison_pages': comparison_proofs, 'posters': poster_proofs,
             'media': [{k:v for k,v in item.items() if k != 'probe'} for item in identities],
             'limitations': ['Basic coverage0 is not complete moveset approval', 'No H/D authored-cell inference for continuous rig',
                            'Explicit arena fixtures and automated real Router input; not a natural campaign route',
                            'Comparison is staged with sample AI/player held, not combat evidence']}
    atomic_json(args.output_catalog, catalog)
    proof['output_catalog'] = str(args.output_catalog)
    proof['output_catalog_sha256'] = sha(args.output_catalog)
    atomic_json(args.output_proof or args.output_catalog.with_suffix('.audit.json'), proof)
    print(json.dumps({'status': 'prepared_catalog_and_original_frame_posters', **counts,
                      'new_combat_variants': 7, 'new_comparison_variants': len(comparison_proofs),
                      'output_catalog': str(args.output_catalog)}, ensure_ascii=False))


if __name__ == '__main__':
    main()
