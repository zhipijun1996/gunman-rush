#!/usr/bin/env python3
"""Capture three actual Home hurt revisions with the untouched MovieMaker mix."""
from __future__ import annotations
import argparse
from godot_identity import verified_engine
from contextlib import contextmanager
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import stat
import subprocess
import time

import capture_audio_feedback as feedback

ROOT, CAPTURE_OVERRIDE, ERROR = feedback.ROOT, feedback.CAPTURE_OVERRIDE, feedback.ERROR
sha, read, write, integer = feedback.sha, feedback.read, feedback.write, feedback.integer
VERSION = 'audio-hurt-feedback-capture-v1'
FRAMES = {'title': 120, 'home_startup': 2, 'home_actions': 360, 'hurt_a': 240, 'hurt_b': 240, 'hurt_c': 240}
LABELS = {'title': '标题 · 2秒无输入 / 原BGM', 'home_startup': '进入真实家园',
          'home_actions': '原跳落 / 对地射击 · wall_1',
          **{f'hurt_{x}': f'受伤候选 {x.upper()} · 真实生命事务 fixture' for x in 'abc'}}


def frozen_sources():
    return feedback.frozen_sources() | {name: sha(ROOT / name) for name in (
        'tools/audio_feedback_06_capture.gd', 'tools/audio_feedback_06_capture.gd.uid', 'tools/capture_audio_hurt.py')}


def validate_trace(trace, count):
    if (trace.get('task'), trace.get('version'), trace.get('fps'), trace.get('failures')) != ('AUDIO-FEEDBACK-06', VERSION, 60, []):
        raise ValueError('Failed or unexpected actual hurt-candidate trace')
    if trace.get('rendering') != {'actual_window': [960, 540], 'logical_content': [1280, 720]}:
        raise ValueError('Actual MovieMaker rendering size changed')
    if abs(integer(trace['movie_clock']['frames_drawn_before_quit']) - integer(count)) > 2:
        raise ValueError('Actual MovieMaker frame count differs from encoded media')
    segments, samples, events = trace['segments'], trace['samples'], trace['events']
    if [s['id'] for s in segments] != list(FRAMES):
        raise ValueError('Missing or reordered title/Home/A/B/C chapters')
    if len(samples) != sum(FRAMES.values()):
        raise ValueError('Missing/repeated actual physical-frame observations')
    assembly = [e for e in events if e['id'] == 'formal_sfx_assembly']
    if len(assembly) != 1 or not assembly[0]['data'].get('validation_ok') or assembly[0]['data'].get('audio_profile') != 'selected':
        raise ValueError('Actual formal selected SFX assembly did not validate')
    previous, camera = None, None
    chapters = []
    for segment in segments:
        name = segment['id']
        start, end = integer(segment['start_frame']), integer(segment['end_frame'])
        if end - start != FRAMES[name] or (previous is not None and start != previous) or end > count:
            raise ValueError('Actual authored chapter frames drifted: ' + name)
        previous = end
        rows = [r for r in samples if r['phase'] == name]
        if [integer(r['movie_frame']) for r in rows] != list(range(start + 1, end + 1)):
            raise ValueError('Missing/discontinuous MovieMaker samples: ' + name)
        first_tick, last_tick = integer(segment['first_physics_tick']), integer(segment['last_physics_tick'])
        if [integer(r['physics_tick']) for r in rows] != list(range(first_tick + 1, last_tick + 1)) or last_tick - first_tick != FRAMES[name]:
            raise ValueError('Missing/discontinuous actual physics samples: ' + name)
        x, y, width, height = segment['caption_rect']
        if not (x >= 220 and x + width <= 1120 and y >= 0 and y + height <= 70):
            raise ValueError('Caption escaped the HUD-safe logical top strip')
        if any(r['music_track'] != 'home' for r in rows):
            raise ValueError('Original Home BGM context changed')
        if not any(v['playing'] and not v['paused'] and v['path'].endswith('/the_kindred_hearth.mp3') for r in rows for v in r['music_voices']):
            raise ValueError('Actual original BGM player missing: ' + name)
        if any(not math.isfinite(v['volume_db']) for r in rows for v in r['voices'] + r['music_voices']):
            raise ValueError('Nonfinite actual mixer gain')
        chapter = {'id': name, 'title': LABELS[name], 'start': start / 60, 'end': end / 60}
        if name.startswith('hurt_'):
            letter = name[-1]
            candidate, path = 'hurt_feedback_06_' + letter, f'res://assets/audio/feedback_06/hurt_{letter}.wav'
            chapter.update(profile=letter.upper(), candidate_id=candidate, path=path)
            configured = [e for e in events if e['phase'] == name and e['id'] == 'hurt_candidate_configured']
            if len(configured) != 1 or configured[0]['data'].get('accepted') is not True or configured[0]['data'].get('candidate_id') != candidate:
                raise ValueError('Candidate revision did not configure: ' + candidate)
            heard = {(e['tick'], e['candidate'], e['path']) for r in rows for e in r['director_events'] if e['id'] == 'hurt' and first_tick <= e['tick'] <= last_tick}
            if len(heard) != 1 or next(iter(heard))[1:] != (candidate, path):
                raise ValueError('Actual damage did not choose exactly one expected hurt candidate: ' + candidate)
            live = [v for r in rows for v in r['voices'] if v['playing'] and v['event'] == 'hurt']
            if not live or any(v['path'] != path or v['paused'] for v in live):
                raise ValueError('Expected real hurt voice never played or another candidate leaked in')
            for row in rows:
                if camera is None: camera = row['camera']
                if row['camera'] != camera or not row['player']['grounded'] or row['hurt_candidate'] != candidate:
                    raise ValueError('Hurt audition did not retain the same grounded Home/camera context')
        chapters.append(chapter)
    title_events = [e for e in events if e['phase'] == 'title']
    if not any(e['id'] == 'title_without_input' and e['data'].get('injected_input_count') == 0 for e in title_events) or any(e['id'] in ['shot', 'jump', 'hurt_fixture_commit'] for e in title_events):
        raise ValueError('Title observation contains an injected gameplay event')
    ids = [e['id'] for e in events]
    if any(name not in ids for name in ['jump', 'land', 'shot', 'terrain_impact']):
        raise ValueError('Original jump/landing or real downward projectile collision missing')
    wall = [v for r in samples if r['phase'] == 'home_actions' for v in r['voices'] if v['cue'] == 'weapon_wall']
    if not wall or any(v['path'] != 'res://assets/audio/feedback_05/wall_1.wav' for v in wall):
        raise ValueError('Actual terrain hit did not use the one fixed wall_1 recording')
    health_ids = set()
    for name, amount in [('hurt_fixture_commit', -1), ('health_restore_fixture', 1)]:
        commits = [e for e in events if e['id'] == name]
        if [e['phase'] for e in commits] != ['hurt_a', 'hurt_b', 'hurt_c'] or any(e['data']['status'] != 0 or e['data']['amount_applied'] != amount for e in commits):
            raise ValueError('Actual damage/heal fixture transactions differ')
        health_ids.update(e['data']['health_instance'] for e in commits)
    if len(health_ids) != 1:
        raise ValueError('Candidates did not use the same actual Home HealthState')
    return {'chapters': chapters}


