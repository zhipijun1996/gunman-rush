extends SceneTree
var failures := 0
var assertions := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("EDITOR CHECK FAILED: "+label)
func run() -> void:
	var construction: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/world/construction.json"))
	var count := 0
	for row: Dictionary in construction.rooms:
		var path := "res://config/world/rooms/"+str(row.room_id)+".json"
		if not FileAccess.file_exists(path): continue
		var doc := WorldRoomDocument.read(path)
		var result := WorldRoomDocument.instantiate(doc)
		check(not result.has("error"), "document creates real components "+str(row.room_id))
		if result.has("error"): continue
		check(result.room.room_id == row.room_id, "stable room identity")
		var wrapper := (load(str(row.scene_ref)) as PackedScene).instantiate() as FixedWorldRoom
		check(wrapper.document_error.is_empty(), "legacy direct scene consumer loads document")
		check(wrapper.platforms == result.room.platforms, "wrapper and direct JSON share collision geometry")
		if row.room_id == "P-R14":
			check(result.room.boss_binding != null, "Boss binding survives full export")
			check(result.room.get_node_or_null("PlatformingModule") != null or result.room.find_children("*", "PlatformingModule", true, false).size() == 1, "arena module survives export")
		wrapper.free()
		result.room.free()
		count += 1
	check(count == Array(DirAccess.get_files_at("res://config/world/rooms")).filter(func(name: String) -> bool: return name.ends_with(".json")).size(), "every authored JSON room covered")
	var app := preload("res://game/application/world/fixed_world.tscn").instantiate() as FixedWorldApp
	root.add_child(app)
	check(await app.review.begin("P-R03", "", "base", true), "formal app loads migrated room with real player")
	check(app.room != null and app.room.platforms.size() > 0, "room creates live collision bodies")
	var editor_project_path := "res://build/editor/project.json"
	if FileAccess.file_exists(editor_project_path):
		var project: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(editor_project_path))
		var error := app.content.install_editor_project(project, "P-R13")
		check(error.is_empty(), "project compiler supports all authored rooms: "+error)
		if error.is_empty():
			Engine.set_meta("world_editor_graybox", true)
			check(await app.review.begin("P-R13", "", "base", true, ["H"], []), "native editor uses isolated real controller lifecycle")
			check(app.room.find_children("*", "WorldEditorGraybox", false, false).size() == 1, "graybox is presentation on the real collision room")
			check(app.state.has("H") and not app.state.has("D"), "preview uses exact selected ability set")
			check(app.content.room("P-R13").doors.size() == project.rooms["P-R13"].ports.size(), "preview consumes live paired-port topology")
	else:
		check(false, "generate build/editor/project.json with tools/world/export_editor_project.py before test")
	await WorldAudioLifecycle.drain_world(app)
	Engine.remove_meta("world_editor_graybox")
	app.queue_free()
	await process_frame
	print("EDITOR DOCUMENTS RUNTIME: ", assertions, " assertions, ", failures, " failures")
	quit(1 if failures else 0)
