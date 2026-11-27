extends SceneTree

var failures := 0

class TestStore extends WorldSaveService:
	var payload := {}
	var revision := 0
	var writable := false

	func commit(candidate: Dictionary, next_revision: int) -> bool:
		if not writable: return false
		payload = candidate.duplicate(true)
		revision = next_revision
		return true

	func load_profile() -> Dictionary:
		return {"accepted":true,"payload":payload.duplicate(true),"revision":revision}

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func ticks(count: int) -> void:
	for frame: int in count: await physics_frame

func _initialize() -> void:
	run.call_deferred()

func check_spike_materials(source: Dictionary) -> void:
	var doc := source.duplicate(true)
	doc.root.properties.terrain_material = "thorn_forest"
	doc.root.properties.terrain_paint = {"version": 1, "regions": [
		{"id": "inlay", "material_id": "mill_masonry", "bounds": [640, 384, 64, 64]}
	]}
	var strips := {"forest": 576, "inlay_tip": 640, "explicit": 736}
	for id: String in strips:
		doc.entities[id] = {"id": id, "definition_id": "hazard.spikes", "definition_version": 1,
			"properties": {"bounds": [strips[id], 360, 32, 24]}}
	doc.entities.explicit.properties.appearance = "stone_spikes"

	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(doc)
	check(error.is_empty(), "spike material room opens: " + error)
	if error.is_empty():
		var styles := {}
		for node in session.room.get_children():
			if node is WorldSpikeArt:
				for band: Dictionary in node.bands:
					styles[int(band.rect.position.x)] = band.style
		check(styles == {576: "forest_bramble", 640: "metal_spikes", 736: "stone_spikes"},
			"assembled strips respect base material, local paint and explicit appearance")
		check(await session.audio_service.shutdown(), "spike room audio released")
	session.free()

func check_door_channels() -> void:
	var exits := {
		"west":{"direction":[-1,0],"point":[2,190],"span":[160,224]},
		"east":{"direction":[1,0],"point":[382,190],"span":[160,224]},
		"north":{"direction":[0,-1],"point":[192,2],"span":[144,240]},
		"south":{"direction":[0,1],"point":[192,318],"span":[144,240]}
	}
	var geometry := WorldRoomSpace.document_geometry([0,0,384,320], exits)
	var walls := WorldRoomSpace.exterior_fill(geometry, [])
	for point: Vector2 in [Vector2(-4,190),Vector2(388,190),Vector2(192,-4),Vector2(192,324)]:
		check(not walls.any(func(wall: Rect2): return wall.has_point(point)), "passage through exterior at "+str(point))
	for point: Vector2 in [Vector2(-4,110),Vector2(388,110),Vector2(100,-4),Vector2(100,324)]:
		check(walls.any(func(wall: Rect2): return wall.has_point(point)), "wall beside passage at "+str(point))

func check_arrival_state() -> void:
	var catalog := WorldContentCatalog.new()
	check(catalog.load_locked().ok and catalog.load_bindings("res://config/imported_world/bindings.json").ok, "load world and species bindings for doorway save")
	var store := TestStore.new()
	var origin := OrdinaryRoomSession.new()
	root.add_child(origin)
	var source := WorldRoomDocument.read("res://rooms/world/P02.json")
	var target := WorldRoomDocument.read("res://rooms/world/P01.json")
	var malformed := source.duplicate(true)
	malformed.exits.d001.span = [42, 12]
	check(WorldRoomDocument.instantiate(malformed).get("error") == "room_door_geometry_invalid", "reject reversed door spans before assembly")
	check(origin.open(source, store, null, catalog).is_empty(), "open starting room")
	var before := origin.state.value.duplicate(true)
	var destination := OrdinaryRoomSession.new()
	root.add_child(destination)
	check(destination.open(target, null, origin, catalog, "missing") == "room_entry_unknown", "reject missing receiving door")
	check(destination.open(target, null, origin, catalog, "d001") == "room_transition_save_failed", "reject unwritable transition")
	check(origin.state.value == before and origin.lifetime.active and not origin.is_queued_for_deletion(), "on failure the original room retains control and state")
	store.writable = true
	var prior_revision := origin.state.revision
	check(destination.open(target, null, origin, catalog, "d001").is_empty(), "retry arrival after save becomes available")
	check(store.revision == prior_revision + 1 and store.payload.room == "P01" and store.payload.entry == "d001", "one save contains both room and door")
	check(store.payload.explored.has("P02") and store.payload.explored.has("P01") and destination.state.valid_entry("P01", "d001"), "destination retains discovered rooms and recognizes the paired door")
	check(destination.player.position == FixedWorldProvider.point(target.exits.d001.spawn), "destination uses the receiving door anchor")
	await destination.audio_service.shutdown()
	destination.free()
	var restored := OrdinaryRoomSession.new()
	root.add_child(restored)
	check(restored.open(target, store, null, catalog).is_empty(), "reopen saved receiving room")
	check(restored.player.position == FixedWorldProvider.point(target.exits.d001.spawn), "reloading returns to the saved safe door landing")
	await restored.audio_service.shutdown()
	restored.free()

