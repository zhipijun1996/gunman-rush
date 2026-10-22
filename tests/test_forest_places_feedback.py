"""Native evidence counterexamples: a green summary cannot replace the requested run.

Compact records model the native JSON protocol. They are validator tests, not
Godot route/FUN evidence; real recordings are revalidated separately.
"""
import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from run_forest_places_feedback import FIXTURE_SCOPE, FORMAL_SCOPE, LAYOUT, LOCAL_SCOPE, _extra_feedback_jobs, jobs_for_suite, validate_report


def record(fixture=False, reward=False, note=False):
    position = [100.0, -18.0] if fixture else [0.0, -18.0]
    route = 'reward' if reward else 'normal'
    edge = {'id': 'e', 'kind': 'ordinary_sequence', 'a': 'C', 'b': 'G',
            'path': [position.copy(), position.copy()],
            'steps': [{'kind': 'walk', 'landing': position.copy(), 'support_id': 'root'}]}
    if reward:
        edge.update(claim_before_edge=True, claim_id='places_seven_backside_cache', claim_area='C')
    step = dict(edge['steps'][0], edge_id='e', step_index=0)
    if reward:
        step.update(claim_before_edge=True, claim_id='places_seven_backside_cache', claim_area='C')
    frames = [{'tick': i, 'motor_steps': 1, 'position': position.copy(),
               'body': [position[0]-12, -36.0, 24.0, 36.0], 'grounded': True,
               'supports': ['root']} for i in range(1, 25)]
    data = {'passed': True, 'failures': [], 'audio_released': True, 'layout': LAYOUT,
            'scope': FIXTURE_SCOPE if fixture else FORMAL_SCOPE, 'route': route,
            'seed': 'unit', 'map_index': 1, 'initial_fixture_spawn_override': fixture,
            'manual_motor_step': False, 'midroute_injection': False, 'resource_override': False,
            'initial': {'position': position.copy(), 'hook_enabled': True,
                        'double_enabled': False, 'wall_enabled': False},
            'final': {'position': position.copy()}, 'frames': frames,
            'manifest': {'layout_version': LAYOUT, 'map_index': 1,
                         'seed': 'unit/thorn_forest/map_1', 'spawn': [0.0, -18.0],
                         'areas': [{'id': 'C', 'position': position.copy()}, {'id': 'G', 'position': position.copy()}],
                         'platforms': [{'id': 'root', 'rect': [-100.0, 0.0, 400.0, 32.0]}],
                         'connections': [edge], 'routes': {route: ['e']}, 'route_goals': {route: 'G'},
                         'rewards': [{'id': 'places_seven_backside_cache', 'approach_route': route, 'resources': [
                             {'kind': 'coin', 'amount': 4}, {'kind': 'note', 'amount': 1}]}]},
            'itinerary': [step, {'kind': 'walk', 'edge_id': 'e', 'landing': position.copy(), 'step_index': 1, 'b': 'G'}],
            'completed': [{'leg': 0, 'edge_id': 'e', 'tick': 12, 'position': position.copy()}, {'leg': 1, 'edge_id': 'e', 'tick': 24, 'position': position.copy()}],
            'reward_transactions': [], 'modal_frames': [], 'pointer_events': []}
    if fixture:
        data['fixture'] = {'initial_fixture_spawn_override': True, 'area': 'C',
                           'motion_steps_before_override': 0, 'resource_or_health_override': False,
                           'original_formal_spawn': [0.0, -18.0], 'actual_fixture_spawn': position.copy()}
    if reward:
        before = {'claimed': {}, 'coins': 0, 'notes': 0, 'items': []}
        after = {'claimed': {'thorn_forest/map_1/places_seven_backside_cache': True},
                 'coins': 0 if note else 4, 'notes': 1 if note else 0, 'items': []}
        data['reward_transactions'] = [{'claim_id': 'places_seven_backside_cache', 'tick': 20,
                                        'before': before, 'after': after,
                                        'duplicate_before': copy.deepcopy(after), 'duplicate_after': copy.deepcopy(after)}]
        data['modal_frames'] = [{'paused': True, 'motion_steps': 17} for _ in range(5)]
        data['pointer_events'] = [{'kind': k, 'button_text': 'resource', 'position': [20, 20], 'rect': [10, 10, 30, 30]}
                                  for k in ('mouse_button_press', 'mouse_button_release')]
    return data


