class_name RandomStageGenerator
extends RefCounted

# Preview and formal plains share validated geometry; type/route/reward streams stay independent.
const MANIFEST_VERSION := 9
const GENERATOR_VERSION := "plains-capability-run-9"
const VALIDATOR_VERSION := "coincident-spatial-capability-9"
const CAMERA_PROFILE_VERSION := 1
const MAX_ATTEMPTS := 4
const DOCK_HALF_WIDTH := 24.0
const DOCK_DEPTH := 64.0
const CATALOG := ["micro_board", "micro_step", "micro_drop", "spike_gap", "saw_gate", "macro_chain", "challenge_recoil_climb", "challenge_long_gap", "challenge_ferry_ascent", "route_junction"]
const PLAINS_CATALOG := ["plains_micro_rise", "plains_meadow_gap", "plains_terraces", "plains_valley", "plains_boss_arena", "plains_long_meadow", "plains_split_terrace", "plains_braided_meadow", "plains_switchback", "plains_wind_spire", "plains_micro_landing", "plains_micro_stool", "plains_thorn_hop", "plains_gear_hop"]
const BRANCH_CATALOG := ["plains_bramble_causeway", "plains_high_perches", "plains_bramble_ridge", "plains_recoil_step", "plains_recoil_double", "plains_ferry_one", "plains_ferry_two", "plains_recoil_chasm", "plains_recoil_chasm_wide", "plains_thorn_bridge", "plains_thorn_steps", "plains_gear_brook", "plains_gear_glade", "plains_perch_rise", "plains_perch_double", "plains_skip_stones", "plains_fork_paths", "plains_door_landing", "plains_fork_rest"]
const LOCAL_REFLECTION_IDS := ["micro_step", "plains_micro_rise", "plains_meadow_gap", "plains_terraces", "plains_valley"]
const CONTENT_RUNTIME_VERSION := "platforming-module-runtime-6"

const PROFILES := {
	"advanced_challenge": {"version": 1, "max_p": 3, "max_t": 2, "max_pressure_chain": 24, "max_advanced": 24, "max_macro": 24, "safe_start_count": 1, "max_saw": 24, "max_spike": 24, "max_hazard_chain": 24, "max_repeated": 24},
	"plains_intro": {"version": 1, "max_p": 1, "max_t": 1, "max_pressure_chain": 1, "max_advanced": 0, "max_macro": 0, "safe_start_count": 2, "max_saw": 2, "max_spike": 3, "max_hazard_chain": 2, "max_repeated": 2},
	"plains_run_coin": {"version": 1, "max_p": 2, "max_t": 1, "max_pressure_chain": 1, "max_advanced": 0, "max_macro": 0, "safe_start_count": 2, "max_saw": 1, "max_spike": 1, "max_hazard_chain": 1, "max_repeated": 2, "required_practice": false, "weights": {"plains_valley": 9, "plains_terraces": 7, "plains_meadow_gap": 7, "micro_step": 4, "plains_long_meadow": 10, "plains_split_terrace": 10}},
	"plains_run_item": {"version": 1, "max_p": 3, "max_t": 2, "max_pressure_chain": 2, "max_advanced": 1, "max_macro": 1, "safe_start_count": 2, "max_saw": 3, "max_spike": 3, "max_hazard_chain": 2, "max_repeated": 2, "weights": {"macro_chain": 5, "challenge_long_gap": 4, "plains_terraces": 7}},
	"plains_run_service": {"version": 1, "max_p": 1, "max_t": 0, "max_pressure_chain": 1, "max_advanced": 0, "max_macro": 0, "safe_start_count": 2, "max_saw": 0, "max_spike": 0, "max_hazard_chain": 0, "max_repeated": 2, "required_practice": false, "weights": {"plains_long_meadow": 12, "plains_split_terrace": 5}},
	"plains_run_early": {"version": 1, "max_p": 1, "max_t": 1, "max_pressure_chain": 1, "max_advanced": 0, "max_macro": 0, "safe_start_count": 2, "max_saw": 1, "max_spike": 2, "max_hazard_chain": 1, "max_repeated": 2},
	"plains_run_mid": {"version": 1, "max_p": 2, "max_t": 2, "max_pressure_chain": 2, "max_advanced": 0, "max_macro": 1, "safe_start_count": 2, "max_saw": 2, "max_spike": 2, "max_hazard_chain": 2, "max_repeated": 2},
	"plains_run_late": {"version": 1, "max_p": 3, "max_t": 2, "max_pressure_chain": 2, "max_advanced": 1, "max_macro": 1, "safe_start_count": 2, "max_saw": 2, "max_spike": 3, "max_hazard_chain": 2, "max_repeated": 2},
	"plains_run_boss": {"version": 1, "max_p": 1, "max_t": 0, "max_pressure_chain": 1, "max_advanced": 0, "max_macro": 0, "safe_start_count": 2, "max_saw": 0, "max_spike": 0, "max_hazard_chain": 0, "max_repeated": 2, "required_practice": false},
	"plains_standard": {"version": 1, "max_p": 3, "max_t": 2, "max_pressure_chain": 2, "max_advanced": 1, "max_macro": 1, "safe_start_count": 2, "max_saw": 2, "max_spike": 3, "max_hazard_chain": 2, "max_repeated": 2}
}

