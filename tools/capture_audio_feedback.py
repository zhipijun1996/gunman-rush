#!/usr/bin/env python3
"""Capture formal audio feedback fixtures with the original MovieMaker audio."""
from __future__ import annotations
import argparse
from godot_identity import verified_engine
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

from capture_audio_ambience import ROOT, CAPTURE_OVERRIDE, ERROR, sha, read, write, integer, frozen_sources as base_sources

VERSION = 'audio-feedback-capture-v1'


def frozen_sources():
    result = base_sources()
    for name in ['tools/audio_feedback_capture.gd', 'tools/audio_feedback_capture.gd.uid', 'tools/capture_audio_feedback.py']:
        result[name] = sha(ROOT / name)
    return result


def validate_trace(trace, count, smoke=False):
    if trace.get('version') != VERSION or trace.get('task') != 'AUDIO-FEEDBACK-05' or trace.get('fps') != 60 or trace.get('smoke') is not smoke or trace.get('failures') != []:
        raise ValueError('Failed or unexpected actual feedback trace')
    if trace.get('rendering') != {'actual_window': [960, 540], 'logical_content': [1280, 720]}:
        raise ValueError('Feedback was not rendered at the actual MovieMaker viewport')
    if abs(integer(trace['movie_clock']['frames_drawn_before_quit']) - count) > 2:
        raise ValueError('Engine.get_frames_drawn clock differs from actual media')
    expected = ['title', 'home_startup', 'home', 'plains_startup', 'bell', 'chest']
    if [s['id'] for s in trace['segments']] != expected:
        raise ValueError('Missing/reordered formal feedback chapters')
    previous = -1
    for segment in trace['segments']:
        start, end = integer(segment['start_frame']), integer(segment['end_frame'])
        if not previous <= start < end <= count:
            raise ValueError('Invalid actual MovieMaker segment bounds')
        previous = end
        expected_frames = {'title': 30 if smoke else 180, 'home_startup': 2, 'home': 120 if smoke else 720, 'bell': 120 if smoke else 360, 'chest': 120 if smoke else 720}
        if segment['id'] in expected_frames and end - start != expected_frames[segment['id']]:
            raise ValueError('Authored formal chapter length changed')
        if segment['id'] == 'plains_startup' and not 1 <= end - start <= 180:
            raise ValueError('Formal stage startup exceeded its bounded physical frames')
        rows = [r for r in trace['samples'] if r['phase'] == segment['id']]
        if not rows or len(rows) != end - start:
            raise ValueError('Missing actual feedback physical-frame samples')
        if [integer(r['movie_frame']) for r in rows] != list(range(start + 1, end + 1)):
            raise ValueError('Actual sample escaped its authored MovieMaker chapter')
        if [integer(r['physics_tick']) for r in rows] != list(range(integer(segment['first_physics_tick']) + 1, integer(segment['last_physics_tick']) + 1)):
            raise ValueError('Actual sample escaped its authored physics chapter')
        for a, b in zip(rows, rows[1:]):
            if integer(b['physics_tick']) - integer(a['physics_tick']) != 1 or integer(b['movie_frame']) - integer(a['movie_frame']) != 1:
                raise ValueError('Feedback trace has a physical/MovieMaker discontinuity')
        rect = segment['caption_rect']
        if rect[1] + rect[3] > 70:
            raise ValueError('Feedback subtitle extends into the game action area')
        for row in rows:
            expected_track = ['home'] if segment['id'] in ['title', 'home_startup', 'home'] else ['home', 'plains'] if segment['id'] == 'plains_startup' else ['plains']
            if row['music_track'] not in expected_track:
                raise ValueError('Original scene BGM context changed')
            for voice in row['voices']:
                if not math.isfinite(voice['volume_db']):
                    raise ValueError('Nonfinite original audio voice gain')
    ids = [e['id'] for e in trace['events']]
    assembly = next((e for e in trace['events'] if e['id'] == 'formal_sfx_assembly'), None)
    if not assembly or not assembly['data'].get('validation_ok') or assembly['data'].get('audio_profile') != 'selected':
        raise ValueError('Formal selected SFX assembly did not validate')
    formal = next((e for e in trace['events'] if e['id'] == 'formal_stage'), None)
    if not formal or not formal['data']['manifest_hash'] or formal['data']['chests'] < 1 or formal['data']['latches'] < 1:
        raise ValueError('Actual generated formal stage/chests/latches were not observed')
    if not smoke:
        for required in ['jump', 'land', 'shot', 'terrain_impact', 'hurt_fixture_commit', 'bell_opened', 'chest_choice_submitted', 'chest_claim_committed']:
            if required not in ids:
                raise ValueError('Actual fixture event missing: ' + required)
        home = [r for r in trace['samples'] if r['phase'] == 'home']
        for context, filename in [('title', 'the_kindred_hearth.mp3'), ('home', 'the_kindred_hearth.mp3'), ('bell', 'where_the_path_bends.mp3'), ('chest', 'where_the_path_bends.mp3')]:
            rows = [r for r in trace['samples'] if r['phase'] == context]
            if not any(v['playing'] and not v['paused'] and v['path'].endswith('/' + filename) for r in rows for v in r['music_voices']):
                raise ValueError('Actual original scene music voice missing: ' + context)
        if not any(e['id'] == 'terrain_impact' and e['phase'] == 'home' for e in trace['events']):
            raise ValueError('Home real terrain collision was not observed')
        hurt = [e for e in trace['events'] if e['id'] == 'hurt_fixture_commit']
        if len(hurt) != 1 or hurt[0]['data']['status'] != 0 or hurt[0]['data']['amount_applied'] != -1:
            raise ValueError('Actual Home APPLIED damage fixture differs')
        if not any(e['id'] == 'hurt' and '/feedback_05/hurt_' in e['path'] for r in home for e in r['director_events']):
            raise ValueError('Real Home damage did not select the revised hurt stream')
        if not any(v['playing'] and v['event'] == 'hurt' and '/feedback_05/hurt_' in v['path'] for r in home for v in r['voices']):
            raise ValueError('Revised Home hurt stream never actually played')
        if not any(v['playing'] and v['cue'] == 'weapon_wall' and '/feedback_05/wall_' in v['path'] for r in home for v in r['voices']):
            raise ValueError('Revised Home terrain-collision stream never actually played')
        claims = [e for e in trace['events'] if e['id'] == 'chest_claim_committed']
        if len(claims) != 1 or not claims[0]['data']['claimed']:
            raise ValueError('Actual generated chest claimed ledger missing')
        cues = claims[0]['data']['director_events']
        wanted = [e['id'] for e in cues if e['id'] in ['chest_open', 'item_get']]
        if wanted != ['chest_open', 'item_get']:
            raise ValueError('Actual chest/item successful transaction cue order differs')
        for event in ['chest_open', 'item_get']:
            if not any(v['playing'] and v['event'] == event for r in trace['samples'] if r['phase'] == 'chest' for v in r['voices']):
                raise ValueError('Actual committed reward voice did not play: ' + event)
    return {'chapters': [{'id': s['id'], 'start': s['start_frame'] / 60, 'end': s['end_frame'] / 60} for s in trace['segments']]}


