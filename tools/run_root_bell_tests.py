"""Run actual root-bell actors and optional continuous GPU+audio fixture.

The package admission stays closed. A movie is an animation review carrier,
not proof of a formal route, visual quality, device performance, or acceptance.
"""
import argparse
import copy
import hashlib
import json
import math
import zipfile
import os
from pathlib import Path
import re
import selectors
import subprocess
import sys
import time
from run_tests import run_engine

ROOT = Path(__file__).resolve().parent.parent
BASE = ROOT / 'build/root_bell'
OUT = BASE
LOCK = '/workspace/gunman-rush/build/region_production_v3/engine.lock'
SOURCES = [
    'scripts/enemies/enemy_actor.gd', 'scripts/enemies/enemy_definition.gd',
    'scripts/enemies/root_bell_behavior.gd', 'scripts/enemies/root_bell_presentation.gd',
    'scripts/generation/plains_encounter_planner.gd',
    'scripts/generation/plains_region_generator.gd',
    'scripts/generation/plains_root_bell_placement.gd',
    'scripts/demo/generated_demo_stage.gd',
    'resources/enemies/plains_root_bell.tres',
    'assets/region_production_v3/enemies/root_bell/source/master.png',
    'assets/region_production_v3/enemies/root_bell/manifest.json',
    'tests/root_bell_tests.gd', 'tests/root_bell_runner.gd', 'tools/run_root_bell_tests.py',
]

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def sources():
    return {p: sha(ROOT / p) for p in SOURCES}

def require(ok, reason):
    if not ok:
        raise ValueError(reason)

CAPTURE_SCOPE = 'G0/G1 fixtures and actual spawn consumer; formal route/visual/audio/device unverified'
CASE_SCOPE = 'actual_normal_scheduled_Motor_damage_and_GeneratedDemoStage_spawn_fixture'
MANIFEST_SCOPE = '20 actual generated manifests; candidate placement only, not formal route execution'
CALIBRATION_MATRIX = {(width, direction) for width in (400, 440, 560) for direction in (-1, 1)}
ESSENTIAL_CASES = {
    'stand_in_pulse_positive_damage', 'walk_out_alive_nonkill', 'base_jump_nonkill',
    'real_projectile_interrupt', 'solid_occlusion_negative', 'miss_does_not_interrupt',
    'pause_actor_epoch', 'inactive_target', 'early_real_death_and_walk_through',
    'actual_stage_capture_and_ledger_roundtrip', 'restored_pending_pulse_is_cancelled',
    'duplicate_hit_does_not_interrupt', 'actual_formal_manifest_gated_candidates',
} | {f'width_{width}_dir_{direction}' for width, direction in CALIBRATION_MATRIX}


def _finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def _near(first, second, tolerance=1e-5):
    if isinstance(first, list) and isinstance(second, list):
        return len(first) == len(second) and all(_near(a, b, tolerance) for a, b in zip(first, second))
    return _finite(first) and _finite(second) and abs(first-second) <= tolerance


def _definition_values():
    # Runtime quantities remain defined in the actual Resource; the acceptance
    # consumer does not silently invent a second timing/collision configuration.
    text = (ROOT/'resources/enemies/plains_root_bell.tres').read_text()
    values = {}
    for name in ('telegraph_duration', 'attack_duration', 'recovery_duration'):
        values[name] = float(re.search(r'^'+name+r'\s*=\s*([0-9.]+)$', text, re.M)[1])
    for name in ('collision_size', 'pulse_size'):
        values[name] = [float(v) for v in re.search(r'^'+name+r'\s*=\s*Vector2\(([^)]+)\)$', text, re.M)[1].split(',')]
    return values


def _events(case, kind):
    return [e for e in case['events'] if e['kind'] == kind]


DAMAGE_FEEDBACK_PATHS = ('resources/damage/feedback.tres', 'scripts/damage/damage_feedback_definition.gd')


def damage_feedback_sources():
    return {path: sha(ROOT/path) for path in DAMAGE_FEEDBACK_PATHS}


def _damage_stun_frames(case):
    """Observe EnemyActor's existing HP-committed, bounded motor-only branch.

    DamagePolicy resolves after actors (priority1000), so accepted damage sets
    the full duration in that frame; subsequent actor ticks consume exactly dt.
    A last tick which reaches zero still returns before advancing behavior.
    """
    name, frames = case['id'], case['frames']
    text = (ROOT/DAMAGE_FEEDBACK_PATHS[0]).read_text()
    value = re.search(r'^enemy_knockback_seconds\s*=\s*([0-9.]+)$', text, re.M)
    if value is None:
        text = (ROOT/DAMAGE_FEEDBACK_PATHS[1]).read_text()
        value = re.search(r'^@export var enemy_knockback_seconds\s*:=\s*([0-9.]+)$', text, re.M)
    require(value is not None, name+': actual damage feedback duration missing')
    duration = float(value[1])
    declared = case.get('damage_feedback', {})
    require(isinstance(declared, dict) and set(declared) == {'resource_path', 'enemy_knockback_seconds'} and
            declared['resource_path'] == 'res://'+DAMAGE_FEEDBACK_PATHS[0] and
            _near(declared['enemy_knockback_seconds'], duration), name+': damage feedback differs from actual Resource/default')
    frozen = set()
    for index, frame in enumerate(frames):
        remaining = frame.get('damage_stun_remaining')
        require(_finite(remaining) and 0 <= remaining <= duration+1e-5, name+': missing or invalid actual damage stun')
        if not index:
            require(remaining == 0, name+': fixture starts with uncaused stun')
            continue
        previous = frames[index-1]
        hits = [e for e in case['events'] if isinstance(e, dict) and e.get('kind') == 'damage' and e.get('target') == 'root_fixture' and e.get('tick') == frame['tick']]
        drop = previous['enemy_hp']-frame['enemy_hp']
        committed = (drop > 0 and len(hits) == 1 and
                     _near(hits[0].get('health'), frame['enemy_hp']) and _near(hits[0].get('amount'), drop))
        if committed and frame['enemy_hp'] > 0:
            expected = duration
        elif previous['enemy_hp'] > 0:
            expected = max(0, previous['damage_stun_remaining']-1/60)
        else:
            expected = previous['damage_stun_remaining']
        require(remaining == 0 if expected == 0 else _near(remaining, expected), name+': stun lacks committed HP cause, decrements incorrectly or was reset/extended')
        if previous['damage_stun_remaining'] > 0 and previous['enemy_hp'] > 0:
            frozen.add(index)
            if not committed:
                require(frame['state'] == previous['state'] and _near(frame['time'], previous['time']) and
                        frame['serial'] == previous['serial'] and _near(frame['goal'], previous['goal']),
                        name+': motor-only damage stun advanced/reset behavior')
    return frozen


