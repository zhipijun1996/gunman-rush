"""Current spider/real-charger local ecology: real input, bullets, policy, strict native exit."""
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
    if data.get('failures') != 0 or data.get('assertions', 0) < 35:
        raise ValueError('Complete native assertions are required')
    expected = {'spider_stand_line', 'spider_live_bypass', 'spider_bullets',
                'spider_cancel_pause_epoch_inactive'}
    rows = data.get('cases', [])
    if len(rows) != len(expected) or {r.get('id') for r in rows} != expected:
        raise ValueError('Every independent golden/counterfactual is required')
    events = data.get('events', [])
    for target in ('forest_thread_spider',):
        hits = [e for e in events if e.get('kind') == 'policy_result'
                and e.get('target') == target and e.get('hp') == 0
                and str(e.get('source', '')).startswith('player_projectile:')]
        if not hits:
            raise ValueError(f'{target}: actual projectile lethal policy result missing')
    if not any(e.get('kind') == 'accepted_shot' and e.get('projectiles', 0) > 0 for e in events):
        raise ValueError('Actual accepted shot with a spawned projectile required')
    row = next(r for r in rows if r['id'] == 'spider_stand_line')
    if row['hp_before'] - row['hp_after'] != 1:
        raise ValueError('Occupied-line policy damage must occur once')
    if not any(e.get('kind') == 'policy_result' and e.get('target') == 'player'
               and ':thread:' in str(e.get('event_id', '')) for e in events):
        raise ValueError('Actual thread hazard policy event missing')
    controls = data.get('comparisons', [])
    expected_controls = {f'root_split/{version}/{strategy}'
                         for version in ('legacy',)
                         for strategy in ('bank_shoot', 'lower_wait', 'fixed_H')}
    expected_controls |= {f'woven_crown/depth/{strategy}' for strategy in
                          ('bank_shoot', 'wait_line', 'fixed_H', 'live_H')}
    if len(controls) != 7 or {row.get('id') for row in controls} != expected_controls:
        raise ValueError('All seven current spatial strategy controls required')
    frames = data.get('comparison_frames', [])
    for row in controls:
        observed = [frame for frame in frames if frame.get('comparison') == row['id']]
        if not observed or row.get('ticks', 0) <= 0:
            raise ValueError(f"{row['id']}: real frame observations missing")
        if not row.get('completed'):
            raise ValueError(f"{row['id']}: strategy did not complete; retain failed control")
        if row.get('requested_H') and not row.get('caught_expected_H_target'):
            raise ValueError(f"{row['id']}: expected real H target was not caught")
        if row.get('strategy') != 'bank_shoot' and not row.get('observed_preview'):
            raise ValueError(f"{row['id']}: strategy bypassed actual observation")
        if row.get('strategy') == 'live_H':
            validate_live_recoil(row, events)
    validate_stress(data)


def validate_live_recoil(row, events):
    before, after = row.get('recoil_before', {}), row.get('recoil_after', {})
    request_tick = row.get('recoil_request_tick', -1)
    shot = [e for e in events[row['event_start']:row['event_end']]
            if e.get('kind') == 'accepted_shot' and e.get('aim') == [-1, 0]
            and request_tick <= e.get('tick', -1) <= request_tick + 1
            and e.get('projectiles', 0) > 0]
    if not shot or before.get('H_state') != 'free' or before.get('grounded'):
        raise ValueError('Live H must actually fire a left projectile at first free airborne recovery')
    if after.get('shot_charges') != before.get('shot_charges', 0) - 1:
        raise ValueError('Actual H->R must consume one real air shot')
    if abs(before.get('stamina', 0) - after.get('stamina', 0) - before.get('shot_cost', -1)) > 1e-6:
        raise ValueError('Actual H->R must consume the real configured shot cost')
    if not row.get('upper_support_seen'):
        raise ValueError('Live H->R must actually reach the named main support')


def _initial_signature(row):
    frame = row['start']
    return {key: frame[key] for key in ('position', 'hp', 'stamina', 'shot_charges', 'actors')}


