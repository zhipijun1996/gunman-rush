"""Synthetic evidence-admission faults only; not actual Motor or art evidence."""
import copy
import re
import unittest
import test_visual_director as fixture

vd = fixture.vd


class PlainsPlacesCaptureTests(unittest.TestCase):
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
        self.data['environment_initial_physics'] = {'fixture_not_runtime': True, 'environment_plan': copy.deepcopy(plan), 'manifest_hash': self.data['manifest_hash'], 'production_pool': False}
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
        for mutation in ('scope', 'teleport', 'source_drift', 'driver_bytes', 'engine_error', 'exit_leak'):
            data, report, log = copy.deepcopy(self.data), copy.deepcopy(self.report), self.log
            if mutation == 'scope': data['captured_scope']['plains_places_candidate'] = False
            elif mutation == 'teleport': data['captured_scope']['actor_teleport_by_driver'] = True
            elif mutation == 'source_drift': report['source_after'][vd.PLACES_CAPTURE] = '0' * 64
            elif mutation == 'driver_bytes': data['capture_extension_sources']['res://' + vd.PLACES_CAPTURE] = '0' * 64
            elif mutation == 'engine_error': log += 'ERROR: synthetic renderer failure\n'
            elif mutation == 'exit_leak': log += 'WARNING: ObjectDB instances leaked at exit\n'
            with self.subTest(mutation=mutation): self.assertTrue(vd.validate_native(data, report, log))

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