def _coherent_frames(case, *, historical_no_stun=False):
    name, frames = case['id'], case['frames']
    require(case.get('scope') == CASE_SCOPE and len(frames) >= 2, name+': missing or wrong native fixture scope/frames')
    required = {'tick', 'process_frame', 'physics_frame', 'position', 'grounded', 'player_hp', 'energy', 'enemy_hp', 'state', 'time', 'goal', 'serial', 'active', 'axis'}
    for index, frame in enumerate(frames):
        require(isinstance(frame, dict) and required <= frame.keys(), name+': incomplete native frame')
        require(type(frame['tick']) is int and frame['tick'] == index+1, name+': native frame chronology has a gap/duplicate')
        require(all(type(frame[key]) is int and frame[key] >= 0 for key in ('process_frame', 'physics_frame', 'serial')), name+': invalid native counters')
        require(all(type(frame[key]) is bool for key in ('grounded', 'active')), name+': invalid native state flags')
        require(all(_finite(frame[key]) and frame[key] >= 0 for key in ('player_hp', 'enemy_hp', 'energy', 'time')), name+': invalid native numeric state')
        require(_finite(frame['axis']) and -1 <= frame['axis'] <= 1, name+': invalid axis')
        require(frame['state'] in ('idle', 'telegraph', 'attack', 'recovery'), name+': unknown enemy state')
        require(all(isinstance(frame[key], list) and len(frame[key]) == 2 and all(_finite(v) for v in frame[key]) for key in ('position', 'goal')), name+': invalid position/mark')
    frozen = set() if historical_no_stun else _damage_stun_frames(case)
    for index, frame in enumerate(frames):
        if not index:
            continue
        previous = frames[index-1]
        require(frame['physics_frame'] > previous['physics_frame'] and frame['process_frame'] > previous['process_frame'], name+': native clocks did not advance')
        if name != 'pause_actor_epoch':
            require(frame['physics_frame'] == previous['physics_frame']+1, name+': omitted native physics samples')
        if frame['state'] == previous['state'] and frame['active'] and previous['active'] and frame['enemy_hp'] > 0 and previous['enemy_hp'] > 0:
            require(_near(frame['time']-previous['time'], 0 if index in frozen else 1/60), name+': state clock was erased/reset/frozen outside actual damage stun')
        if frame['state'] in ('telegraph', 'attack') and previous['state'] in ('telegraph', 'attack'):
            require(_near(frame['goal'], previous['goal']), name+': locked mark tracked the player')
        require(0 <= frame['serial']-previous['serial'] <= 1, name+': attack serial regressed/jumped')
    require(isinstance(case['events'], list), name+': missing native events')
    seen_damage = set()
    for event in case['events']:
        require(isinstance(event, dict) and isinstance(event.get('kind'), str) and type(event.get('tick')) is int and 1 <= event['tick'] <= len(frames), name+': event lacks a real observed frame')
        current = frames[event['tick']-1]
        if event['kind'] == 'state':
            require(current['state'] == event.get('state'), name+': state event disagrees with actual frame')
        if event['kind'] == 'accepted_jump':
            require(not current['grounded'] and event['tick'] > 1 and frames[event['tick']-2]['grounded'], name+': jump lacks physical takeoff')
        if event['kind'] == 'accepted_landing':
            require(current['grounded'], name+': landing lacks actual support')
        if event['kind'] == 'pulse':
            require(current['state'] == 'attack' and _near(current['goal'], event.get('point')), name+': pulse lacks actual attack/locked mark')
            require(event.get('id') == f"root_fixture:root_pulse:{current['serial']}", name+': pulse event serial is not actual attack serial')
        if event['kind'] == 'damage':
            require(event.get('target') in ('player', 'root_fixture') and isinstance(event.get('id'), str) and _finite(event.get('amount')) and event['amount'] > 0, name+': malformed committed damage')
            key = (event['target'], event['id'])
            require(key not in seen_damage, name+': repeated committed damage identity')
            seen_damage.add(key)
            hp = 'player_hp' if event['target'] == 'player' else 'enemy_hp'
            require(event['tick'] > 1 and _near(current[hp], event.get('health')) and _near(frames[event['tick']-2][hp]-current[hp], event['amount']), name+': committed damage lacks actual before/after HP delta')
    for index, frame in enumerate(frames):
        previous = frames[index-1] if index else None
        entered = (previous is None and frame['state'] != 'idle') or (previous is not None and frame['state'] != previous['state'])
        if entered:
            require(any(e['kind'] == 'state' and e.get('state') == frame['state'] and e['tick'] == frame['tick'] for e in case['events']), name+': actual state transition lost its accepted event')
        if frame['state'] == 'attack' and entered:
            require(len([e for e in _events(case, 'pulse') if e['tick'] == frame['tick']]) == 1, name+': attack entry lost its actual pulse')
    for hit in [e for e in _events(case, 'damage') if e['target'] == 'root_fixture']:
        matching = [e for e in _events(case, 'shot') if str(hit['id']).rsplit(':', 1)[-1] == str(e['shot_id']) and e['tick'] < hit['tick']]
        require(len(matching) == 1, name+': HP commitment lacks its real accepted projectile')
    for index in range(1, len(frames)):
        for hp, target in (('player_hp', 'player'), ('enemy_hp', 'root_fixture')):
            delta = frames[index-1][hp]-frames[index][hp]
            matching = [e for e in _events(case, 'damage') if e['tick'] == index+1 and e['target'] == target]
            require(delta >= -1e-5 and _near(delta, sum(e['amount'] for e in matching)), name+': HP delta lacks a committed damage cause')