def verify(data, fixture=False, reward=False, note=False):
    script = 'tests/forest_places_fixture_runner.gd' if fixture else 'tests/forest_places_motor_runner.gd'
    name = 'map1_reward' if reward else 'map1_normal'
    validate_report(data, name, script, ['--map=1', '--seed=unit', '--route='+('reward' if reward else 'normal'),
                                       '--reward-index='+str(int(note))])


def airborne_record():
    program = [{'action': 'H', 'anchor': 'fruit'}, {'action': 'R', 'direction': [.8, .6]}]
    route = {'kind': 'airborne_chain', 'from_port': 'entry', 'to_port': 'crown', 'action_program': program}
    frames = [{'tick': i, 'motor_steps': 1, 'position': [128, 0] if i == 1 else [-64, -194],
               'grounded': i == 1 or i >= 13, 'crown_support': i >= 13,
               'program_index': 2 if i >= 8 else 0} for i in range(1, 25)]
    return {'passed': True, 'audio_released': True, 'scope': LOCAL_SCOPE, 'layout': 'backbranch_fruit_reversal',
            'route': 'main', 'place_variant': 0, 'initial_fixture_spawn_override': True,
            'manual_motor_step': False, 'midroute_injection': False, 'resource_override': False,
            'reached': True, 'failure': '', 'danger_contacts': [], 'frames': frames,
            'manifest': {'id': 'backbranch_fruit_reversal', 'variant': 0, 'spawn': [128, 0], 'goal': [-64, -194],
                         'goal_support_id': 'crown', 'routes': {'main': route}, 'action_program': program,
                         'chain_contract': {'continuous_airborne': True},
                         'ports': {'crown': {'position': [-64, -194], 'support_id': 'crown'}},
                         'platforms': [{'id': 'crown', 'rect': [-384, -176, 464, 32]}]},
            'requests': [{'kind': 'grapple', 'tick': 2, 'queued': True},
                         {'kind': 'shoot_release', 'tick': 8, 'queued': True, 'direction': [.8, .6]}],
            'events': [{'kind': 'hook_cast', 'tick': 2}, {'kind': 'hook_pull', 'tick': 3, 'target': 'fruit'},
                       {'kind': 'hook_contact_kick', 'tick': 4, 'target': 'fruit', 'hook_used_at_event': True},
                       {'kind': 'hook_kick', 'tick': 5, 'target': 'fruit', 'hook_used_at_event': False},
                       {'kind': 'shot_fired', 'tick': 8, 'direction': [.8, .6], 'serial': 7}]}


def verify_air(data):
    validate_report(data, 'local_back_0_main', 'tests/forest_exploration_place_runner.gd',
                    ['--layout=backbranch_fruit_reversal', '--place-variant=0', '--route=main'])


