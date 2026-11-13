class_name WorldRoomDocument
extends RefCounted
## Complete static room authoring document. Runtime creates the existing game
## components; no external JSON-to-scene build and no second movement engine.
const SCHEMA := 2
const COMPONENTS := {
	"FixedWorldRoom":"res://game/world/levels/fixed_world_room.gd",
	"StarbridgeTrialRoom":"res://game/world/regions/V/starbridge_trial_room.gd",
	"WorldRoomInteraction":"res://game/world/components/world_room_interaction.gd",
	"WorldReturnLatch":"res://game/world/components/world_return_latch.gd",
	"WorldMovingPlatform":"res://game/world/components/world_moving_platform.gd",
	"WorldNpc":"res://game/npcs/world_npc.gd",
	"GrappleAnchor":"res://game/world/components/grapple_anchor.gd",
	"PlatformingModule":"res://game/world/components/platforming_module.gd",
	"WorldModuleTerrain":"res://game/presentation/world/plains_v07/world_module_terrain.gd",
	"WorldFlagPresentation":"res://game/world/components/world_flag_presentation.gd"
}
const SCRIPT_RESOURCES := [
	"res://game/bosses/windkeeper/windkeeper_world_binding.gd",
	"res://game/bosses/bellstrider/bellstrider_world_binding.gd"
]
const ENTITY_FIELDS := ["platforms", "terrain_polygons", "enemy_placements", "bell_mechanisms", "spike_strips", "gear_obstacles", "hook_points", "climbable_walls", "environment_zones", "art_placements", "hazards", "signs", "retry_anchors"]
const PLATFORM_FLAGS := {"one_way":"one_way_indices", "masonry":"masonry_platform_indices", "illustrated":"illustrated_platform_indices"}

static func component_for(script: Script) -> String:
	if script == null: return ""
	for key: String in COMPONENTS:
		if COMPONENTS[key] == script.resource_path: return key
	return ""