def _interrupt_causality(case, definition, terminal):
    damage = [e for e in _events(case, 'damage') if e['target'] == 'root_fixture']
    cancelled, shots = _events(case, 'interrupted'), _events(case, 'shot')
    require(len(damage) == len(cancelled) == len(shots) == 1, case['id']+': incomplete actual interrupt chain')
    hit, interruption, shot = damage[0], cancelled[0], shots[0]
    require(shot['tick'] < hit['tick'] == interruption['tick'], case['id']+': shot/HP/interrupt ordering invalid')
    require(str(hit['id']).rsplit(':', 1)[-1] == str(shot['shot_id']), case['id']+': committed HP is unrelated to accepted shot')
    frames = case['frames']
    before, committed = frames[hit['tick']-2], frames[hit['tick']-1]
    require(before['state'] == 'telegraph' and before['time'] < definition['telegraph_duration'], case['id']+': hit did not interrupt an observed live warning')
    require(committed['state'] == 'recovery' and committed['time'] <= 1/60+1e-5 and committed['enemy_hp'] < before['enemy_hp'], case['id']+': no committed-HP recovery transition')
    require(any(e['tick'] == hit['tick'] and e.get('state') == 'recovery' for e in _events(case, 'state')), case['id']+': recovery event absent')
    require(frames[shot['tick']-1]['energy'] < frames[shot['tick']-2]['energy'], case['id']+': accepted shot lacks actual resource spend')
    recovery = []
    for frame in frames[hit['tick']-1:]:
        if frame['state'] != 'recovery':
            break
        recovery.append(frame)
    require(recovery and recovery[-1]['time'] >= definition['attack_duration'], case['id']+': recovery not observed for the cancelled pulse interval')
    if terminal:
        require(len(recovery) == len(frames)-hit['tick']+1, case['id']+': missing continuous post-interruption recovery')
    require(not _events(case, 'pulse'), case['id']+': interrupted warning still pulsed')


def _validate_structure_and_lifecycle(data, *, historical_no_stun=False):
    require(isinstance(data, dict) and set(data) == {'cases', 'production_pool', 'scope'}, 'Unknown capture declarations; raw source provenance belongs in a bound receipt')
    require(data['production_pool'] is False and data['scope'] == CAPTURE_SCOPE, 'Fixture capture cannot declare production/formal admission')
    require(isinstance(data['cases'], list) and all(isinstance(c, dict) and isinstance(c.get('id'), str) for c in data['cases']), 'Invalid case inventory')
    ids = [case['id'] for case in data['cases']]
    require(len(ids) == len(set(ids)) and set(ids) == ESSENTIAL_CASES, 'Essential native cases must appear exactly once, including every lifecycle and direction case')
    cases = {case['id']: case for case in data['cases']}
    for case in data['cases']:
        require(isinstance(case.get('frames'), list) and isinstance(case.get('events'), list), case['id']+': no frame/event arrays')
        if case['id'] != 'actual_formal_manifest_gated_candidates':
            _coherent_frames(case, historical_no_stun=historical_no_stun)
    definition = _definition_values()
    _interrupt_causality(cases['real_projectile_interrupt'], definition, True)
    duplicate = cases['duplicate_hit_does_not_interrupt']
    _interrupt_causality(duplicate, definition, False)
    require(duplicate['frames'][-1]['state'] == 'telegraph' and len([e for e in _events(duplicate, 'state') if e.get('state') == 'telegraph']) == 2 and _near(duplicate['frames'][-1]['enemy_hp'], duplicate['frames'][-2]['enemy_hp']), 'Duplicate-hit negative lacks second actual unbroken warning')
    for name in ('pause_actor_epoch', 'inactive_target'):
        case = cases[name]
        warning = [f for f in case['frames'] if f['state'] == 'telegraph']
        recovery = [f for f in case['frames'] if f['state'] == 'recovery']
        require(warning and recovery and warning[-1]['tick'] < recovery[0]['tick'], name+': missing observed warning/cancel/recovery')
        require(not _events(case, 'damage') and not _events(case, 'pulse') and recovery[-1]['serial'] == warning[-1]['serial'], name+': cancelled old attack still committed')
    paused = cases['pause_actor_epoch']['frames']
    require(any(b['physics_frame']-a['physics_frame'] > 1 for a, b in zip(paused, paused[1:])), 'Pause negative lacks observed paused-clock interval')
    require(all(f['active'] for f in paused), 'Pause/epoch case silently deactivated target')
    inactive = cases['inactive_target']['frames']
    require(any(f['active'] and f['state'] == 'telegraph' for f in inactive) and all(not f['active'] for f in inactive if f['state'] == 'recovery'), 'Inactive negative lacks actual active-to-inactive cancellation')
    saved = cases['actual_stage_capture_and_ledger_roundtrip']
    pending = saved['frames'][-1]
    require(pending['state'] == 'attack' and _events(saved, 'pulse') and any(e['target'] == 'player' for e in _events(saved, 'damage')), 'Snapshot source lacks actual committed pending pulse')
    restored = cases['restored_pending_pulse_is_cancelled']
    frames = restored['frames']
    require(not _events(restored, 'damage') and not _events(restored, 'pulse'), 'Restored old pulse produced damage')
    require(all(f['state'] == 'recovery' and f['active'] and f['serial'] == pending['serial'] and _near(f['enemy_hp'], pending['enemy_hp']) and _near(f['goal'], pending['goal']) for f in frames), 'Restored cancellation lost inherited serial/HP/mark or recovery state')
    require(0 < frames[0]['time'] <= 2/60 and definition['attack_duration'] <= frames[-1]['time'] < definition['recovery_duration'], 'Restored recovery debt/time interval is absent or fabricated')
    require(all(_near(f['player_hp'], frames[0]['player_hp']) for f in frames), 'Restored target HP changed during old-pulse observation')
    require(any(e.get('state') == 'recovery' and e['tick'] == frames[0]['tick'] for e in _events(restored, 'state')), 'Restored recovery transition lacks its actual first frame')
    calibrated = [case for case in data['cases'] if 'calibration' in case]
    observed_pairs = [(case['calibration'].get('width'), case['calibration'].get('direction')) for case in calibrated]
    require(len(observed_pairs) == len(set(observed_pairs)) and set(observed_pairs) == CALIBRATION_MATRIX, 'Calibration requires unique exact width x direction Cartesian coverage')
    for case in calibrated:
        c, frames = case['calibration'], case['frames']
        width, direction = c['width'], c['direction']
        require(case['id'] == f'width_{int(width)}_dir_{int(direction)}', 'Calibration identity differs from declared actual pair')
        floor, center, size = c['actual_support_rect_xywh'], c['actual_enemy_center'], c['actual_enemy_collision_size']
        require(len(floor) == 4 and all(_finite(v) for v in floor) and floor[2] == width and floor[3] > 0, 'Calibration actual support invalid')
        require(_near(size, definition['collision_size']) and _near(c['actual_pulse_size'], definition['pulse_size']), 'Calibration sizes disagree with actual Definition')
        require(_near(center, [floor[0]+width/2, floor[1]-size[1]/2]), 'Calibration live enemy is not actually supported at center')
        start_x = floor[0]+64 if direction == 1 else floor[0]+width-64
        finish_x = floor[0]+width-64 if direction == 1 else floor[0]+64
        takeoff_x = center[0]-direction*90
        require(_near(c['takeoff_x'], takeoff_x) and _near(c['finish_x'], finish_x), 'Calibration metadata does not match directed fixture start/takeoff/finish')
        require(_near(frames[0]['position'][0], start_x) and frames[0]['grounded'], 'Calibration did not actually start on declared side')
        require(abs(frames[-1]['position'][0]-finish_x) <= 5 and frames[-1]['grounded'] and abs(frames[-1]['position'][1]+18-floor[1]) < .1, 'Calibration real endpoint is not supported at declared finish')
        jump = _events(case, 'accepted_jump')
        require(len(jump) == 1 and abs(frames[jump[0]['tick']-2]['position'][0]-takeoff_x) <= 5, 'Calibration has no actual supported takeoff at declared approach')
        require(direction*(frames[-1]['position'][0]-frames[0]['position'][0]) > width/2 and all(direction*(b['position'][0]-a['position'][0]) >= -1e-5 for a, b in zip(frames, frames[1:])), 'Calibration did not traverse in its declared direction')
        require(all(floor[0]+12 <= f['position'][0] <= floor[0]+width-12 for f in frames), 'Calibration leaves actual supported lane')
    manifest = cases['actual_formal_manifest_gated_candidates']
    require(manifest['scope'] == MANIFEST_SCOPE and len(manifest['frames']) == 1 and not manifest['events'], 'Manifest-only scope incorrectly claims a native route')
    rows = manifest['frames'][0].get('manifest_rows', [])
    pairs = [(r.get('seed'), r.get('difficulty')) for r in rows]
    require(len(pairs) == len(set(pairs)) and set(pairs) == {(f'v3-root-bell-{i}', difficulty) for i in range(10) for difficulty in ('intro', 'advanced')}, 'Manifest matrix root/difficulty coverage missing or duplicated')
    require(all(re.fullmatch('[0-9a-f]{64}', r.get('manifest_hash', '')) for r in rows), 'Manifest matrix lacks actual hashes')


