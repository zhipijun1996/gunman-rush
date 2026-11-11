class_name WorldRoomDraft
extends RefCounted
## One data adapter for the browser draft and ResourceSaver authoring tool.
## Apply only to a fresh scene instance, before _ready creates any physics.
const SCHEMA := 1
const ROOM_FIELDS := [
	"story_sequence", "intro_sequence", "wave_encounter", "route_guide", "arrival_text", "traveler_point", "tutorial_action", "tutorial_target",
	"tutorial_min_move", "tutorial_recoil_finish_x", "section_volumes",
	"retry_anchors", "art_placements", "art_profile",
	"bell_mechanisms", "platforms", "one_way_indices", "illustrated_platform_indices",
	"masonry_platform_indices", "start_point", "rest_point", "reward_point",
	"enemy_placements", "signs", "hazards", "spike_strips", "gear_obstacles",
	"hook_points", "climbable_walls", "environment_zones", "boss_position",
	"arena_bounds", "battle_entry_anchor", "arena_door_height", "terrain_polygons",
	"workbench_entity_ids"
]
const INDEXED_FIELDS := ["platforms", "hazards", "climbable_walls", "hook_points", "signs", "art_placements", "retry_anchors"]
const NODE_SCRIPTS := {
	"GrappleAnchor": "res://game/world/components/grapple_anchor.gd",
	"WorldMovingPlatform": "res://game/world/components/world_moving_platform.gd",
	"WorldRoomInteraction": "res://game/world/components/world_room_interaction.gd",
	"WorldReturnLatch": "res://game/world/components/world_return_latch.gd",
	"WorldFlagPresentation": "res://game/world/components/world_flag_presentation.gd",
	"WorldNpc": "res://game/npcs/world_npc.gd"
}
const NODE_FIELDS := {
	"GrappleAnchor": ["position", "hang_enabled", "material_family"],
	"WorldMovingPlatform": ["position", "endpoint", "platform_size", "period", "phase_offset", "one_way", "route", "endpoint_dwell", "activation_flag"],
	"WorldRoomInteraction": ["position", "action_id", "section_id", "label", "visual", "radius"],
	"WorldReturnLatch": ["position", "action_id", "section_id", "label", "visual", "radius", "return_steps", "closed_panels", "metal_hatch"],
	"WorldFlagPresentation": ["position", "flag"],
	"WorldNpc": ["position", "npc_id", "visual_kind", "display_name"]
}

static func extract(room: FixedWorldRoom) -> Dictionary:
	assert(not room.is_inside_tree(), "Export a fresh PackedScene, not runtime-created bodies.")
	var properties: Dictionary = {}
	for key: String in ROOM_FIELDS:
		properties[key] = encode(room.get(key))
	var ids: Dictionary = properties.get("workbench_entity_ids", {}).duplicate(true)
	for key: String in INDEXED_FIELDS:
		var previous: Array = ids.get(key, [])
		var identities: Array = []
		for index: int in properties[key].size():
			identities.append(str(previous[index]) if index < previous.size() else room.room_id+":"+key+":"+str(index))
		ids[key] = identities
	properties["workbench_entity_ids"] = ids
	var nodes: Array = []
	for node: Node in room.find_children("*", "", true, false):
		var kind := node_kind(node)
		if kind.is_empty(): continue
		var values: Dictionary = {}
		for key: String in NODE_FIELDS[kind]: values[key] = encode(node.get(key))
		nodes.append({"path": str(room.get_path_to(node)), "type": kind, "properties": values})
	return {"schema": SCHEMA, "room_id": room.room_id, "properties": properties, "nodes": nodes}

