"""V18 finite development feedback: actual places, canonical contour and App routes.

This proves selected technical paths only. Art, meaningful library size, generated
map identity, FUN and devices remain independent; this is never a release gate.
"""
import argparse
import contextlib
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time

from forest_bible_world_sources import inventory
from run_forest_exploration_contract import archive_sources, changed_sources, git, save
from run_tests import run_engine

ROOT = Path(__file__).resolve().parents[1]


LAYOUT = 'forest-exploration-places-v18'
FORMAL_SCOPE = 'formal_spawn_actual_App_Router_Motor_no_position_or_resource_injection'
FIXTURE_SCOPE = 'initial_fixture_spawn_only_actual_App_no_midroute_or_resource_injection'
LOCAL_SCOPE = 'single_place_real_input_not_formal_map_or_FUN'


def _require(condition, reason):
    if not condition:
        raise ValueError(reason)


def _point(value):
    import math
    return (isinstance(value, list) and len(value) == 2
            and all(type(n) in (int, float) and math.isfinite(n) for n in value))


def _close(a, b, x=0.1, y=0.1):
    return _point(a) and _point(b) and abs(a[0]-b[0]) <= x and abs(a[1]-b[1]) <= y


def _full_support(frame, platforms, expected=None):
    if frame.get('grounded') is not True:
        return False
    x, y, width, height = frame['body']
    return any(s in platforms and x >= platforms[s][0]-.1
               and x+width <= platforms[s][0]+platforms[s][2]+.1
               and abs(y+height-platforms[s][1]) < 1
               for s in frame.get('supports', []) if expected is None or s == expected)


def _expand_itinerary(manifest, route):
    """Rebuild the actual Bible reader expansion, including its terminal walks."""
    edges = {edge['id']: edge for edge in manifest['connections']}
    _require(len(edges) == len(manifest['connections']), 'Duplicate world edge IDs')
    route_ids = manifest['routes'][route]
    _require(isinstance(route_ids, list) and route_ids, 'Empty requested world route')
    result = []
    for edge_id in route_ids:
        edge = edges[edge_id]
        if edge['kind'] == 'ordinary_sequence':
            _require(isinstance(edge['steps'], list) and edge['steps'], 'Empty ordinary edge')
            for index, authored in enumerate(edge['steps']):
                step = dict(authored, edge_id=edge_id, step_index=index)
                if index == 0:
                    step.update({key: edge[key] for key in ('claim_before_edge', 'claim_area', 'claim_id') if key in edge})
                result.append(step)
            result.append(dict(kind='walk', edge_id=edge_id, landing=edge['path'][-1],
                               step_index=len(edge['steps']), b=edge['b']))
        else:
            result.append(dict(edge, edge_id=edge_id, landing=edge.get('landing', edge['path'][-1])))
            result.extend(dict(step, edge_id=edge_id, step_index=index, post_landing=True)
                          for index, step in enumerate(edge.get('post_landing_steps', [])))
            if edge['kind'] == 'hollow_recovery':
                result.append(dict(kind='walk', edge_id=edge_id, landing=edge['path'][-1], post_recovery_align=True))
    return result