def validate_evidence(capture_bytes, report, runtime_bytes, expected_sources, expected_commit, *, historical_no_stun=False):
    """Complete explicit receipt binding. validate_capture alone is content/scope
    validation; it never turns an unbound dictionary into authenticated runtime.
    Historical rechecks pass their archived exact source map explicitly.
    """
    require(set(expected_sources) == set(SOURCES) and all(re.fullmatch('[0-9a-f]{64}', value) for value in expected_sources.values()), 'Expected source receipt is incomplete')
    require(report.get('status') == 'passed' and report.get('source_commit') == expected_commit, 'Wrong source commit/status in native receipt')
    require(report.get('source_before') == report.get('source_after') == expected_sources, 'Native evidence source receipt mismatch or drift')
    require(hashlib.sha256(capture_bytes).hexdigest() == report.get('capture_sha256'), 'Raw capture differs from native receipt')
    require(hashlib.sha256(runtime_bytes).hexdigest() == report.get('runtime_log_sha256'), 'Runtime log differs from native receipt')
    match = re.search(rb'^ROOT BELL: ([1-9]\d*) assertions, 0 failures$', runtime_bytes, re.M)
    require(match is not None and int(match[1]) == report.get('assertions') and b'ERROR:' not in runtime_bytes, 'Missing actual native completion or stale assertion receipt')
    if not historical_no_stun:
        require(report.get("damage_feedback_source_before") == report.get("damage_feedback_source_after") == damage_feedback_sources(), "Damage feedback dependency receipt mismatch or drift")
    data = json.loads(capture_bytes)
    validate_capture(data, historical_no_stun=historical_no_stun)
    return {'scope': CAPTURE_SCOPE, 'essential_cases': len(ESSENTIAL_CASES), 'width_direction_pairs': sorted([list(pair) for pair in CALIBRATION_MATRIX]), 'native_assertions': report['assertions'], 'native_reexecuted': False}


def validate_capture(data, *, historical_no_stun=False):
    _validate_structure_and_lifecycle(data, historical_no_stun=historical_no_stun)
    cases = {c['id']: c for c in data['cases']}
    def events(name, kind):
        return [e for e in cases[name]['events'] if e['kind'] == kind]
    standing = events('stand_in_pulse_positive_damage', 'damage')
    require(len(standing) == 1 and standing[0]['target'] == 'player' and ':root_pulse:' in standing[0]['id'], 'standing pulse lacks one actual damage event')
    for name in ('walk_out_alive_nonkill', 'base_jump_nonkill'):
        row = cases[name]
        require(len(events(name, 'pulse')) == 1 and not events(name, 'damage'), 'nonkill bypass lacks a real living pulse')
        require(row['frames'][-1]['enemy_hp'] == 3, 'nonkill bypass silently killed target')
    jumping = cases['base_jump_nonkill']
    require(len(events('base_jump_nonkill', 'accepted_jump')) == 1, 'missing actual accepted jump')
    require(any(not f['grounded'] and f['position'][1] < 245 for f in jumping['frames']) and jumping['frames'][-1]['grounded'], 'jump lacks physical ascent and landing')
    interrupted = cases['real_projectile_interrupt']
    shots = events('real_projectile_interrupt', 'shot')
    damage = [e for e in events('real_projectile_interrupt', 'damage') if e['target'] == 'root_fixture']
    cancelled = events('real_projectile_interrupt', 'interrupted')
    require(len(shots) == len(damage) == len(cancelled) == 1, 'real projectile interruption requires accepted shot/damage/interrupt')
    require(shots[0]['tick'] <= damage[0]['tick'] == cancelled[0]['tick'], 'interruption precedes HP commitment')
    require(interrupted['frames'][-1]['enemy_hp'] == 2 and not events('real_projectile_interrupt', 'pulse'), 'interruption did not lower HP/cancel pulse')
    for name in ('solid_occlusion_negative', 'miss_does_not_interrupt'):
        require(cases[name]['frames'][-1]['enemy_hp'] == 3 and not events(name, 'interrupted'), 'blocked/missed attack faked HP interrupt')
    dead = cases['early_real_death_and_walk_through']
    require(dead['frames'][-1]['enemy_hp'] == 0 and dead['frames'][-1]['position'][0] > 370, 'dead actor path was not walked')
    require(len([e for e in events(dead['id'], 'damage') if e['target'] == 'root_fixture']) == 3, 'death lacks three actual committed shots')
    require(not events('restored_pending_pulse_is_cancelled', 'damage') and not events('restored_pending_pulse_is_cancelled', 'pulse'), 'restored old attack damaged new target')
    calibrated = [c for c in data['cases'] if 'calibration' in c]
    require(len(calibrated) == 6, 'missing two-direction 400/440/560 physical calibration')
    for row in calibrated:
        observed = row['calibration']
        require(observed['actual_support_rect_xywh'][2] == observed['width'], 'calibration floor differs from live support')
        require(not observed['formal_width_policy_changed'], 'calibration silently changed production policy')
        require(not [e for e in row['events'] if e['kind'] in ('shot', 'damage')], 'calibration used shooting or accepted damage')
        require(len([e for e in row['events'] if e['kind'] == 'accepted_jump']) == 1, 'calibration lacks one real base jump')
        require(any(e['kind'] == 'pulse' for e in row['events']) and row['frames'][-1]['grounded'] and row['frames'][-1]['enemy_hp'] == 3, 'calibration missing live pulse or final supported landing')
        center = observed['actual_enemy_center']
        half = observed['actual_enemy_collision_size']
        over_body = [f for f in row['frames'] if abs(f['position'][0] - center[0]) < half[0]/2 + 13]
        require(over_body and all(f['position'][1] < center[1] - half[1]/2 - 19 for f in over_body), 'calibration did not physically clear live enemy contact envelope')
    rows = cases['actual_formal_manifest_gated_candidates']['frames'][0]['manifest_rows']
    require(len(rows) == 20 and all(r['candidate']['replaced'] <= 1 for r in rows), 'missing formal manifest budget matrix')

