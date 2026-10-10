class_name RandomStageGenerator
extends RefCounted

# Development preview only. Formal type/route/reward streams remain independent.
const MANIFEST_VERSION := 1
const GENERATOR_VERSION := "horizontal-preview-1"
const VALIDATOR_VERSION := "translated-ground-seams-1"
const CAMERA_PROFILE_VERSION := 1
const MAX_ATTEMPTS := 4
const GAP := 200.0
const CATALOG := ["safe_hub", "stepped_crossing", "descending_switchback", "recoil_shaft", "timed_gallery", "moving_transfer", "square_loop"]
const CONTENT_RUNTIME_VERSION := "platforming-module-runtime-1"

func generate(map_seed: int, tuning: PlayerTuning, module_count: int = 7) -> Dictionary:
	if tuning == null or module_count < 6 or module_count > 8:
		return _failure("Preview requires tuning and 6–8 modules")
	var candidates: Array[String] = []
	for module_id: String in CATALOG:
		if module_id != "safe_hub" and definition_for(module_id).supports(tuning):
			candidates.append(module_id)
	for attempt: int in MAX_ATTEMPTS:
		var rng := RandomNumberGenerator.new()
		rng.seed = map_seed + attempt * 104729
		var ids: Array[String] = ["safe_hub"]
		var bag := candidates.duplicate()
		for index: int in module_count - 2:
			if bag.is_empty():
				bag = candidates.duplicate()
			if bag.is_empty():
				ids.append("safe_hub")
			else:
				var selected := rng.randi_range(0, bag.size() - 1)
				ids.append(bag[selected])
				bag.remove_at(selected)
		ids.append("safe_hub")
		var manifest := _assemble_manifest(ids, map_seed, tuning, attempt, "", rng)
		var checked := validate_manifest(manifest, tuning)
		if checked.ok:
			return {"ok": true, "error": "", "manifest": manifest}
	# Compatible same-preview safe route; never changes a formal room type.
	var safe_ids: Array[String] = []
	for index: int in module_count:
		safe_ids.append("safe_hub")
	var safe_rng := RandomNumberGenerator.new()
	safe_rng.seed = map_seed
	var fallback := _assemble_manifest(safe_ids, map_seed, tuning, MAX_ATTEMPTS, "safe_walk_preview", safe_rng)
	var checked := validate_manifest(fallback, tuning)
	if not checked.ok:
		return _failure("No compatible preview fallback: " + str(checked.error))
	return {"ok": true, "error": "", "manifest": fallback}

func definition_for(module_id: String) -> PlatformingModuleDefinition:
	if module_id not in CATALOG:
		return null
	return load("res://resources/generation/modules/%s.tres" % module_id) as PlatformingModuleDefinition

func scene_for(module_id: String) -> PackedScene:
	if module_id not in CATALOG:
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
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_json_value(item))
		return result
	return value

