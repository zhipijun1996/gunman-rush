extends SceneTree
## Load the documents the shipping host can reach and probe their real collision.
## Map-only rooms are counted separately; they cannot pass by having a map outline.
var failures := 0
var loaded := 0
var endpoints := 0
var catalog := WorldContentCatalog.new()

func _initialize() -> void: run.call_deferred()

func check(ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL authored world ",detail)

func verify(doc: Dictionary) -> void:
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var err := session.open(doc,null,null,catalog)
	check(err.is_empty(),str(doc.room_id)+" "+err)
	if err.is_empty():
		loaded += 1
		await physics_frame
		await physics_frame
		check(root.get_camera_2d() == session.camera and session.camera.target == session.player and session.camera.room == session.room,doc.room_id+" active world camera")
		var collision := session.player.get_node("CollisionShape2D") as CollisionShape2D
		var space := session.room.get_world_2d().direct_space_state
		for row: Dictionary in catalog.connections(doc.room_id).rows:
			var location: Vector2
			if row.connection_type == "physical":
				location = FixedWorldProvider.point(doc.exits[row.id].spawn)
			elif row.connection_type == "interior":
				if not doc.get("sites",{}).has(row.id):
					check(false,doc.room_id+"/"+row.id+" missing interior door")
					continue
				location = FixedWorldProvider.point(doc.sites[row.id].at)
			else: continue
			endpoints += 1
			check(WorldPassage.supported(space,location,collision,session.player.collision_mask),
				doc.room_id+"/"+row.id+" unsupported or obstructed arrival at "+str(location))
	if session.audio_service != null: await session.audio_service.shutdown()
	session.free()
	await physics_frame

func run() -> void:
	check(catalog.load_locked().ok and catalog.load_bindings("res://config/imported_world/bindings.json").ok,"load current world")
	if not failures:
		var files := DirAccess.get_files_at("res://rooms/world")
		for filename in files:
			if not filename.ends_with(".json"): continue
			var id := filename.get_basename()
			var binding := catalog.room_document(id)
			if not binding.ok:
				check(false,id+" room document not registered for production")
				continue
			var doc := WorldRoomDocument.read(binding.path)
			check(doc.get("room_id","") == id,id+" identity mismatch")
			if doc.get("room_id","") == id: await verify(doc)
	print("AUTHORED WORLD failures=",failures," rooms=",loaded," arrival_points=",endpoints)
	quit(1 if failures else 0)