def _validate_reward(data, itinerary, choice_index):
    claims = {leg['claim_id'] for leg in itinerary if leg.get('claim_before_edge') is True}
    transactions = data['reward_transactions']
    _require(isinstance(transactions, list) and len(transactions) == len(claims)
             and {row['claim_id'] for row in transactions} == claims, 'Missing or duplicate actual reward transaction')
    rewards = {row['id']: row for row in data['manifest']['rewards']}
    for row in transactions:
        reward = rewards[row['claim_id']]
        selected = reward['resources'][choice_index]
        _require(selected['kind'] in ('coin', 'note') and type(selected['amount']) is int
                 and selected['amount'] > 0, 'Invalid actual OR resource choice')
        before, after = row['before'], row['after']
        for state in (before, after):
            _require(all(type(state[key]) is int and state[key] >= 0 for key in ('coins', 'notes')),
                     'Invalid actual reward balances')
        expected = (selected['amount'], 0) if selected['kind'] == 'coin' else (0, selected['amount'])
        _require((after['coins']-before['coins'], after['notes']-before['notes']) == expected,
                 'Reward did not settle the requested OR choice')
        claim_key = f"thorn_forest/map_{data['map_index']}/{row['claim_id']}"
        _require(not before['claimed'].get(claim_key, False)
                 and after['claimed'] == dict(before['claimed'], **{claim_key: True})
                 and before['items'] == after['items'], 'Reward claim state/items do not match actual OR settlement')
        _require(row['duplicate_before'] == after == row['duplicate_after'], 'Duplicate reward changed the full wallet')
        _require(type(row['tick']) is int and 1 <= row['tick'] <= data['frames'][-1]['tick'], 'Reward tick outside actual trace')
    if claims:
        modal = data['modal_frames']
        _require(len(modal) >= 5 and all(f['paused'] is True for f in modal)
                 and len({f['motion_steps'] for f in modal}) == 1, 'Actual paused reward modal proof missing')
        pointer = data['pointer_events']
        _require(len(pointer) == 2 and [e['kind'] for e in pointer] == ['mouse_button_press', 'mouse_button_release'],
                 'Actual reward pointer choice missing')
        _require(pointer[0]['position'] == pointer[1]['position'] and pointer[0]['button_text'] == pointer[1]['button_text'],
                 'Reward pointer did not click the same choice')
        for event in pointer:
            x, y, width, height = event['rect']
            _require(_point(event['position']) and x <= event['position'][0] <= x+width
                     and y <= event['position'][1] <= y+height, 'Reward pointer outside the choice button')


def _validate_local_air(data, selected):
    """Validate the intended native airborne program, not a fabricated walk log."""
    import math
    manifest, frames, events = data['manifest'], data['frames'], data['events']
    program = selected['action_program']
    _require(program == manifest['action_program'] and program
             and any(a['action'] == 'H' for a in program) and any(a['action'] == 'R' for a in program),
             'Actual nonempty H/R program missing')
    _require(not any(e.get('kind') == 'actual_ordinary_leg_complete' for e in events),
             'Ordinary completion events cannot prove an airborne program')
    contacts = [e for e in events if e.get('kind') == 'hook_contact_kick']
    shots = [e for e in events if e.get('kind') == 'shot_fired']
    _require(len(contacts) == sum(a['action'] == 'H' for a in program)
             and len(shots) == sum(a['action'] == 'R' for a in program), 'Actual H contacts or R shots missing/duplicated')
    _require(all(type(e['serial']) is int and e['serial'] > 0 for e in shots)
             and len({e['serial'] for e in shots}) == len(shots), 'Actual shot identity missing/duplicated')
    cursor, first_cast = 0, None
    for action in program:
        if action['action'] == 'H':
            actual = next((e for e in contacts if e['tick'] > cursor), None)
            _require(actual is not None and actual['target'] == action['anchor']
                     and actual.get('hook_used_at_event') is True, 'H contacted the wrong or absent real target')
            casts = [e for e in events if e.get('kind') == 'hook_cast' and cursor <= e['tick'] <= actual['tick']]
            pulls = [e for e in events if e.get('kind') == 'hook_pull' and cursor <= e['tick'] <= actual['tick']
                     and e.get('target') == action['anchor']]
            kicks = [e for e in events if e.get('kind') == 'hook_kick' and e['tick'] >= actual['tick']
                     and e.get('target') == action['anchor'] and e.get('hook_used_at_event') is False]
            _require(len(casts) == 1 and len(pulls) == 1 and kicks
                     and casts[0]['tick'] <= pulls[0]['tick'] <= actual['tick'] <= kicks[0]['tick'],
                     'Actual H cast/pull/contact/kick sequence missing')
            _require(any(r.get('kind') == 'grapple' and r.get('queued') is True
                         and cursor <= r['tick'] <= casts[0]['tick'] for r in data['requests']),
                     'Accepted H did not follow a real queued Router request')
            first_cast = casts[0]['tick'] if first_cast is None else first_cast
            cursor = kicks[0]['tick']
        elif action['action'] == 'R':
            actual = next((e for e in shots if e['tick'] > cursor), None)
            direction = action['direction']
            _require(_point(direction) and math.hypot(*direction) > 0, 'Invalid authored R direction')
            length = math.hypot(*direction)
            direction = [n/length for n in direction]
            _require(actual is not None and _close(actual['direction'], direction, .0001, .0001),
                     'Actual R shot direction/order mismatches the program')
            _require(any(r.get('kind') == 'shoot_release' and r.get('queued') is True
                         and cursor <= r['tick'] <= actual['tick']
                         and _close(r['direction'], direction, .0001, .0001) for r in data['requests']),
                     'Actual R shot has no matching queued Router request')
            cursor = actual['tick']
        else:
            _require(False, 'Unsupported airborne action')
    _require(type(frames[-1].get('program_index')) is int and frames[-1]['program_index'] == len(program),
             'Airborne action program did not finish')
    if manifest.get('chain_contract', {}).get('continuous_airborne') is True:
        _require(all(f['grounded'] is False for f in frames if first_cast <= f['tick'] <= cursor),
                 'Continuous airborne program landed before the last action')
    support_id = manifest['goal_support_id']
    goal_port = manifest['ports'][selected['to_port']]
    _require(support_id == 'crown' == goal_port['support_id']
             and _close(goal_port['position'], manifest['goal']), 'Airborne goal is not its actual crown receiving port')
    supports = {p['id']: p['rect'] for p in manifest['platforms']}
    _require(len(frames) >= 12, 'Actual airborne receiving observation missing')
    for frame in frames[-12:]:
        x, y = frame['position']
        sample = dict(frame, body=[x-12, y-18, 24, 36], supports=['crown'])
        _require(frame.get('crown_support') is True and _full_support(sample, supports, 'crown'),
                 'Actual final twelve full-foot crown frames missing')


