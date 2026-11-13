class_name WorldRoomDocument
extends RefCounted
## Complete static room authoring document. Runtime creates the existing game
## components; no external JSON-to-scene build and no second movement engine.
const SCHEMA := 3
static var _defaults: Dictionary = {}
static func component_scripts() -> Dictionary:
	var result := {}
	for kind: String in WorldElementCatalog.catalog().behaviors:
		var path := WorldElementCatalog.component_path(kind)
		if not path.is_empty() and not WorldElementCatalog.catalog().behaviors[kind].get("internal_service",false): result[kind] = path
	return result

static func entity_fields() -> Array[String]:
	var result: Array[String] = []
	for kind: String in WorldElementCatalog.catalog().behaviors:
		var field := str(WorldElementCatalog.catalog().behaviors[kind].get("storage_field",""))
		if not field.is_empty(): result.append(field)
	return result

static func registered_script_resources() -> Array[String]:
	var result: Array[String]=[]
	for definition:Dictionary in WorldElementCatalog.catalog().definitions.values():
		for binding:Dictionary in definition.get("room_bindings",{}).values():
			var constant:Variant=binding.get("constant")
			if constant is Dictionary and constant.has("$resource"):result.append(str(constant["$resource"]))
	return result

const PLATFORM_FLAGS := {"one_way":"one_way_indices", "masonry":"masonry_platform_indices", "illustrated":"illustrated_platform_indices"}

static func component_for(script: Script) -> String:
	if script == null: return ""
	return WorldElementCatalog.component_for(script)

