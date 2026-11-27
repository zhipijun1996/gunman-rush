class_name WorldRoomValidation
extends RefCounted
## Shared runtime geometry checks. No authoring protocol or mutation entry point.
const INDEXED_FIELDS := ["platforms", "hazards", "climbable_walls", "hook_points", "signs", "retry_anchors"]

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= 1000000.0

static func vector(value: Variant) -> bool:
	return value is Array and value.size() == 2 and number(value[0]) and number(value[1])

static func passage_error(exits: Variant) -> String:
	if not exits is Dictionary: return "room_exits_invalid"
	for id: Variant in exits:
		var gate: Variant = exits[id]
		if not id is String or id.is_empty() or not gate is Dictionary: return "room_exits_invalid"
		if not vector(gate.get("spawn")): return "room_entry_spawn_required"
		# Older documents recorded door anchors without opening a physical channel.
		if not gate.has("span"): continue
		if not vector(gate.get("point")) or not vector(gate.get("direction")) or not vector(gate.span):
			return "room_door_geometry_invalid"
		var direction := FixedWorldProvider.point(gate.direction)
		if direction not in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN] or gate.span[0] >= gate.span[1]:
			return "room_door_geometry_invalid"
	return ""

static func rectangle(value: Variant, allow_empty := false) -> bool:
	return value is Array and value.size() == 4 and number(value[0]) and number(value[1]) and number(value[2]) and number(value[3]) and (float(value[2]) >= 0.0 if allow_empty else float(value[2]) > 0.0) and (float(value[3]) >= 0.0 if allow_empty else float(value[3]) > 0.0)

static func valid_camera_landmark(landmark: Variant, sites: Variant) -> bool:
	if not landmark is Dictionary or not sites is Dictionary: return false
	if not rectangle(landmark.get("bounds")) or not landmark.get("site") is String: return false
	var target: Variant = sites.get(landmark.site)
	if not target is Dictionary or not vector(target.get("at")): return false
	for key: String in ["approach_width","framing","ease_seconds"]:
		if not number(landmark.get(key)) or landmark[key] <= 0: return false
	return landmark.framing <= 1 and landmark.approach_width <= landmark.bounds[2]

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

static func validate_room(room: FixedWorldRoom) -> String:
	if not TerrainMaterialRegistry.known(room.terrain_material): return "room_material_required"
	var properties := {}
	var terrain_error := TerrainPaint.validate(properties.get("terrain_paint", room.terrain_paint))
	if not terrain_error.is_empty(): return terrain_error
	var platform_count: int = properties.get("platforms", room.platforms).size()
	for key: String in ["one_way_indices", "illustrated_platform_indices", "masonry_platform_indices"]:
		for index: Variant in properties.get(key, room.get(key)):
			if int(index) < 0 or int(index) >= platform_count: return "platform_index_invalid:"+key
	var identities: Dictionary = {}
	for key: String in ["terrain_polygons", "enemy_placements", "spike_strips", "environment_zones"]:
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
			if key in ["spike_strips", "environment_zones"] and not rectangle(row.get("bounds")): return "bounds_invalid:"+key
			if key == "spike_strips" and str(row.get("facing", "up")) not in ["up", "down", "left", "right"]: return "spike_facing_invalid"
			if key == "environment_zones" and str(row.get("mode", "")) not in ["gas", "dark", "phase_light", "thorns", "water", "wind"]: return "environment_mode_invalid"
	for key: String in ["retry_anchors", "section_volumes"]:
		for row: Dictionary in properties.get(key, room.get(key)):
			if not rectangle(row.get("bounds")): return "bounds_invalid:"+key
			if key != "section_volumes" and not vector(row.get("point")): return "point_invalid:"+key
			if key == "section_volumes" and str(row.get("id", "")).is_empty(): return "section_id_missing"
	for row: Dictionary in properties.get("signs", room.signs):
		if not vector(row.get("point")) or not row.get("text") is String: return "sign_invalid"
	var entity_ids: Dictionary = properties.get("entity_ids", room.entity_ids)
	for key: String in entity_ids:
		if key not in INDEXED_FIELDS or not entity_ids[key] is Array: return "indexed_ids_invalid"
		if entity_ids[key].size() != properties.get(key, room.get(key)).size(): return "indexed_id_count_mismatch:"+key
		for id: Variant in entity_ids[key]:
			if not id is String or str(id).is_empty() or identities.has(id): return "indexed_id_missing_or_duplicate"
			identities[id] = true
	return ""