def validate_report(data, name, script, extra):
    """Reject partial/misbound native evidence; this does not evaluate FUN/art."""
    try:
        _validate_report(data, name, script, extra)
    except (KeyError, IndexError, TypeError) as error:
        raise ValueError('Malformed native report: '+str(error)) from error


def _validate_report(data, name, script, extra):
    _require(isinstance(data, dict), 'Native report must be an object')
    if name in ('world', 'union'):
        _require(data.get('failures') == [] and type(data.get('assertions')) is int
                 and data['assertions'] > 0, 'Missing or failed nonempty native assertions')
        if name == 'world':
            samples = data['samples']
            expected = {(m, f'forest-places-{i:02d}') for m in (1, 2) for i in range(10)}
            _require(len(samples) == 20 and {(s['map_index'], s['root_seed']) for s in samples} == expected,
                     'Actual 20-world structure/replay corpus missing')
            for sample in samples:
                _require(type(sample['map_index']) is int and sample['seed'] == f"{sample['root_seed']}/thorn_forest/map_{sample['map_index']}"
                         and type(sample['variant']) is int and sample['variant'] in (0, 1), 'World sample identity mismatch')
        else:
            _require(len(data['rows']) == 2 and {r['variant'] for r in data['rows']} == {0, 1}
                     and all(r['internal_edges'] == [] and type(r['solid_count']) is int and r['solid_count'] > 0
                             and type(r['edge_count']) is int and r['edge_count'] > 0 for r in data['rows']),
                     'Both nonempty real contour variants missing')
            expansion = data['expansion_rows']
            expected = {(module, variant) for module in ('z_descending_return', 'fallen_trunk_two_faces',
                                                         'backbranch_fruit_reversal') for variant in (0, 1)}
            _require(isinstance(expansion, list) and len(expansion) == 6
                     and {(r['module_id'], r['variant']) for r in expansion} == expected
                     and all(type(r['variant']) is int and r['internal_edges'] == []
                             and type(r['solid_count']) is int and r['solid_count'] > 0
                             and type(r['edge_count']) is int and r['edge_count'] > 0 for r in expansion),
                     'Exact six nonempty new-module contour variants missing')
        return
    options = dict(arg[2:].split('=', 1) for arg in extra)
    route = options['route']
    frames = data['frames']
    _require(data.get('passed') is True and data.get('audio_released') is True
             and data.get('route') == route and isinstance(frames, list) and frames,
             'Missing, failed or wrong native route')
    _require(data.get('manual_motor_step') is False and data.get('midroute_injection') is False
             and data.get('resource_override') is False, 'Native pose/Motor/resource injection')
    _require(all(type(f.get('motor_steps')) is int and f['motor_steps'] == 1
                 and type(f.get('tick')) is int and f['tick'] == index+1 and _point(f.get('position'))
                 for index, f in enumerate(frames)), 'Actual contiguous single-Motor frames missing')
    manifest = data['manifest']
    if name.startswith('local_'):
        variant = int(options['place-variant'])
        module = options.get('layout', 'seven_bough_reveal')
        _require(data['scope'] == LOCAL_SCOPE and data['layout'] == module == manifest['id']
                 and type(data['place_variant']) is int and data['place_variant'] == variant == manifest['variant']
                 and data.get('initial_fixture_spawn_override') is True and data.get('reached') is True
                 and data.get('failure') == '' and data.get('danger_contacts') == [], 'Local fixture identity or outcome mismatch')
        selected = manifest['routes'][route]
        _require(selected == manifest['routes']['main'], 'Local requested itinerary was replaced')
        _require(_close(frames[0]['position'], manifest['spawn'], 1, 2), 'Local initial fixture pose mismatch')
        if selected['kind'] == 'airborne_chain':
            _validate_local_air(data, selected)
            return
        _require(selected['kind'] == 'ordinary_sequence' and selected['steps'], 'Local requested ordinary itinerary is empty')
        completed = [e for e in data['events'] if e.get('kind') == 'actual_ordinary_leg_complete']
        _require(len(completed) == len(selected['steps'])
                 and [e['step'] for e in completed] == list(range(len(selected['steps'])))
                 and all(e['stable_frames'] >= 12 for e in completed), 'Actual complete place itinerary missing')
        for event, step in zip(completed, selected['steps']):
            _require(_close(event['position'], step['landing'], 7, 2), 'Local leg completed at the wrong destination')
        _require(_close(frames[-1]['position'], manifest['goal'], 7, 2), 'Actual final local frame missed its goal')
        _require(_close(frames[0]['position'], manifest['spawn'], 1, 2)
                 and _close(completed[-1]['position'], manifest['goal'], 7, 2), 'Local departure/final goal mismatch')
        return
    map_index, seed = int(options['map']), options['seed']
    fixture = script == 'tests/forest_places_fixture_runner.gd'
    _require(script in ('tests/forest_places_fixture_runner.gd', 'tests/forest_places_motor_runner.gd'), 'Unexpected App evidence consumer')
    _require(data['scope'] == (FIXTURE_SCOPE if fixture else FORMAL_SCOPE) and data['layout'] == LAYOUT
             and manifest['layout_version'] == LAYOUT and data['seed'] == seed
             and type(data['map_index']) is int and data['map_index'] == map_index == manifest['map_index']
             and manifest['seed'] == f'{seed}/thorn_forest/map_{map_index}' and data.get('failures') == [], 'App layout/map/seed/scope mismatch')
    areas = {a['id']: a['position'] for a in manifest['areas']}
    initial = data['initial']
    _require(initial['hook_enabled'] is True and initial['double_enabled'] is False and initial['wall_enabled'] is False,
             'Initial capability snapshot is not S2-H')
    if fixture:
        info = data['fixture']
        area = options.get('fixture-area', 'C')
        _require(data.get('initial_fixture_spawn_override') is True and info['initial_fixture_spawn_override'] is True
                 and info['area'] == area and type(info['motion_steps_before_override']) is int
                 and info['motion_steps_before_override'] == 0 and info['resource_or_health_override'] is False
                 and _close(info['original_formal_spawn'], manifest['spawn'], 1, 2)
                 and _close(info['actual_fixture_spawn'], areas[area])
                 and _close(initial['position'], areas[area], 1, 2), 'Undeclared or late initial fixture spawn')
    else:
        _require(data.get('initial_fixture_spawn_override', False) is False and not data.get('fixture')
                 and _close(initial['position'], manifest['spawn'], 1, 2), 'Formal route secretly used a local fixture pose')
    itinerary = _expand_itinerary(manifest, route)
    completed = data['completed']
    _require(data['itinerary'] == itinerary and len(completed) == len(itinerary), 'Actual complete exact App itinerary missing')
    platforms = {p['id']: p['rect'] for p in manifest['platforms']}
    for frame in frames:
        body = frame['body']
        _require(isinstance(body, list) and len(body) == 4 and body[2:] == [24, 36]
                 and _close([body[0]+12, body[1]+18], frame['position']), 'Actual player body observation missing')
    for index, event in enumerate(completed):
        tick = event['tick']
        leg = itinerary[index]
        expected_support = leg.get('landing_support_id', leg.get('support_id'))
        _require(type(tick) is int and 12 <= tick <= len(frames) and event['leg'] == index
                 and event['edge_id'] == itinerary[index]['edge_id']
                 and (index == 0 or tick > completed[index-1]['tick'])
                 and _close(event['position'], leg['landing'], 7, 2)
                 and _close(event['position'], frames[tick-1]['position'])
                 and all(_full_support(f, platforms, expected_support) for f in frames[tick-12:tick]),
                 'Actual full-foot completion proof missing')
    goal = areas[manifest['route_goals'][route]]
    _require(_close(data['final']['position'], goal, 7, 2)
             and _close(frames[-1]['position'], data['final']['position']), 'Actual final route goal missing')
    _validate_reward(data, itinerary, int(options.get('reward-index', 0)))
    if name.endswith('_reward'):
        intended = {r['id'] for r in manifest['rewards'] if r.get('approach_route') == route}
        _require(intended and {r['claim_id'] for r in data['reward_transactions']} == intended,
                 'Requested reward route did not claim its actual cache')



