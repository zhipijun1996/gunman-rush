extends SceneTree
## Run from an empty project against the actual exported PCK, never repo fallback.
var app: FixedWorldApp
var failed := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, detail: String) -> void:
	if not ok:
		failed += 1
		printerr("WORKBENCH PACK FAILED: ", detail)

func ticks(count: int) -> void:
	for frame: int in count: await physics_frame

func settle() -> void:
	for frame: int in 300:
		await physics_frame
		if not app.busy: break
	await ticks(5)
	check(not app.busy, "room transition finishes")

func run() -> void:
	root.size = Vector2i(1280, 720)
	check(not FileAccess.file_exists("res://config/world/world.json"), "no authoring source fallback")
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://build/workbench/preview-world.json"))
	if not catalog is Dictionary or not catalog.get("rooms") is Dictionary:
		check(false, "compiled preview catalog missing");quit(1);return
	var expected: Dictionary = {}
	for index: int in range(1, 36): expected["P-R%02d" % index] = true
	var scope_path := "res://config/workbench/rooms.json"
	if FileAccess.file_exists(scope_path):
		var scope: Variant = JSON.parse_string(FileAccess.get_file_as_string(scope_path))
		if not scope is Dictionary or scope.get("schema") != 1 or not scope.get("additional_room_ids") is Array:
			check(false, "registered preview room scope invalid");quit(1);return
		for id: String in scope.additional_room_ids: expected[id] = true
	var formal_catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://build/world/runtime.json"))
	for id:String in formal_catalog.rooms:expected[id]=true
	check(catalog.rooms.size() == expected.size(), "complete plains and registered preview scene contracts")
	for id: String in expected: check(catalog.rooms.has(id), "registered preview scene " + id)
	var plains: Dictionary = {}
	for id: String in catalog.rooms:
		var row: Dictionary = catalog.rooms[id]
		var packed := load(str(row.scene_ref)) as PackedScene
		if packed == null:
			check(false, "packaged scene " + id);continue
		var room := packed.instantiate() as FixedWorldRoom
		if room == null:
			check(false, "room instance " + id);continue
		var draft := WorldRoomDraft.extract(room)
		check(WorldRoomDraft.validate(room, draft).is_empty(), "editable packed scene " + id)
		if id == "P-R03": plains = draft
		room.free()
	app = preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path = "user://workbench_pack_probe.json"
	app.save_profile = "workbench_pack_probe"
	for suffix: String in ["", ".backup", ".tmp", ".corrupt"]: DirAccess.remove_absolute(app.save_path + suffix)
	root.add_child(app)
	var formal_ids: Array = app.content.data.rooms.keys()
	check(app.start_new(), "actual FixedWorldApp accepts new game")
	await settle()
	for id: String in formal_ids:
		app.load_room(id, "")
		await settle()
		if is_instance_valid(app.introduction) and app.introduction.phase in ["pending","waking"]:
			await ticks(100)
			while app.introduction.dialogue_active:app.introduction.advance()
		check(app.room != null and app.room.room_id == id and app.controller.active, "actual room and native presentation " + id + ": " + app.status)
		print("WORKBENCH PACK room=", id)
	app.return_title()
	await ticks(4)
	app.workbench.enabled = true
	plains.base_content_version = app.content.workbench_base_version()
	plains.revision = 1
	plains.properties.enemy_placements = []
	var species: Array[String] = []
	for behavior: StringName in EnemyBehaviorRegistry.behavior_ids(): species.append(str(behavior))
	for index: int in species.size():
		plains.properties.enemy_placements.append({"id":"pack_" + species[index], "behavior":species[index], "point":[560 + index*48, 1750]})
	await app.workbench._handle({"channel":"gunman-workbench", "type":"load_draft", "request_id":"pack_species", "revision":1, "draft":plains, "paused":true})
	check(app.workbench.last_event.get("type") == "draft_loaded", "real draft bridge: " + JSON.stringify(app.workbench.last_event))
	if app.room != null:
		for species_id: String in species:
			check(app.room.enemies.has("pack_" + species_id), "instantiated registered species " + species_id)
	await WorldAudioLifecycle.drain_world(app)
	app.queue_free()
	await ticks(8)
	for suffix: String in ["", ".backup", ".tmp", ".corrupt"]: DirAccess.remove_absolute("user://workbench_pack_probe.json" + suffix)
	print("WORKBENCH PACK failures=", failed, " formal_rooms=", formal_ids.size(), " editable_scenes=", catalog.rooms.size(), " species=", species.size())
	quit(failed)