def validate_wav(path, trace):
    """Check the actual captured PCM, never replace or remix it."""
    import wave
    import numpy as np
    with wave.open(str(path), 'rb') as stream:
        if (stream.getnchannels(), stream.getsampwidth(), stream.getframerate()) != (2, 2, 48000):
            raise ValueError('Unexpected native PCM WAV format')
        data = np.frombuffer(stream.readframes(stream.getnframes()), dtype='<i2').reshape(-1, 2).astype('float64') / 32768
    result = []
    for segment in trace['segments']:
        first, last = round(segment['start_frame'] / 60 * 48000), round(segment['end_frame'] / 60 * 48000)
        clip = data[first:last]
        rms = float(np.sqrt(np.mean(clip * clip))) if clip.size else 0
        peak = float(np.max(np.abs(clip))) if clip.size else 0
        if len(clip) != last - first or not np.isfinite(clip).all() or rms <= 1e-5:
            raise ValueError('Original native soundtrack missing/nonfinite/zero in ' + segment['id'])
        result.append({'chapter': segment['id'], 'rms': rms, 'peak': peak, 'samples': len(clip)})
    return {'chapters': result, 'scope': 'Actual native mixed PCM is nonzero in every chapter. Stream/event receipts identify live consumers; mixed PCM alone does not isolate each cue or certify aesthetics/physical devices.'}


