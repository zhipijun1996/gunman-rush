"""Actual normal-input App Guardian earned-state reload and legacy compatibility.

Run inside copy_runtime_snapshot.py's guarded runtime snapshot while holding
its host's global engine lock; this wrapper never mutates the author worktree.
"""
import argparse
import contextlib
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import time

import level_formal
from run_tests import run_engine

ROOT = Path(__file__).resolve().parents[1]


def validate(data):
    if data.get('failures') != 0 or not isinstance(data.get('assertions'), int) or data['assertions'] < 45:
        raise ValueError('Complete App restore runtime assertions required')
    checks = data.get('checks', [])
    if len(checks) != data['assertions'] or not all(r.get('passed') is True for r in checks):
        raise ValueError('Full native assertion ledger required')
    rows = data.get('cases', [])
    if len(rows) != 2 or {r.get('id') for r in rows} != {'guardian_app_reload', 'legacy_app_reload'}:
        raise ValueError('Both actual App reload paths required')
    guardian = next(r for r in rows if r['id'] == 'guardian_app_reload')
    if guardian.get('malformed_cases') != 6 or guardian['actor_epoch_after'] <= guardian['actor_epoch_before']:
        raise ValueError('Malformed App negatives and fresh actor epoch required')
    saved = guardian['saved']
    policy=[e for e in guardian.get('phase_events', []) if e.get('event')=='actual_app_policy_result' and e.get('target')=='boss']
    if not any(str(e.get('source','')).startswith('player_projectile:') for e in policy):
        raise ValueError('Actual normal projectile damage must earn nondefault Boss HP')
    if not any(str(e.get('source','')).startswith('guardian_bell_counter:') for e in policy):
        raise ValueError('Actual returned Bell Policy damage required')
    if abs(guardian.get('initial_boss_hp', -1)-saved.get('health', 0)-sum(e.get('amount', 0) for e in policy))>0.0001:
        raise ValueError('Complete actual Boss damage ledger must reconcile to saved HP')
    if not any(e.get('event')=='body_collision' for e in guardian.get('phase_events', [])):
        raise ValueError('Real completed physical Body cycle required')
    after = guardian['after_activation']
    if guardian.get('invalid_contract_cases') != 11:
        raise ValueError('All current contract and retired-schema negatives required')
    for row in (saved, guardian['after_bound_restore'], after):
        if row.get('duel_version') != 'guardian-two-action-cycle-v6' or 'duel_roots' in row:
            raise ValueError('Exact current V6 schema without retired root ledger required')
    if saved.get('cycles', 0) <= 0 or saved.get('mode') != 'bell_stagger' or not guardian.get('combat_frames') or not guardian.get('route_frames'):
        raise ValueError('Actual Body cycle, earned Bell stagger and full normal-input trace required')
    if not any(r.get('event') == 'bell_counter_committed' for r in guardian.get('phase_events', [])):
        raise ValueError('Real counter commit evidence required')
    if saved.get('stage_phase') != 2 or after.get('stage_phase') != 2:
        raise ValueError('Actual HP-triggered phase2 persistence required')
    if after.get('body_position') != saved.get('body_position') or after.get('health') != saved.get('health'):
        raise ValueError('Actual body and damaged HP persistence required')
    if after.get('attack_epoch', -1) <= saved.get('attack_epoch', 0):
        raise ValueError('Fresh attack invalidation required')
    validate_recorded_chronology(dict(guardian, _all_cases=rows))



def _require(condition, message):
    if not condition:
        raise ValueError(message)


def _number(value):
    return type(value) in (int, float) and math.isfinite(value)


def _vector(value):
    return isinstance(value, list) and len(value) == 2 and all(_number(x) for x in value)


def _close(a, b):
    return _number(a) and _number(b) and abs(a - b) < 1e-6


