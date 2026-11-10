extends "res://tests/world/plains_intro.gd"
## Real scene roundtrip, runtime draft replacement, slope traversal, and save isolation.
var baseline_draft: Dictionary = {}

func _codec_checks() -> void:
	var construction: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/world/construction.json"))
	for row: Dictionary in construction.rooms:
		if not str(row.room_id).begins_with("P-R"): continue
		var scene := (load(str(row.scene_ref)) as PackedScene).instantiate() as FixedWorldRoom
		var draft := WorldRoomDraft.extract(scene)
		var error := WorldRoomDraft.validate(scene, draft)
		check(error.is_empty(), "current scene editable "+str(row.room_id)+" "+error)
		if row.room_id == "P-R22": baseline_draft = draft
		scene.free()
	var fresh := preload("res://game/world/regions/P/rooms/P-R22.tscn").instantiate() as FixedWorldRoom
	var before := JSON.stringify(WorldRoomDraft.extract(fresh), "", true)
	var malformed := baseline_draft.duplicate(true)
	malformed.properties.platforms[0][2] = -32
	check(not WorldRoomDraft.apply(fresh, malformed).is_empty(), "negative collision size rejected")
	check(JSON.stringify(WorldRoomDraft.extract(fresh), "", true) == before, "rejected draft leaves source instance untouched")
	malformed = baseline_draft.duplicate(true)
	malformed.properties.terrain_polygons = [{"id":"self_crossing", "points":[[0,0],[96,96],[0,96],[96,0]]}]
	check(not WorldRoomDraft.apply(fresh, malformed).is_empty(), "self-intersecting polygon rejected")
	malformed = baseline_draft.duplicate(true)
	malformed.properties.enemy_placements = [{"id":"bad_enemy", "behavior":"not_registered", "point":[0,0]}]
	check(not WorldRoomDraft.apply(fresh, malformed).is_empty(), "unknown behavior rejected before runtime")
	malformed = baseline_draft.duplicate(true)
	malformed.properties.gear_obstacles = [{"id":"bad_gear", "point":[300,300], "period":0}]
	check(WorldRoomDraft.apply(fresh, malformed) == "gear_period_invalid", "zero-period gear rejected before division by zero")
	malformed = baseline_draft.duplicate(true)
	malformed.properties.environment_zones = [{"id":"bad_zone", "bounds":[0,0,100,100], "mode":"invented"}]
	check(WorldRoomDraft.apply(fresh, malformed) == "environment_mode_invalid", "unknown environment cannot silently become harmless")
	malformed = baseline_draft.duplicate(true)
	malformed.properties.camera_interests = [{"bounds":[0,0,200,100], "point":[100]}]
	check(WorldRoomDraft.apply(fresh, malformed) == "property_not_editable:camera_interests", "retired camera interface rejected before entering the room")
	fresh.free()
	for behavior: StringName in EnemyBehaviorRegistry.behavior_ids():
		var motor := EnemyFactory.create_for_behavior(behavior)
		check(motor != null, "catalog species is constructed by actual game factory: "+str(behavior))
		if motor != null: motor.free()

func _catalog_roundtrip() -> void:
	var draft := baseline_draft.duplicate(true)
	draft.properties.spike_strips.append({"id":"catalog_spikes", "bounds":[512,1280,160,24], "facing":"down"})
	draft.properties.gear_obstacles.append({"id":"catalog_gear", "point":[704,1056], "travel":[0,128], "period":4.8, "phase":0.25})
	draft.properties.environment_zones.append({"id":"catalog_water", "bounds":[512,1440,256,128], "mode":"water"})
	draft.properties.bell_mechanisms.append({"id":"catalog_bell", "bell":[400,1200], "gate":[704,1152,32,128], "open_seconds":3.0, "access_bells":[[800,1200]]})
	draft.properties.retry_anchors = [{"bounds":[256,1152,128,128], "point":[320,1200], "section":"main"}]
	draft.properties.art_placements = [{"point":[448,1280], "asset":"barrel", "layer":-2}]
	draft.nodes.append({"path":"TestCarrier", "type":"WorldMovingPlatform", "properties":{"position":[1700,1450], "endpoint":[192,0], "platform_size":[128,24], "period":5.0, "endpoint_dwell":0.0}})
	for field: String in ["retry_anchors", "art_placements"]:
		draft.properties.workbench_entity_ids[field] = ["catalog:"+field]
	_roundtrip(draft)