func generate(map_seed: int, tuning: PlayerTuning, module_count: int = 14, profile_id: String = "advanced_challenge", formal_layout: bool = false) -> Dictionary:
	if tuning == null or MovementCapabilityEnvelope.snapshot(tuning).is_empty() or module_count < 6 or module_count > 24 or not PROFILES.has(profile_id):
		return _failure("Preview requires tuning and 6–24 modules")
	var candidates: Array[String] = []
	for module_id: String in CATALOG:
		if module_id not in ["micro_board", "route_junction"] and definition_for(module_id).supports(tuning):
			candidates.append(module_id)
	if profile_id.begins_with("plains_run_"):
		for module_id: String in PLAINS_CATALOG:
			if module_id not in ["plains_boss_arena", "plains_braided_meadow", "plains_switchback", "plains_wind_spire"] and definition_for(module_id).supports(tuning):
				candidates.append(module_id)
	if profile_id != "advanced_challenge":
		return _generate_plains(map_seed, tuning, module_count, candidates, profile_id, formal_layout)
	for attempt: int in MAX_ATTEMPTS:
		var rng := RandomNumberGenerator.new()
		rng.seed = map_seed + attempt * 104729
		var ids: Array[String] = ["micro_board"]
		# A short, seamless landing stretch precedes the first authored challenge.
		var required: Array[String] = []
		if "macro_chain" in candidates:
			required.append("macro_chain")
		if "spike_gap" in candidates:
			required.append("spike_gap")
		if "saw_gate" in candidates:
			required.append("saw_gate")
		for challenge_id: String in ["challenge_recoil_climb", "challenge_long_gap", "challenge_ferry_ascent"]:
			if challenge_id in candidates:
				required.append(challenge_id)
		for position: int in range(required.size() - 1, 0, -1):
			var swap := rng.randi_range(0, position)
			var stored := required[position]
			required[position] = required[swap]
			required[swap] = stored
		var bag := candidates.duplicate()
		for index: int in module_count - 2:
			if index < (1 if module_count >= 10 else 0):
				ids.append("micro_board")
			elif not required.is_empty():
				ids.append(required.pop_front())
			else:
				if bag.is_empty():
					bag = candidates.duplicate()
				if bag.is_empty():
					ids.append("micro_board")
				else:
					var selected := rng.randi_range(0, bag.size() - 1)
					ids.append(bag[selected])
					bag.remove_at(selected)
		ids.append("route_junction")
		var manifest := _assemble_manifest(ids, map_seed, tuning, attempt, "", rng)
		var checked := validate_manifest(manifest, tuning)
		if checked.ok:
			return {"ok": true, "error": "", "manifest": manifest}
	# Compatible same-preview safe route; never changes a formal room type.
	var safe_ids: Array[String] = []
	for index: int in module_count:
		safe_ids.append("route_junction" if index == module_count - 1 else "micro_board")
	var safe_rng := RandomNumberGenerator.new()
	safe_rng.seed = map_seed
	var fallback := _assemble_manifest(safe_ids, map_seed, tuning, MAX_ATTEMPTS, "safe_walk_preview", safe_rng)
	var checked := validate_manifest(fallback, tuning)
	if not checked.ok:
		return _failure("No compatible preview fallback: " + str(checked.error))
	return {"ok": true, "error": "", "manifest": fallback}

func _generate_plains(map_seed: int, tuning: PlayerTuning, count: int, candidates: Array[String], profile_id: String, formal_layout: bool = false) -> Dictionary:
	var budget: Dictionary = PROFILES[profile_id]
	var pool: Array[String] = []
	for id: String in candidates:
		var definition := definition_for(id)
		if (not formal_layout or id != "micro_drop") and (not _hazardous(definition) or int(budget.max_hazard_chain) > 0) and definition.platform_pressure <= int(budget.max_p) and definition.timing_pressure <= int(budget.max_t) and (not id.begins_with("challenge_") or int(budget.max_advanced) > 0) and (id != "macro_chain" or int(budget.max_macro) > 0):
			pool.append(id)
	for attempt: int in MAX_ATTEMPTS:
		var rng := RandomNumberGenerator.new()
		rng.seed = map_seed + attempt * 104729
		var ids: Array[String] = ["micro_board", "micro_board"]
		var required: Array[String] = []
		if formal_layout and profile_id in ["plains_run_service", "plains_run_boss"] and "plains_long_meadow" in pool:
			required.append("plains_long_meadow")
		for id: String in ["spike_gap", "saw_gate"]:
			if bool(budget.get("required_practice", true)) and id in pool:
				required.append(id)
		var chain := 0
		var hazard_chain := 0
		var advanced_count := 0
		var macro_count := 0
		while ids.size() < count - 1:
			var remaining := count - 1 - ids.size()
			var id := "micro_board"
			if chain < int(budget.max_pressure_chain) and (int(budget.max_hazard_chain) == 0 or hazard_chain < int(budget.max_hazard_chain)):
				if not required.is_empty() and (ids.size() % 3 == 2 or remaining <= required.size()):
					id = required.pop_front()
				else:
					var weighted: Array[String] = ["micro_board", "micro_board"]
					for candidate: String in pool:
						if candidate == "saw_gate" and ids.count(candidate) >= int(budget.max_saw) or candidate == "spike_gap" and ids.count(candidate) >= int(budget.max_spike):
							continue
						if ids.size() >= 2 and ids[-1] == candidate and ids[-2] == candidate:
							continue
						if candidate.begins_with("challenge_") and advanced_count >= int(budget.max_advanced) or candidate == "macro_chain" and macro_count >= int(budget.max_macro):
							continue
						for unused: int in int(budget.get("weights", {}).get(candidate, 1 if candidate.begins_with("challenge_") or candidate == "macro_chain" else 3)):
							weighted.append(candidate)
					id = weighted[rng.randi_range(0, weighted.size() - 1)]
			if id in required:
				required.erase(id)
			ids.append(id)
			if id.begins_with("challenge_"):
				advanced_count += 1
			if id == "macro_chain":
				macro_count += 1
			var definition := definition_for(id)
			chain = chain + 1 if _high_pressure(definition) else 0
			hazard_chain = hazard_chain + 1 if _hazardous(definition) else 0
		if profile_id == "plains_run_boss":
			ids[-1] = "plains_boss_arena"
		ids.append("route_junction")
		var manifest := _assemble_manifest(ids, map_seed, tuning, attempt, "", rng, profile_id, formal_layout)
		if validate_manifest(manifest, tuning).ok:
			return {"ok": true, "error": "", "manifest": manifest}
	var safe_ids: Array[String] = []
	for index: int in count:
		safe_ids.append("route_junction" if index == count - 1 else ("plains_boss_arena" if profile_id == "plains_run_boss" and index == count - 2 else "micro_board"))
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var fallback := _assemble_manifest(safe_ids, map_seed, tuning, MAX_ATTEMPTS, "safe_walk_preview", rng, profile_id, formal_layout)
	var checked := validate_manifest(fallback, tuning)
	return {"ok": true, "error": "", "manifest": fallback} if checked.ok else _failure(str(checked.error))

