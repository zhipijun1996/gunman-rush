class_name WorldRoomValidation
extends RefCounted
## Shared runtime geometry checks. No authoring protocol or mutation entry point.
const INDEXED_FIELDS := ["platforms", "hazards", "climbable_walls", "hook_points", "signs", "art_placements", "retry_anchors"]

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

static func validate_room(room: FixedWorldRoom) -> String:
	var properties := {}
	var terrain_error := TerrainPaint.validate(properties.get("terrain_paint", room.terrain_paint))
	if not terrain_error.is_empty(): return terrain_error
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
	if properties.get("region_preview",room.region_preview)!=room.region_preview:return "region_preview_not_editable"
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
			if key == "environment_zones" and str(row.get("mode", "")) not in ["gas", "dark", "phase_light", "thorns", "water"]: return "environment_mode_invalid"
	for key: String in ["retry_anchors", "section_volumes"]:
		for row: Dictionary in properties.get(key, room.get(key)):
			if not rectangle(row.get("bounds")): return "bounds_invalid:"+key
			if key != "section_volumes" and not vector(row.get("point")): return "point_invalid:"+key
			if key == "section_volumes" and str(row.get("id", "")).is_empty(): return "section_id_missing"
	for row: Dictionary in properties.get("signs", room.signs):
		if not vector(row.get("point")) or not row.get("text") is String: return "sign_invalid"
	for row: Dictionary in properties.get("art_placements", room.art_placements):
		if row.has("surface_platform_id"):
			if str(row.surface_platform_id) not in properties.get("entity_ids", room.entity_ids).get("platforms",[]): return "art_surface_platform_missing"
			continue
		if row.has("surface_platform"):
			var index:Variant=row.surface_platform
			if not number(index) or floorf(float(index))!=float(index) or int(index)<0 or int(index)>=platform_count: return "art_surface_platform_invalid"
			continue
		if row.has("masonry_region"):
			if not rectangle(row.masonry_region): return "art_masonry_region_invalid"
			continue
		if not vector(row.get("point")): return "art_point_invalid"
		if row.has("tile_rect") and not rectangle(row.tile_rect):return "art_tile_rect_invalid"
		if row.has("material_transition"): return "manual_transition_retired_use_terrain_paint"
		if row.has("support_height"):
			if not number(row.support_height) or float(row.support_height) <= 0: return "art_support_invalid"
		elif not row.get("asset") is String or str(row.asset).is_empty(): return "art_asset_missing"
	var entity_ids: Dictionary = properties.get("entity_ids", room.entity_ids)
	for key: String in entity_ids:
		if key not in INDEXED_FIELDS or not entity_ids[key] is Array: return "indexed_ids_invalid"
		if entity_ids[key].size() != properties.get(key, room.get(key)).size(): return "indexed_id_count_mismatch:"+key
		for id: Variant in entity_ids[key]:
			if not id is String or str(id).is_empty() or identities.has(id): return "indexed_id_missing_or_duplicate"
			identities[id] = true
	return ""
