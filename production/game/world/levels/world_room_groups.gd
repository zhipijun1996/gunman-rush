class_name WorldRoomGroups
extends RefCounted
## Edits operate on a copy of authored schema-3 data. No preset regeneration occurs.
const REFERENCE_FIELDS := ["drive_id","result_target_id","action_owner_id","host_id","surface_platform_id","water_source_id","facing_platform_ids","groups","members_order","protected_sources","carrier_ids"]

static func members(doc: Dictionary,group: String) -> Array:
	return doc.entities.values().filter(func(row): return not group.is_empty() and row.get("assembly_id") == group)

static func translate(row: Dictionary, delta: Vector2) -> void:
	var definition: Dictionary = WorldElementCatalog.catalog().definitions[row.definition_id]
	var fields: Array = definition.get("offset_fields",[]).duplicate()
	fields.append(definition.get("position_field","position"))
	for field: String in fields:
		if field == "polygon":
			for point: Array in row.properties.points: shift(point,delta)
		else:
			if not row.properties.has(field):
				row.properties[field] = definition.get("defaults",{}).get(field,[0,0]).duplicate()
			shift(row.properties[field],delta)
	for point: Array in row.properties.get("access_points",[]): shift(point,delta)

static func shift(value: Array,delta: Vector2) -> void:
	value[0] += delta.x
	value[1] += delta.y

static func validated(doc: Dictionary) -> Dictionary:
	var result := WorldRoomDocument.instantiate(doc)
	if result.has("error"): return result
	result.room.free()
	return doc

static func move_group(doc: Dictionary, group: String, delta: Vector2) -> Dictionary:
	var edited := doc.duplicate(true)
	var rows := members(edited,group)
	if rows.is_empty(): return {"error":"unknown_assembly:"+group}
	for row: Dictionary in rows: translate(row,delta)
	return validated(edited)

static func detach_group(doc: Dictionary, group: String) -> Dictionary:
	var edited := doc.duplicate(true)
	var rows := members(edited,group)
	if rows.is_empty(): return {"error":"unknown_assembly:"+group}
	for row: Dictionary in rows:
		for key: String in ["assembly_id","assembly_definition_id","assembly_definition_version"]: row.erase(key)
	return validated(edited)

static func rewrite(value: Variant, mapping: Dictionary, errors: Array) -> Variant:
	if value is Array: return value.map(func(item): return rewrite(item,mapping,errors))
	if value is Dictionary:
		var result := {}
		for key: String in value: result[key] = rewrite(value[key],mapping,errors)
		return result
	if value == "": return ""
	if not mapping.has(value):
		errors.append("external_reference_requires_mapping:"+str(value))
		return value
	return mapping[value]

static func copy_group(doc: Dictionary, group: String, new_id: String, delta: Vector2, external_refs := {}) -> Dictionary:
	var rows := members(doc,group)
	if rows.is_empty(): return {"error":"unknown_assembly:"+group}
	if new_id.is_empty() or not members(doc,new_id).is_empty() or doc.entities.has(new_id): return {"error":"assembly_id_in_use:"+new_id}
	var mapping := external_refs.duplicate()
	for row: Dictionary in rows:
		if not str(row.id).begins_with(group+"/"): return {"error":"assembly_member_identity:"+row.id}
		var id := new_id+"/"+str(row.id).trim_prefix(group+"/")
		if doc.entities.has(id): return {"error":"entity_id_in_use:"+id}
		mapping[row.id] = id
	var edited := doc.duplicate(true)
	var errors := []
	for original: Dictionary in rows:
		var row := original.duplicate(true)
		row.id = mapping[original.id]
		row.assembly_id = new_id
		for key: String in ["id","element_id"]:
			if row.properties.has(key): row.properties[key] = row.id
		for field: String in REFERENCE_FIELDS:
			if row.properties.has(field): row.properties[field] = rewrite(row.properties[field],mapping,errors)
		if row.properties.has("target_bindings"):
			var bindings := {}
			for key: String in row.properties.target_bindings:
				var target_key: String = rewrite(key,mapping,errors) if key.contains("/") else key
				bindings[target_key] = row.properties.target_bindings[key]
			row.properties.target_bindings = bindings
		if row.has("parent") and row.parent != "": row.parent = rewrite(row.parent,mapping,errors)
		for link: Dictionary in row.properties.get("links",[]): link.target = rewrite(link.target,mapping,errors)
		if row.definition_id == "internal.bool_condition":
			for source: Dictionary in row.properties.sources: source.source_id = rewrite(source.source_id,mapping,errors)
		if row.definition_id == "interaction.action" and not row.properties.get("action_id","").is_empty():
			var key := "action:"+str(row.properties.action_id)
			if not external_refs.has(key): errors.append("external_reference_requires_mapping:"+key)
			else: row.properties.action_id = external_refs[key]
		translate(row,delta)
		edited.entities[row.id] = row
	if not errors.is_empty(): return {"error":errors[0]}
	return validated(edited)