static func encode(value: Variant) -> Variant:
	if value is Vector2: return [value.x, value.y]
	if value is Rect2: return [value.position.x, value.position.y, value.size.x, value.size.y]
	if value is Color: return {"$color":[value.r, value.g, value.b, value.a]}
	if value is Resource:
		return {"$resource":value.resource_path} if not value.resource_path.is_empty() and not value.resource_path.contains("::") else {"$unsupported":"embedded_resource"}
	if value is StringName or value is NodePath: return str(value)
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(encode(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[str(key)] = encode(value[key])
		return result
	if value == null or value is String or value is bool or value is int or value is float: return value
	return {"$unsupported":type_string(typeof(value))}

static func value_error(value: Variant, depth := 0) -> String:
	if depth > 48: return "document_too_deep"
	if value is float and not is_finite(value): return "non_finite"
	if value is Dictionary:
		if value.has("$unsupported"): return "unsupported:"+str(value["$unsupported"])
		if value.has("$color") and (not value["$color"] is Array or value["$color"].size() != 4): return "color_invalid"
		if value.has("$resource"):
			var path := str(value["$resource"])
			if path.contains("..") or not (path.begins_with("res://game/") or path.begins_with("res://assets/") or path.begins_with("res://resources/")): return "resource_not_registered"
			if path.ends_with(".gd") and path not in SCRIPT_RESOURCES: return "script_resource_not_registered"
			if not ResourceLoader.exists(path): return "resource_missing:"+path
		for item: Variant in value.values():
			var error := value_error(item, depth+1)
			if not error.is_empty(): return error
	elif value is Array:
		for item: Variant in value:
			var error := value_error(item, depth+1)
			if not error.is_empty(): return error
	return ""

static func decode(original: Variant, value: Variant) -> Variant:
	if value is Dictionary and value.has("$resource"): return load(str(value["$resource"]))
	if value is Dictionary and value.has("$color"):
		var rgba: Array = value["$color"]
		return Color(float(rgba[0]), float(rgba[1]), float(rgba[2]), float(rgba[3]))
	if original is Vector2: return Vector2(float(value[0]), float(value[1]))
	if original is Rect2: return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	if original is StringName: return StringName(str(value))
	if original is NodePath: return NodePath(str(value))
	if original is int: return int(value)
	if original is Array:
		var result: Array = original.duplicate()
		result.clear()
		for item: Variant in value:
			match original.get_typed_builtin():
				TYPE_VECTOR2: result.append(Vector2(float(item[0]), float(item[1])))
				TYPE_RECT2: result.append(Rect2(float(item[0]), float(item[1]), float(item[2]), float(item[3])))
				TYPE_INT: result.append(int(item))
				_: result.append(decode(null, item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[key] = decode(null, value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(decode(null, item))
		return result
	return value

static func extract(packed: PackedScene) -> Dictionary:
	var source := packed.instantiate()
	if not str(source.get("document_ref")).is_empty():
		var document := read(str(source.get("document_ref")))
		source.free()
		return document
	var root_component := component_for(source.get_script())
	if root_component not in ["FixedWorldRoom", "StarbridgeTrialRoom"]:
		source.free()
		return {"error":"root_component_unregistered"}
	var state := packed.get_state()
	var document := {"schema":SCHEMA, "room_id":str(source.get("room_id")), "root":{"component":root_component, "properties":{}}, "entities":{}}
	var node_ids: Dictionary = {".":""}
	for index: int in state.get_node_count():
		var path := str(state.get_node_path(index))
		var node := source if index == 0 else source.get_node(NodePath(path))
		var component := component_for(node.get_script())
		if component.is_empty():
			source.free()
			return {"error":"component_unregistered:"+path}
		var values: Dictionary = {}
		# Exported defaults are part of the component contract too. PackedScene
		# deliberately drops redundant explicit defaults when repacked.
		for info: Dictionary in node.get_property_list():
			var key := str(info.name)
			if int(info.usage) & PROPERTY_USAGE_STORAGE and int(info.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and key != "document_ref":
				values[key] = encode(node.get(key))
		for key: String in ["position", "rotation", "scale", "z_index", "visible", "modulate"]:
			values[key] = encode(node.get(key))
		for property_index: int in state.get_node_property_count(index):
			var key := str(state.get_node_property_name(index, property_index))
			if key in ["script", "document_ref", "metadata/editor_entity_ids"]: continue
			values[key] = encode(node.get(key))
		if index == 0:
			document.root.properties = values
		else:
			var entity_id := str(document.room_id)+":node:"+path
			node_ids[path] = entity_id
			var parent_path := path.get_base_dir()
			document.entities[entity_id] = {"id":entity_id, "component":component, "node_name":str(node.name), "parent":node_ids.get(parent_path if not parent_path.is_empty() else ".", ""), "node_path":path, "order":index, "properties":values}
	var props: Dictionary = document.root.properties
	var identities: Dictionary = source.get_meta("editor_entity_ids", source.get("workbench_entity_ids"))
	for field: String in ENTITY_FIELDS:
		if not props.has(field): continue
		var values: Array = props[field]
		for index: int in values.size():
			var identity := str(document.room_id)+":"+field+":"+str(index)
			if identities.has(field) and index < identities[field].size(): identity = str(identities[field][index])
			var parameters: Dictionary
			if field in ["platforms", "climbable_walls", "hazards"]: parameters = {"rect":values[index]}
			elif field == "hook_points": parameters = {"position":values[index]}
			else: parameters = values[index].duplicate(true)
			if field == "platforms":
				for flag: String in PLATFORM_FLAGS: parameters[flag] = index in props.get(PLATFORM_FLAGS[flag], [])
			document.entities[identity] = {"id":identity, "component":"array:"+field, "order":index, "properties":parameters}
		props.erase(field)
	for field: String in PLATFORM_FLAGS.values(): props.erase(field)
	props.erase("workbench_entity_ids")
	source.free()
	var error := value_error(document)
	return document if error.is_empty() else {"error":error}

static func assign_properties(node: Node, properties: Dictionary) -> String:
	var allowed: Dictionary = {}
	for info: Dictionary in node.get_property_list():
		if int(info.usage) & PROPERTY_USAGE_STORAGE: allowed[str(info.name)] = true
	for key: String in properties:
		if key.begins_with("metadata/"):
			node.set_meta(StringName(key.trim_prefix("metadata/")), decode(null, properties[key]))
			continue
		if key in ["script", "owner", "document_ref"] or not allowed.has(key): return "property_not_registered:"+key
		var original: Variant = node.get(key)
		var value: Variant = properties[key]
		if original is Color:
			if not value is Dictionary or not value.has("$color"): return "color_required:"+key
		elif original is Resource or (original == null and value is Dictionary and value.has("$resource")):
			if value != null and (not value is Dictionary or not value.has("$resource")): return "resource_required:"+key
		elif original is NodePath:
			if not value is String: return "node_path_required:"+key
		elif original != null:
			var error := WorldRoomDraft.property_error(original, value)
			if not error.is_empty(): return error+":"+key
		node.set(key, decode(node.get(key), properties[key]))
	return ""

static func apply(room: Node, document: Dictionary) -> String:
	if room.is_inside_tree(): return "room_already_running"
	if document.get("schema") != SCHEMA or str(document.get("room_id", "")).is_empty() or not document.get("entities") is Dictionary: return "document_invalid"
	var error := value_error(document)
	if not error.is_empty(): return error
	if component_for(room.get_script()) != document.root.get("component"): return "root_component_mismatch"
	error = assign_properties(room, document.root.properties)
	if not error.is_empty(): return error
	room.set("room_id", str(document.room_id))
	var fields: Dictionary = {}
	for field: String in ENTITY_FIELDS: fields[field] = []
	var rows: Array = document.entities.values()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
	var ids: Dictionary = {}
	var platform_flags: Dictionary = {}
	for flag: String in PLATFORM_FLAGS: platform_flags[PLATFORM_FLAGS[flag]] = []
	for row: Dictionary in rows:
		if str(row.get("id", "")).is_empty() or ids.has(str(row.id)): return "entity_identity_invalid"
		ids[str(row.id)] = true
		var kind := str(row.get("component", ""))
		if not kind.begins_with("array:"): continue
		var field := kind.trim_prefix("array:")
		if field not in ENTITY_FIELDS: return "array_component_unregistered"
		var value: Variant = row.properties.duplicate(true)
		if field == "platforms":
			for flag: String in PLATFORM_FLAGS:
				if bool(value.get(flag, false)): platform_flags[PLATFORM_FLAGS[flag]].append(fields[field].size())
			value = value.rect
		elif field in ["climbable_walls", "hazards"]: value = value.rect
		elif field == "hook_points": value = value.position
		fields[field].append(value)
	var engine_ids: Dictionary = {}
	for field: String in ENTITY_FIELDS:
		room.set(field, decode(room.get(field), fields[field]))
		engine_ids[field] = []
		for row: Dictionary in rows:
			if row.component == "array:"+field: engine_ids[field].append(row.id)
	room.set_meta("editor_entity_ids", engine_ids)
	var legacy_ids: Dictionary = {}
	for field: String in WorldRoomDraft.INDEXED_FIELDS: legacy_ids[field] = engine_ids[field]
	room.set("workbench_entity_ids", legacy_ids)
	for field: String in platform_flags: room.set(field, decode(room.get(field), platform_flags[field]))
	var parents: Dictionary = {"":room}
	var pending: Array = rows.filter(func(row: Dictionary) -> bool: return not str(row.component).begins_with("array:"))
	while not pending.is_empty():
		var advanced := false
		for row: Dictionary in pending.duplicate():
			var parent_id := str(row.get("parent", ""))
			if not parents.has(parent_id): continue
			if row.component not in COMPONENTS or row.component in ["FixedWorldRoom", "StarbridgeTrialRoom"]: return "node_component_unregistered"
			var node := (load(COMPONENTS[row.component]) as Script).new() as Node
			node.name = str(row.get("node_name", ""))
			if str(node.name).is_empty() or str(node.name).validate_node_name() != str(node.name):
				node.free()
				return "node_name_invalid"
			error = assign_properties(node, row.properties)
			if not error.is_empty():
				node.free()
				return error
			parents[parent_id].add_child(node)
			node.owner = room
			parents[row.id] = node
			pending.erase(row)
			advanced = true
		if not advanced: return "node_parent_missing_or_cyclic"
	return WorldRoomDraft.validate(room as FixedWorldRoom, WorldRoomDraft.extract(room as FixedWorldRoom)) if room is FixedWorldRoom else ""

static func instantiate(document: Dictionary) -> Dictionary:
	var kind := str(document.get("root", {}).get("component", ""))
	if kind not in ["FixedWorldRoom", "StarbridgeTrialRoom"]: return {"error":"root_component_unregistered"}
	var room := (load(COMPONENTS[kind]) as Script).new() as Node
	var error := apply(room, document)
	if not error.is_empty():
		room.free()
		return {"error":error}
	return {"room":room}

static func read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return {"error":"document_json_invalid"}
	return parsed