def _extra_feedback_jobs():
    """Finite new-place probes; unchanged original budgets and serial engine lease."""
    jobs = []
    for index in (0, 1):
        for label, module, route in (('z', 'z_descending_return', 'reward_return'),
                                     ('fallen', 'fallen_trunk_two_faces', 'reward_return'),
                                     ('back', 'backbranch_fruit_reversal', 'main'),
                                     ('back', 'backbranch_fruit_reversal', 'retry')):
            jobs.append((f'local_{label}_{index}_{route}', 'tests/forest_exploration_place_runner.gd',
                         ['--layout='+module, f'--place-variant={index}', '--route='+route],
                         r'^FOREST PLACE: PASS /', 240))
    for map_index, label, route, area, choice in (
            (1, 'z_reward', 'places_z_reward_trial', 'C', 0),
            (2, 'fallen_reward', 'places_fallen_reward_trial', 'C', 1),
            (2, 'back_reward', 'places_backbranch_reward_trial', 'C', 1),
            (1, 'z_failure', 'places_z_failure_recovery_trial', 'places_z__failure', 0),
            (2, 'z_failure', 'places_z_failure_recovery_trial', 'places_z__failure', 0)):
        jobs.append((f'map{map_index}_{label}', 'tests/forest_places_fixture_runner.gd',
                     [f'--map={map_index}', '--seed='+('forest-places-00' if map_index == 1 else 'forest-places-01'),
                      '--route='+route, '--fixture-area='+area, f'--reward-index={choice}'],
                     r'^FOREST PLACES FIXTURE: PASS /', 240))
    return jobs


