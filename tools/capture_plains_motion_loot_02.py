#!/usr/bin/env python3
"""Record disclosed App/Router combat and real death-loot transactions at 60fps.

The original engine PCM is preserved. Full/subset coverage and source integrity
are separate from human visual, listening and device acceptance.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import harness
from enemy_all_review_02 import original_audio_statistics

ROSTER = ('patrol', 'charger', 'diver', 'hopper', 'sentry', 'fan_sentry', 'root_bell')
ALIASES = {'patrol_drone': 'patrol', **{'plains_' + name: name for name in ROSTER if name != 'patrol'}}
DRIVER = 'tools/plains_motion_loot_02_capture.gd'


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def selection(raw):
    if not raw:
        return list(ROSTER)
    requested = raw.split(',')
    normalized = [ALIASES.get(name, name) for name in requested]
    if any(name not in ROSTER for name in normalized) or len(set(normalized)) != len(normalized):
        raise ValueError('Unknown or duplicate species/behavior')
    return [name for name in ROSTER if name in normalized]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--seed', default='plains-motion-loot-02')
    subset = parser.add_mutually_exclusive_group()
    subset.add_argument('--species', default='', help='Comma-separated stable species IDs or behavior names')
    subset.add_argument('--behaviors', default='', help='Comma-separated behavior subset; omitted means all seven')
    parser.add_argument('--retain-avi', action='store_true')
    args = parser.parse_args()
    try:
        wanted = selection(args.species or args.behaviors)
    except ValueError as error:
        parser.error(str(error))
    folder = args.output.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    source = harness.git_metadata()
    before = harness.source_inventory()
    report = {'task': 'PLAINS-MOTION-LOOT-02', 'status': 'running', 'source': source,
              'selected_behaviors': wanted, 'whole_roster': len(wanted) == 7,
              'driver_sha256': digest(ROOT / DRIVER), 'source_files_before': before,
              'scope': 'Disclosed .8s idle movement hold followed by real Factory AI, InputRouter/projectiles and App reward/health transactions on unchanged original plains terrain; not a natural generated roster/route.',
              'user_acceptance': 'pending', 'listening_acceptance': False, 'device_acceptance': 'unverified'}
    env = os.environ.copy()
    env['LIBGL_ALWAYS_SOFTWARE'] = '1'
    display = display_log = None
    started = time.monotonic()
    exit_code = 0
    try:
        if not env.get('DISPLAY'):
            candidate = Path(os.environ.get('GUNMAN_TOOLCHAIN_ROOT', str(ROOT.parent / 'toolchains'))) / 'xvfb/usr/bin/Xvfb'
            binary = shutil.which('Xvfb') or (str(candidate) if candidate.is_file() else None)
            if not binary:
                raise RuntimeError('Xvfb required for genuine pixels')
            display_log = (folder / 'display.log').open('wb')
            display = subprocess.Popen([binary, '-displayfd', '1', '-screen', '0', '1280x720x24', '-nolisten', 'tcp', '-ac'], stdout=subprocess.PIPE, stderr=display_log)
            with selectors.DefaultSelector() as selector:
                selector.register(display.stdout, selectors.EVENT_READ)
                if not selector.select(30):
                    raise RuntimeError('Xvfb startup timeout')
                number = display.stdout.readline().decode().strip()
            if not number.isdigit():
                raise RuntimeError('Invalid Xvfb display')
            env['DISPLAY'] = ':' + number
        avi, movie, trace_path = (folder / name for name in ('capture.avi', 'review.mp4', 'trace.json'))
        command = ['bash', 'tools/godot.sh', '--path', '.', '--rendering-method', 'gl_compatibility', '--write-movie', str(avi), '--fixed-fps', '60', '--script', DRIVER, '--', '--trace=' + str(trace_path), '--seed=' + args.seed, '--behaviors=' + ','.join(wanted)]
        report['command'] = command
        result = harness.run_check({'argv': command, 'timeout_seconds': max(240, len(wanted) * 120), 'success_pattern': r'^PLAINS MOTION LOOT REVIEW: complete; cases=\d+; frames=\d+; failures=0$'}, folder / 'capture.log', ROOT, env)
        report['execution'] = result
        if result['status'] != 'passed':
            raise RuntimeError('Godot capture failed; retain original AVI/log/trace as failed evidence')
        trace = json.loads(trace_path.read_text())
        if not trace.get('complete') or trace.get('failures') or trace.get('selected_behaviors') != wanted or len(trace.get('cases', [])) != len(wanted):
            raise RuntimeError('Incomplete requested subset, source, teardown or gameplay coverage')
        rows = trace.get('frames', [])
        if not rows or [row['frame'] for row in rows] != list(range(1, len(rows) + 1)):
            raise RuntimeError('Active-frame observations are not continuous')
        if trace.get('postdraw_rows', 0) < len(rows) - len(wanted) * 3:
            raise RuntimeError('Missing actual renderer post-draw observations')
        for case in trace['cases']:
            if case.get('coverage_gaps') or not case.get('original_manifest_unchanged') or case['actual_wallet_delta'] != case['configured_coin_total']:
                raise RuntimeError('Coverage/amount/manifest mismatch for ' + case['id'])
            if not any(event['amount'] < 0 and not event['terminal'] for event in case['events']) or sum(bool(event['terminal']) for event in case['events']) != 1:
                raise RuntimeError('Actual nonlethal then single lethal commits required')
            if not case['shots'] or not case['inputs']:
                raise RuntimeError('Real Router/projectile evidence missing')
        if 'root_bell' in wanted and (not trace.get('actual_heal_observed') or not trace.get('root_7_equals_5_1_1')):
            raise RuntimeError('Actual heal and seven-coin denomination proof required')
        report['original_engine_audio'] = original_audio_statistics(avi, folder)
        with (folder / 'encode.log').open('wb') as log:
            subprocess.run(['ffmpeg', '-y', '-i', str(avi), '-c:v', 'libx264', '-crf', '20', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-movflags', '+faststart', str(movie)], stdout=subprocess.DEVNULL, stderr=log, check=True, timeout=max(120, len(wanted) * 30))
        media = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(movie)], timeout=30))
        video = next(stream for stream in media['streams'] if stream['codec_type'] == 'video')
        audio = next(stream for stream in media['streams'] if stream['codec_type'] == 'audio')
        duration = float(media['format']['duration'])
        if (video['width'], video['height'], video['avg_frame_rate'], audio['sample_rate'], audio['channels']) != (1280, 720, '60/1', '48000', 2):
            raise RuntimeError('Normal-speed original pixels/stereo contract mismatch')
        if any(not (0 <= case['start_seconds'] < case['end_seconds'] <= duration + .1) for case in trace['cases']):
            raise RuntimeError('Declared original movie chapter bounds outside actual media')
        after = harness.source_inventory()
        report['source_files_after'] = after
        report['source_after'] = harness.git_metadata()
        report['source_stable'] = before == after and source == report['source_after'] and trace.get('source_stable') is True
        if not report['source_stable']:
            raise RuntimeError('Source changed during capture/encoding')
        chapters = [{key: case[key] for key in ('case', 'id', 'behavior', 'start_frame', 'end_frame', 'start_seconds', 'end_seconds', 'configured_coin_total', 'actual_wallet_delta', 'coverage', 'coverage_gaps')} for case in trace['cases']]
        (folder / 'chapters.json').write_text(json.dumps(chapters, ensure_ascii=False, indent=2) + '\n')
        report.update(status='recorded_complete_coverage', media=media, trace_frame_count=len(rows), chapters=chapters,
                      mp4_sha256=digest(movie), avi_sha256=digest(avi), trace_sha256=digest(trace_path),
                      trace_bytes=trace_path.stat().st_size, raw_avi_retained=args.retain_avi)
        if not args.retain_avi:
            avi.unlink()
        print(f'PLAINS MOTION LOOT MOVIE: {len(wanted)} actual chapters; {duration:.2f}s; 0 gaps; {movie}')
    except BaseException as error:
        report.update(status='failed', error=str(error))
        print(str(error), file=sys.stderr)
        exit_code = 1
    finally:
        report['seconds'] = time.monotonic() - started
        (folder / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        if display is not None:
            display.terminate()
            try:
                display.wait(timeout=5)
            except subprocess.TimeoutExpired:
                display.kill(); display.wait()
        if display_log:
            display_log.close()
    return exit_code


if __name__ == '__main__':
    raise SystemExit(main())