func _runtime_scope_checks() -> void:
	var provider := FixedWorldProvider.new()
	check(provider.open(), "compiled runtime scope fixture opens the formal source")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FixedWorldProvider.WORKBENCH_CATALOG))
	var runtime := provider.data.duplicate(true)
	for key: String in ["rooms", "actions", "demo_services", "npcs", "map_rooms"]:
		runtime[key] = catalog[key].duplicate(true)
	var accepted := baseline_draft.duplicate(true)
	accepted.base_content_version = provider.workbench_base_version()
	accepted.revision = 40
	accepted.runtime = runtime
	check(not accepted.has("geometry"), "runtime scope tests do not rely on a separate geometry draft")
	check(provider.install_workbench_draft(accepted).is_empty(), "same-version complete compiled preview runtime is accepted")
	check(provider.data.rooms.size() == catalog.rooms.size() and provider.workbench_formal_room_ids().size() == 24, "compiled runtime replacement keeps the registered preview scope and formal twenty-four-room base")
	var unchanged := JSON.stringify(provider.workbench_snapshot(), "", true)
	for mutation: String in ["component", "room", "map_room", "seam"]:
		var rejected := accepted.duplicate(true)
		rejected.revision = 41
		var expected := ""
		match mutation:
			"component":
				for map_row: Dictionary in rejected.runtime.map_rooms:
					if map_row.id == "P-R22": map_row.map_component = "P-R22"
				expected = "runtime_map_component_changed"
			"room":
				rejected.runtime.rooms.erase("P-R17")
				expected = "runtime_room_scope_mismatch"
			"map_room":
				rejected.runtime.map_rooms.pop_back()
				expected = "runtime_map_scope_mismatch"
			"seam":
				for door: Dictionary in rejected.runtime.rooms["P-R22"].doors:
					if door.target_room == "P-R23": door.position_candidate.local_world_units[1] += 16
				expected = "map_seam_conflict:"
		var error := provider.install_workbench_draft(rejected)
		check(error.begins_with(expected), "compiled runtime rejects "+mutation+" without a separate geometry field: "+error)
		check(JSON.stringify(provider.workbench_snapshot(), "", true) == unchanged, "rejected compiled runtime leaves state unchanged: "+mutation)
	provider.restore_workbench_base()
	check(provider.data.rooms.size() == 24, "compiled runtime scope fixture restores the formal source")

func _fixture() -> Dictionary:
	var result := baseline_draft.duplicate(true)
	var props: Dictionary = result.properties
	props.platforms = [[0,1408,512,384], [1024,1152,512,640], [672,160,192,32], [2976,1152,288,32]]
	props.workbench_entity_ids.platforms = ["test:left", "test:right", "test:top_entry", "test:right_entry"]
	props.one_way_indices = []
	props.masonry_platform_indices = []
	props.illustrated_platform_indices = []
	props.terrain_polygons = [{"id":"test:slope", "points":[[512,1408],[1024,1152],[1024,1792],[512,1792]], "material":"ground"}]
	props.start_point = [96,1390]
	props.bell_mechanisms = []
	props.enemy_placements = []
	props.spike_strips = []
	props.retry_anchors = []
	props.signs = []
	props.workbench_entity_ids.signs = []
	props.art_placements = []
	for field: String in ["retry_anchors", "art_placements"]:
		props.workbench_entity_ids[field] = []
	result.nodes = [{"path":"TestCarrier", "type":"WorldMovingPlatform", "properties":{"position":[1700,1450], "endpoint":[192,0], "platform_size":[128,24], "period":5.0, "endpoint_dwell":0.0}}]
	return result

