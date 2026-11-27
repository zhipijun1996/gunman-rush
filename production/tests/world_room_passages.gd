extends SceneTree
## Review every implemented map passage against the two independently derived
## world normals. Include receiving segments before their full room is bound.
var catalog := WorldContentCatalog.new()
var documents := {}
var failures := 0
var checked_ends := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL ", message)

func collect() -> void:
	for room: Dictionary in catalog.table("rooms").rows:
		if not catalog.binding("rooms",room.id).ok: continue
		var registered := catalog.room_document(room.id)
		check(registered.ok, "registered room document: "+str(room.id))
		if registered.ok: documents[room.id] = WorldRoomDocument.read(registered.path)

func check_rooms() -> void:
	for room_id: String in documents:
		var doc: Dictionary = documents[room_id]
		var binding := catalog.binding("rooms", room_id)
		var complete: bool = binding.ok and binding.row.status == "authored"
		var result := WorldContentRoomBridge.check_passages(doc, catalog, complete)
		check(result.ok, "%s: %s" % [room_id, result])
		for link: Dictionary in catalog.connections(room_id).rows:
			if link.connection_type != "physical": continue
			var expected := catalog.physical_passage(room_id, link.id)
			var exists: bool = doc.get("exits", {}).has(link.id)
			if not documents.has(expected.destination):
				check(exists,room_id+" includes its world boundary "+str(link.id))
				continue
			check(exists and documents.get(expected.destination, {}).get("exits", {}).has(link.id),
				"%s/%s must pair with %s" % [room_id, link.id, expected.destination])
			checked_ends += 1

func counterexamples() -> void:
	var field: Dictionary = documents.P02
	var grass: Dictionary = documents.P16
	check(catalog.physical_passage("P02","d009").direction == Vector2.DOWN and catalog.physical_passage("P16","d009").direction == Vector2.UP, "grass mouth connects the lower P02 edge to the upper P16 edge")
	# Reproduce the former bug. The two local exits still agree with each other.
	for doc: Dictionary in [field, grass]:
		var wrong := doc.duplicate(true)
		wrong.exits.d009.direction = [-1,0] if doc.room_id == "P02" else [1,0]
		check(WorldContentRoomBridge.prepare(wrong, catalog).get("error","").begins_with("content_door_direction_mismatch:"), "reject individually incorrect directions " + str(doc.room_id))
	var invalid_site := field.duplicate(true)
	var observation: Dictionary = invalid_site.sites.discover_p02_low_slope
	observation.other_approaches = [[186]]
	check(WorldContentRoomBridge.prepare(invalid_site, catalog).get("error") == "grass_discovery_approach_invalid:discover_p02_low_slope", "reject malformed second approach to the grass mouth")
	observation.erase("other_approaches")
	observation.approach_radius = 0
	check(WorldContentRoomBridge.prepare(invalid_site, catalog).get("error") == "grass_discovery_approach_invalid:discover_p02_low_slope", "require a positive grass observation radius")
	var wrong_side := grass.duplicate(true)
	wrong_side.exits.d009.direction = [0,1]
	check(not WorldContentRoomBridge.prepare(wrong_side,catalog).ok, "the correct axis still needs the correct outward side")
	var exterior := grass.duplicate(true)
	exterior.exits.d009.spawn = exterior.exits.d009.point
	check(WorldContentRoomBridge.prepare(exterior,catalog).get("error","") == "content_door_landing_outside:P16/d009", "a return anchor must lie inside the mapped entrance")
	var incomplete := field.duplicate(true)
	incomplete.exits.erase("d009")
	check(WorldContentRoomBridge.prepare(incomplete,catalog).get("error","") == "content_door_missing:P02/d009", "reject missing door in fully authored world room")
	var wrong_id := grass.duplicate(true)
	wrong_id.exits = {"d330":grass.exits.d009}
	check(not WorldContentRoomBridge.prepare(wrong_id,catalog).ok, "reject a door belonging to different rooms")
	var reversed := field.duplicate(true)
	reversed.exits.d009 = field.exits.d330
	reversed.exits.d330 = field.exits.d009
	check(WorldContentRoomBridge.prepare(reversed,catalog).get("error","").begins_with("content_door_order_mismatch:"), "two lower doors cannot exchange positions along the wall")

func _init() -> void:
	check(catalog.load_locked().ok and catalog.load_bindings("res://config/imported_world/bindings.json").ok,"load locked map and current room bindings")
	if failures == 0:
		collect()
		check(documents.has("P02") and documents.has("P16"), "pilot and receiving segment found")
		check_rooms()
		if documents.has("P02") and documents.has("P16"): counterexamples()
	print("WORLD ROOM PASSAGES failures=",failures," endpoints=",checked_ends)
	quit(1 if failures else 0)
