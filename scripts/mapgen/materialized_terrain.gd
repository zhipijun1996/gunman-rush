extends RefCounted
## Builds exactly one native terrain graph from already materialized local pixels.
const LOOP = preload("res://third_party/mapgen/0.1.0/module_pack/runtime/module_runtime/install_v1-e73bc68f3203.gd")
const ELLIPSE = preload("res://third_party/mapgen/0.1.0/module_pack/runtime/module_runtime/revision061_ellipse_install_v1-7416999b951a.gd")
const MIRRORED_ELLIPSE = preload("res://scripts/mapgen/materialized_ellipse.gd")

static func build(host: Node2D, content: Dictionary, definition: PlatformingModuleDefinition, loops: bool, ellipses: bool) -> Dictionary:
	if content.get("schema") != "pcg/compiled-module-content/v1" or content.get("coordinate_frame") != "owned_rectangle_pixels":
		return {"ok": false, "reason": "materialized_coordinate_contract_required"}
	definition.module_id = StringName(content.stable_id)
	if definition.get("allow_same_port_return") != null:
		definition.set("allow_same_port_return", true)
	if definition.get("air_points") != null:
		for port: Dictionary in content.get("ports", []):
			if port.surface == "AIR":
				definition.air_points.append(Vector2(port.stagingPosition[0], port.stagingPosition[1]))
	definition.world_bounds = rect(content.world_bounds)
	for value: Array in content.platforms:
		definition.platforms.append(rect(value))
	for value: Array in content.hazards:
		definition.danger_bounds.append(rect(value))
	for raw: Dictionary in content.moving_platforms:
		var value := ModuleMovingPlatformDefinition.new()
		for key: String in ["platform_id", "travel_duration", "dwell_duration", "initial_phase"]:
			if raw.has(key): value.set(key, raw[key])
		for key: String in ["start", "finish", "size"]:
			if raw.has(key): value.set(key, point(raw[key]))
		definition.ferries.append(value)
	for raw: Dictionary in content.saws:
		var value := ModuleSawDefinition.new()
		for key: String in ["source_id", "radius", "period", "initial_phase", "damage", "contact_interval"]:
			if raw.has(key): value.set(key, raw[key])
		for key: String in ["origin", "travel"]:
			if raw.has(key): value.set(key, point(raw[key]))
		definition.saws.append(value)
	for raw: Dictionary in content.thorns:
		var value := PlatformThornDefinition.new()
		for key: String in ["surface_id", "platform_index", "start_offset", "length", "depth"]:
			if raw.has(key): value.set(key, raw[key])
		var face: Variant = raw.get("face", "top")
		value.face = ["top", "left", "right", "bottom"].find(face) if face is String else int(face)
		definition.surface_thorns.append(value)
	for index: Variant in content.one_way_platform_indices:
		definition.one_way_platform_indices.append(int(index))
	definition.entry_port = PlatformingModulePort.new()
	definition.entry_port.port_id = &"entry"
	definition.entry_port.position = point(content.entry_port)
	definition.exit_port = PlatformingModulePort.new()
	definition.exit_port.port_id = &"exit"
	definition.exit_port.position = point(content.exit_port)
	definition.anchors.append(definition.entry_port.position)
	definition.anchors.append(definition.exit_port.position)
	if loops: LOOP.install(definition, content)
	if ellipses:
		for index: int in content.moving_platforms.size():
			var raw: Dictionary = content.moving_platforms[index]
			if raw.get("trajectory_kind", "") != "clockwise_ellipse/v1": continue
			var native = ELLIPSE.from_raw(raw)
			var mirrored := MIRRORED_ELLIPSE.new()
			for key: String in ["platform_id", "size", "center", "radii", "travel_duration", "dwell_duration", "initial_phase", "start", "finish"]:
				mirrored.set(key, native.get(key))
			mirrored.ellipse_x_sign = float(raw.get("ellipse_x_sign", 1))
			mirrored.materialized_center = native.center
			mirrored.materialized_radii = native.radii
			definition.ferries[index] = mirrored
	if not definition.is_valid():
		return {"ok": false, "reason": "native_definition_rejected_materialized_content/" + str(content.stable_id)}
	var module := PlatformingModule.new()
	module.name = "Content"
	module.definition = definition
	module.authoring_debug = false
	host.add_child(module)
	for index: Variant in content.wall_platform_indices:
		module.get_node("Platform" + str(int(index))).add_to_group(&"wall_climbable")
	return {"ok": true, "module": module}

static func point(raw: Array) -> Vector2:
	return Vector2(raw[0], raw[1])

static func rect(raw: Array) -> Rect2:
	return Rect2(raw[0], raw[1], raw[2], raw[3])