@contextmanager
def owned_renderer(output, report):
    """Same owned override/lease/Xvfb lifecycle as feedback05; never touch foreign state."""
    override, lock, display, owned = ROOT / 'override.cfg', None, None, False
    env = {**os.environ, 'LIBGL_ALWAYS_SOFTWARE': '1', 'LP_NUM_THREADS': '4'}
    try:
        lock = (ROOT / 'build/.audio_ambience_capture.lock').open('a')
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        fd = os.open(override, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        owned = True
        with os.fdopen(fd, 'wb') as stream:
            stream.write(CAPTURE_OVERRIDE); stream.flush(); os.fsync(stream.fileno())
        (output / 'capture-override.cfg').write_bytes(CAPTURE_OVERRIDE)
        report['capture_override'] = {'path': 'override.cfg', 'content': CAPTURE_OVERRIDE.decode(), 'sha256': hashlib.sha256(CAPTURE_OVERRIDE).hexdigest(), 'created': True, 'removed': False, 'drifted': False, 'project_sha256_before': sha(ROOT / 'project.godot')}
        if not env.get('DISPLAY'):
            binary = shutil.which('Xvfb') or str(ROOT.parent / 'toolchains/xvfb/usr/bin/Xvfb')
            display = subprocess.Popen([binary, '-displayfd', '1', '-screen', '0', '960x540x24', '-nolisten', 'tcp', '-ac'], stdout=subprocess.PIPE, stderr=(output / 'display.log').open('w'), text=True)
            env['DISPLAY'] = ':' + display.stdout.readline().strip()
        yield env
    finally:
        cleanup_error = None
        if display:
            display.terminate()
            try: display.wait(timeout=5)
            except subprocess.TimeoutExpired: display.kill(); display.wait()
        if owned:
            row = report['capture_override']; row['project_sha256_after'] = sha(ROOT / 'project.godot')
            if override.is_symlink() or not override.exists() or not stat.S_ISREG(override.lstat().st_mode) or override.read_bytes() != CAPTURE_OVERRIDE:
                row['drifted'] = True; cleanup_error = 'Owned capture override drifted; foreign state preserved'
            else: override.unlink(); row['removed'] = True
            if row['project_sha256_before'] != row['project_sha256_after']: cleanup_error = 'Formal project.godot changed during capture'
        if lock: fcntl.flock(lock.fileno(), fcntl.LOCK_UN); lock.close()
        if cleanup_error: report.update(status='failed', cleanup_error=cleanup_error); raise ValueError(cleanup_error)


def capture(output):
    if output.exists(): raise ValueError('Use a fresh output directory; retain all earlier evidence')
    output.mkdir(parents=True)
    started = time.monotonic()
    report = {'status': 'failed', 'task': 'AUDIO-FEEDBACK-06', 'version': VERSION, 'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(), 'scope': 'Continuous actual formal title/Home with original MovieMaker audio; Router action plus explicit 1HP damage/heal audition fixtures; no dubbed audio, natural enemy-hit, browser-autoplay or device claim'}
    native, wav, movie = output / 'native.avi', output / 'native.wav', output / 'feedback.mp4'
    try:
        if shutil.disk_usage(ROOT).free < 512 * 1024 * 1024: raise ValueError('Less than 512MiB free; no prior evidence is deleted')
        with owned_renderer(output, report) as env:
            engine_identity = verified_engine(repo=ROOT)
            report['engine'] = {'version': engine_identity['version'], 'sha256': engine_identity['binary_sha256']}
            report['source_before'] = frozen_sources()
            command = ['bash', 'tools/godot.sh', '--path', '.', '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', '--write-movie', str(native), '--fixed-fps', '60', '--resolution', '960x540', '--script', 'res://tools/audio_feedback_06_capture.gd', '--', '--output=' + str(output)]
            report['command'] = command
            with (output / 'native.log').open('w') as log:
                result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=420)
            report['exit_code'] = result.returncode
            if result.returncode or ERROR.search((output / 'native.log').read_text()) or 'AUDIO_HURT_FEEDBACK_CAPTURE failures=0' not in (output / 'native.log').read_text():
                raise ValueError('Native capture failed; original log/trace/AVI retained')
            report['native_container'] = {'path': 'native.avi', 'sha256': sha(native), 'bytes': native.stat().st_size, 'retained': True}
            report['native_media'] = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(native)]))
            v = next(s for s in report['native_media']['streams'] if s['codec_type'] == 'video')
            if (int(v['width']), int(v['height']), v['avg_frame_rate']) != (960, 540, '60/1'): raise ValueError('Actual native AVI dimensions/FPS differ')
            subprocess.run(['ffmpeg', '-v', 'error', '-i', str(native), '-vn', '-c:a', 'copy', str(wav)], check=True, timeout=90)
            subprocess.run(['ffmpeg', '-i', str(native), '-c:v', 'libx264', '-preset', 'fast', '-crf', '23', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', str(movie)], stdout=subprocess.DEVNULL, stderr=(output / 'encode.log').open('w'), check=True, timeout=180)
            report['media'] = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(movie)]))
            v = next(s for s in report['media']['streams'] if s['codec_type'] == 'video'); a = next(s for s in report['media']['streams'] if s['codec_type'] == 'audio')
            if (int(v['width']), int(v['height']), v['avg_frame_rate'], int(a['sample_rate']), a['channels']) != (960, 540, '60/1', 48000, 2): raise ValueError('Actual encoded MP4 dimensions/FPS/audio differ')
            report.update(frame_count=int(v['nb_frames']), movie_sha256=sha(movie), movie_bytes=movie.stat().st_size, native_wav_sha256=sha(wav), native_wav_bytes=wav.stat().st_size)
            trace = read(output / 'trace.json'); chapters = validate_trace(trace, report['frame_count'])
            report['native_audio_validation'] = feedback.validate_wav(wav, trace)
            write(output / 'chapters.json', chapters)
            report.update(trace_sha256=sha(output / 'trace.json'), chapters_sha256=sha(output / 'chapters.json'))
            # Only this fresh, fingerprinted temporary AVI is removed after its
            # untouched PCM and encoded movie have both validated; older media stay.
            if not native.is_symlink() and sha(native) == report['native_container']['sha256']:
                native.unlink(); report['native_container'].update(retained=False, removal_reason='Owned temporary AVI; original PCM WAV/MP4 and AVI fingerprint/media index retained')
            write(output / 'native-container-index.json', report['native_container'])
        report['source_after'] = frozen_sources(); report['source_stable'] = report['source_before'] == report['source_after']
        if not report['source_stable']: raise ValueError('Production/producer source changed during capture')
        report['status'] = 'passed'
    except Exception as error:
        report.update(status='failed', error=str(error)); raise
    finally:
        if 'source_before' in report:
            report['source_after'] = frozen_sources(); report['source_stable'] = report['source_before'] == report['source_after']
            if not report['source_stable']: report.update(status='failed', source_error='Production/producer source drift retained')
        report['seconds'] = time.monotonic() - started
        write(output / 'report.json', report)
    if report['status'] != 'passed': raise ValueError('Capture failed; see retained report.json')
    print(json.dumps({'status': report['status'], 'movie': str(movie), 'frames': report['frame_count']}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    capture(parser.parse_args().output.resolve())