# A room chooses real authored spatial geometry, not merely another weighted chain.
# Every inter-module join still uses the proven coincident docking contract.
func generate_spatial(map_seed: int, tuning: PlayerTuning, profile_id: String, spatial_id: String) -> Dictionary:
	if spatial_id not in ["plains_braided_meadow", "plains_switchback", "plains_wind_spire"] or not PROFILES.has(profile_id) or not definition_for(spatial_id).supports(tuning):
		return _failure("Spatial family is incompatible with this movement envelope")
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var ids: Array[String] = ["micro_board", "micro_board", spatial_id, "micro_board", "plains_long_meadow", "micro_board", "micro_board", "micro_board", "route_junction"]
	if spatial_id != "plains_braided_meadow":
		ids = ["micro_board", "micro_board", spatial_id, "plains_thorn_hop"]
		for unused: int in rng.randi_range(1, 4):
			ids.append("plains_micro_landing" if unused % 2 == 0 else "plains_micro_stool")
		ids.append_array(["plains_gear_hop", "route_junction"])
	elif bool(PROFILES[profile_id].get("required_practice", true)):
		ids[5] = "spike_gap"
		ids[7] = "saw_gate"
	else:
		var compatible: Array[String] = []
		for id: String in ["plains_micro_rise", "plains_terraces", "plains_meadow_gap", "plains_valley"]:
			if definition_for(id).supports(tuning) and definition_for(id).platform_pressure <= int(PROFILES[profile_id].max_p):
				compatible.append(id)
		ids[5] = compatible[rng.randi_range(0, compatible.size() - 1)] if not compatible.is_empty() else "micro_board"
		# A valley needs a real preceding rise so its floor stays above spawn.
		if ids[5] == "plains_valley" and definition_for("plains_terraces").supports(tuning) and int(PROFILES[profile_id].max_p) >= 2:
			ids[4] = "plains_terraces"
		ids[7] = "plains_split_terrace"
	if spatial_id == "plains_braided_meadow" and profile_id in ["plains_run_item", "plains_run_late"] and definition_for("challenge_long_gap").supports(tuning) and rng.randi_range(0, 2) > 0:
		ids[4] = "challenge_long_gap"
	var manifest := _assemble_manifest(ids, map_seed, tuning, 0, "", rng, profile_id, true)
	var checked := validate_manifest(manifest, tuning)
	return {"ok": true, "error": "", "manifest": manifest} if checked.ok else checked

func _route_graph(nodes: Array) -> Dictionary:
	var points: Array = []
	var edges: Array = []
	var previous_exit := ""
	for node: Dictionary in nodes:
		var definition := definition_for(node.module_id, node.mirrored, node.reverse_traversal)
		var offset := Vector2(node.offset[0], node.offset[1])
		var entry_id := str(node.id) + ":entry"
		var exit_id := str(node.id) + ":exit"
		points.append({"id": entry_id, "position": _point_array(definition.entry_port.position + offset)})
		points.append({"id": exit_id, "position": _point_array(definition.exit_port.position + offset)})
		if not previous_exit.is_empty():
			edges.append({"from": previous_exit, "to": entry_id, "kind": "coincident_dock"})
		if definition.main_route.is_empty():
			edges.append({"from": entry_id, "to": exit_id, "kind": "authored_module"})
		else:
			for index: int in definition.anchors.size():
				points.append({"id": str(node.id) + ":anchor_%d" % index, "position": _point_array(definition.anchors[index] + offset)})
			edges.append({"from": entry_id, "to": str(node.id) + ":anchor_%d" % definition.main_route[0], "kind": "main"})
			var paths: Array = [definition.main_route]
			paths.append_array(definition.branch_routes)
			for path_index: int in paths.size():
				var path: Variant = paths[path_index]
				for index: int in path.size() - 1:
					edges.append({"from": str(node.id) + ":anchor_%d" % path[index], "to": str(node.id) + ":anchor_%d" % path[index + 1], "kind": "main" if path_index == 0 else "optional_branch"})
			edges.append({"from": str(node.id) + ":anchor_%d" % definition.main_route[-1], "to": exit_id, "kind": "main"})
		previous_exit = exit_id
	return {"version": 1, "points": points, "edges": edges}