def tamper_checks(data, *, historical_no_stun=False):
    def remove(case, kind):
        def mutation(row):
            target = next(c for c in row['cases'] if c['id'] == case)
            target['events'] = [e for e in target['events'] if e['kind'] != kind]
        return mutation
    mutations = {
        'erase_actual_pulse_damage': remove('stand_in_pulse_positive_damage', 'damage'),
        'erase_actual_projectile_damage': remove('real_projectile_interrupt', 'damage'),
        'erase_accepted_shot': remove('real_projectile_interrupt', 'shot'),
        'erase_accepted_jump': remove('base_jump_nonkill', 'accepted_jump'),
        'erase_death_hits': remove('early_real_death_and_walk_through', 'damage'),
    }
    def one(data, name):
        return next(case for case in data['cases'] if case['id'] == name)
    # Keep the original five negatives above unchanged and append the actual
    # independent-review counterexamples plus structural variations.
    for case_id in sorted(ESSENTIAL_CASES):
        mutations['erase_required_case/'+case_id] = lambda d, case_id=case_id: d.update(cases=[c for c in d['cases'] if c['id'] != case_id])
    def missing_lifecycle(data):
        missing = {'pause_actor_epoch', 'inactive_target', 'actual_stage_capture_and_ledger_roundtrip', 'duplicate_hit_does_not_interrupt'}
        data['cases'] = [case for case in data['cases'] if case['id'] not in missing]
    def erase_warning(data):
        case = one(data, 'real_projectile_interrupt')
        case['frames'] = [f for f in case['frames'] if f['state'] != 'telegraph']
    def empty_restore(data):
        case = one(data, 'restored_pending_pulse_is_cancelled')
        case['frames'], case['events'] = [], []
    def clone_calibration(data, forged_unique_metadata=False):
        template = copy.deepcopy(one(data, 'width_400_dir_1'))
        data['cases'] = [case for case in data['cases'] if 'calibration' not in case]
        for index, (width, direction) in enumerate(sorted(CALIBRATION_MATRIX)):
            case = copy.deepcopy(template)
            case['id'] = f'width_{width}_dir_{direction}' if forged_unique_metadata else 'renamed_duplicate_'+str(index)
            if forged_unique_metadata:
                c = case['calibration']
                c.update(width=width, direction=direction, takeoff_x=width/2-direction*90, finish_x=width-64 if direction == 1 else 64)
                c['actual_support_rect_xywh'][2] = width
                c['actual_enemy_center'][0] = width/2
            data['cases'].append(case)
    def change_restore(data, field, value):
        for frame in one(data, 'restored_pending_pulse_is_cancelled')['frames']:
            frame[field] = copy.deepcopy(value)
    def wrong_endpoint(data):
        case = one(data, 'width_560_dir_1')
        case['frames'][-1]['position'][0] = case['calibration']['takeoff_x']
    def wrong_landing(data):
        one(data, 'width_440_dir_-1')['frames'][-1]['grounded'] = False
    mutations.update({
        'review_001_erase_pause_inactive_save_duplicate_cases': missing_lifecycle,
        'review_001_erase_interrupt_warning_frames': erase_warning,
        'review_001_empty_restored_trace': empty_restore,
        'review_002_six_copies_one_width_direction': clone_calibration,
        'review_002_forge_unique_metadata_over_same_physical_run': lambda d: clone_calibration(d, True),
        'restore_serial_erased': lambda d: change_restore(d, 'serial', 0),
        'restore_time_frozen': lambda d: change_restore(d, 'time', 0),
        'restore_hp_disagrees_with_snapshot': lambda d: change_restore(d, 'enemy_hp', 2),
        'restore_mark_disagrees_with_snapshot': lambda d: change_restore(d, 'goal', [0, 0]),
        'duplicate_case_identity': lambda d: d['cases'].append(copy.deepcopy(d['cases'][0])),
        'wrong_real_calibration_endpoint': wrong_endpoint,
        'no_real_calibration_final_support': wrong_landing,
        'wrong_capture_scope': lambda d: d.update(scope='formal admitted region success'),
        'wrong_production_admission_claim': lambda d: d.update(production_pool=True),
        'undeclared_source_identity_in_capture': lambda d: d.update(source_commit='0'*40),
        'missing_actual_recovery_event': remove('real_projectile_interrupt', 'state'),
        'missing_actual_snapshot_pulse': remove('actual_stage_capture_and_ledger_roundtrip', 'pulse'),
    })
    if not historical_no_stun:
        def interrupt_frames(data):
            return one(data, 'real_projectile_interrupt')['frames']
        def first_stun_index(data):
            return next(i for i, f in enumerate(interrupt_frames(data)) if f['damage_stun_remaining'] > 0)
        def uncaused_stun(data):
            frames = one(data, 'stand_in_pulse_positive_damage')['frames']
            frames[10]['damage_stun_remaining'] = .12
        def epsilon_stun_without_damage(data):
            frames = one(data, 'solid_occlusion_negative')['frames']
            original_time = frames[0]['time']
            for frame in frames:
                frame['damage_stun_remaining'] = 1e-6
                frame['time'] = original_time
        def change_stun(data, offset, value):
            frames = interrupt_frames(data)
            index = first_stun_index(data)+offset
            frames[index]['damage_stun_remaining'] = value(frames, index)
        def freeze_after_stun(data):
            frames = interrupt_frames(data)
            start = first_stun_index(data)
            index = next(i for i in range(start+1, len(frames)) if frames[i-1]['damage_stun_remaining'] == 0)
            frames[index]['time'] = frames[index-1]['time']
        def advance_during_stun(data):
            frames = interrupt_frames(data); index = first_stun_index(data)+1
            frames[index]['time'] = frames[index-1]['time']+1/60
        def missing_stun(data):
            for frame in interrupt_frames(data): frame.pop('damage_stun_remaining')
        mutations.update({
            'current_frame_missing_original_hp_key': lambda d: interrupt_frames(d)[10].pop('enemy_hp'),
            'current_frame_invalid_original_hp_type': lambda d: interrupt_frames(d)[10].update(enemy_hp='3'),
            'current_frame_not_a_dictionary': lambda d: interrupt_frames(d).__setitem__(10, None),
            'current_capture_missing_actual_stun_trace': missing_stun,
            'current_capture_missing_feedback_identity': lambda d: one(d, 'real_projectile_interrupt').pop('damage_feedback'),
            'stun_configuration_differs_from_actual_resource': lambda d: one(d, 'real_projectile_interrupt')['damage_feedback'].update(enemy_knockback_seconds=9),
            'stun_without_actual_committed_enemy_damage': uncaused_stun,
            'epsilon_fake_stun_freezes_undamaged_actor': epsilon_stun_without_damage,
            'accepted_damage_stun_erased': lambda d: change_stun(d, 0, lambda f, i: 0),
            'stun_exceeds_actual_configured_duration': lambda d: change_stun(d, 0, lambda f, i: 9),
            'stun_timer_reset_without_new_damage': lambda d: change_stun(d, 1, lambda f, i: f[i-1]['damage_stun_remaining']),
            'stun_timer_ends_before_actual_duration': lambda d: change_stun(d, 1, lambda f, i: 0),
            'behavior_clock_advanced_during_actual_stun': advance_during_stun,
            'behavior_clock_frozen_after_stun_release': freeze_after_stun,
        })
    rejected = []
    for name, mutate in mutations.items():
        altered = copy.deepcopy(data)
        mutate(altered)
        try:
            validate_capture(altered, historical_no_stun=historical_no_stun)
        except ValueError:
            rejected.append(name)
        else:
            raise RuntimeError('Evidence validator accepted deliberate erasure: ' + name)
    return rejected

