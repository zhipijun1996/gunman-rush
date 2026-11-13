class_name WorldElementCatalog
extends RefCounted
## Definitions are shared by room loading, authoring and runtime state validation.
const PATH := "res://config/world_elements/index.json"
static var _data: Dictionary = {}

static func catalog() -> Dictionary:
	if _data.is_empty():
		var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = {"version":index.version,"libraries":index.libraries,"behaviors":{},"definitions":{}}
		for group: String in ["behaviors","definitions"]:
			for id: String in index[group]:
				var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(index[group][id])))
				assert(entry.get("id")==id,"Catalog identity mismatch: "+id)
				_data[group][id] = entry
	return _data

static func component_path(kind: String) -> String:
	return str(catalog().behaviors.get(kind, {}).get("script", ""))

static func component_for(script: Script) -> String:
	if script == null: return ""
	for kind: String in catalog().behaviors:
		if component_path(kind) == script.resource_path: return kind
	return ""

static func fields_error(fields: Dictionary, values: Dictionary) -> String:
	for key: String in fields:
		var spec: Dictionary = fields[key]
		if not values.has(key):
			if spec.get("required", false): return "field_missing:"+key
			continue
		var value: Variant = values[key]
		match str(spec.type):
			"dict":
				if not value is Dictionary: return "dictionary_invalid:"+key
			"array":
				if not value is Array: return "array_invalid:"+key
			"number":
				if not WorldRoomValidation.number(value): return "number_invalid:"+key
				if spec.has("min") and float(value) < float(spec.min): return "number_too_small:"+key
			"bool":
				if not value is bool: return "bool_invalid:"+key
			"point":
				if not WorldRoomValidation.vector(value): return "point_invalid:"+key
				if spec.has("min_component") and (float(value[0])<float(spec.min_component) or float(value[1])<float(spec.min_component)): return "point_too_small:"+key
			"rect":
				if not WorldRoomValidation.rectangle(value): return "rect_invalid:"+key
			"string":
				if not value is String: return "string_invalid:"+key
			"points":
				if not value is Array: return "points_invalid:"+key
				for point: Variant in value:
					if not WorldRoomValidation.vector(point): return "point_invalid:"+key
		if spec.has("choices") and value not in spec.choices: return "choice_invalid:"+key
	return ""

static func state_error(packet: Dictionary) -> String:
	if not packet.has("type"): return "state_type_missing"
	var behavior: Dictionary = catalog().behaviors.get(str(packet.type), {})
	if behavior.is_empty() or not behavior.has("state"): return "state_type_unknown"
	if packet.get("version") != behavior.get("state_version") or not packet.get("data") is Dictionary: return "state_version_invalid"
	return fields_error(behavior.state, packet.data)

static func signal_value_valid(type: String, value: Variant) -> bool:
	match type:
		"bool": return value is bool
		"number": return WorldRoomValidation.number(value)
		"string": return value is String
		"point": return WorldRoomValidation.vector(value)
		"pulse": return value == null
	return false

static func document_error(document: Dictionary) -> String:
	var entities: Dictionary = document.entities
	var bindings := {}
	for id: String in entities:
		var row: Dictionary = entities[id]
		if row.get("id") != id: return "element_id_mismatch:"+id
		var kind := str(row.get("component", ""))
		if row.has("definition_id"):
			var definition: Dictionary = catalog().definitions.get(str(row.definition_id), {})
			if definition.is_empty() or definition.component != kind or row.get("definition_version", 1) != definition.version: return "element_definition_invalid:"+id
		var behavior: Dictionary = catalog().behaviors.get(kind, {})
		var properties: Dictionary = row.get("properties", {})
		var error := fields_error(behavior.get("fields", {}), properties)
		if not error.is_empty(): return id+":"+error
		var definition: Dictionary = catalog().definitions.get(str(row.get("definition_id","")),{})
		for field: String in definition.get("room_bindings",{}):
			if bindings.has(field): return "duplicate_feature_host:"+field
			bindings[field]=id
		if definition.has("parameter_fields"):
			error=fields_error(definition.parameter_fields,properties.get("parameters",{}))
			if not error.is_empty():return id+":"+error
		if behavior.has("state") and properties.get("element_id") != id: return "element_identity_mismatch:"+id
		if kind=="WorldElementGate" and not TerrainMaterialRegistry.known(str(properties.get("appearance","mill_masonry"))): return "gate_material_unknown:"+id
		if kind=="array:spike_strips" and not str(properties.get("appearance", "")).is_empty():
			error = WorldSurfaceStyles.error(str(properties.appearance),str(properties.get("facing","up")))
			if not error.is_empty(): return error+":"+id
		for key: String in ["host_id","surface_platform_id"]:
			if properties.has(key) and not entities.has(str(properties[key])): return "host_missing:"+id
		if kind=="array:spike_strips" and properties.has("host_id"):
			if not spike_attachment_valid(properties,entities[str(properties.host_id)]): return "spike_attachment_invalid:"+id
		for host: String in properties.get("facing_platform_ids",[]):
			if not entities.has(host) or entities[host].component!="array:platforms": return "facing_host_missing:"+id
		if properties.has("links") and not properties.links is Array: return "signal_links_invalid:"+id
		var linked := {}
		for link: Variant in properties.get("links", []):
			if not link is Dictionary: return "signal_link_invalid:"+id
			var target: Dictionary = entities.get(str(link.get("target", "")), {})
			var receiver: Dictionary = catalog().behaviors.get(str(target.get("component", "")), {})
			var output := str(link.get("output", "active"))
			var input := str(link.get("input", "set_active"))
			if not behavior.get("outputs", {}).has(output) or not receiver.get("inputs", {}).has(input): return "signal_port_invalid:"+id
			if behavior.outputs[output] != receiver.inputs[input]: return "signal_type_mismatch:"+id
			var signature := str(link.target)+":"+output
			if linked.has(signature): return "signal_duplicate:"+id
			linked[signature] = true
			if properties.get("state_scope","permanent") != target.get("properties",{}).get("state_scope","permanent"): return "signal_state_scope_mismatch:"+id
		if properties.has("drive_id") and not str(properties.drive_id).is_empty():
			var target: Dictionary = entities.get(str(properties.drive_id), {})
			if not catalog().behaviors.get(str(target.get("component", "")), {}).get("clock", false): return "motion_source_invalid:"+id
	# Registered receivers currently have no immediate outputs. Future additions
	# still pass cycle validation, rather than relying on scene-tree callback order.
	for id: String in entities:
		if _cyclic(id, entities, {}, {}): return "signal_cycle:"+id
	return ""

