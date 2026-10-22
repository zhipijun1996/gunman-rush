"""Continuous MovieWriter AV of an existing formal F05 or F08 journey.

No new pilot,
fixture spawn, resources, physics stepping, BGM, or staged player pose.
"""
import argparse
from array import array
import contextlib
from fractions import Fraction
import hashlib
import json
import math
import os
from pathlib import Path
import re
import selectors
import shutil
import subprocess
import time
import wave

from forest_bible_world_sources import inventory
from run_forest_depth_region import import_inventory_guard, expected_itinerary, validate_movie_timeline
from run_tests import run_engine

ROOT = Path(__file__).resolve().parents[1]
ERRORS = re.compile(r'SCRIPT ERROR:|Parse Error:|SHADER ERROR:|^ERROR:|ObjectDB.*leaked|resources? still in use at exit', re.M)


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def sha(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def provenance():
    def git(*args):
        return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()
    return {'head': git('rev-parse', 'HEAD'), 'branch': git('branch', '--show-current'),
            'porcelain': git('status', '--porcelain=v1', '--untracked-files=all'),
            'tracked_diff_numstat': git('diff', '--numstat', 'HEAD'),
            'scope': 'HEAD plus exact complete runtime/test/tool byte inventory; WIP is not committed-release proof'}


@contextlib.contextmanager
def native_environment(output):
    """run_engine inherits this bounded software-GL environment; no engine fork."""
    binary = shutil.which('Xvfb')
    if binary is None:
        fallback = ROOT / 'build/forest_revision04/display-final-W6/runtime/usr/bin/Xvfb'
        if not fallback.is_file():
            raise RuntimeError('Actual Xvfb required; no screenshot or headless substitute')
        binary = str(fallback)
    command = [binary, '-displayfd', '1', '-screen', '0', '1280x720x24', '-nolisten', 'tcp', '-ac']
    with (output / 'display.log').open('wb') as log:
        display = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=log)
        patch = {'LIBGL_ALWAYS_SOFTWARE': '1', 'LP_NUM_THREADS': '1', 'OMP_NUM_THREADS': '1',
                 'GUNMAN_DATA_HOME': str(output / 'user-data'),
                 'XDG_CONFIG_HOME': str(output / 'config'), 'XDG_CACHE_HOME': str(output / 'cache')}
        previous = {}
        try:
            with selectors.DefaultSelector() as ready:
                ready.register(display.stdout, selectors.EVENT_READ)
                if not ready.select(20):
                    raise RuntimeError('Xvfb readiness exceeded20s')
                number = display.stdout.readline().decode().strip()
                if not number.isdigit():
                    raise RuntimeError('Invalid actual Xvfb display number')
            patch['DISPLAY'] = ':' + number
            previous = {key: os.environ.get(key) for key in patch}
            os.environ.update(patch)
            yield {'display_argv': command, 'environment_patch': patch}
        finally:
            for key, value in previous.items():
                if value is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = value
            if display.poll() is None:
                display.terminate()
                try:
                    display.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    display.kill(); display.wait(timeout=5)
            display.stdout.close()


def require(ok, reason):
    if not ok:
        raise RuntimeError(reason)


def original_pcm(path, output, video_frames):
    """Extract original PCM bytes, never resample, synthesize or pad a track."""
    wav = output / 'original.wav'
    command = ['ffmpeg', '-nostdin', '-v', 'error', '-i', str(path), '-map', '0:a:0', '-c:a', 'copy', str(wav)]
    with (output / 'original.wav.extract.log').open('wb') as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=180, check=True)
    with wave.open(str(wav), 'rb') as source:
        require((source.getnchannels(), source.getsampwidth(), source.getframerate(), source.getcomptype()) ==
                (2, 2, 48000, 'NONE'), 'Original audio must be uncompressed16bit/stereo48k')
        count = source.getnframes()
        peak = squared = nonzero = samples = 0
        while block := source.readframes(48000):
            values = array('h', block)
            if __import__('sys').byteorder != 'little':
                values.byteswap()
            peak = max(peak, max((abs(v) for v in values), default=0))
            squared += sum(v * v for v in values)
            nonzero += sum(v != 0 for v in values)
            samples += len(values)
    require(samples == count * 2 and abs(count - video_frames * 800) <= 800,
            'Original PCM duration must cover the complete60fps movie within one writer frame')
    require(peak > 0 and nonzero > 0 and squared > 0, 'Original MovieWriter audio is entirely silent')
    return {'argv': command, 'path': wav.name, 'sha256': sha(wav), 'sample_frames': count,
            'sample_rate': 48000, 'channels': 2, 'bits': 16, 'seconds': count / 48000,
            'duration_tolerance_samples': 800, 'peak_pcm16': peak,
            'rms_pcm16': math.sqrt(squared / samples), 'nonzero_samples': nonzero,
            'listening_acceptance': False}