static func authored_defaults(kind: String) -> Dictionary:
	if _defaults.has(kind):return _defaults[kind].duplicate(true)
	var values:Dictionary={}
	if kind.begins_with("array:"):return values
	var node:Node=(load(WorldElementCatalog.component_path(kind)) as Script).new()
	for info:Dictionary in node.get_property_list():
		var key:=str(info.name)
		if int(info.usage) & PROPERTY_USAGE_STORAGE and int(info.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and key!="document_ref":values[key]=encode(node.get(key))
	for key:String in ["position","rotation","scale","z_index","visible","modulate"]:values[key]=encode(node.get(key))
	for key:StringName in node.get_meta_list():values["metadata/"+str(key)]=encode(node.get_meta(key))
	if WorldElementCatalog.catalog().behaviors[kind].get("root",false):
		for key:String in entity_fields()+["entity_ids","platform_appearances","one_way_indices","masonry_platform_indices","illustrated_platform_indices","terrain_paint"]:values.erase(key)
	node.free()
	_defaults[kind]=values.duplicate(true)
	return values

## The source contains definitions. This derived view is shared with the editor;
## component and scene names are implementation details, not another authority.
static func view(source: Dictionary) -> Dictionary:
	if source.get("schema")!=SCHEMA: return {"error":"document_version_unsupported"}
	if not source.get("root") is Dictionary or not source.root.get("properties") is Dictionary or not source.get("entities") is Dictionary: return {"error":"document_shape_invalid"}
	for key: Variant in source.entities:
		var row: Variant = source.entities[key]
		if not row is Dictionary or row.get("id")!=key or not row.get("properties") is Dictionary: return {"error":"entity_shape_invalid"}
	var reserved:Array=entity_fields()+["entity_ids","platform_appearances","one_way_indices","masonry_platform_indices","illustrated_platform_indices"]
	for definition:Dictionary in WorldElementCatalog.catalog().definitions.values():reserved.append_array(definition.get("room_bindings",{}).keys())
	for field:String in reserved:
		if source.root.properties.has(field):return {"error":"root_field_owned_by_instance:"+field}
	var document := source.duplicate(true)
	var rows: Array = [document.root]
	rows.append_array(document.entities.values())
	for row: Dictionary in rows:
		var definition: Dictionary = WorldElementCatalog.catalog().definitions.get(str(row.get("definition_id","")),{})
		if definition.is_empty() or definition.has("members") or row.get("definition_version")!=definition.version: return {"error":"instance_definition_invalid"}
		if row.has("component") and row.component!=definition.component: return {"error":"derived_component_mismatch"}
		var behavior:Dictionary=WorldElementCatalog.catalog().behaviors.get(str(definition.component),{})
		if behavior.get("internal_service",false) or bool(behavior.get("root",false))!=not row.has("id"): return {"error":"definition_role_invalid"}
		if (definition.has("room_bindings") or definition.id=="presentation.trial") and not str(row.get("parent","")).is_empty(): return {"error":"feature_requires_room_parent"}
		row["component"] = definition.component
		var values:=authored_defaults(str(definition.component))
		values.merge(definition.get("defaults",{}),true)
		values.merge(row.properties,true)
		row["properties"]=values
		row.erase("node_path")
		if row.has("id") and not str(row.component).begins_with("array:"):
			var id := str(row.id)
			row["node_name"] = id.split(":node:",true,1)[1].get_file() if id.contains(":node:") else "Element_"+id.sha256_text().substr(0,16)
			row["parent"] = row.get("parent", "")
	document.root.properties["room_id"]=str(document.get("room_id",""))
	return document

static func canonical(source: Dictionary) -> Dictionary:
	var document := source.duplicate(true)
	for definition: Dictionary in WorldElementCatalog.catalog().definitions.values():
		for field: String in definition.get("room_bindings",{}): document.root.properties.erase(field)
	var rows: Array = [document.root]; rows.append_array(document.entities.values())
	for row: Dictionary in rows:
		if not row.has("definition_id"):
			row["definition_id"] = WorldElementCatalog.catalog().behaviors.get(str(row.get("component","")),{}).get("default_definition","")
			row["definition_version"] = 1
		for key: String in ["component","node_name","node_path"]: row.erase(key)
	return document

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
			if path.ends_with(".gd") and path not in registered_script_resources(): return "script_resource_not_registered"
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
	if root_component not in ["FixedWorldRoom"]:
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
				if key == "terrain_paint" and node.get(key).is_empty(): continue
				values[key] = encode(node.get(key))
		for key: String in ["position", "rotation", "scale", "z_index", "visible", "modulate"]:
			values[key] = encode(node.get(key))
		for property_index: int in state.get_node_property_count(index):
			var key := str(state.get_node_property_name(index, property_index))
			if key in ["script", "document_ref", "metadata/editor_entity_ids", "metadata/editor_entity_id", "metadata/editor_element_rows", "metadata/definition_id"]: continue
			values[key] = encode(node.get(key))
		if index == 0:
			document.root.properties = values
		else:
			var entity_id := str(node.get_meta("editor_entity_id",str(document.room_id)+":node:"+path))
			node_ids[path] = entity_id
			var parent_path := path.get_base_dir()
			document.entities[entity_id] = {"id":entity_id, "component":component, "node_name":str(node.name), "parent":node_ids.get(parent_path if not parent_path.is_empty() else ".", ""), "node_path":path, "order":index, "properties":values}
	var props: Dictionary = document.root.properties
	var identities: Dictionary = source.get_meta("editor_entity_ids", source.get("entity_ids"))
	for field: String in entity_fields():
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
	props.erase("entity_ids")
	props.erase("platform_appearances")
	var element_rows: Dictionary = source.get_meta("editor_element_rows", {})
	for id: String in document.entities:
		if not element_rows.has(id): continue
		for key: String in ["definition_id", "definition_version", "assembly_id", "order"]:
			if element_rows[id].has(key): document.entities[id][key] = element_rows[id][key]
		if document.entities[id].component=="array:platforms" and source.platform_appearances.has(id): document.entities[id].properties.appearance = source.platform_appearances[id]
	# Codec metadata is persisted on the packed root, never duplicated in JSON.
	for key: String in props.keys():
		if key.begins_with("metadata/editor_"): props.erase(key)
	source.free()
	var error := value_error(document)
	return view(canonical(document)) if error.is_empty() else {"error":error}

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
			var error := WorldRoomValidation.property_error(original, value)
			if not error.is_empty(): return error+":"+key
		node.set(key, decode(node.get(key), properties[key]))
	return ""

static func apply(room: Node, document: Dictionary) -> String:
	if room.is_inside_tree(): return "room_already_running"
	document = view(document)
	if document.has("error"): return str(document.error)
	if document.get("schema") != SCHEMA or str(document.get("room_id", "")).is_empty() or not document.get("entities") is Dictionary: return "document_invalid"
	var error := value_error(document)
	if not error.is_empty(): return error
	error = WorldElementCatalog.document_error(document)
	if not error.is_empty(): return error
	room.set_meta("editor_element_rows", document.entities.duplicate(true))
	if component_for(room.get_script()) != document.root.get("component"): return "root_component_mismatch"
	error = assign_properties(room, document.root.properties)
	if not error.is_empty(): return error
	room.set("room_id", str(document.room_id))
	var fields: Dictionary = {}
	room.platform_appearances = {}
	for field: String in entity_fields(): fields[field] = []
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
		if field not in entity_fields(): return "array_component_unregistered"
		var value: Variant = row.properties.duplicate(true)
		if field == "platforms":
			if value.has("appearance"): room.platform_appearances[str(row.id)] = str(value.appearance)
			for flag: String in PLATFORM_FLAGS:
				if bool(value.get(flag, false)): platform_flags[PLATFORM_FLAGS[flag]].append(fields[field].size())
			value = value.rect
		elif field in ["climbable_walls", "hazards"]: value = value.rect
		elif field == "hook_points": value = value.position
		fields[field].append(value)
	var engine_ids: Dictionary = {}
	for field: String in entity_fields():
		room.set(field, decode(room.get(field), fields[field]))
		engine_ids[field] = []
		for row: Dictionary in rows:
			if row.component == "array:"+field: engine_ids[field].append(row.id)
	room.set_meta("editor_entity_ids", engine_ids)
	var legacy_ids: Dictionary = {}
	for field: String in WorldRoomValidation.INDEXED_FIELDS: legacy_ids[field] = engine_ids[field]
	room.set("entity_ids", legacy_ids)
	for field: String in platform_flags: room.set(field, decode(room.get(field), platform_flags[field]))
	var parents: Dictionary = {"":room}
	var pending: Array = rows.filter(func(row: Dictionary) -> bool: return not str(row.component).begins_with("array:"))
	while not pending.is_empty():
		var advanced := false
		for row: Dictionary in pending.duplicate():
			var parent_id := str(row.get("parent", ""))
			if not parents.has(parent_id): continue
			var script_path := WorldElementCatalog.component_path(str(row.component))
			if script_path.is_empty(): script_path = str(component_scripts().get(row.component,""))
			if script_path.is_empty() or row.component in ["FixedWorldRoom"]: return "node_component_unregistered"
			var node := (load(script_path) as Script).new() as Node
			node.set_meta("editor_entity_id", str(row.id))
			node.set_meta("definition_id", str(row.definition_id))
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
	for node: Node in room.find_children("*", "", true, false):
		if node.has_method("prepare_room"): node.call("prepare_room",room)
	return WorldRoomValidation.validate_room(room as FixedWorldRoom) if room is FixedWorldRoom else ""

static func instantiate(document: Dictionary) -> Dictionary:
	document = view(document)
	if document.has("error"): return document
	var kind := str(document.get("root", {}).get("component", ""))
	if kind not in ["FixedWorldRoom"]: return {"error":"root_component_unregistered"}
	var room := (load(component_scripts()[kind]) as Script).new() as Node
	var error := apply(room, document)
	if not error.is_empty():
		room.free()
		return {"error":error}
	return {"room":room}

static func read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return {"error":"document_json_invalid"}
	return view(parsed)
