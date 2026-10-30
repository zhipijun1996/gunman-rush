#!/usr/bin/env python3
"""Package the real feedback06 capture and seven WAV comparisons, without a web build."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit
import wave
import zipfile

import capture_audio_hurt as capture

ROOT = Path(__file__).resolve().parents[1]
VERSION = 'audio-feedback-06-v1'
TASK = 'AUDIO-FEEDBACK-06'


def digest(path):
    value = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def load(path):
    return json.loads(Path(path).read_text())


def write(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def local_path(resource):
    path = (ROOT / resource.removeprefix('res://')).resolve()
    if not path.is_relative_to(ROOT) or not path.is_file():
        raise ValueError('Missing or escaped local audio resource: ' + resource)
    return path


def fingerprint(path, expected, size=None):
    if not re.fullmatch('[a-f0-9]{64}', str(expected)) or digest(path) != expected or (size is not None and path.stat().st_size != size):
        raise ValueError('Actual file fingerprint differs: ' + str(path))


def game_link(base, profile):
    parts = urlsplit(base)
    if parts.scheme not in ['', 'https', 'http'] or base.startswith('//'):
        raise ValueError('Game URL must be a relative path or HTTP(S) URL')
    query = dict(parse_qsl(parts.query))
    query['audio_hurt'] = profile
    return urlunsplit(parts._replace(query=urlencode(query)))


def build(args):
    output = args.output.resolve()
    if output.exists():
        raise ValueError('Use a fresh --output directory; earlier deliveries stay untouched')
    manifest_path = ROOT / 'assets/audio/feedback_06/manifest.json'
    sources_path = ROOT / 'config/audio_director/feedback_06/sources.json'
    recipes_path = ROOT / 'config/audio_director/feedback_06/recipes.json'
    manifest, source_registry, recipes = map(load, [manifest_path, sources_path, recipes_path])
    if (manifest.get('task'), manifest.get('version'), recipes.get('task'), recipes.get('version'), source_registry.get('task')) != (TASK, VERSION, TASK, VERSION, TASK):
        raise ValueError('Feedback06 manifest/recipe/source identity mismatch')
    fingerprint(sources_path, manifest['sources_sha256'])
    fingerprint(recipes_path, manifest['recipes_sha256'])
    if manifest['sources'] != source_registry['sources']:
        raise ValueError('Manifest source metadata differs from actual source registry')
    candidates = next(e['candidates'] for e in manifest['events'] if e['id'] == 'hurt')
    if [(c['profile'], c['id']) for c in candidates] != [(p, 'hurt_feedback_06_' + p.lower()) for p in 'ABC']:
        raise ValueError('Exactly the three ordered feedback06 directions are required')
    if [(c['id'], c['label']) for c in recipes['candidates']] != [(c['id'], c['label']) for c in candidates]:
        raise ValueError('Candidate names/IDs differ from the authored recipes')

    folder = args.capture.resolve()
    report = load(folder / 'report.json')
    if report.get('status') != 'passed' or report.get('task') != TASK or report.get('version') != capture.VERSION or report.get('source_stable') is not True or report.get('exit_code') != 0:
        raise ValueError('Only an actual passed/source-stable feedback06 capture can be published')
    if not re.fullmatch('[a-f0-9]{40}', str(report.get('commit'))):
        raise ValueError('Actual capture commit is missing')
    if report.get('source_before') != report.get('source_after') or not report.get('source_before'):
        raise ValueError('Capture source closure is not intact')
    for relative, expected in report['source_before'].items():
        fingerprint(local_path(relative), expected)
    log = (folder / 'native.log').read_text()
    if capture.ERROR.search(log) or 'AUDIO_HURT_FEEDBACK_CAPTURE failures=0' not in log:
        raise ValueError('Native capture log contains an error or lacks its real success marker')
    movie = folder / 'feedback.mp4'
    fingerprint(movie, report['movie_sha256'], report['movie_bytes'])
    fingerprint(folder / 'trace.json', report['trace_sha256'])
    fingerprint(folder / 'chapters.json', report['chapters_sha256'])
    chapters = capture.validate_trace(load(folder / 'trace.json'), report['frame_count'])
    if chapters != load(folder / 'chapters.json'):
        raise ValueError('Chapter metadata differs from the verified actual MovieMaker trace')
    fingerprint(folder / 'native.wav', report['native_wav_sha256'], report['native_wav_bytes'])
    if capture.feedback.validate_wav(folder / 'native.wav', load(folder / 'trace.json')) != report['native_audio_validation']:
        raise ValueError('Actual native PCM proof differs from the captured report')
    media = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams', '-of', 'json', str(movie)]))
    video = next(s for s in media['streams'] if s['codec_type'] == 'video')
    sound = next(s for s in media['streams'] if s['codec_type'] == 'audio')
    if (video['codec_name'], int(video['width']), int(video['height']), video['avg_frame_rate'], int(video['nb_frames']), sound['codec_name'], int(sound['sample_rate']), sound['channels']) != ('h264', 960, 540, '60/1', report['frame_count'], 'aac', 48000, 2):
        raise ValueError('Actual MP4 does not match the verified video/audio format')

    info_path = args.build_info.resolve()
    info = load(info_path)
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    if info.get('source_commit') != head or not re.fullmatch('[a-f0-9]{12}', str(info.get('build_id'))):
        raise ValueError('The real Web build must come from current committed HEAD')
    pack = info_path.parent / info['pack']
    if pack.name != info['pack'] or info['pack'] != 'index.' + info['build_id'] + '.pck' or pack.stat().st_size != info['pack_bytes']:
        raise ValueError('Actual complete Web PCK is missing or has a different size')
    pack_sha = digest(pack)
    if pack_sha[:12] != info['build_id']:
        raise ValueError('Actual complete Web PCK has a different SHA')

    old = load(ROOT / 'assets/audio/director_v3/manifest.json')
    previous = load(ROOT / 'assets/audio/feedback_05/manifest.json')
    rows, credits = [], {}

    def add(candidate, render, group, label, bank, namespace):
        source = local_path(render['path'])
        fingerprint(source, render['sha256'], render['bytes'])
        with wave.open(str(source), 'rb') as wav:
            if wav.getnframes() <= 0 or wav.getsampwidth() != 2 or wav.getnchannels() not in [1, 2]:
                raise ValueError('Comparison is not a valid PCM16 WAV')
        source_ids = []
        for source_id in candidate['source_ids']:
            record = bank['sources'][source_id]
            if not record.get('author') or not record.get('source_url') or not record.get('license'):
                raise ValueError('Comparison source lacks authorship/source/license metadata')
            key = namespace + '/' + source_id
            credits[key] = record
            source_ids.append(key)
        row = {'id': candidate['id'] if group == 'new' else namespace + '/' + source.name,
               'candidate_id': candidate['id'], 'version': candidate['version'], 'profile': candidate.get('profile'),
               'label': label, 'group': group, 'path': 'audio/' + namespace + '_' + source.name,
               'sha256': render['sha256'], 'bytes': render['bytes'], 'source_ids': source_ids}
        row['choice_value'] = candidate['profile'] if group == 'new' else 'old_c' if namespace == 'director_v3' else 'feedback05_1' if source.name == 'hurt_1.wav' else 'feedback05_2' if source.name == 'hurt_2.wav' else None
        rows.append((row, source))

    for candidate in candidates:
        if candidate['version'] != VERSION or len(candidate['renders']) != 1 or candidate['renders'][0]['path'] != candidate['path']:
            raise ValueError('Feedback06 candidate render identity differs')
        add(candidate, candidate['renders'][0], 'new', candidate['profile'] + ' · ' + candidate['label'], manifest, 'feedback06')
    old_c = next(c for e in old['events'] if e['id'] == 'hurt' for c in e['candidates'] if c['id'] == 'hurt_c')
    add(old_c, old_c['renders'][0], 'compare', '之前选定的 C', old, 'director_v3')
    prior_hurt = next(c for e in previous['events'] if e['id'] == 'hurt' for c in e['candidates'])
    for index, render in enumerate(prior_hurt['renders'], 1):
        add(prior_hurt, render, 'compare', '05 受伤 · 变体 ' + str(index), previous, 'feedback05')
    prior_wall = next(c for e in previous['events'] if e['id'] == 'wall' for c in e['candidates'])
    add(prior_wall, prior_wall['renders'][0], 'wall', '固定碰墙 · 05 wall_1', previous, 'feedback05')
    for row, _source in rows:
        if row['group'] == 'new':
            chapter = next(c for c in chapters['chapters'] if c.get('candidate_id') == row['id'])
            if chapter['path'] != next(c['path'] for c in candidates if c['id'] == row['id']):
                raise ValueError('Real movie chapter does not use the same actual WAV candidate')
            row['chapter_id'] = chapter['id']
            row['game_url'] = game_link(args.game_url, row['profile'])

    output.mkdir(parents=True)
    (output / 'audio').mkdir()
    for row, source in rows:
        shutil.copyfile(source, output / row['path'])
    shutil.copyfile(movie, output / 'feedback.mp4')
    shutil.copyfile(manifest_path, output / 'manifest.json')
    shutil.copyfile(recipes_path, output / 'recipes.json')
    shutil.copyfile(sources_path, output / 'feedback06-sources.json')
    shutil.copyfile(folder / 'report.json', output / 'capture-report.json')
    shutil.copyfile(info_path, output / 'build-info.json')
    shutil.copyfile(ROOT / 'assets/audio/director_v3/_sources/CC0-1.0.txt', output / 'CC0-1.0.txt')
    write(output / 'sources.json', {'task': TASK, 'version': VERSION, 'sources': credits})
    write(output / 'chapters.json', chapters)
    delivery = {'task': TASK, 'version': VERSION, 'status': 'awaiting-user', 'default_profile': 'A',
                'source_commit': info['source_commit'], 'build_id': info['build_id'], 'pack_sha256': pack_sha, 'pack_bytes': info['pack_bytes'],
                'capture_commit': report['commit'], 'capture_source_stable': True, 'capture_production_fingerprints_match_current': True,
                'movie': {'path': 'feedback.mp4', 'sha256': report['movie_sha256'], 'bytes': report['movie_bytes'], 'frame_count': report['frame_count']},
                'manifest_sha256': digest(manifest_path), 'recipes_sha256': digest(recipes_path), 'sources_sha256': digest(sources_path),
                'chapters': chapters['chapters'], 'audios': [row for row, _source in rows],
                'scope': 'Real formal Home native MovieMaker mix, original Home BGM, explicit APPLIED HP damage/heal fixtures. No commercial reference audio copied or original recipe/reconstruction claim; user aesthetic/device review pending.'}
    write(output / 'delivery.json', delivery)
    with zipfile.ZipFile(output / 'audio-comparison.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
        for name in ['manifest.json', 'recipes.json', 'feedback06-sources.json', 'sources.json', 'CC0-1.0.txt', 'delivery.json'] + [row['path'] for row, _source in rows]:
            archive.write(output / name, name)
    expected = {key: delivery[key] for key in ['task', 'version', 'source_commit', 'build_id', 'manifest_sha256']}
    expected['movie_sha256'] = delivery['movie']['sha256']
    (output / 'index.html').write_text(HTML.replace('__EXPECTED__', json.dumps(expected, ensure_ascii=False)))
    write(output / 'package-report.json', {'status': 'passed', 'task': TASK, 'generator_sha256': digest(Path(__file__)),
        'delivery_sha256': digest(output / 'delivery.json'), 'index_sha256': digest(output / 'index.html'),
        'source_commit': info['source_commit'], 'capture_commit': report['commit'], 'build_id': info['build_id'], 'audio_count': len(rows),
        'scope': 'Packaging checks only; actual browser playback/mobile interaction and user listening remain separate checks.'})
    print(json.dumps({'status': 'passed', 'output': str(output), 'build_id': info['build_id'], 'audio_count': len(rows)}))


HTML = r'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>失序之钟 · 受伤声音候选</title>
<style>:root{color-scheme:dark;font-family:system-ui,sans-serif;background:#17251f;color:#f3ead5}*{box-sizing:border-box}body{max-width:960px;margin:auto;padding:26px 14px 70px}h1{font-size:clamp(26px,5vw,38px);margin:8px 0}h2{font-size:21px}h3{font-size:17px}p{line-height:1.7;color:#cecbbb}a{color:#e1c780}.eyebrow{font-size:12px;color:#c3ae76;letter-spacing:.1em}.card{background:#213329;border:1px solid #5d6650;border-radius:14px;padding:20px;margin-top:20px}.row{display:flex;gap:10px;flex-wrap:wrap;align-items:center}button,.button,select{font:inherit;min-height:44px;padding:10px 13px;color:#fff4d8;background:#344d3d;border:1px solid #a6a77b;border-radius:8px;cursor:pointer;text-decoration:none}button:disabled{opacity:.45;cursor:default}.primary{background:#cfb775;color:#202b22;font-weight:650}button:focus-visible,a:focus-visible,select:focus-visible{outline:3px solid #e2c16e;outline-offset:3px}video{width:100%;aspect-ratio:16/9;background:#0c1510;border-radius:9px}audio{display:block;width:100%;margin:10px 0;height:40px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,250px),1fr));gap:14px}.take{border:1px solid #56644c;padding:14px;border-radius:10px;margin-top:14px}.small{font-size:12px;color:#c1c0a8;overflow-wrap:anywhere}.loop{display:flex;gap:8px;align-items:center;min-height:44px}input[type=checkbox]{width:18px;height:18px;accent-color:#cfb775}textarea{width:100%;min-height:90px;background:#17271e;color:inherit;border:1px solid #738066;border-radius:8px;padding:10px;font:inherit;margin:12px 0}details{margin-top:14px;line-height:1.7;overflow-wrap:anywhere}summary{cursor:pointer}#status{min-height:28px;color:#e1c780}select{width:100%;max-width:100%}.identity{font-size:11px;overflow-wrap:anywhere;color:#c1c0a8}@media(max-width:600px){body{padding:18px 10px 50px}.card{padding:15px}}</style>
<div class="eyebrow">THE DISORDERED CLOCK / AUDIO FEEDBACK 06</div><h1>三种受伤声音，放回真实家园比较</h1><p>这次尝试更短的断裂、竹条掠风与气息。方向名称来自实际配方，A 是本轮开发默认，尚待你选择。它们没有使用《空洞骑士》原音轨，也不代表其原配方。</p><p id="identity" class="identity">正在核验版本…</p>
<section class="card"><h2>先看有声场景</h2><p>同一个真实 Home、同一镜头，保留原家园 BGM。受伤是对真实生命状态扣除 1 HP 的明示开发 fixture，再恢复生命以比较下一方向；不是自然敌人攻击录像。</p><video id="reel" controls playsinline preload="none"></video><div id="chapters" class="row"></div><div class="row" style="margin-top:12px"><button id="full" disabled>播放完整短片</button><button id="stop" disabled>停止所有播放</button><a class="button" href="feedback.mp4" download>下载原生有声短片</a></div><p id="status" role="status">核验后可试听。</p></section>
<section class="card"><h2>单声与实际游戏</h2><p>单声试听不代表游戏混音响度。循环用于辨认细节；真实混音请比较上方短片，或分别进入 A/B/C 游戏。</p><div id="new" class="grid"></div><details><summary>和旧 C、05 两个受伤变体比较</summary><div id="compare" class="grid"></div></details><div id="wall"></div><p><a href="audio-comparison.zip" download>下载七条 WAV 与来源配方</a></p></section>
<section class="card"><h2>记录你的选择</h2><label for="choice">受伤声音方向</label><select id="choice" disabled><option value="unreviewed">尚未选择</option><option value="A">A</option><option value="B">B</option><option value="C">C</option><option value="old_c">更喜欢之前的 C</option><option value="feedback05_1">更喜欢 05 变体 1</option><option value="feedback05_2">更喜欢 05 变体 2</option><option value="none">这些都不合适</option></select><textarea id="notes" disabled placeholder="例如：断裂太尖、呼吸太明显，或更喜欢哪一段…"></textarea><div class="row"><button id="export" disabled>导出选择 JSON</button><span id="saved" class="small"></span></div></section>
<section class="card"><details><summary>来源、许可与实际版本</summary><p>新候选采用 CC0 录音：黄瓜脆裂、实际竹条掠风与作者已放慢处理的呼吸；“断裂”是加工后的声音意象，不是骨骼录音。原件与原作者许可记录保留在项目素材库。以下可查看每条使用的作者、原文件、商业条件与下载日期。</p><div id="credits"></div><p><a href="sources.json">全部比较素材来源</a> · <a href="feedback06-sources.json">本轮原始来源登记</a> · <a href="recipes.json">加工配方</a> · <a href="manifest.json">候选指纹</a> · <a href="CC0-1.0.txt">CC0 全文</a> · <a href="capture-report.json">实际捕获报告</a> · <a href="build-info.json">实际游戏版本</a></p><p class="small">自动检查只验证文件、事件与传输；音色审美与真实手机设备听感需要你试听确认。</p></details></section>
<script>
'use strict';const EXPECTED=__EXPECTED__,$=id=>document.getElementById(id),video=$('reel'),audios=[];
let data=null,epoch=0,owner=null,activeChapter=null,boundary=null,blobPromise=null,blobURL=null;
const stats=window.FEEDBACK06_STATS={ready:false,starts:0,stops:0,chapterStarts:0,mediaErrors:[],identity:null};
const key='audio-feedback-06-v1';
function message(t){$('status').textContent=t}
function node(tag,text){const n=document.createElement(tag);if(text!==undefined)n.textContent=text;return n}
function safeURL(value){const u=new URL(value,location.href);if(!['http:','https:'].includes(u.protocol))throw Error('来源链接协议无效');return u.href}
async function hash(bytes){return [...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(x=>x.toString(16).padStart(2,'0')).join('')}
function cancelBoundary(){if(boundary!==null){clearInterval(boundary);boundary=null}}
function intent(element){epoch++;cancelBoundary();activeChapter=null;for(const a of audios)if(a!==element)a.pause();if(video!==element)video.pause();owner=element;if(element)element.dataset.owner=String(epoch);return epoch}
function stopAll(){intent(null);video.pause();for(const a of audios){a.pause();a.currentTime=0}stats.stops++;message('已停止；等待中的下载不会自动播放。')}
function still(token,element){return epoch===token&&owner===element&&element.dataset.owner===String(token)}
async function playAudio(a,label){const token=intent(a);try{await a.play();if(!still(token,a)){if(a.dataset.owner===String(token))a.pause();return}stats.starts++;message(label)}catch(e){if(still(token,a))message('请直接点击音频控件播放：'+e.message)}}
async function movieURL(){if(blobURL)return blobURL;if(!blobPromise)blobPromise=(async()=>{const r=await fetch(data.movie.path,{cache:'no-store'});if(!r.ok)throw Error('短片下载失败：HTTP '+r.status);const bytes=await r.arrayBuffer();if(bytes.byteLength!==data.movie.bytes||await hash(bytes)!==data.movie.sha256)throw Error('实际短片指纹不符，已拒绝播放');blobURL=URL.createObjectURL(new Blob([bytes],{type:'video/mp4'}));return blobURL})().catch(e=>{blobPromise=null;throw e});return blobPromise}
function metadata(token){if(video.readyState>=1)return Promise.resolve();return new Promise((resolve,reject)=>{const timer=setTimeout(()=>done(Error('视频元数据载入超时')),10000);function done(error){clearTimeout(timer);video.removeEventListener('loadedmetadata',yes);video.removeEventListener('error',bad);error?reject(error):resolve()}function yes(){done()}function bad(){done(Error('视频无法解码'))}video.addEventListener('loadedmetadata',yes,{once:true});video.addEventListener('error',bad,{once:true});if(token!==epoch)done(Error('已取消'))})}
function seek(time,token){if(Math.abs(video.currentTime-time)<.02)return Promise.resolve();return new Promise((resolve,reject)=>{const timer=setTimeout(()=>done(Error('章节跳转超时')),8000);function done(error){clearTimeout(timer);video.removeEventListener('seeked',yes);video.removeEventListener('error',bad);error?reject(error):resolve()}function yes(){done(Math.abs(video.currentTime-time)>.12?Error('实际视频尚未跳至章节'):null)}function bad(){done(Error('视频跳转失败'))}video.addEventListener('seeked',yes,{once:true});video.addEventListener('error',bad,{once:true});if(token!==epoch){done(Error('已取消'));return}try{video.currentTime=time}catch(e){done(e)}})}
function watch(token){cancelBoundary();boundary=setInterval(()=>{if(!still(token,video)||!activeChapter)return;if(video.currentTime>=activeChapter.end-.025){cancelBoundary();video.pause();message(activeChapter.title+' · 片段结束')}},25)}
async function playVideo(chapter){const token=intent(video);try{message('正在取得完整短片，以支持可靠跳段…');const src=await movieURL();if(!still(token,video))return;if(video.src!==src){video.src=src;video.load()}await metadata(token);if(!still(token,video))return;const start=chapter?.start||0;if(chapter&&chapter.end>video.duration+.08)throw Error('章节超出实际短片');await seek(start,token);if(!still(token,video))return;activeChapter=chapter;video.dataset.owner=String(token);await video.play();if(!still(token,video)){if(video.dataset.owner===String(token))video.pause();return}stats.starts++;if(chapter){stats.chapterStarts++;watch(token)}message(chapter?chapter.title:'完整真实场景短片')}catch(e){if(still(token,video)){video.pause();message(e.name==='NotAllowedError'?'请点击视频播放控件开启声音，再选择章节。':e.message)}}}
function mediaIntent(element){if(data)intent(element)}
function bindNative(element){element.addEventListener('pointerdown',()=>mediaIntent(element),{capture:true});element.addEventListener('keydown',e=>{if([' ','Enter'].includes(e.key))mediaIntent(element)},{capture:true});element.addEventListener('play',()=>{if(owner!==element||element.dataset.owner!==String(epoch)){element.pause();return}for(const a of audios)if(a!==element)a.pause();if(element!==video)video.pause();if(element===video&&activeChapter)watch(epoch)});element.addEventListener('error',()=>{stats.mediaErrors.push(element.error?.code||0);message('媒体载入失败，可下载原件试听。')})}
bindNative(video);video.addEventListener('ended',()=>{cancelBoundary();message('短片播放结束')});
document.addEventListener('visibilitychange',()=>{if(document.hidden)stopAll()});window.addEventListener('pagehide',()=>{stopAll();if(blobURL)URL.revokeObjectURL(blobURL)});
function creditsFor(ids,sources){const d=node('details'),s=node('summary','来源与许可');d.append(s);for(const id of ids){const x=sources[id],p=node('p'),a=node('a',x.author+' · '+x.original_filename+' · '+x.license);a.href=safeURL(x.source_url);a.target='_blank';a.rel='noopener';p.append(a,node('br'),document.createTextNode('下载：'+x.download_date+'；'+(x.attribution_required?'需署名':'无需强制署名')+'；'+(x.commercial_conditions||'')));p.className='small';d.append(p)}return d}
function renderAudios(sources){for(const row of data.audios){const box=node('div');box.className='take';box.dataset.candidateId=row.id;box.append(node('h3',row.label));const a=node('audio');a.controls=true;a.preload='none';a.src=row.path;audios.push(a);bindNative(a);box.append(a);const line=node('div');line.className='row';const button=node('button','播放'),download=node('a','下载 WAV');button.onclick=()=>playAudio(a,row.label);download.href=row.path;download.download='';line.append(button,download);const loop=node('label');loop.className='loop';const check=node('input');check.type='checkbox';check.onchange=()=>a.loop=check.checked;loop.append(check,document.createTextNode('循环'));line.append(loop);box.append(line);if(row.game_url){const link=node('a','进入实际游戏 · '+row.profile);link.href=safeURL(row.game_url);link.className='button';link.onclick=stopAll;box.append(link)}box.append(node('p',row.candidate_id+' · '+row.version));box.lastChild.className='small';box.append(creditsFor(row.source_ids,sources));$(row.group).append(box)}for(const p of ['A','B','C'])$('choice').querySelector('[value="'+p+'"]').textContent=data.audios.find(a=>a.group==='new'&&a.profile===p).label}
function payload(){const selected=$('choice').value,row=data.audios.find(a=>a.choice_value===selected);return {schema_version:1,task:data.task,version:data.version,manifest_sha256:data.manifest_sha256,source_commit:data.source_commit,build_id:data.build_id,capture_commit:data.capture_commit,exported_at:new Date().toISOString(),choice:selected,candidate_id:row?.candidate_id||null,candidate_version:row?.version||null,candidate_sha256:row?.sha256||null,notes:$('notes').value,subjective_status:selected==='unreviewed'?'unreviewed':'user-feedback'}}
function save(){const p=payload();try{localStorage.setItem(key,JSON.stringify(p));$('saved').textContent='已保存在本机；导出后可发回。'}catch{$('saved').textContent='本机存储不可用，请直接导出。'}return p}
$('stop').onclick=stopAll;$('full').onclick=()=>playVideo(null);$('choice').onchange=save;$('notes').oninput=save;$('export').onclick=()=>{if(!data)return;const url=URL.createObjectURL(new Blob([JSON.stringify(save(),null,2)],{type:'application/json'})),a=node('a');a.href=url;a.download='audio-feedback-06-choices.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1500)};
async function getJSON(path){const r=await fetch(path,{cache:'no-store'});if(!r.ok)throw Error('版本文件不可用：'+path);return r.json()}
(async()=>{try{const d=await getJSON('delivery.json');for(const k of ['task','version','source_commit','build_id','manifest_sha256'])if(d[k]!==EXPECTED[k])throw Error('交付身份不符：'+k);if(d.movie?.sha256!==EXPECTED.movie_sha256)throw Error('场景版本不符');const response=await fetch('manifest.json',{cache:'no-store'});if(!response.ok)throw Error('候选文件不可用');const raw=await response.arrayBuffer();if(await hash(raw)!==d.manifest_sha256)throw Error('候选指纹不符');const m=JSON.parse(new TextDecoder().decode(raw));if(m.task!==d.task||m.version!==d.version)throw Error('候选版本不符');const sources=await getJSON('sources.json');if(sources.task!==d.task||sources.version!==d.version)throw Error('来源版本不符');if(d.audios.length!==7||d.audios.filter(a=>a.group==='new').map(a=>a.profile).join('')!=='ABC')throw Error('候选不完整');for(const row of d.audios.filter(a=>a.group==='new')){const c=m.events.find(e=>e.id==='hurt').candidates.find(c=>c.id===row.id);if(!c||c.renders[0].sha256!==row.sha256)throw Error('试听素材不匹配')}data=d;renderAudios(sources.sources);for(const c of d.chapters){const b=node('button',c.title);b.dataset.chapter=c.id;b.onclick=()=>playVideo(c);$('chapters').append(b)}try{const saved=JSON.parse(localStorage.getItem(key)||'null');if(saved?.manifest_sha256===d.manifest_sha256&&saved.version===d.version){if([...$('choice').options].some(o=>o.value===saved.choice))$('choice').value=saved.choice;$('notes').value=typeof saved.notes==='string'?saved.notes:''}}catch{}for(const id of ['stop','full','choice','notes','export'])$(id).disabled=false;$('identity').textContent=d.version+' · 游戏 source '+d.source_commit.slice(0,12)+' / build '+d.build_id+' · 原生录像 source '+d.capture_commit.slice(0,12);stats.ready=true;stats.identity={source:d.source_commit,build:d.build_id,manifest:d.manifest_sha256};message('点击 A/B/C 章节或单声试听；选择将保存在本机。')}catch(e){stopAll();message('已停止：'+e.message);$('identity').textContent='版本核验未通过'}})();
</script></html>'''


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--build-info', type=Path, required=True)
    parser.add_argument('--game-url', default='/game/')
    parser.add_argument('--output', type=Path, required=True)
    build(parser.parse_args())
