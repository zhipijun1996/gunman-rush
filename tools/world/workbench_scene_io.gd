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
	for row: Dictionary in construction.get("rooms", []):
		var id := str(row.room_id)
		if not id.begins_with("P-R"): continue
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
		data["id"] = id
		data["scene_ref"] = path
		data["source_hash"] = FileAccess.get_sha256(path)
		data["implemented"] = bool(row.get("implemented", false))
		rows[id] = data
		room.free()
	var version := ""
	if FileAccess.file_exists(FixedWorldProvider.BUNDLE):
		var runtime: Variant = JSON.parse_string(FileAccess.get_file_as_string(FixedWorldProvider.BUNDLE))
		if runtime is Dictionary: version = str(runtime.get("content_version", ""))
	var result := {"schema":1, "base_content_version":version, "rooms":rows}
	return _write_json(output, result)

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
		var packed_error := packed.pack(room)
		var expected := WorldRoomDraft.extract(room)
		room.free()
		if packed_error != OK:
			printerr("Could not pack "+id)
			return 1
		prepared.append({"id":id, "packed":packed, "expected":expected, "source":path})
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		printerr("Could not create output directory")
		return 1
	var receipts: Array = []
	for row: Dictionary in prepared:
		var path := output_dir.path_join(str(row.id)+".tscn")
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
