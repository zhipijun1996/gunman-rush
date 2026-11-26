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
		var libraries: Dictionary = index.mechanism_libraries
		_data.mechanism_regions = {}
		for region: String in libraries.regions:
			var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(libraries.regions[region]))
			_data.mechanism_regions[region] = profile
	return _data

## A room without a region uses the common library and the original default art.
static func region_known(region: Variant) -> bool:
	return region is String and (region.is_empty() or catalog().mechanism_regions.has(region))

static func mechanism_palette(region: String) -> Dictionary:
	if not region_known(region): return {"error":"unknown_room_region:"+region}
	var common := []
	var regional := []
	for definition: Dictionary in catalog().definitions.values():
		if definition.library != "mechanisms" or not permitted(definition, region): continue
		if permitted(definition, ""): common.append(definition.id)
		else: regional.append(definition.id)
	return {"common": common, "regional": regional}

static func permitted(definition: Dictionary, region: String) -> bool:
	var regions: Array = definition.get("usable_regions", ["*"])
	if "*" not in regions and region not in regions: return false
	for member: Dictionary in definition.get("members", []):
		var child: Dictionary = catalog().definitions.get(member.definition, {})
		if child.is_empty() or child.has("members") or not permitted(child, region): return false
	return true

static func skin_value(node: Node, definition_id: String, field: String, fallback: String) -> String:
	var ancestor := node.get_parent()
	while ancestor != null and not ancestor is FixedWorldRoom:
		ancestor = ancestor.get_parent()
	if ancestor == null: return fallback
	var profile: Dictionary = catalog().mechanism_regions.get((ancestor as FixedWorldRoom).region_id,{})
	return profile.get("skins",{}).get(definition_id,{}).get(field,fallback)

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
				if spec.has("max") and float(value) > float(spec.max): return "number_too_large:"+key
				if spec.get("integer",false) and float(value) != floorf(value): return "integer_required:"+key
				if spec.get("positive",false) and float(value) <= 0: return "positive_required:"+key
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
		if spec.has("choices") and not spec.choices.any(func(choice): return choice == value): return "choice_invalid:"+key
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