def media_probe(path, output, original_audio=None, expected_frames=None):
    command = ['ffprobe', '-v', 'error', '-count_frames', '-show_streams', '-show_format', '-of', 'json', str(path)]
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=60)
    (output / (path.stem + '.ffprobe.stderr.log')).write_text(result.stderr)
    require(result.returncode == 0, 'ffprobe failed for ' + path.name)
    data = json.loads(result.stdout)
    write_json(output / (path.stem + '.ffprobe.json'), data)
    videos = [r for r in data.get('streams', []) if r.get('codec_type') == 'video']
    audios = [r for r in data.get('streams', []) if r.get('codec_type') == 'audio']
    require(len(videos) == len(audios) == 1, 'Exactly one original video and audio stream required')
    video, audio = videos[0], audios[0]
    count = int(video.get('nb_read_frames', 0))
    require((video.get('width'), video.get('height')) == (1280, 720)
            and Fraction(video.get('avg_frame_rate', '0/1')) == 60 and count > 0
            and int(audio.get('sample_rate', 0)) == 48000 and audio.get('channels') == 2,
            'Actual movie must be1280x720/60fps/stereo48k; no resampling or silent-track repair')
    require(expected_frames is None or count == expected_frames, 'MP4 dropped or duplicated original video frames')
    report = {'argv': command, 'exit_code': result.returncode, 'frames': count,
              'seconds_from_frames': count / 60, 'bytes': path.stat().st_size, 'sha256': sha(path)}
    if original_audio is None:
        require(path.suffix.lower() == '.avi' and audio.get('codec_name') == 'pcm_s16le',
                'Original AVI must contain the actual MovieWriter PCM16 track')
        report['pcm'] = original_pcm(path, output, count)
    else:
        require(audio.get('codec_name') == 'aac', 'Playback derivative must preserve the original track through AAC')
        duration = float(audio.get('duration', 'nan'))
        # AAC-LC uses1024sample packets: at most one priming and one tail
        # packet, plus the original writer's at-most-one-frame boundary.
        tolerance = 2 * 1024 / 48000 + 1 / 60
        require(math.isfinite(duration) and abs(duration - original_audio['seconds']) <= tolerance
                and abs(duration - count / 60) <= tolerance, 'AAC duration exceeds bounded codec packet padding')
        report.update(audio_seconds=duration, aac_duration_tolerance_seconds=tolerance,
                      audio_duration_policy='two1024sample AAC packets plus one original60fps writer frame')
    return report


def distance(a, b):
    require(isinstance(a, list) and isinstance(b, list) and len(a) == len(b) == 2
            and all(type(n) in (int, float) and math.isfinite(n) for n in a + b), 'Finite actual2D position required')
    return math.dist(a, b)


