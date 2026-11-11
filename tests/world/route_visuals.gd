extends "res://tests/world/approved_exploration_rooms.gd"
## Formal boss arena art survives draft roundtrip and follows committed floor changes.
func run() -> void:
	app = preload("res://game/application/world/fixed_world.tscn").instantiate()
	root.add_child(app)
	var source := load("res://game/world/regions/P/rooms/P-R14.tscn") as PackedScene
	var authored := source.instantiate() as FixedWorldRoom
	var draft := WorldRoomDraft.extract(authored)
	check(WorldRoomDraft.apply(authored, draft).is_empty(), "arena draft roundtrip")
	check(authored.get_node_or_null("Arena/RegionalTerrain") is WorldModuleTerrain, "roundtrip retains formal terrain presenter")
	var packed := PackedScene.new()
	check(packed.pack(authored) == OK, "arena scene packs")
	var restored := packed.instantiate()
	check(restored.get_node_or_null("Arena/RegionalTerrain") is WorldModuleTerrain, "packed roundtrip retains presenter")
	check(restored.get_node("Arena").get_meta("authored_timber_surface", false), "packed roundtrip retains timber presentation")
	restored.free(); authored.free()
	await load_room("P-R14")
	var arena := app.room.get_node("Arena") as PlatformingModule
	var art := arena.get_node("RegionalTerrain") as WorldModuleTerrain
	var original := arena.definition.platforms.duplicate()
	check(art.terrain != null and arena.terrain_candidate_preview, "formal arena uses regional terrain")
	for i: int in original.size():
		var body := arena.get_node("Platform" + str(i)) as StaticBody2D
		var shape := body.get_node("CollisionShape2D") as CollisionShape2D
		check(body.position == original[i].get_center() and shape.shape.size == original[i].size, "presentation preserves authored collision")
	var previous := art.terrain.get_instance_id()
	await ticks(8)
	check(art.terrain.get_instance_id() == previous, "stable arena does not rebuild each frame")
	# Simulate a committed phase geometry update in an isolated fixture.
	arena.definition.platforms[0] = Rect2(0, 760, 640, 96)
	await ticks(2)
	check(art.surfaces[0] == arena.definition.platforms[0] and art.terrain.get_instance_id() != previous, "phase geometry refreshes presentation")
	arena.definition.platforms = original
	await ticks(2)
	check(art.surfaces[0] == original[0], "restored phase restores terrain")
	await WorldAudioLifecycle.drain_world(app)
	print("ROUTE VISUALS: ", failures, " failures")
	quit(failures)
