class_name FoundryCatalog
extends RefCounted
## Bounded, versioned phrase generation. No change to Motor, input, or formal pool.
const CONFIG := "res://config/platforming_foundry.json"
const BATCH := "res://resources/foundry/batch.json"
const MAX_PARTS := 24
const PHASES := [0.0, 0.25, 0.5, 0.75]

static func profiles() -> Array:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/foundry_capabilities.json"))
	return value.get("profiles", []) if value is Dictionary else []

static func tuning_for(profile_id: String) -> PlayerTuning:
	for profile: Dictionary in profiles():
		if profile.id != profile_id or not profile.implemented: continue
		var tuning := PlayerTuning.load_default()
		for key: String in profile.overrides:
			if key not in ["max_jumps", "max_air_shots"]: return null
			tuning.set(key, profile.overrides[key])
		return tuning
	return null

static func apply_profile(controller: PlayerController, profile_id: String) -> bool:
	var tuning := tuning_for(profile_id)
	if tuning == null: return false
	controller.motor.tuning = tuning
	controller.jump_ability.tuning = tuning
	controller.jump_ability.reset()
	controller.action_resources.tuning = tuning
	controller.action_resources.reset()
	controller.shoot_ability.tuning = tuning
	return controller.enable_shot_energy()

static func catalog() -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	return value if value is Dictionary else {}

