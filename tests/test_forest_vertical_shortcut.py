"""Synthetic reader adversaries only; these fixtures are not gameplay evidence."""
import importlib.util
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
spec = importlib.util.spec_from_file_location('shortcut_reader', ROOT/'tools/run_forest_vertical_shortcut.py')
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)


def reader_fixture():
    snapshot = {'config': {'tuning': 'unit-test'}, 'weapon': 'pulse_gun', 'tier': 1, 'hook_enabled': True, 'double_enabled': False, 'wall_enabled': False, 'health': 4}
    return {
        'scope': 'real_Motor_internal_noH_shortcut_after_real_HHRH_prefix',
        'manual_motor_step': False, 'position_or_resource_injection': False,
        'failures': [], 'audio_released': True, 'probe_started': 4,
        'initial_snapshot': snapshot.copy(), 'final_snapshot': snapshot.copy(),
        'completed_legs': [{'edge_id': 'root_spiral_approach'}, {'edge_id': 'root_spiral_flight'}],
        'manifest': {'layout_version': 'forest-woven-trunk-v12', 'platforms': [
            {'id': 'thorn_mouth__recovery', 'rect': [0, 100, 300, 40]},
            {'id': 'middle_fork__crown', 'rect': [0, -100, 300, 24], 'one_way': True}]},
        'frames': [{'tick': i+1, 'motor_steps': 1, 'position': [100, 82], 'grounded': True, 'supports': ['thorn_mouth__recovery'], 'shots': 2, 'energy': 80, 'health': 4} for i in range(24)],
        'events': [
            {'tick': 1, 'kind': 'hook_contact_kick', 'target': 'root_spiral__spiral_lower'},
            {'tick': 2, 'kind': 'hook_contact_kick', 'target': 'root_spiral__spiral_middle'},
            {'tick': 3, 'kind': 'shot_fired'},
            {'tick': 4, 'kind': 'hook_contact_kick', 'target': 'root_spiral__spiral_crown'},
            {'tick': 5, 'kind': 'jumped'}, {'tick': 6, 'kind': 'shot_fired', 'aim': [0, 1]},
            {'tick': 24, 'kind': 'shortcut_program_finished_on_real_recovery'}],
        'requests': [], 'shortcut_reached': False, 'negative_recovered': True,
    }


def recovery_reader_fixture():
    data = reader_fixture()
    data['scope'] = 'real_Motor_deep_H_recovery_after_real_prefix'
    data['recovery_reached'] = True
    data['manifest']['platforms'].append({'id': 'thorn_mouth__entry', 'rect': [0, -100, 300, 24], 'one_way': True})
    data['frames'] = []
    for tick in range(1, 81):
        airborne = 8 <= tick < 69
        hanging = any(a <= tick <= b for a, b in [(12, 23), (27, 38), (45, 56)])
        data['frames'].append({'tick': tick, 'motor_steps': 1, 'position': [100, -118 if tick >= 68 else 82-max(0,tick-56)*200/12], 'grounded': not airborne, 'supports': ['thorn_mouth__entry' if tick >= 69 else 'thorn_mouth__recovery'] if not airborne else [], 'shots': 1 if 57 <= tick < 69 else 2, 'energy': 80, 'health': 4, 'hook_state': 'hook_hang' if hanging else 'free'})
    data['events'] = data['events'][:4] + [{'tick': 8, 'kind': 'jumped'}, {'tick': 57, 'kind': 'shot_fired', 'aim': [0, 1]}, {'tick': 80, 'kind': 'retry_actual_mouth_arrival'}]
    data['requests'] = []
    for begin, target in [(9, 'thorn_retry_low_ring'), (24, 'thorn_retry_high_ring'), (42, 'thorn_retry_exit_ring')]:
        data['requests'].append({'tick': begin, 'kind': 'grapple', 'queued': True, 'aim': [0, -1]})
        for offset, state in enumerate(['hook_cast', 'hook_fly', 'hook_pull', 'hook_hang']):
            data['events'].append({'tick': begin+offset, 'kind': state, 'target': target, 'hook_tip': [100, 60]})
    data['manifest']['hook_anchors'] = [{'id': target, 'position': [100, 60], 'hang_enabled': True} for target in ['thorn_retry_low_ring', 'thorn_retry_high_ring', 'thorn_retry_exit_ring']]
    for frame in data['frames']:
        frame['body'] = [frame['position'][0]-12, frame['position'][1]-18, 24, 36]
        frame['hook_tip'] = [100, 60]
        frame['hook_start'] = [100, 76]
        for begin in [9, 24, 42]:
            if begin <= frame['tick'] < begin+3:
                frame['hook_state'] = ['hook_cast', 'hook_fly', 'hook_pull'][frame['tick']-begin]
    data['events'].sort(key=lambda e: e['tick'])
    return data


