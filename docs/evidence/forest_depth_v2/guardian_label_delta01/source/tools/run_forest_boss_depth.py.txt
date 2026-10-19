"""Isolated guardian v2: normal inputs, physical weapon counter, static terrain, strict exit."""
import argparse
import contextlib
import hashlib
import json
from pathlib import Path
import re
import time
from run_tests import run_engine
import level_formal

ROOT = Path(__file__).resolve().parent.parent


def validate(data):
    if data.get('failures') != 0 or data.get('assertions', 0) < 50:
        raise ValueError('All revised guardian golden assertions must complete')
    if data.get('version') != 'forest-guardian-duel-arena-v4':
        raise ValueError('Exact static arena content version required')
    if data.get('mechanic_version') != 'guardian-two-action-cycle-v6':
        raise ValueError('Exact actual-arrival counter mechanic version required')
    expected = {'normal_core_motion_terrain_pause_cancel', 'static_side_branch_contract', 'stationary_physical_impact', 'solid_moving_bell_block_and_H', 'actual_phase2_restore'}
    if len(data.get('cases', [])) != len(expected) or {r.get('id') for r in data['cases']} != expected:
        raise ValueError('Both causal action goldens required')
    events = data.get('events', [])
    first = data['cases'][0]
    ordinary = [e for e in events if first['start_tick'] <= e.get('tick', -1) <= first['end_tick']]
    if not any(e.get('event') == 'body_collision' and e.get('kind') == 'terrain' for e in ordinary):
        raise ValueError('Actual ordinary terrain collider result required')
    if not any(e.get('event') == 'policy_result' and e.get('target') == 'boss'
               and str(e.get('source', '')).startswith('player_projectile:') for e in ordinary):
        raise ValueError('Normal core damage without root key required')
    stationary = next(row for row in data['cases'] if row['id'] == 'stationary_physical_impact')
    if not stationary.get('collision_found') or stationary['initial_player_hp'] - stationary['player_hp'] != 1:
        raise ValueError('A real stationary player collision must cause one normal policy damage')
    bell = next(row for row in data['cases'] if row['id'] == 'solid_moving_bell_block_and_H')
    if not bell.get('projectile_block') or not bell.get('mobile_hook') or not bell.get('actual_arrival'):
        raise ValueError('Actual projectile collision and actual moving-bell H required')
    bell_events = [e for e in events if bell['start_tick'] <= e.get('tick', -1) <= bell['end_tick']]
    if not any(e.get('event') == 'actual_bell_projectile_block' for e in bell_events):
        raise ValueError('Real projectile impact queried against actual bell body required')
    if not any(e.get('bell_target') is True for e in bell_events):
        raise ValueError('Actual H contact must target the moving bell, not a fixed ring')
    restored = next(row for row in data['cases'] if row['id'] == 'actual_phase2_restore')
    if restored.get('saved_phase') != 2 or restored.get('restored_phase') != 2 or restored.get('boss_hp', 0) <= 0:
        raise ValueError('Actual live phase2 save/restore required, not default phase1')
    branches = next(row for row in data['cases'] if row['id'] == 'static_side_branch_contract')
    if branches.get('policy_targets') != ['boss', 'player'] or len(branches.get('branches', [])) != 2:
        raise ValueError('Retired root mechanic must not leave extra Health policy targets')
    if any(row.get('damageable') is not False or row.get('one_way') is not True or row.get('collision_layer', 0) == 0 for row in branches['branches']):
        raise ValueError('Both static branches must retain actual terrain and no hidden damage gate')
    for phase in (e for e in events if e.get('event') == 'duel_phase_changed' and e.get('phase') == 2):
        completed = [e for e in events if e.get('fixture') == phase.get('fixture')
                     and e.get('event') in {'body_collision', 'body_flight_completed'}
                     and e.get('phase') == 1 and e.get('completed_body_cycles', 0) > 0
                     and e.get('tick', -1) <= phase.get('tick', -1)]
        if phase.get('completed_body_cycles', 0) <= 0 or not any(
                launch.get('event') == 'body_launch' and launch.get('phase') == 1
                and launch.get('fixture') == phase.get('fixture')
                and launch.get('attack_id') == finished.get('attack_id')
                and launch.get('tick', -1) <= finished.get('tick', -1)
                for finished in completed for launch in events):
            raise ValueError('Phase2 needs a real independent Body launch and physical completion in this fixture')
    samples = data.get('samples', [])
    if len(samples) < 100:
        raise ValueError('Per-frame real body/player trace required')
    if not any(s.get('phase') == 2 and s.get('mode') == 'pursuit_flight' and s.get('bell_state') in {'outbound', 'returning'} and s.get('bell_moved') is True for s in samples):
        raise ValueError('Real phase2 moving-body / in-flight-bell overlap required')
    validate_bell_physics(data)
    previous = {}
    motion = False
    for sample in samples:
        key = sample['fixture']
        if key in previous:
            old = previous[key]
            delta = sample['boss_steps'] - old['boss_steps']
            if delta < 0 or delta > sample['tick'] - old['tick']:
                raise ValueError('Boss must perform at most one physical sweep per tick')
            motion |= sample['boss_p'] != old['boss_p']
        previous[key] = sample
    if not motion:
        raise ValueError('Boss body must actually move')
    rows = data.get('comparisons', [])
    strategies = {'H_pure_shift', 'H', 'ground_walk_shoot', 'jump_no_H', 'jump_peek_no_H', 'stationary_shoot', 'evade_then_stationary'}
    if len(rows) != len(strategies) or {r.get('id') for r in rows} != strategies:
        raise ValueError('All same-content cheap strategy comparisons required')
    if len({(r.get('initial_boss_hp'), r.get('initial_player_hp'), r.get('initial_stamina')) for r in rows}) != 1:
        raise ValueError('Identical real initial resources required')
    arena = data.get('arena', [])
    if len(arena) != 4:
        raise ValueError('Actual factory arena required')
    for row in rows:
        for sample in samples:
            if row['start_tick'] <= sample['tick'] <= row['end_tick'] and sample['boss_hp'] > 0:
                x, y = sample['p']
                if x < arena[0] + 8 or x > arena[0] + arena[2] - 8 or y > arena[1] + arena[3] + 3:
                    raise ValueError('Alive-boss strategy left physical sealed arena or fell below floor')
        if not row.get('initially_sealed') or row.get('seal_close_count') != 1 or row.get('stop_reason') == 'escaped_arena':
            raise ValueError('Real production seal and legal arena recovery required')
        bounded = events[row['event_start']:row['event_end']]
        hits = [e for e in bounded if e.get('event') == 'policy_result' and e.get('target') == 'boss']
        hooks = [e for e in bounded if e.get('event') == 'hook_contact']
        if len(hits) != row['boss_hits'] or len(hooks) != row['hook_contacts']:
            raise ValueError('Strategy summary must match actual bounded events')
        floor_center_y = arena[1] + arena[3] - 48  # Actual frozen Guardian collider height is 96.
        actual_floor_travel = 0
        for launch in (e for e in bounded if e.get('event') == 'body_launch' and e.get('phase') == 2):
            if abs(launch['from'][1] - floor_center_y) >= 3:
                continue
            collisions = [e for e in bounded if e.get('event') == 'body_collision' and e.get('attack_id') == launch.get('attack_id')]
            if collisions:
                actual_floor_travel = max(actual_floor_travel, abs(collisions[0]['body_position'][0] - launch['from'][0]))
        if abs(row.get('max_phase2_floor_travel', -1) - actual_floor_travel) > 0.01:
            raise ValueError('Body route summary must match actual bounded launch/collision positions')
        counter_hits = [e for e in hits if str(e.get('source', '')).startswith('guardian_bell_counter:')]
        if len(counter_hits) != row.get('counter_hits') or sum(e['amount'] for e in counter_hits) != row.get('counter_damage'):
            raise ValueError('Counter summary must match committed policy results')
        if row['id'] in {'H', 'H_pure_shift'}:
            if row.get('defeats') != 1 or row.get('boss_hp') != 0 or row.get('player_hp', 0) <= 0:
                raise ValueError('Complete actual H fight and pure-shift ablation required')
            if not row.get('offensive_arrived') or not any(e.get('bell_target') is True for e in hooks):
                raise ValueError('H profile must actually reach the moving weapon')
            if row['id'] == 'H' and (not row.get('counter_enabled') or not counter_hits):
                raise ValueError('Counter hypothesis requires a committed physical weapon counter')
            if row['id'] == 'H_pure_shift' and (row.get('counter_enabled') or counter_hits):
                raise ValueError('Pure-shift resource ablation must have no counter damage')
        elif hooks:
            raise ValueError('No-H strategies cannot contain hook contacts')
        # Fast legal kills may skip teaching cycles; record rather than prohibit them.
        covered = (row.get('bell_launches', 0) >= 2 and row.get('body_launches', 0) >= 2
                   and row.get('phase1_body_launches', 0) > 0 and row.get('phase2_body_launches', 0) > 0
                   and row.get('phase2_overlap_frames', 0) > 0)
        if row.get('learning_cycle_covered') is not covered:
            raise ValueError('Learning-cycle summary must reflect observed events')
    validate_counter_causality(events)
    if not any(row.get('max_phase2_floor_travel', 0) > 200 for row in rows):
        raise ValueError('Actual phase2 floor-to-new-position pursuit must travel, not count launches into a branch wall')
    for collision in (e for e in events if e.get('event') == 'body_collision'):
        if str(collision.get('platform_id', '')).startswith('guardian_branch_') and collision.get('normal', [0,0])[1] > -0.5:
            raise ValueError('Ordinary one-way side branches cannot stop an ascending Body against a side/bottom wall')
    # This checks the evidence pipeline, not a claim H wins or the design is fun.