func check_live_patrol_revisits(doc: Dictionary) -> void:
	var side := doc.duplicate(true)
	side.room_id = "patrol-return-check"
	side.entities.erase("patrol")
	var current := OrdinaryRoomSession.new()
	root.add_child(current)
	check(current.open(doc).is_empty(),"open patrol fixture")
	var actor: EnemyActor = current.room.enemies.patrol
	var origin_x := actor.motor.global_position.x
	var radius := actor.definition.patrol_half_width
	actor.restore_instance_health(.5)
	# Leave partway through one rightward and one leftward trip.
	for facing: int in [1,-1]:
		for i: int in 240:
			await physics_frame
			if actor.brain.direction==facing and (actor.motor.global_position.x-origin_x)*facing>radius*.4:
				break
		await process_frame
		var position := actor.motor.global_position
		check(actor.brain.direction==facing and absf(position.x-origin_x)>radius*.4,"patrol moves away from authored origin before saving")
		var away := OrdinaryRoomSession.new()
		root.add_child(away)
		check(away.open(side,null,current).is_empty(),"visit adjacent room with moving enemy")
		await ticks(2)
		await process_frame
		current = OrdinaryRoomSession.new()
		root.add_child(current)
		check(current.open(doc,null,away).is_empty(),"revisit patrol room")
		actor = current.room.enemies.patrol
		check(actor.motor.global_position.is_equal_approx(position) and actor.brain.direction==facing and actor.health.current==.5,
				"revisit restores exact live position, direction and remaining health")
		var edge := position.x
		for i: int in 210:
			await physics_frame
			var x := actor.motor.global_position.x
			edge = maxf(edge,x) if facing>0 else minf(edge,x)
			if actor.brain.direction!=facing: break
		check(absf(edge-(origin_x+facing*radius))<.1,"revisited patrol turns at authored boundary; x="+str(edge))
	await current.audio_service.shutdown()
	current.free()


