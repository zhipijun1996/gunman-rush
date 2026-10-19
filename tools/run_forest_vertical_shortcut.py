"""Real-input regression for the proved internal catch-to-crown no-H shortcut.

A blocked result covers this finite strategy only, and requires its complete real
jump/recoil attempt followed by a stable live recovery. It is not an impossibility
proof for all strategies. The original successful baseline remains archived.
"""
import argparse
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import time

import run_forest_depth_region as REGION
import run_forest_directional_golden as PHYSICS

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = 'tests/forest_vertical_shortcut_runner.gd'
RETRY_SCRIPT = 'tests/forest_root_retry_runner.gd'


def validate(data, expect='blocked'):
    errors = []
    def require(value, label):
        if not value:
            errors.append(label)
    frames = data.get('frames', [])
    events = data.get('events', [])
    requests = data.get('requests', [])
    manifest = data.get('manifest', {})
    start = data.get('probe_started', -1)
    require(data.get('scope') == ('real_Motor_deep_H_recovery_after_real_prefix' if expect == 'recovery' else 'real_Motor_internal_noH_shortcut_after_real_HHRH_prefix'), 'wrong_scope')
    require(data.get('manual_motor_step') is False and data.get('position_or_resource_injection') is False, 'privileged_motion_or_resources')
    require(data.get('failures') == [] and data.get('audio_released') is True, 'native_failure_or_cleanup')
    require(manifest.get('layout_version') == 'forest-woven-trunk-v12', 'wrong_layout')
    require(start > 0 and len(frames) > start, 'missing_actual_prefix')
    require(bool(frames) and all(f.get('tick') == i + 1 and f.get('motor_steps') == 1 for i, f in enumerate(frames)), 'noncontinuous_unique_motor')
    require([x.get('edge_id') for x in data.get('completed_legs', [])] == ['root_spiral_approach', 'root_spiral_flight'], 'prefix_not_actual_first_flight')
    prefix = [e for e in events if e.get('tick', 0) <= start and e.get('kind') in ['hook_contact_kick', 'shot_fired']]
    require([e.get('kind') for e in prefix] == ['hook_contact_kick', 'hook_contact_kick', 'shot_fired', 'hook_contact_kick'], 'prefix_not_HHRH')
    require([e.get('target') for e in prefix if e.get('kind') == 'hook_contact_kick'] == ['root_spiral__spiral_lower', 'root_spiral__spiral_middle', 'root_spiral__spiral_crown'], 'prefix_H_targets_wrong')
    if expect != 'recovery':
        require(not any(x.get('kind') == 'grapple' and x.get('tick', 0) > start for x in requests), 'postprefix_H_request')
        require(not any(x.get('kind') == 'hook_contact_kick' and x.get('tick', 0) > start for x in events), 'postprefix_H_contact')
    later = [x for x in events if x.get('tick', 0) > start]
    jumps = [x for x in later if x.get('kind') == 'jumped']
    require(len(jumps) == 1, 'postprefix_jump_program_incomplete')
    shots = [x for x in later if x.get('kind') == 'shot_fired']
    require(len(shots) == 1 and shots[0].get('aim') == [0.0, 1.0], 'postprefix_actual_UPR_missing')
    initial = data.get('initial_snapshot', {})
    final = data.get('final_snapshot', {})
    require(initial.get('config') == final.get('config'), 'runtime_config_changed')
    require(all(initial.get(k) == final.get(k) for k in ['weapon', 'tier', 'hook_enabled', 'double_enabled', 'wall_enabled']), 'capability_changed')
    require(initial.get('hook_enabled') is True and final.get('health', 0) > 0, 'not_grapple_granted_or_dead')
    require(bool(frames) and all(0 <= f.get('shots', -1) <= 2 and 0 <= f.get('energy', -1) <= 100 and f.get('health', 0) > 0 for f in frames), 'resource_bounds_or_death')
    # A landing can restore charges; airborne restoration needs the real
    # controlled shot direction hits no Damageable; every purported credit is
    # therefore rejected, including forged fired_airborne flags.
    shot_ticks = {e.get('tick') for e in events if e.get('kind') == 'shot_fired'}
    require(not any(e.get('kind') == 'actual_shot_energy_credit' for e in events), 'unexpected_hit_credit_in_controlled_no_hit_strategy')
    for old, frame in zip(frames, frames[1:]):
        delta = frame.get('shots', 0)-old.get('shots', 0)
        if delta < 0:
            require(delta == -1 and frame.get('tick') in shot_ticks, 'charge_spent_without_actual_shot')
        if delta > 0:
            require(frame.get('grounded') or old.get('grounded'), 'air_charge_refill_in_no_hit_strategy')
    supports = {p['id']: p for p in manifest.get('platforms', [])}
    def full(f, support_id):
        p = supports.get(support_id)
        if not p or not f.get('grounded') or support_id not in f.get('supports', []):
            return False
        x, y = f['position']; rx, ry, rw, _ = p['rect']
        return x-12 >= rx-.1 and x+12 <= rx+rw+.1 and abs(y+18-ry) < 1
    count = 0
    reached = False
    for f in frames:
        count = count+1 if full(f, 'middle_fork__crown') else 0
        reached |= count >= 12
    tuning, hook_numbers = PHYSICS._runtime_numbers()
    maximum_step = max(hook_numbers['pull_speed'], tuning['shot_burst_speed'], math.hypot(tuning['ground_speed'], tuning['max_normal_fall_speed'])) / tuning['physics_hz'] + .3
    require(all(math.dist(a['position'], b['position']) <= maximum_step for a, b in zip(frames, frames[1:])), 'unexplained_body_displacement')
    for frame in frames:
        x, y = frame['position']
        if expect == 'recovery':
            require(isinstance(frame.get('body'), list) and len(frame['body']) == 4 and frame['body'][2:] == [24, 36] and math.dist(frame['body'][:2], [x-12, y-18]) < .001, 'body_geometry_not_actual_position')
            for danger in manifest.get('dangers', []):
                px, py, width, height = danger
                require(not(min(x+12, px+width)-max(x-12, px) > .01 and min(y+18, py+height)-max(y-18, py) > .01), 'recovery_body_crossed_actual_thorns')
        for platform in supports.values():
            if platform.get('one_way', False): continue
            px, py, width, height = platform['rect']
            require(not(min(x+12, px+width)-max(x-12, px) > .2 and min(y+18, py+height)-max(y-18, py) > .2), 'body_inside_solid')
    if expect == 'blocked':
        require(data.get('shortcut_reached') is False and not reached, 'shortcut_still_physically_reached')
        require(data.get('negative_recovered') is True, 'native_negative_not_completed')
        require(len(frames) >= 12 and all(full(f, 'thorn_mouth__recovery') for f in frames[-12:]), 'negative_not_real_fullbody_recovery12')
        require(any(e.get('kind') == 'shortcut_program_finished_on_real_recovery' for e in events), 'negative_completion_event_missing')
    elif expect == 'recovery':
        require(data.get('recovery_reached') is True, 'actual_recovery_not_completed')
        require(len(frames) >= 12 and all(full(f, 'thorn_mouth__entry') for f in frames[-12:]), 'recovery_not_actual_mouth_fullbody12')
        require(any(full(f, 'thorn_mouth__recovery') and f.get('tick', 0) > start for f in frames), 'recovery_never_landed_actual_deep_catch')
        target_ids = ['thorn_retry_low_ring', 'thorn_retry_high_ring', 'thorn_retry_exit_ring']
        hangs = [e for e in later if e.get('kind') == 'hook_hang']
        require([e.get('target') for e in hangs] == target_ids, 'recovery_actual_hang_targets_wrong')
        require([e.get('kind') for e in later if e.get('kind') in ['hook_hang', 'shot_fired']] == ['hook_hang', 'hook_hang', 'hook_hang', 'shot_fired'], 'recovery_accepted_HHHR_order_wrong')
        require(len([r for r in requests if r.get('kind') == 'grapple' and r.get('tick', 0) > start]) == 3, 'recovery_H_request_program_wrong')
        anchors = {a['id']: a for a in manifest.get('hook_anchors', [])}
        by_tick = {f['tick']: f for f in frames}
        for target in target_ids:
            require(target in anchors and anchors[target].get('hang_enabled') is True, 'missing_manifest_hanging_anchor/'+target)
        for index, event in enumerate(hangs):
            until = hangs[index+1]['tick'] if index+1 < len(hangs) else frames[-1]['tick']+1
            interval = [f for f in frames if event['tick'] <= f.get('tick', -1) < until]
            held = 0; maximum = 0
            for f in interval:
                held = held+1 if f.get('hook_state') == 'hook_hang' and not f.get('grounded') else 0
                maximum = max(maximum, held)
            require(maximum >= 12, 'recovery_actual_hang_not_held12/'+str(event.get('target')))
            preceding = [e for e in later if e.get('kind') in ['hook_cast', 'hook_fly', 'hook_pull'] and e.get('tick', 0) < event['tick'] and (index == 0 or e.get('tick', 0) > hangs[index-1]['tick'])]
            require([e.get('kind') for e in preceding] == ['hook_cast', 'hook_fly', 'hook_pull'], 'recovery_H_state_sequence_missing')
            require(bool(preceding) and preceding[-1].get('target') == event.get('target'), 'recovery_pull_target_differs_from_hang')
            target = event.get('target'); anchor = anchors.get(target)
            if anchor and len(preceding) == 3:
                chain = preceding+[event]
                requests_at_cast = [r for r in requests if r.get('kind') == 'grapple' and r.get('tick') == chain[0]['tick'] and r.get('queued') is True]
                require(len(requests_at_cast) == 1, 'recovery_cast_not_bound_to_queued_request')
                before = by_tick.get(chain[0]['tick']-1, {})
                if len(requests_at_cast) == 1 and before.get('position'):
                    origin = [before['position'][0], before['position'][1]-6]
                    actual_origin = by_tick.get(chain[0]['tick'], {}).get('hook_start', [1e9, 1e9])
                    require(math.dist(actual_origin, origin) <= .01, 'recovery_hook_start_not_actual_cast_origin')
                    require(math.dist(preceding[-1].get('hook_tip', [1e9, 1e9]), actual_origin) <= hook_numbers['range']+.01, 'recovery_actual_contact_beyond_real_range')
                    dx, dy = anchor['position'][0]-origin[0], anchor['position'][1]-origin[1]
                    length = math.hypot(dx, dy)
                    require(0 < length <= hook_numbers['range']+12.1, 'recovery_request_target_outside_real_range')
                    require(length > 0 and math.dist(requests_at_cast[0].get('aim', [1e9, 1e9]), [dx/length, dy/length]) < .001, 'recovery_request_not_aimed_at_manifest_target')
                for left, right in zip(chain, chain[1:]):
                    require(left['tick'] < right['tick'] and all(by_tick.get(t, {}).get('hook_state') == left['kind'] for t in range(left['tick'], right['tick'])), 'recovery_H_live_state_interval_missing')
                hang_frames = []
                for f in interval:
                    if f.get('hook_state') == 'hook_hang':hang_frames.append(f)
                    elif hang_frames:break
                if hang_frames:
                    first = hang_frames[0]
                    for f in hang_frames:
                        tip = f.get('hook_tip', [1e9, 1e9])
                        require(math.dist(tip, anchor['position']) <= 12.2, 'recovery_hang_tip_not_on_actual_ring')
                        require(math.dist(f['position'], tip) <= hook_numbers['stop']+.2, 'recovery_hang_body_not_at_actual_contact')
                        require(math.dist(f['position'], first['position']) <= .2 and math.dist(tip, first.get('hook_tip', [1e9, 1e9])) <= .2, 'recovery_static_hang_moved_or_teleported')

        require(any(e.get('kind') == 'retry_actual_mouth_arrival' for e in later), 'actual_mouth_arrival_event_missing')
    else:
        require(data.get('shortcut_reached') is True and reached, 'baseline_not_physically_reached')
        require(len(frames) >= 12 and all(full(f, 'middle_fork__crown') for f in frames[-12:]), 'baseline_not_stable_crown12')
    return errors