def validate_counter_causality(events):
    committed = set()
    for result in (e for e in events if e.get('event') == 'policy_result'
                   and str(e.get('source', '')).startswith('guardian_bell_counter:')):
        event_id = result.get('id')
        if not event_id or event_id in committed or result.get('target') != 'boss' or result.get('amount', 0) <= 0:
            raise ValueError('A counter commits once to the existing Boss policy target')
        committed.add(event_id)
        contacts = [e for e in events if e.get('event') == 'bell_counter_owner_contact'
                    and e.get('event_id') == event_id and e.get('tick', -1) <= result.get('tick', -1)
                    and e.get('contact_kind') in {'kinematic_sweep', 'actual_shape_overlap'}
                    and e.get('physics_frame') == result.get('physics_frame')]
        if len(contacts) != 1:
            raise ValueError('Counter damage needs one exact current physical owner contact')
        contact = contacts[0]
        armed = [e for e in events if e.get('event') == 'bell_counter_armed'
                 and e.get('event_id') == event_id and e.get('bell_id') == contact.get('bell_id')
                 and e.get('owner_id') == contact.get('owner_id') and e.get('accepted_action') == 'hook_kick'
                 and e.get('tick', -1) <= contact.get('tick', -1)]
        if not armed or not any(e.get('event') == 'bell_player_arrived'
                                 and e.get('bell_id') == contact.get('bell_id')
                                 and e.get('accepted_action') == 'hook_contact_kick'
                                 and e.get('tick', -1) <= armed[0].get('tick', -1) for e in events):
            raise ValueError('Physical counter requires actual Motor arrival and subsequent accepted kick')