def provenance_tamper_checks(capture_bytes, report, runtime_bytes, expected_sources, expected_commit, *, historical_no_stun=False):
    """Wrong source/scope is rejected at the actual receipt-consuming boundary,
    not merely labelled unsupported by the capture-only helper.
    """
    mutations = {}
    def edit_report(key, value):
        def mutation(capture, receipt, runtime):
            receipt[key] = copy.deepcopy(value)
            return capture, receipt, runtime
        return mutation
    mutations['wrong_native_source_commit'] = edit_report('source_commit', '0'*40)
    mutations['wrong_native_source_before'] = edit_report('source_before', {name:'0'*64 for name in expected_sources})
    mutations['missing_native_source_after'] = edit_report('source_after', {})
    mutations['stale_native_assertion_count'] = edit_report('assertions', report['assertions']+1)
    mutations['failed_native_receipt_labelled_success'] = edit_report('status', 'failed')
    if not historical_no_stun:
        mutations['missing_actual_feedback_source_receipt'] = edit_report('damage_feedback_source_before', {})
        mutations['wrong_actual_feedback_source_receipt'] = edit_report('damage_feedback_source_after', {name:'0'*64 for name in DAMAGE_FEEDBACK_PATHS})
    def changed_capture(capture, receipt, runtime):
        return capture+b' ', receipt, runtime
    mutations['raw_capture_not_bound_to_receipt'] = changed_capture
    def changed_runtime(capture, receipt, runtime):
        return capture, receipt, runtime+b'old success residual\n'
    mutations['raw_native_log_not_bound_to_receipt'] = changed_runtime
    def forged_formal(capture, receipt, runtime):
        data = json.loads(capture)
        data.update(production_pool=True, scope='formally admitted region')
        capture = json.dumps(data).encode()
        receipt['capture_sha256'] = hashlib.sha256(capture).hexdigest()
        return capture, receipt, runtime
    mutations['rehashed_forged_formal_scope'] = forged_formal
    def absent_native(capture, receipt, runtime):
        runtime = b'PREVIOUS SUCCESS ONLY\n'
        receipt['runtime_log_sha256'] = hashlib.sha256(runtime).hexdigest()
        return capture, receipt, runtime
    mutations['rehashed_old_success_without_native_completion'] = absent_native
    refused = []
    for name, mutation in mutations.items():
        changed = mutation(capture_bytes, copy.deepcopy(report), runtime_bytes)
        try:
            validate_evidence(*changed, expected_sources, expected_commit, historical_no_stun=historical_no_stun)
        except ValueError:
            refused.append(name)
        else:
            raise RuntimeError('Complete receipt consumer accepted '+name)
    return refused


