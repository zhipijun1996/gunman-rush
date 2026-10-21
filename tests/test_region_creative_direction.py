"""Selected direction binding and short-prompt production boundaries, not artistic scoring."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import region_creative_direction as creative
import level_design
import production_loop


class CreativeTests(unittest.TestCase):
    def setUp(self):
        self.path = 'docs/creative_direction/thorn_forest.json'
        self.data = json.loads((creative.ROOT / self.path).read_text())

    def test_actual_recommendations_are_valid_but_never_player_or_runtime_acceptance(self):
        for path in ('windchime_plains', 'thorn_forest'):
            data, ref = creative.load_direction('docs/creative_direction/' + path + '.json', path)
            self.assertIn(data['acceptance'], {'professional_recommendation', 'user_confirmed'})
            if data['acceptance'] == 'professional_recommendation':
                self.assertEqual(data['user_acceptance'], 'unverified')
            else:
                self.assertEqual(data['user_acceptance'], 'direction_only_not_art_gameplay_or_device')
                self.assertIn('scope', data['user_evidence'])
            self.assertEqual(ref['sha256'], hashlib.sha256((creative.ROOT/ref['path']).read_bytes()).hexdigest())

    def test_historical_v2_bytes_keep_identity_and_reject_current_authority(self):
        expected = {
            'windchime_plains': '8f07e1c3d8fdd3553f7bf373075a52b2b900aac703b4789cead2cc5ebeeb0fa4',
            'thorn_forest': 'c79445e94ed41217ec326b0a928f1b6e723a754d66a8cc3eabcfd08e6c01b150',
        }
        for region, digest in expected.items():
            path = 'docs/creative_direction/archive/creative-v2/' + region + '.json'
            raw = (creative.ROOT/path).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(), digest)
            self.assertEqual(json.loads(raw)['version'], 'creative-v2')
            with self.assertRaisesRegex(ValueError, 'Authority changed'):
                creative.load_direction(path, region)

    def test_missing_theme_or_whole_screen_coverage_is_refused(self):
        for key in creative.COVERAGE:
            bad = copy.deepcopy(self.data); del bad[key]
            self.assertTrue(creative.validate_direction(bad), key)

    def test_candidate_comparison_cannot_be_empty_or_single_color_variant(self):
        self.data = json.loads((creative.ROOT/'docs/creative_direction/archive/creative-v3/thorn_forest.json').read_text())
        for mutate in ('single', 'duplicate', 'missing_comparison', 'unselected'):
            bad = copy.deepcopy(self.data)
            if mutate == 'single': bad['candidates'] = bad['candidates'][:1]
            if mutate == 'duplicate': bad['candidates'][1]['id'] = bad['candidates'][0]['id']
            if mutate == 'missing_comparison': del bad['candidates'][1]['ecology_boss']
            if mutate == 'unselected': bad['direction_id'] = 'uncompared'
            self.assertTrue(creative.validate_direction(bad), mutate)
        # Structural completeness does not prove real creative differences: independent review still required.

    def test_authority_changes_and_region_mismatch_fail_closed(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); (root/'authority.txt').write_text('old')
            data = json.loads((creative.ROOT/'docs/creative_direction/archive/creative-v3/thorn_forest.json').read_text())
            data['authority_sources'] = [{'path':'authority.txt','sha256':hashlib.sha256(b'old').hexdigest()}]
            (root/'direction.json').write_text(json.dumps(data))
            creative.load_direction('direction.json', 'thorn_forest', root)
            with self.assertRaisesRegex(ValueError, 'another region'):
                creative.load_direction('direction.json', 'windchime_plains', root)
            (root/'authority.txt').write_text('new')
            with self.assertRaisesRegex(ValueError, 'Authority changed'):
                creative.load_direction('direction.json', 'thorn_forest', root)

    def test_short_prompt_starts_creative_work_before_assets_or_terrain(self):
        mission = level_design.route_request('制作荆棘森林')
        production_loop.validate(mission)
        self.assertEqual(mission['phase'], 'production')
        self.assertEqual(len(mission['tasks']), 9)
        self.assertEqual(mission['region_bible']['bible_id'], 'thorn_forest_v2')
        self.assertNotIn('continuation', mission)
        self.assertEqual(mission['human_acceptance'], 'unverified')
        proposed = level_design.route_request('制作萤雾沼泽')
        self.assertEqual(proposed['phase'], 'preproduction')
        self.assertEqual(proposed['tasks'][0]['skills'], ['region-creative-director'])
        self.assertNotIn('scripts/', proposed['tasks'][0]['allowed_paths'])
        self.assertEqual(len(proposed['production_plan']), 9)

    def test_selected_direction_binds_every_specialist_and_retains_stage_gates(self):
        mission = level_design.route_request('制作荆棘森林', direction=self.path)
        production_loop.validate(mission)
        self.assertEqual(mission['phase'], 'production')
        for task in mission['tasks']:
            self.assertEqual(task['creative_direction']['region_id'], 'thorn_forest')
            self.assertEqual(task['creative_direction']['version'], 'creative-v6')
            self.assertEqual(task['feedback_context'], 'compact')
        self.assertEqual(mission['tasks'][-1]['completion'], 'content')
        self.assertIn('G2', mission['tasks'][-2]['required_gates'])
        self.assertFalse(mission['preparation']['production_boundary']['formal_opening_authorized'])

    def test_engineering_prototype_stays_explicit_and_does_not_claim_region(self):
        mission = level_design.route_request('制作荆棘森林', phase='prototype', direction=self.path)
        self.assertEqual(mission['phase'], 'prototype')
        self.assertIn('forest-current-slice', mission['tasks'][0]['checks'])
        self.assertNotIn('forest-h-slice', mission['tasks'][0]['checks'])
        self.assertEqual(mission['tasks'][0]['region_proof']['kind'], 'technical_sample')
        self.assertEqual(mission['tasks'][0]['region_proof']['allowed_capabilities'], ['H'])
        self.assertEqual(mission['tasks'][0]['required_gates'], ['G0','G1'])
        self.assertEqual(mission['tasks'][0]['region_proof']['scope'], 'prototype')

    def test_shared_source_inventory_keeps_original_extra_dependencies_and_detects_changes(self):
        import level_formal
        extras = ['tools/run_plains_experience_golden_tests.py',
                  'tools/run_plains_redesign_spatial_tests.py', 'tools/harness/profiles.json']
        before = level_formal.source_files()
        expected = dict(before)
        expected.update({name: hashlib.sha256((creative.ROOT/name).read_bytes()).hexdigest() for name in extras})
        self.assertEqual(level_formal.source_files(extra_paths=extras), expected)
        for name in extras:
            self.assertIn(name, level_formal.source_files(extra_paths=extras))
        with self.assertRaises(ValueError):
            level_formal.source_files(extra_paths=['../outside'])
        with self.assertRaises(FileNotFoundError):
            level_formal.source_files(extra_paths=['missing_producer.py'])

    def test_direction_cannot_bind_another_region_or_unregistered_request(self):
        for request in ('优化风铃平原', '制作未知地下河'):
            with self.assertRaises(ValueError):
                level_design.route_request(request, direction=self.path)


if __name__ == '__main__':
    unittest.main()