def selected_events(data, challenge):
    events = data['events']
    def one(kind):
        rows = [r for r in events if r.get('kind') == kind]
        require(len(rows) == 1, 'Required actual event missing or duplicated: ' + kind)
        return rows[0]
    if challenge == 'F05':
        departure = one('bible_F05_grounded_departure')
        cast = one('bible_F05_actual_descending_side_cast')
        require(departure['tick'] < cast['tick'] and departure['leg'] == cast['leg']
                and departure.get('method') == 'ordinary_walk_off_outside_edge'
                and departure.get('entry_support') == 'bible_backbranch__entry'
                and cast.get('grounded') is False and cast.get('outside_body') is True
                and cast.get('velocity', [0, 0])[1] > 0, 'F05 real grounded departure and descending outside cast required')
        hooks = [r for r in events if r.get('kind') == 'hook_contact_kick' and r.get('leg') == cast['leg']
                 and r.get('target') == 'bible_backbranch__side_fruit' and r['tick'] > cast['tick']]
        require(bool(hooks), 'F05 actual side-fruit contact missing')
        shots = [r for r in events if r.get('kind') == 'shot_fired' and r.get('leg') == cast['leg'] and r['tick'] > hooks[0]['tick']]
        require(bool(shots), 'F05 actual post-hook recoil shot missing')
        return [departure, cast, hooks[0], shots[0]]
    bank = one('spiral_actual_reader_bank')
    accepted = one('spiral_actual_queued_item_accepted')
    ascent = {r['leg'] for r in data['completed'] if r['edge_id'] == 'interwoven_deep_ascent'}
    hooks = [r for r in events if r.get('kind') == 'hook_contact_kick' and r.get('leg') in ascent and r['tick'] < bank['tick']]
    require(bool(hooks) and bank['tick'] < accepted['tick'], 'F08 actual ascent, Reader bank and accepted item sequence required')
    return [hooks[0], bank, accepted]


