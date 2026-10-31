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
        # One explicit current-v15 retirement. These finite segment coordinates
        # come from the historical solids, independently of the reader builder.
        retired_index = len(m['dangers']) - 1
        self.assertEqual(m['dangers'][retired_index], [-903, 1296, 790, 18])
        retired = dict(instance_id='broken_arch', reason='unhosted_prototype_strip_210wu_below_broken_arch',
                       source_local_dangers=[[82, 100, 790, 18]], source_global_dangers=[[-903, 1296, 790, 18]],
                       source_danger_indices=[retired_index])
        m['dangers'].pop(); m['danger_presentations'].pop()
        broken = next(r for r in m['geometry_instances'] if r['id'] == 'broken_arch')
        broken['local_geometry']['dangers'] = []; broken['danger_indices'] = []
        broken['thorn_surface_derivation'] = copy.deepcopy(retired)
        m['thorn_surface_contract'] = dict(version='forest-bible-thorn-covered-platforms-v1',
            retired_prototype=retired, physical_delta='remove_exact_unhosted_prototype_strip_only', existing_supports_unchanged=True)
        plans = ([('down', [('hollow__belly_roof_upper', [380,170], [770,170])]),
                  ('up', [('hollow__belly_roof', [380,324], [640,324])]),
                  ('up', [('hollow__elbow_lower_lip', [770,414], [810,414]), ('hollow__trunk_above_window', [810,414], [930,414])]),
                  ('down', [('hollow__elbow_upper_lip', [770,210], [810,210]), ('hollow__trunk_upper_cap', [810,210], [930,210])])]
                 if index == 0 else
                 [('down', [('hollow__belly_roof_upper', [380,170], [810,170]), ('hollow__trunk_upper_cap', [810,170], [930,170])]),
                  ('up', [('hollow__belly_roof', [380,324], [640,324])]),
                  ('up', [('hollow__belly_roof', [770,324], [810,324]), ('hollow__trunk_above_window', [810,324], [930,324])])])
        plans += [('down', [('thorn_mouth__root_arch', [-1485,1170], [-1425,1170])]),
                  ('left', [('thorn_mouth__crown', [-1445,1256], [-1445,1308])])]
        m['thorn_surfaces'] = [dict(danger_index=i, face=face, hazard_rect=copy.deepcopy(m['dangers'][i]),
             segments=[dict(support_id=identity, start=start, end=end) for identity, start, end in segments])
             for i, (face, segments) in enumerate(plans)]
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
            # Complete old snapshots also lack the new explicit thorn contract;
            # reject them before their old F08/F05 geometry can be considered.
            self.assertIn('bible_malformed_manifest_or_authority', admission.validate_bible_admission(data))

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

    def test_thorn_retirement_keeps_all_other_dangers_and_old_reference(self):
        for index, count in ((0, 6), (1, 5)):
            data = self.fixture(index)
            m, old = data['manifest'], data['bible_admission']['reference_manifest']
            self.assertEqual(len(m['dangers']), count)
            self.assertEqual(m['dangers'], old['dangers'][:-1])
            self.assertEqual(m['danger_presentations'], old['danger_presentations'][:-1])
            self.assertEqual(old['dangers'][-1], [-903,1296,790,18])
            self.assertEqual(next(r for r in old['geometry_instances'] if r['id']=='broken_arch')['danger_indices'], [count])

    def test_thorn_retirement_contract_and_both_original_indices_are_required(self):
        self.reject(lambda d: d['manifest'].pop('thorn_surface_contract'))
        self.reject(lambda d: d['manifest']['thorn_surface_contract'].update(version='old'))
        self.reject(lambda d: d['manifest']['thorn_surface_contract'].update(existing_supports_unchanged=1))
        self.reject(lambda d: d['manifest']['thorn_surface_contract']['retired_prototype'].update(source_danger_indices=[]))
        self.reject(lambda d: next(r for r in d['manifest']['geometry_instances'] if r['id']=='broken_arch')['thorn_surface_derivation'].update(source_danger_indices=[]))

    def test_metadata_only_retirement_cannot_hide_the_actual_old_strip(self):
        def restore_physical(d):
            old = d['bible_admission']['reference_manifest']
            d['manifest']['dangers'] = copy.deepcopy(old['dangers'])
            d['manifest']['danger_presentations'] = copy.deepcopy(old['danger_presentations'])
        self.reject(restore_physical)
        self.reject(lambda d: next(r for r in d['manifest']['geometry_instances'] if r['id']=='broken_arch')['local_geometry'].update(dangers=[[82,100,790,18]]))
        self.reject(lambda d: next(r for r in d['manifest']['geometry_instances'] if r['id']=='broken_arch').update(danger_indices=[6]))

    def test_thorn_surface_metadata_cannot_create_a_fake_host(self):
        def fake_host(d):
            m = d['manifest']
            host = copy.deepcopy(m['platforms'][0]);host['id']='fake_carrier';host['rect']=[380,170,550,20]
            m['platforms'].append(host)
            m['thorn_surfaces'][0]['segments'][0]['support_id']='fake_carrier'
        self.reject(fake_host, 'actual_thorn_solid_union_faces')
        self.reject(lambda d: d['manifest']['danger_presentations'][0].update(host_support_id='fake_carrier'),
                    'exact_one_thorn_retirement')

    def test_thorn_union_requires_both_real_solids_and_exact_face(self):
        self.reject(lambda d: d['manifest']['thorn_surfaces'][2]['segments'].pop(0), 'actual_thorn_solid_union_faces')
        self.reject(lambda d: d['manifest']['thorn_surfaces'][2]['segments'][0]['end'].__setitem__(0, 809), 'actual_thorn_solid_union_faces')
        self.reject(lambda d: d['manifest']['thorn_surfaces'][-1].update(face='up'), 'actual_thorn_solid_union_faces')
        self.reject(lambda d: d['manifest']['thorn_surfaces'][0].update(danger_index=False), 'actual_thorn_solid_union_faces')

    def test_thorn_retirement_cannot_delete_or_move_a_second_danger(self):
        self.reject(lambda d: d['manifest']['dangers'].pop(0))
        self.reject(lambda d: d['manifest']['dangers'][0].__setitem__(2, 1), 'exact_one_thorn_retirement')
        self.reject(lambda d: next(r for r in d['manifest']['geometry_instances'] if r['id']=='broken_arch')['local_geometry']['action_program'].pop(), 'inherited_geometry_instances')

    def test_interwoven_ambient_gate_exempts_only_exact_v15_retirement(self):
        m = self.fixture()['manifest']
        leg = self.edge(m, 'root_bay_lesson_flight')
        instance = next(r for r in m['geometry_instances'] if r['id']==leg['geometry_instance'])
        self.assertEqual(region._validate_interwoven_binding(m, leg, instance), [])
        wrong = copy.deepcopy(m);wrong['dangers'].pop(0)
        for metadata in (wrong['thorn_surface_contract']['retired_prototype'],
                         next(r for r in wrong['geometry_instances'] if r['id']=='broken_arch')['thorn_surface_derivation']):
            metadata['source_danger_indices'] = [len(wrong['dangers'])]
        # This particular missing hollow danger is independently denied by the
        # full old-reference comparison even if not in ambient factory rows.
        data = self.fixture();data['manifest']=wrong
        self.assertTrue(admission.validate_bible_admission(data))
        old_label = copy.deepcopy(m);old_label['layout_version']=region.FRUIT_LAYOUT
        self.assertIn('interwoven_inherited_dangers', region._validate_interwoven_binding(old_label, leg, instance))
        data = self.fixture();data['manifest']=old_label
        self.assertIn('bible_distinct_actual_versions', admission.validate_bible_admission(data))

    def test_interwoven_ambient_gate_still_requires_every_other_factory_danger(self):
        m = self.fixture()['manifest']
        leg = self.edge(m, 'root_bay_lesson_flight')
        instance = next(r for r in m['geometry_instances'] if r['id']==leg['geometry_instance'])
        m['dangers'].remove([-1485,1142,60,44])
        for metadata in (m['thorn_surface_contract']['retired_prototype'],
                         next(r for r in m['geometry_instances'] if r['id']=='broken_arch')['thorn_surface_derivation']):
            metadata['source_danger_indices']=[len(m['dangers'])]
        self.assertIn('interwoven_inherited_dangers', region._validate_interwoven_binding(m, leg, instance))

    def test_reader_positive_cannot_substitute_for_physics(self):
        data = self.fixture()
        self.assertEqual(admission.validate_bible_admission(data), [])
        data.update(route='fast', seed='forest-depth-hollow-00', map_index=2, frames=[], events=[], requests=[])
        errors = region.validate(data)
        self.assertIn('continuous_single_motor_frames', errors)
        self.assertIn('incomplete_actual_route', errors)

    def test_bible_default_preserves_original_unpinned_budget_protocol(self):
        source = (ROOT / 'game/world/generation/thorn_forest_region_generator.gd').read_text()
        self.assertIn('const CURRENT_DEPTH_LAYOUT := DEPTH_LAYOUT_BIBLE', source)
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