func _spatial_exits(nodes: Array, default_exits: Array, tuning: PlayerTuning) -> Array:
	for node: Dictionary in nodes:
		if node.module_id == "plains_braided_meadow" and definition_for(node.module_id).supports(tuning):
			var offset := Vector2(node.offset[0], node.offset[1])
			return [default_exits[0], {"id": "exit_meadow_upper", "position": _point_array(offset + definition_for(node.module_id).anchors[8])}]
	return default_exits

func _pressure(definition: PlatformingModuleDefinition) -> Dictionary:
	return {"p": definition.platform_pressure, "c": 0, "t": definition.timing_pressure, "r": "authored_grounded_dock"}

func _hazardous(definition: PlatformingModuleDefinition) -> bool:
	return not definition.danger_bounds.is_empty() or not definition.saws.is_empty()

func _high_pressure(definition: PlatformingModuleDefinition) -> bool:
	return definition.platform_pressure >= 2 or definition.timing_pressure >= 2

func _same_data(first: Variant, second: Variant) -> bool:
	return JSON.stringify(_canonical(first), "", true) == JSON.stringify(_canonical(second), "", true)

func _profile_schedule_valid(manifest: Dictionary, tuning: PlayerTuning) -> bool:
	var budget: Dictionary = PROFILES[manifest.profile_id]
	var chain := 0
	var hazard_chain := 0
	var repeated := 0
	var advanced := 0
	var macro := 0
	var ids: Array[String] = []
	for index: int in manifest.nodes.size():
		var id := str(manifest.nodes[index].module_id)
		ids.append(id)
		var definition := definition_for(id)
		if definition.platform_pressure > int(budget.max_p) or definition.timing_pressure > int(budget.max_t) or index < int(budget.safe_start_count) and id != "micro_board":
			return false
		chain = chain + 1 if _high_pressure(definition) else 0
		hazard_chain = hazard_chain + 1 if _hazardous(definition) else 0
		repeated = repeated + 1 if index > 0 and id == ids[index - 1] else 1
		if hazard_chain > int(budget.max_hazard_chain) or id != "micro_board" and repeated > int(budget.max_repeated) or ids.count("saw_gate") + ids.count("plains_gear_hop") > int(budget.max_saw) or ids.count("spike_gap") + ids.count("plains_thorn_hop") > int(budget.max_spike):
			return false
		advanced += 1 if id.begins_with("challenge_") else 0
		macro += 1 if id == "macro_chain" else 0
		if chain > int(budget.max_pressure_chain) or advanced > int(budget.max_advanced) or macro > int(budget.max_macro):
			return false
	if manifest.local_reflections and manifest.profile_id in ["plains_run_service", "plains_run_boss"] and manifest.fallback_id.is_empty() and "plains_long_meadow" not in ids:
		return false
	if manifest.profile_id == "plains_run_boss" and (ids.count("plains_boss_arena") != 1 or ids[-2] != "plains_boss_arena"):
		return false
	if manifest.profile_id != "advanced_challenge" and manifest.fallback_id.is_empty() and bool(budget.get("required_practice", true)):
		for id: String in ["spike_gap", "saw_gate"]:
			var definition := definition_for(id)
			if definition.supports(tuning) and definition.platform_pressure <= int(budget.max_p) and definition.timing_pressure <= int(budget.max_t) and id not in ids and ("plains_thorn_hop" if id == "spike_gap" else "plains_gear_hop") not in ids:
				return false
	return true

func definition_for(module_id: String, mirrored: bool = false, reverse_traversal: bool = false) -> PlatformingModuleDefinition:
	if module_id not in CATALOG and module_id not in PLAINS_CATALOG and module_id not in BRANCH_CATALOG:
		return null
	var definition := load("res://resources/generation/modules/%s.tres" % module_id) as PlatformingModuleDefinition
	if not mirrored:
		return definition
	var reflected := ModuleReflection.reflected_definition(definition)
	if reverse_traversal:
		if module_id not in LOCAL_REFLECTION_IDS:
			return null
		var old_entry := reflected.entry_port
		reflected.entry_port = reflected.exit_port
		reflected.exit_port = old_entry
		reflected.entry_port.direction = Vector2.RIGHT
		reflected.exit_port.direction = Vector2.RIGHT
		reflected.anchors.reverse()
	return reflected

func scene_for(module_id: String) -> PackedScene:
	if module_id not in CATALOG and module_id not in PLAINS_CATALOG and module_id not in BRANCH_CATALOG:
		return null
	return load("res://scenes/generation/modules/%s.tscn" % module_id) as PackedScene

