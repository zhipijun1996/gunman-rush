"""Synthetic evidence-admission faults only; not actual Motor or art evidence."""
import copy
import re
import unittest
import test_visual_director as fixture
from run_plains_places_tests import numeric_shape, numeric_local_shape

vd = fixture.vd


class PlainsPlacesCaptureTests(unittest.TestCase):
    def test_numeric_variation_ignores_identity_and_rejects_invalid_coordinates(self):
        row = {'place_instances': [{'id': 'A', 'translation': [0, 0]}],
               'connections': [{'id': 'edge', 'path': [[10, 20], [200, 20]], 'gap_world': 160, 'rise_world': 0}]}
        renamed = copy.deepcopy(row)
        renamed['place_instances'][0]['id'] = 'renamed'
        renamed['connections'][0]['id'] = 'different-name-only'
        self.assertEqual(numeric_shape(row), numeric_shape(renamed))
        moved = copy.deepcopy(row)
        moved['connections'][0]['path'][1][0] += 40
        self.assertNotEqual(numeric_shape(row), numeric_shape(moved))
        for invalid in (float('nan'), True, '200'):
            broken = copy.deepcopy(row)
            broken['place_instances'][0]['translation'][0] = invalid
            with self.subTest(invalid=invalid), self.assertRaises(ValueError): numeric_shape(broken)

    def test_local_variation_requires_geometry_not_place_order_or_identity(self):
        row = {'local_terrain': [[[[0, 0], [100, 0], [100, 80], [0, 80]]],
                                 [[[0, 0], [50, 0], [25, 40]]]]}
        renamed = copy.deepcopy(row)
        renamed['local_terrain'].reverse()
        for place in renamed['local_terrain']:
            for polygon in place:
                polygon.reverse()
                polygon[:] = polygon[1:] + polygon[:1]
        renamed['place_instances'] = [{'id': 'labels_do_not_count', 'translation': [10000, 20000]}]
        self.assertEqual(numeric_local_shape(row), numeric_local_shape(renamed))
        changed = copy.deepcopy(row)
        changed['local_terrain'][0][0][1][0] += 30
        self.assertNotEqual(numeric_local_shape(row), numeric_local_shape(changed))
        for invalid in (float('nan'), True, '100'):
            broken = copy.deepcopy(row)
            broken['local_terrain'][0][0][1][0] = invalid
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                numeric_local_shape(broken)
        for missing in ({}, {'local_terrain': []}, {'local_terrain': [[]]}):
            with self.subTest(missing=missing), self.assertRaises((ValueError, KeyError)):
                numeric_local_shape(missing)

    def setUp(self):
        fixture.VisualDirectorTests.setUp(self)
        script = vd.PLACES_CAPTURE
        self.request.update(capture_script=script, map_index=1, strategy='fast', encounter_policy='blind_legacy', environment_phase='full', environment_mutation='', visual_sample='', visual_layout='')
        self.data.update(map_index=1, strategy='fast', encounter_policy='blind_legacy', outcome='route_target_reached', route_reached=True)
        self.data['policy_basis'].update(encounter_policy='blind_legacy', reward_policy='legacy_auto_claim_v1')
        extension = {script: 'f' * 64, 'tests/plains_places_trace.gd': 'e' * 64}
        self.report['capture_extension'] = {'script': script, 'sources': extension}
        self.source.update(extension)
        self.report['source_after'] = copy.deepcopy(self.source)
        self.data['capture_extension_sources'] = {'res://' + p: h for p, h in extension.items()}
        self.data['visual_layout_treatment'] = 'original'
        self.data['visual_sample_treatment'] = {'catalog_path': '', 'catalog_sha256': ''}
        instances = [{'id': 'synthetic_instance_' + str(i), 'prototype_id': name, 'translation': [i * 100, 0], 'source_measurement_sha256': 'b' * 64} for i, name in enumerate(('wind_meadow', 'postal_valley', 'lee_court'))]
        waypoints = [row['id'] + '/stand' for row in instances]
        plan = {'place_instances': instances, 'place_order': [row['id'] for row in instances], 'prototype_order': [row['prototype_id'] for row in instances], 'route_waypoints': [{'id': key} for key in waypoints], 'safe_stands': [{'id': 'fixture'}], 'route_forward': waypoints, 'route_return': []}
        self.data['manifest']['environment_plan'] = plan
        self.data['environment_route_contract'] = {'phase': 'full', 'mutation': '', 'plan': copy.deepcopy(plan)}
        self.data['environment_initial_physics'] = {'fixture_not_runtime': True, 'art': {'omitted': []}, 'environment_plan': copy.deepcopy(plan), 'manifest_hash': self.data['manifest_hash'], 'production_pool': False}
        self.data['environment_final_physics'] = copy.deepcopy(self.data['environment_initial_physics'])
        self.data['environment_cases'] = [{'id': key, 'start_tick': i + 1, 'end_tick': i + 1, 'position': [i * 100, 0], 'passed': True, 'supported': True} for i, key in enumerate(waypoints)]
        self.data['places_route_contract'] = {key: copy.deepcopy(plan[key]) for key in ('place_instances', 'place_order', 'prototype_order')}
        self.data['places_waypoint_observations'] = [{'waypoint_id': case['id'], 'place_instance_id': row['id'], 'prototype_id': row['prototype_id'], **{key: case[key] for key in ('passed', 'start_tick', 'end_tick', 'position', 'supported')}} for row, case in zip(instances, self.data['environment_cases'])]
        self.data['edges'] = copy.deepcopy(self.data['environment_cases'])
        self.log = re.sub(r'LEVEL FORMAL CAPTURE:.*capture_errors=0', 'LEVEL FORMAL CAPTURE: 1 frames, 3 edges, outcome=route_target_reached, capture_errors=0', self.log)
        avatar = {'selected_id': 'p1_girl', 'painted_owner_count': 1, 'hero_states': ['fixture'], 'gameplay_changed': False, 'source_calibration': 'res://tests/observer_fixture.gd', 'source_sha256': self.source['tests/observer_fixture.gd'], 'texture_source': 'res://assets/fixture-bitmap.png', 'texture_sha256': self.source['assets/fixture-bitmap.png']}
        self.data['environment_avatar_initial'] = avatar
        self.data['environment_avatar_final'] = copy.deepcopy(avatar)
        self.data['captured_scope'].update(plains_places_candidate=True, pure_art_comparison_eligible=False)

    def test_exact_places_adapter_keeps_original_guards(self):
        self.assertEqual(vd.validate_native(self.data, self.report, self.log), [])
        command = vd.native_command(self.report, self.native, self.movie.with_suffix('.avi'))
        self.assertEqual(command[command.index('--script') + 1], vd.PLACES_CAPTURE)
        self.assertIn('--environment-phase=full', command)
        for mutation in ('scope', 'teleport', 'source_drift', 'driver_bytes', 'engine_error', 'exit_leak', 'initial_art_omission', 'final_art_omission', 'missing_art'):
            data, report, log = copy.deepcopy(self.data), copy.deepcopy(self.report), self.log
            if mutation == 'scope': data['captured_scope']['plains_places_candidate'] = False
            elif mutation == 'teleport': data['captured_scope']['actor_teleport_by_driver'] = True
            elif mutation == 'source_drift': report['source_after'][vd.PLACES_CAPTURE] = '0' * 64
            elif mutation == 'driver_bytes': data['capture_extension_sources']['res://' + vd.PLACES_CAPTURE] = '0' * 64
            elif mutation == 'engine_error': log += 'ERROR: synthetic renderer failure\n'
            elif mutation == 'exit_leak': log += 'WARNING: ObjectDB instances leaked at exit\n'
            elif mutation == 'initial_art_omission': data['environment_initial_physics']['art']['omitted'] = [{'reason': 'bridge_outside_declared_discrete_span'}]
            elif mutation == 'final_art_omission': data['environment_final_physics']['art']['omitted'] = [{'reason': 'missing_actual_terrain_consumer'}]
            elif mutation == 'missing_art': data['environment_final_physics'].pop('art')
            with self.subTest(mutation=mutation): self.assertTrue(vd.validate_native(data, report, log))

    def test_joint_consumer_requires_installed_body_bridge_and_attachment(self):
        plan = self.data['manifest']['environment_plan']
        plan['joint_synthesis'] = {'version': 1, 'same_source_contract': True}
        plan['terrain_instances'] = [{'id': 'body', 'solid_id': 'solid', 'uniform_scale': 0.4, 'source_profile_px': [[i, 0] for i in range(9)]}]
        plan['surfaces'] = [{'id': 'bridge_surface', 'kind': 'bridge'}]
        plan['attachments'] = [{'id': 'tree_attachment', 'role': 'tree'}]
        plan['layer_instances'] = [{'id': 'layer'}]
        art = {'omitted': [], 'layers': [{'id': 'layer'}],
               'terrain': [{'instance_id': 'body', 'solid_id': 'solid'}],
               'objects': [{'role': 'bridge', 'surface_id': 'bridge_surface'},
                           {'role': 'tree', 'attachment_id': 'tree_attachment'}],
               'joint_consumer': {'version': 1, 'bindings': [{'body_id': 'body', 'solid_id': 'solid',
                                                'installed_profile_points': 9,
                                                'max_display_to_collision_error_world': 0,
                                                'agrees': True}]}}
        for key in ('environment_initial_physics', 'environment_final_physics'):
            self.data[key]['environment_plan'] = copy.deepcopy(plan)
            self.data[key]['art'] = copy.deepcopy(art)
        self.data['environment_route_contract']['plan'] = copy.deepcopy(plan)
        self.assertEqual(vd.validate_native(self.data, self.report, self.log), [])
        for mutation in ('missing_binding', 'false_agreement', 'wrong_solid', 'nan_error',
                         'large_error', 'missing_bridge', 'missing_attachment', 'missing_body', 'missing_layer', 'wrong_receipt_version'):
            data = copy.deepcopy(self.data)
            observed = data['environment_final_physics']['art']
            if mutation == 'missing_binding': observed['joint_consumer']['bindings'] = []
            elif mutation == 'false_agreement': observed['joint_consumer']['bindings'][0]['agrees'] = False
            elif mutation == 'wrong_solid': observed['joint_consumer']['bindings'][0]['solid_id'] = 'unrelated'
            elif mutation == 'nan_error': observed['joint_consumer']['bindings'][0]['max_display_to_collision_error_world'] = float('nan')
            elif mutation == 'large_error': observed['joint_consumer']['bindings'][0]['max_display_to_collision_error_world'] = 0.5
            elif mutation == 'missing_bridge': observed['objects'].pop(0)
            elif mutation == 'missing_attachment': observed['objects'].pop(1)
            elif mutation == 'missing_body': observed['terrain'] = []
            elif mutation == 'missing_layer': observed['layers'] = []
            elif mutation == 'wrong_receipt_version': observed['joint_consumer']['version'] = 999
            with self.subTest(mutation=mutation):
                self.assertTrue(vd.validate_native(data, self.report, self.log))

    def test_prototype_claims_need_bound_real_cases(self):
        for mutation in ('missing_contract', 'duplicate_prototype', 'missing_visit', 'forged_position', 'wrong_prefix', 'wrong_order', 'bad_measurement', 'nan_translation'):
            data = copy.deepcopy(self.data)
            plan = data['manifest']['environment_plan']
            if mutation == 'missing_contract': data.pop('places_route_contract')
            elif mutation == 'duplicate_prototype': plan['place_instances'][1]['prototype_id'] = 'wind_meadow'
            elif mutation == 'missing_visit': data['places_waypoint_observations'].pop()
            elif mutation == 'forged_position': data['places_waypoint_observations'][0]['position'] = [999, 999]
            elif mutation == 'wrong_prefix': data['places_waypoint_observations'][0]['place_instance_id'] = plan['place_instances'][1]['id']
            elif mutation == 'wrong_order': plan['place_order'].reverse()
            elif mutation == 'bad_measurement': plan['place_instances'][0]['source_measurement_sha256'] = ''
            elif mutation == 'nan_translation': plan['place_instances'][0]['translation'][0] = float('nan')
            with self.subTest(mutation=mutation): self.assertTrue(vd.validate_native(data, self.report, self.log))

    def test_closure_includes_real_shared_driver_and_manual_preview(self):
        closure = vd.capture_extension_sources(vd.PLACES_CAPTURE)
        for name in ('tools/plains_places_preview.gd', 'tests/plains_places_trace.gd', 'tests/plains_environment_trace.gd', 'tests/level_formal_trace.gd', 'tools/observed_audio_teardown.gd'):
            self.assertIn(name, closure)
        for catalog in vd.VISUAL_SAMPLE_CATALOGS:
            self.assertFalse(vd.valid_visual_sample(vd.PLACES_CAPTURE, catalog))


if __name__ == '__main__':
    unittest.main()
