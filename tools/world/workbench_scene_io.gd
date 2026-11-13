extends SceneTree
## The CLI and the Web bridge intentionally use the same WorldRoomDraft adapter.
## --export=/absolute/rooms.json
## --apply=/absolute/drafts.json --output-dir=/absolute/candidate-scenes
func _initialize() -> void:
	var arguments: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var pair := arg.trim_prefix("--").split("=", true, 1)
			arguments[pair[0]] = pair[1]
	if arguments.has("export"):
		quit(_export(str(arguments["export"])))
	elif arguments.has("apply") and arguments.has("output-dir"):
		quit(_apply(str(arguments["apply"]), str(arguments["output-dir"])))
	else:
		printerr("Use --export=FILE or --apply=FILE --output-dir=DIR")
		quit(2)

func _construction() -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/world/construction.json"))
	return value if value is Dictionary else {}

func _export(output: String) -> int:
	var rows: Dictionary = {}
	var construction := _construction()
	var known: Dictionary = {}
	var editable: Dictionary = {}
	for row: Dictionary in construction.get("rooms", []):
		var id := str(row.room_id)
		known[id] = true
		if id.begins_with("P-R"): editable[id] = true
	var scope_path := "res://config/workbench/rooms.json"
	if FileAccess.file_exists(scope_path):
		var scope: Variant = JSON.parse_string(FileAccess.get_file_as_string(scope_path))
		if not scope is Dictionary or scope.get("schema") != 1 or not scope.get("additional_room_ids") is Array:
			printerr("Unsupported workbench room scope")
			return 1
		for id: Variant in scope.additional_room_ids:
			if not id is String or not known.has(id) or editable.has(id):
				printerr("Unknown or duplicate workbench review room: "+str(id))
				return 1
			editable[id] = true
	for row: Dictionary in construction.get("rooms", []):
		var id := str(row.room_id)
		if not editable.has(id): continue
		var path := str(row.get("scene_ref", ""))
		if not ResourceLoader.exists(path):
			printerr("Scene missing: "+path)
			return 1
		var packed := load(path) as PackedScene
		var room := packed.instantiate() as FixedWorldRoom
		if room == null:
			printerr("Not a FixedWorldRoom: "+path)
			return 1
		var data := WorldRoomDraft.extract(room)
		var error := WorldRoomDraft.validate(room, data)
		if not error.is_empty():
			room.free()
			printerr("Invalid authored room "+id+": "+error)
			return 1
		data["id"] = id
		data["scene_ref"] = path
		data["source_hash"] = FileAccess.get_sha256(path)
		data["implemented"] = bool(row.get("implemented", false))
		var provenance: Dictionary = {}
		for field: String in WorldRoomDraft.INDEXED_FIELDS:
			var authored: Variant = room.workbench_entity_ids.get(field)
			provenance[field] = "authored" if authored is Array and authored.size() == room.get(field).size() else "derived_index"
		data["identity_provenance"] = provenance
		rows[id] = data
		room.free()
	var version := ""
	if FileAccess.file_exists(FixedWorldProvider.BUNDLE):
		var runtime: Variant = JSON.parse_string(FileAccess.get_file_as_string(FixedWorldProvider.BUNDLE))
		if runtime is Dictionary: version = str(runtime.get("content_version", ""))
	var result := {"schema":1, "base_content_version":version, "rooms":rows, "catalog_runtime":_catalog_runtime()}
	return _write_json(output, result)

func _catalog_runtime() -> Dictionary:
	# Read the same registry and real Resource defaults used by gameplay. The
	# browser never owns a second list of enemy species or component scripts.
	var enemies: Array[Dictionary] = []
	for id: StringName in EnemyBehaviorRegistry.behavior_ids():
		var definition := EnemyFactory.definition_for_behavior(id)
		if definition == null:
			push_error("Workbench catalog cannot load registered enemy: "+str(id))
			continue
		enemies.append({"id":str(id), "definition":EnemyFactory.definition_path_for_behavior(id),
			"scene":EnemyFactory.scene_path_for_behavior(id), "size":WorldRoomDraft.encode(definition.collision_size),
			"default_health":definition.health_definition.max_health, "aerial":definition.aerial,
			"definition_version":definition.definition_version, "defaults":{"behavior":str(id)}, "switch_fields":["behavior"]})
	var node_defaults: Dictionary = {}
	for kind: String in WorldRoomDraft.NODE_SCRIPTS:
		var node: Node = (load(WorldRoomDraft.NODE_SCRIPTS[kind]) as Script).new()
		var values: Dictionary = {}
		for field: String in WorldRoomDraft.NODE_FIELDS[kind]: values[field] = WorldRoomDraft.encode(node.get(field))
		node_defaults[kind] = values
		node.free()
	return {"enemies":enemies, "node_types":WorldRoomDraft.NODE_SCRIPTS.keys(),
		"node_scripts":WorldRoomDraft.NODE_SCRIPTS, "node_fields":WorldRoomDraft.NODE_FIELDS,
		"node_defaults":node_defaults, "room_fields":WorldRoomDraft.ROOM_FIELDS,
		"indexed_fields":WorldRoomDraft.INDEXED_FIELDS}