func capability_snapshot(tuning: PlayerTuning) -> Dictionary:
	return {"max_jumps": tuning.max_jumps, "max_air_shots": tuning.max_air_shots, "recoil_mode": tuning.recoil_mode, "burst_speed": tuning.shot_burst_speed, "burst_duration": tuning.shot_burst_duration}

func physics_hash(tuning: PlayerTuning) -> String:
	var values: Dictionary = {}
	for property: Dictionary in tuning.get_property_list():
		var key := str(property.name)
		if key in ["resource_local_to_scene", "resource_path", "resource_name", "script"] or key.contains("/"):
			continue
		var value: Variant = tuning.get(key)
		if value is float or value is int or value is bool or value is String or value is Array:
			values[key] = value
	return JSON.stringify(values, "", true).sha256_text()

func content_hash(module_id: String) -> String:
	# Resource properties remain available in exported PCKs; source files do not.
	return JSON.stringify({"runtime_version": CONTENT_RUNTIME_VERSION, "scene_id": module_id, "definition": _resource_data(definition_for(module_id))}, "", true).sha256_text()

func _resource_data(resource: Resource) -> Dictionary:
	var data: Dictionary = {}
	for property: Dictionary in resource.get_property_list():
		var key := str(property.name)
		if key in ["resource_local_to_scene", "resource_path", "resource_name", "script"] or key.contains("/"):
			continue
		data[key] = _json_value(resource.get(key))
	return data

func _json_value(value: Variant) -> Variant:
	if value is Resource:
		return _resource_data(value)
	if value is Vector2:
		return _point_array(value)
	if value is Rect2:
		return _rect_array(value)
	if value is StringName:
		return str(value)
	if value is Array or value is PackedInt32Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_json_value(item))
		return result
	return value

func _assemble_manifest(ids: Array[String], map_seed: int, tuning: PlayerTuning, attempt: int, fallback_id: String, rng: RandomNumberGenerator, profile_id: String = "advanced_challenge", formal_layout: bool = false) -> Dictionary:
	var nodes: Array = []
	var seams: Array = []
	var mirrored := rng.randi_range(0, 1) == 1 and not formal_layout
	var offset := Vector2.ZERO
	var bounds := Rect2()
	var previous: PlatformingModuleDefinition
	var previous_offset := Vector2.ZERO
	for index: int in ids.size():
		var local_mirror := mirrored
		if formal_layout and ids[index] in LOCAL_REFLECTION_IDS:
			local_mirror = rng.randi_range(0, 1) == 1
		var definition := definition_for(ids[index], local_mirror, formal_layout and local_mirror)
		# Formal rooms start at the lowest left landing. Reject a downhill draw
		# that would put any safe standing surface below the initial spawn.
		if formal_layout and index > 0:
			var next_offset := previous_offset + previous.exit_port.position - definition.entry_port.position
			if definition.anchors.any(func(point: Vector2): return point.y + next_offset.y > 282.001):
				local_mirror = false
				definition = definition_for(ids[index])
				next_offset = previous_offset + previous.exit_port.position - definition.entry_port.position
				if definition.anchors.any(func(point: Vector2): return point.y + next_offset.y > 282.001):
					ids[index] = "micro_board"
					definition = definition_for("micro_board")
		if index > 0:
			offset = previous_offset + previous.exit_port.position - definition.entry_port.position
			var start := previous.exit_port.position + previous_offset
			seams.append({"id": "seam_%02d" % (index - 1), "from": index - 1, "to": index, "point": _point_array(start)})
		var phases: Array = []
		for saw: ModuleSawDefinition in definition.saws:
			phases.append({"id": str(saw.source_id), "phase": rng.randi_range(0, 3) * 0.25})
		for ferry: ModuleMovingPlatformDefinition in definition.ferries:
			phases.append({"id": str(ferry.platform_id), "phase": rng.randi_range(0, 3) * 0.25})
		nodes.append({"id": "module_%02d" % index, "module_id": ids[index], "mirrored": local_mirror, "reverse_traversal": formal_layout and local_mirror, "entry_port_id": str(definition.entry_port.port_id), "exit_port_id": str(definition.exit_port.port_id), "version": definition.definition_version, "content_hash": content_hash(ids[index]), "offset": _point_array(offset), "initial_phases": phases, "pressure": _pressure(definition)})
		var node_bounds := Rect2(definition.world_bounds.position + offset, definition.world_bounds.size)
		bounds = node_bounds if index == 0 else bounds.merge(node_bounds)
		previous = definition
		previous_offset = offset
	var manifest := {"manifest_version": MANIFEST_VERSION, "generator_version": GENERATOR_VERSION, "validator_version": VALIDATOR_VERSION, "development_only": not profile_id.begins_with("plains_run_"), "layout_id": "seamless_port_chain", "local_reflections": formal_layout, "spawn_policy": "left_lowest_safe_landing" if formal_layout else "legacy_handedness", "mirrored": mirrored, "terminal_exits": _terminal_exits(previous, previous_offset, tuning, formal_layout), "seed": str(map_seed), "attempt_index": attempt, "fallback_id": fallback_id, "fallback_reason": "bounded_geometry_attempts_exhausted" if not fallback_id.is_empty() else "", "capabilities": capability_snapshot(tuning), "physics_hash": physics_hash(tuning), "nodes": nodes, "seams": seams, "world_bounds": _rect_array(bounds), "camera_profile_id": "horizontal_preview_follow", "camera_profile_version": CAMERA_PROFILE_VERSION, "engine_version": str(Engine.get_version_info().string), "validation_scope": "authored_geometry_and_capability_filter; whole_stage_motor_test_separate"}
	manifest["profile_id"] = profile_id
	manifest["profile_budget"] = PROFILES[profile_id].duplicate(true)
	manifest["movement_envelope"] = MovementCapabilityEnvelope.snapshot(tuning)
	manifest["route_graph"] = _route_graph(nodes)
	manifest["spatial_family"] = "corridor"
	for node: Dictionary in nodes:
		if node.module_id in ["plains_braided_meadow", "plains_switchback", "plains_wind_spire"]:
			manifest["spatial_family"] = node.module_id
	if formal_layout:
		manifest["terminal_exits"] = _spatial_exits(nodes, manifest.terminal_exits, tuning)
	manifest["manifest_hash"] = _manifest_hash(manifest)
	return manifest