func _roundtrip(draft: Dictionary) -> void:
	var fresh := preload("res://game/world/regions/P/rooms/P-R22.tscn").instantiate() as FixedWorldRoom
	check(WorldRoomDraft.apply(fresh, draft).is_empty(), "slope and registered mechanism apply before ready")
	var expected := WorldRoomDraft.extract(fresh)
	var packed := PackedScene.new()
	check(packed.pack(fresh) == OK, "pack edited actual scene")
	fresh.free()
	DirAccess.make_dir_recursive_absolute("res://build/workbench/tests")
	var path := "res://build/workbench/tests/roundtrip.tscn"
	check(ResourceSaver.save(packed, path) == OK, "save candidate scene")
	var loaded := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var instance := loaded.instantiate() as FixedWorldRoom
	check(JSON.stringify(WorldRoomDraft.extract(instance), "", true) == JSON.stringify(expected, "", true), "ResourceSaver output has the exact accepted codec contents")
	check(instance.get_node_or_null("TestCarrier") is WorldMovingPlatform, "new mechanism retained by scene ownership")
	var removed := WorldRoomDraft.extract(instance)
	removed.nodes = []
	check(WorldRoomDraft.apply(instance, removed).is_empty() and instance.get_node_or_null("TestCarrier") == null, "omitted authored mechanism is really removed")
	instance.free()

func _walk_to(x: float, limit := 420) -> void:
	for frame: int in limit:
		await physics_frame
		if app.busy: continue
		var delta := x-app.player.position.x
		app.controller.router.set_source_axis(&"keyboard_mouse", signf(delta) if absf(delta)>4 else 0.0)
		if absf(delta)<6 and app.player.is_on_floor(): break
	app.controller.router.clear("workbench_test_stop")
	await ticks(4)

