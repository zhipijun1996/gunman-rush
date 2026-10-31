"""Finite admission/consumer controls. Source checks do not claim native execution."""
import copy
import hashlib
from pathlib import Path
import re
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import run_forest_depth_enemies as enemies
import test_forest_bible_region_admission as fixture_module


class BibleTraceConsumerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixture_module.BibleAdmissionTests.setUpClass()
        cls.fixtures = fixture_module.BibleAdmissionTests()

    def fixture(self, index=0):
        return self.fixtures.fixture(index)

    def test_same_strict_reader_accepts_both_explicit_current_variants(self):
        for index in (0, 1):
            data = self.fixture(index)
            before = copy.deepcopy(data)
            enemies.strict_manifest_admission(data)
            self.assertEqual(data, before)

    def test_missing_reference_flags_and_changed_actual_body_reject(self):
        mutations = (
            lambda d: d.pop('bible_admission'),
            lambda d: d['bible_admission'].update(actual_validated=False),
            lambda d: d['bible_admission'].update(reference_validated=False),
            lambda d: d['bible_admission'].update(reference_manifest=copy.deepcopy(d['manifest'])),
            lambda d: d['manifest']['platforms'].pop(),
            lambda d: d['manifest'].update(candidate_overlay={'scope': 'historical_candidate'}),
        )
        for mutate in mutations:
            data = self.fixture()
            mutate(data)
            with self.subTest(mutate=mutate):
                with self.assertRaisesRegex(ValueError, 'Bible manifest admission rejected'):
                    enemies.strict_manifest_admission(data)

    def test_lift_and_crossbranch_cannot_bypass_strict_reader(self):
        for validate in (enemies.validate_lift_choice, enemies.validate_crossbranch):
            data = self.fixture()
            data.pop('bible_admission')
            with self.subTest(consumer=validate.__name__):
                with self.assertRaisesRegex(ValueError, 'Bible manifest admission rejected'):
                    validate(data)

    def test_historical_manifest_does_not_enter_new_reader(self):
        for layout in ('shared-tree-canopy-hunt-v10', 'forest-interwoven-canopy-v13', 'forest-fruit-routes-v14'):
            with patch('forest_bible_region_admission.validate_bible_admission', side_effect=AssertionError('old path changed')):
                enemies.strict_manifest_admission({'manifest': {'layout_version': layout}})

    def test_finite_v15_recipe_controls_keep_strict_reference_and_selected_mix(self):
        # Synthetic encounter events isolate this reader branch. The actual
        # complete native capture is replayed separately, without these mocks.
        def synthetic():
            d = self.fixture()
            d.update(map_index=2, ecology_strategy='west_jump', ecology_started=1, ecology_finished=2,
                     ecology_entry={'health': 5}, ecology_exit={'health': 5},
                     events=[{'kind': 'ecology_choice_started', 'primary': 'hollow_route__west_seed_watch', 'tick': 1},
                             {'kind': 'west_seed_actual_M_arrival', 'supports': ['hollow__belly'], 'tick': 2}])
            return d
        def validate(d):
            with patch('run_forest_depth_region.validate', side_effect=fixture_module.admission.validate_bible_admission), \
                 patch.object(enemies, 'validate_router_observation'):
                enemies.validate_formal_choice(d)
        validate(synthetic())
        for key, value in [('version', 'compact-authored-ecology-v3'), ('mix_consumed', False), ('selected_mix', 999)]:
            d = synthetic()
            # Even equal contract edits cannot make v15 use the historical v3
            # label, an unconsumed mix, or a mix foreign to the recorded seed.
            for manifest in (d['manifest'], d['bible_admission']['reference_manifest']):
                manifest['encounter_plan_contract'][key] = value
            with self.subTest(field=key), self.assertRaises(ValueError): validate(d)
        d = synthetic(); d['manifest']['encounter_plan_contract']['recipe'] = 'foreign_recipe'
        with self.assertRaisesRegex(ValueError, 'Actual DemoApp route rejected'):
            validate(d)

    def test_formal_recipe_gate_always_keeps_full_route_reader_first(self):
        with patch('run_forest_depth_region.validate', return_value=['strict_route_sentinel']) as reader, \
             patch.object(enemies, 'validate_router_observation') as router:
            with self.assertRaisesRegex(ValueError, 'strict_route_sentinel'):
                enemies.validate_formal_choice({})
            reader.assert_called_once_with({})
            router.assert_not_called()

    def test_ecology_and_lift_only_migrate_owned_item_observations(self):
        expected = {'forest_depth_ecology_trace.gd': ('ba4e4a24c43c9eaadbf1d48730200c205bf575267fe7ca0608064519183a4016', 1),
                    'forest_depth_lift_trace.gd': ('d973cb63ddf29838dd168e9f39584ce290b3ef805805264309b05685337a5762', 3)}
        # Ownership telemetry now reads the inventory. Reverse only these exact
        # 1/3 observations; every other strategy byte keeps its original SHA.
        owned = b'app.build.inventory.item_ids()'
        previous = b'app.build.item_ids()'
        for name, (digest, count) in expected.items():
            source = (ROOT / 'tests' / name).read_bytes()
            self.assertEqual(source.count(owned), count)
            self.assertNotIn(previous, source)
            self.assertEqual(hashlib.sha256(source.replace(owned, previous)).hexdigest(), digest)

    def test_three_thin_traces_share_real_support_without_physics_override(self):
        allowed = {'canopy_layout', 'interwoven_layout', 'woven_layout', 'begin', 'observe_actual_projectile', '_process', 'admission_evidence'}
        for new, old in (('region_auto', 'depth_region'), ('ecology', 'depth_ecology'), ('lift', 'depth_lift')):
            source = (ROOT / 'tests' / f'forest_bible_{new}_trace.gd').read_text()
            self.assertTrue(source.startswith(f'extends "res://tests/forest_{old}_trace.gd"'))
            expected = allowed | ({'owns_strategy_encounter', 'preserves_strategy_target', '_entry_prefix_owns_leg', 'drive_jump'} if new == 'ecology' else set())
            self.assertEqual(set(re.findall(r'^func (\w+)\(', source, re.M)), expected)
            self.assertIn('BIBLE_SUPPORT.install(self)\n\tawait super.begin()\n\tBIBLE_SUPPORT.bind(self)', source)
            self.assertIn('BIBLE_SUPPORT.process_reader(self)\n\tsuper._process(delta)', source)
            self.assertIn('super.observe_actual_projectile(serial)', source)

    def test_finite_encounter_ownership_preserves_prefix_and_finished_choices(self):
        # Evaluate only this resource-free boolean predicate's shared Python/
        # GDScript syntax. This source control does not claim native execution.
        source = (ROOT / 'tests/forest_bible_ecology_trace.gd').read_text()
        body = source.split('func owns_strategy_encounter(leg: Dictionary) -> bool:\n', 1)[1].split('\nfunc ', 1)[0]
        body = body.replace('var edge: String =', 'edge =')
        body = re.sub(r'\btrue\b', 'True', body)
        body = re.sub(r'\bfalse\b', 'False', body)
        def owns(mode, edge, finished=-1, enabled=True, formal=False):
            namespace = {'ecology_strategy': mode, 'ecology_finished': finished,
                         'ecology_enabled': enabled, 'crossbranch_formal': formal}
            exec(compile('def owns(leg):\n' + body, '<finite-ownership-source-control>', 'exec'), namespace)
            return namespace['owns']({'edge_id': edge})
        for mode in ('live_H', 'shoot_clear', 'wait_phase', 'fixed_route_continue', 'stand_danger'):
            self.assertTrue(owns(mode, 'crown_prep'))
            self.assertFalse(owns(mode, 'crown_prep', finished=10))
            self.assertFalse(owns(mode, 'crown_prep', enabled=False))
        for mode in ('entry_clear', 'entry_wait', 'entry_hold'):
            self.assertTrue(owns(mode, 'belly_borer_access'))
            self.assertFalse(owns(mode, 'belly_borer_access', finished=10))
            self.assertFalse(owns('wait_phase', 'belly_borer_access'))
        for mode in ('west_clear', 'west_wait', 'west_jump'):
            self.assertTrue(owns(mode, 'west_to_belly'))
            self.assertFalse(owns(mode, 'west_to_belly', finished=10))
            self.assertFalse(owns('wait_phase', 'west_to_belly'))
        self.assertTrue(owns('crossbranch_physics', 'cavity_prep', enabled=False, formal=True))
        self.assertFalse(owns('crossbranch_physics', 'cavity_prep', enabled=False, formal=False))
        for edge in ('root_bay_lesson', 'lower_fork_approach', 'canopy_fork_approach', 'woven_descent', 'outer_to_inner'):
            self.assertFalse(owns('wait_phase', edge))
        support = (ROOT / 'tests/forest_bible_trace_support.gd').read_text()
        grove = support.split('class GrovePilot', 1)[1].split('class CrownPilot', 1)[0]
        self.assertLess(grove.index('owns_strategy_encounter(leg)'), grove.index('return super.drive(trace,leg)'))

    def test_only_exact_entry_strategy_subject_is_reserved_across_prefix(self):
        source = (ROOT / 'tests/forest_bible_ecology_trace.gd').read_text()
        body = source.split('func preserves_strategy_target(enemy_id: String) -> bool:\n', 1)[1].split('\nfunc ', 1)[0].split('\nvar ', 1)[0]
        for mode in ('entry_clear', 'entry_wait', 'entry_hold', 'wait_phase', 'west_wait', 'crossbranch_live_H'):
            for finished in (-1, 500):
                namespace = {'ecology_strategy': mode, 'ecology_finished': finished}
                exec(compile('def preserves(enemy_id):\n' + body, '<finite-target-source-control>', 'exec'), namespace)
                for target in ('hollow_route__borer_entry_thread', 'hollow_route__outer_watch', 'root_spiral_bark_keeper', 'hollow_route__west_seed_watch'):
                    expected = mode.startswith('entry_') and finished < 0 and target == 'hollow_route__borer_entry_thread'
                    self.assertEqual(namespace['preserves'](target), expected)
        original = (ROOT / 'tests/forest_depth_grove_combat_case.gd').read_text()
        hook = original.split('func _eligible_target(', 1)[1].split('\nfunc ', 1)[0]
        self.assertEqual([line.strip() for line in hook.splitlines()[1:] if line.strip() and not line.lstrip().startswith('#')], ['return true'])
        self.assertLess(original.index('if not _eligible_target(trace,row,actor):continue'), original.index('for id: String in trace.supports():'))
        support = (ROOT / 'tests/forest_bible_trace_support.gd').read_text().split('class GrovePilot', 1)[1].split('class CrownPilot', 1)[0]
        self.assertIn('trace.preserves_strategy_target(str(row.id))', support)
        self.assertIn('return super._eligible_target(trace,row,actor)', support)

    def test_entry_prefix_input_override_is_exact_and_uses_real_actions(self):
        source = (ROOT / 'tests/forest_bible_ecology_trace.gd').read_text()
        body = source.split('func _entry_prefix_owns_leg(leg: Dictionary) -> bool:\n', 1)[1].split('\nfunc ', 1)[0]
        leg = {'edge_id': 'west_to_belly', 'kind': 'jump_gap', 'from_support_id': 'west_court', 'support_id': 'hollow__belly_entry'}
        namespace = {'map_index': 1, 'ecology_finished': -1, 'ecology_strategy': 'entry_wait'}
        exec(compile('def owns(leg):\n' + body, '<finite-prefix-source-control>', 'exec'), namespace)
        self.assertTrue(namespace['owns'](leg))
        for field, value in [('edge_id', 'belly_borer_access'), ('kind', 'walk'), ('from_support_id', 'hollow__belly_west'), ('support_id', 'hollow__belly_west')]:
            self.assertFalse(namespace['owns']({**leg, field: value}))
        for field, value in [('map_index', 2), ('ecology_finished', 10), ('ecology_strategy', 'wait_phase')]:
            old = namespace[field]; namespace[field] = value
            self.assertFalse(namespace['owns'](leg)); namespace[field] = old
        drive = source.split('func drive_jump(leg: Dictionary) -> void:\n', 1)[1]
        self.assertIn('request(&"shoot_release",Vector2(-1,1))', drive)
        self.assertIn('super.drive_jump(leg)', drive)
        self.assertIn('not _entry_prefix_drop_requested and player.is_on_floor() and full_support("borer_access_low")', drive)
        self.assertIn('jump(false);request(&"drop_through");_entry_prefix_drop_requested=true', drive)
        self.assertNotRegex(drive, r'\bage\s*=|leg_started\s*=')
        self.assertNotRegex(drive, r'player\.global_position\s*=|health\.current\s*=|ecology_started\s*=|attack_behavior\.state\s*=')

    def test_conflicting_historical_cli_override_refuses_before_engine(self):
        for args in (['--scenario', 'expedition'], ['--scenario', 'root_entry', '--map', '2'],
                     ['--scenario', 'crossbranch', '--crossbranch-strategies', 'lifecycle']):
            result = subprocess.run([sys.executable, str(ROOT / 'tools/run_forest_depth_enemies.py'), *args,
                                     '--layout', 'forest-bible-world-v15'], capture_output=True, text=True, cwd=ROOT)
            self.assertEqual(result.returncode, 2)
            self.assertIn('Historical coordinate fixtures require their original explicit v10 layout', result.stderr)


if __name__ == '__main__':
    unittest.main()