static func basis() -> String:
	if OS.has_feature("template"):
		# Cooked exports remap source scripts/resources and exclude test drivers.
		# The guarded exporter stamps the validated source basis, plus raw configs.
		var stamp: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://resources/foundry/export_basis.json"))
		if not stamp is Dictionary or stamp.get("schema") != 1 or stamp.get("engine") != Engine.get_version_info().string: return ""
		for path: String in stamp.get("configs", {}):
			if FileAccess.get_sha256(path) != stamp.configs[path]: return ""
		return str(stamp.get("basis", ""))
	var files: Array[String] = [CONFIG, "res://config/player_tuning.json", "res://game/player/player_motor.gd", "res://game/player/player_controller.gd", "res://game/player/actions/jump_ability.gd", "res://game/combat/weapons/shoot_ability.gd", "res://game/combat/resources/action_resources.gd", "res://game/combat/resources/shot_energy_policy.gd", "res://game/world/components/platforming_module.gd", "res://game/world/components/module_moving_platform.gd", "res://game/world/components/module_saw_hazard.gd", "res://game/world/generation/foundry_catalog.gd", "res://game/world/generation/foundry_route_player.gd", "res://game/player/resources/plains_shot_energy.tres"]
	for t: Dictionary in catalog().get("templates", []):
		for variant: Array in t.variants:
			for id: String in variant:
				var path := "res://resources/generation/modules/%s.tres" % id
				if path not in files: files.append(path)
	files.sort()
	files.append("res://config/foundry_capabilities.json")
	files.append("res://tests/branch_module_driver.gd")
	files.append("res://tests/plains_exploration_motion.gd")
	files.append("res://tests/plains_interactive_motion.gd")
	files.append("res://experiments/generation/foundry_lab.gd")
	files.append("res://game/presentation/ui/foundry_pause_input.gd")
	files.append("res://tools/foundry_validate.gd")
	files.append("res://game/player/player.tscn")
	files.append("res://assets/characters/courier/courier_visual.gd")
	files.append("res://game/presentation/actors/art/player_visual_adapter.gd")
	files.append("res://assets/actor_actions/courier_manifest.json")
	files.append("res://assets/actor_actions/weapon_catalog.json")
	files.append("res://assets/plains_v3/hero/manifest.json")
	files.append("res://config/input_profile.json")
	# Actual relocated members of the original bounded source basis, plus the shared level API.
	for source: String in ["res://game/combat/projectiles/", "res://game/combat/resources/contracts/", "res://game/combat/resources/definitions/", "res://game/combat/resources/state/", "res://game/combat/respawn/", "res://game/enemies/behaviors/", "res://game/enemies/presentation/", "res://game/enemies/projectiles/", "res://game/enemies/state/", "res://game/platform/input/", "res://game/player/resources/", "res://game/world/levels/", "res://resources/enemies/", "res://resources/player/", "res://resources/weapons/", "res://scripts/combat/", "res://scripts/enemies/", "res://scripts/generation/", "res://scripts/player/", "res://scripts/resources/definitions/", "res://experiments/motion/graybox.gd", "res://game/application/demo_run_director.gd", "res://game/application/demo_run_result.gd", "res://game/application/run_campaign_progression.gd", "res://game/application/run_composition.gd", "res://game/application/run_manifest.gd", "res://game/application/run_session.gd", "res://game/combat/damage/damage_boundary.gd", "res://game/combat/damage/damage_feedback_definition.gd", "res://game/combat/damage/damage_request.gd", "res://game/combat/damage/damage_result.gd", "res://game/combat/damage/damageable.gd", "res://game/combat/damage/demo_contact_emitter.gd", "res://game/combat/damage/frame_damage_policy.gd", "res://game/combat/resources/action_resources.gd", "res://game/combat/resources/shot_energy_policy.gd", "res://game/combat/weapons/recoil_ability.gd", "res://game/combat/weapons/shoot_ability.gd", "res://game/combat/weapons/weapon_action_runtime.gd", "res://game/combat/weapons/weapon_catalog.gd", "res://game/combat/weapons/weapon_entity.gd", "res://game/enemies/enemy_actor.gd", "res://game/enemies/enemy_behavior_registry.gd", "res://game/enemies/enemy_factory.gd", "res://game/enemies/enemy_motor.gd", "res://game/enemies/prototype_enemy_damageable.gd", "res://game/enemies/species/forest_bark_damageable.gd", "res://game/player/actions/air_focus_ability.gd", "res://game/player/actions/jump_ability.gd", "res://game/player/actions/traversal_ability.gd", "res://game/player/player_controller.gd", "res://game/player/player_motor.gd", "res://game/player/player_tuning.gd", "res://game/presentation/effects/damage_return_echo.gd", "res://game/world/components/module_moving_platform.gd", "res://game/world/components/module_saw_hazard.gd", "res://game/world/components/platforming_module.gd", "res://game/world/generation/forest_ecology_geometry.gd", "res://game/world/generation/forest_hollow_upper_candidate.gd", "res://game/world/generation/foundry_catalog.gd", "res://game/world/generation/foundry_route_player.gd", "res://game/world/generation/foundry_world.gd", "res://game/world/generation/module_reflection.gd", "res://game/world/generation/movement_capability_envelope.gd", "res://game/world/generation/plains_art_language.gd", "res://game/world/generation/plains_encounter_planner.gd", "res://game/world/generation/plains_environment_assembler.gd", "res://game/world/generation/plains_environment_module.gd", "res://game/world/generation/plains_environment_plan.gd", "res://game/world/generation/plains_exploration_topology.gd", "res://game/world/generation/plains_ground_supports.gd", "res://game/world/generation/plains_joint_recoil_plan.gd", "res://game/world/generation/plains_place_plan.gd", "res://game/world/generation/plains_region_art_plan.gd", "res://game/world/generation/plains_region_assembler.gd", "res://game/world/generation/plains_region_generator.gd", "res://game/world/generation/plains_root_bell_encounter_v2.gd", "res://game/world/generation/plains_root_bell_encounter_v3.gd", "res://game/world/generation/plains_root_bell_placement.gd", "res://game/world/generation/plains_route_recipes.gd", "res://game/world/generation/plains_shot_latch_planner.gd", "res://game/world/generation/plains_spatial_golden.gd", "res://game/world/generation/plains_world_rebuild.gd", "res://game/world/generation/random_stage_assembler.gd", "res://game/world/generation/random_stage_generator.gd", "res://game/world/generation/stage_camera_rig.gd", "res://game/world/generation/thorn_forest_region_assembler.gd", "res://game/world/generation/thorn_forest_region_generator.gd", "res://game/world/state/biome_definition.gd", "res://game/world/state/demo_lifetime.gd", "res://game/world/state/demo_token.gd", "res://game/world/state/exit_offer.gd", "res://game/world/state/plains_region_campaign.gd", "res://game/world/state/plains_region_state.gd", "res://game/world/state/route_planner.gd", "res://game/world/state/run_profile.gd", "res://game/world/state/run_random_stream.gd", "res://game/world/state/stage_completion_rule.gd", "res://game/world/state/stage_type_definition.gd"]:
		if source.ends_with("/"): _add_basis_tree(files, source.trim_suffix("/"))
		elif source not in files: files.append(source)
	files.sort()
	var hashes: Array[String] = [Engine.get_version_info().string]
	for path: String in files: hashes.append(path + ":" + FileAccess.get_sha256(path))
	return "\n".join(hashes).sha256_text()

static func _add_basis_tree(files: Array[String], directory: String) -> void:
	for filename: String in DirAccess.get_files_at(directory):
		var path := directory.path_join(filename)
		if (filename.ends_with(".gd") or filename.ends_with(".tres")) and path not in files: files.append(path)
	for child: String in DirAccess.get_directories_at(directory): _add_basis_tree(files, directory.path_join(child))

static func template(id: String) -> Dictionary:
	for t: Dictionary in catalog().get("templates", []):
		if t.id == id: return t
	return {}