func run() -> void:
	root.size = Vector2i(1280,720)
	_codec_checks()
	_catalog_roundtrip()
	_runtime_scope_checks()
	var draft := _fixture()
	_roundtrip(draft)
	app = preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path = "user://workbench_runtime_test.json"
	app.save_profile = "workbench_runtime_test"
	for suffix: String in ["", ".backup", ".tmp", ".corrupt"]: DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app)
	check(app.start_new(), "independent formal save fixture starts")
	await settle()
	app.return_title()
	await ticks(3)
	var formal_bytes := FileAccess.get_file_as_string(app.save_path)
	var formal_storage := app.state.storage
	app.workbench.enabled = true # Native test of the same handler; no JS emulation.
	draft.base_content_version = app.content.workbench_base_version()
	draft.revision = 1
	await app.workbench._handle({"channel":"gunman-workbench", "type":"load_draft", "request_id":"first", "revision":1, "draft":draft, "paused":true})
	check(app.workbench.last_event.get("type") == "draft_loaded", "actual app loads draft "+JSON.stringify(app.workbench.last_event))
	if app.room == null:
		print("WORLD WORKBENCH: ",failures," failures")
		quit(maxi(failures, 1));return
	check(app.paused and app.review.active, "editing pauses actual gameplay in isolated review")
	var polygon_bodies := app.room.find_children("Polygon_*", "StaticBody2D", true, false)
	check(polygon_bodies.size() == 1, "one true polygon body exists")
	check(app.room.get_node_or_null("TestCarrier") is WorldMovingPlatform, "registered mechanism exists in actual runtime")
	await app.workbench._handle({"channel":"gunman-workbench", "type":"play", "request_id":"play"})
	await _walk_to(1180)
	check(app.player.position.x > 1100 and app.player.position.y < 1150 and app.player.is_on_floor(), "real controller walks up 256wu slope: "+str(app.player.position))
	await _walk_to(160)
	check(app.player.position.x < 200 and app.player.position.y > 1370 and app.player.is_on_floor(), "real controller walks down slope: "+str(app.player.position))
	await _walk_to(700)
	app.controller.router.set_jump_held(&"keyboard_mouse", true)
	await ticks(10)
	app.controller.router.set_jump_held(&"keyboard_mouse", false)
	app.controller.router.request_action(&"shoot_release", Vector2.LEFT)
	await ticks(90)
	app.controller.router.clear("workbench_land")
	check(app.player.is_on_floor(), "real jump and recoil land on authored geometry")
	var old_room := app.room.get_instance_id()
	var old_app := app.get_instance_id()
	var second := draft.duplicate(true)
	second.revision = 2
	second.properties.terrain_polygons[0].points[1][1] = 1216
	second.properties.terrain_polygons[0].points[2][1] = 1792
	await app.workbench._handle({"channel":"gunman-workbench", "type":"load_draft", "request_id":"second", "revision":2, "draft":second, "paused":true})
	check(app.workbench.last_event.get("type") == "draft_loaded" and app.workbench.last_event.get("revision") == 2, "next draft acknowledged with actual revision")
	check(app.get_instance_id() == old_app and app.room.get_instance_id() != old_room, "room replaced while the application and engine stay resident")
	check(app.room.terrain_polygons[0].points[1][1] == 1216, "new polygon reaches the actual scene")
	var accepted_room := app.room.get_instance_id()
	await app.workbench._handle({"channel":"gunman-workbench", "type":"load_draft", "request_id":"stale", "revision":1, "draft":draft})
	check(app.workbench.last_event.get("code") == "stale_revision" and app.room.get_instance_id() == accepted_room, "stale draft cannot replace current room")
	var unsafe := second.duplicate(true)
	unsafe.revision = 3
	unsafe.properties.platforms[0][1] = 1536
	await app.workbench._handle({"channel":"gunman-workbench", "type":"load_draft", "request_id":"unsafe", "revision":3, "draft":unsafe})
	check(app.workbench.last_event.get("code") == "room_load_failed" and app.workbench.revision == 2, "real unsafe spawn rejects candidate without advancing accepted revision")
	check(app.room != null and app.paused and app.room.platforms[0].position.y == 1408, "failed physical load restores previous editable room")
	var geometry_draft := second.duplicate(true)
	geometry_draft.revision = 3
	var contract := app.content.room("P-R22").duplicate(true)
	geometry_draft.geometry = {"bounds":contract.world_geometry.bounds_world_units.duplicate(), "space_rects":contract.world_geometry.space_rects.duplicate(true), "doors":contract.doors.duplicate(true)}
	geometry_draft.geometry.space_rects[1][2] = 1504
	await app.workbench._handle({"channel":"gunman-workbench", "type":"load_draft", "request_id":"geometry", "revision":3, "draft":geometry_draft})
	check(app.workbench.last_event.get("type") == "draft_loaded", "changed real room shape accepted "+JSON.stringify(app.workbench.last_event))
	check(app.room.contract.world_geometry.space_rects[1][2] == 1504, "shape change reaches camera and physics contract")
	var moved_door := geometry_draft.duplicate(true)
	moved_door.revision = 4
	var entry_id := "INTRO-P22-P23:P-R22"
	for door: Dictionary in moved_door.geometry.doors:
		if door.id != entry_id: continue
		door.position_candidate.local_world_units[1] -= 32
		door.landing_contract.safe_standing_position_world_units[1] -= 32
		door.landing_contract.entry_position_world_units[1] -= 32
		door.landing_contract.platform_candidate_rect_world_units[1] -= 32
	moved_door.properties.platforms[3][1] -= 32
	await app.workbench._handle({"channel":"gunman-workbench", "type":"load_draft", "request_id":"unpaired_door", "revision":4, "draft":moved_door, "entry_id":entry_id})
	check(app.workbench.last_event.get("code") == "draft_rejected" and str(app.workbench.last_event.get("detail", "")).begins_with("map_seam_conflict"), "full 35-room loop rejects an inconsistent single-ended door shift")
	var neighbor_scene := preload("res://game/world/regions/P/rooms/P-R23.tscn").instantiate() as FixedWorldRoom
	var neighbor := WorldRoomDraft.extract(neighbor_scene)
	neighbor_scene.free()
	var neighbor_contract := app.content.room("P-R23")
	neighbor.geometry = {"bounds":neighbor_contract.world_geometry.bounds_world_units.duplicate(), "space_rects":neighbor_contract.world_geometry.space_rects.duplicate(true), "doors":neighbor_contract.doors.duplicate(true)}
	for door: Dictionary in neighbor.geometry.doors:
		if door.target_room != "P-R22": continue
		door.position_candidate.local_world_units[1] -= 32
		door.landing_contract.safe_standing_position_world_units[1] -= 32
		door.landing_contract.entry_position_world_units[1] -= 32
		door.landing_contract.platform_candidate_rect_world_units[1] -= 32
	neighbor.properties.platforms[0][1] -= 32
	neighbor.properties.platforms[6][1] -= 32
	neighbor.properties.start_point[1] -= 32
	moved_door.room_drafts = {"P-R23":neighbor}
	await app.workbench._handle({"channel":"gunman-workbench", "type":"load_draft", "request_id":"door", "revision":4, "draft":moved_door, "entry_id":entry_id})
	check(app.workbench.last_event.get("type") == "draft_loaded", "edited door and actual landing load together "+JSON.stringify(app.workbench.last_event))
	check(absf(app.player.position.y-1102) < 3 and app.player.is_on_floor(), "normal entry uses moved authored support")
	await app.workbench._handle({"channel":"gunman-workbench", "type":"play", "request_id":"cross"})
	app.controller.router.set_source_axis(&"keyboard_mouse", 1.0)
	for frame: int in 180:
		await physics_frame
		if app.room != null and app.room.room_id == "P-R23" and not app.busy: break
	app.controller.router.clear("workbench_cross_stop")
	check(app.room != null and app.room.room_id == "P-R23" and app.player.is_on_floor() and app.room.platforms[0].position.y == 608, "edited real doorway traverses to same-revision edited adjacent room")
	check(FileAccess.get_file_as_string(app.save_path) == formal_bytes, "editing and slope trials preserve formal save bytes")
	await app.workbench._handle({"channel":"gunman-workbench", "type":"leave", "request_id":"leave"})
	check(not app.review.active and app.state.storage == formal_storage, "leaving restores formal storage and base provider")
	check(FileAccess.get_file_as_string(app.save_path) == formal_bytes, "leaving workbench does not write test progress")
	check(app.content.data.rooms.size() == 24 and app.content.room("P-R18").is_empty(), "formal construction state still exposes only the twenty-four constructed rooms")
	var unbuilt_scene := preload("res://game/world/regions/P/rooms/P-R18.tscn").instantiate() as FixedWorldRoom
	var unbuilt := WorldRoomDraft.extract(unbuilt_scene)
	unbuilt_scene.free()
	unbuilt.base_content_version = app.content.workbench_base_version()
	unbuilt.revision = 1
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FixedWorldProvider.WORKBENCH_CATALOG))
	var unbuilt_contract: Dictionary = catalog.rooms["P-R18"]
	unbuilt.geometry = {"bounds":unbuilt_contract.world_geometry.bounds_world_units, "space_rects":unbuilt_contract.world_geometry.space_rects, "doors":unbuilt_contract.doors}
	await app.workbench._handle({"channel":"gunman-workbench", "type":"load_draft", "request_id":"unbuilt", "revision":1, "draft":unbuilt})
	check(app.workbench.last_event.get("type") == "draft_loaded" and app.workbench.last_event.get("preview_only") == true, "unbuilt room loads through real runtime and stays labelled preview only "+JSON.stringify(app.workbench.last_event))
	check(app.room != null and app.room.room_id == "P-R18" and app.player.is_on_floor(), "unbuilt authored scene and real controller physically land")
	var preview_ids: Array = catalog.rooms.keys()
	preview_ids.sort()
	var actual_ids: Array = app.content.data.rooms.keys()
	actual_ids.sort()
	check(actual_ids == preview_ids and app.content.action("reward_return_EQ_MAP_P03_open").get("room_id") == "P-R17", "registered authored preview rooms and local return action available in disposable session")
	await app.workbench._handle({"channel":"gunman-workbench", "type":"leave", "request_id":"unbuilt_leave"})
	check(app.content.data.rooms.size() == 24 and app.state.storage == formal_storage and FileAccess.get_file_as_string(app.save_path) == formal_bytes, "unbuilt preview restores formal twenty-four-room catalog and save")
	await WorldAudioLifecycle.drain_world(app)
	app.queue_free()
	await ticks(8)
	print("WORLD WORKBENCH: ",failures," failures")
	quit(failures)