def validate_stress(data):
    rows = data.get('stress_controls', [])
    expected = {f'ablation/{phase}/{strategy}/{switch}'
                for phase in ('fresh', 'line_hold')
                for strategy in ('direct_walk', 'wait_line', 'fixed_H', 'live_H')
                for switch in ('on', 'off')}
    expected |= {'phase/travel_left', 'phase/travel_right', 'dead_lantern/fixed_H', 'low_resource/live_H'}
    if len(rows) != len(expected) or {row.get('id') for row in rows} != expected:
        raise ValueError('All twenty causal/phase/dead/low-resource controls required')
    events = data['events']
    frames = data['comparison_frames']
    by_id = {row['id']: row for row in rows}
    for row in rows:
        if not row.get('setup_ok') or not row.get('completed'):
            raise ValueError(f"{row['id']}: actual setup or legal completion failed")
        observed = [frame for frame in frames if frame.get('comparison') == row['id']]
        if not observed:
            raise ValueError(f"{row['id']}: no actual frame observations")
        if row.get('requested_H') and not row.get('caught_expected_H_target'):
            raise ValueError(f"{row['id']}: requested H missed its actual target")
        if row.get('strategy') == 'live_H':
            validate_live_recoil(row, events)
        if row.get('strategy') not in ('bank_shoot', 'direct_walk') and not row.get('observed_preview'):
            raise ValueError(f"{row['id']}: missing actual observed preview")
        suppressed = row.get('thread_suppressed', [])
        if not row['variant'].get('line_disabled') and suppressed:
            raise ValueError('Normal controls must never suppress damage')
        if any(e.get('source') != 'woven_thread_spider' or ':thread:' not in e.get('event_id', '')
               or e.get('target') != 'player' or e.get('amount') != row['primary_definition']['line_damage']
               for e in suppressed):
            raise ValueError('Ablation may suppress only this spider line, never body/other damage')
    for phase in ('fresh', 'line_hold'):
        for strategy in ('direct_walk', 'wait_line', 'fixed_H', 'live_H'):
            left, right = [by_id[f'ablation/{phase}/{strategy}/{switch}'] for switch in ('on', 'off')]
            if left['geometry_hash'] != right['geometry_hash'] or _initial_signature(left) != _initial_signature(right):
                raise ValueError('Causal line pairs need exactly matched geometry, entry, resources and actor states')
    for phase in ('travel_left', 'travel_right'):
        row = by_id[f'phase/{phase}']
        actor = next(a for a in row['setup_state']['actors'] if a['id'] == 'forest_lantern')
        if actor['state'] != 'travel':
            raise ValueError('Moving-anchor phase must be reached through actual travel')
    row = by_id['dead_lantern/fixed_H']
    actor = next(a for a in row['start']['actors'] if a['id'] == 'forest_lantern')
    prefix = events[row['setup_event_start']:row['event_start']]
    if actor['hp'] != 0 or not any(e.get('kind') == 'policy_result' and e.get('target') == 'woven_lantern'
                                  and e.get('hp') == 0 and str(e.get('source', '')).startswith('player_projectile:')
                                  for e in prefix):
        raise ValueError('Dead-anchor fallback needs real projectile death before the route')
    row = by_id['low_resource/live_H']
    cost = row['start']['shot_cost']
    if not cost <= row['start']['stamina'] <= 2 * cost:
        raise ValueError('Low-energy route must start with one or two configured shot costs')
    prefix = events[row['setup_event_start']:row['event_start']]
    if not any(e.get('kind') == 'accepted_shot' and e.get('aim') == [-1, 0] and e.get('projectiles', 0) > 0 for e in prefix):
        raise ValueError('Low-energy setup needs actual costly missed projectiles')
    if any(e.get('kind') == 'policy_result' for e in prefix):
        raise ValueError('Low-energy miss setup must not secretly hit/refund or damage the player')


def summarize_stress(data):
    rows = {row['id']: row for row in data['stress_controls']}
    effects = []
    for phase in ('fresh', 'line_hold'):
        for strategy in ('direct_walk', 'wait_line', 'fixed_H', 'live_H'):
            on, off = [rows[f'ablation/{phase}/{strategy}/{switch}'] for switch in ('on', 'off')]
            effects.append({'phase': phase, 'strategy': strategy,
                            'line_on': {'ticks': on['ticks'], 'hp': on['end']['hp'], 'stamina': on['end']['stamina']},
                            'line_off': {'ticks': off['ticks'], 'hp': off['end']['hp'], 'stamina': off['end']['stamina']},
                            'off_suppressed_requests': len(off['thread_suppressed'])})
    return {'scope': 'Actual local matched causal observations, not fun/formal pool acceptance',
            'pairs': effects, 'no_automatic_mechanic_acceptance': True}




def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output-dir', default='build/forest_depth/ecology/native')
    args = parser.parse_args()
    out = (ROOT / args.output_dir).resolve()
    if not out.is_relative_to((ROOT / 'build/forest_depth/ecology').resolve()):
        parser.error('output must be under build/forest_depth/ecology')
    if out.exists() and any(out.iterdir()):
        parser.error('fresh output directory required')
    out.mkdir(parents=True, exist_ok=True)
    before = level_formal.source_files()
    verifier = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in (Path(__file__).resolve(), ROOT / 'tests/forest_depth_enemy_runner.gd')}
    receipt = {'scope': 'Local actors, four spider actor cases, seven spatial controls and twenty causal/phase/dead/low-resource controls; rejected badger prototype retired. Mechanics value remains subject to actual comparison; not formal forest admission',
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
                               'tests/forest_depth_enemy_runner.gd', '--',
                               f'--output-dir=res://{out.relative_to(ROOT)}'], 180)
        if not re.search(r'^FOREST DEPTH ENEMIES: [1-9]\d* assertions, 0 failures$', text, re.M):
            raise RuntimeError('Native completion missing')
        if re.search(r'(^|\n)(?:SCRIPT )?ERROR:', text):
            raise RuntimeError('Unexpected engine ERROR')
        data = json.loads((out / 'capture.json').read_text())
        validate(data)
        (out / 'stress-summary.json').write_text(json.dumps(summarize_stress(data), indent=2) + '\n')
        receipt['passed'] = True
    finally:
        receipt['source_after'] = level_formal.source_files()
        receipt['source_guard'] = before == receipt['source_after']
        receipt['verifier_after'] = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
                                     for path in verifier}
        receipt['elapsed_seconds'] = time.monotonic() - started
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        if not receipt['source_guard'] or verifier != receipt['verifier_after']:
            raise RuntimeError('Source changed during native capture')
    print('PASS: local forest depth enemies, actual bullets/policy and strict exit')


if __name__ == '__main__':
    main()