static func document_error(document: Dictionary, control_order: Array[String] = []) -> String:
	var entities: Dictionary = document.entities
	var bindings := {}
	var reward_sources := {}
	var graph := {}
	var validators := {}
	for id: String in entities: graph[id] = []
	var boolean_writers := {}
	var sections := {"main":true}
	var volumes: Variant = document.root.properties.get("section_volumes", [])
	if not volumes is Array: return "section_volumes:array_required"
	for volume: Variant in volumes:
		if volume is Dictionary: sections[volume.get("id","")] = true
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
	# Cross-instance validators may read any row in the room.
	for id: String in entities:
		var row: Dictionary = entities[id]
		var kind: String = row.component
		var behavior: Dictionary = catalog().behaviors[kind]
		var properties: Dictionary = row.properties
		var error := ""
		var definition: Dictionary = catalog().definitions.get(str(row.get("definition_id","")),{})
		if definition.get("library") in ["mechanisms","internal"]:
			var authored := WorldRoomDocument.authored_defaults(kind)
			for key: String in properties:
				if key == "id" or key.begins_with("metadata/") or behavior.fields.has(key) or authored.has(key): continue
				return "unknown_mechanism_field:"+id+":"+key
		if behavior.has("validator_script"):
			var validator: Script = load(behavior.validator_script)
			error = validator.validate_configuration(properties, row, document)
			if not error.is_empty(): return id+":"+error
			validators[behavior.validator_script] = validator
		if properties.has("section_id") and not sections.has(properties.section_id):
			return "unknown_section_id:"+id
		if kind == "array:retry_anchors" and not sections.has(properties.section): return "unknown_anchor_section:"+id
		if kind == "WorldCrossingSensor":
			var points: Array = properties.line_points
			if points.size() != 2 or FixedWorldProvider.point(points[0]) == FixedWorldProvider.point(points[1]):
				return "line_points:distinct_pair_required:"+id
		if kind == "WorldElementGear" and properties.path_mode == "arc" and properties.arc_angles_deg[0] == properties.arc_angles_deg[1]: return "arc_angles_deg:distinct_required:"+id
		if kind == "WorldElementGate" and properties.gate_mode == "directional" and properties.state_scope != "attempt": return "directional_gate_requires_attempt:"+id
		if kind == "WorldElementSwitch":
			if properties.duration > 0 and (properties.repeat_enabled or properties.state_scope != "attempt"):
				return "duration:invalid_switch_mode:"+id
			if properties.initial_active and not properties.repeat_enabled: return "initial_active:requires_toggle:"+id
		if kind in ["WorldRoomInteraction","WorldReturnLatch"]:
			var action_id: String = properties.action_id
			var actions: Array = document.get("actions",[]).filter(func(action): return action is Dictionary and action.get("id") == action_id)
			if action_id.is_empty() or actions.size()!=1: return "action_id:registered_action_required:"+id
			var action: Dictionary = actions[0]
			if document.room_id not in action.get("service_rooms",[action.get("room_id")]) or action.get("section_id","main") != properties.section_id: return "action_id:wrong_room_or_section:"+id
			var owner: String = properties.get("action_owner_id","")
			if not owner.is_empty() and entities.get(owner,{}).get("definition_id") != "internal.permanent_result": return "action_owner_id:invalid:"+id
			if kind == "WorldReturnLatch" and action.get("repeat",false): return "action_id:single_use_required:"+id
			if kind == "WorldReturnLatch":
				for panel: Variant in properties.closed_panels + properties.return_steps:
					if not WorldRoomValidation.rectangle(panel): return "return_gate:invalid_rectangle:"+id
			if properties.visual != "chest" and not WorldSpriteAnimation.has_asset(properties.visual): return "visual:unknown_asset:"+id
			if properties.radius <= 0: return "radius:positive_required:"+id
		if kind == "EquipmentSite":
			var role: String = properties.get("kind","")
			var source: String = properties.get("source_id","")
			if role != definition.get("defaults",{}).get("kind"): return "equipment_role_invalid:"+id
			for clause: Variant in properties.get("requirements",[]):
				if not clause is Array: return "equipment_requirement_invalid:"+id
				for flag: Variant in clause:
					if not flag is String or flag.is_empty(): return "equipment_requirement_invalid:"+id
			if role == "reward":
				if not EquipmentCatalog.REWARDS.data.has(source) or reward_sources.has(source): return "equipment_source_invalid:"+id
				reward_sources[source] = true
			if role == "secret" and source.is_empty(): return "secret_discovery_flag_required:"+id
		for field: String in definition.get("room_bindings",{}):
			if bindings.has(field): return "duplicate_feature_host:"+field
			bindings[field]=id
		if definition.has("parameter_fields"):
			for key: String in properties.get("parameters",{}):
				if not definition.parameter_fields.has(key): return "unknown_parameter:"+id+":"+key
			error=fields_error(definition.parameter_fields,properties.get("parameters",{}))
			if not error.is_empty():return id+":"+error
		if behavior.has("state") and properties.get("element_id") != id: return "element_identity_mismatch:"+id
		if kind == "WorldResourcePickup" and properties.get("resource_kind") == "note" and float(properties.amount) != floorf(properties.amount): return "note_quantity_invalid:"+id
		if kind=="WorldElementGate" and properties.get("appearance","inherit") != "inherit" and not TerrainMaterialRegistry.known(str(properties.get("appearance","inherit"))): return "gate_material_unknown:"+id
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
			if input == "set_active" and receiver.inputs[input] == "bool":
				var owner := target
				if target.component == "WorldElementGear" or (target.component == "WorldRotatingBeam" and entities.get(target.properties.drive_id,{}).get("component") == "WorldRotatingBeam"):
					owner = effective_clock_owner(target,entities)
				if owner.is_empty() or not catalog().behaviors[owner.component].inputs.has(input): return "clock_owner_input_unavailable:"+id
				var writer_key := str(owner.id)+":"+input
				if owner.id != target.id: graph[id].append(owner.id)
				if boolean_writers.has(writer_key): return "multiple_boolean_sources:"+writer_key
				boolean_writers[writer_key] = id
			if properties.get("state_scope") == "attempt" and properties.get("section_id","main") != target.properties.get("section_id","main"):
				return "signal_section_mismatch:"+id
			graph[id].append(str(link.target))
			var signature := str(link.target)+":"+input+":"+output
			if linked.has(signature): return "signal_duplicate:"+id
			linked[signature] = true
			if properties.get("state_scope","permanent") != target.get("properties",{}).get("state_scope","permanent"): return "signal_state_scope_mismatch:"+id
		if properties.has("drive_id") and not str(properties.drive_id).is_empty():
			var target: Dictionary = entities.get(str(properties.drive_id), {})
			if not catalog().behaviors.get(str(target.get("component", "")), {}).get("clock", false): return "motion_source_invalid:"+id
			if target.properties.get("state_scope") != properties.get("state_scope") or target.properties.get("section_id","main") != properties.get("section_id","main"): return "motion_source_scope_mismatch:"+id
			if kind == "WorldElementGear":
				var clock := effective_clock_owner(target,entities)
				if clock.is_empty() or clock.properties.get("motion_mode","") in ["manual_cart","follow_water","targets"]: return "motion_source_has_no_path_clock:"+id
			graph[target.id].append(id)
	for validator: Script in validators.values():
		if not validator.has_method("control_dependencies"): continue
		var dependencies: Dictionary = validator.control_dependencies(document)
		for target: String in dependencies:
			for source: String in dependencies[target]:
				if not graph.has(source) or not graph.has(target): return "unknown_control_dependency:"+target
				graph[source].append(target)
	var visited := {}
	for id: String in graph:
		if _cyclic(id, graph, {}, visited): return "signal_cycle:"+id
	# Edges point from controller to consumer. DFS finishes consumers first.
	control_order.assign(visited.keys())
	control_order.reverse()
	return ""