func run() -> void:
	check_door_channels()
	await check_arrival_state()
	var doc := WorldRoomDocument.read("res://tests/assembly_room.json")
	await check_live_patrol_revisits(doc)
	await check_spike_materials(doc)
	var store := TestStore.new()
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	check(session.open(doc,store).is_empty(),"fresh storage opens")
	if session.room == null or session.room.loot == null:
		printerr("Room failed to assemble")
		quit(1)
		return
	var room := session.room
	var composer := room.get_node("TerrainComposer") as TerrainComposer
	check(composer.groups[0].material_id == "echo_mines", "authored terrain selection")
	check(not FileAccess.file_exists("res://config/world/world.json"), "no frozen topology available")
	check(room.element_runtime.nodes.size() == 2, "two independent mechanisms")
	check(room.enemies.size() == 1, "real enemy factory")
	var bell: WorldElementSwitch = room.element_runtime.nodes.bell
	var gate: WorldElementGate = room.element_runtime.nodes.gate
	check(gate.body.collision_layer == 1, "closed gate collides")
	await ticks(4)
	session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(36)
	check(not bell.is_open and not gate.active and store.payload.is_empty(),"failed commit preserves closed gate")
	store.writable = true
	session.player.reset_at(room.start_point)
	await ticks(4)
	session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(36)
	check(bell.is_open and gate.active and gate.body.collision_layer == 0, "player projectile opens gate")
	check(session.state.value.mechanisms.has("gate"), "gate and bell committed")
	store.writable = false
	var actor: EnemyActor = room.enemies.patrol
	session.player.reset_at(actor.motor.position - Vector2(72, 0))
	await ticks(4)
	session.controller.router.request_action(&"shoot_release",(actor.motor.position-session.player.position-Vector2(0,-6)).normalized())
	await ticks(32)
	check(actor.health.terminal, "second shot defeats enemy")
	check(session.services.ledger().drops.is_empty() and not store.payload.enemies.has("patrol"),"failed save keeps death and payout pending together")
	store.writable = true
	await ticks(65)
	check(not session.services.ledger().drops.is_empty() or session.services.ledger().gold > 0, "defeat generates coin")
	for step: int in 120:
		if room.loot.pickups.is_empty() or session.services.ledger().gold == session.drop_rules.enemy_gold: break
		for pickup: Dictionary in room.loot.pickups:
			if not pickup.claimed:
				session.player.reset_at(pickup.position)
				break
		await ticks(1)
	check(session.services.ledger().gold == session.drop_rules.enemy_gold, "coin collected once")
	check(session.player.has_node("WeaponFeel") and PixelVfx.CLIPS.size() == 18, "weapon feedback and imported effects")
	# A single short slope must not switch distant banks to an unbatched skin.
	var bank: Array[Rect2] = [Rect2(0, 0, 640, 320)]
	var slope: Array[Dictionary] = [{"points":[[640,0],[736,64],[736,320],[640,320]]}]
	var plains := TerrainMaterialRegistry.appearance("windchime_plains")
	var level_bank := UnderworldTerrain.build(bank, {}, plains)
	var sloped_bank := UnderworldTerrain.build_with_polygons(bank, slope, {}, plains)
	var interior := Vector2i(5, 4)
	check(sloped_bank.core_layer.get_cell_source_id(interior) == 0 and sloped_bank.core_layer.tile_set == plains.tileset, "slope room uses native plains atlas inside solid bank")
	check(sloped_bank.core_layer.get_cell_atlas_coords(interior) == level_bank.core_layer.get_cell_atlas_coords(interior), "a distant slope preserves the flat bank's atlas variant")
	check(sloped_bank.core_layer.get_cell_source_id(Vector2i(20,0)) == -1, "sloped outline stays exact")
	level_bank.free()
	sloped_bank.free()
	var terrace := WorldRoomDocument.read("res://rooms/world/P02.json")
	var terrace_model := WorldRoomDocument.instantiate(terrace)
	var terrace_scene := PackedScene.new()
	check(terrace_scene.pack(terrace_model.room) == OK, "pack authored terrace")
	terrace_model.room.free()
	var saved_terrace := WorldRoomDocument.extract(terrace_scene)
	for field: String in ["scenery", "lesson", "sites", "exits"]:
		check(saved_terrace.get(field) == terrace[field], "editor preserves terrace " + field)
	var model_copy := WorldRoomDocument.instantiate(doc)
	var packed := PackedScene.new()
	check(packed.pack(model_copy.room) == OK,"pack document")
	model_copy.room.free()
	var encoded := WorldRoomDocument.extract(packed)
	check(encoded.get("bounds") == doc.bounds and encoded.entities.has("bell"),"editor round trip preserves room bounds and instance identity")
	doc = doc.duplicate(true)
	doc.entities.bell.properties.links[0].target = "missing"
	check(WorldRoomDocument.instantiate(doc).has("error"), "broken signal rejected")
	doc.entities.erase("bell")
	doc.root.properties.erase("terrain_material")
	check(WorldRoomDocument.instantiate(doc).has("error"), "unassigned material rejected")
	for material: String in TerrainMaterialRegistry.catalog().materials:
		var appearance := TerrainMaterialRegistry.appearance(material)
		check(appearance.tileset != null and appearance.texture != null, material+" registered runtime atlas")
		var definition := TerrainMaterialRegistry.definition(material)
		if definition.has("authoring_tileset"):
			var tiles := load(str(definition.authoring_tileset)) as TileSet
			check(tiles != null and tiles.tile_size == Vector2i(32,32) and tiles.get_source(0).get_tiles_count() == 47, material+" editable native TileSet")
	var species := EnemyBehaviorRegistry.behavior_ids()
	for behavior: StringName in species:
		var enemy := EnemyFactory.create_for_behavior(behavior)
		check(enemy != null, "registered species "+str(behavior))
		if enemy != null: enemy.free()
	var regions: Array = TerrainMaterialRegistry.catalog().regions.keys()
	regions.push_front("")
	for region: String in regions:
		var palette := WorldElementCatalog.mechanism_palette(region)
		var entries: Array = palette.common if region.is_empty() else palette.regional
		for id: String in entries:
			var options := {"action_id":"repair"} if id == "assembly.one_shot_route" else {}
			var made := WorldElementCatalog.instantiate_definition(id, "probe", Vector2(128,128), region,options)
			var model := {"schema":3,"room_id":"independent","root":{"definition_id":"room.standard","definition_version":1,"properties":{"terrain_material":"gear_city","region_id":region}},"entities":made.entities}
			if id in ["interaction.action","interaction.return_gate","assembly.one_shot_route"]:
				model.actions = [{"id":"repair","room_id":"independent","section_id":"main","grants":["repair"]}]
				if id != "assembly.one_shot_route": model.entities.probe.properties.action_id = "repair"
			if id == "zone.environment_shelter":
				model.entities.merge(WorldElementCatalog.instantiate_definition("hazard.area","vent",Vector2.ZERO).entities)
				model.entities.vent.properties.hazard_profile = "heat_wave"
				model.entities.probe.properties.protected_sources = ["vent"]
			if id == "hazard.falling_weight":
				model.entities.base = {"id":"base","definition_id":"platform.solid","definition_version":1,"properties":{"rect":[0,352,512,32]}}
			var result := WorldRoomDocument.instantiate(model)
			check(result.has("room"), id+" "+str(result.get("error","")))
			if result.has("room"): result.room.free()
	check(await session.audio_service.shutdown(), "audio backend released")
	session.queue_free()
	await process_frame
	await ticks(3)
	var restored := OrdinaryRoomSession.new()
	root.add_child(restored)
	check(restored.open(WorldRoomDocument.read("res://tests/assembly_room.json"),store).is_empty(),"saved room reopens")
	check(restored.room.element_runtime.nodes.gate.active and restored.room.mechanisms.bell.open_count == 1,"restore gate without replay")
	check(restored.room.enemies.patrol.health.terminal and restored.services.ledger().gold == restored.drop_rules.enemy_gold,"defeat and coin receipt survive reload")
	check(await restored.audio_service.shutdown(),"restored audio released")
	restored.free()
	print("ORDINARY ROOM failures=", failures, " species=", species.size())
	quit(1 if failures else 0)
