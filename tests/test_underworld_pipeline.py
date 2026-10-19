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


    def reject_json(self, path, mutate, expected):
        value = json.loads((ROOT / path).read_text())
        mutate(value)
        result = audit(json_overrides={path: value})
        self.assertFalse(result['passed'])
        self.assertIn(expected, {item['code'] for item in result['checks'] if not item['passed']})

    def test_native_grass_override_must_match_source(self):
        self.reject_json('assets/underworld_plains/decor/chime_props.json', lambda v: v['regions']['grass'].update(atlas='assets/style_exploration/cavern/terrain.png'), 'decor.grass.runtime_recipe')

    def test_native_grass_source_hash(self):
        self.reject_json('assets/underworld_plains/decor/provenance.json', lambda v: v['native_grass'].update(source_sha256='0'*64), 'decor.grass.source.sha256')

    def test_native_grass_license_required(self):
        self.reject_json('assets/underworld_plains/decor/provenance.json', lambda v: v['native_grass'].pop('license_record'), 'decor.grass.license')

    def test_native_grass_crop_must_fit_original(self):
        self.reject_json('assets/underworld_plains/decor/chime_props.json', lambda v: v['regions']['grass'].update(region=[170,32,32,16]), 'decor.region.grass.bounds')

    def test_native_grass_root_uses_real_alpha_foot(self):
        self.reject_json('assets/underworld_plains/decor/chime_props.json', lambda v: v['regions']['grass'].update(foot=[16,3]), 'decor.region.grass.actual_opaque_foot')

    def test_identity_crop_must_fit_original(self):
        self.reject_json('assets/underworld_plains/decor/chime_props.json', lambda v: v['regions']['well'].update(region=[2160,247,576,406]), 'decor.region.well.bounds')

    def test_identity_foot_must_be_inside_crop(self):
        self.reject_json('assets/underworld_plains/decor/chime_props.json', lambda v: v['regions']['clock_arch'].update(foot=[-1,548]), 'decor.region.clock_arch.foot_bounds')

    def test_identity_foot_must_match_actual_source_bottom(self):
        self.reject_json('assets/underworld_plains/decor/chime_props.json', lambda v: v['regions']['repair_shelter'].update(foot=[303,10]), 'decor.region.repair_shelter.actual_opaque_foot')

    def test_identity_runtime_recipe_not_independent_copy(self):
        self.reject_json('assets/underworld_plains/decor/identity_generation.json', lambda v: v['regions'][0].update(foot=[10,394]), 'decor.region.well.generation_recipe')

    def test_identity_actual_original_hash_required(self):
        self.reject_json('assets/underworld_plains/decor/identity_generation.json', lambda v: v.update(source_sha256='0'*64), 'decor.identity_generation.source_sha256')

    def test_identity_actual_generation_prompt_required(self):
        self.reject_json('assets/underworld_plains/decor/identity_generation.json', lambda v: v.update(prompt=''), 'decor.identity_generation.prompt')

    def test_identity_source_lineage_not_unrelated_atlas(self):
        self.reject_json('assets/underworld_plains/decor/chime_props.json', lambda v: v['regions']['well'].update(atlas='assets/underworld_plains/decor/chime_props.png'), 'decor.region.well.actual_generated_atlas')

    def test_missing_identity_source_record(self):
        self.reject('scenery', lambda v: v['decor'].update(identity_generation_record='assets/underworld_plains/decor/provenance.json'), 'decor.identity.complete_objects')

    def test_four_identity_roles_not_just_three_labels(self):
        self.reject('scenery', lambda v: v['decor']['identity_landmarks'].pop('creek_well'), 'decor.identity.four_roles')

    def test_local_background_spec_required(self):
        self.reject('scenery', lambda v: v['decor'].pop('local_composition'), 'local.spec_present')

    def test_local_architecture_cannot_be_foreground(self):
        self.reject('scenery', lambda v: v['decor']['local_composition'].update(z_index=0), 'local.background_z')

    def test_local_architecture_cannot_claim_solid_support(self):
        self.reject('scenery', lambda v: v['decor']['local_composition'].update(physical_support=True), 'local.physical_support')

    def test_local_architecture_cannot_add_collision(self):
        self.reject('scenery', lambda v: v['decor']['local_composition'].update(collision=True), 'local.collision')

    def test_local_architecture_cannot_claim_standing_edge(self):
        self.reject('scenery', lambda v: v['decor']['local_composition'].update(standing_edge=True), 'local.standing_edge')

    def test_local_architecture_depth_not_grounded_landmark(self):
        self.reject('scenery', lambda v: v['decor']['local_composition'].update(depth='grounded_landmark'), 'local.depth')

    def test_local_architecture_painted_base_source_required(self):
        self.reject('scenery', lambda v: v['decor']['local_composition']['painted_base'].update(source='assets/underworld_plains/decor/native_underworld.png'), 'local.same_painted_base')

    def test_local_architecture_painted_base_disclosure_required(self):
        self.reject('scenery', lambda v: v['decor']['local_composition']['painted_base'].update(description=''), 'local.painted_base.description')

    def test_local_architecture_actual_runtime_consumer_required(self):
        self.reject('scenery', lambda v: v['decor']['local_composition'].update(consumer_script='scripts/art_foundation/pixel_formal_terrain.gd'), 'local.read_by_runtime')

    def test_local_architecture_no_bright_playable_rim(self):
        self.reject('scenery', lambda v: v['decor']['local_composition'].update(fog_highlight='ffffff'), 'local.fog_highlight.runtime_readability')

    def test_local_architecture_no_green_playable_rim(self):
        self.reject('scenery', lambda v: v['decor']['local_composition'].update(fog_shadow='22ee00'), 'local.fog_shadow.runtime_readability')

    def test_local_architecture_uses_declared_runtime_limits(self):
        self.reject('scenery', lambda v: v['decor']['local_composition'].update(readability_limits={}), 'local.readability_contract')

    def test_local_architecture_positive_scale(self):
        self.reject('scenery', lambda v: v['decor']['local_composition'].update(target_height=0), 'local.positive_height')

    def test_local_architecture_socket_offsets_required(self):
        self.reject('scenery', lambda v: v['decor']['local_composition'].update(offset_x=[]), 'local.offset_x')

    def test_local_architecture_keepouts_required(self):
        self.reject('scenery', lambda v: v['decor']['local_composition'].update(functional_keepout=''), 'local.functional_keepout')


    def test_local_architecture_cannot_be_fully_transparent(self):
        self.reject('scenery', lambda v: v['decor']['local_composition'].update(opacity=0), 'local.visible_opacity')

    def test_local_architecture_cannot_accept_all_samples_hidden(self):
        self.reject('scenery', lambda v: v['decor']['local_composition'].update(maximum_solid_hidden_samples=v['decor']['local_composition']['total_visibility_samples']), 'local.visibility_budget')


if __name__ == '__main__':
    unittest.main(verbosity=2)
