extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func instance_rows(definition: String, id: String, region: String) -> Dictionary:
	return WorldElementCatalog.instantiate_definition(definition, id, Vector2(128, 160), region).entities

func round_trip(doc: Dictionary) -> Dictionary:
	var result := WorldRoomDocument.instantiate(doc)
	if result.has("error"): return result
	var packed := PackedScene.new()
	var status := packed.pack(result.room)
	result.room.free()
	if status != OK: return {"error": "packing failed"}
	return WorldRoomDocument.extract(packed)

func check_scope(source: Dictionary) -> void:
	var db := WorldElementCatalog.catalog()
	# Test a local unit and a local combination of common units without publishing fixture designs.
	var owner: Array = db.mechanism_regions.gear_city.definitions
	for id: String in ["gate.masonry", "assembly.bell_gate"]:
		var fixture_id := "fixture." + id
		var definition: Dictionary = db.definitions[id].duplicate(true)
		definition.id = fixture_id
		db.definitions[fixture_id] = definition
		owner.append(fixture_id)
		check(fixture_id in WorldElementCatalog.mechanism_palette("gear_city").regional, "owner lists " + id)
		check(fixture_id not in WorldElementCatalog.mechanism_palette("thorn_forest").regional, "other area hides " + id)
		var doc := source.duplicate(true)
		doc.root.properties.region_id = "gear_city"
		doc.entities.merge(instance_rows(fixture_id, "local", "gear_city"))
		var saved := round_trip(doc)
		check(not saved.has("error"), "local definition retains its identity through packing " + str(saved.get("error","")))
		if not saved.has("error"):
			for region: String in ["", "thorn_forest"]:
				saved.root.properties.region_id = region
				check(WorldRoomDocument.instantiate(saved).has("error"), "document rejects foreign " + id)
				check(WorldElementCatalog.instantiate_definition(fixture_id, "local", Vector2.ZERO, region).has("error"), "placement rejects foreign " + id)
		owner.erase(fixture_id)
		db.definitions.erase(fixture_id)
	for bad_region: Variant in ["unknown_region", 4, null]:
		var doc := source.duplicate(true)
		doc.root.properties.region_id = bad_region
		check(WorldRoomDocument.instantiate(doc).has("error"), "invalid region " + str(bad_region))
	check(WorldElementCatalog.mechanism_palette("unknown_region").has("error"), "unknown region has no palette")

func check_art(source: Dictionary, region: String, gate_material: String, family: String, explicit_skin := false) -> void:
	var doc := source.duplicate(true)
	if not region.is_empty(): doc.root.properties.region_id = region
	doc.entities.merge(instance_rows("traversal.hook", "hook", region))
	doc.entities.merge(instance_rows("traversal.hook_point", "hanging", region))
	if explicit_skin:
		doc.entities.hook.properties.material_family = family
		doc.entities.gate.properties.appearance = gate_material
	var saved := round_trip(doc)
	if saved.has("error"):
		check(false, str(saved.error))
		return
	check(saved.root.properties.get("region_id", "") == region, "region survives packing")
	check(saved.entities.gate.properties.appearance == (gate_material if explicit_skin else "inherit"), "gate keeps authored skin choice")
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(saved)
	check(error.is_empty(), "round-tripped room opens " + error)
	if error.is_empty():
		var gate: WorldElementGate = session.room.element_runtime.nodes.gate
		var atlas := gate.visual.core_layer.tile_set.get_source(0) as TileSetAtlasSource
		check(atlas.texture.resource_path == TerrainMaterialRegistry.definition(gate_material).atlas, "regional gate atlas " + region)
		check(session.room.terrain_material == "echo_mines", "floor material is independent")
		check(gate.body.collision_layer == 1 and gate.bounds.size == Vector2(32, 128), "gate collision")
		gate.element_restore({"active": true})
		check(gate.body.collision_layer == 0 and not gate.visual.visible, "restored open state")
		var hook_count := 0
		for child: Node in session.room.get_children():
			if child is GrappleAnchor:
				hook_count += 1
				var kind := "hang" if child.hang_enabled else "bounce"
				var expected_family := "rootbound" if explicit_skin and child.hang_enabled else family
				var path := "res://assets/world_traversal/native/%s_%s.png" % [expected_family, kind]
				check(child.artwork.texture.resource_path == path, "anchor artwork " + region + " " + kind)
				check(child.is_in_group(&"grapple_target") and child.collision_layer == 8, "shared anchor targeting")
		check(hook_count == 2, "both authored and fixed hooks present")
		check(await session.audio_service.shutdown(), "audio released")
	session.free()

func run() -> void:
	var source := WorldRoomDocument.read("res://tests/assembly_room.json")
	check_scope(source)
	await check_art(source, "", "mill_masonry", "clockwork")
	await check_art(source, "gear_city", "gear_city", "clockwork")
	await check_art(source, "thorn_forest", "thorn_forest", "rootbound")
	await check_art(source, "thorn_forest", "mill_masonry", "clockwork", true)
	print("MECHANISM LIBRARIES failures=", failures)
	quit(1 if failures else 0)
