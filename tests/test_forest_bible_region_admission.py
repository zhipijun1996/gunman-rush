"""Finite reader controls; these synthetic fixtures never certify Motor play."""
import ast
import copy
import gzip
import hashlib
import json
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import forest_bible_region_admission as admission
import run_forest_depth_region as region


class BibleAdmissionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path = ROOT / 'tests/fixtures/forest_bible_admission_recorded_map2.json.gz'
        provenance = json.loads(path.with_name('forest_bible_admission_recorded_map2.provenance.json').read_text())
        if hashlib.sha256(path.read_bytes()).hexdigest() != provenance['fixture_sha256']:
            raise ValueError('Historical fixture bytes drifted')
        cls.recorded = json.loads(gzip.decompress(path.read_bytes()))

    def fixture(self, index=0):
        """Explicitly synthetic current-F08/F05-v3 reader data, not native output.

        Original snapshots stay byte-bound in the fixture and provenance. Only
        these declared F08 edits and explicit F05-v3 withdrawal are applied;
        no captured physics/health/results are manufactured or reused.
        """
        row = copy.deepcopy(self.recorded[index])
        m = row['manifest']
        # V3 withdraws the v2 solid extension that blocked the real approach.
        # Its physical rectangle equals historical v1; its explicit version
        # records the withdrawal. These reader controls are never played proof.
        next(r for r in m['platforms'] if r['id'] == 'bible_backbranch__broken_lower')['rect'] = [1790, 1080, 80, 140]
        instance = next(r for r in m['geometry_instances'] if r['id'] == 'bible_backbranch')
        instance['geometry_version'] = 'forest-bible-backbranch-v3'
        instance['local_geometry']['version'] = 'forest-bible-backbranch-v3'
        next(r for r in instance['local_geometry']['platforms'] if r['id'] == 'broken_lower')['rect'] = [1790, 1080, 80, 140]
        outside = row['name'] == 'outer'
        m['platforms'] = [r for r in m['platforms'] if r['id'] != 'bible_spiral_return_catch']
        mouth = 'bible_spiral_mouth' if outside else 'bible_inner_mouth'
        if outside:
            at = next(i for i, r in enumerate(m['platforms']) if r['id'].startswith('bible_backbranch__'))
            m['platforms'].insert(at, dict(id=mouth, rect=[835, 900, 85, 20], one_way=True,
                scene_kind='living_bough', structure_id='bible_root_tunnel', surface_role='spiral_east_mouth_receiver'))
        for structure in m['scene_structures']:
            if structure['id'] == 'bible_root_tunnel':
                structure['member_support_ids'] = [r['id'] for r in m['platforms'] if r.get('structure_id') == structure['id']]
        edge = self.edge(m, 'bible_spiral_other_exit')
        edge.update(b='R', kind='ordinary_sequence', path=[[400, 802], [430, 802], [875, 882], [980, 882], [1020, 882]],
                    steps=[{'kind': 'walk', 'landing': [430, 802], 'support_id': 'hollow__inner_root', 'bible_spiral_reader': True},
                           {'kind': 'drop_through', 'path': [[430, 802], [810, 802], [875, 882]],
                            'landing': [875, 882], 'support_id': mouth},
                           {'kind': 'jump_gap', 'takeoff': [905, 882], 'landing': [980, 882],
                            'from_support_id': mouth, 'support_id': 'hollow__outer_root', 'hold_until_ceiling_or_receiver': True}])
        m['routes']['bible_spiral_return'] = ['bible_spiral_other_exit'] + m['routes']['bible_backbranch_short_return'][1:]
        prefix = m['routes']['growth'][:m['routes']['growth'].index('broken_arch_flight') + 1]
        m['routes']['bible_spiral_journey'] = prefix + m['routes']['bible_spiral_approach'] + m['routes']['bible_spiral_return']
        m['bible_world_contract']['F08']['return_version'] = 'forest-bible-spiral-east-mouth-v1'
        return {'manifest': m, 'bible_admission': {'strategy': 'original_fixed_fps_Router_no_human_hold',
                'actual_validated': True, 'reference_validated': True, 'reference_manifest': row['reference_manifest']}}

    @staticmethod
    def edge(m, identity):
        return next(r for r in m['connections'] if r['id'] == identity)

    def reject(self, mutate, reason=None, index=0):
        data = self.fixture(index)
        mutate(data)
        errors = admission.validate_bible_admission(data)
        self.assertTrue(errors)
        if reason:
            self.assertIn('bible_' + reason, errors)

    def test_two_synthetic_reader_variants_and_no_input_mutation(self):
        for index in (0, 1):
            with self.subTest(index=index):
                data = self.fixture(index)
                original = copy.deepcopy(data)
                self.assertEqual(admission.validate_bible_admission(data), [])
                self.assertEqual(data, original)

    def test_original_historical_manifests_are_not_current_F08_passes(self):
        for index in (0, 1):
            data = self.fixture(index)
            data['manifest'] = self.recorded[index]['manifest']
            self.assertIn('bible_actual_added_platforms', admission.validate_bible_admission(data))

    def test_missing_wrong_or_self_relabelled_reference_rejected(self):
        for key in ('bible_admission',):
            self.reject(lambda d: d.pop(key))
        self.reject(lambda d: d['bible_admission'].pop('reference_manifest'))
        self.reject(lambda d: d['bible_admission'].update(reference_manifest=copy.deepcopy(d['manifest'])), 'distinct_actual_versions')
        for key, value in (('seed', 'foreign'), ('map_index', 1), ('player_tuning_hash', 'foreign')):
            with self.subTest(key=key):
                self.reject(lambda d: d['bible_admission']['reference_manifest'].update({key: value}), 'same_reference_seed_map_tuning')

    def test_native_flags_or_human_strategy_cannot_substitute(self):
        for key in ('actual_validated', 'reference_validated'):
            for value in (False, 1, 'true', None):
                with self.subTest(key=key, value=value):
                    self.reject(lambda d: d['bible_admission'].update({key: value}), 'actual_native_validation_and_strategy')
        self.reject(lambda d: d['bible_admission'].update(strategy='human_aim'), 'actual_native_validation_and_strategy')

    def test_all_original_row_categories_remain_equal(self):
        for category in ('platforms', 'hook_anchors', 'areas', 'connections', 'enemies', 'rewards',
                         'geometry_instances', 'fruit_boughs', 'scene_structures'):
            with self.subTest(category=category):
                self.reject(lambda d: d['manifest'][category][0].update(unreviewed=True), 'inherited_' + category)

    def test_original_routes_and_streams_cannot_be_changed(self):
        for category in ('routes', 'choices', 'enemy_drops', 'streams', 'stream_positions', 'scene_structure_kinds'):
            with self.subTest(category=category):
                self.reject(lambda d: d['manifest'][category].pop(next(iter(d['bible_admission']['reference_manifest'][category]))),
                            'inherited_' + category)

    def test_v14_closed_fruit_reader_is_still_exact(self):
        self.reject(lambda d: d['bible_admission']['reference_manifest']['hook_anchors'][0]['position'].__setitem__(0, 123456),
                    'separate_v14_fruit_reference')

    def test_actual_added_platform_and_factory_cannot_move(self):
        self.reject(lambda d: next(r for r in d['manifest']['platforms'] if r['id'] == 'bible_root_step1')['rect'].__setitem__(0, 1),
                    'actual_added_platforms')
        self.reject(lambda d: next(r for r in d['manifest']['geometry_instances'] if r['id'] == 'bible_backbranch')['local_geometry']['action_program'].pop(),
                    'actual_added_factory')

    def test_missing_or_duplicated_added_body_rejected(self):
        self.reject(lambda d: d['manifest']['platforms'].pop())
        self.reject(lambda d: d['manifest']['platforms'].append(copy.deepcopy(d['manifest']['platforms'][-1])))

    def test_real_rooted_new_fruit_binding_rejected_if_moved(self):
        self.reject(lambda d: next(r for r in d['manifest']['hook_anchors'] if r['id'] == 'bible_backbranch__side_fruit')['fruit_stem_root'].__setitem__(0, 1),
                    'actual_added_fruit')

    def test_gate_is_reward_opened_not_generic_open(self):
        for key, value in (('condition', 'open'), ('shortcut_id', 'foreign'), ('claim_id', 'foreign'),
                           ('claim_before_edge', False), ('claim_area', 'foreign'), ('b', 'camp')):
            with self.subTest(key=key):
                self.reject(lambda d: self.edge(d['manifest'], 'bible_backbranch_shortcut').update({key: value}),
                            'actual_gate_claim_binding')

    def test_gate_record_and_actual_window_must_match(self):
        self.reject(lambda d: d['manifest']['forest_shortcuts'][0].update(unlock_reward_id='foreign'), 'actual_claim_opened_gate')
        self.reject(lambda d: d['manifest']['forest_shortcuts'][0]['rect'].__setitem__(2, 0), 'gate_matches_actual_opening')

    def test_wrong_reward_or_duplicate_reward_rejected(self):
        self.reject(lambda d: next(r for r in d['manifest']['rewards'] if r['id'] == 'bible_backbranch_cache').update(coins=4000),
                    'actual_new_reward')
        self.reject(lambda d: d['manifest']['rewards'].append(copy.deepcopy(d['manifest']['rewards'][-1])))

    def test_short_and_long_return_cannot_be_aliased(self):
        self.reject(lambda d: d['manifest']['routes'].update(bible_backbranch_short_return=d['manifest']['routes']['bible_backbranch_return']),
                    'actual_distinct_returns')

    def test_unsupported_F08_exit_cannot_be_restored(self):
        original = self.edge(self.recorded[0]['manifest'], 'bible_spiral_other_exit')
        self.reject(lambda d: self.edge(d['manifest'], 'bible_spiral_other_exit').update(copy.deepcopy(original)),
                    'actual_authored_edge/bible_spiral_other_exit')

    def test_failed_F05_v2_blocking_shape_cannot_use_current_v3_label(self):
        data = self.fixture()
        m = data['manifest']
        next(r for r in m['platforms'] if r['id'] == 'bible_backbranch__broken_lower')['rect'] = [1790, 1080, 80, 240]
        instance = next(r for r in m['geometry_instances'] if r['id'] == 'bible_backbranch')
        next(r for r in instance['local_geometry']['platforms'] if r['id'] == 'broken_lower')['rect'] = [1790, 1080, 80, 240]
        self.assertEqual(instance['geometry_version'], 'forest-bible-backbranch-v3')
        errors = admission.validate_bible_admission(data)
        self.assertIn('bible_actual_added_platforms', errors)
        self.assertIn('bible_actual_added_factory', errors)

    def test_F05_departure_and_actual_enemy_windows_cannot_change(self):
        self.reject(lambda d: self.edge(d['manifest'], 'bible_backbranch_flight').update(first_hook_requires_descent_below=0),
                    'actual_F05_program')
        self.reject(lambda d: next(r for r in d['manifest']['enemies'] if r['id'] == 'bible_double_window_weaver')['web_strands'].pop(),
                    'actual_new_enemy_and_windows')

    def test_pending_admission_and_H_only_remain_explicit(self):
        self.reject(lambda d: d['manifest'].update(production_pool=True), 'pending_H_only_admission')
        self.reject(lambda d: d['manifest'].update(requires=['grapple', 'double_jump']), 'pending_H_only_admission')
        self.reject(lambda d: d['manifest']['bible_world_contract'].update(native_verified=True), 'explicit_pending_world_contract')

    def test_reader_positive_cannot_substitute_for_physics(self):
        data = self.fixture()
        self.assertEqual(admission.validate_bible_admission(data), [])
        data.update(route='fast', seed='forest-depth-hollow-00', map_index=2, frames=[], events=[], requests=[])
        errors = region.validate(data)
        self.assertIn('continuous_single_motor_frames', errors)
        self.assertIn('incomplete_actual_route', errors)

    def test_original_default_and_budget_protocol_unchanged(self):
        source = (ROOT / 'scripts/generation/thorn_forest_region_generator.gd').read_text()
        self.assertIn('const CURRENT_DEPTH_LAYOUT := DEPTH_LAYOUT_FRUIT', source)
        profile = json.loads((ROOT / 'tools/harness/profiles.json').read_text())['checks']['forest-depth-region']
        self.assertEqual(profile['timeout_seconds'], 600)
        self.assertNotIn('--layout', profile['argv'])
        cases = region.corpus_cases()
        self.assertEqual(len(cases), 80)
        self.assertEqual(len(set(cases)), 80)
        self.assertEqual(cases[:16], [(s, m, r) for s, m in [('forest-depth-hollow-00', 1), ('forest-depth-hollow-02', 1),
                         ('forest-depth-hollow-00', 2), ('forest-depth-hollow-02', 2)] for r in region.ROUTES[:4]])
        self.assertEqual(set(cases), {(f'forest-depth-hollow-{s:02d}', m, r) for s in range(10) for m in (1, 2) for r in region.ROUTES[:4]})
        ast.parse((ROOT / 'tools/run_forest_depth_region.py').read_text())
        auto = (ROOT / 'tests/forest_bible_region_auto_trace.gd').read_text()
        self.assertNotIn('forest_player_aim_trace', auto)
        self.assertNotIn('Engine.time_scale', auto)
        self.assertNotIn('physics_tick(', auto)


if __name__ == '__main__':
    unittest.main()