static func effective_clock_owner(row: Dictionary, entities: Dictionary) -> Dictionary:
	var seen := {}
	while not row.is_empty() and not str(row.properties.get("drive_id","")).is_empty():
		if seen.has(row.id): return {}
		seen[row.id] = true
		row = entities.get(row.properties.drive_id,{})
	return row

static func _cyclic(id: String, graph: Dictionary, visiting: Dictionary, visited: Dictionary) -> bool:
	if visiting.has(id): return true
	if visited.has(id): return false
	visiting[id] = true
	for next: String in graph[id]:
		if _cyclic(next, graph, visiting, visited): return true
	visiting.erase(id)
	visited[id] = true
	return false

static func qualify_reference(value: Variant, instance_id: String) -> Variant:
	if value is Array:
		return value.map(func(item): return qualify_reference(item, instance_id))
	if value is Dictionary:
		var result := {}
		for key: String in value: result[key] = qualify_reference(value[key], instance_id)
		return result
	return instance_id+"/"+str(value)

static func instantiate_definition(definition_id: String, instance_id: String, at: Vector2, region_id: String = "", options: Dictionary = {}) -> Dictionary:
	if not region_known(region_id): return {"error":"unknown_room_region:"+region_id}
	var definition: Dictionary = catalog().definitions.get(definition_id, {})
	if definition.is_empty(): return {"error":"definition_unknown"}
	if not permitted(definition,region_id): return {"error":"mechanism_outside_region:"+definition_id}
	if instance_id.is_empty(): return {"error":"instance_id_missing"}
	var result: Dictionary = {}
	var members: Array = definition.get("members", [{"id":"", "definition":definition_id, "offset":[0,0]}])
	if not options.is_empty() or definition.has("creation_fields"):
		var fields: Dictionary = definition.get("creation_fields", {})
		for key: Variant in options:
			if not fields.has(key): return {"error":"unknown_creation_field:"+str(key)}
		var error := fields_error(fields, options)
		if not error.is_empty(): return {"error":error}
		if definition.has("creation_adapter"):
			members = members.duplicate(true)
			var adapter: Script = load(definition.creation_adapter)
			error = adapter.configure(definition, members, options)
			if not error.is_empty(): return {"error":error}
	for member: Dictionary in members:
		var child: Dictionary = catalog().definitions.get(str(member.definition), {})
		if child.is_empty() or child.has("members"): return {"error":"nested_definition_invalid"}
		if not permitted(child,region_id): return {"error":"mechanism_outside_region:"+str(child.id)}
		var id := instance_id if str(member.id).is_empty() else instance_id+"/"+str(member.id)
		if result.has(id): return {"error":"duplicate_assembly_member:"+id}
		var props: Dictionary = child.get("defaults", {}).duplicate(true)
		props.merge(member.get("properties", {}).duplicate(true), true)
		for field: String in member.get("instance_refs", {}):
			props[field] = qualify_reference(member.instance_refs[field], instance_id)
		var offset := at+FixedWorldProvider.point(member.get("offset", [0,0]))
		for group_field: String in member.get("group_points",{}):
			var positions := []
			for point: Array in member.group_points[group_field]: positions.append([at.x+point[0],at.y+point[1]])
			props[group_field] = positions
		var position_field := str(child.get("position_field", "position"))
		for field: String in child.get("offset_fields",[]):
			props[field][0] += offset.x
			props[field][1] += offset.y
		if position_field=="polygon":
			for point: Array in props.points: point[0]+=offset.x;point[1]+=offset.y
		elif position_field in ["rect", "bounds"]:
			props[position_field][0] += offset.x; props[position_field][1] += offset.y
		else: props[position_field] = [offset.x, offset.y]
		var row := {"id":id,"definition_id":member.definition,"definition_version":child.version,"component":child.component,"order":result.size(),"properties":props}
		if not str(child.component).begins_with("array:"):
			row.node_name = "Element_"+id.sha256_text().substr(0,16); row.parent = ""
			if catalog().behaviors.get(str(child.component), {}).get("state", {}).size()>0: props["element_id"] = id
		elif str(child.component) not in ["array:platforms", "array:hook_points", "array:climbable_walls", "array:hazards"]: props["id"] = id
		if definition.has("members"):
			row["assembly_id"] = instance_id
			row["assembly_definition_id"] = definition_id
			row["assembly_definition_version"] = definition.version
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