def recheck_existing(folder, source_archive, expected_commit):
    """Revalidate preserved native facts using the new acceptance consumer.
    This performs no engine work and does not relabel original evidence fresh.
    """
    folder, source_archive = Path(folder), Path(source_archive)
    report = {'status':'failed', 'scope':'Historical R1 native165 evidence revalidated by current R2 Python acceptance consumer; native not reexecuted, no movie/AI/art changes', 'native_reexecuted':False, 'current_acceptance_sources':sources(), 'source_archive_sha256':sha(source_archive), 'started_epoch':time.time()}
    try:
        native = json.loads((folder/'g1_report.json').read_text())
        capture_bytes = (folder/'g1_capture.json').read_bytes()
        runtime_bytes = (folder/'g1_runtime.log').read_bytes()
        with zipfile.ZipFile(source_archive) as archive:
            require(len(archive.namelist()) == len(set(archive.namelist())) and set(archive.namelist()) == set(SOURCES)|{'source_manifest.json'}, 'Historical source archive missing/duplicated actual dependencies')
            expected_sources = json.loads(archive.read('source_manifest.json'))['source_sha256']
            require(set(expected_sources) == set(SOURCES), 'Historical source manifest incomplete')
            require(all(hashlib.sha256(archive.read(name)).hexdigest() == digest for name, digest in expected_sources.items()), 'Historical source bytes do not match archived SHA')
        stats = validate_evidence(capture_bytes, native, runtime_bytes, expected_sources, expected_commit, historical_no_stun=True)
        data = json.loads(capture_bytes)
        content_refusals = tamper_checks(data, historical_no_stun=True)
        source_refusals = provenance_tamper_checks(capture_bytes, native, runtime_bytes, expected_sources, expected_commit, historical_no_stun=True)
        unchanged = [name for name in SOURCES if name != 'tools/run_root_bell_tests.py']
        require(all(sources()[name] == expected_sources[name] for name in unchanged), 'R2 unexpectedly changed gameplay/art/native producer; original native scope cannot be reused')
        report.update(status='passed', observed_native=stats, historical_native_sources=expected_sources, content_mutation_refusals=content_refusals, receipt_mutation_refusals=source_refusals, unchanged_native_art_dependencies=unchanged, original_capture_sha256=hashlib.sha256(capture_bytes).hexdigest(), original_report_sha256=sha(folder/'g1_report.json'), original_runtime_sha256=hashlib.sha256(runtime_bytes).hexdigest())
        print('ROOT BELL R2 PYTHON RECHECK: original native165 retained;',len(content_refusals),'content and',len(source_refusals),'receipt/scope negatives rejected; native_reexecuted=false')
        print('ROOT BELL UNIQUE OUTPUT:',OUT.relative_to(ROOT))
    finally:
        report['finished_epoch'] = time.time()
        (OUT/'recheck_report.json').write_text(json.dumps(report, indent=2)+'\n')