def jobs_for_suite(suite):
    """Select bounded development evidence; no selection claims whole-region acceptance."""
    _require(suite in ('core', 'library', 'all'), 'Unknown forest development suite')
    jobs = [('import', None, [], '', 90),
            ('world', 'tests/forest_places_world_runner.gd', [], r'^FOREST PLACES WORLD: [1-9]\d* assertions, 0 failures$', 240),
            ('menu', 'tests/forest_places_menu_runner.gd', [], r'^FOREST PLACES MENU: [1-9]\d* assertions, 0 failures$', 240)]
    jobs.insert(2, ('union', 'tests/forest_places_union_runner.gd', [], r'^FOREST PLACES UNION: [1-9]\d* assertions, 0 failures$', 240))
    for index in (0, 1):
        for route in ('main', 'reward_return', 'failure_west_return', 'near_west_return'):
            jobs.append((f'local_{index}_{route}', 'tests/forest_exploration_place_runner.gd',
                         [f'--place-variant={index}', '--route='+route], r'^FOREST PLACE: PASS /', 240))
    for map_index in (1, 2):
        for label, route, fixture in (('normal', 'places_normal_journey', False),
                                      ('reward', 'places_reward_trial', True),
                                      ('return', 'places_outer_trial', True),
                                      ('windows', 'places_window_loop', True)):
            script = 'tests/forest_places_fixture_runner.gd' if fixture else 'tests/forest_places_motor_runner.gd'
            marker = r'^FOREST PLACES FIXTURE: PASS /' if fixture else r'^FOREST PLACES MOTOR: PASS /'
            jobs.append((f'map{map_index}_{label}', script,
                         [f'--map={map_index}', '--seed='+('forest-places-00' if map_index == 1 else 'forest-places-01'), '--route='+route,
                          *(['--reward-index=1'] if map_index == 2 and label == 'reward' else [])], marker, 240))
    if suite == 'library':
        return jobs[:3] + _extra_feedback_jobs()
    return jobs + _extra_feedback_jobs() if suite == 'all' else jobs


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--suite', choices=('core', 'library', 'all'), default='core')
    args = parser.parse_args(argv)
    output = args.output_dir.absolute()
    if (not output.is_relative_to(ROOT / 'build') or output.exists() or '..' in output.parts
            or any(p.is_symlink() for p in [output, *output.parents] if p.is_relative_to(ROOT))):
        parser.error('Use a fresh ordinary directory under build/')
    output.mkdir(parents=True)
    started = time.monotonic()
    jobs = jobs_for_suite(args.suite)
    receipt = {'scope': __doc__, 'import_cap_seconds': 90, 'native_cap_seconds': 240,
               'whole_cap_seconds': 600, 'fixed_fps': 60, 'workers': 1, 'checks': [], 'exit_code': 1,
               'suite': args.suite, 'expected_job_ids': [job[0] for job in jobs],
               'expected_job_count': len(jobs)}
    before = None
    try:
        receipt['baseline_head'] = git('rev-parse', 'HEAD').decode().strip()
        before = inventory()
        save(output / 'source-before.json', before)
        archived = archive_sources(output / 'source-snapshot-before', before, changed_sources())
        save(output / 'source-bytes-before.json', {'baseline_head': receipt['baseline_head'], 'files': archived})
        for name, script, extra, marker, cap in jobs:
            remaining = 600 - (time.monotonic() - started)
            if remaining <= 0:
                raise TimeoutError('Original 600 second whole feedback budget exceeded')
            native_report = output / (name + '.json')
            log = output / (name + '.log')
            arguments = ['--headless', '--path', '.']
            if script:
                arguments += ['--fixed-fps', '60', '--script', script]
                if name != 'menu':
                    arguments += ['--', *extra, '--output=res://' + native_report.relative_to(ROOT).as_posix()]
            else:
                arguments += ['--editor', '--quit']
            row = {'id': name, 'argv': ['bash', 'tools/godot.sh', *arguments], 'passed': False,
                   'timeout_seconds': min(cap, remaining), 'log': log.name}
            receipt['checks'].append(row)
            t = time.monotonic()
            try:
                with log.open('w') as stream, contextlib.redirect_stdout(stream), contextlib.redirect_stderr(stream):
                    text = run_engine(arguments, min(cap, remaining))
                if marker and len(re.findall(marker, text, re.M)) != 1:
                    raise RuntimeError('Missing or nonunique native completion marker')
                if script and name != 'menu':
                    data = json.loads(native_report.read_text())
                    validate_report(data, name, script, extra)
                    row['report'] = native_report.name
                    row['report_sha256'] = hashlib.sha256(native_report.read_bytes()).hexdigest()
                row.update(passed=True, exit_code=0)
            except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
                row.update(exit_code=1, error=repr(error))
                raise
            finally:
                row['seconds'] = round(time.monotonic() - t, 3)
                if log.is_file(): row['log_sha256'] = hashlib.sha256(log.read_bytes()).hexdigest()
                save(output / 'receipt.json', receipt)
        receipt['exit_code'] = 0
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        receipt.update(exit_code=1, error=repr(error))
    finally:
        after = inventory()
        save(output / 'source-after.json', after)
        receipt['source_stable'] = before is not None and before == after and receipt.get('baseline_head') == git('rev-parse', 'HEAD').decode().strip()
        if not receipt['source_stable']: receipt['exit_code'] = 1
        receipt['seconds'] = round(time.monotonic() - started, 3)
        save(output / 'receipt.json', receipt)
    print(('PASS' if receipt['exit_code'] == 0 else 'FAIL') + ': forest places development feedback / '+args.suite)
    return receipt['exit_code']


if __name__ == '__main__':
    sys.exit(main())
