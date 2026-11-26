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

func run() -> void:
	var doc := WorldRoomDocument.read("res://tests/assembly_room.json")
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
			var made := WorldElementCatalog.instantiate_definition(id, "probe", Vector2(128,128), region)
			var model := {"schema":3,"room_id":"independent","root":{"definition_id":"room.standard","definition_version":1,"properties":{"terrain_material":"gear_city","region_id":region}},"entities":made.entities}
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