def movie():
    folder = OUT / 'movie'
    folder.mkdir(parents=True, exist_ok=False)
    xvfb = '/workspace/toolchains/xvfb/usr/bin/Xvfb'
    display_log = (folder / 'display.log').open('wb')
    display = subprocess.Popen([xvfb, '-displayfd', '1', '-screen', '0', '1280x720x24', '-nolisten', 'tcp', '-ac'], stdout=subprocess.PIPE, stderr=display_log)
    env = os.environ.copy()
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(display.stdout, selectors.EVENT_READ)
            if not selector.select(20):
                raise RuntimeError('Xvfb readiness timeout')
            number = display.stdout.readline().decode().strip()
            require(number.isdigit(), 'Invalid display number')
        env.update(DISPLAY=':' + number, LIBGL_ALWAYS_SOFTWARE='1', LP_NUM_THREADS='1')
        avi = folder / 'showcase.avi'
        command = ['bash', str(ROOT / 'tools/godot.sh'), '--path', str(ROOT), '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--fixed-fps', '60', '--write-movie', str(avi), '--script', 'tests/root_bell_runner.gd', '--', '--showcase', '--output-dir=res://' + str(OUT.relative_to(ROOT))]
        request = {'command': command, 'environment': {k: env.get(k) for k in ('DISPLAY', 'LIBGL_ALWAYS_SOFTWARE', 'LP_NUM_THREADS', 'GODOT_BIN')}, 'source_before': sources(), 'scope': 'one continuous actual-input fixture, not formal-route/visual/device admission', 'started_epoch': time.time()}
        (folder / 'request.json').write_text(json.dumps(request, indent=2) + '\n')
        with (folder / 'capture.log').open('w') as log:
            result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        output = (folder / 'capture.log').read_text()
        require(result.returncode == 0 and 'ERROR:' not in output and re.search(r'^ROOT BELL: [1-9]\d* assertions, 0 failures$', output, re.M), 'actual GPU movie runner failed; preserve original log')
        mp4 = folder / 'showcase.mp4'
        with (folder / 'encode.log').open('w') as log:
            subprocess.run(['flock', LOCK, 'ffmpeg', '-y', '-i', str(avi), '-c:v', 'libx264', '-crf', '20', '-pix_fmt', 'yuv420p', '-c:a', 'aac', str(mp4)], check=True, stdout=log, stderr=subprocess.STDOUT, timeout=120)
        media = json.loads(subprocess.check_output(['flock', LOCK, 'ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(mp4)], timeout=30))
        video = next(s for s in media['streams'] if s['codec_type'] == 'video')
        audio = next(s for s in media['streams'] if s['codec_type'] == 'audio')
        require(video['avg_frame_rate'] == '60/1' and (video['width'], video['height']) == (1280, 720), 'wrong video format')
        require(int(audio['sample_rate']) == 48000 and audio['channels'] == 2, 'wrong audio format')
        require(sources() == request['source_before'], 'source drift during movie')
        request.update(status='captured', source_after=sources(), finished_epoch=time.time(), exit_code=0, media=media, movie_sha256=sha(mp4), trace_sha256=sha(OUT/'showcase.json'))
        (folder / 'receipt.json').write_text(json.dumps(request, indent=2) + '\n')
        # Keep the original AVI as local evidence; parent decides archival size.
        print('ROOT BELL MOVIE: actual 1280x720 60FPS stereo48k fixture; art/audio judgment unverified')
    finally:
        display.terminate()
        try:
            display.wait(timeout=5)
        except subprocess.TimeoutExpired:
            display.kill()
            display.wait(timeout=5)
        display_log.close()


def reserve_output(target):
    target = Path(target).resolve()
    require(target.is_relative_to(BASE) and target != BASE, 'Output must be a new child of build/root_bell')
    require(not target.exists(), 'Output already exists; all earlier success/failure artifacts are retained')
    target.mkdir(parents=True, exist_ok=False)
    return target


def output_policy_tests():
    folder = BASE / 'output_policy' / str(time.time_ns())
    first = reserve_output(folder / 'used')
    stale = first / 'report.json'
    stale.write_text('{"status":"passed","scope":"deliberately forged stale success negative fixture"}\n')
    before = stale.read_bytes()
    refused = []
    for label, target in [('repeated_run_directory', first), ('stale_success_directory', first), ('base_directory', BASE), ('source_directory', ROOT/'scripts')]:
        try:
            reserve_output(target)
        except ValueError:
            refused.append(label)
        else:
            raise RuntimeError('Output guard accepted ' + label)
    require(stale.read_bytes() == before, 'Rejected repeated run mutated old success bytes')
    second = reserve_output(folder / 'distinct')
    require(second != first and not (second/'report.json').exists(), 'New invocation inherited old success')
    record = {'refused': refused, 'distinct_new_directory': str(second.relative_to(ROOT)), 'stale_success_unchanged': True, 'scope': 'pure output-policy negative fixtures; no gameplay success claim'}
    (folder / 'result.json').write_text(json.dumps(record, indent=2) + '\n')
    return record


def strict_formal_python_checks():
    """Run the real verifier test CLI; synthetic transport is never native proof."""
    folder = OUT / 'strict_formal_python'
    require(not folder.exists(), 'Strict verifier output already exists')
    command = [sys.executable, 'tools/test_root_bell_formal_verifier.py',
               '--output-dir', str(folder.relative_to(ROOT))]
    started = time.time()
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=90)
    log = OUT / 'strict_formal_python.log'
    log.write_text(result.stdout + result.stderr)
    require(result.returncode == 0 and re.search(
        r'^STRICT FORMAL PYTHON: original27 \+ coherent full-main 9 refusals; no native$',
        log.read_text(), re.M), 'Strict formal Python CLI failed or lacks completion marker')
    report_path = folder / 'report.json'
    require(report_path.is_file(), 'Strict formal Python CLI lacks its invocation-bound report')
    data = json.loads(report_path.read_text())
    require(data.get('status') == 'passed' and data.get('scope') ==
            'Actual Python main negatives with explicitly synthetic transport, NO NATIVE/MOVIE execution',
            'Strict formal Python report status/scope disagrees')
    require(len(data.get('original27_refusals', [])) == 27 and
            len(data.get('coherent_fullmain_refusals', {})) == 9 and
            all(row.get('refused') is True for row in data['coherent_fullmain_refusals'].values()),
            'Strict formal Python report omitted original27 or coherent full-main9 refusals')
    require(data.get('current_verifier_sha256') == sha(ROOT/'tools/run_root_bell_formal.py') and
            data.get('current_test_sha256') == sha(ROOT/'tools/test_root_bell_formal_verifier.py'),
            'Strict formal Python report belongs to different verifier bytes')
    return {'command':command, 'exit_code':result.returncode,
            'started_epoch':started, 'finished_epoch':time.time(),
            'report':str(report_path.relative_to(ROOT)), 'report_sha256':sha(report_path),
            'log':str(log.relative_to(ROOT)), 'log_sha256':sha(log),
            'verifier_sha256':data['current_verifier_sha256'],
            'test_sha256':data['current_test_sha256'],
            'native_reexecuted':False, 'scope':data['scope']}


def main():
    global OUT
    parser = argparse.ArgumentParser()
    parser.add_argument('--recheck-existing', help='Pure Python recheck of preserved g1_capture/report/runtime, no native replay')
    parser.add_argument('--source-archive', help='Exact original source ZIP for --recheck-existing')
    parser.add_argument('--native-source-commit', help='Explicit expected historical commit (defaults to current repository baseline)')
    parser.add_argument('--movie', action='store_true', help='Record separate single-fight animation fixture after tests')
    parser.add_argument('--movie-only', action='store_true', help='Record fixture on already-imported source; no technical rerun')
    parser.add_argument('--output-dir', help='Explicit NEW directory below build/root_bell; existing paths are always refused')
    args = parser.parse_args()
    BASE.mkdir(parents=True, exist_ok=True)
    policy_result = output_policy_tests()
    OUT = reserve_output(args.output_dir if args.output_dir else BASE/'runs'/str(time.time_ns()))
    (OUT/'invocation.json').write_text(json.dumps({'created_epoch':time.time(), 'output_policy':policy_result, 'scope':'new invocation; no previous result is reused'}, indent=2)+'\n')
    if args.recheck_existing:
        require(args.source_archive is not None and not args.movie and not args.movie_only, 'Historical recheck needs exact source archive and no native movie mode')
        expected_commit = args.native_source_commit or subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
        recheck_existing(args.recheck_existing, args.source_archive, expected_commit)
        return
    if args.movie_only:
        movie()
        return
    report = {'output_policy': policy_result, 'status': 'failed', 'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(), 'source_before': sources(), 'damage_feedback_source_before': damage_feedback_sources(), 'scope': 'G0/G1 actual Motor/collision/projectile/phase/snapshot/placement tests; promotion gated; no independent/device/player approval', 'started_epoch': time.time()}
    try:
        report['strict_formal_python'] = strict_formal_python_checks()
        output = run_engine(['--headless', '--path', '.', '--editor', '--quit'], 120)
        (OUT / 'import.log').write_text(output)
        command = ['--headless', '--path', '.', '--fixed-fps', '60', '--script', 'tests/root_bell_runner.gd', '--', '--output-dir=res://' + str(OUT.relative_to(ROOT))]
        output = run_engine(command, 120)
        (OUT / 'runtime.log').write_text(output)
        match = re.search(r'^ROOT BELL: ([1-9]\d*) assertions, 0 failures$', output, re.M)
        require(match is not None and 'ERROR:' not in output, 'Missing root-bell completion or engine ERROR')
        capture = json.loads((OUT / 'capture.json').read_text())
        validate_capture(capture)
        report['validator_erasure_rejections'] = tamper_checks(capture)
        require(sources() == report['source_before'], 'source drift during tests')
        strict = report['strict_formal_python']
        require(strict['verifier_sha256'] == sha(ROOT/'tools/run_root_bell_formal.py') and
                strict['test_sha256'] == sha(ROOT/'tools/test_root_bell_formal_verifier.py'),
                'Strict formal Python source drift during native tests')
        native_receipt = dict(report, status='passed', assertions=int(match[1]), source_after=sources(), damage_feedback_source_after=damage_feedback_sources(), capture_sha256=sha(OUT/'capture.json'), runtime_log_sha256=sha(OUT/'runtime.log'))
        validate_evidence((OUT/'capture.json').read_bytes(), native_receipt, (OUT/'runtime.log').read_bytes(), sources(), native_receipt['source_commit'])
        native_receipt['receipt_mutation_refusals'] = provenance_tamper_checks((OUT/'capture.json').read_bytes(), native_receipt, (OUT/'runtime.log').read_bytes(), sources(), native_receipt['source_commit'])
        report.update(native_receipt)
        print('PASS: root bell actual fixtures and evidence erasure/matrix/lifecycle and receipt/scope rejections; promotion remains gated')
        print('ROOT BELL UNIQUE OUTPUT:', OUT.relative_to(ROOT))
    finally:
        report['finished_epoch'] = time.time()
        (OUT / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    if args.movie:
        movie()

if __name__ == '__main__':
    main()