static func encode(value: Variant) -> Variant:
	if value is Vector2: return [value.x, value.y]
	if value is Rect2: return [value.position.x, value.position.y, value.size.x, value.size.y]
	if value is StringName or value is NodePath: return str(value)
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(encode(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[str(key)] = encode(value[key])
		return result
	return value

static func node_kind(node: Node) -> String:
	var script: Script = node.get_script()
	if script == null: return ""
	for kind: String in NODE_SCRIPTS:
		if script.resource_path == NODE_SCRIPTS[kind]: return kind
	return ""

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= 1000000.0

static func vector(value: Variant) -> bool:
	return value is Array and value.size() == 2 and number(value[0]) and number(value[1])

static func rectangle(value: Variant, allow_empty := false) -> bool:
	return value is Array and value.size() == 4 and number(value[0]) and number(value[1]) and number(value[2]) and number(value[3]) and (float(value[2]) >= 0.0 if allow_empty else float(value[2]) > 0.0) and (float(value[3]) >= 0.0 if allow_empty else float(value[3]) > 0.0)

static func json_error(value: Variant, depth := 0) -> String:
	if depth > 16: return "data_too_deep"
	if value == null or value is bool: return ""
	if value is int or value is float: return "" if number(value) else "invalid_number"
	if value is String: return "" if value.length() <= 16384 else "text_too_long"
	if value is Array or value is Dictionary:
		if value.size() > 4096: return "too_many_items"
		for key: Variant in value:
			var item: Variant = value[key] if value is Dictionary else key
			if value is Dictionary and not key is String and not key is StringName: return "invalid_key"
			var error := json_error(item, depth+1)
			if not error.is_empty(): return error
		return ""
	return "unsupported_value"

static func polygon_error(row: Variant) -> String:
	if not row is Dictionary or not row.get("id") is String or str(row.id).is_empty(): return "polygon_id_missing"
	var points: Variant = row.get("points")
	if not points is Array or points.size() < 3 or points.size() > 64: return "polygon_vertex_count"
	var vertices := PackedVector2Array()
	for point: Variant in points:
		if not vector(point): return "polygon_point_invalid"
		vertices.append(Vector2(float(point[0]), float(point[1])))
	for index: int in vertices.size():
		var a := vertices[index]
		var b := vertices[(index+1) % vertices.size()]
		if a.distance_squared_to(b) < 0.01: return "polygon_duplicate_vertex"
		for other: int in range(index+1, vertices.size()):
			if other == index+1 or (index == 0 and other == vertices.size()-1): continue
			var hit: Variant = Geometry2D.segment_intersects_segment(a, b, vertices[other], vertices[(other+1) % vertices.size()])
			if hit != null: return "polygon_self_intersection"
	if Geometry2D.triangulate_polygon(vertices).size() != (vertices.size()-2)*3: return "polygon_not_simple"
	if str(row.get("material", "ground")) not in ["ground", "masonry"]: return "polygon_material_unknown"
	return ""

static func property_error(original: Variant, value: Variant) -> String:
	if original is Vector2: return "" if vector(value) else "vector_required"
	if original is Rect2: return "" if rectangle(value, true) else "rect_required"
	if original is bool: return "" if value is bool else "bool_required"
	if original is int: return "" if number(value) and float(value) == floorf(float(value)) else "integer_required"
	if original is float: return "" if number(value) else "number_required"
	if original is String or original is StringName: return "" if value is String else "string_required"
	if original is Dictionary: return "" if value is Dictionary else "dictionary_required"
	if original is Array:
		if not value is Array: return "array_required"
		for item: Variant in value:
			match original.get_typed_builtin():
				TYPE_RECT2:
					if not rectangle(item): return "positive_rect_required"
				TYPE_VECTOR2:
					if not vector(item): return "vector_required"
				TYPE_DICTIONARY:
					if not item is Dictionary: return "dictionary_required"
				TYPE_INT:
					if not number(item) or float(item) != floorf(float(item)): return "integer_required"
		return ""
	return "unsupported_property_type"

static func decode(original: Variant, value: Variant) -> Variant:
	if original is Vector2: return Vector2(float(value[0]), float(value[1]))
	if original is Rect2: return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	if original is StringName: return StringName(value)
	if original is int: return int(value)
	if original is float: return float(value)
	if original is Array:
		match original.get_typed_builtin():
			TYPE_RECT2:
				var result: Array[Rect2] = []
				for item: Array in value: result.append(Rect2(float(item[0]), float(item[1]), float(item[2]), float(item[3])))
				return result
			TYPE_VECTOR2:
				var result: Array[Vector2] = []
				for item: Array in value: result.append(Vector2(float(item[0]), float(item[1])))
				return result
			TYPE_INT:
				var result: Array[int] = []
				for item: Variant in value: result.append(int(item))
				return result
			TYPE_DICTIONARY:
				var result: Array[Dictionary] = []
				result.assign(value.duplicate(true))
				return result
		return value.duplicate(true)
	if original is Dictionary: return value.duplicate(true)
	return value

static func validate(room: FixedWorldRoom, draft: Dictionary) -> String:
	if room.is_inside_tree(): return "room_already_running"
	if draft.get("schema") != SCHEMA or str(draft.get("room_id", "")) != room.room_id: return "draft_identity_mismatch"
	var safe := json_error(draft)
	if not safe.is_empty(): return safe
	if not draft.get("properties") is Dictionary or not draft.get("nodes", []) is Array: return "draft_shape_invalid"
	var properties: Dictionary = draft.properties
	for key: String in properties:
		if key not in ROOM_FIELDS: return "property_not_editable:"+key
		var error := property_error(room.get(key), properties[key])
		if not error.is_empty(): return key+":"+error
	var intro: Dictionary=properties.get("intro_sequence",room.intro_sequence)
	if not intro.is_empty():
		if intro.get("kind") not in ["wake","traveler"]:return "intro_kind_invalid"
		if intro.kind=="wake" and not vector(intro.get("pickup_point")):return "intro_pickup_invalid"
		if intro.kind=="traveler" and (not rectangle(intro.get("trigger")) or not intro.get("lines") is Array or intro.lines.is_empty()):return "intro_dialogue_invalid"
	var encounter: Dictionary=properties.get("wave_encounter",room.wave_encounter)
	if not encounter.is_empty():
		for key: String in ["trigger","exit_gate","entry_gate"]:
			if not rectangle(encounter.get(key)):return "wave_rect_invalid:"+key
		for key: String in ["recovery_point","label_point"]:
			if not vector(encounter.get(key)):return "wave_point_invalid:"+key
		if not encounter.get("completion_action") is String or not encounter.get("waves") is Array or encounter.waves.is_empty():return "wave_sequence_invalid"
		var wave_ids: Dictionary={}
		for wave: Variant in encounter.waves:
			if not wave is Array or wave.is_empty():return "wave_empty"
			for spec: Variant in wave:
				if not spec is Dictionary or str(spec.get("id","")).is_empty() or wave_ids.has(str(spec.id)) or not vector(spec.get("point")):return "wave_enemy_invalid"
				if EnemyFactory.scene_path_for_behavior(StringName(str(spec.get("behavior","")))).is_empty():return "wave_species_invalid"
				if not spec.get("max_health",5) is float and not spec.get("max_health",5) is int:return "wave_health_invalid"
				if float(spec.get("max_health",5))<=0:return "wave_health_invalid"
				wave_ids[str(spec.id)]=true
	var platform_count: int = properties.get("platforms", room.platforms).size()
	for key: String in ["one_way_indices", "illustrated_platform_indices", "masonry_platform_indices"]:
		for index: Variant in properties.get(key, room.get(key)):
			if int(index) < 0 or int(index) >= platform_count: return "platform_index_invalid:"+key
	var identities: Dictionary = {}
	for key: String in ["terrain_polygons", "enemy_placements", "bell_mechanisms", "spike_strips", "gear_obstacles", "environment_zones"]:
		for row: Dictionary in properties.get(key, room.get(key)):
			var id := str(row.get("id", ""))
			if id.is_empty() or identities.has(id): return "entity_id_missing_or_duplicate:"+key
			identities[id] = true
			if key == "terrain_polygons":
				var error := polygon_error(row)
				if not error.is_empty(): return error
			if key == "enemy_placements":
				if not vector(row.get("point")): return "enemy_point_invalid"
				if EnemyFactory.scene_path_for_behavior(StringName(str(row.get("behavior", "")))).is_empty(): return "enemy_behavior_unknown"
				if row.has("max_health") and (not number(row.max_health) or float(row.max_health) <= 0): return "enemy_health_invalid"
			if key == "bell_mechanisms":
				if not vector(row.get("bell")): return "bell_point_invalid"
				if row.has("gate") and not rectangle(row.gate): return "bell_gate_invalid"
				if row.has("open_seconds") and (not number(row.open_seconds) or float(row.open_seconds) < 0): return "bell_time_invalid"
				if row.has("access_bells") and not row.access_bells is Array: return "bell_access_points_invalid"
				for point: Variant in row.get("access_bells", []):
					if not vector(point): return "bell_access_point_invalid"
			if key in ["spike_strips", "environment_zones"] and not rectangle(row.get("bounds")): return "bounds_invalid:"+key
			if key == "spike_strips" and str(row.get("facing", "up")) not in ["up", "down", "left", "right"]: return "spike_facing_invalid"
			if key == "environment_zones" and str(row.get("mode", "")) not in ["gas", "dark", "phase_light", "thorns", "water"]: return "environment_mode_invalid"
			if key == "gear_obstacles":
				if not vector(row.get("point")) or not vector(row.get("travel", [0, 0])): return "gear_point_invalid"
				if not number(row.get("period", 4.8)) or float(row.get("period", 4.8)) <= 0.05: return "gear_period_invalid"
				if not number(row.get("phase", 0)): return "gear_phase_invalid"
	for key: String in ["retry_anchors", "section_volumes"]:
		for row: Dictionary in properties.get(key, room.get(key)):
			if not rectangle(row.get("bounds")): return "bounds_invalid:"+key
			if key != "section_volumes" and not vector(row.get("point")): return "point_invalid:"+key
			if key == "section_volumes" and str(row.get("id", "")).is_empty(): return "section_id_missing"
	for row: Dictionary in properties.get("signs", room.signs):
		if not vector(row.get("point")) or not row.get("text") is String: return "sign_invalid"
	for row: Dictionary in properties.get("art_placements", room.art_placements):
		if row.has("surface_platform"):
			var index:Variant=row.surface_platform
			if not number(index) or floorf(float(index))!=float(index) or int(index)<0 or int(index)>=platform_count: return "art_surface_platform_invalid"
			continue
		if row.has("masonry_region"):
			if not rectangle(row.masonry_region): return "art_masonry_region_invalid"
			continue
		if not vector(row.get("point")): return "art_point_invalid"
		if row.has("tile_rect") and not rectangle(row.tile_rect):return "art_tile_rect_invalid"
		if row.has("support_height"):
			if not number(row.support_height) or float(row.support_height) <= 0: return "art_support_invalid"
		elif not row.get("asset") is String or str(row.asset).is_empty(): return "art_asset_missing"
	var entity_ids: Dictionary = properties.get("workbench_entity_ids", room.workbench_entity_ids)
	for key: String in entity_ids:
		if key not in INDEXED_FIELDS or not entity_ids[key] is Array: return "indexed_ids_invalid"
		if entity_ids[key].size() != properties.get(key, room.get(key)).size(): return "indexed_id_count_mismatch:"+key
		for id: Variant in entity_ids[key]:
			if not id is String or str(id).is_empty() or identities.has(id): return "indexed_id_missing_or_duplicate"
			identities[id] = true
	var paths: Dictionary = {}
	for row: Variant in draft.get("nodes", []):
		if not row is Dictionary or not row.get("properties") is Dictionary: return "node_shape_invalid"
		var path := str(row.get("path", ""))
		var kind := str(row.get("type", ""))
		if not valid_path(path) or paths.has(path) or not NODE_SCRIPTS.has(kind): return "node_identity_invalid"
		paths[path] = true
		var existing := room.get_node_or_null(NodePath(path))
		if existing != null and node_kind(existing) != kind: return "node_type_change_rejected:"+path
		var probe: Node = existing if existing != null else (load(NODE_SCRIPTS[kind]) as Script).new()
		var error := ""
		for key: String in row.properties:
			if key not in NODE_FIELDS[kind]: error = "node_property_not_editable:"+key;break
			error = property_error(probe.get(key), row.properties[key])
			if not error.is_empty(): break
		if existing == null: probe.free()
		if not error.is_empty(): return error
		if kind == "WorldMovingPlatform":
			if row.properties.has("period") and float(row.properties.period) <= 0.05: return "platform_period_invalid"
			if row.properties.has("platform_size") and (float(row.properties.platform_size[0]) <= 0 or float(row.properties.platform_size[1]) <= 0): return "platform_size_invalid"
			if row.properties.has("endpoint_dwell") and float(row.properties.endpoint_dwell) < 0: return "platform_dwell_invalid"
	for row: Dictionary in draft.get("nodes", []):
		var parent := str(row.path).get_base_dir()
		if not parent.is_empty() and not paths.has(parent):
			var parent_node := room.get_node_or_null(NodePath(parent))
			if parent_node == null or not node_kind(parent_node).is_empty(): return "node_parent_missing"
	for row: Dictionary in properties.get("bell_mechanisms", room.bell_mechanisms):
		if not row.has("carrier"): continue
		var carrier_path := str(row.carrier)
		var carrier_type := ""
		if draft.has("nodes"):
			for node_row: Dictionary in draft.nodes:
				if str(node_row.path) == carrier_path: carrier_type = str(node_row.type)
		else:
			var carrier_node := room.get_node_or_null(NodePath(carrier_path))
			if carrier_node != null: carrier_type = node_kind(carrier_node)
		if carrier_type != "WorldMovingPlatform": return "bell_carrier_missing:"+carrier_path
	for row: Dictionary in properties.get("gear_obstacles", room.gear_obstacles):
		if not row.has("drive"): continue
		var drive_path := str(row.drive)
		var available := false
		for node_row: Dictionary in draft.get("nodes", []):
			if str(node_row.path) == drive_path and str(node_row.type) == "WorldMovingPlatform": available = true
		if not draft.has("nodes"):
			available = room.get_node_or_null(NodePath(drive_path)) is WorldMovingPlatform
		if not available: return "gear_drive_missing:"+drive_path
	return ""

static func valid_path(value: String) -> bool:
	if value.is_empty() or value.length() > 256 or value.begins_with("/") or value.contains(":") or value.contains("\\"): return false
	for part: String in value.split("/"):
		if part.is_empty() or part in [".", ".."] or NodePath(part).get_name_count() != 1: return false
		if part.validate_node_name() != part or part.contains("%") or part.contains("@"): return false
	return true

static func apply(room: FixedWorldRoom, draft: Dictionary) -> String:
	var error := validate(room, draft)
	if not error.is_empty(): return error
	for key: String in draft.properties: room.set(key, decode(room.get(key), draft.properties[key]))
	if not draft.has("nodes"): return ""
	var wanted: Dictionary = {}
	for row: Dictionary in draft.nodes: wanted[str(row.path)] = row
	var previous: Array[Node] = room.find_children("*", "", true, false)
	previous.reverse()
	for node: Node in previous:
		if not node_kind(node).is_empty() and not wanted.has(str(room.get_path_to(node))):
			node.get_parent().remove_child(node)
			node.free()
	var paths: Array = wanted.keys()
	paths.sort_custom(func(a: String, b: String) -> bool: return a.count("/") < b.count("/"))
	for path: String in paths:
		var row: Dictionary = wanted[path]
		var node := room.get_node_or_null(NodePath(path))
		if node == null:
			node = (load(NODE_SCRIPTS[str(row.type)]) as Script).new()
			node.name = path.get_file()
			var parent_path := path.get_base_dir()
			var parent := room if parent_path.is_empty() else room.get_node(NodePath(parent_path))
			parent.add_child(node)
			node.owner = room
		for key: String in row.properties: node.set(key, decode(node.get(key), row.properties[key]))
	return ""