func _apply(input: String, output_dir: String) -> int:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(input))
	if not parsed is Dictionary:
		printerr("Draft file must contain an object")
		return 1
	var drafts: Array = parsed.get("drafts", [parsed])
	var bindings: Dictionary = {}
	for row: Dictionary in _construction().get("rooms", []): bindings[str(row.room_id)] = str(row.scene_ref)
	var prepared: Array[Dictionary] = []
	for draft: Variant in drafts:
		if not draft is Dictionary or not bindings.has(str(draft.get("room_id", ""))):
			printerr("Unknown draft room")
			return 1
		var id := str(draft.room_id)
		var path: String = bindings[id]
		if draft.has("source_hash") and str(draft.source_hash) != FileAccess.get_sha256(path):
			printerr("Source conflict: "+id)
			return 1
		var room := (load(path) as PackedScene).instantiate() as FixedWorldRoom
		var error := WorldRoomDraft.apply(room, draft)
		if not error.is_empty():
			room.free()
			printerr(id+": "+error)
			return 1
		var packed := PackedScene.new()
		var document_ref := room.document_ref
		room.document_ref = ""
		var packed_error := packed.pack(room)
		var expected := WorldRoomDraft.extract(room)
		room.free()
		if packed_error != OK:
			printerr("Could not pack "+id)
			return 1
		prepared.append({"id":id, "packed":packed, "expected":expected, "source":path, "document_ref":document_ref})
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		printerr("Could not create output directory")
		return 1
	var receipts: Array = []
	for row: Dictionary in prepared:
		var path := output_dir.path_join(str(row.id)+".tscn")
		if not str(row.document_ref).is_empty():
			var document := WorldRoomDocument.extract(row.packed)
			if document.has("error"):
				printerr(document.error)
				return 1
			var result := WorldRoomDocument.instantiate(document)
			if result.has("error"): return 1
			var actual := WorldRoomDraft.extract(result.room)
			result.room.free()
			if JSON.parse_string(JSON.stringify(actual)) != JSON.parse_string(JSON.stringify(row.expected)):
				printerr("Saved document differs from accepted draft: "+str(row.id))
				return 1
			var document_path := output_dir.path_join(str(row.id)+".json")
			if _write_json(document_path, document) != 0: return 1
			var wrapper := FileAccess.open(path, FileAccess.WRITE)
			wrapper.store_string(FileAccess.get_file_as_string(row.source))
			wrapper.close()
			receipts.append({"room_id":row.id, "source":row.source, "candidate":path, "source_hash":FileAccess.get_sha256(path), "document_source":row.document_ref, "document_candidate":document_path, "document_hash":FileAccess.get_sha256(document_path), "draft_hash":JSON.stringify(actual, "", true).sha256_text(), "roundtrip_verified":true})
			continue
		if ResourceSaver.save(row.packed, path) != OK:
			printerr("Could not save "+path)
			return 1
		var reloaded := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		if reloaded == null:
			printerr("Could not reload "+path)
			return 1
		var room := reloaded.instantiate() as FixedWorldRoom
		var actual := WorldRoomDraft.extract(room)
		room.free()
		if JSON.stringify(actual, "", true) != JSON.stringify(row.expected, "", true):
			printerr("Saved scene differs from accepted draft: "+str(row.id))
			return 1
		receipts.append({"room_id":row.id, "source":row.source, "candidate":path, "source_hash":FileAccess.get_sha256(path), "draft_hash":JSON.stringify(actual, "", true).sha256_text(), "roundtrip_verified":true})
	return _write_json(output_dir.path_join("receipt.json"), {"schema":1, "scenes":receipts})

func _write_json(path: String, value: Dictionary) -> int:
	var parent := path.get_base_dir()
	if not parent.is_empty(): DirAccess.make_dir_recursive_absolute(parent)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write "+path)
		return 1
	file.store_string(JSON.stringify(value, "\t", true)+"\n")
	file.close()
	print(path)
	return 0
