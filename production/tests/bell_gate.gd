extends SceneTree

var failures := 0
const PRESET := "assembly.bell_gate"
const ROOM := "res://tests/bell_gate_demo.json"

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func ticks(frames: int) -> void:
	for i: int in frames: await physics_frame

func create(options: Dictionary) -> Dictionary:
	return WorldElementCatalog.instantiate_definition(PRESET, "shutter", Vector2(368,360), "gear_city", options)

func check_authoring() -> void:
	var once := create({}).entities as Dictionary
	check(FixedWorldProvider.point(once["shutter/bell"].properties.position) == Vector2(272,360), "bell uses local offset")
	check(FixedWorldProvider.rect(once["shutter/gate"].properties.bounds) == Rect2(464,296,32,128), "gate uses local offset")
	check(once["shutter/bell"].properties.duration == 0 and once["shutter/gate"].properties.state_scope == "permanent", "one-shot defaults")
	var custom := create({"mode":"timed", "bell.duration":1.25, "gate.bounds":[8,12,40,128], "member_offsets":{"gate":[16,24]}}).entities as Dictionary
	check(FixedWorldProvider.rect(custom["shutter/gate"].properties.bounds) == Rect2(392,396,40,128), "local bounds and member offset applied once")
	check(custom["shutter/bell"].properties.duration == 1.25 and custom["shutter/gate"].properties.state_scope == "attempt", "timed fields")
	for invalid: Dictionary in [{"mode":"toggle"},{"bell.duration":1},{"mode":"timed","bell.duration":0},{"bell.duration":-1},
			{"mode":"timed","bell.duration":"2"},{"gate.bounds":[0,0,0,128]},{"member_offsets":{"unknown":[0,0]}},
			{"section_id":""},{"state_scope":"attempt"},{"member_offsets":{"bell":[0]}}]:
		check(create(invalid).has("error"), "diagnose invalid option " + str(invalid))
	var doc := WorldRoomDocument.read(ROOM)
	doc.entities.merge(create({"mode":"timed","section_id":"side"}).entities,true)
	check(WorldRoomDocument.instantiate(doc).has("error"), "reject unknown room section")
	doc.root.properties.section_volumes = [{"id":"side","bounds":[0,0,512,500]}]
	doc.entities["shutter/gate"].properties.section_id = "main"
	check(WorldRoomDocument.instantiate(doc).has("error"), "reject cross-section temporary link")
	doc.entities["shutter/gate"].properties.section_id = "side"
	doc.entities["shutter/bell"].properties.repeat_enabled = true
	check(WorldRoomDocument.instantiate(doc).has("error"), "reject overlapping switch modes")
	doc.entities["shutter/bell"].properties.repeat_enabled = false
	doc.entities["shutter/bell"].properties.initial_active = true
	check(WorldRoomDocument.instantiate(doc).has("error"), "timed always starts ready")
	doc.entities = once
	# Old groups retain their authored child names and data, even without a stored source version.
	var old: Dictionary = doc.entities["shutter/bell"]
	doc.entities.erase("shutter/bell")
	old.id = "shutter/switch"
	old.properties.element_id = old.id
	doc.entities[old.id] = old
	for row: Dictionary in doc.entities.values(): row.erase("assembly_definition_version")
	var previous := WorldRoomDocument.instantiate(doc)
	check(previous.has("room"), "previously placed v1 group loads")
	if previous.has("room"):
		var packed := PackedScene.new()
		check(packed.pack(previous.room) == OK,"pack historical assembly")
		previous.room.free()
		var saved := WorldRoomDocument.extract(packed)
		check(saved.entities["shutter/switch"].assembly_definition_version == 1, "round trip keeps original provenance")
	old.assembly_definition_version = 2
	check(WorldRoomDocument.instantiate(doc).has("error"), "wrong source version rejected")

func check_play() -> void:
	var doc := WorldRoomDocument.read(ROOM)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("region="):
			var region := argument.trim_prefix("region=")
			doc.root.properties.region_id = region
			doc.root.properties.terrain_material = region
	var generated := create({"mode":"timed","member_offsets":{"gate":[96,-104]}})
	var from_catalog := doc.duplicate(true)
	from_catalog.entities.merge(generated.entities, true)
	var authored := WorldRoomDocument.view(doc)
	var expected := WorldRoomDocument.view(from_catalog)
	for id: String in generated.entities:
		check(authored.entities[id].properties == expected.entities[id].properties, "playable fixture equals catalog expansion " + id)
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(doc)
	if not error.is_empty():
		check(false, error)
		session.free()
		return
	var bell: WorldElementSwitch = session.room.element_runtime.nodes["shutter/bell"]
	var gate: WorldElementGate = session.room.element_runtime.nodes["shutter/gate"]
	await ticks(12)
	session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(24)
	check(bell.is_open and gate.body.collision_layer == 0, "controller projectile opens real gate")
	var first := bell._opened_at
	session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(24)
	check(bell._opened_at == first and bell.open_count == 1, "active hits preserve initial deadline")
	session.controller.router.set_move_axis(1)
	for i: int in 160:
		if session.player.global_position.x >= gate.bounds.get_center().x: break
		await physics_frame
	session.controller.router.set_move_axis(0)
	# Stop in the opening with the same body that passed the formerly solid face.
	session.player.velocity = Vector2.ZERO
	await ticks(200)
	check(gate.bounds.grow(12).has_point(session.player.global_position), "player reached and occupies gate")
	check(gate.active and bell.is_open, "expired gate waits for player to clear")
	session.controller.router.set_move_axis(1)
	await ticks(40)
	session.controller.router.set_move_axis(0)
	check(not gate.active and not bell.is_open and gate.body.collision_layer == 1, "same pending close accepted after exit")
	check(session.state.value.mechanisms.is_empty(), "attempt leaves no permanent receipt")
	check(await session.audio_service.shutdown(), "audio released")
	session.free()

func check_toggle() -> void:
	var doc := WorldRoomDocument.read("res://tests/assembly_room.json")
	doc.entities.erase("patrol")
	doc.entities.bell.properties.repeat_enabled = true
	doc.entities.bell.properties.initial_active = true
	doc.entities.bell.properties.access_points = [[232,360]]
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(doc)
	if not error.is_empty():
		check(false,error)
		session.free()
		return
	var bell: WorldElementSwitch = session.room.element_runtime.nodes.bell
	var gate: WorldElementGate = session.room.element_runtime.nodes.gate
	check(bell.is_open and gate.active and gate.body.collision_layer == 0, "fresh toggle initializes linked gate")
	await ticks(4)
	session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(32)
	check(not gate.active and bell.open_count == 1, "shot at access point toggles shared switch once")
	check(await session.audio_service.shutdown(), "toggle audio released")
	session.free()

func run() -> void:
	check_authoring()
	await check_play()
	await check_toggle()
	print("BELL GATE failures=", failures)
	quit(1 if failures else 0)