def validate_bell_physics(data):
    events = data.get("events", [])
    samples = data.get("samples", [])
    # A flight-state label cannot turn a trapped circle into a live threat.
    flight_window = []
    last_bell = None
    for frame in samples:
        bell_id = frame.get('bell_id')
        if frame.get('bell_state') in {'outbound', 'returning'} and (not isinstance(bell_id, (int, float)) or bell_id <= 0 or len(frame.get('bell_p', [])) != 2):
            raise ValueError('Live bell identity and actual position required')
        if frame.get('bell_state') not in {'outbound', 'returning'} or not bell_id or bell_id != last_bell:
            flight_window = []
        last_bell = bell_id
        if frame.get('bell_state') in {'outbound', 'returning'}:
            flight_window.append(frame['bell_p'])
            flight_window = flight_window[-24:]
            if len(flight_window) == 24 and max(p[0] for p in flight_window)-min(p[0] for p in flight_window)<1 and max(p[1] for p in flight_window)-min(p[1] for p in flight_window)<1:
                raise ValueError('Live thrown/returning bell stagnated for 24 actual frames')
    # The finite contact rebound is 0.20 s. Nearly half a second of the
    # player pushing the returning weapon is not a legitimate new attack.
    player_runs = {}
    for contact in (e for e in events if e.get('event') == 'bell_collision'):
        bell_id = contact.get('bell_id')
        previous_frame, length = player_runs.get(bell_id, (-2, 0))
        frame = contact.get('physics_frame', -1)
        length = length + 1 if contact.get('kind') == 'player' and frame == previous_frame + 1 else (1 if contact.get('kind') == 'player' else 0)
        player_runs[bell_id] = (frame, length)
        if length > 24:
            raise ValueError('A thrown/returning bell stayed in consecutive player collision beyond its finite rebound')
    for catch in (e for e in events if e.get('event') == 'bell_caught'):
        if not any(e.get('event') == 'bell_collision' and e.get('kind') == 'owner' and e.get('bell_id') == catch.get('bell_id') and e.get('collider') == e.get('owner_id') and e.get('contact_kind') in {'kinematic_sweep', 'actual_shape_overlap'} and e.get('tick', 0)<=catch.get('tick', 0) for e in events):
            raise ValueError('Catch needs actual live owner sweep or exact shape overlap')


