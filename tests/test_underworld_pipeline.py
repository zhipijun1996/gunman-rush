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
        for name in ['terrain','scenery','hazards','player_animation','mechanisms','home','ui']:
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


    def reject_text(self, path, old, new, expected):
        source = (ROOT / path).read_text()
        self.assertIn(old, source, 'Negative fixture must mutate actual current code')
        result = audit(text_overrides={path: source.replace(old,new)})
        self.assertFalse(result['passed'])
        self.assertIn(expected, {item['code'] for item in result['checks'] if not item['passed']})

    def test_new_four_real_consumer_sections(self):
        self.assertEqual(self.baseline['measurements']['player_animation']['body_frames'],20)
        self.assertEqual(self.baseline['measurements']['player_animation']['distinct_run_pixels'],8)
        self.assertEqual(self.baseline['measurements']['home']['slots'],12)
        self.assertEqual(self.baseline['measurements']['ui']['icons'],18)
        self.assertEqual(self.baseline['measurements']['ui']['ui_roots'],13)

    def test_missing_real_player_manifest(self):
        self.reject_json(DEFAULT_MANIFEST,lambda v:v.pop('player_animation_manifest'),'player_animation.manifest')

    def test_new_sections_must_reach_real_json_consumers(self):
        for key in ['player_animation','mechanisms','home','ui']:
            with self.subTest(key=key):
                self.reject_json(DEFAULT_MANIFEST,lambda v,k=key:v['consumers'].update({k:['scripts/art_foundation/pixel_formal_terrain.gd']}),key+'.read_by_runtime')

    def test_consumer_png_is_rejected_as_non_script_without_crashing(self):
        self.reject_json(DEFAULT_MANIFEST,lambda v:v['consumers'].update(player_animation=['assets/underworld_plains/player_animation/run_sheet.png']),'player_animation.consumer.decode')

    def test_player_missing_required_state(self):
        self.reject('player_animation',lambda v:v['animations'].pop('land'),'player.states')

    def test_player_missing_generated_frame(self):
        self.reject('player_animation',lambda v:v['frames'].pop(),'player.frame_count')

    def test_player_wrong_actual_frame_hash(self):
        self.reject('player_animation',lambda v:v['frames'][0].update(pixel_sha256='0'*64),'player.frame.0.pixel_sha256')

    def test_player_duplicate_body_frames_are_not_a_run_cycle(self):
        def mutate(v):
            first=copy.deepcopy(v['frames'][0])
            for i in range(8):
                v['frames'][i]=copy.deepcopy(first)
                v['frames'][i]['index']=i
        self.reject('player_animation',mutate,'player.real_run_cycle')

    def test_player_duplicate_indices(self):
        self.reject('player_animation',lambda v:v['frames'][0].update(index=1),'player.contiguous_frames')

    def test_player_bad_frame_crop(self):
        self.reject('player_animation',lambda v:v['frames'][0].update(rect=[100000,0,80,64]),'player.frame.0.bounds')

    def test_player_padded_canvas_is_not_body_height(self):
        self.reject('player_animation',lambda v:v.update(standing_body_source_height=64),'player.standing_opaque_height')

    def test_player_terminal_animation_cannot_loop(self):
        self.reject('player_animation',lambda v:v['animations']['death'].update(loop=True),'player.loop_semantics')

    def test_player_frame_anchor_must_match_recipe(self):
        self.reject('player_animation',lambda v:v.update(anchor=[40,10]),'player.recipe_anchor')

    def test_player_generated_source_hash_required(self):
        self.reject_json('assets/underworld_plains/player_animation/recipe.json',lambda v:v['pages'][0].update(source_sha256='0'*64),'player.page.0.source.sha256')

    def test_player_source_png_cannot_disappear(self):
        self.reject_json('assets/underworld_plains/player_animation/recipe.json',lambda v:v['pages'][1].update(source='generated/missing.png'),'player.page.1.source.exists')

    def test_player_generated_prompt_cannot_be_empty(self):
        self.reject_json('assets/underworld_plains/player_animation/generated/run_call.json',lambda v:v.update(prompt=''),'player.call.0.prompt')

    def test_player_packing_must_replay_actual_source_pixels(self):
        self.reject_json('assets/underworld_plains/player_animation/recipe.json',lambda v:v['pages'][0]['frames'][0].update(pivot_x=0),'player.source_reconstruction.run_sheet.png')

    def test_player_missing_runtime_left_mirror_is_rejected(self):
        self.reject_text('scripts/underworld_plains/underworld_player.gd','Vector2(facing,1.0)','Vector2.ONE','player.left_mirror')

    def test_player_aim_must_not_replace_move_facing(self):
        self.reject_text('scripts/underworld_plains/underworld_player.gd','facing = signf(motor.normal_velocity.x)','facing = signf(controller.router.aim_direction.x)','player.move_facing')

    def test_mechanism_source_hash_required(self):
        self.reject('mechanisms',lambda v:v['carrier'].pop('source_sha256'),'mechanisms.carrier.source.sha256')

    def test_mechanism_missing_source_rejected(self):
        self.reject('mechanisms',lambda v:v['carrier'].update(source='missing_carrier.png'),'mechanisms.carrier.source.exists')

    def test_mechanism_actual_texture_hash_required(self):
        self.reject('mechanisms',lambda v:v['carrier'].update(sha256='0'*64),'mechanisms.carrier.image.sha256')

    def test_mechanism_cap_source_bounds(self):
        self.reject('mechanisms',lambda v:v['carrier'].update(middle_x_px=95),'mechanisms.carrier.patch_bounds')

    def test_mechanism_no_fake_new_colliders(self):
        self.reject('mechanisms',lambda v:v.update(physics_mutation=True),'mechanisms.physics_unchanged')

    def test_mechanism_bell_aspect_required(self):
        self.reject('mechanisms',lambda v:v['bell'].update(sampling='stretch independent axes'),'mechanisms.bell.aspect')

    def test_mechanism_runtime_aspect_cannot_be_an_unused_label(self):
        self.reject_text('scripts/underworld_plains/underworld_terrain.gd','source * minf(','source * maxf(','mechanisms.runtime_bell_aspect')

    def test_mechanism_generation_record_is_real(self):
        self.reject_json('assets/underworld_plains/mechanisms/generation_call.json',lambda v:v.update(prompt=''),'mechanisms.generation.prompt')

    def test_mechanism_real_crop_reconstruction(self):
        self.reject_json('assets/underworld_plains/mechanisms/generation_call.json',lambda v:v.update(measured_alpha128_bbox_px=[0,0,96,16]),'mechanisms.carrier.source_reconstruction')

    def test_home_actual_generation_source_hash(self):
        self.reject_json('assets/underworld_plains/home/generation_record.json',lambda v:v.update(source_sha256='0'*64),'home.generation.raw_source.sha256')

    def test_home_asset_crop_must_be_inside_original(self):
        self.reject('home',lambda v:v['assets']['tailor'].update(region=[0,0,99999,1]),'home.asset.tailor.bounds')

    def test_home_foot_uses_actual_opaque_body(self):
        self.reject('home',lambda v:v['assets']['tailor'].update(foot=[93.5,1]),'home.asset.tailor.actual_opaque_foot')

    def test_home_height_uses_actual_opaque_body(self):
        self.reject('home',lambda v:v['assets']['tailor'].update(opaque_height=344),'home.asset.tailor.opaque_height')

    def test_home_reserved_plot_is_not_a_fake_active_service(self):
        self.reject('home',lambda v:v['slots'][4].update(active=True),'home.active_services')

    def test_home_duplicate_slot_ids(self):
        self.reject('home',lambda v:v['slots'][4].update(id='character'),'home.unique_slots')

    def test_home_slot_cannot_reference_nonexistent_source(self):
        self.reject('home',lambda v:next(slot for slot in v['slots'] if slot['id']=='arms').update(building='missing_house'),'home.slot.arms.source')

    def test_home_slots_within_actual_world(self):
        self.reject('home',lambda v:v['slots'][4].update(x=99999),'home.slot_bounds')

    def test_home_world_uses_shared_real_actor_height(self):
        self.reject('home',lambda v:v.update(player_height_source='104px_guess'),'home.safe_shared_height')

    def test_home_actual_uniform_scale_code(self):
        self.reject_text('scripts/underworld_plains/underworld_home_world.gd','sprite.scale=Vector2.ONE*factor','sprite.scale=Vector2(2,1)*factor','home.runtime_uniform_aspect')

    def test_ui_generated_source_missing(self):
        self.reject_json('assets/underworld_plains/ui/provenance.json',lambda v:v.update(original='missing_ui_source.png'),'ui.generated_original.exists')

    def test_ui_generated_source_hash_corrupt(self):
        self.reject_json('assets/underworld_plains/ui/provenance.json',lambda v:v.update(original_sha256='0'*64),'ui.generated_original.sha256')

    def test_ui_generated_prompt_cannot_be_a_template(self):
        self.reject_json('assets/underworld_plains/ui/provenance.json',lambda v:v.update(prompt=''),'ui.generation.prompt')

    def test_ui_runtime_atlas_hash_required(self):
        self.reject_json('assets/underworld_plains/ui/icon_regions.json',lambda v:v.update(sha256='0'*64),'ui.icons.atlas.sha256')

    def test_ui_missing_real_item_key(self):
        self.reject_json('assets/underworld_plains/ui/icon_regions.json',lambda v:v['regions'].pop('boots'),'ui.complete_item_keys')

    def test_ui_whole_object_crop_with_padding(self):
        self.reject_json('assets/underworld_plains/ui/icon_regions.json',lambda v:v['regions'].update(boots=[1189,93,257,219]),'ui.icon.boots.whole_object_padding')

    def test_ui_actual_source_measurement(self):
        self.reject_json('assets/underworld_plains/ui/icon_regions.json',lambda v:v['measurements']['boots'].update(native_body_alpha16=[0,0,2,2]),'ui.icon.boots.actual_source_bounds')

    def test_ui_panel_patch_corners_fit_source(self):
        self.reject('ui',lambda v:v['panel'].update(slice_margin=100),'ui.panel.slice_margin')

    def test_ui_panel_permission_label_cannot_cover_unrelated_pixels(self):
        self.reject('ui',lambda v:v['panel'].update(texture='assets/underworld_plains/mechanisms/source_carrier.png'),'ui.panel.native_reference')

    def test_ui_no_fake_cc0_reference(self):
        self.reject('ui',lambda v:v['panel'].update(source_license='CC0'),'ui.panel.custom_license')

    def test_ui_root_inventory_must_resolve_real_consumers(self):
        self.reject('ui',lambda v:v['production_roots'].__setitem__(0,'NonexistentMenu'),'ui.root.NonexistentMenu.actual_theme')

    def test_ui_aspect_is_actual_code(self):
        self.reject_text('scripts/ui/item_card.gd','STRETCH_KEEP_ASPECT_CENTERED','STRETCH_SCALE','ui.aspect.ItemCard')

    def test_ui_real_item_source_dispatch(self):
        self.reject_text('scripts/ui/item_presentation.gd','return UnderworldUI.icon(key)','return null','ui.actual_item_dispatch')

    def test_actual_entry_inventory_is_not_empty(self):
        self.reject_json(DEFAULT_MANIFEST,lambda v:v.update(runtime_entries=[]),'production.runtime_entries')

    def test_home_requires_current_terrace_contract(self):
        self.reject('home',lambda v:v.update(schema='unknown-future-layout'),'home.schema')

    def test_home_all_plots_cannot_collapse_to_one_floor(self):
        self.reject('home',lambda v:[slot.update(y=v['floor_y']) for slot in v['slots']],'home.three_tiers')

    def test_home_terrace_cannot_be_fake_solid(self):
        self.reject('home',lambda v:v['platforms'][0].update(one_way=False),'home.platform.0.one_way')

    def test_home_slot_cannot_float_between_tiers(self):
        self.reject('home',lambda v:v['slots'][1].update(y=333),'home.slot.upgrade.supported')

    def test_home_departure_must_follow_the_village_road(self):
        self.reject('home',lambda v:v['departure_road'].update(direction='west'),'home.departure_road')

    def test_objects_raw_generation_hash(self):
        self.reject_json('assets/underworld_plains/objects/objects_build.json',lambda v:v['generation'].update(source_sha256='0'*64),'objects.original.sha256')

    def test_objects_original_crop_bounds(self):
        self.reject_json('assets/underworld_plains/objects/objects_build.json',lambda v:v['opened_chest'].update(crop=[0,0,99999,2]),'objects.complete_crop')

    def test_objects_raised_lid_cannot_be_cropped_off(self):
        self.reject_json('assets/underworld_plains/objects/objects_build.json',lambda v:v['opened_chest'].update(crop=[241,300,1272,977]),'objects.whole_pose')

    def test_objects_runtime_requires_the_actual_open_pose(self):
        self.reject_text('scripts/underworld_plains/underworld_objects.gd','OPEN_CHEST if claimed else CLOSED_CHEST','CLOSED_CHEST if claimed else CLOSED_CHEST','objects.actual_dispatch')

    def test_objects_legacy_alpha_cannot_move_into_formal_branch(self):
        self.reject_text('scripts/demo/plains_region_stage.gd',
                         '\t\t\telse:\n\t\t\t\tUnderworldObjects.place_chest',
                         '\t\t\telse:\n\t\t\t\t(c.sprite as Sprite2D).modulate.a=0.35 if c.claimed else 1.0\n\t\t\t\tUnderworldObjects.place_chest',
                         'objects.no_grey_claimed')

    def test_objects_legacy_alpha_guard_cannot_invert(self):
        self.reject_text('scripts/demo/plains_region_stage.gd',
                         '\t\t\tif generated.has("regional_art_plan"):',
                         '\t\t\tif not generated.has("regional_art_plan"):',
                         'objects.no_grey_claimed')

    def test_objects_legacy_alpha_guard_cannot_disappear(self):
        self.reject_text('scripts/demo/plains_region_stage.gd',
                         '\t\t\tif generated.has("regional_art_plan"):\n',
                         '', 'objects.no_grey_claimed')

    def test_objects_legacy_alpha_cannot_leave_capture_consumer(self):
        path = 'scripts/demo/plains_region_stage.gd'
        source = (ROOT / path).read_text()
        start = source.index('\tfor c: Dictionary in chests:', source.index('func capture_state()'))
        end = source.index('\tfor p: Dictionary in pickups:', start)
        block = source[start:end]
        moved = source[:start] + source[end:] + '\nfunc wrong_chest_consumer() -> void:\n' + block
        result = audit(text_overrides={path: moved})
        self.assertFalse(result['passed'])
        self.assertIn('objects.no_grey_claimed', {item['code'] for item in result['checks'] if not item['passed']})

    def test_objects_duplicate_legacy_alpha_is_rejected(self):
        call = '\t\t\t\tUnderworldObjects.place_chest(c.sprite as Sprite2D,c.position+Vector2(0,21),bool(c.claimed))'
        self.reject_text('scripts/demo/plains_region_stage.gd',
                         call, call + '\n\t\t\t\t(c.sprite as Sprite2D).modulate . a = 0.8 if c.claimed else 1.0',
                         'objects.no_grey_claimed')

    def test_objects_legacy_alpha_value_cannot_change(self):
        self.reject_text('scripts/demo/plains_region_stage.gd',
                         '.modulate.a=0.35 if c.claimed',
                         '.modulate.a=0.9 if c.claimed',
                         'objects.no_grey_claimed')

    def test_objects_formal_alpha_multiply_is_rejected(self):
        call = '\t\t\t\tUnderworldObjects.place_chest(c.sprite as Sprite2D,c.position+Vector2(0,21),bool(c.claimed))'
        self.reject_text('scripts/demo/plains_region_stage.gd', call,
                         call + '\n\t\t\t\t(c.sprite as Sprite2D).modulate.a *= 0.35 if c.claimed else 1.0',
                         'objects.no_grey_claimed')

    def test_objects_formal_alpha_addition_is_rejected(self):
        call = '\t\t\t\tUnderworldObjects.place_chest(c.sprite as Sprite2D,c.position+Vector2(0,21),bool(c.claimed))'
        self.reject_text('scripts/demo/plains_region_stage.gd', call,
                         call + '\n\t\t\t\t(c.sprite as Sprite2D).modulate.a += -0.65 if c.claimed else 0.0',
                         'objects.no_grey_claimed')

    def test_objects_legacy_block_cannot_duplicate(self):
        path = 'scripts/demo/plains_region_stage.gd'
        source = (ROOT / path).read_text()
        start = source.index('\tfor c: Dictionary in chests:', source.index('func capture_state()'))
        end = source.index('\tfor p: Dictionary in pickups:', start)
        duplicated = source + '\nfunc duplicate_chest_consumer() -> void:\n' + source[start:end]
        result = audit(text_overrides={path: duplicated})
        self.assertFalse(result['passed'])
        self.assertIn('objects.no_grey_claimed', {item['code'] for item in result['checks'] if not item['passed']})


if __name__ == '__main__':
    unittest.main(verbosity=2)