func validate_manifest(manifest: Dictionary, tuning: PlayerTuning) -> Dictionary:
	if tuning == null or not _numeric(manifest.get("manifest_version")) or manifest.get("manifest_version") != MANIFEST_VERSION or not manifest.get("generator_version") is String or manifest.get("generator_version") != GENERATOR_VERSION or not manifest.get("validator_version") is String or manifest.get("validator_version") != VALIDATOR_VERSION or not manifest.get("development_only") is bool  or not manifest.get("layout_id") is String or manifest.get("layout_id") not in ["seamless_port_chain", "branched_terminal_paths"] or not manifest.get("mirrored") is bool:
		return _failure("Incompatible manifest version or layout")
	if not manifest.get("camera_profile_id") is String or manifest.get("camera_profile_id") != "horizontal_preview_follow" or not _numeric(manifest.get("camera_profile_version")) or manifest.get("camera_profile_version") != CAMERA_PROFILE_VERSION:
		return _failure("Incompatible camera profile")
	if not manifest.get("engine_version") is String or manifest.get("engine_version") != str(Engine.get_version_info().string):
		return _failure("Incompatible engine version")
	var profile: Variant = manifest.get("profile_id")
	if not profile is String or not PROFILES.has(profile) or not _same_data(manifest.get("profile_budget"), PROFILES[profile]) or not _same_data(manifest.get("movement_envelope"), MovementCapabilityEnvelope.snapshot(tuning)):
		return _failure("Incompatible profile budget or movement envelope")
	if manifest.development_only != (not str(profile).begins_with("plains_run_")):
		return _failure("Development/formal profile scope mismatch")
	if not manifest.get("local_reflections") is bool or manifest.get("spawn_policy") != ("left_lowest_safe_landing" if manifest.local_reflections else "legacy_handedness") or manifest.local_reflections and (manifest.development_only or manifest.mirrored):
		return _failure("Invalid formal spawn/reflection policy")
	if manifest.has("stage_type"):
		var formal_type: Variant = manifest.get("stage_type")
		var formal_index: Variant = manifest.get("stage_index")
		if not manifest.local_reflections or not formal_type is String or formal_type not in ["combat", "shop", "coin_reward", "health_reward", "item_reward", "boss"] or not _numeric(formal_index) or formal_index != floorf(formal_index) or formal_index < 1 or formal_index > 8 or (formal_index == 8) != (formal_type == "boss") or manifest.profile_id != PlainsStageGenerator.new().profile_for(int(formal_index), StringName(formal_type)):
			return _failure("Invalid formal room type/index/profile contract")
		var variants := {"coin_reward": "open_meadow_exploration", "shop": "short_respite", "health_reward": "short_respite", "item_reward": "challenge_gauntlet", "boss": "fixed_core_random_approach", "combat": "ascending_combat_ridge"}
		if manifest.get("layout_variant") != variants[formal_type]:
			return _failure("Invalid recorded spatial content variant")
	var attempt: Variant = manifest.get("attempt_index")
	if not _numeric(attempt) or attempt != floorf(float(attempt)) or attempt < 0 or attempt > MAX_ATTEMPTS or not manifest.get("fallback_id") is String or not manifest.get("fallback_reason") is String:
		return _failure("Invalid bounded attempt metadata")
	if attempt == MAX_ATTEMPTS:
		if manifest.fallback_id != "safe_walk_preview" or manifest.fallback_reason != "bounded_geometry_attempts_exhausted":
			return _failure("Invalid fallback metadata")
	elif manifest.fallback_id != "" or manifest.fallback_reason != "":
		return _failure("Unexpected fallback metadata")

	if not manifest.get("physics_hash") is String or not manifest.get("capabilities") is Dictionary or not manifest.get("seed") is String or not str(manifest.seed).is_valid_int() or manifest.get("physics_hash") != physics_hash(tuning) or JSON.stringify(_canonical(manifest.get("capabilities")), "", true) != JSON.stringify(_canonical(capability_snapshot(tuning)), "", true):
		return _failure("Incompatible seed or physics/capability snapshot")
	if not manifest.get("manifest_hash") is String or manifest.get("manifest_hash", "") != _manifest_hash(manifest):
		return _failure("Manifest integrity mismatch")
	if manifest.layout_id == "branched_terminal_paths":
		return PlainsBranchLayout.new().validate(manifest, tuning, self)
	var nodes: Variant = manifest.get("nodes")
	var seams: Variant = manifest.get("seams")
	if not nodes is Array or nodes.size() < 6 or nodes.size() > 24 or not seams is Array or seams.size() != nodes.size() - 1:
		return _failure("Invalid graph size")
	var bounds := Rect2()
	var occupied_definitions: Array[PlatformingModuleDefinition] = []
	var occupied_offsets: Array[Vector2] = []
	var previous: PlatformingModuleDefinition
	var previous_offset := Vector2.ZERO
	for index: int in nodes.size():
		var node: Variant = nodes[index]
		if not node is Dictionary or not node.get("id") is String or node.get("id") != "module_%02d" % index or not node.get("module_id") is String:
			return _failure("Invalid node identity")
		if not manifest.get("local_reflections") is bool or not node.get("reverse_traversal") is bool or not node.get("mirrored") is bool or (not manifest.local_reflections and node.mirrored != manifest.mirrored) or node.reverse_traversal != (manifest.local_reflections and node.mirrored) or (manifest.local_reflections and (manifest.mirrored or index == 0 and node.mirrored)):
			return _failure("Incompatible recorded reflection")
		var definition := definition_for(node.module_id, node.mirrored, node.reverse_traversal)
		if node.module_id in PLAINS_CATALOG and not str(profile).begins_with("plains_run_"):
			return _failure("Formal content cannot enter preview catalogs")
		if definition == null or not definition.supports(tuning) or not _numeric(node.get("version")) or node.get("version") != definition.definition_version or not node.get("content_hash") is String or node.get("content_hash") != content_hash(node.module_id) or not _valid_array(node.get("offset"), 2):
			return _failure("Incompatible module content or capability")
		if not node.get("entry_port_id") is String or not node.get("exit_port_id") is String or node.entry_port_id != str(definition.entry_port.port_id) or node.exit_port_id != str(definition.exit_port.port_id):
			return _failure("Incompatible active port identity")
		if index == 0 and node.module_id != "micro_board" or index == nodes.size() - 1 and node.module_id != "route_junction" or attempt == MAX_ATTEMPTS and index < nodes.size() - 1 and node.module_id != "micro_board" and not (profile == "plains_run_boss" and index == nodes.size() - 2 and node.module_id == "plains_boss_arena"):
			return _failure("Unsafe entry/exit module")
		if not _same_data(node.get("pressure"), _pressure(definition)):
			return _failure("Incompatible authored pressure")
		var offset := Vector2(node.offset[0], node.offset[1])
		if index == 0 and offset != Vector2.ZERO:
			return _failure("Invalid stage origin")
		if manifest.local_reflections and (definition.entry_port.direction.x <= 0 or definition.exit_port.direction.x <= 0 or definition.anchors.any(func(point: Vector2): return point.y + offset.y > 282.001)):
			return _failure("Formal landing lies below left-bottom spawn or points backward")
		var node_bounds := Rect2(definition.world_bounds.position + offset, definition.world_bounds.size)
		bounds = node_bounds if index == 0 else bounds.merge(node_bounds)
		if not _valid_phases(node.get("initial_phases"), definition):
			return _failure("Invalid recorded initial phase")
		if index > 0:
			var expected_offset := previous_offset + previous.exit_port.position - definition.entry_port.position
			if offset != expected_offset:
				return _failure("Disconnected module transform")
			var seam: Variant = seams[index - 1]
			var point := previous.exit_port.position + previous_offset
			if not seam is Dictionary or not seam.get("id") is String or seam.get("id") != "seam_%02d" % (index - 1) or not _numeric(seam.get("from")) or seam.get("from") != index - 1 or not _numeric(seam.get("to")) or seam.get("to") != index or not _valid_array(seam.get("point"), 2) or Vector2(seam.point[0], seam.point[1]) != point or seam.has("rect") or seam.has("anchor"):
				return _failure("Invalid coincident docking port")
			if not _clear_dock(point, previous, previous_offset) or not _clear_dock(point, definition, offset):
				return _failure("Dock intersects hazard or body clearance")
		for other_index: int in occupied_definitions.size():
			var dock := Rect2()
			if other_index == index - 1:
				dock = Rect2(definition.entry_port.position + offset + Vector2(-DOCK_HALF_WIDTH, 18), Vector2(DOCK_HALF_WIDTH * 2, DOCK_DEPTH))
			if not _compatible_geometry(occupied_definitions[other_index], occupied_offsets[other_index], definition, offset, dock):
				return _failure("Module geometry overlaps outside shared docking support")
		occupied_definitions.append(definition)
		occupied_offsets.append(offset)
		previous = definition
		previous_offset = offset
	var expected_exits := _terminal_exits(previous, previous_offset, tuning, manifest.local_reflections)
	if manifest.local_reflections:
		expected_exits = _spatial_exits(nodes, expected_exits, tuning)
	if not _same_data(manifest.get("route_graph"), _route_graph(nodes)):
		return _failure("Recorded route graph differs from authored spatial paths")
	var spatial_family := "corridor"
	for node: Dictionary in nodes:
		if node.module_id in ["plains_braided_meadow", "plains_switchback", "plains_wind_spire"]:
			spatial_family = node.module_id
	if manifest.get("spatial_family") != spatial_family:
		return _failure("Recorded spatial family differs from real geometry")
	if not manifest.get("terminal_exits") is Array or not _same_data(manifest.terminal_exits, expected_exits):
		return _failure("Incompatible terminal port choices")
	if not _valid_array(manifest.get("world_bounds"), 4) or _array_rect(manifest.world_bounds) != bounds:
		return _failure("Invalid world bounds")
	if not _profile_schedule_valid(manifest, tuning):
		return _failure("Schedule exceeds recorded profile or misses compatible practice mechanics")
	return {"ok": true, "error": ""}

