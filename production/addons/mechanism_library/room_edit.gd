extends RefCounted
## Executed by an ordinary Godot process, so room validation uses gameplay scripts.

class ValidationLog extends Logger:
	var first_error := ""
	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _traces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING and first_error == "":
			first_error = "%s:%d %s" % [file,line,rationale if rationale != "" else code]

static func snapshot(path: String) -> Dictionary:
	if path.get_extension().to_lower() != "json": return {"error":"room_json_required"}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file: return {"error":"room_unreadable:"+path}
	var bytes := file.get_buffer(file.get_length())
	var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not value is Dictionary or value.get("schema") != 3: return {"error":"schema_3_room_required"}
	if not value.get("root") is Dictionary or not value.root.get("properties") is Dictionary or not value.get("entities") is Dictionary:
		return {"error":"document_shape_invalid"}
	for id: Variant in value.entities:
		var row: Variant = value.entities[id]
		if not row is Dictionary or row.get("id") != id or not row.get("properties") is Dictionary:
			return {"error":"entity_shape_invalid:"+str(id)}
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return {"doc":value, "hash":hash.finish().hex_encode()}

static func execute(path: String, expected: String, operation: Dictionary, save: bool) -> Dictionary:
	var original := snapshot(path)
	if original.has("error"): return original
	if original.hash != expected: return {"error":"room_changed_on_disk"}
	var errors := ValidationLog.new()
	OS.add_logger(errors)
	var edited := apply(original.doc, operation)
	OS.remove_logger(errors)
	if not errors.first_error.is_empty(): return {"error":errors.first_error}
	if edited.has("error"): return edited
	var changed := {}
	for id: String in edited.entities:
		if original.doc.entities.get(id) != edited.entities[id]: changed[id] = edited.entities[id]
	if changed.is_empty(): return {"error":"no_changed_instances"}
	var result := {"changed":changed, "saved":false}
	if not save: return result
	var absolute := ProjectSettings.globalize_path(path)
	var lock := absolute + ".mechanism-write"
	if DirAccess.make_dir_absolute(lock) != OK: return {"error":"room_write_busy:"+lock}
	var temporary := lock.path_join("room.tmp")
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if not file:
		DirAccess.remove_absolute(lock)
		return {"error":"cannot_write_room"}
	file.store_string(JSON.stringify(edited, "  ", false) + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	var latest := snapshot(path)
	if write_error != OK: result = {"error":"cannot_write_room"}
	elif latest.get("hash","") != expected: result = {"error":"room_changed_on_disk"}
	elif DirAccess.rename_absolute(temporary,absolute) != OK: result = {"error":"cannot_replace_room"}
	else: result.saved = true
	if FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
	DirAccess.remove_absolute(lock)
	return result

static func apply(source: Dictionary, operation: Dictionary) -> Dictionary:
	var at_data: Variant = operation.get("at", [0,0])
	if not WorldRoomValidation.vector(at_data): return {"error":"invalid_placement_point"}
	var at := Vector2(at_data[0],at_data[1])
	var doc := source.duplicate(true)
	var kind := str(operation.get("kind",""))
	var id := str(operation.get("id","")).strip_edges()
	var group := str(operation.get("group",""))
	match kind:
		"move": return WorldRoomGroups.move_group(doc, group, at)
		"detach": return WorldRoomGroups.detach_group(doc, group)
		"copy": return WorldRoomGroups.copy_group(doc, group, id, at, operation.get("external_refs",{}))
	var fields: Variant = operation.get("fields",{})
	if not fields is Dictionary: return {"error":"field_object_required"}
	var def_id := str(operation.get("definition",""))
	if kind == "edit":
		if not doc.entities.has(id): return {"error":"unknown_instance:"+id}
		def_id = str(doc.entities[id].definition_id)
	var definition: Dictionary = WorldElementCatalog.catalog().definitions.get(def_id,{})
	if definition.is_empty() or (kind != "edit" and definition.get("library") != "mechanisms"):
		return {"error":"unknown_mechanism:"+def_id}
	var preset := definition.has("members")
	var schema: Dictionary = definition.creation_fields if preset and definition.has("creation_fields") else {}
	if not preset: schema = WorldElementCatalog.catalog().behaviors[definition.component].get("fields",{})
	for key: String in fields:
		if key in ["id","element_id","time_profile"] or not schema.has(key): return {"error":"unknown_or_readonly_field:"+key}
	if kind == "edit":
		doc.entities[id].properties.merge(fields,true)
	elif kind == "add":
		if doc.entities.has(id) or not WorldRoomGroups.members(doc,id).is_empty(): return {"error":"instance_id_in_use:"+id}
		var region := str(doc.root.properties.get("region_id",""))
		var made := WorldElementCatalog.instantiate_definition(def_id,id,at,region,fields if preset else {})
		if made.has("error"): return made
		var next_order := 0
		for previous: Dictionary in doc.entities.values(): next_order = maxi(next_order, int(previous.get("order",0))+1)
		for child_id: String in made.entities:
			if doc.entities.has(child_id) or not WorldRoomGroups.members(doc,child_id).is_empty(): return {"error":"instance_id_in_use:"+child_id}
			var row: Dictionary = made.entities[child_id]
			for key: String in ["component","node_name","node_path"]: row.erase(key)
			row.order = next_order
			next_order += 1
			if not preset:
				# Overrides start in the same local coordinate system as definition defaults.
				# The expansion has already translated unchanged properties.
				for key: String in fields:
					var value: Variant = fields[key]
					if key == definition.get("position_field","position") or key in definition.get("offset_fields",[]):
						if not value is Array or value.size() < 2 or not WorldRoomValidation.number(value[0]) or not WorldRoomValidation.number(value[1]):
							return {"error":"invalid_placement_geometry:"+key}
						value = value.duplicate(true)
						value[0] += at.x
						value[1] += at.y
					row.properties[key] = value
			doc.entities[child_id] = row
	else: return {"error":"unknown_edit_operation"}
	return WorldRoomGroups.validated(doc)