def verify_trace(data, challenge, map_index):
    require(challenge in ('F05', 'F08') and type(map_index) is int and map_index in (1, 2), 'Exact selected challenge/map required')
    frames, completed, m = data['frames'], data['completed'], data['manifest']
    require(data.get('failures') == [] and frames and completed, 'Existing formal journey failed or lacks Motor trace')
    require(data.get('manual_motor_step') is False and data.get('map_index') == map_index
            and type(data.get('map_index')) is int and type(m.get('map_index')) is int
            and m.get('map_index') == map_index and m.get('layout_version') == 'forest-bible-world-v15'
            and m.get('version') == 'thorn-forest-region-v2'
            and m.get('seed') == f"{data['seed']}/thorn_forest/map_{map_index}", 'Wrong actual map/version/seed or privileged Motor stepping')
    if challenge == 'F05':
        require(data.get('scope') == 'full_formal_spawn_Bible_world_Motor'
                and data.get('route') == 'bible_backbranch_journey' and data.get('position_or_resource_injection') is False,
                'F05 requires exact formal full-spawn existing runner')
        require(data.get('claimed', {}).get(f'thorn_forest/map_{map_index}/bible_backbranch_cache') is True
                and data.get('opened', {}).get('bible_backbranch_return') is True, 'Actual F05 cache and shortcut claim required')
    else:
        require(map_index == 2 and data.get('scope') == 'full_formal_spawn_F08_reader_and_other_exit'
                and data.get('route') == 'bible_spiral_journey' and data.get('mode') == 'full'
                and data.get('initial_fixture_spawn_override') is False and data.get('resource_or_health_override') is False
                and data.get('direct_claim_or_grant') is False, 'F08 requires full formal spawn, never LOCAL')
    legs = expected_itinerary(m, data['route'])
    require(len(legs) == data.get('itinerary_count') == len(completed), 'Incomplete actual generated itinerary')
    if 'itinerary' in data:
        require(data['itinerary'] == legs, 'Actual exported itinerary differs from generated route expansion')
    require(all(type(r.get('tick')) is int for r in frames)
            and [r.get('tick') for r in frames] == list(range(1, len(frames) + 1))
            and all(r.get('motor_steps') == 1 and type(r.get('motor_steps')) is int for r in frames),
            'Complete contiguous ticks with one ordinary Motor step required')
    require(all(r.get('health') == 5 for r in frames), 'Every actual route sample must retain full5HP')
    damage = [r for r in data['events'] if r.get('kind') == 'committed_damage' and r.get('target') == 'player']
    require(not damage, 'Committed player damage is forbidden for this route capture')
    epochs = {}
    for key in ('actor_epoch', 'stage_epoch'):
        values = {r.get(key) for r in frames}
        require(len(values) == 1 and all(type(n) is int and n > 0 for n in values), 'Actual ' + key + ' changed or missing')
        epochs[key] = next(iter(values))
    for key in ('owner_id', 'session_id', 'weapon_epoch'):
        values = {r.get('shot_economy', {}).get(key) for r in frames}
        require(len(values) == 1 and all(type(n) is int and n >= (0 if key == 'weapon_epoch' else 1) for n in values), 'Actual projectile custody changed: ' + key)
    initial, final = data['initial'], data['final']
    config = {'tuning': sha(ROOT / 'config/player_tuning.json'), 'traversal': sha(ROOT / 'resources/player/traversal.tres')}
    for sample in (initial, final):
        require(sample.get('config') == config and sample.get('health') == 5 and sample.get('hook_enabled') is True
                and sample.get('double_enabled') is False and sample.get('wall_enabled') is False
                and sample.get('weapon') == 'pulse_gun' and sample.get('tier') == 1, 'Actual config/basic Pulse/H-only setup required')
    require(distance(initial['position'], m['spawn']) < .01 and distance(final['position'], m['merchant_position']) <= 12,
            'Actual formal departure and final camp required')
    previous = 0
    for index, (row, leg) in enumerate(zip(completed, legs)):
        tick = row.get('tick')
        require(type(row.get('leg')) is int and row.get('leg') == index and row.get('edge_id') == leg['edge_id'] and row.get('start_tick') == previous + 1
                and type(tick) is int and previous < tick <= len(frames), 'Completed legs do not match the continuous generated route')
        require(distance(row['position'], leg['landing']) <= 12 and distance(row['position'], frames[tick - 1]['position']) < .01,
                'Completed actual leg lacks its real landing observation')
        previous = tick
    require(previous == len(frames) and distance(final['position'], frames[-1]['position']) < .01,
            'Trace tail missing or final snapshot detached from actual completed route')
    required = selected_events(data, challenge)
    if challenge == 'F08':
        core = data.get('core_evidence', {})
        require(core.get('id') == 'forest_spiral_core' and type(core.get('item_count_before')) is int and core.get('item_count_before') == 0
                and core.get('item_count_after') == 1 and type(core.get('item_count_after')) is int
                and core.get('projectile_damage_before') == 1 and core.get('projectile_damage_after') == 2.5
                and core.get('claim_via_real_Reader_buttons_and_App_postdamage_queue') is True
                and core.get('direct_claim_or_grant') is False, 'Exact real core item/count/damage effect required')
        receipt = core.get('actual_receipt', {})
        expected = {'amount': 0.0, 'approach_route': 'bible_spiral_approach', 'definition_id': 'spiral_core',
                    'id': 'forest_spiral_core', 'item': 'forest_spiral_core', 'kind': 'item',
                    'return_route': 'bible_spiral_return', 'story_read': True}
        require(set(receipt) == set(expected) | {'source_id'} and all(receipt.get(k) == v for k, v in expected.items())
                and re.fullmatch(r'forest_discovery:[1-9][0-9]*:' + str(epochs['stage_epoch']) + ':' + re.escape(m['manifest_hash']) + ':forest_spiral_core', receipt.get('source_id', '')),
                'Actual Reader receipt identity/custody differs')
        require(all(required[-1].get(k) == v for k, v in core.items())
                and {'interwoven_deep_ascent', 'bible_spiral_other_exit'}.issubset({r['edge_id'] for r in completed}),
                'Core receipt event or actual other exit missing')
        if 'claimed' in data:
            require(data['claimed'].get('forest_spiral_core') is True, 'Actual final Reader claim missing')
        pointers = data.get('pointer_events', [])
        require([(r.get('kind'), r.get('button_text')) for r in pointers] ==
                [('mouse_button_press', '查看发现物'), ('mouse_button_release', '查看发现物'),
                 ('mouse_button_press', '取用物资并记下线索'), ('mouse_button_release', '取用物资并记下线索')], 'Four actual visible Reader button inputs required')
        for row in pointers:
            x, y, w, h = row['rect']; px, py = row['position']
            require(w > 0 and h > 0 and x <= px <= x + w and y <= py <= y + h
                    and 0 <= px < 1280 and 0 <= py < 720, 'Actual Reader pointer must be inside visible button/viewport')
    return {'physics_samples': len(frames), 'completed_legs': len(completed), 'min_hp': 5,
            'actual_player_damage': damage, **epochs, 'actual_config': config}