func _assemble_manifest(ids: Array[String], map_seed: int, tuning: PlayerTuning, attempt: int, fallback_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var nodes: Array = []
	var seams: Array = []
	var offset := Vector2.ZERO
	var bounds := Rect2()
	var previous: PlatformingModuleDefinition
	var previous_offset := Vector2.ZERO
	for index: int in ids.size():
		var definition := definition_for(ids[index])
		if index > 0:
			offset = Vector2(previous_offset.x + previous.world_bounds.end.x + GAP - definition.world_bounds.position.x, previous_offset.y + previous.exit_port.position.y - definition.entry_port.position.y)
			var start := previous.exit_port.position + previous_offset
			var finish := definition.entry_port.position + offset
			seams.append({"id": "seam_%02d" % (index - 1), "from": index - 1, "to": index, "rect": _rect_array(Rect2(start + Vector2(-24, 18), Vector2(finish.x - start.x + 48, 32))), "anchor": _point_array(Vector2((start.x + finish.x) / 2.0, start.y))})
		var phases: Array = []
		for saw: ModuleSawDefinition in definition.saws:
			phases.append({"id": str(saw.source_id), "phase": rng.randi_range(0, 3) * 0.25})
		for ferry: ModuleMovingPlatformDefinition in definition.ferries:
			phases.append({"id": str(ferry.platform_id), "phase": rng.randi_range(0, 3) * 0.25})
		nodes.append({"id": "module_%02d" % index, "module_id": ids[index], "version": definition.definition_version, "content_hash": content_hash(ids[index]), "offset": _point_array(offset), "initial_phases": phases})
		var node_bounds := Rect2(definition.world_bounds.position + offset, definition.world_bounds.size)
		bounds = node_bounds if index == 0 else bounds.merge(node_bounds)
		previous = definition
		previous_offset = offset
	var manifest := {"manifest_version": MANIFEST_VERSION, "generator_version": GENERATOR_VERSION, "validator_version": VALIDATOR_VERSION, "development_only": true, "layout_id": "horizontal_chain_preview", "seed": str(map_seed), "attempt_index": attempt, "fallback_id": fallback_id, "fallback_reason": "bounded_geometry_attempts_exhausted" if not fallback_id.is_empty() else "", "capabilities": capability_snapshot(tuning), "physics_hash": physics_hash(tuning), "nodes": nodes, "seams": seams, "world_bounds": _rect_array(bounds), "camera_profile_id": "horizontal_preview_follow", "camera_profile_version": CAMERA_PROFILE_VERSION, "engine_version": str(Engine.get_version_info().string), "validation_scope": "geometry_ports_and_existing_module_traces; whole_stage_motor_test_separate"}
	manifest["manifest_hash"] = _manifest_hash(manifest)
	return manifest

func validate_manifest(manifest: Dictionary, tuning: PlayerTuning) -> Dictionary:
	if tuning == null or not _numeric(manifest.get("manifest_version")) or manifest.get("manifest_version") != MANIFEST_VERSION or not manifest.get("generator_version") is String or manifest.get("generator_version") != GENERATOR_VERSION or not manifest.get("validator_version") is String or manifest.get("validator_version") != VALIDATOR_VERSION or not manifest.get("development_only") is bool or manifest.get("development_only") != true or not manifest.get("layout_id") is String or manifest.get("layout_id") != "horizontal_chain_preview":
		return _failure("Incompatible manifest version or layout")
	if not manifest.get("camera_profile_id") is String or manifest.get("camera_profile_id") != "horizontal_preview_follow" or not _numeric(manifest.get("camera_profile_version")) or manifest.get("camera_profile_version") != CAMERA_PROFILE_VERSION:
		return _failure("Incompatible camera profile")
	if not manifest.get("engine_version") is String or manifest.get("engine_version") != str(Engine.get_version_info().string):
		return _failure("Incompatible engine version")
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
	var nodes: Variant = manifest.get("nodes")
	var seams: Variant = manifest.get("seams")
	if not nodes is Array or nodes.size() < 6 or nodes.size() > 8 or not seams is Array or seams.size() != nodes.size() - 1:
		return _failure("Invalid graph size")
	var bounds := Rect2()
	var occupied: Array[Rect2] = []
	var previous: PlatformingModuleDefinition
	var previous_offset := Vector2.ZERO
	for index: int in nodes.size():
		var node: Variant = nodes[index]
		if not node is Dictionary or not node.get("id") is String or node.get("id") != "module_%02d" % index or not node.get("module_id") is String:
			return _failure("Invalid node identity")
		var definition := definition_for(node.module_id)
		if definition == null or not definition.supports(tuning) or not _numeric(node.get("version")) or node.get("version") != definition.definition_version or not node.get("content_hash") is String or node.get("content_hash") != content_hash(node.module_id) or not _valid_array(node.get("offset"), 2):
			return _failure("Incompatible module content or capability")
		if (index == 0 or index == nodes.size() - 1 or attempt == MAX_ATTEMPTS) and node.module_id != "safe_hub":
			return _failure("Unsafe entry/exit module")
		var offset := Vector2(node.offset[0], node.offset[1])
		if index == 0 and offset != Vector2.ZERO:
			return _failure("Invalid stage origin")
		var node_bounds := Rect2(definition.world_bounds.position + offset, definition.world_bounds.size)
		for other: Rect2 in occupied:
			if other.intersects(node_bounds):
				return _failure("Module world bounds overlap")
		occupied.append(node_bounds)
		bounds = node_bounds if index == 0 else bounds.merge(node_bounds)
		if not _valid_phases(node.get("initial_phases"), definition):
			return _failure("Invalid recorded initial phase")
		if index > 0:
			var expected_offset := Vector2(previous_offset.x + previous.world_bounds.end.x + GAP - definition.world_bounds.position.x, previous_offset.y + previous.exit_port.position.y - definition.entry_port.position.y)
			if offset != expected_offset:
				return _failure("Disconnected module transform")
			var seam: Variant = seams[index - 1]
			var start := previous.exit_port.position + previous_offset
			var finish := definition.entry_port.position + offset
			var expected := Rect2(start + Vector2(-24, 18), Vector2(finish.x - start.x + 48, 32))
			if not seam is Dictionary or not seam.get("id") is String or seam.get("id") != "seam_%02d" % (index - 1) or not _numeric(seam.get("from")) or seam.get("from") != index - 1 or not _numeric(seam.get("to")) or seam.get("to") != index or not _valid_array(seam.get("rect"), 4) or not _valid_array(seam.get("anchor"), 2) or _array_rect(seam.rect) != expected or Vector2(seam.anchor[0], seam.anchor[1]) != Vector2((start.x + finish.x) / 2, start.y):
				return _failure("Invalid grounded seam")
			if not _clear_seam(expected, previous, previous_offset) or not _clear_seam(expected, definition, offset):
				return _failure("Seam intersects hazard or body clearance")
		previous = definition
		previous_offset = offset
	if not _valid_array(manifest.get("world_bounds"), 4) or _array_rect(manifest.world_bounds) != bounds:
		return _failure("Invalid world bounds")
	return {"ok": true, "error": ""}

func _clear_seam(seam: Rect2, definition: PlatformingModuleDefinition, offset: Vector2) -> bool:
	var corridor := Rect2(seam.position - Vector2(0, 44), Vector2(seam.size.x, 44))
	for platform: Rect2 in definition.platforms:
		if Rect2(platform.position + offset, platform.size).intersects(corridor):
			return false
	var forbidden: Array[Rect2] = definition.danger_bounds.duplicate()
	for saw: ModuleSawDefinition in definition.saws:
		forbidden.append(saw.envelope())
	for ferry: ModuleMovingPlatformDefinition in definition.ferries:
		forbidden.append(ferry.envelope())
	for rect: Rect2 in forbidden:
		if Rect2(rect.position + offset, rect.size).intersects(corridor.grow(8)):
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
		if not phases[index] is Dictionary or not phases[index].get("id") is String or phases[index].get("id") != expected[index] or not phases[index].get("phase") is float and not phases[index].get("phase") is int or phases[index].get("phase") not in [0, 0.25, 0.5, 0.75]:
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