def validate_tolerance(data):
    if data.get('failures') != 0 or data.get('assertions', 0) < 54:
        raise ValueError('All six actual-input tolerance samples must complete')
    if data.get('scenario_selection') != 'tolerance' or data.get('version') != 'forest-guardian-duel-arena-v4' or data.get('mechanic_version') != 'guardian-two-action-cycle-v6':
        raise ValueError('Exact immutable mechanic/geometry/input-tolerance scope required')
    configurations = {(0,9), (0,12), (0,15), (3,12), (6,12), (9,12)}
    rows = data.get('comparisons', [])
    if len(rows) != 6 or {(r.get('reaction_delay_frames'), r.get('ingress_hold_frames')) for r in rows} != configurations:
        raise ValueError('Exact six reaction-delay / normal-jump-hold configurations required')
    events = data.get('events', [])
    for row in rows:
        if (row.get('initial_boss_hp'), row.get('initial_player_hp'), row.get('initial_stamina')) != (32,5,100):
            raise ValueError('Normal actual initial resources required for every tolerance sample')
        if row.get('id') != 'H_delay%s_hold%s' % (row['reaction_delay_frames'], row['ingress_hold_frames']):
            raise ValueError('Exact input timing identity required')
        if row.get('boss_hp') != 0 or row.get('player_hp', 0) <= 0 or row.get('defeats') != 1 or not row.get('offensive_arrived') or not row.get('counter_enabled'):
            raise ValueError('Each tolerance sample must survive a unique full normal-input fight')
        if not row.get('initially_sealed') or row.get('seal_close_count') != 1 or row.get('stop_reason') == 'escaped_arena':
            raise ValueError('Physical production seal/recovery required for every sample')
        bounded = events[row['event_start']:row['event_end']]
        hits = [e for e in bounded if e.get('event')=='policy_result' and e.get('target')=='boss' and str(e.get('source','')).startswith('guardian_bell_counter:')]
        if len(hits) != row.get('counter_hits') or not hits or sum(e['amount'] for e in hits) != row.get('counter_damage'):
            raise ValueError('Each timing variant must actually perform the physical counter')
        hooks = [e for e in bounded if e.get('event')=='hook_contact' and e.get('bell_target') is True]
        if len(hooks) != row.get('moving_bell_hooks') or not hooks:
            raise ValueError('Each timing variant must actually hook a moving bell')
    validate_bell_physics(data)
    validate_counter_causality(events)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output-dir', default='build/forest_depth/boss/native')
    parser.add_argument('--scenario', choices=['full', 'tolerance'], default='full')
    args = parser.parse_args()
    out = (ROOT / args.output_dir).resolve()
    if not out.is_relative_to((ROOT / 'build/forest_depth/boss').resolve()):
        parser.error('output must be under build/forest_depth/boss')
    if out.exists() and any(out.iterdir()):
        parser.error('fresh output required')
    out.mkdir(parents=True, exist_ok=True)
    before = level_formal.source_files()
    owned = [Path(__file__).resolve(), ROOT / 'tests/forest_boss_depth_runner.gd']
    verifier = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in owned}
    receipt = {'scope': 'Guardian local two-action candidate; phase evidence is explicit, not formal rewards, Queen, player or device acceptance',
               'source_before': before, 'verifier_before': verifier, 'passed': False}
    started = time.monotonic()
    try:
        # The public check must work from a clean checkout, not an author's
        # separately imported snapshot. Native gameplay keeps its original cap.
        with (out / 'import.log').open('w') as log, contextlib.redirect_stdout(log):
            imported = run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
        if re.search(r'(^|\n)(?:SCRIPT )?ERROR:', imported):
            raise RuntimeError('Unexpected native import ERROR')
        with (out / 'native.log').open('w') as log, contextlib.redirect_stdout(log):
            text = run_engine(['--headless', '--fixed-fps', '60', '--path', '.', '--script',
                               'tests/forest_boss_depth_runner.gd', '--',
                               f'--output-dir=res://{out.relative_to(ROOT)}'] + ([] if args.scenario=='full' else ['--only=tolerance']), 180)
        if not re.search(r'^FOREST BOSS DEPTH: [1-9]\d* assertions, 0 failures$', text, re.M):
            raise RuntimeError('Complete golden success marker required')
        if re.search(r'(^|\n)(?:SCRIPT )?ERROR:', text):
            raise RuntimeError('Unexpected engine error')
        data = json.loads((out / 'capture.json').read_text())
        (validate if args.scenario=='full' else validate_tolerance)(data)
        receipt['passed'] = True
    finally:
        receipt['source_after'] = level_formal.source_files()
        receipt['source_guard'] = before == receipt['source_after']
        receipt['verifier_after'] = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in owned}
        receipt['elapsed_seconds'] = time.monotonic() - started
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        if not receipt['source_guard'] or receipt['verifier_after'] != verifier:
            raise RuntimeError('Source changed during golden capture')
    print('PASS: isolated guardian physical counter, moving body and cheap-strategy evidence; scenario=' + args.scenario)


if __name__ == '__main__':
    main()
