extends SceneTree
## A v29 save can continue in the current room. Old geometry cannot restore a
## player to obsolete coordinates, even if a foreign save is copied into the slot.
var failed := false
var catalog := WorldContentCatalog.new()

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		printerr("FAIL ", label)
		failed = true

func run() -> void:
	check(catalog.load_locked().ok and catalog.load_bindings("res://config/imported_world/bindings.json").ok,"load current world")
	var doc := WorldRoomDocument.read(catalog.room_document("P01").path)
	var path := "user://v29_fingerprint_%s.json" % OS.get_process_id()
	var slot := PlayableWorldSave.new()
	slot.configure_world(path,false,"test")
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	check(session.open(doc,slot,null,catalog).is_empty(),"open current room")
	check(session.checkpoint(),"save current room")
	await session.audio_service.shutdown()
	session.free()
	var saved := slot.load_profile()
	check(saved.accepted and saved.payload.room=="P01","read current slot")
	session = OrdinaryRoomSession.new()
	root.add_child(session)
	check(session.open(doc,slot,null,catalog).is_empty(),"continue from same geometry")
	await session.audio_service.shutdown()
	session.free()
	var old: Dictionary = saved.payload.duplicate(true)
	old.content_version = "different map and room geometry".sha256_text()
	slot.content_version = old.content_version
	check(slot.commit(old,saved.revision+1),"write foreign envelope")
	var bytes := FileAccess.get_file_as_bytes(path)
	session = OrdinaryRoomSession.new()
	root.add_child(session)
	var err := session.open(doc,slot,null,catalog)
	check(err=="room_content_save_version_mismatch" and session.room==null,"refuse stale coordinates")
	check(FileAccess.get_file_as_bytes(path)==bytes,"foreign slot stays intact")
	session.free()
	for suffix: String in ["",".backup",".tmp",".corrupt"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	print("WORLD SAVE COMPATIBILITY failures=",int(failed))
	quit(int(failed))
