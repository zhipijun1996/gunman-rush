extends SceneTree
func _initialize() -> void:
	var input := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--documents="): input = argument.trim_prefix("--documents=")
	if input.is_empty(): quit(2);return
	var request: Variant = JSON.parse_string(FileAccess.get_file_as_string(input))
	if not request is Array: quit(2);return
	var failures := 0
	for path: String in request:
		var doc := WorldRoomDocument.read(path)
		if doc.has("error"): failures += 1;continue
		var result := WorldRoomDocument.instantiate(doc)
		if result.has("error"):
			printerr(str(doc.get("room_id", path))+":"+str(result.error))
			failures += 1
		else: result.room.free()
	print("EDITOR VALIDATE: ", request.size(), " documents, ", failures, " failures")
	quit(1 if failures else 0)
