"""Pixel-bound visual production adapter; uses the existing formal driver and Harness loop.

Capture integrity, computable candidates, AI review and human acceptance stay separate.
No live PNG readback: images are extracted from the completed real Godot movie.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import selectors
import struct
import shutil
import subprocess
import sys
import time
import tempfile

import harness
import level_formal
from level_design import ROOT, read, write, file_hash


# Explicit experimental capture adapter; arbitrary script execution is not a CLI option.
ENVIRONMENT_CAPTURE = "tools/plains_environment_capture.gd"
PLACES_CAPTURE = "tools/plains_places_capture.gd"
REGIONAL_CAPTURE = "tools/plains_regional_art_capture.gd"
JOINT_RECOIL_CAPTURE = "tools/plains_joint_recoil_capture.gd"
ENVIRONMENT_CAPTURES = (ENVIRONMENT_CAPTURE, PLACES_CAPTURE)
CAPTURE_SCRIPTS = {"tools/spatial_golden_capture.gd", "tools/painted_formal_capture.gd", "tools/p1_random_capture.gd", REGIONAL_CAPTURE, JOINT_RECOIL_CAPTURE, *ENVIRONMENT_CAPTURES}
VISUAL_SAMPLE_CATALOG = "res://resources/visual_development/candidate.json"
VISUAL_SAMPLE_CATALOGS = (VISUAL_SAMPLE_CATALOG, "res://resources/visual_development/painted_terrain_candidate.json", "res://resources/visual_development/p1_candidate.json")

def valid_visual_sample(script, sample):
    return ((script == 'tools/spatial_golden_capture.gd' and sample in VISUAL_SAMPLE_CATALOGS)
            or (script == 'tools/painted_formal_capture.gd' and sample == VISUAL_SAMPLE_CATALOGS[1])
            or (script == 'tools/p1_random_capture.gd' and sample == VISUAL_SAMPLE_CATALOGS[2]))


def capture_extension_sources(script):
    if script is None:
        return {}
    if script not in CAPTURE_SCRIPTS:
        raise ValueError("Unsupported capture script")
    pending = [script]
    if script == "tools/spatial_golden_capture.gd":
        pending.append("tools/spatial_golden_preview.gd")
    if script == ENVIRONMENT_CAPTURE:
        pending.append("tools/plains_environment_preview.gd")
    if script == PLACES_CAPTURE:
        pending.append("tools/plains_places_preview.gd")
    if script == REGIONAL_CAPTURE:
        pending.append("tools/plains_regional_art_preview.gd")
    if script == JOINT_RECOIL_CAPTURE:
        pending.append("tools/plains_joint_recoil_preview.gd")
    result = {}
    while pending:
        relative_path = pending.pop()
        if relative_path in result:
            continue
        path = (ROOT / relative_path).resolve()
        if not path.is_relative_to(ROOT) or not path.is_file():
            raise ValueError("Missing capture extension source: " + relative_path)
        result[relative_path] = file_hash(path)
        pending.extend(re.findall(r"res://((?:tests|tools)/[a-zA-Z0-9_/]+[.]gd)", path.read_text()))
    return dict(sorted(result.items()))


def sources(capture_script=None):
    result = level_formal.source_files()
    for p in (ROOT / 'assets').rglob('*'):
        if p.is_file() and p.suffix != '.import':
            result[p.relative_to(ROOT).as_posix()] = file_hash(p)
    result[Path(__file__).relative_to(ROOT).as_posix()] = file_hash(Path(__file__))
    result.update(capture_extension_sources(capture_script))
    return dict(sorted(result.items()))


def relative(path):
    return str(Path(path).resolve().relative_to(ROOT))


def artifact(path):
    return {'path': relative(path), 'sha256': file_hash(Path(path))}


def capture(seed, map_index, strategy, folder, max_ticks=6000, timeout=900,
            encounter_policy='kill_from_bank_v1', phase_wait_ticks=0, frame_stride=120, composition=False, capture_script=None, visual_sample='', visual_layout='', environment_phase='full', environment_mutation=''):
    folder = Path(folder).resolve()
    if not folder.is_relative_to(ROOT / 'build') or folder.exists():
        raise ValueError('Use a NEW build/ directory; failed attempts are immutable')
    tick_limit = 36000 if capture_script == REGIONAL_CAPTURE else 18000
    if not (1 <= max_ticks <= tick_limit and 0 <= phase_wait_ticks <= 600 and 1 <= frame_stride <= 3600 and 1 <= timeout <= 3600):
        raise ValueError('Unbounded capture request')
    if map_index not in (1, 2) or strategy not in ('fast', 'growth', 'deep', 'return') or encounter_policy not in level_formal.ENCOUNTER_POLICIES:
        raise ValueError('Unknown formal driver request')
    extension_sources = capture_extension_sources(capture_script)
    if environment_phase not in ('probe', 'full') or environment_mutation not in ('', 'no-gun') or ((environment_phase != 'full' or environment_mutation) and capture_script not in ENVIRONMENT_CAPTURES):
        raise ValueError('Unsupported explicit environment request')
    if capture_script in ENVIRONMENT_CAPTURES and (map_index != 1 or strategy != 'fast' or encounter_policy != 'blind_legacy'):
        raise ValueError('Environment candidate requires independent map1/fast/blind_legacy; its route policy is explicit')
    if visual_sample and not valid_visual_sample(capture_script, visual_sample):
        raise ValueError('Unsupported explicit visual sample catalog')
    if visual_sample and not (ROOT / visual_sample.removeprefix('res://')).is_file():
        raise ValueError('Missing explicit visual sample catalog')
    if visual_layout not in ('', 'open-meadow') or (visual_layout and capture_script != 'tools/spatial_golden_capture.gd'):
        raise ValueError('Unsupported explicit visual layout')
    if visual_sample and capture_script == 'tools/spatial_golden_capture.gd' and visual_layout != 'open-meadow':
        raise ValueError('Visual sample requires explicit open-meadow layout')
    folder.mkdir(parents=True)
    before = sources(capture_script)
    request = dict(source_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                   root_seed=seed, map_index=map_index, strategy=strategy, phase_wait_ticks=phase_wait_ticks,
                   max_ticks=max_ticks, encounter_policy=encounter_policy)
    if capture_script is not None:
        request['capture_script'] = capture_script
        request['visual_sample'] = visual_sample
        request['visual_layout'] = visual_layout
    if capture_script in ENVIRONMENT_CAPTURES:
        request.update(environment_phase=environment_phase, environment_mutation=environment_mutation)
    report = dict(schema_version=1, artifact_kind='actual_formal_visual_capture', status='running', producer_root=str(ROOT),
                  request=request, source_before=before, source_after=None, errors=[],
                  subjective_acceptance='unverified', device_acceptance='unverified',
                  scope='Real DemoApp camera, enemies, Motor and synthetic Router input; post-extracted video frames are NOT exact physics-tick screenshots',
                  started_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()))
    if capture_script is not None:
        report['capture_extension'] = {'script': capture_script, 'sources': extension_sources,
            'scope': 'explicit experimental spatial fixture; not campaign arrival or pure-art equivalence'}
    if composition:
        report['composition_capture']={'requested':True,'raw_path':relative(folder/'composition_raw.json')}
    report['composition_observation_status']='pending' if composition else 'not_requested'
    receipt = folder / 'visual_capture.json'
    write(receipt, report)
    display = None
    display_log = None
    started = time.monotonic()
    env = os.environ.copy()
    env.update(LIBGL_ALWAYS_SOFTWARE='1', LP_NUM_THREADS='1')
    output, avi, movie = folder/'capture.json', folder/'gameplay.avi', folder/'gameplay.mp4'
    scratch_avi = None
    try:
        if capture_script in (REGIONAL_CAPTURE, JOINT_RECOIL_CAPTURE):
            # Full-region raw movies can exceed the workspace disk. Keep the
            # bounded producer destination unchanged and explicitly record the
            # unique system-temp backing file. Failed originals stay available.
            scratch_avi = Path(tempfile.mkdtemp(prefix='gunman-regional-movie-'))/'gameplay.avi'
            scratch_avi.touch(exist_ok=False)
            avi.symlink_to(scratch_avi)
            report['temporary_movie_storage'] = {'logical_path':str(avi),'backing_file':str(scratch_avi),'scope':'raw AVI only; final MP4/source/log/frame evidence stays in build; failure retained'}
        if not env.get('DISPLAY'):
            binary = shutil.which('Xvfb') or str(ROOT.parent/'toolchains/xvfb/usr/bin/Xvfb')
            display_log = (folder/'display.log').open('wb')
            display = subprocess.Popen([binary, '-displayfd', '1', '-screen', '0', '1280x720x24', '-nolisten', 'tcp', '-ac'], stdout=subprocess.PIPE, stderr=display_log)
            with selectors.DefaultSelector() as selector:
                selector.register(display.stdout, selectors.EVENT_READ)
                if not selector.select(20): raise RuntimeError('Xvfb readiness timeout')
                number = display.stdout.readline().decode().strip()
                if not number.isdigit(): raise RuntimeError('Invalid Xvfb display')
            env['DISPLAY'] = ':' + number
        report['environment'] = {k:env[k] for k in ('LIBGL_ALWAYS_SOFTWARE','LP_NUM_THREADS','DISPLAY')}
        command = native_command(report, output, avi)
        report['command'] = command
        write(receipt, report)
        report['capture_process'] = harness.run_check({'argv':command, 'timeout_seconds':timeout,
            'success_pattern':r'^LEVEL FORMAL CAPTURE: [1-9]\d* frames, [1-9]\d* edges, outcome=\S+, capture_errors=0$'}, folder/'capture.log', ROOT, env)
        report['source_after'] = sources(capture_script)
        if output.exists(): report['native_capture'] = artifact(output)
        if (folder/'capture.log').exists(): report['native_log'] = artifact(folder/'capture.log')
        if report['capture_process']['status'] != 'passed' or report['source_after'] != before:
            raise RuntimeError('Native producer failed/timed out or source drifted; retain evidence')
        data = read(output)
        errors = validate_native(data, report, (folder/'capture.log').read_text())
        if errors: raise RuntimeError('; '.join(errors))
        if composition:
            raw_path=folder/'composition_raw.json'
            if raw_path.is_file():
                observation_path=folder/'composition_observation.json'
                bind_composition(raw_path,output,before,observation_path)
                report['composition_observation']=artifact(observation_path)
                report['composition_observation_status']='measured'
            else:
                report['composition_observation_status']='unverified_missing_raw'
        with (folder/'encode.log').open('w') as log:
            subprocess.run(['ffmpeg','-n','-i',str(avi),'-c:v','libx264','-crf','21','-pix_fmt','yuv420p','-c:a','aac',str(movie)], stdout=log, stderr=subprocess.STDOUT, timeout=600 if capture_script == REGIONAL_CAPTURE else 180, check=True)
        media = json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(movie)],timeout=30))
        video = next(s for s in media['streams'] if s['codec_type']=='video')
        audio = next(s for s in media['streams'] if s['codec_type']=='audio')
        count = int(video['nb_frames'])
        if (video['width'],video['height'],video['avg_frame_rate'],int(audio['sample_rate']),audio['channels']) != (1280,720,'60/1',48000,2) or count < data['tick_count']:
            raise RuntimeError('Formal movie resolution/frame/audio coverage mismatch')
        numbers = sorted(set([0,count-1]+list(range(frame_stride,count,frame_stride))))
        images = folder/'video_frames'; images.mkdir()
        select = 'select=' + '+'.join('eq(n\\,'+str(n)+')' for n in numbers)
        with (folder/'extract.log').open('w') as log:
            subprocess.run(['ffmpeg','-n','-i',str(movie),'-vf',select,'-vsync','0',str(images/'extracted_%06d.png')],stdout=log,stderr=subprocess.STDOUT,timeout=600 if capture_script == REGIONAL_CAPTURE else 180,check=True)
        outputs = sorted(images.glob('extracted_*.png'))
        if len(outputs) != len(numbers): raise RuntimeError('Video frame extraction incomplete')
        frames = []
        for p, n in zip(outputs,numbers):
            target = images/f'video_frame_{n:06d}.png';p.rename(target)
            frames.append(dict(**artifact(target),video_frame_index_zero_based=n,video_time_seconds=n/60,scope='post-extracted actual MP4 frame; not physics tick'))
        report.update(status='captured', outcome=data['outcome'], route_reached=data['route_reached'],
                      tick_count=data['tick_count'], media=media, movie=artifact(movie),video_frames=frames,
                      original_avi_sha256=file_hash(avi), source_after=sources(capture_script))
        if report['source_after'] != before: raise RuntimeError('Source drift during media finalization')
        # Keep native trace and validated complete MP4. Failed temporary AVI is never removed.
        avi.unlink()
        if scratch_avi is not None:
            scratch_avi.unlink()
            scratch_avi.parent.rmdir()
    except Exception as exc:
        report['status'] = 'failed'; report['errors'].append(type(exc).__name__+': '+str(exc))
    finally:
        try:
            report['source_after'] = sources(capture_script)
        except (OSError, ValueError) as exc:
            report['source_after'] = None
            report['status'] = 'failed'
            report['errors'].append('Final source guard unavailable: ' + str(exc))
        report.update(wall_seconds=time.monotonic()-started,finished_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()))
        write(receipt,report)
        if display:
            display.terminate()
            try: display.wait(timeout=5)
            except subprocess.TimeoutExpired: display.kill();display.wait(timeout=5)
        if display_log: display_log.close()
    return report


def native_command(report, output, avi):
    command=level_formal.command_for(report['request'],output,frame_dir='',visible=True)
    script = report['request'].get('capture_script')
    if script is not None:
        if script not in CAPTURE_SCRIPTS:
            raise ValueError('Unsupported capture script')
        command[command.index('--script') + 1] = script
    if script in ENVIRONMENT_CAPTURES:
        phase = report['request'].get('environment_phase')
        mutation = report['request'].get('environment_mutation')
        if phase not in ('probe', 'full') or mutation not in ('', 'no-gun'):
            raise ValueError('Unsupported explicit environment request')
        command += ['--environment-phase=' + phase, '--environment-mutation=' + mutation]
    sample = report['request'].get('visual_sample', '')
    layout = report['request'].get('visual_layout', '')
    if layout not in ('', 'open-meadow') or (layout and script != 'tools/spatial_golden_capture.gd'):
        raise ValueError('Unsupported explicit visual layout')
    if layout:
        command.append('--visual-layout=' + layout)
    if sample:
        if not valid_visual_sample(script, sample):
            raise ValueError('Unsupported explicit visual sample catalog')
        if script == 'tools/spatial_golden_capture.gd' and layout != 'open-meadow':
            raise ValueError('Visual sample requires explicit open-meadow layout')
        command.append('--visual-sample=' + sample)
    command[2:2]=['--rendering-method','gl_compatibility','--write-movie',str(avi)]
    composition=report.get('composition_capture')
    if composition:
        expected=relative(Path(output).parent/'composition_raw.json')
        if composition!={'requested':True,'raw_path':expected}:
            raise ValueError('Unexpected composition output request')
        command.append('--visual-composition-output=res://'+expected)
    return command


def producer_command_origin(report, output, native_log):
    """Verify original commands after a workspace move, without rewriting receipts.

    Only the absolute MovieWriter destination may differ. Its repository-relative
    path and the independently bound native completion log must still agree.
    All other arguments, source, media and evidence checks remain mandatory.
    """
    output = Path(output).resolve()
    expected = native_command(report, output, output.parent / 'gameplay.avi')
    actual = report.get('command')
    completions = [line.strip().removeprefix('Done recording movie at path: ')
                   for line in native_log.splitlines()
                   if line.strip().startswith('Done recording movie at path: ')]
    index = expected.index('--write-movie') + 1
    if not isinstance(actual,list) or len(actual)!=len(expected) or completions!=[actual[index]]:
        raise ValueError('MovieWriter origin lacks unique matching native completion')
    if actual == expected:
        if report.get('producer_root', str(ROOT)) != str(ROOT):
            raise ValueError('unexpected real producer root')
        return {'kind': 'original_workspace', 'producer_root': str(ROOT), 'movie_writer_completion_bound':True}
    if not isinstance(actual, list) or len(actual) != len(expected):
        raise ValueError('unexpected real producer command')
    index = expected.index('--write-movie') + 1
    destination = actual[index]
    if not isinstance(destination, str):
        raise ValueError('unexpected real producer movie destination')
    original = Path(destination)
    relative_avi = output.parent.relative_to(ROOT) / 'gameplay.avi'
    if (not original.is_absolute() or str(original.resolve()) != destination
            or len(original.parts) <= len(relative_avi.parts)
            or original.parts[-len(relative_avi.parts):] != relative_avi.parts):
        raise ValueError('unexpected real producer archive path')
    producer_root = Path(*original.parts[:-len(relative_avi.parts)])
    reconstructed = expected.copy()
    reconstructed[index] = destination
    if (actual != reconstructed or completions != [destination]
            or report.get('producer_root', str(producer_root)) != str(producer_root)):
        raise ValueError('unexpected real producer command or unbound archived MovieWriter origin')
    return {'kind': 'relocated_workspace_same_relative_paths', 'producer_root': str(producer_root),
            'movie_writer_completion_bound': True,
            'limits': 'Original capture/command/log bytes unchanged; not authentication against forged native processes.'}


def bind_composition(raw_path,native_path,source_before,output):
    """Adapt actual runtime measurements after native completion; never manufacture measured Nodes."""
    raw_path=Path(raw_path).resolve();output=Path(output).resolve()
    if output.exists() or not output.is_relative_to(ROOT/'build'):
        raise ValueError('Use a new build/ composition observation')
    raw=read(raw_path)
    if raw.get('artifact_kind')!='actual_scene_composition_measurements':
        raise ValueError('Not runtime composition measurements')
    observer=raw.get('observer',{})
    observer_path=observer.get('path','').removeprefix('res://')
    if not observer_path or source_before.get(observer_path)!=observer.get('sha256'):
        raise ValueError('Actual composition observer absent/changed in captured source')
    if not isinstance(raw.get('samples'),list) or not raw['samples']:
        raise ValueError('Missing actual runtime composition samples')
    observation=dict(raw)
    observation.update(artifact_kind='actual_scene_composition_observation',
                       capture_sha256=file_hash(Path(native_path)),raw_measurements=artifact(raw_path),
                       observer={'path':observer_path,'sha256':observer['sha256']},
                       scope='Actual runtime Sprite and Platform bounds from read-only scene observer. Nodes are last measured sample; samples retain actual cadence. Layer/semantic labels are declarations, not artistic quality proof.')
    composition_candidates(observation,observation['capture_sha256'],source_before)
    write(output,observation)
    return observation


def validate_composition_binding(observation,native_sha,source_before):
    raw=read(bound_file(observation.get('raw_measurements')))
    if raw.get('artifact_kind')!='actual_scene_composition_measurements' or not raw.get('samples'):
        raise ValueError('Missing real runtime measurement provenance')
    for key in ('nodes','protected_world_bounds','samples'):
        if observation.get(key)!=raw.get(key): raise ValueError('Composition adapter changed actual measurements/'+key)
    original_observer=raw.get('observer',{})
    expected={'path':original_observer.get('path','').removeprefix('res://'),'sha256':original_observer.get('sha256')}
    if observation.get('observer')!=expected: raise ValueError('Composition observer identity changed')
    composition_candidates(observation,native_sha,source_before)
    return observation


def formal_source_projection(inventory):
    """Original observer hashes code/resources, not bitmap bytes; preserve that exact contract.

    Full bitmap + producer inventories remain separately bound by before/after equality.
    Never replace the full original runtime inventory with the small driver/core subset.
    """
    runtime_folders=('scripts/','scenes/','resources/','config/','shaders/','assets/')
    suffixes={'.gd','.tscn','.tres','.json','.gdshader'}
    return {k:v for k,v in inventory.items() if not k.startswith(runtime_folders) or Path(k).suffix in suffixes}


def _validate_place_art_consumers(data, plan):
    """A completed film/route must not admit missing actual art consumers."""
    errors = []
    for key in ('environment_initial_physics', 'environment_final_physics'):
        snapshot = data.get(key, {})
        art = snapshot.get('art') if isinstance(snapshot, dict) else None
        if not isinstance(art, dict) or art.get('omitted') != []:
            errors.append('places actual art missing/omitted/' + key)
            continue
        if not plan.get('joint_synthesis'):
            continue
        bodies = plan.get('terrain_instances', [])
        receipt = art.get('joint_consumer', {})
        bindings = receipt.get('bindings') if isinstance(receipt, dict) else None
        if not isinstance(receipt, dict) or receipt.get('version') != plan['joint_synthesis'].get('version'):
            errors.append('places actual joint consumer version missing/' + key)
        if not isinstance(bindings, list) or not bodies or len(bindings) != len(bodies) or not all(isinstance(row, dict) for row in bindings):
            errors.append('places actual joint bindings missing/' + key)
            continue
        expected = {body['id']: body for body in bodies}
        if len({row.get('body_id') for row in bindings}) != len(bodies):
            errors.append('places actual joint bindings duplicated/' + key)
        for row in bindings:
            body = expected.get(row.get('body_id'))
            error = row.get('max_display_to_collision_error_world')
            count = row.get('installed_profile_points')
            if (not body or row.get('solid_id') != body['solid_id'] or row.get('agrees') is not True
                    or type(error) not in (int, float) or not math.isfinite(error) or error < 0
                    or error > max(0.0001, float(body.get('uniform_scale', 0)))
                    or type(count) is not int or count != len(body.get('source_profile_px', []))):
                errors.append('places actual joint source/collision mismatch/' + key)
        terrain = art.get('terrain', [])
        objects = art.get('objects', [])
        layers = art.get('layers', [])
        if not isinstance(terrain, list) or not isinstance(objects, list) or not isinstance(layers, list) or not all(isinstance(row, dict) for row in terrain + objects + layers):
            errors.append('places actual joint scenery inventory missing/' + key)
            continue
        if {row.get('solid_id') for row in terrain} != {body['solid_id'] for body in bodies}:
            errors.append('places actual joint terrain missing/' + key)
        if {row.get('id') for row in layers} != {row['id'] for row in plan.get('layer_instances', [])}:
            errors.append('places actual joint layer missing/' + key)
        bridges = {row['id'] for row in plan.get('surfaces', []) if row.get('semantic') == 'bridge' or row.get('kind') == 'bridge'}
        if {row.get('surface_id') for row in objects if row.get('role') == 'bridge'} != bridges:
            errors.append('places actual joint bridge missing/' + key)
        attachments = {row['id'] for row in plan.get('attachments', []) if row.get('role') != 'bridge_abutment'}
        if {row.get('attachment_id') for row in objects if row.get('attachment_id')} != attachments:
            errors.append('places actual joint attachment missing/' + key)
    return errors


def validate_places_observations(data, plan):
    """Bind the finite three-prototype experiment to real inherited route cases."""
    if not isinstance(plan, dict): return ['places shared plan missing']
    errors = _validate_place_art_consumers(data, plan)
    instances = plan.get('place_instances')
    if not isinstance(instances, list) or len(instances) != 3 or not all(isinstance(row, dict) for row in instances):
        return ['places three realized instances missing']
    identities = [row.get('id') for row in instances]
    prototypes = [row.get('prototype_id') for row in instances]
    if not all(isinstance(value, str) and value for value in identities) or len(set(identities)) != 3:
        return ['places instance identities missing/duplicated']
    if not all(isinstance(value, str) for value in prototypes) or set(prototypes) != {'wind_meadow', 'postal_valley', 'lee_court'}:
        errors.append('places three distinct prototypes missing')
    if plan.get('place_order') != identities or plan.get('prototype_order') != prototypes:
        errors.append('places actual order mismatch')
    for row in instances:
        offset = row.get('translation')
        if not isinstance(offset, list) or len(offset) != 2 or any(type(value) not in (int, float) or not math.isfinite(value) for value in offset):
            errors.append('places realized translation invalid')
        if not re.fullmatch(r'[0-9a-f]{64}', str(row.get('source_measurement_sha256', ''))):
            errors.append('places measurement source identity missing')
    contract = data.get('places_route_contract')
    if not isinstance(contract, dict) or any(contract.get(key) != plan.get(key) for key in ('place_instances', 'place_order', 'prototype_order')):
        errors.append('places actual route contract mismatch')
    observed = data.get('places_waypoint_observations')
    if not isinstance(observed, list) or not all(isinstance(row, dict) for row in observed):
        return errors + ['places actual waypoint observations missing']
    cases = {case.get('id'): case for case in data.get('environment_cases', []) if isinstance(case, dict)}
    by_id = {row['id']: row for row in instances}
    visited = set()
    forward_order = []
    for row in observed:
        if not isinstance(row.get('place_instance_id'), str) or not isinstance(row.get('waypoint_id'), str) or type(row.get('passed')) is not bool or type(row.get('supported')) is not bool:
            errors.append('places observation identity/state malformed')
            continue
        place = by_id.get(row.get('place_instance_id'))
        case = cases.get(row.get('waypoint_id'))
        if not place or not case or row.get('prototype_id') != place['prototype_id'] or not str(row.get('waypoint_id', '')).startswith(place['id'] + '/'):
            errors.append('places observation identity differs from real case')
            continue
        if any(row.get(key) != case.get(key) for key in ('passed', 'start_tick', 'end_tick', 'position', 'supported')):
            errors.append('places observation changed actual Motor case')
        if row.get('passed') is True and row.get('supported') is True:
            visited.add(place['id'])
            if row['waypoint_id'] in plan.get('route_forward', []) and place['id'] not in forward_order:
                forward_order.append(place['id'])
    if data.get('route_reached') and visited != set(identities):
        errors.append('places route success lacks actual three-prototype visits')
    if data.get('route_reached') and forward_order != identities:
        errors.append('places actual forward visits differ from realized order')
    return errors


def validate_native(data, report, log):
    errors=[]
    if data.get('artifact_kind') != 'formal_level_capture' or data.get('schema_version') != 1 or data.get('capture_contract_version') != 3: errors.append('not actual current formal capture')
    if not data.get('frames') or data.get('capture_errors') != []: errors.append('empty/incomplete real trace')
    if data.get('screenshots') not in ([],None): errors.append('unexpected live screenshot readback')
    if report.get('source_before') != report.get('source_after') or not report.get('source_before'): errors.append('source drift/incomplete inventory')
    request=report.get('request',{})
    for k in ('source_commit','root_seed','map_index','strategy','phase_wait_ticks','encounter_policy'):
        if data.get(k) != request.get(k): errors.append('request mismatch/'+k)
    extension = report.get('capture_extension')
    script = request.get('capture_script')
    if script is not None:
        if script not in CAPTURE_SCRIPTS or not isinstance(extension, dict) or extension.get('script') != script:
            errors.append('invalid capture extension identity')
        else:
            bound = extension.get('sources', {})
            observed = data.get('capture_extension_sources')
            if not bound or script not in bound or observed != {'res://' + p: h for p, h in bound.items()}:
                errors.append('missing/changed native capture extension closure')
            if any(report.get('source_before', {}).get(p) != h for p, h in bound.items()):
                errors.append('capture extension absent from source guard')
    elif extension is not None or data.get('capture_extension_sources'):
        errors.append('unexpected capture extension')
    if 'visual_sample' in report['request'] and script not in (REGIONAL_CAPTURE, JOINT_RECOIL_CAPTURE):
        selected = report['request']['visual_sample']
        treatment = data.get('visual_sample_treatment', {})
        valid = isinstance(selected, str) and selected in ('', *VISUAL_SAMPLE_CATALOGS)
        if not isinstance(treatment, dict): treatment = {}
        if not valid or treatment.get('catalog_path') != selected:
            errors.append('explicit visual sample treatment mismatch')
        expected = report.get('source_before', {}).get(selected.removeprefix('res://')) if valid and selected else ''
        if treatment.get('catalog_sha256') != expected or (selected and not expected):
            errors.append('explicit visual sample catalog source mismatch')
    if 'visual_layout' in report['request'] and script not in (REGIONAL_CAPTURE, JOINT_RECOIL_CAPTURE):
        layout = report['request']['visual_layout']
        if layout not in ('', 'open-meadow') or data.get('visual_layout_treatment') != (layout or 'original'):
            errors.append('explicit visual layout treatment mismatch')
    if script == 'tools/p1_random_capture.gd':
        selected = bool(request.get('visual_sample', ''))
        expected_avatar = 'p1_girl' if selected else 'courier'
        if selected and not valid_visual_sample(script, request['visual_sample']):
            errors.append('formal random catalog outside exact allowlist')
        if data.get('p1_random_requested') is not selected or data.get('requested_avatar') != expected_avatar:
            errors.append('formal random treatment/identity mismatch')
        if data.get('p1_install_collision_unchanged') is not True:
            errors.append('formal random install collision changed or unobserved')
        for key in ('avatar_initial', 'avatar_final'):
            avatar = data.get(key, {})
            if avatar.get('selected_id') != expected_avatar or avatar.get('painted_owner_count') != int(selected) or not avatar.get('hero_states'):
                errors.append('formal random actual avatar mismatch/' + key)
        if selected and (not data.get('p1_random_initial', {}).get('selected') or not data.get('p1_random_final', {}).get('selected')):
            errors.append('formal random actual terrain consumer missing')
    if script in ENVIRONMENT_CAPTURES:
        contract = data.get('environment_route_contract', {})
        if not isinstance(contract, dict):
            errors.append('environment actual route contract malformed')
            contract = {}
        plan = data.get('manifest', {}).get('environment_plan')
        if request.get('map_index') != 1 or request.get('strategy') != 'fast' or request.get('encounter_policy') != 'blind_legacy':
            errors.append('environment candidate entry/policy mismatch')
        if request.get('visual_sample') or request.get('visual_layout'):
            errors.append('environment candidate cannot borrow another visual treatment')
        if request.get('environment_phase') not in ('probe', 'full') or request.get('environment_mutation') not in ('', 'no-gun'):
            errors.append('environment candidate request mismatch')
        if not isinstance(contract, dict) or contract.get('phase') != request.get('environment_phase') or contract.get('mutation') != request.get('environment_mutation'):
            errors.append('environment actual route policy mismatch')
        if not isinstance(plan, dict) or not plan.get('route_waypoints') or not plan.get('safe_stands') or contract.get('plan') != plan:
            errors.append('environment actual shared plan missing/changed')
        candidate_scope = 'plains_places_candidate' if script == PLACES_CAPTURE else 'plains_environment_candidate'
        if data.get('captured_scope', {}).get(candidate_scope) is not True or data.get('captured_scope', {}).get('pure_art_comparison_eligible') is not False:
            errors.append('environment candidate scope missing')
        if not data.get('environment_initial_physics') or not data.get('environment_final_physics') or not data.get('environment_cases'):
            errors.append('environment actual observations missing')
        for key in ('environment_initial_physics', 'environment_final_physics'):
            observation = data.get(key, {})
            if not isinstance(observation, dict) or observation.get('environment_plan') != plan or observation.get('manifest_hash') != data.get('manifest_hash') or observation.get('production_pool') is not False:
                errors.append('environment physics/plan binding mismatch/' + key)
        if data.get('route_reached'):
            cases = data.get('environment_cases', [])
            forward = plan.get('route_forward') if isinstance(plan, dict) else None
            returning = plan.get('route_return') if isinstance(plan, dict) else None
            expected = forward + returning if isinstance(forward, list) and isinstance(returning, list) else []
            well_formed = isinstance(cases, list) and all(isinstance(case, dict) for case in cases)
            if request.get('environment_phase') != 'full' or not expected or not well_formed or [case.get('id') for case in cases] != expected or not all(case.get('passed') is True for case in cases):
                errors.append('environment route success without completed real cases')
        if re.search(r'^\s*ERROR:', log, re.M):
            errors.append('environment native engine error')
        for key in ('environment_avatar_initial', 'environment_avatar_final'):
            avatar = data.get(key, {})
            if not isinstance(avatar, dict): avatar = {}
            if avatar.get('selected_id') != 'p1_girl' or avatar.get('painted_owner_count') != 1 or not avatar.get('hero_states') or avatar.get('gameplay_changed') is not False:
                errors.append('environment actual avatar missing/duplicated/' + key)
            for path_key, sha_key in (('source_calibration', 'source_sha256'), ('texture_source', 'texture_sha256')):
                path = avatar.get(path_key, '')
                expected = report.get('source_before', {}).get(path.removeprefix('res://')) if isinstance(path, str) else None
                if not expected or avatar.get(sha_key) != expected:
                    errors.append('environment actual avatar source mismatch/' + key + '/' + path_key)
        if script == PLACES_CAPTURE:
            errors.extend(validate_places_observations(data, plan))
    if script == REGIONAL_CAPTURE:
        errors.extend(validate_regional_observations(data))
        errors.extend(validate_regional_bindings(data,report))
    if script == JOINT_RECOIL_CAPTURE:
        errors.extend(validate_joint_recoil_observations(data, report))
    scope=data.get('captured_scope',{})
    for k in ('enemies_instantiated','enemy_attacks_enabled','enemy_contacts_enabled','production_rewards_enabled','production_camera_enabled'):
        if scope.get(k) is not True: errors.append('missing formal runtime/'+k)
    for k in ('controller_manual_step','actor_teleport_by_driver','resource_injection','enemy_disable'):
        if scope.get(k) is not False: errors.append('altered runtime/'+k)
    if not data.get('initial_capability') or not data.get('initial_scenery_inventory'): errors.append('missing capability/scenery observation')
    if data.get('manifest_hash') != data.get('manifest',{}).get('manifest_hash'): errors.append('manifest identity mismatch')
    errors.extend(level_formal.validate_policy_basis(data,formal_source_projection(report.get('source_before',{}))))
    marks=re.findall(r'^LEVEL FORMAL CAPTURE: (\d+) frames, (\d+) edges, outcome=(\S+), capture_errors=(\d+)$',log,re.M)
    if marks != [(str(len(data.get('frames',[]))),str(len(data.get('edges',[]))),str(data.get('outcome')),'0')]: errors.append('missing/mismatched native completion')
    if re.search(r'SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script|ObjectDB.*leaked|resources? still in use at exit',log): errors.append('engine script error')
    if not level_formal.engine_log_matches(data.get('engine'),log): errors.append('engine identity mismatch')
    if data.get('route_reached') is not (data.get('outcome')=='route_target_reached'): errors.append('route outcome mismatch')
    return errors



def validate_joint_recoil_observations(data, report):
    """One input-driven challenge in a full region; never whole-region admission."""
    errors = []
    request = report.get('request', {})
    if request.get('visual_sample', '') or request.get('visual_layout', '') or data.get('joint_baseline') is not False:
        errors.append('joint capture requires the actual opt-in candidate')
    expected_cases = ['original_tutorial', 'actual_adjacent_entry', 'target_edge_forward',
                      'actual_lower_neighbor_descent', 'actual_underbank_ferry_reverse',
                      'actual_underbank_ferry_forward', 'actual_lower_neighbor_return', 'target_edge_return']
    coverage = data.get('joint_coverage', {})
    cases = coverage.get('cases', [])
    if data.get('route_reached') and (coverage.get('complete') is not True or not isinstance(cases, list)
            or [c.get('id') for c in cases if isinstance(c, dict)] != expected_cases
            or not all(c.get('passed') is True and c.get('grounded') is True and c.get('recovery_count') == 0 for c in cases)):
        errors.append('joint route lacks actual grounded forward/return cases')
    for phase in ('initial', 'final'):
        snap = data.get('joint_' + phase, {})
        art = snap.get('art', {})
        modules = snap.get('art_plan', {}).get('joint_modules', [])
        collisions = snap.get('joint_collisions', [])
        banks = art.get('joint_terrain', [])
        if modules and all(m.get('render_method') == 'landform_world_material_v1' for m in modules):
            errors.extend(validate_landform_consumers(snap, report, phase))
            if data.get('joint_decoration_collisions_' + phase) != []:
                errors.append('joint decoration gained physical collision/' + phase)
            avatar = data.get('joint_avatar_' + phase, {})
            if avatar.get('selected_id') != 'p1_girl' or avatar.get('painted_owner_count') != 1 or avatar.get('gameplay_changed') is not False:
                errors.append('joint actual avatar missing/duplicated/' + phase)
            continue
        if (snap.get('joint_ready') is not True or snap.get('production_pool') is not False
                or len(modules) != 1 or len(collisions) != 2 or len(banks) != 2 or art.get('omitted') != []):
            errors.append('joint actual complete banks/collision consumer missing/' + phase)
        catalog = 'resources/visual_development/p1_joint_recoil_assets.json'
        if not report.get('source_before', {}).get(catalog) or art.get('joint_catalog_sha256') != report.get('source_before', {}).get(catalog):
            errors.append('joint actual catalog not source-bound/' + phase)
        planned = modules[0].get('terrain_bodies', []) if len(modules) == 1 else []
        if {b.get('source_role') for b in banks} != {'bank_left', 'bank_right'}:
            errors.append('joint bank roles missing/duplicated/' + phase)
        # Godot Vector2 stores float32: reproduce the actual local->world
        # conversion, rather than compare its JSON to plan float64 arithmetic.
        def f32(value):
            return struct.unpack('f', struct.pack('f', value))[0]
        offset = modules[0].get('offset', [0, 0]) if len(modules) == 1 else [0, 0]
        expected_points = [[[f32(f32(v) + f32(o)) for v, o in zip(point, offset)]
                            for point in bank.get('local_points', [])] for bank in planned]
        actual_points = [[[f32(v) for v in point] for point in c.get('world_points', [])] for c in collisions]
        if sorted(actual_points, key=str) != sorted(expected_points, key=str):
            errors.append('joint actual collision differs from shared plan/' + phase)
        if any(c.get('disabled') is not False or c.get('one_way') is not False or c.get('collision_layer') != 1 or c.get('build_mode') != 0 for c in collisions):
            errors.append('joint solid bank collision disabled or altered/' + phase)
        for collider in collisions:
            originals = collider.get('replaced_slabs', [])
            if (len(originals) != 3 or len({o.get('path') for o in originals}) != 3
                    or any(o.get('disabled') is not True or o.get('one_way') is not False or not o.get('size') for o in originals)):
                errors.append('joint original slabs not explicitly transferred to polygon ownership/' + phase)
        for bank in banks:
            source = bank.get('source', '').removeprefix('res://')
            if (not source or bank.get('source_sha256') != report.get('source_before', {}).get(source)
                    or not bank.get('actual_mesh_vertices') or not bank.get('actual_mesh_indices')
                    or bank.get('collision_written') is not False):
                errors.append('joint actual whole-bank mesh/source missing/' + phase)
        if data.get('joint_decoration_collisions_' + phase) != []:
            errors.append('joint decoration gained physical collision/' + phase)
        avatar = data.get('joint_avatar_' + phase, {})
        if avatar.get('selected_id') != 'p1_girl' or avatar.get('painted_owner_count') != 1 or avatar.get('gameplay_changed') is not False:
            errors.append('joint actual avatar missing/duplicated/' + phase)
    return errors



def validate_landform_consumers(snap, report, phase):
    """V5 actual material/solid/rear consumers; art and whole-map admission separate."""
    errors = []
    art = snap.get('art', {})
    modules = snap.get('art_plan', {}).get('joint_modules', [])
    if len(modules) != 1:
        return ['landform capture requires one actual source-owned experimental program/' + phase]
    program = modules[0]
    bodies = program.get('terrain_bodies', [])
    physical = snap.get('joint_collisions', [])
    painted = art.get('joint_terrain', [])
    catalog = 'resources/visual_development/p1_landform_assets.json'
    bound = report.get('source_before', {})
    if (snap.get('joint_ready') is not True or snap.get('production_pool') is not False
            or not bodies or len(physical) != len(bodies) or len(painted) != len(bodies) or art.get('omitted') != []):
        errors.append('landform actual complete source consumer missing/' + phase)
    if not bound.get(catalog) or art.get('joint_catalog_sha256') != bound.get(catalog):
        errors.append('landform actual catalog not source-bound/' + phase)
    def f32(value):
        return struct.unpack('f', struct.pack('f', value))[0]
    def points(values):
        return [[f32(x), f32(y)] for x, y in values]
    def source_ok(item):
        path = item.get('source', '').removeprefix('res://')
        return bool(path and bound.get(path) and item.get('source_sha256') == bound[path])
    def identity_map(rows, nested=False):
        result = {}
        for row in rows:
            role = row.get('source', {}).get('source_role') if nested else row.get('source_role')
            if not role or role in result:
                errors.append('landform duplicated/missing volume identity/' + phase)
            result[role] = row
        return result
    expected = identity_map(bodies)
    actual_physics = identity_map(physical, True)
    actual_paint = identity_map(painted)
    if set(expected) != set(actual_physics) or set(expected) != set(actual_paint):
        errors.append('landform volume ownership incomplete/' + phase)
    owned = program.get('region_context', {}).get('owned_slabs', [])
    for role, body in expected.items():
        collision, mesh = actual_physics.get(role, {}), actual_paint.get(role, {})
        expected_world = points(body.get('points', []))
        if points(collision.get('world_points', [])) != expected_world:
            errors.append('landform actual collision differs from shared source/' + phase)
        if (collision.get('disabled') is not False or collision.get('one_way') is not False
                or collision.get('collision_layer') != 1 or collision.get('build_mode') != 0):
            errors.append('landform source solid disabled or altered/' + phase)
        originals = collision.get('replaced_slabs', [])
        if (not owned or len(originals) != len(owned) or len({o.get('path') for o in originals}) != len(owned)
                or any(o.get('disabled') is not True or o.get('one_way') is not False for o in originals)
                or any(not any(o.get('path', '').endswith('/' + str(spec['node_id']).replace('/', '_') + '/Platform' + str(spec['platform_index']) + '/CollisionShape2D') for o in originals) for spec in owned)):
            errors.append('landform original collision ownership transfer incomplete/' + phase)
        paints = mesh.get('paint_sources', [])
        if ({p.get('role') for p in paints} != {'rock_core', 'meadow_transition', 'cave_transition'}
                or len(paints) != 3 or not all(source_ok(p) for p in paints)
                or mesh.get('mapping') != 'landform_world_material_v1' or mesh.get('collision_written') is not False):
            errors.append('landform actual painting sources/mapping missing/' + phase)
        if (points(mesh.get('actual_world_polygon', [])) != expected_world
                or points(mesh.get('actual_mesh_vertices', [])) != expected_world
                or mesh.get('material_space') != body.get('material_space')
                or mesh.get('source_exposed_faces') != body.get('exposed_faces')
                or not mesh.get('actual_mesh_indices')):
            errors.append('landform installed mesh/material differs from shared source/' + phase)
        if body.get('geometry_source') != 'environment_program' or not body.get('support_id'):
            errors.append('landform missing actual environmental source/support/' + phase)
    expected_rear = {w.get('id'): w for w in program.get('rear_walls', [])}
    actual_rear = {w.get('id'): w for w in art.get('joint_rear_walls', [])}
    if (not expected_rear or set(expected_rear) != set(actual_rear)
            or len(actual_rear) != len(art.get('joint_rear_walls', []))):
        errors.append('landform actual cave rear substrate incomplete/' + phase)
    for key, rear in expected_rear.items():
        installed = actual_rear.get(key, {})
        if (not source_ok(installed) or installed.get('collision_written') is not False
                or points(installed.get('actual_world_polygon', [])) != points(rear.get('points', []))
                or installed.get('material_space') != rear.get('material_space')):
            errors.append('landform actual rear wall/source mismatch/' + phase)
    if art.get('joint_rear_openings') != program.get('rear_openings'):
        errors.append('landform actual rear opening declaration differs/' + phase)
    relations = program.get('support_relations', [])
    if (len(relations) != len(bodies) or any(r.get('valid') is not True or not r.get('overlap_polygons') or r.get('overlap_area', 0) <= 100 for r in relations)):
        errors.append('landform source lacks rooted rear overlap/' + phase)
    return errors


def validate_regional_bindings(data, report):
    """Regional entry has its own actual catalog; legacy sample flags are unsupported."""
    errors = []
    request = report.get('request', {})
    if request.get('visual_sample', '') or request.get('visual_layout', ''):
        errors.append('regional entry does not support legacy visual sample/layout flags')
    sources_before = report.get('source_before', {})
    catalog = 'resources/visual_development/p1_regional_assets.json'
    for key in ('regional_art_initial', 'regional_art_final'):
        art = data.get(key, {}).get('art', {})
        if (art.get('catalog_path') != 'res://' + catalog or not sources_before.get(catalog)
                or art.get('catalog_sha256') != sources_before.get(catalog)):
            errors.append('regional actual catalog source binding missing/' + key)
        def check_sources(value):
            if isinstance(value, dict):
                if 'source' in value:
                    path = value['source']
                    expected = sources_before.get(path.removeprefix('res://')) if isinstance(path, str) else None
                    if not expected or value.get('source_sha256') != expected:
                        errors.append('regional actual painted source binding missing/' + key)
                for child in value.values(): check_sources(child)
            elif isinstance(value, list):
                for child in value: check_sources(child)
        check_sources(art)
    for key in ('regional_avatar_initial', 'regional_avatar_final'):
        avatar = data.get(key, {})
        if avatar.get('selected_id') != 'p1_girl' or avatar.get('painted_owner_count') != 1 or not avatar.get('hero_states') or avatar.get('gameplay_changed') is not False:
            errors.append('regional actual avatar missing/duplicated/' + key)
        for path_key, sha_key in (('source_calibration', 'source_sha256'), ('texture_source', 'texture_sha256')):
            path = avatar.get(path_key, '')
            expected = sources_before.get(path.removeprefix('res://')) if isinstance(path, str) else None
            if not expected or avatar.get(sha_key) != expected:
                errors.append('regional actual avatar source mismatch/' + key + '/' + path_key)
    return errors


def validate_regional_observations(data):
    """Whole-region coverage is separate from movie capture and local art."""
    errors = []
    manifest = data.get('manifest', {})
    expected = {area['id'] for area in manifest.get('areas', []) if area.get('role') not in ('boss', 'tutorial')}
    coverage = data.get('regional_coverage', {})
    if not expected or set(coverage.get('expected_area_ids', [])) != expected:
        errors.append('regional actual full-area denominator missing/changed')
    visits = coverage.get('actual_grounded_visits', {})
    positions = {area['id']: area['position'] for area in manifest.get('areas', [])}
    for area_id, row in visits.items():
        point, target = row.get('position'), positions.get(area_id)
        if (not isinstance(point, list) or len(point) != 2 or target is None
                or any(type(v) not in (int, float) or not math.isfinite(v) for v in point)
                or math.dist(point, target) > 3.00001 or row.get('grounded') is not True):
            errors.append('regional unsupported/forged area visit')
    if data.get('route_reached') and (coverage.get('missing_area_ids') != [] or not expected <= set(visits)):
        errors.append('regional route success without complete actual area visits')
    if data.get('route_reached') and (not data.get('regional_cases') or not all(case.get('passed') is True for case in data['regional_cases'])):
        errors.append('regional incomplete actual itinerary cases')
    for key in ('regional_art_initial', 'regional_art_final'):
        observed = data.get(key, {})
        plan, art = observed.get('art_plan', {}), observed.get('art', {})
        if plan.get('version') == 'plains-regional-art-v2':
            errors.extend(validate_regional_foundations(observed))
        if (observed.get('ready') is not True or observed.get('production_pool') is not False
                or observed.get('manifest_hash') != data.get('manifest_hash')
                or plan.get('layout_source') != 'formal_full_region' or manifest.get('sample') is not False
                or not art.get('terrain') or art.get('omitted') != []
                or art.get('plan_hash') != plan.get('plan_hash')
                or not observed.get('actual_boss') or observed.get('actual_chests', 0) < 1):
            errors.append('regional actual full-map art/content consumer missing/' + key)
    return errors


def validate_regional_foundations(observed):
    """V2 actual installed pavilion support; V1 media keeps its original limited scope."""
    errors = []
    plan, art = observed.get('art_plan', {}), observed.get('art', {})
    if art.get('installed_foundations_valid') is not True:
        errors.append('regional v2 actual foundation guard missing/failed')
    expected = {row.get('id'): row for row in plan.get('landmarks', [])}
    objects = art.get('objects', [])
    if not expected or len(objects) != len(expected) or {row.get('id') for row in objects} != set(expected):
        errors.append('regional v2 actual rooted consumer denominator missing')
    for obj in objects:
        if obj.get('role') != expected.get(obj.get('id'), {}).get('asset_role'):
            errors.append('regional v2 actual attachment family mismatch')
        if obj.get('role') != 'shelter':
            continue
        foundation = obj.get('foundation', {})
        feet = foundation.get('feet', [])
        if (obj.get('visible_in_tree') is not True or foundation.get('ok') is not True
                or foundation.get('required') is not True or foundation.get('tolerance_world') != 3.0
                or len(feet) != 4 or foundation.get('surface_id') != expected.get(obj.get('id'), {}).get('surface_id')):
            errors.append('regional v2 actual four-foot pavilion support incomplete')
        for foot in feet:
            point = foot.get('world')
            if (foot.get('supported') is not True or not foot.get('installed_collision_node')
                    or not isinstance(point, list) or len(point) != 2
                    or any(type(v) not in (int, float) or not math.isfinite(v) for v in point)):
                errors.append('regional v2 actual installed foundation foot missing')
            for key in ('declared_surface_error_world', 'installed_collision_error_world'):
                value = foot.get(key)
                if type(value) not in (int, float) or not math.isfinite(value) or not 0.0 <= value <= 3.0:
                    errors.append('regional v2 unsupported installed pavilion foot')
    return errors


def finalize_existing(original_receipt,folder,frame_stride=120):
    """Repair only failed postprocessing in a NEW receipt, without invoking Godot or changing history."""
    original_receipt=Path(original_receipt).resolve();folder=Path(folder).resolve()
    if folder.exists() or not folder.is_relative_to(ROOT/'build') or not 1<=frame_stride<=3600:
        raise ValueError('Use a new bounded build/ finalization directory')
    original=read(original_receipt)
    if original.get('status')!='failed' or original.get('artifact_kind')!='actual_formal_visual_capture':
        raise ValueError('Original must be a preserved FAILED visual adapter receipt')
    process=original.get('capture_process',{})
    if process.get('status')!='passed' or type(process.get('exit_code')) is not int or process['exit_code']!=0:
        raise ValueError('Cannot rescue a failed/timed-out native process')
    native=bound_file(original['native_capture']);log=bound_file(original['native_log'])
    data=read(native)
    errors=validate_native(data,original,log.read_text())
    if errors: raise ValueError('Original native data is not admissible: '+'; '.join(errors))
    avi=native.parent/'gameplay.avi'
    if not avi.is_file(): raise ValueError('Original complete movie AVI missing')
    origin=producer_command_origin(original,native,log.read_text())
    folder.mkdir(parents=True)
    adapter_source=folder/'adapter_source.py'
    adapter_source.write_bytes(Path(__file__).read_bytes())
    report=copy_json(original)
    report.update(status='running',errors=[],adaptation={'kind':'postprocessing_only_no_engine_rerun',
        'contract_version':2,'original_receipt':artifact(original_receipt),'original_status':'failed','original_errors':original.get('errors'),
        'adapter':artifact(adapter_source),'producer_origin':origin,'scope':'Original failed receipt stays FAILED. Revalidate native data with original formal source projection; encode retained real AVI and extract actual video frames. No game input/state/source changes or engine rerun.'})
    report.pop('error',None)
    destination=folder/'visual_capture.json';write(destination,report);started=time.monotonic()
    movie=folder/'gameplay.mp4'
    try:
        composition=original.get('composition_capture')
        if composition:
            # native_command above checks that this is exactly the original
            # repository-relative producer output, never a design-plan JSON.
            raw=ROOT/composition['raw_path']
            if not raw.is_file(): raise ValueError('Original measured composition raw missing')
            raw_receipt=artifact(raw)
            observation=folder/'composition_observation.json'
            bind_composition(raw,native,original['source_before'],observation)
            report['composition_observation']=artifact(observation)
            report['composition_observation_status']='measured'
            report['adaptation']['original_composition_raw']=raw_receipt
        avi_hash=file_hash(avi)
        with (folder/'encode.log').open('w') as out:
            subprocess.run(['ffmpeg','-n','-i',str(avi),'-c:v','libx264','-crf','21','-pix_fmt','yuv420p','-c:a','aac',str(movie)],stdout=out,stderr=subprocess.STDOUT,timeout=600 if original['request'].get('capture_script') == REGIONAL_CAPTURE else 180,check=True)
        media=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(movie)],timeout=30))
        video=next(s for s in media['streams'] if s['codec_type']=='video');audio=next(s for s in media['streams'] if s['codec_type']=='audio');count=int(video['nb_frames'])
        if (video['width'],video['height'],video['avg_frame_rate'],int(audio['sample_rate']),audio['channels'])!=(1280,720,'60/1',48000,2) or count<data['tick_count']:
            raise RuntimeError('Formal movie coverage mismatch')
        numbers=sorted(set([0,count-1]+list(range(frame_stride,count,frame_stride))))
        images=folder/'video_frames';images.mkdir()
        select='select='+'+'.join('eq(n\\,'+str(n)+')' for n in numbers)
        with (folder/'extract.log').open('w') as out:
            subprocess.run(['ffmpeg','-n','-i',str(movie),'-vf',select,'-vsync','0',str(images/'extracted_%06d.png')],stdout=out,stderr=subprocess.STDOUT,timeout=600 if original['request'].get('capture_script') == REGIONAL_CAPTURE else 180,check=True)
        outputs=sorted(images.glob('extracted_*.png'))
        if len(outputs)!=len(numbers):raise RuntimeError('Video extraction incomplete')
        frames=[]
        for p,n in zip(outputs,numbers):
            target=images/f'video_frame_{n:06d}.png';p.rename(target)
            frames.append(dict(**artifact(target),video_frame_index_zero_based=n,video_time_seconds=n/60,scope='post-extracted actual MP4 frame; not physics tick'))
        report.update(status='captured',outcome=data['outcome'],route_reached=data['route_reached'],tick_count=data['tick_count'],
                      movie=artifact(movie),media=media,video_frames=frames,original_avi_sha256=avi_hash)
        if composition and artifact(raw)!=raw_receipt:
            raise RuntimeError('Original measured composition changed during finalization')
        if file_hash(original_receipt)!=report['adaptation']['original_receipt']['sha256'] or file_hash(avi)!=avi_hash:
            raise RuntimeError('Original evidence changed during finalization')
    except Exception as exc:
        report['status']='failed';report['errors'].append(type(exc).__name__+': '+str(exc))
    finally:
        report['adaptation'].update(wall_seconds=time.monotonic()-started,finished_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()))
        write(destination,report)
    return report


def copy_json(value):
    return json.loads(json.dumps(value))


def bound_file(item):
    if not isinstance(item,dict) or set(('path','sha256'))-item.keys():
        raise ValueError('Missing path/hash binding')
    path=(ROOT/item['path']).resolve()
    if not path.is_relative_to(ROOT) or not path.is_file() or file_hash(path)!=item['sha256']:
        raise ValueError('Missing/changed evidence: '+str(item.get('path')))
    return path


def load_capture(receipt_path):
    """Recheck retained bytes and native producer; does not authenticate a human reviewer."""
    receipt_path=Path(receipt_path).resolve()
    report=read(receipt_path)
    # Admission metadata is computed, never inherited from caller JSON.
    report.pop('adaptation_validation',None)
    if report.get('schema_version')!=1 or report.get('artifact_kind')!='actual_formal_visual_capture' or report.get('status')!='captured' or report.get('errors')!=[]:
        raise ValueError('Not a terminal actual rendered capture')
    if report.get('capture_process',{}).get('status')!='passed' or type(report.get('capture_process',{}).get('exit_code')) is not int or report['capture_process']['exit_code']!=0:
        raise ValueError('Native process failed')
    adaptation=report.get('adaptation')
    if adaptation:
        original=read(bound_file(adaptation['original_receipt']))
        if adaptation.get('kind')!='postprocessing_only_no_engine_rerun' or original.get('status')!='failed' or adaptation.get('original_status')!='failed':
            raise ValueError('Adaptation must preserve the original FAILED receipt')
        for key in ('request','source_before','source_after','native_capture','native_log','capture_process','command'):
            if original.get(key)!=report.get(key): raise ValueError('Adaptation changed original native facts/'+key)
        version=adaptation.get('contract_version',1)
        if version not in (1,2): raise ValueError('Unknown adaptation contract version')
        if version==2:
            adapter=bound_file(adaptation.get('adapter'))
            if adapter != receipt_path.parent/'adapter_source.py':
                raise ValueError('Adaptation adapter must be archived beside its new receipt')
            if adaptation.get('original_errors')!=original.get('errors'):
                raise ValueError('Adaptation changed original errors')
            origin=producer_command_origin(original,bound_file(original['native_capture']),bound_file(original['native_log']).read_text())
            if adaptation.get('producer_origin')!=origin:
                raise ValueError('Adaptation producer origin differs from actual native log')
            composition=original.get('composition_capture')
            if composition:
                raw=bound_file(adaptation.get('original_composition_raw'))
                if raw!=ROOT/composition['raw_path'] or not report.get('composition_observation') or report.get('composition_observation_status')!='measured':
                    raise ValueError('Adaptation lacks original measured composition binding')
                observation=read(bound_file(report['composition_observation']))
                if observation.get('raw_measurements')!=artifact(raw):
                    raise ValueError('Adaptation composition differs from original raw')
            elif adaptation.get('original_composition_raw') is not None:
                raise ValueError('Unexpected original composition raw')
            report['adaptation_validation']={'contract_version':2,'adapter_identity':'archived_bytes_verified','limits':'Byte binding, not authentication of the executing process.'}
        else:
            report['adaptation_validation']={'contract_version':1,'adapter_identity':'unverified','limits':'Legacy receipt references a mutable adapter path; native evidence revalidated, adapter identity is not proven.'}
    data=read(bound_file(report['native_capture']))
    log=bound_file(report['native_log']).read_text()
    errors=validate_native(data,report,log)
    movie=bound_file(report['movie'])
    try:
        producer_command_origin(report, bound_file(report['native_capture']), log)
    except ValueError as error:
        errors.append(str(error))
    if report.get('environment',{}).get('LP_NUM_THREADS')!='1' or report.get('environment',{}).get('LIBGL_ALWAYS_SOFTWARE')!='1': errors.append('unmatched rendering environment')
    try:
        video=next(s for s in report['media']['streams'] if s['codec_type']=='video')
        audio=next(s for s in report['media']['streams'] if s['codec_type']=='audio')
        count=int(video['nb_frames'])
        if (video['width'],video['height'],video['avg_frame_rate'],int(audio['sample_rate']),audio['channels'])!=(1280,720,'60/1',48000,2) or count<data['tick_count']: errors.append('invalid formal media coverage')
        if not report.get('video_frames'): errors.append('no actual game pixels')
        last=-1
        from PIL import Image
        for item in report.get('video_frames',[]):
            path=bound_file(item)
            n=item['video_frame_index_zero_based']
            if type(n) is not int or not last<n<count or item['video_time_seconds']!=n/60: errors.append('invalid video frame/time binding')
            last=n
            with Image.open(path) as image:
                if image.size!=(1280,720): errors.append('non-formal image dimensions')
    except (KeyError,TypeError,ValueError,StopIteration) as exc: errors.append('invalid media/frame metadata: '+str(exc))
    if report.get('outcome')!=data.get('outcome') or report.get('route_reached')!=data.get('route_reached') or report.get('tick_count')!=data.get('tick_count'): errors.append('route summary mismatch')
    if report.get('composition_observation'):
        observation=read(bound_file(report['composition_observation']))
        validate_composition_binding(observation,report['native_capture']['sha256'],report['source_before'])
    if errors: raise ValueError('; '.join(errors))
    return report,data


def validate_review(review,report):
    """Pixel-review attestations must bind known actual frames; no metadata-only acceptance."""
    if not isinstance(review,dict) or not review.get('reviewer') or review.get('scope')!='observed_actual_game_pixels':
        raise ValueError('Reviewer must declare actual pixel observation and identity')
    known={(x['path'],x['sha256'],x['video_frame_index_zero_based']) for x in report['video_frames']}
    seen=review.get('observed_frames')
    if not isinstance(seen,list) or not seen: raise ValueError('Empty visual review')
    for item in seen:
        bound_file(item)
        if (item['path'],item['sha256'],item.get('video_frame_index_zero_based')) not in known: raise ValueError('Concept/foreign image is not this actual gameplay frame')
    if not isinstance(review.get('findings'),list) or review.get('verdict') not in ('ACCEPT','REJECT','UNVERIFIED'): raise ValueError('Missing visual judgment/findings')
    return {'kind':'reviewer_attestation_not_machine_proof_of_viewing','reviewer':review['reviewer'],'observed_frames':seen,'verdict':review['verdict'],'findings':review['findings']}


def _rect(value):
    if not isinstance(value,list) or len(value)!=4 or any(type(x) not in (int,float) or not math.isfinite(x) for x in value) or value[2]<=0 or value[3]<=0:
        raise ValueError('Bounds must be finite [x,y,width,height] with positive dimensions')
    return value


def overlap(a,b):
    return max(0,min(a[0]+a[2],b[0]+b[2])-max(a[0],b[0]))*max(0,min(a[1]+a[3],b[1]+b[3])-max(a[1],b[1]))


def composition_candidates(observation,native_capture_sha256,sources_at_capture):
    """Optional measured Node observation contract. Never infer opacity or beauty from AABBs."""
    if observation.get('artifact_kind')!='actual_scene_composition_observation' or observation.get('capture_sha256')!=native_capture_sha256:
        raise ValueError('Composition observation must bind this native capture')
    observer=observation.get('observer',{})
    if not observer.get('path') or sources_at_capture.get(observer['path'])!=observer.get('sha256'):
        raise ValueError('Composition observer absent/changed in capture source inventory')
    nodes=observation.get('nodes')
    if not isinstance(nodes,list) or not nodes: raise ValueError('Empty composition observation')
    candidates=[];layers=set();paths=set()
    for node in nodes:
        name=node.get('node_path')
        if not isinstance(name,str) or not name or name in paths: raise ValueError('Missing/duplicate observed Node path')
        paths.add(name);bounds=_rect(node['world_bounds']);layer=node.get('layer')
        if layer not in ('extreme_far','far','middle_far','middle','gameplay','near','atmosphere'): raise ValueError('Unknown layer role')
        layers.add(layer)
        if node.get('semantic') in ('rooted_architecture','hanging_plant','ground_vegetation') and not node.get('attachment_node_path'):
            candidates.append({'code':'unobserved_attachment','kind':'computed_proxy','node_path':name,'owner_skill':'scene-composer','reason':'Root/hanger attachment missing from measured scene observation; pixel review required, not proof of floating'})
        family=node.get('asset_family',{})
        if family.get('intended_use') and node.get('spatial_use')!=family['intended_use']:
            candidates.append({'code':'asset_use_mismatch','kind':'contract_fact','node_path':name,'owner_skill':'art-director','reason':'Observed spatial_use differs from supplied family intended_use'})
        if layer=='near':
            for zone in observation.get('protected_world_bounds',[]):
                target=_rect(zone['bounds'])
                if overlap(bounds,target)>0:
                    candidates.append({'code':'foreground_protected_bounds_overlap','kind':'computed_proxy','node_path':name,'target':zone.get('id'),'owner_skill':'scene-composer','reason':'AABBs overlap; opacity, depth, camera and actual pixels must establish occlusion'})
    for node in nodes:
        if node.get('attachment_node_path') and node['attachment_node_path'] not in paths:
            candidates.append({'code':'attachment_not_observed','kind':'computed_proxy','node_path':node['node_path'],'owner_skill':'scene-composer','reason':'Attachment reference has no measured Node in this observation'})
    if len(layers-{'gameplay','atmosphere'})<2:
        candidates.append({'code':'depth_roles_not_observed','kind':'observation_gap','owner_skill':'scene-composer','reason':'Fewer than two measured environmental depth roles; not proof that image lacks depth'})
    return candidates


def inspect_capture(receipt_path,review_path=None,observation_path=None):
    report,data=load_capture(receipt_path)
    nodes=[child for group in data['initial_scenery_inventory'] for child in group.get('descendants',[])]
    cameras=[{'tick':f['tick'],'camera':f['runtime']['camera'],'player_position':f['position'],'edge':f.get('edge')} for f in data['frames'] if f.get('runtime',{}).get('camera')]
    findings=[]
    if not cameras: findings.append({'code':'camera_observation_missing','kind':'observation_gap','owner_skill':'scene-composer'})
    missing=['Actual z_index/opacity/texture bounds/anchor attachment and parallax are not present in the original formal observer; no inferred occlusion/root acceptance']
    if not observation_path and report.get('composition_observation'):
        observation_path=bound_file(report['composition_observation'])
    if observation_path:
        observation=read(observation_path)
        validate_composition_binding(observation,report['native_capture']['sha256'],report['source_before'])
        findings+=composition_candidates(observation,report['native_capture']['sha256'],report['source_before'])
        missing=['Bounds/attachments are actual last-sample measurements; opacity, parallax and whole-route protected-zone coverage still require actual pixels and complete sampled coverage.']
    review=validate_review(read(review_path),report) if review_path else None
    return {'schema_version':1,'artifact_kind':'visual_director_diagnostic','status':'review_required',
            'receipt':artifact(receipt_path),'conditions':report['request'],'outcome':data['outcome'],'route_reached':data['route_reached'],
            'native_capture':report['native_capture'],'actual_game_movie':report['movie'],'actual_video_frames':report['video_frames'],
            'observed_scenery_nodes':nodes,'camera_trajectory':cameras,'findings':findings,'observation_gaps':missing,
            'adaptation_validation':report.get('adaptation_validation'),'review':review,'subjective_acceptance':'unverified','device_acceptance':'unverified',
            'composition_observation':artifact(observation_path) if observation_path else None,
            'review_source':artifact(review_path) if review_path else None,
            'limits':'Hashes establish byte provenance only. AABB candidates are not visual defects or aesthetic scores. Reviewer declarations are not authenticated proof of attention.'}


def compare_captures(before_path,after_path):
    before,old=load_capture(before_path);after,new=load_capture(after_path)
    errors=[]
    for key in ('root_seed','map_index','strategy','phase_wait_ticks','max_ticks','encounter_policy','capture_script','visual_layout','environment_phase','environment_mutation'):
        if before['request'].get(key)!=after['request'].get(key): errors.append('condition mismatch/'+key)
    if before.get('capture_extension') != after.get('capture_extension'):
        errors.append('capture extension/route source mismatch')
    for key in ('driver_sources','core_invariants'):
        if not old.get('policy_basis',{}).get(key) or old['policy_basis'][key]!=new.get('policy_basis',{}).get(key): errors.append('actual driver/core mismatch/'+key)
    if old.get('initial_capability')!=new.get('initial_capability'): errors.append('initial actual capability mismatch')
    for key in ('LP_NUM_THREADS','LIBGL_ALWAYS_SOFTWARE'):
        if before['environment'].get(key)!=after['environment'].get(key): errors.append('render environment mismatch/'+key)
    if old.get('engine')!=new.get('engine'): errors.append('engine mismatch')
    # Art-only changes require exactly the same generated playable route input.
    for key in ('manifest','formal_run_manifest_initial'):
        if old.get(key)!=new.get(key): errors.append('generated route input mismatch/'+key)
    if errors: raise ValueError('; '.join(errors))
    changed=[name for name in sorted(before['source_before'].keys()|after['source_before'].keys()) if before['source_before'].get(name)!=after['source_before'].get(name)]
    return {'schema_version':1,'artifact_kind':'actual_visual_comparison','status':'comparable_for_review',
            'before':artifact(before_path),'after':artifact(after_path),'conditions':{k:v for k,v in before['request'].items() if k!='source_commit'},
            'source_changes':changed,'before_source_commit':before['request']['source_commit'],'after_source_commit':after['request']['source_commit'],
            'visual_treatments': {'before': before['request'].get('visual_sample', ''), 'after': after['request'].get('visual_sample', '')},
            'before_movie':before['movie'],'after_movie':after['movie'],
            'route_outcomes':{'before':old['outcome'],'after':new['outcome']},
            'adaptation_validation':{'before':before.get('adaptation_validation'),'after':after.get('adaptation_validation')},
            'producer_origins':{
                'before':producer_command_origin(before,bound_file(before['native_capture']),bound_file(before['native_log']).read_text()),
                'after':producer_command_origin(after,bound_file(after['native_capture']),bound_file(after['native_log']).read_text())},
            'subjective_acceptance':'unverified','limits':'Same actual driver/core/entry/manifest conditions, not byte-identical trajectory, pixel registration, performance, full route success or beauty proof.'}


def route(request,task_id,quality_record,allowed_paths,max_calls=10,max_rounds=2,call_timeout=1800,phase='full'):
    """Build actual existing production_loop input, no separate AI scheduling or gate system."""
    import production_loop
    from level_region_context import build_region_context,resolve_region_id
    from level_experience import load_lessons
    if not request.strip() or not re.fullmatch(r'[A-Za-z0-9_-]+',task_id): raise ValueError('Concrete request and safe task id required')
    region_id=resolve_region_id(request)
    tasks=[];previous=[]
    groups=[('audit',['art-director','scene-composer'],'Read actual gameplay pixels and continuous footage; audit asset consumer/semantic gaps, measured scale/roots/layers; propose one original spatial silhouette.',True),
            ('golden',['art-director','scene-composer','animation-vfx'],'Register G0 visual design/family contract; implement ONE static golden in the real consumer, then wind/light; capture actual same-condition footage, inspect, compare and request independent pixel review. Fix actual observed defects with bounded attempts; never change core gameplay.',False),
            ('review',['gameplay-reviewer','art-director','scene-composer'],'Independently view actual PNG pixels and continuous normal-speed game footage; bind exact observed refs. Reject semantic misuse, visible cuts/unsupported roots, dangerous occlusion and weak composition. Technical pass never grants commercial quality/user/device acceptance.',True)]
    if phase not in ('full','audit','golden','review'): raise ValueError('Unknown visual production phase')
    for name,skills,goal,readonly in groups:
        if phase!='full' and name!=phase: continue
        entry={'id':task_id+'-'+name if phase=='full' else task_id,'goal':request+' — '+goal,'skills':['visual-director',*skills],'checks':(['visual-director-tests'] if readonly else ['visual-director-tests','art-art','capture-tests'] + (['visual-director-space'] if region_id == 'windchime_plains' else [])),
               'depends_on':previous,'read_only':readonly,'allowed_paths':allowed_paths,'quality_record':quality_record}
        if not readonly and region_id == 'windchime_plains':
            entry['checks'] = ['visual-director-terrain' if c == 'visual-director-space' else c for c in entry['checks']]
        if readonly: entry['completion']='scope'
        else: entry.update(completion='stage',required_gates=['G0','G1'],quality_task_id=entry['id'])
        tasks.append(entry);previous=[entry['id']]
    m={'schema_version':1,'objective':request,'workflow':'visual_golden','scope':'offline_production_plan_not_executed',
       'max_calls':max_calls,'max_rounds':max_rounds,'call_timeout_seconds':call_timeout,'tasks':tasks,
       'preparation':{'region_context':build_region_context(region_id) if region_id else {'status':'unregistered','runtime_available':None},'lessons':load_lessons(region_id)},
       'constraints':['Freeze Motor, weapons/resources/progression, RNG, actual collision geometry/route and saves; within the authorized art scope visual mesh, source profiles and UV mapping may be redesigned, not collision or gameplay','Admission is scoped to this family and actual consumer: independently evidenced actual-pixel G2 is required before its descendants expand; a rejected unrelated mother does not block independently qualified units. Preserve rejected contracts; a different limited pilot role requires its own actual-pixel review, never retroactive approval','No conceptual image posing as actual gameplay; no subjective score from hashes','Two no-progress visual rounds stop. Preserve every failed native/model/review attempt.','Host mode needs an active real Codex host, distinct implementation/review agents; otherwise block with original Harness lease/timeout','Use existing G0–G5/eleven quality dimensions; G0/G1 stage is not G2 beauty approval or full content completion']}
    regional_request = region_id == 'windchime_plains' and not re.search(r'场所|局部|另一段|钟庭|\blocal\b|\bplace\b', request, re.I)
    if regional_request:
        paths = ['scripts/generation/plains_region_art_plan.gd', 'scripts/generation/plains_region_generator.gd',
                 'scripts/art/plains_regional_composer.gd', 'shaders/plains_regional_ground.gdshader',
                 'resources/visual_development/p1_regional_assets.json', REGIONAL_CAPTURE,
                 'tools/plains_regional_art_preview.gd', 'tools/run_plains_regional_art_tests.py',
                 'tools/plains_regional_art_map.py', 'docs/evidence/plains_regional/recipe.md',
                 'docs/quality/records/PLAINS-REGIONAL-01.json',
                 'docs/evidence/plains_regional/independent-native-02.md']
        recipe = {'status': 'candidate_not_automatic_admission',
                  'scope': 'Actual complete formal randomized-region candidate; not automatic acceptance, golden, user, commercial or device approval',
                  'sources': [{'path': path, 'sha256': file_hash(ROOT / path)} for path in paths],
                  'profile': 'scripts/art/plains_regional_composer.gd',
                  'method': 'RETHINK: both collision-union painting and deep mass-minus-void prototypes failed actual whole-region art. Reuse full topology, actual shared plan/consumer and evidence tools; next art experiment must jointly embed landforms and routes rather than extrude the old row/column layout or resume place permutations.',
                  'recipe': 'docs/evidence/plains_regional/recipe.md',
                  'quality_record': 'docs/quality/records/PLAINS-REGIONAL-01.json',
                  'reviews': ['docs/evidence/plains_regional/independent-native-02.md'],
                  'capture_script': REGIONAL_CAPTURE,
                  'preview_script': 'tools/plains_regional_art_preview.gd',
                  'geometry_authority': 'Art-only task grants no new collision edits. Existing isolated full-region profile may be run; changed gameplay geometry requires an explicitly authorized joint experiment and actual Motor revalidation.',
                  'expansion': 'blocked_art_RETHINK_not_mature_production',
                  'technical_history_on_demand': 'docs/evidence/plains_joint/recipe.md'}
        m['preparation']['visual_recipe'] = recipe
        m['constraints'][1] = ('P1 remains a user preference, not final style approval. Actual regional art failed both methods; do not expand their descendants or label a local scene chain a complete region. A rejected unrelated mother does not block independently qualified units.')
        for task in tasks:
            if not task['read_only']:
                task['checks'] = list(dict.fromkeys([c for c in task['checks'] if c not in ('visual-director-terrain', 'visual-director-space')] + ['plains-regional-art-contract', 'plains-regional-art-counterexamples', 'plains-regional-art-graph-counterexamples']))
            task['goal'] += ' Before a long movie, execute this same MovieWriter adapter with max_ticks=60; require capture integrity and label frame_budget_exhausted as a bounded preflight, never route acceptance. Read the current full-region recipe and actual independent rejection first. Use the formal complete map, not fixed place reordering. Structural checks cannot sign art. Show whole-world terrain/routes/layers plus normal-camera actual full-route footage; preserve failed Seeds. Do not repeat the two rejected landmass methods or silently change collision in an art-only task.'
    elif region_id == 'windchime_plains':
        catalog_path = 'resources/visual_development/p1_places_assets.json'
        catalog = read(ROOT / catalog_path)
        paths = [catalog_path, catalog['master'],
                 'resources/generation/environment_grammar/places_v1.json',
                 'scripts/art/plains_place_composer.gd', 'scripts/generation/plains_place_plan.gd',
                 PLACES_CAPTURE, 'tools/plains_places_preview.gd', 'tests/plains_places_trace.gd',
                 'resources/art/avatars.json', 'docs/evidence/plains_places/recipe.md',
                 'docs/quality/records/PLAINS-PLACES-01.json',
                 'docs/evidence/plains_places/independent-01.md']
        def source_textures(value):
            if isinstance(value, dict):
                for key, child in value.items():
                    if key == 'texture' and isinstance(child, str) and child.startswith('res://'):
                        yield child.removeprefix('res://')
                    else:
                        yield from source_textures(child)
            elif isinstance(value, list):
                for child in value:
                    yield from source_textures(child)
        textures = list(dict.fromkeys(source_textures(catalog)))
        paths += textures
        paths += [str(Path(path).with_suffix('.record.json')) for path in textures]
        paths = list(dict.fromkeys(paths))
        m['constraints'][1] = ('P1 is the user-preferred candidate, not final user approval or formal-pool admission. Read the current P1 quality record and actual native review before deciding expansion; old B scoped acceptance does not admit P1. First-space whole-image art and motion readability must be independently admitted before a second structure; no batch expansion or full G2 claim from a plan. A rejected unrelated mother does not block independently qualified units.')
        m['preparation']['visual_recipe'] = {
            'status': 'candidate_not_automatic_admission',
            'scope': 'P1 three-place whole-volume development candidate; not automatic acceptance, no user, device, commercial or formal-production admission',
            'sources': [{'path': path, 'sha256': file_hash(ROOT / path)} for path in paths],
            'profile': 'scripts/art/plains_place_composer.gd',
            'method': 'STOP the PR82 shoulder-band/turned-end method after REWORK. Whole painted volumes use equal axis scale with measured interfaces; one resolved plan drives actual surfaces, place order and depth layers. Interface rejection and seeded structural execution provide limited technical evidence; actual whole-screen art remains pending independent native review.',
            'recipe': 'docs/evidence/plains_places/recipe.md',
            'quality_record': 'docs/quality/records/PLAINS-PLACES-01.json',
            'reviews': ['docs/evidence/plains_places/independent-01.md'],
            'capture_script': PLACES_CAPTURE,
            'preview_script': 'tools/plains_places_preview.gd',
            'geometry_authority': 'Existing candidate only. This art route grants no new collision edits; joint geometry redesign requires a separately authorized spatial experiment and real operation revalidation.',
            'technical_history_on_demand': 'docs/evidence/p1_native/recipe.md'}
        for task in tasks:
            if not task['read_only']:
                # The historical painted-terrain fixture remains available, but
                # cannot certify this different actual candidate consumer.
                task['checks'] = list(dict.fromkeys([c for c in task['checks'] if c != 'visual-director-terrain'] + ['plains-places-contract', 'plains-places-capture-tests']))
                task['goal'] += (' Read the current whole-volume place recipe and preserved PR82 REWORK evidence before choosing a method. Design the continuous multi-screen terrain, rooted construction, actor path and negative space jointly; never map independent images one-to-one onto collision rectangles. Use the explicit candidate consumer and capture adapter, preserving original core contracts. STOP the rejected PR82 shoulder-band/turned-end method. Inspect whole source volumes at equal axis scale, measured source ports and actual place transitions. Run bounded interface rejection and seeded structure checks; these checks cannot admit art. Retain source/prompt/reference and native before/after records. Independently judge the whole actual screen before local polish or expansion. A plan is not execution, a strict route pass is not art admission, and changing Seed phase is not structural variation.')
    production_loop.validate(m)
    return m


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest='command',required=True)
    p=sub.add_parser('capture')
    p.add_argument('--seed',default='level-design-v2-baseline');p.add_argument('--map-index',type=int,choices=(1,2),default=1)
    p.add_argument('--strategy',choices=('fast','growth','deep','return'),default='growth');p.add_argument('--output',required=True)
    p.add_argument('--max-ticks',type=int,default=6000);p.add_argument('--timeout',type=int,default=900)
    p.add_argument('--phase-wait-ticks',type=int,default=0);p.add_argument('--frame-stride',type=int,default=120)
    p.add_argument('--capture-script',choices=sorted(CAPTURE_SCRIPTS),help='Explicit spatial fixture adapter; default formal capture unchanged')
    p.add_argument('--environment-phase',choices=('probe','full'),default='full',help='Explicit environment candidate only; probe observes the initial real stand')
    p.add_argument('--environment-mutation',choices=('', 'no-gun'),default='',help='Explicit environment driver negative case; never modifies player abilities')
    p.add_argument('--visual-sample',choices=VISUAL_SAMPLE_CATALOGS,default='',help='Explicit PR75 baseline, painted-terrain or P1 candidate catalog; requires spatial capture adapter')
    p.add_argument('--visual-layout',choices=('open-meadow',),default='',help='Explicit actual three-shore layout; A/E must select the same variant')
    p.add_argument('--composition',action='store_true',help='Request actual read-only scene measurements; absent consumer remains an explicit gap')
    p.add_argument('--encounter-policy',choices=level_formal.ENCOUNTER_POLICIES,default='kill_from_bank_v1')
    p=sub.add_parser('finalize-existing');p.add_argument('--original-receipt',required=True);p.add_argument('--output',required=True);p.add_argument('--frame-stride',type=int,default=120)
    for name in ('inspect','analyze'):
        p=sub.add_parser(name);p.add_argument('--capture',required=True);p.add_argument('--output',required=True)
        p.add_argument('--review');p.add_argument('--composition-observation')
    p=sub.add_parser('compare');p.add_argument('--before',required=True);p.add_argument('--after',required=True);p.add_argument('--output',required=True)
    p=sub.add_parser('route');p.add_argument('--request',required=True);p.add_argument('--task-id',required=True)
    p.add_argument('--quality-record',required=True);p.add_argument('--allowed-path',action='append',required=True)
    p.add_argument('--phase',choices=('full','audit','golden','review'),default='full')
    p.add_argument('--output',required=True);p.add_argument('--max-calls',type=int,default=10);p.add_argument('--max-rounds',type=int,default=2);p.add_argument('--call-timeout',type=int,default=1800)
    p=sub.add_parser('run');p.add_argument('--mission',required=True);p.add_argument('--evidence-dir',required=True)
    p.add_argument('--execute',action='store_true');p.add_argument('--worker-mode',choices=('host','codex'),default='host')
    args=parser.parse_args(argv)
    try:
        if args.command=='capture':
            report=capture(args.seed,args.map_index,args.strategy,args.output,args.max_ticks,args.timeout,args.encounter_policy,args.phase_wait_ticks,args.frame_stride,args.composition,args.capture_script,args.visual_sample,args.visual_layout,args.environment_phase,args.environment_mutation)
            print(json.dumps({'status':report['status'],'outcome':report.get('outcome'),'route_reached':report.get('route_reached'), 'receipt':str(Path(args.output)/'visual_capture.json')},ensure_ascii=False))
            return 0 if report['status']=='captured' else 1
        if args.command=='finalize-existing':
            result=finalize_existing(args.original_receipt,args.output,args.frame_stride)
            print(json.dumps({'status':result['status'],'receipt':str(Path(args.output)/'visual_capture.json')}))
            return 0 if result['status']=='captured' else 1
        if args.command in ('inspect','analyze'):
            result=inspect_capture(args.capture,args.review,args.composition_observation)
        elif args.command=='compare': result=compare_captures(args.before,args.after)
        elif args.command=='route': result=route(args.request,args.task_id,args.quality_record,args.allowed_path,args.max_calls,args.max_rounds,args.call_timeout,args.phase)
        else:
            command=[sys.executable,str(ROOT/'tools/harness.py'),'--mission',args.mission,'--evidence-dir',args.evidence_dir,'--worker-mode',args.worker_mode]
            if args.execute: command.append('--execute')
            return subprocess.call(command,cwd=ROOT)
        output=Path(args.output).resolve()
        if not output.is_relative_to(ROOT/'build') or output.exists(): raise ValueError('Use a new build/ output, retain previous diagnostics')
        write(output,result)
        print('PASS: visual director '+args.command+' evidence written; subjective/device acceptance remains unverified')
        return 0
    except (ValueError,KeyError,OSError) as exc:
        print('BLOCKED: '+str(exc),file=sys.stderr);return 2

if __name__=='__main__': raise SystemExit(main())