def validate_recorded_chronology(guardian):
    """Check recorded observations, without inventing absent input timestamps.

    Attempt03 combat samples omit input requests and Boss HP. Its shared route
    event callback stops incrementing tick after route completion. Therefore its
    combat action ledger has ordering, but NOT combat-frame timestamps. Cross-
    ledger IDs and positions are checked here; frame-exact input/Policy causality
    is outside this capture schema and must not be claimed by this reader.
    """
    saved = guardian['saved']
    persistent = ('body_position', 'health', 'cycles', 'mode', 'clock', 'serial',
                  'stage_phase', 'weak_side', 'intro_duration', 'next_bell',
                  'duel_counter_enabled', 'vertical_speed', 'duel_version')
    _require(guardian.get('capture_schema') == 'combat_snapshot_plus_actual_HealthState_current',
             'Explicit actual HealthState capture schema required')
    _require(_vector(saved.get('body_position')) and saved.get('position') == saved['body_position'],
             'Finite saved body and App position must agree')
    _require(all(_number(saved.get(k)) for k in ('health', 'clock', 'intro_duration', 'vertical_speed')),
             'Finite saved numeric state required')
    _require(0 < saved['clock'] <= .8 and 0 < saved['health'] <= 12.8,
             'Earned positive remaining stagger and phase2 HP required')
    _require(saved.get('active') is True and saved.get('seal_closed') is True,
             'Active sealed App save required')
    _require(saved.get('weak_side') in (-1, 1) and type(saved.get('weak_side')) is int
             and 0 <= saved['intro_duration'] <= 1.6
             and type(saved.get('next_bell')) is bool
             and saved.get('duel_counter_enabled') is True,
             'Strict current saved contract required')
    for key in ('cycles', 'serial', 'stage_phase', 'attack_epoch'):
        _require(type(saved.get(key)) is int and saved[key] > 0, 'Positive integer saved ' + key)
    previous_epoch = saved['attack_epoch']
    for name in ('after_bound_restore', 'after_activation'):
        row = guardian[name]
        for key in persistent:
            _require(key in row and type(row[key]) is type(saved[key]) and row[key] == saved[key],
                     name + ' must preserve exact ' + key)
        _require(type(row.get('attack_epoch')) is int and row['attack_epoch'] > previous_epoch,
                 name + ' must invalidate previous attack epoch')
        previous_epoch = row['attack_epoch']
    route, combat = guardian['route_frames'], guardian['combat_frames']
    # These are minimum observations of this deterministic integration fixture,
    # not assertions inferred from its self-reported assertion count.
    for label, frames, start, minimum, hpkey, poskey in (
            ('route', route, 1, 254, 'health', 'position'),
            ('combat', combat, 0, 618, 'player_hp', 'player_position')):
        _require(len(frames) >= minimum, label + ' complete frame stream required')
        for index, frame in enumerate(frames):
            _require(type(frame.get('tick')) is int and frame['tick'] == start + index,
                     label + ' ticks must be contiguous and ordered')
            _require(_vector(frame.get(poskey)) and _number(frame.get(hpkey))
                     and 0 < frame[hpkey] <= 5 and _number(frame.get('energy'))
                     and 0 <= frame['energy'] <= 100, label + ' finite normal resources and body required')
            if index:
                prior = frames[index - 1]
                _require(math.dist(frame[poskey], prior[poskey]) < 25,
                         label + ' discontinuous body movement')
            if label == 'route':
                _require(frame.get('motor_steps') == 1 and frame.get('actor_epoch') == guardian['actor_epoch_before']
                         and frame.get('stage_epoch') == guardian['actor_epoch_before'],
                         'One Motor step and original live route lifetime required')
            else:
                boss = frame['boss']
                _require(_vector(boss.get('body_position')) and _number(boss.get('clock'))
                         and boss['clock'] >= 0 and boss.get('duel_version') == saved['duel_version'],
                         'Finite current Boss observation required on every combat frame')
                _require(boss.get('stage_phase') in (1, 2)
                         and type(boss.get('cycles')) is int and boss['cycles'] >= 0,
                         'Valid observed phase and cycle history required')
                if index:
                    priorboss = frames[index - 1]['boss']
                    _require(boss['cycles'] >= priorboss['cycles']
                             and boss['stage_phase'] >= priorboss['stage_phase'],
                             'Observed phase/cycles cannot regress')
    _require(route[-1]['position'] == combat[0]['player_position']
             and route[-1]['health'] == combat[0]['player_hp'], 'Continuous route-to-combat body/resources required')
    last = combat[-1]['boss']
    # Samples precede each physics tick; saved state follows the final tick.
    for key in ('body_position', 'cycles', 'serial', 'mode', 'weak_side', 'next_bell',
                'intro_duration', 'duel_counter_enabled', 'attack_epoch', 'vertical_speed'):
        _require(last.get(key) == saved[key], 'Final observed combat state differs from save: ' + key)
    _require(_close(last['clock'] - saved['clock'], 1 / 60),
             'Saved stagger must follow final combat sample by one physics tick')
    _require(combat[0]['boss']['body_position'] != saved['body_position']
             and combat[0]['boss']['cycles'] == 0, 'Actual moving Body cycle required')
    states = []
    for frame in combat:
        if not states or states[-1] != frame['hook_state']:
            states.append(frame['hook_state'])
    _require(states == ['free', 'hook_cast', 'hook_fly', 'hook_pull', 'hook_contact_kick', 'hook_kick', 'free'],
             'Complete observed real Bell H action sequence required')
    route_events = guardian['route_events']
    # Route callback timestamps are valid through the route's final frame only;
    # later combat callbacks retain that tick and are checked as an ordered ledger.
    route_damage = [e for e in route_events if e.get('kind') == 'committed_damage' and e.get('target') == 'player']
    hp = route[0]['health']
    for frame in route:
        for event in route_damage:
            if event['tick'] == frame['tick']:
                hp -= event['amount']
                _require(_close(hp, event['health_after']), 'Route damage event actual HP mismatch')
        _require(_close(hp, frame['health']), 'Every route frame must reconcile actual Player damage')
    shots = [e for e in route_events if e.get('kind') == 'shot_fired']
    _require(len(shots) >= 17 and [e.get('serial') for e in shots] == list(range(1, len(shots) + 1)),
             'Complete accepted actual shot serial history required')
    for shot in shots:
        _require(_vector(shot.get('aim')) and abs(math.hypot(*shot['aim']) - 1) < .001,
                 'Finite unit aim for every real accepted shot required')
    _require(all(_close(f['player_hp'], route[-1]['health']) for f in combat),
             'Full combat Player HP observations must agree with damage-free combat ledger')
    events = guardian['phase_events']
    def only(name):
        rows = [e for e in events if e.get('event') == name]
        _require(len(rows) == 1, 'Exactly one earned ' + name + ' required')
        return rows[0]
    chain = [only(n) for n in ('bell_player_arrived', 'bell_counter_armed',
                              'bell_counter_owner_contact', 'bell_counter_submitted', 'bell_counter_committed')]
    _require([events.index(e) for e in chain] == sorted(events.index(e) for e in chain),
             'Actual Bell contact/arm/owner/submit/commit ordering required')
    _require(len({e['bell_id'] for e in chain}) == 1
             and len({e['event_id'] for e in chain[1:]}) == 1,
             'Bell and counter identities must agree')
    arrived, armed, owner = chain[:3]
    _require(arrived['accepted_action'] == 'hook_contact_kick' and armed['accepted_action'] == 'hook_kick'
             and arrived['physics_frame'] < armed['physics_frame'] < owner['physics_frame'],
             'Real accepted H contact precedes physical returned-owner contact')
    contact_frames = [f for f in combat if f['hook_state'] == 'hook_contact_kick']
    _require(arrived['player_position'] == contact_frames[0]['player_position'],
             'Recorded Bell arrival must agree with actual Player contact frame')
    collision = only('body_collision')
    phase = only('duel_phase_changed')
    _require(collision.get('completed_body_cycles') == saved['cycles']
             and phase.get('completed_body_cycles') == saved['cycles']
             and phase.get('phase') == 2 and phase.get('boss_hp') == saved['health']
             and events.index(collision) < events.index(phase)
             and phase.get('bell_out') is False, 'Real completed Body then HP-triggered phase2 required')
    policies = [e for e in events if e.get('event') == 'actual_app_policy_result' and e.get('target') == 'boss']
    committed = [e for e in guardian['route_events'] if e.get('kind') == 'committed_damage' and e.get('target') == 'boss']
    _require(len(policies) == len(committed) and len({e['event_id'] for e in policies}) == len(policies),
             'Complete unique Policy and actual HealthState ledgers required')
    hp = guardian['initial_boss_hp']
    for policy, actual in zip(policies, committed):
        _require(all(policy[k] == actual[k] for k in ('event_id', 'source', 'target', 'amount')),
                 'Policy and actual committed damage order/identity mismatch')
        _require(_number(policy['amount']) and policy['amount'] > 0, 'Positive finite actual damage required')
        hp -= policy['amount']
        _require(_close(hp, actual['health_after']), 'Every committed damage must reconcile observed HP')
    _require(_close(hp, saved['health']), 'Final actual damaged HP must equal saved HP')
    legacy = next(r for r in guardian['_all_cases'] if r['id'] == 'legacy_app_reload')
    _require(legacy.get('scene') == 'res://scenes/bosses/thorn_guardian.tscn'
             and _number(legacy.get('health_before')) and legacy['health_before'] > 0
             and legacy.get('health_after') == legacy['health_before'], 'Legacy observed health/scene persistence required')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', default='build/forest_depth/restore/native')
    args = parser.parse_args()
    out = (ROOT / args.output_dir).resolve()
    if not out.is_relative_to(ROOT / 'build/forest_depth/restore') or out.exists():
        parser.error('Fresh output below build/forest_depth/restore required')
    out.mkdir(parents=True)
    before = level_formal.source_files()
    verifier = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in (Path(__file__).resolve(), ROOT / 'tests/forest_depth_restore_runner.gd')}
    receipt = {'scope': 'Actual DemoApp Guardian reload/legacy compatibility; normal-input earned-state integration, NOT Boss content admission',
               'base_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
               'source_before': before, 'verifier_before': verifier, 'passed': False}
    snapshot = ROOT / 'build/snapshot-receipt.json'
    if snapshot.is_file():
        receipt['runtime_snapshot_receipt_sha256'] = hashlib.sha256(snapshot.read_bytes()).hexdigest()
    started = time.monotonic()
    try:
        with (out / 'import.log').open('w') as log, contextlib.redirect_stdout(log):
            import_text = run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
        if re.search(r'(^|\n)(?:SCRIPT )?ERROR:', import_text):
            raise RuntimeError('Unexpected native import ERROR')
        with (out / 'native.log').open('w') as log, contextlib.redirect_stdout(log):
            text = run_engine(['--headless', '--fixed-fps', '60', '--path', '.', '--script',
                'tests/forest_depth_restore_runner.gd', '--',
                '--output=res://' + str((out / 'capture.json').relative_to(ROOT))], 90)
        if not re.search(r'^FOREST DEPTH RESTORE: [1-9]\d* assertions, 0 failures$', text, re.M):
            raise RuntimeError('Complete native restore result missing')
        if re.search(r'(^|\n)(?:SCRIPT )?ERROR:', text):
            raise RuntimeError('Unexpected native engine ERROR')
        validate(json.loads((out / 'capture.json').read_text()))
        receipt['passed'] = True
    finally:
        receipt['source_after'] = level_formal.source_files()
        receipt['verifier_after'] = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in verifier}
        receipt['source_guard'] = before == receipt['source_after'] and verifier == receipt['verifier_after']
        receipt['elapsed_seconds'] = time.monotonic() - started
        receipt['logs'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                           for p in out.iterdir() if p.is_file()}
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        if not receipt['source_guard']:
            raise RuntimeError('Source changed during native restore check')
    print('PASS: actual App V6 earned-state reload and legacy compatibility; full Boss content admission NOT covered')


if __name__ == '__main__':
    main()