class PlacesReportGuard(unittest.TestCase):
    def test_formal_fixture_coin_note_positive_controls(self):
        verify(record())
        verify(record(fixture=True), fixture=True)
        verify(record(fixture=True, reward=True), fixture=True, reward=True)
        verify(record(fixture=True, reward=True, note=True), fixture=True, reward=True, note=True)

    def test_wrong_job_identity_and_scope(self):
        for key, value in [('route', 'other'), ('map_index', 2), ('seed', 'wrong'),
                           ('scope', FIXTURE_SCOPE), ('layout', 'forest-bible-world-v15')]:
            with self.subTest(key=key):
                data = record(); data[key] = value
                with self.assertRaises(ValueError): verify(data)

    def test_empty_or_coherently_truncated_itinerary_is_not_success(self):
        data = record(); data['completed'] = []; data['itinerary'] = []
        with self.assertRaises(ValueError): verify(data)
        data = record(); data['completed'].pop(); data['itinerary'].pop()
        with self.assertRaises(ValueError): verify(data)
        data = record(); data['manifest']['routes']['normal'] = []
        with self.assertRaises(ValueError): verify(data)

    def test_formal_cannot_inherit_fixture_teleport(self):
        data = record(fixture=True); data['scope'] = FORMAL_SCOPE
        with self.assertRaises(ValueError): verify(data)
        data['initial_fixture_spawn_override'] = False; data.pop('fixture')
        with self.assertRaises(ValueError): verify(data)

    def test_fixture_must_be_actual_area_before_motor_without_resource_write(self):
        for field, value in [('motion_steps_before_override', 1), ('area', 'G'),
                             ('resource_or_health_override', True), ('actual_fixture_spawn', [999, 0])]:
            with self.subTest(field=field):
                data = record(fixture=True); data['fixture'][field] = value
                with self.assertRaises(ValueError): verify(data, fixture=True)

    def test_single_motor_body_support_and_contiguous_observation(self):
        for update in ({'motor_steps': True}, {'motor_steps': 2}, {'tick': 4},
                       {'body': [-12, -36, 1, 36]}, {'grounded': False}, {'supports': ['invented']}):
            with self.subTest(update=update):
                data = record(); data['frames'][0].update(update)
                with self.assertRaises(ValueError): verify(data)
        data = record(); data['final']['position'] = [999, -18]
        with self.assertRaises(ValueError): verify(data)

    def test_reward_requires_actual_selected_OR_and_idempotency(self):
        data = record(fixture=True, reward=True); data['reward_transactions'] = []
        with self.assertRaises(ValueError): verify(data, fixture=True, reward=True)
        data = record(fixture=True, reward=True)
        with self.assertRaises(ValueError): verify(data, fixture=True, reward=True, note=True)
        for field in ('after', 'duplicate_before', 'duplicate_after'):
            data = record(fixture=True, reward=True)
            data['reward_transactions'][0][field]['notes'] += 1
            with self.subTest(field=field), self.assertRaises(ValueError): verify(data, fixture=True, reward=True)
        data = record(fixture=True, reward=True); data['pointer_events'] = []
        with self.assertRaises(ValueError): verify(data, fixture=True, reward=True)
        data = record(fixture=True, reward=True); data['modal_frames'][0]['motion_steps'] += 1
        with self.assertRaises(ValueError): verify(data, fixture=True, reward=True)

    def test_world_duplicate_corpus_and_union_empty_rows_rejected(self):
        data = {'assertions': 165, 'failures': [], 'samples': [{'map_index': 1, 'root_seed': 'forest-places-00'}]*20}
        with self.assertRaises(ValueError): validate_report(data, 'world', '', [])
        data = {'assertions': 1, 'failures': [], 'rows': [{}, {}]}
        with self.assertRaises(ValueError): validate_report(data, 'union', '', [])


    def test_new_local_module_identity_and_real_airborne_events(self):
        verify_air(airborne_record())
        data = airborne_record(); data['manifest']['id'] = 'seven_bough_reveal'
        with self.assertRaises(ValueError): verify_air(data)
        for kind in ('hook_contact_kick', 'hook_pull', 'hook_kick', 'shot_fired'):
            data = airborne_record(); data['events'] = [e for e in data['events'] if e['kind'] != kind]
            with self.subTest(missing=kind), self.assertRaises(ValueError): verify_air(data)
        data = airborne_record(); data['events'][2]['target'] = 'another_fruit'
        with self.assertRaises(ValueError): verify_air(data)
        data = airborne_record(); data['events'].append({'kind': 'actual_ordinary_leg_complete'})
        with self.assertRaises(ValueError): verify_air(data)
        data = airborne_record(); data['events'][-1]['serial'] = 0
        with self.assertRaises(ValueError): verify_air(data)
        data = airborne_record(); data['events'][-1]['tick'] = 4
        with self.assertRaises(ValueError): verify_air(data)
        data = airborne_record(); data['requests'][0]['queued'] = False
        with self.assertRaises(ValueError): verify_air(data)

    def test_airborne_receiver_must_have_twelve_real_full_foot_frames(self):
        for mutation in ({'grounded': False}, {'crown_support': False}, {'position': [999, -194]}):
            data = airborne_record(); data['frames'][-12].update(mutation)
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): verify_air(data)
        data = airborne_record(); data['frames'][3]['grounded'] = True
        with self.assertRaises(ValueError): verify_air(data)

    def test_new_cache_rewards_use_their_own_authored_OR_amount(self):
        for cache, coin, note in [('places_z_cache', 6, 2), ('places_fallen_cache', 4, 1), ('places_backbranch_cache', 5, 2)]:
            for pick_note in (False, True):
                data = record(fixture=True, reward=True, note=pick_note)
                old = 'places_seven_backside_cache'
                for leg in data['itinerary']:
                    if leg.get('claim_id') == old: leg['claim_id'] = cache
                edge = data['manifest']['connections'][0]; edge['claim_id'] = cache
                reward = data['manifest']['rewards'][0]; reward['id'] = cache
                reward['resources'] = [{'kind': 'coin', 'amount': coin}, {'kind': 'note', 'amount': note}]
                tx = data['reward_transactions'][0]; tx['claim_id'] = cache
                for field in ('after', 'duplicate_before', 'duplicate_after'):
                    tx[field]['claimed'] = {'thorn_forest/map_1/'+cache: True}
                    tx[field]['coins'] = 0 if pick_note else coin
                    tx[field]['notes'] = note if pick_note else 0
                with self.subTest(cache=cache, note=pick_note): verify(data, fixture=True, reward=True, note=pick_note)

    def test_new_optional_jobs_cover_both_variants_and_explicit_failure_pose(self):
        jobs = _extra_feedback_jobs()
        self.assertEqual(len(jobs), 13)
        self.assertEqual(len({j[0] for j in jobs}), 13)
        self.assertEqual(sum(j[0].startswith('local_') for j in jobs), 8)
        self.assertTrue(all(j[4] == 240 for j in jobs))
        for map_index in (1, 2):
            job = next(j for j in jobs if j[0] == f'map{map_index}_z_failure')
            self.assertIn('--fixture-area=places_z__failure', job[2])
            self.assertIn('--route=places_z_failure_recovery_trial', job[2])


    def test_union_requires_all_six_new_real_contours(self):
        def row(module, variant):
            return {'module_id': module, 'variant': variant, 'solid_count': 10,
                    'edge_count': 12, 'internal_edges': []}
        data = {'assertions': 8000, 'failures': [],
                'rows': [row('seven_bough_reveal', i) for i in (0, 1)],
                'expansion_rows': [row(module, i) for module in ('z_descending_return', 'fallen_trunk_two_faces',
                                                               'backbranch_fruit_reversal') for i in (0, 1)]}
        validate_report(data, 'union', '', [])
        for defect in ('missing', 'duplicate', 'internal', 'empty', 'wrong_module'):
            bad = copy.deepcopy(data)
            if defect == 'missing': bad.pop('expansion_rows')
            elif defect == 'duplicate': bad['expansion_rows'][-1] = copy.deepcopy(bad['expansion_rows'][0])
            elif defect == 'internal': bad['expansion_rows'][0]['internal_edges'] = [[0, 0, 32, 0]]
            elif defect == 'empty': bad['expansion_rows'][0]['solid_count'] = 0
            else: bad['expansion_rows'][0]['module_id'] = 'seven_bough_reveal'
            with self.subTest(defect=defect), self.assertRaises(ValueError):
                validate_report(bad, 'union', '', [])


    def test_bounded_suite_selection_preserves_all_cases_without_duplicates(self):
        suites = {suite: jobs_for_suite(suite) for suite in ('core', 'library', 'all')}
        self.assertEqual({suite: len(jobs) for suite, jobs in suites.items()}, {'core': 20, 'library': 16, 'all': 33})
        ids = {suite: {j[0] for j in jobs} for suite, jobs in suites.items()}
        for suite, jobs in suites.items():
            self.assertEqual(len(ids[suite]), len(jobs))
            self.assertEqual(jobs[0][0], 'import')
            self.assertEqual(jobs[0][4], 90)
            self.assertTrue(all(j[4] == 240 for j in jobs[1:]))
        self.assertEqual(ids['core'] & ids['library'], {'import', 'world', 'union'})
        self.assertEqual(ids['all'], ids['core'] | ids['library'])
        expected_core = {'import', 'world', 'union', 'menu'}
        expected_core.update(f'local_{v}_{route}' for v in (0, 1)
                             for route in ('main', 'reward_return', 'failure_west_return', 'near_west_return'))
        expected_core.update(f'map{m}_{route}' for m in (1, 2) for route in ('normal', 'reward', 'return', 'windows'))
        self.assertEqual(ids['core'], expected_core)
        self.assertEqual(ids['library'] - {'import', 'world', 'union'}, {j[0] for j in _extra_feedback_jobs()})
        self.assertTrue({'map1_z_reward', 'map2_fallen_reward', 'map2_back_reward',
                         'map1_z_failure', 'map2_z_failure'} <= ids['library'])
        with self.assertRaises(ValueError): jobs_for_suite('silently_skip_failures')


if __name__ == '__main__':
    unittest.main()