class ShortcutReaderTests(unittest.TestCase):
    def test_synthetic_reader_positive_only(self):
        self.assertEqual(reader.validate(reader_fixture()), [])

    def test_reject_removed_last_support(self):
        data = reader_fixture(); data['frames'][-1]['supports'] = []
        self.assertIn('negative_not_real_fullbody_recovery12', reader.validate(data))

    def test_reject_only_eleven_full_body_frames(self):
        data = reader_fixture(); data['frames'][-12]['position'] = [5, 82]
        self.assertIn('negative_not_real_fullbody_recovery12', reader.validate(data))

    def test_reject_privileged_resource_source(self):
        data = reader_fixture(); data['position_or_resource_injection'] = True
        self.assertIn('privileged_motion_or_resources', reader.validate(data))

    def test_reject_postprefix_hook_even_without_contact(self):
        data = reader_fixture(); data['requests'].append({'tick': 7, 'kind': 'grapple'})
        self.assertIn('postprefix_H_request', reader.validate(data))

    def test_reject_fake_upward_recoil(self):
        data = reader_fixture(); data['events'][5]['aim'] = [0, -1]
        self.assertIn('postprefix_actual_UPR_missing', reader.validate(data))

    def test_reject_infinite_ammo(self):
        data = reader_fixture(); data['frames'][7]['shots'] = 999
        self.assertIn('resource_bounds_or_death', reader.validate(data))

    def test_reject_airborne_refill_inside_capacity(self):
        data = reader_fixture()
        data['frames'][10]['grounded'] = False; data['frames'][10]['shots'] = 1
        data['frames'][11]['grounded'] = False
        self.assertIn('air_charge_refill_in_no_hit_strategy', reader.validate(data))

    def test_reject_forged_credit_whitelist(self):
        data = reader_fixture()
        data['frames'][10]['grounded'] = False; data['frames'][10]['shots'] = 1
        data['frames'][11]['grounded'] = False
        data['events'].append({'tick': 11, 'kind': 'actual_shot_energy_credit', 'fired_airborne': True})
        errors = reader.validate(data)
        self.assertIn('unexpected_hit_credit_in_controlled_no_hit_strategy', errors)
        self.assertIn('air_charge_refill_in_no_hit_strategy', errors)

    def test_reject_physical_crown_despite_false_flag(self):
        data = reader_fixture()
        for frame in data['frames'][4:16]:
            frame['position'] = [100, -118]; frame['supports'] = ['middle_fork__crown']
        self.assertIn('shortcut_still_physically_reached', reader.validate(data))

    def test_reject_death_or_timeout_as_negative_success(self):
        data = reader_fixture(); data['failures'] = ['shortcut_bounded_timeout/jump']; data['final_snapshot']['health'] = 0
        errors = reader.validate(data)
        self.assertIn('native_failure_or_cleanup', errors)
        self.assertIn('not_grapple_granted_or_dead', errors)


class RecoveryReaderTests(unittest.TestCase):
    def test_synthetic_recovery_reader_positive_only(self):
        self.assertEqual(reader.validate_recovery(recovery_reader_fixture()), [])

    def test_reject_recovery_target_substitution(self):
        data = recovery_reader_fixture()
        next(e for e in data['events'] if e.get('kind') == 'hook_hang')['target'] = 'thorn_retry_high_ring'
        self.assertIn('recovery_actual_hang_targets_wrong', reader.validate_recovery(data))

    def test_reject_short_actual_hang(self):
        data = recovery_reader_fixture(); data['frames'][22]['hook_state'] = 'free'
        self.assertTrue(any(e.startswith('recovery_actual_hang_not_held12/') for e in reader.validate_recovery(data)))

    def test_reject_twelve_selfreport_without_mouth_support(self):
        data = recovery_reader_fixture(); data['frames'][-1]['supports'] = []
        self.assertIn('recovery_not_actual_mouth_fullbody12', reader.validate_recovery(data))

    def test_reject_hang_far_from_ring(self):
        data = recovery_reader_fixture(); data['manifest']['hook_anchors'][0]['position'] = [10000, 10000]
        self.assertTrue(any(e.startswith('recovery_hang_tip_not_on_actual_ring') for e in reader.validate_recovery(data)))

    def test_reject_hang_body_teleport(self):
        data = recovery_reader_fixture(); data['frames'][14]['position'] = [10000, 10000]
        self.assertIn('unexplained_body_displacement', reader.validate_recovery(data))

    def test_reject_manifest_with_no_anchors(self):
        data = recovery_reader_fixture(); data['manifest']['hook_anchors'] = []
        self.assertTrue(any(e.startswith('missing_manifest_hanging_anchor/') for e in reader.validate_recovery(data)))

    def test_reject_hang_tip_teleport(self):
        data = recovery_reader_fixture()
        for f in data['frames']: f['hook_tip'] = [10000, 10000]
        self.assertIn('recovery_hang_tip_not_on_actual_ring', reader.validate_recovery(data))

    def test_reject_wrong_cast_origin(self):
        data = recovery_reader_fixture(); data['frames'][8]['hook_start'] = [999, 999]
        self.assertIn('recovery_hook_start_not_actual_cast_origin', reader.validate_recovery(data))

    def test_reject_actual_thorn_body_overlap(self):
        data = recovery_reader_fixture(); data['manifest']['dangers'] = [[90, 70, 20, 20]]
        self.assertIn('recovery_body_crossed_actual_thorns', reader.validate_recovery(data))

    def test_reject_hang_without_real_pull(self):
        data = recovery_reader_fixture()
        data['events'] = [e for e in data['events'] if not(e.get('kind') == 'hook_pull' and e.get('target') == 'thorn_retry_low_ring')]
        self.assertIn('recovery_H_state_sequence_missing', reader.validate_recovery(data))


if __name__ == '__main__':
    unittest.main()