func _terminal_exits(definition: PlatformingModuleDefinition, offset: Vector2, tuning: PlayerTuning, formal_layout: bool = false) -> Array:
	var result: Array = []
	for port: PlatformingModulePort in definition.get_exit_ports():
		if port.supports(tuning):
			result.append({"id": str(port.port_id), "position": _point_array(port.position + offset)})
	if formal_layout:
		var selected: Array = [result[0]]
		for option: Dictionary in result:
			if option.id == "exit_upper_left":
				selected.append(option)
		if selected.size() == 1:
			selected.append({"id": "exit_lower_left_safe", "position": _point_array(offset + Vector2(160, 582))})
		return selected
	return result

func _clear_dock(point: Vector2, definition: PlatformingModuleDefinition, offset: Vector2) -> bool:
	# Grounded player body and a small overhead margin, never an added platform.
	var corridor := Rect2(point + Vector2(-24, -26), Vector2(48, 44))
	for platform: Rect2 in definition.platforms:
		if Rect2(platform.position + offset, platform.size).intersects(corridor):
			return false
	for rect: Rect2 in _forbidden(definition):
		if Rect2(rect.position + offset, rect.size).intersects(corridor.grow(8)):
			return false
	return true

func _forbidden(definition: PlatformingModuleDefinition) -> Array[Rect2]:
	var result: Array[Rect2] = definition.danger_bounds.duplicate()
	for saw: ModuleSawDefinition in definition.saws:
		result.append(saw.envelope())
	for ferry: ModuleMovingPlatformDefinition in definition.ferries:
		result.append(ferry.envelope())
	return result