static func generate(id: String, variant: int, phase_index: int, seed_value: String, profile_id: String = "base") -> Dictionary:
	var t := template(id)
	if t.is_empty() or variant < 0 or variant >= t.variants.size() or phase_index < 0 or phase_index >= PHASES.size(): return {}
	var result := {"schema": 1, "id": "%s-%s-v%d-p%d" % [id, profile_id, variant, phase_index], "template_id": id, "variant": variant, "phase_index": phase_index, "capability_profile": profile_id, "seed": seed_value, "basis": basis(), "engine": Engine.get_version_info().string, "scope": "development_only", "nodes": []}
	var point := Vector2.ZERO
	var previous: PlatformingModuleDefinition
	var previous_offset := Vector2.ZERO
	var tuning := tuning_for(profile_id)
	if tuning == null: return {}
	var g := RandomStageGenerator.new()
	for index: int in t.variants[variant].size():
		var module_id: String = t.variants[variant][index]
		var d := definition(module_id, phase_index)
		if d == null or not d.supports(tuning): return {}
		var offset := point - d.entry_port.position if index > 0 else Vector2.ZERO
		if previous != null:
			var dock := Rect2(point + Vector2(-24, 18), Vector2(48, 64))
			if not g._compatible_geometry(previous, previous_offset, d, offset, dock): return {}
		result.nodes.append({"module_id": module_id, "offset": [offset.x, offset.y], "phase_index": phase_index})
		point = offset + d.exit_port.position
		previous = d
		previous_offset = offset
	result["hash"] = checksum(result)
	return result

static func definition(id: String, phase_index: int) -> PlatformingModuleDefinition:
	if not id.begins_with("plains_") or "/" in id or phase_index < 0 or phase_index >= PHASES.size(): return null
	var source := load("res://resources/generation/modules/%s.tres" % id) as PlatformingModuleDefinition
	if source == null: return null
	var d := source.duplicate(true) as PlatformingModuleDefinition
	for saw: ModuleSawDefinition in d.saws: saw.initial_phase = fposmod(saw.initial_phase + PHASES[phase_index], 1.0)
	for ferry: ModuleMovingPlatformDefinition in d.ferries: ferry.initial_phase = fposmod(ferry.initial_phase + PHASES[phase_index], 1.0)
	return d

static func checksum(value: Dictionary) -> String:
	var copy := value.duplicate(true)
	copy.erase("hash")
	return JSON.stringify(canonical(copy)).sha256_text()

static func canonical(value: Variant) -> Variant:
	# Godot parses JSON numbers as floats. Disk round trips must preserve identity.
	if value is Dictionary:
		var result: Dictionary = {}
		var keys: Array = value.keys()
		keys.sort()
		for key: String in keys: result[key] = canonical(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(canonical(item))
		return result
	if value is int or value is float:
		if not is_finite(float(value)): return null
		return int(value) if float(value) == floorf(float(value)) else value
	return value

static func same(first: Variant, second: Variant) -> bool:
	return JSON.stringify(canonical(first)) == JSON.stringify(canonical(second))

static func valid(value: Dictionary) -> bool:
	if value.get("schema") != 1 or value.get("basis") != basis() or value.get("hash", "") != checksum(value): return false
	if not value.get("nodes") is Array or value.nodes.is_empty() or value.nodes.size() > MAX_PARTS: return false
	if value.get("kind", "") == "itinerary":
		if not value.get("phrases") is Array or value.phrases.is_empty() or value.phrases.size() > 6: return false
		var expected := itinerary(value.phrases, str(value.get("seed", "")))
		return not expected.is_empty() and same(expected, value)
	var expected := generate(str(value.get("template_id", "")), int(value.get("variant", -1)), int(value.get("phase_index", -1)), str(value.get("seed", "")), str(value.get("capability_profile", "")))
	return not expected.is_empty() and same(expected, value)

static func itinerary(phrases: Array, seed_value: String) -> Dictionary:
	if phrases.is_empty() or phrases.size() > 6: return {}
	var result := {"schema": 1, "id": "route-" + seed_value.sha256_text().left(10), "kind": "itinerary", "seed": seed_value, "basis": basis(), "engine": Engine.get_version_info().string, "scope": "development_only", "phrases": phrases.duplicate(true), "nodes": [], "boundaries": []}
	var point := Vector2.ZERO
	var previous: PlatformingModuleDefinition
	var previous_offset := Vector2.ZERO
	var g := RandomStageGenerator.new()
	for phrase: Dictionary in phrases:
		if not valid(phrase) or phrase.get("kind", "") == "itinerary": return {}
		if result.has("capability_profile") and result.capability_profile != phrase.capability_profile: return {}
		result["capability_profile"] = phrase.capability_profile
		result.boundaries.append(result.nodes.size())
		for node: Dictionary in phrase.nodes:
			var d := definition(node.module_id, int(node.phase_index))
			var offset := point - d.entry_port.position if not result.nodes.is_empty() else Vector2.ZERO
			if previous != null and not g._compatible_geometry(previous, previous_offset, d, offset, Rect2(point + Vector2(-24, 18), Vector2(48, 64))): return {}
			result.nodes.append({"module_id": node.module_id, "offset": [offset.x, offset.y], "phase_index": node.phase_index})
			point = offset + d.exit_port.position
			previous = d
			previous_offset = offset
	if result.nodes.size() > MAX_PARTS: return {}
	result["hash"] = checksum(result)
	return result

static func batch() -> Dictionary:
	if not FileAccess.file_exists(BATCH): return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(BATCH))
	return value if value is Dictionary and value.get("basis") == basis() else {}

static func replay_path(id: String) -> String:
	return "res://resources/foundry/replays/%s.json" % id if id.is_valid_filename() else ""