def verify_movie_timeline(data, count, challenge):
    """Keep the original guard; only bounded actual process records get intervals."""
    for key in ('itinerary', 'requests', 'modal_frames', 'pointer_events'):
        require(key in data and isinstance(data[key], list), 'Missing native movie observation group: ' + key)
    require(data['requests'] and data['pointer_events'], 'Actual input records cannot be absent from a full movie')
    modal = data['modal_frames'] if challenge == 'F05' else data.get('reader_modal_frames', [])
    require(len(modal) >= 5 and all(r.get('paused') is True for r in modal), 'Actual paused modal observations required')
    require(len({r['motion_steps'] for r in modal}) == 1 and len({tuple(r['position']) for r in modal}) == 1,
            'Modal must freeze actual Motor steps and position')
    if challenge == 'F08':
        require(data.get('claimed', {}).get('forest_spiral_core') is True, 'Actual final Reader claim snapshot required')
    timeline = {**data, 'modal_frames': modal}
    errors = validate_movie_timeline(timeline, count)
    alignment = {'movie_events_not_aligned_to_actual_physics_draw', 'movie_requests_not_aligned_to_actual_physics_draw'}
    require(not (set(errors) - alignment), 'Original complete movie guard: ' + ', '.join(errors))
    groups = ('frames', 'events', 'requests', 'modal_frames', 'pointer_events')
    for group in groups:
        rows = timeline[group]
        require(all(r.get('observation_phase') in ('physics', 'process') and type(r.get('process_frame')) is int
                    and type(r.get('engine_physics_frame')) is int and r['engine_physics_frame'] > 0 for r in rows),
                'Missing actual engine phase/process counter in ' + group)
        require(all(a['process_frame'] <= b['process_frame'] for a, b in zip(rows, rows[1:])), 'Reversed actual process counter in ' + group)
    require(all(r['observation_phase'] == 'physics' for r in data['frames']), 'Motor samples must come from actual physics phase')
    counters = [r['engine_physics_frame'] for r in data['frames']]
    require(all(a < b for a, b in zip(counters, counters[1:])), 'Actual physics samples need unique increasing engine counters')
    by_engine = {r['engine_physics_frame']: r for r in data['frames']}
    physical = {**timeline}
    preincrement = []
    for group in ('events', 'requests'):
        observed = []
        for row in data[group]:
            if row['observation_phase'] != 'physics':
                continue
            sample = by_engine.get(row['engine_physics_frame'])
            require(sample is not None and type(row.get('tick')) is int
                    and row['tick'] in (sample['tick'], sample['tick'] - 1)
                    and row['presentation_frame'] == sample['presentation_frame']
                    and row['process_frame'] == sample['process_frame'],
                    'Physics record must match its unique real engine-frame sample/draw/process counter')
            # The old human/grove observers can log before incrementing their
            # auxiliary tick. Normalize only this detached validation view from
            # the independently recorded engine identity; raw data stays exact.
            observed.append({**row, 'tick': sample['tick']})
            if row['tick'] != sample['tick']:
                preincrement.append({'group': group, 'kind': row.get('kind'), 'declared_tick': row['tick'],
                                     'observed_tick': sample['tick'], 'engine_physics_frame': row['engine_physics_frame']})
        physical[group] = observed
    require(not validate_movie_timeline(physical, count), 'Original exact physics-draw alignment rejected')
    by_tick = {r['tick']: r for r in data['frames']}
    for row in modal + data['pointer_events']:
        require(row['observation_phase'] == 'process' and type(row.get('tick')) is int and row['tick'] in by_tick,
                'Modal/pointer must carry its actual process-phase tick')
        current = by_tick[row['tick']]
        following = by_tick.get(row['tick'] + 1)
        require(following is not None and current['presentation_frame'] <= row['presentation_frame'] < following['presentation_frame']
                and current['process_frame'] <= row['process_frame'] < following['process_frame'],
                'Modal/pointer outside its actual half-open physics/draw interval')
    modal_first = min(r['presentation_frame'] for r in modal + data['pointer_events'])
    modal_last = max(r['presentation_frame'] for r in modal + data['pointer_events'])
    process_rows = []
    reasons = ({'region_cache', 'pause', 'region_cache_complete'} if challenge == 'F05'
               else {'menu', 'pause', 'forest_reader_confirm', 'forest_reader_close'})
    seal = 'Bible_world_trace_sealed' if challenge == 'F05' else 'Bible_spiral_trace_sealed'
    aim_events = []
    for group in ('events', 'requests'):
        for row in data[group]:
            if row['observation_phase'] != 'process':
                continue
            kind = row.get('kind')
            is_seal = group == 'events' and kind == 'actual_input_cancelled' and row.get('reason') == seal
            require(row.get('tick') in by_tick, 'Process observation outside actual physics ticks')
            current = by_tick[row['tick']]
            following = by_tick.get(row['tick'] + 1)
            require(current['presentation_frame'] <= row['presentation_frame'] < (following['presentation_frame'] if following else count)
                    and current['process_frame'] <= row['process_frame']
                    and (following is None or row['process_frame'] < following['process_frame']), 'Process record outside its actual half-open physics/draw interval')
            if following is None:
                require(is_seal and row['tick'] == len(data['frames']), 'Only exact completed-route sealing can follow the final physics sample')
            if group == 'requests':
                require(kind == 'actual_mouse_button' and row.get('button') in (1, 2)
                        and type(row.get('pressed')) is bool and row.get('aim_kind') in ('shot', 'hook'), 'Unknown process input record')
            elif kind == 'bible_actual_aim_release':
                require(row.get('sample') in data.get('aim_samples', []) and row['sample'].get('tick') == row['tick']
                        and row['sample'].get('leg') == row.get('leg'), 'Process aim release does not match its actual held sample')
                aim_events.append(row['sample'])
            elif kind == 'spiral_actual_queued_item_accepted':
                require(challenge == 'F08' and all(row.get(k) == v for k, v in data['core_evidence'].items()), 'Process core event differs from real claim')
            else:
                require(kind == 'actual_input_cancelled' and (is_seal or row.get('reason') in reasons), 'Unknown process event')
                if not is_seal:
                    require(modal_first <= row['presentation_frame'] <= modal_last, 'Process cancellation outside actual modal/pointer window')
            process_rows.append({'group': group, 'kind': kind, 'tick': row['tick'], 'frame': row['presentation_frame']})
    require(aim_events == data.get('aim_samples'), 'Every actual held aim sample must have its exact process release record')
    for row in modal:
        require(row['observation_phase'] == 'process', 'Modal must be sampled in actual process phase')
    if challenge == 'F08':
        bank, accepted = selected_events(data, challenge)[1:]
        pointers = data['pointer_events']
        require(bank['presentation_frame'] <= pointers[0]['presentation_frame'] <= pointers[1]['presentation_frame']
                <= pointers[2]['presentation_frame'] <= pointers[3]['presentation_frame'] <= accepted['presentation_frame'],
                'Actual Reader bank/pointer/accept draw order differs')
        require(all(r.get('actor_epoch') == data['frames'][0]['actor_epoch'] and r.get('stage_epoch') == data['frames'][0]['stage_epoch'] for r in modal),
                'Reader modal actor/stage custody changed')
    return {'original_guard_reused': True, 'physics_sample_binding': 'actual_engine_counter_draw_and_process_exact',
            'raw_ticks_unchanged': True, 'preincrement_observations': preincrement, 'bounded_process_observations': process_rows,
            'video_frames': count, 'modal_samples': len(modal), 'no_counter_reconstruction': True}