func _compatible_geometry(first: PlatformingModuleDefinition, first_offset: Vector2, second: PlatformingModuleDefinition, second_offset: Vector2, shared_support: Rect2) -> bool:
	# Visual/content bounds can overlap; only intentional adjacent ground pads
	# may share physical volume. Hazard sweeps cannot enter another module.
	for first_platform: Rect2 in first.platforms:
		var first_world := Rect2(first_platform.position + first_offset, first_platform.size)
		for second_platform: Rect2 in second.platforms:
			var second_world := Rect2(second_platform.position + second_offset, second_platform.size)
			if first_world.intersects(second_world) and not shared_support.encloses(first_world.intersection(second_world)):
				return false
	var first_hazards := _forbidden(first)
	var second_hazards := _forbidden(second)
	for hazard: Rect2 in first_hazards:
		var world := Rect2(hazard.position + first_offset, hazard.size)
		for platform: Rect2 in second.platforms:
			if world.intersects(Rect2(platform.position + second_offset, platform.size)):
				return false
		for other: Rect2 in second_hazards:
			if world.intersects(Rect2(other.position + second_offset, other.size)):
				return false
	for hazard: Rect2 in second_hazards:
		var world := Rect2(hazard.position + second_offset, hazard.size)
		for platform: Rect2 in first.platforms:
			if world.intersects(Rect2(platform.position + first_offset, platform.size)):
				return false
	return true

func _valid_phases(phases: Variant, definition: PlatformingModuleDefinition) -> bool:
	if not phases is Array or phases.size() != definition.saws.size() + definition.ferries.size():
		return false
	var expected: Array[String] = []
	for saw: ModuleSawDefinition in definition.saws:
		expected.append(str(saw.source_id))
	for ferry: ModuleMovingPlatformDefinition in definition.ferries:
		expected.append(str(ferry.platform_id))
	for index: int in expected.size():
		if not phases[index] is Dictionary or not phases[index].get("id") is String or phases[index].get("id") != expected[index] or not phases[index].get("phase") is float and not phases[index].get("phase") is int or float(phases[index].get("phase")) not in [0.0, 0.25, 0.5, 0.75]:
			return false
	return true

func _manifest_hash(manifest: Dictionary) -> String:
	var copy := manifest.duplicate(true)
	copy.erase("manifest_hash")
	return JSON.stringify(_canonical(copy), "", true).sha256_text()

func _canonical(value: Variant) -> Variant:
	# Godot JSON parses all numbers as floats; normalize before integrity hashing.
	if value is int or value is float:
		return float(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _canonical(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_canonical(item))
		return result
	return value

func _numeric(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _valid_array(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for number: Variant in value:
		if not (number is float or number is int) or not is_finite(float(number)):
			return false
	return true

func _point_array(point: Vector2) -> Array:
	return [point.x, point.y]

func _rect_array(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _array_rect(value: Array) -> Rect2:
	return Rect2(value[0], value[1], value[2], value[3])

func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
