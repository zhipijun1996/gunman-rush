#!/usr/bin/env python3
"""Positive and deliberate corruptions of the actual runtime production inputs.

No synthetic 'good' manifest: setUpClass first requires the checked-in real
consumer chain to pass. Mutations change one real fragment in memory and must
fail the intended invariant, rather than benefiting from another missing file.
"""
from __future__ import annotations
import copy
import json
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from underworld_pipeline import ROOT, DEFAULT_MANIFEST, audit, canonical_mask


class UnderworldPipelineTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = audit()
        failures = [v for v in cls.baseline['checks'] if not v['passed']]
        if failures:
            raise AssertionError('Actual runtime production inputs fail baseline: ' + json.dumps(failures, ensure_ascii=False))
        cls.manifest = json.loads((ROOT / DEFAULT_MANIFEST).read_text())
        cls.fragments = {}
        for name in ['terrain','scenery','hazards']:
            rel = cls.manifest.get(name + '_manifest', cls.manifest.get(name))
            if isinstance(rel, dict):
                rel = rel['path']
            cls.fragments[name] = json.loads((ROOT / rel.removeprefix('res://')).read_text())

    def reject(self, section, mutate, expected):
        fragment = copy.deepcopy(self.fragments[section])
        mutate(fragment)
        result = audit(overrides={section: fragment})
        self.assertFalse(result['passed'])
        failures = {item['code'] for item in result['checks'] if not item['passed']}
        self.assertIn(expected, failures)

    def test_actual_runtime_consumer_manifest(self):
        self.assertTrue(self.baseline['passed'])
        self.assertEqual(self.baseline['measurements']['terrain']['canonical_masks'], 47)
        self.assertEqual(len(self.baseline['measurements']['backgrounds']), 3)

    def test_canonical_diagonal_rule(self):
        self.assertEqual(canonical_mask(2), 0)
        self.assertEqual(canonical_mask(7), 7)
        self.assertEqual(len({canonical_mask(i) for i in range(256)}), 47)

    def test_no_false_cc0(self):
        self.reject('terrain', lambda v: v.update(license='CC0'), 'reference.no_false_cc0')

    def test_wrong_native_scale(self):
        self.reject('terrain', lambda v: v.update(tile_px=64), 'terrain.native_pixel_scale')

    def test_missing_mask(self):
        self.reject('terrain', lambda v: v['mask_to_atlas'].pop('255'), 'terrain.mask_mapping')

    def test_wrong_corner_coordinate(self):
        self.reject('terrain', lambda v: v['mask_to_atlas'].update({'253':[0,0]}), 'terrain.mask_mapping')

    def test_missing_boundary_source_regions(self):
        self.reject('terrain', lambda v: v.update(source_regions={}), 'terrain.source_regions')

    def test_wrong_source_pixels(self):
        self.reject('terrain', lambda v: v.update(atlas='assets/style_exploration/cavern/terrain.png'), 'terrain.source_reconstruction')

    def test_no_fake_formal_tilemap_claim(self):
        self.reject('terrain', lambda v: v.update(mode='complete_47_tilemap'), 'terrain.honest_geometry_mode')

    def test_manifest_must_reach_runtime(self):
        self.reject('terrain', lambda v: v.update(consumer_scripts=['scripts/art_foundation/pixel_formal_terrain.gd']), 'terrain.read_by_runtime')

    def test_one_panorama_copied_three_times(self):
        def mutate(v):
            v['backgrounds'][1]['image'] = copy.deepcopy(v['backgrounds'][0]['image'])
            v['backgrounds'][2]['image'] = copy.deepcopy(v['backgrounds'][0]['image'])
        self.reject('scenery', mutate, 'background.independent_pixels')

    def test_same_camera_speed_is_rejected(self):
        self.reject('scenery', lambda v: v['backgrounds'][1].update(camera_factor=v['backgrounds'][0]['camera_factor']), 'background.ordered_factors')

    def test_invalid_speed(self):
        self.reject('scenery', lambda v: v['backgrounds'][2].update(camera_factor=[1.5,-1]), 'background.2.factor')

    def test_generation_record_cannot_be_a_template(self):
        self.reject('scenery', lambda v: v['backgrounds'][1].update(generation_record='assets/underworld_plains/terrain/terrain_build.json'), 'background.1.generation_record.prompt')

    def test_no_gameplay_rng_for_decor(self):
        self.reject('scenery', lambda v: v['decor'].update(independent_seed=False), 'decor.independent_seed')

    def test_missing_keepout(self):
        self.reject('scenery', lambda v: v['decor'].update(keepout_policy=''), 'decor.keepout')

    def test_missing_root_support(self):
        self.reject('scenery', lambda v: v['decor'].update(support_policy=''), 'decor.support')

    def test_no_collision_decor(self):
        self.reject('scenery', lambda v: v['decor'].update(collision=True), 'decor.no_collision')

    def test_preserve_danger_definition(self):
        self.reject('hazards', lambda v: v['semantics'].update(damage_source='duplicated_damage_default'), 'hazards.damage_source')

    def test_do_not_add_solid_base(self):
        self.reject('hazards', lambda v: v['semantics'].update(collision_mutation=True), 'hazards.preserve_collision')

    def test_do_not_float_thorn_material(self):
        self.reject('hazards', lambda v: v['connection'].update(floating_base=True), 'hazards.no_floating_base')

    def test_hazard_must_have_same_material_family(self):
        self.reject('hazards', lambda v: v['connection'].update(material_family=''), 'hazards.material_family')

    def test_safe_to_danger_transition_variants(self):
        self.reject('hazards', lambda v: v['atlas'].update(columns=['middle']*4), 'hazards.transitions')

    def test_source_hash_corruption(self):
        self.reject('hazards', lambda v: v['source_image'].update(sha256='0'*64), 'hazards.source.sha256')


if __name__ == '__main__':
    unittest.main(verbosity=2)