def keyframes(data, count, challenge):
    """Required actual events never disappear through optional picks or dedup."""
    picks = [{'kind': r['kind'], 'tick': r['tick'], 'frame': r.get('presentation_frame')} for r in selected_events(data, challenge)]
    for label, row in [('formal_route_first_observed_frame', data['frames'][0]), ('formal_route_final_observed_frame', data['frames'][-1])]:
        picks.append({'kind': label, 'tick': row['tick'], 'frame': row.get('presentation_frame')})
    require(all(type(r['frame']) is int and 0 <= r['frame'] < count for r in picks), 'Required actual event lacks bounded draw counter')
    grouped = {}
    for row in picks:
        grouped.setdefault(row['frame'], {'frame': row['frame'], 'events': []})['events'].append({'kind': row['kind'], 'tick': row['tick']})
    require(len(grouped) >= 3, 'Required events collapsed to a static/constant draw counter')
    return [grouped[index] for index in sorted(grouped)]


def verify_pixel_motion(images):
    from PIL import Image, ImageChops, ImageStat
    require(len(images) >= 3, 'At least three original event frames required for pixel comparison')
    comparisons = []
    previous = None
    for path in images:
        with Image.open(path) as source:
            require(source.size == (1280, 720), 'Extracted original event frame has wrong resolution')
            current = source.convert('RGB')
        if previous is not None:
            delta = ImageChops.difference(previous, current)
            mean = sum(ImageStat.Stat(delta).mean) / 3
            comparisons.append({'mean_absolute_rgb_difference': mean, 'changed_bbox': delta.getbbox()})
        previous = current
    require(any(r['mean_absolute_rgb_difference'] > 1 for r in comparisons), 'Original selected route frames are static or lack meaningful pixel motion')
    return {'comparisons': comparisons, 'threshold_mean_absolute_rgb': 1, 'scope': 'Actual decoded original-event pixel differences plus complete draw timeline; no aesthetic acceptance'}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--challenge', choices=('F05', 'F08'), required=True)
    parser.add_argument('--map', type=int, choices=(1, 2), default=2)
    parser.add_argument('--seed', default='forest-depth-hollow-00')
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if args.challenge == 'F08' and args.map != 2:
        parser.error('Existing F08 formal runner is map2 only')
    output = args.output.resolve()
    if not output.is_relative_to(ROOT / 'build') or output.exists():
        parser.error('Fresh output below repository build required')
    output.mkdir(parents=True)
    started = time.monotonic()
    receipt = {'scope': 'Continuous existing formal full-spawn route AV; no new pilot or gameplay/device/FUN/audio-listening acceptance',
               'challenge': args.challenge, 'seed': args.seed, 'map': args.map,
               'source_before': inventory(), 'provenance_before': provenance(),
               'import_cap_seconds': 90, 'native_cap_seconds': 240, 'exit_code': 1,
               'free_bytes_before': shutil.disk_usage(output).free,
               'audio_format_policy': 'Require original MovieWriter stereo48k in raw AVI, then encode same tracks; Dummy is backend, no physical device/listening claim',
               'commands': [], 'checks': {}}
    try:
        import_args = ['--headless', '--path', '.', '--editor', '--quit']
        receipt['commands'].append({'phase': 'import', 'argv': ['bash', str(ROOT / 'tools/godot.sh'), *import_args], 'timeout_seconds': 90})
        with (output / 'import.log').open('w') as log, contextlib.redirect_stdout(log):
            import_text = run_engine(import_args, 90)
        if ERRORS.search(import_text):
            raise RuntimeError('Unexpected import error or resource leak')
        after_import = inventory()
        receipt['source_after_import'] = after_import
        receipt['import_guard'] = import_inventory_guard(receipt['source_before'], after_import)
        if not receipt['import_guard']['passed']:
            raise RuntimeError('Source changed during import beyond allowed UID/import metadata')
        raw, trace = output / 'original.avi', output / 'trace.json'
        runner = ('tests/forest_bible_world_motor_runner.gd' if args.challenge == 'F05'
                  else 'tests/forest_bible_spiral_motor_runner.gd')
        native_args = ['--path', '.', '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy',
                       '--resolution', '1280x720', '--fixed-fps', '60', '--write-movie', str(raw),
                       '--script', runner, '--', '--output=res://' + trace.relative_to(ROOT).as_posix(),
                       '--seed=' + args.seed, '--capture-movie']
        native_args += (['--route=bible_backbranch_journey', '--map=' + str(args.map)]
                        if args.challenge == 'F05' else ['--mode=full'])
        with native_environment(output) as display:
            receipt['native_environment'] = display
            receipt['commands'].append({'phase': 'native', 'argv': ['bash', str(ROOT / 'tools/godot.sh'), *native_args], 'timeout_seconds': 240})
            with (output / 'native.log').open('w') as log, contextlib.redirect_stdout(log):
                native_text = run_engine(native_args, 240)
        marker = 'FOREST BIBLE WORLD MOTOR: PASS' if args.challenge == 'F05' else 'FOREST BIBLE F08 MOTOR: PASS'
        if (marker not in native_text or ERRORS.search(native_text) or 'OpenGL API' not in native_text
                or 'Godot Engine v4.7.2.stable.official.ed1daf0bf' not in native_text):
            raise RuntimeError('Exact engine, real GL, existing runner completion and clean resource teardown required')
        data = json.loads(trace.read_text())
        if data.get('seed') != args.seed:
            raise RuntimeError('Actual formal root seed differs')
        receipt['checks']['existing_route'] = verify_trace(data, args.challenge, args.map)
        receipt['checks']['raw_media'] = media_probe(raw, output)
        count = receipt['checks']['raw_media']['frames']
        receipt['checks']['movie_timeline'] = verify_movie_timeline(data, count, args.challenge)
        receipt['keyframes'] = keyframes(data, count, args.challenge)
        # Godot and Xvfb have finished. Retain the original AVI; derivatives are
        # encoded and extracted only now, never by polling active PNG frames.
        mp4 = output / 'playback.mp4'
        encode = ['ffmpeg', '-nostdin', '-v', 'error', '-i', str(raw), '-map', '0:v:0', '-map', '0:a:0',
                  '-c:v', 'libx264', '-threads', '1', '-preset', 'veryfast', '-crf', '18', '-pix_fmt', 'yuv420p',
                  '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart', str(mp4)]
        receipt['commands'].append({'phase': 'encode', 'argv': encode, 'timeout_seconds': 180})
        with (output / 'encode.log').open('wb') as log:
            subprocess.run(encode, stdout=log, stderr=subprocess.STDOUT, timeout=180, check=True)
        receipt['checks']['mp4_media'] = media_probe(mp4, output, receipt['checks']['raw_media']['pcm'], count)
        if receipt['checks']['mp4_media']['frames'] != count:
            raise RuntimeError('MP4 derivative dropped or duplicated original video frames')
        frames_dir = output / 'keyframes'; frames_dir.mkdir()
        select = "select='" + '+'.join('eq(n,%s)' % r['frame'] for r in receipt['keyframes']) + "'"
        extract = ['ffmpeg', '-nostdin', '-v', 'error', '-threads', '1', '-i', str(raw), '-vf', select,
                   '-fps_mode', 'passthrough', str(frames_dir / '%02d.png')]
        receipt['commands'].append({'phase': 'extract_selected_original_frames', 'argv': extract, 'timeout_seconds': 180})
        with (output / 'extract.log').open('wb') as log:
            subprocess.run(extract, stdout=log, stderr=subprocess.STDOUT, timeout=180, check=True)
        images = sorted(frames_dir.glob('*.png'))
        if len(images) != len(receipt['keyframes']):
            raise RuntimeError('Not all selected original draw frames were extracted')
        receipt['checks']['actual_pixel_motion'] = verify_pixel_motion(images)
        for row, path in zip(receipt['keyframes'], images):
            row.update(path=path.relative_to(output).as_posix(), sha256=sha(path))
        receipt['exit_code'] = 0
    except (OSError, RuntimeError, ValueError, KeyError, TypeError, IndexError, subprocess.SubprocessError) as error:
        receipt['error'] = type(error).__name__ + ': ' + str(error)
    finally:
        try:
            receipt['source_after'] = inventory()
            receipt['provenance_after'] = provenance()
            receipt['source_stable'] = (receipt.get('import_guard', {}).get('passed') is True
                                        and receipt['source_after_import'] == receipt['source_after']
                                        and receipt['provenance_before']['head'] == receipt['provenance_after']['head'])
            if not receipt['source_stable']:
                receipt['exit_code'] = 1
                receipt.setdefault('error', 'Source/HEAD closure changed or import guard absent')
        except (OSError, subprocess.SubprocessError) as error:
            receipt.update(exit_code=1, source_stable=False, source_guard_error=str(error))
        receipt['elapsed_seconds'] = time.monotonic() - started
        receipt['free_bytes_after'] = shutil.disk_usage(output).free
        receipt['artifacts'] = {p.relative_to(output).as_posix(): {'bytes': p.stat().st_size, 'sha256': sha(p)}
                                for p in output.rglob('*') if p.is_file() and p.name != 'receipt.json'}
        write_json(output / 'receipt.json', receipt)
    print(json.dumps({key: receipt.get(key) for key in ('challenge', 'seed', 'map', 'exit_code', 'source_stable', 'elapsed_seconds', 'error')}, ensure_ascii=False))
    return receipt['exit_code']


if __name__ == '__main__':
    raise SystemExit(main())