def capture(output, smoke=False):
    if output.exists():
        raise ValueError('Use a fresh feedback output directory; preserve prior failures')
    output.mkdir(parents=True)
    started = time.monotonic()
    report = {'status': 'failed', 'task': 'AUDIO-FEEDBACK-05', 'version': VERSION,
              'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'scope': 'Actual formal demo.tscn continuous native MovieMaker capture; title/Home/Plains with explicit position/debug/damage fixtures; no dubbed audio or natural-campaign claim', 'smoke': smoke}
    display = lock = None
    owned = False
    cleanup_error = None
    override = ROOT / 'override.cfg'
    native, wav, movie = output / 'native.avi', output / 'native.wav', output / 'feedback.mp4'
    env = {**os.environ, 'LIBGL_ALWAYS_SOFTWARE': '1', 'LP_NUM_THREADS': '4'}
    try:
        if shutil.disk_usage(ROOT).free < 512 * 1024 * 1024:
            raise ValueError('Less than 512MiB free for owned native capture; no old evidence is deleted')
        lock = (ROOT / 'build/.audio_ambience_capture.lock').open('a')
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        fd = os.open(override, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        owned = True
        with os.fdopen(fd, 'wb') as stream:
            stream.write(CAPTURE_OVERRIDE)
            stream.flush()
            os.fsync(stream.fileno())
        (output / 'capture-override.cfg').write_bytes(CAPTURE_OVERRIDE)
        report['capture_override'] = {'path': 'override.cfg', 'content': CAPTURE_OVERRIDE.decode(), 'sha256': hashlib.sha256(CAPTURE_OVERRIDE).hexdigest(), 'created': True, 'removed': False, 'drifted': False, 'project_sha256_before': sha(ROOT / 'project.godot')}
        if not env.get('DISPLAY'):
            binary = shutil.which('Xvfb') or str(ROOT.parent / 'toolchains/xvfb/usr/bin/Xvfb')
            display = subprocess.Popen([binary, '-displayfd', '1', '-screen', '0', '960x540x24', '-nolisten', 'tcp', '-ac'], stdout=subprocess.PIPE, stderr=(output / 'display.log').open('w'), text=True)
            env['DISPLAY'] = ':' + display.stdout.readline().strip()
        engine_identity = verified_engine(repo=ROOT)
        report['engine'] = {'version': engine_identity['version'], 'sha256': engine_identity['binary_sha256']}
        before = frozen_sources()
        report['source_before'] = before
        command = ['bash', 'tools/godot.sh', '--path', '.', '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', '--write-movie', str(native), '--fixed-fps', '60', '--resolution', '960x540', '--script', 'res://tools/audio_feedback_capture.gd', '--', '--output=' + str(output)]
        if smoke:
            command.append('--scene-smoke')
        report['command'] = command
        with (output / 'native.log').open('w') as log:
            result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=900)
        report['exit_code'] = result.returncode
        # Preserve the original AVI fingerprint and format before removing this
        # one owned temporary container after lossless audio + actual MP4 exist.
        if native.is_file():
            report['native_container'] = {'path': 'native.avi', 'sha256': sha(native), 'bytes': native.stat().st_size, 'retained': True}
            report['native_media'] = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(native)]))
            video = next(s for s in report['native_media']['streams'] if s['codec_type'] == 'video')
            if (int(video['width']), int(video['height']), video['avg_frame_rate']) != (960, 540, '60/1'):
                raise ValueError('Actual AVI is not rendered at 960x540/60fps')
            subprocess.run(['ffmpeg', '-v', 'error', '-i', str(native), '-vn', '-c:a', 'copy', str(wav)], check=True, timeout=90)
            subprocess.run(['ffmpeg', '-i', str(native), '-c:v', 'libx264', '-preset', 'fast', '-crf', '23', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', str(movie)], stdout=subprocess.DEVNULL, stderr=(output / 'encode.log').open('w'), check=True, timeout=180)
            report['media'] = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(movie)]))
            encoded_video = next(s for s in report['media']['streams'] if s['codec_type'] == 'video')
            encoded_audio = next(s for s in report['media']['streams'] if s['codec_type'] == 'audio')
            if (int(encoded_video['width']), int(encoded_video['height']), encoded_video['avg_frame_rate'], int(encoded_audio['sample_rate']), encoded_audio['channels']) != (960, 540, '60/1', 48000, 2):
                raise ValueError('Unexpected actual feedback MP4 media')
            report.update(frame_count=int(encoded_video['nb_frames']), movie_sha256=sha(movie), movie_bytes=movie.stat().st_size, native_wav_sha256=sha(wav), native_wav_bytes=wav.stat().st_size)
            report['native_container']['removal_reason'] = 'Only this fresh output AVI is temporary; native PCM WAV, actual MP4, full AVI SHA/bytes/ffprobe index retained. No older evidence deleted.'
            # Only delete bytes still exactly matching our recorded container.
            if not native.is_symlink() and native.is_file() and sha(native) == report['native_container']['sha256']:
                native.unlink()
                report['native_container']['retained'] = False
            write(output / 'native-container-index.json', report['native_container'])
        text = (output / 'native.log').read_text()
        marker = 'AUDIO_FEEDBACK_CAPTURE smoke=%s failures=0' % ('true' if smoke else 'false')
        if result.returncode or ERROR.search(text) or marker not in text:
            raise ValueError('Native feedback run failed; original log/trace/audio retained')
        trace = read(output / 'trace.json')
        chapters = validate_trace(trace, report['frame_count'], smoke)
        report['native_audio_validation'] = validate_wav(wav, trace)
        write(output / 'chapters.json', chapters)
        report.update(trace_sha256=sha(output / 'trace.json'), chapters_sha256=sha(output / 'chapters.json'))
        after = frozen_sources()
        report.update(source_after=after, source_stable=before == after)
        if before != after:
            raise ValueError('Production/producer source changed during feedback capture')
        report['status'] = 'passed'
    except Exception as error:
        report['error'] = str(error)
        raise
    finally:
        if report.get('source_before') is not None:
            after = frozen_sources()
            report.update(source_after=after, source_stable=report['source_before'] == after)
            if not report['source_stable']:
                report['status'] = 'failed'
                report['source_error'] = 'Production/producer source drift retained'
        if display:
            display.terminate()
            try:
                display.wait(timeout=5)
            except subprocess.TimeoutExpired:
                display.kill()
                display.wait()
        if owned:
            row = report['capture_override']
            row['project_sha256_after'] = sha(ROOT / 'project.godot')
            if override.is_symlink() or not override.exists() or not stat.S_ISREG(override.lstat().st_mode) or override.read_bytes() != CAPTURE_OVERRIDE:
                row['drifted'] = True
                cleanup_error = 'Feedback capture override drifted; foreign/missing state preserved'
            else:
                override.unlink()
                row['removed'] = True
            if row['project_sha256_before'] != row['project_sha256_after']:
                cleanup_error = 'Formal project.godot changed during capture'
        if lock:
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
            lock.close()
        if cleanup_error:
            report.update(status='failed', cleanup_error=cleanup_error)
        report['seconds'] = time.monotonic() - started
        write(output / 'report.json', report)
        if cleanup_error:
            raise ValueError(cleanup_error)
    print(json.dumps({'status': report['status'], 'movie': str(movie), 'frames': report['frame_count']}))
    if report['status'] != 'passed':
        raise ValueError('Feedback report failed; see retained report.json')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--scene-smoke', action='store_true')
    args = parser.parse_args()
    capture(args.output.resolve(), args.scene_smoke)


if __name__ == '__main__':
    main()