static func _cyclic(id: String, rows: Dictionary, visiting: Dictionary, visited: Dictionary) -> bool:
	if visiting.has(id): return true
	if visited.has(id): return false
	visiting[id] = true
	for link: Dictionary in rows[id].get("properties", {}).get("links", []):
		if _cyclic(str(link.target), rows, visiting, visited): return true
	visiting.erase(id); visited[id] = true
	return false

static func instantiate_definition(definition_id: String, instance_id: String, at: Vector2) -> Dictionary:
	var definition: Dictionary = catalog().definitions.get(definition_id, {})
	if definition.is_empty(): return {"error":"definition_unknown"}
	if instance_id.is_empty(): return {"error":"instance_id_missing"}
	var result: Dictionary = {}
	var members: Array = definition.get("members", [{"id":"", "definition":definition_id, "offset":[0,0]}])
	for member: Dictionary in members:
		var child: Dictionary = catalog().definitions.get(str(member.definition), {})
		if child.is_empty() or child.has("members"): return {"error":"nested_definition_invalid"}
		var id := instance_id if str(member.id).is_empty() else instance_id+"/"+str(member.id)
		var props: Dictionary = child.get("defaults", {}).duplicate(true)
		props.merge(member.get("properties", {}), true)
		var offset := at+FixedWorldProvider.point(member.get("offset", [0,0]))
		var position_field := str(child.get("position_field", "position"))
		for field: String in child.get("offset_fields",[]):
			props[field] = [float(props[field][0])+offset.x,float(props[field][1])+offset.y]
		if position_field=="polygon":
			for point: Array in props.points: point[0]+=offset.x;point[1]+=offset.y
		elif position_field in ["rect", "bounds"]:
			props[position_field][0] = offset.x; props[position_field][1] = offset.y
		else: props[position_field] = [offset.x, offset.y]
		var row := {"id":id,"definition_id":member.definition,"definition_version":child.version,"component":child.component,"order":result.size(),"properties":props}
		if not str(child.component).begins_with("array:"):
			row.node_name = "Element_"+id.sha256_text().substr(0,16); row.parent = ""
			if catalog().behaviors.get(str(child.component), {}).get("state", {}).size()>0: props["element_id"] = id
		elif str(child.component) not in ["array:platforms", "array:hook_points", "array:climbable_walls", "array:hazards"]: props["id"] = id
		if definition.has("members"): row["assembly_id"] = instance_id
		result[id] = row
	for link: Dictionary in definition.get("links", []):
		var source: Dictionary = result[instance_id+"/"+str(link.source)].properties
		if not source.has("links"): source.links = []
		source.links.append({"output":link.get("output","active"),"target":instance_id+"/"+str(link.target),"input":link.get("input","set_active")})
	return {"entities":result}

static func spike_attachment_valid(p: Dictionary, host: Dictionary) -> bool:
	if host.component!="array:platforms" or host.properties.get("one_way",false): return false
	var r := FixedWorldProvider.rect(p.bounds); var h := FixedWorldProvider.rect(host.properties.rect)
	match str(p.facing):
		"up": return is_equal_approx(r.end.y,h.position.y) and r.position.x>=h.position.x and r.end.x<=h.end.x
		"down": return is_equal_approx(r.position.y,h.end.y) and r.position.x>=h.position.x and r.end.x<=h.end.x
		"left": return is_equal_approx(r.end.x,h.position.x) and r.position.y>=h.position.y and r.end.y<=h.end.y
		"right": return is_equal_approx(r.position.x,h.end.x) and r.position.y>=h.position.y and r.end.y<=h.end.y
	return false