def validate_recovery(data):
    return validate(data, 'recovery')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--expect', choices=['blocked', 'reached'], default='blocked')
    parser.add_argument('--scenario', choices=['shortcut', 'recovery', 'all'], default='shortcut')
    parser.add_argument('--validate-only', type=Path)
    args = parser.parse_args()
    expected = 'recovery' if args.scenario == 'recovery' else args.expect
    script = RETRY_SCRIPT if args.scenario == 'recovery' else SCRIPT
    if args.scenario == 'all' and (args.validate_only or args.expect != 'blocked'):
        parser.error('--scenario all is exactly blocked shortcut plus recovery, without --validate-only')
    if args.validate_only:
        errors = validate(json.loads(args.validate_only.read_text()), expected)
        print(json.dumps({'errors': errors})); return int(bool(errors))
    output = args.output.resolve()
    if not output.is_relative_to(ROOT/'build') or output.exists():
        parser.error('fresh output below repository build required')
    output.mkdir(parents=True)
    report = {'status': 'running', 'scope': 'one_proved_internal_noH_strategy_not_all_shortcuts', 'expect': expected, 'scenario': args.scenario}
    def save():
        (output/'receipt.json').write_text(json.dumps(report, indent=2)+'\n')
    save()
    lock = ROOT/'build/verification/engine.lock'; lock.parent.mkdir(parents=True, exist_ok=True)
    with lock.open('a') as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        report['source_before'] = REGION.inventory()
        report['source_at_execution'] = report['source_before']
        report['source_guard_scope'] = 'after_engine_lock_acquired_through_native_exit'
        import_argv = ['bash', 'tools/godot.sh', '--headless', '--path', '.', '--editor', '--quit']
        import_log = output/'import.log'
        try:
            with import_log.open('w') as stream:
                imported = subprocess.run(import_argv, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=90)
            after_import = REGION.inventory()
            report['import'] = {'argv': import_argv, 'exit_code': imported.returncode, 'timeout_seconds': 90, 'log_sha256': hashlib.sha256(import_log.read_bytes()).hexdigest()}
            report['import_source_guard'] = REGION.import_inventory_guard(report['source_before'], after_import)
            if imported.returncode or REGION.ERRORS.search(import_log.read_text()) or not report['import_source_guard']['passed']:
                report.update(status='failed', errors=['strict_import_failed']); save(); print('FOREST VERTICAL SHORTCUT: failed import', output); return 1
            report['source_at_execution'] = after_import
        except subprocess.TimeoutExpired:
            report.update(status='failed', errors=['import_90s_timeout']); save(); return 1
        cases = [('shortcut', 'blocked', SCRIPT), ('recovery', 'recovery', RETRY_SCRIPT)] if args.scenario == 'all' else [(args.scenario, expected, script)]
        report['runs'] = []
        errors = []
        for scenario, expected_case, script_case in cases:
            case_output = output/scenario if args.scenario == 'all' else output
            case_output.mkdir(exist_ok=True)
            capture = case_output/'capture.json'; log = case_output/'native.log'
            argv = ['bash', 'tools/godot.sh', '--headless', '--fixed-fps', '60', '--path', '.', '--script', script_case, '--', '--output='+str(capture)]
            row = {'scenario': scenario, 'expect': expected_case, 'argv': argv, 'timeout_seconds': 90}
            save(); start = time.monotonic()
            env = {**os.environ, 'GUNMAN_DATA_HOME': str(case_output/'user'), 'XDG_CONFIG_HOME': str(case_output/'config'), 'XDG_CACHE_HOME': str(case_output/'cache'), 'LP_NUM_THREADS': '1'}
            case_errors = []
            try:
                with log.open('w') as stream:
                    result = subprocess.run(argv, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=90)
                text = log.read_text()
                row['exit_code'] = result.returncode
                if result.returncode != 0: case_errors.append('native_nonzero')
                if REGION.ERRORS.search(text): case_errors.append('native_script_error_or_leak')
                marker = 'ROOT RETRY' if scenario == 'recovery' else 'SHORTCUT'
                if not re.search(r'^FOREST '+marker+r': reached=(?:true|false) failures=\[\] frames=[1-9]\d*$', text, re.M): case_errors.append('native_completion_missing')
                if capture.exists():
                    data = json.loads(capture.read_text()); case_errors.extend(validate(data, expected_case))
                    source_hashes = data.get('source_hashes', {})
                    for path, expected_sha in source_hashes.items():
                        actual_path = ROOT/path.removeprefix('res://')
                        if not actual_path.is_file() or hashlib.sha256(actual_path.read_bytes()).hexdigest() != expected_sha:
                            case_errors.append('native_source_hash_mismatch/'+path)
                    if 'res://'+script_case not in source_hashes: case_errors.append('actual_runner_source_missing')
                    row['capture_sha256'] = hashlib.sha256(capture.read_bytes()).hexdigest()
                else: case_errors.append('capture_absent')
            except subprocess.TimeoutExpired:
                case_errors.append('native_90s_timeout')
            except (OSError, ValueError, TypeError, KeyError) as exc:
                case_errors.append(type(exc).__name__+': '+str(exc))
            row.update(seconds=time.monotonic()-start, errors=case_errors, status='failed' if case_errors else 'passed')
            row['log_sha256'] = hashlib.sha256(log.read_bytes()).hexdigest()
            report['runs'].append(row)
            errors.extend(scenario+'/'+error for error in case_errors)
            save()
            if case_errors: break
        report['source_after'] = REGION.inventory()
        if report['source_at_execution'] != report['source_after']:
            errors.append('source_changed_during_capture')
        if len(report['runs']) != len(cases): errors.append('finite_case_set_incomplete')
        report['errors'] = errors
        report['status'] = 'passed' if not errors else 'failed'
        save()
    print('FOREST VERTICAL SHORTCUT:', report['status'])
    return int(bool(errors))


if __name__ == '__main__':
    raise SystemExit(main())
