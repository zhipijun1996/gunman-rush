extends SceneTree
## Review every implemented map passage against the two independently derived
## world normals. Include receiving segments before their full room is bound.
var catalog := WorldContentCatalog.new()
var documents := {}
var failures := 0
var checked_ends := 0
var global_points := {}

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
		var construction: Dictionary = catalog.lookup("rooms",room_id).row.authoring.construction
		check(FixedWorldProvider.rect(doc.bounds).is_equal_approx(FixedWorldProvider.rect(construction.bounds_world)), room_id+" preserves the surveyed aspect and envelope")
		for opening: Dictionary in construction.doors:
			if not doc.exits.has(opening.id): continue
			var gate: Dictionary = doc.exits[opening.id]
			var p := FixedWorldProvider.point(gate.point)
			var a := FixedWorldProvider.point(opening.opening_world[0])
			var b := FixedWorldProvider.point(opening.opening_world[1])
			var plane := a.x if opening.axis=="v" else a.y
			check(absf((p.x if opening.axis=="v" else p.y)-plane)<.01, room_id+"/"+opening.id+" matches the fixed line")
			var interval := Vector2(a.y,b.y) if opening.axis=="v" else Vector2(a.x,b.x)
			check(FixedWorldProvider.point(gate.span).distance_to(interval)<.01, room_id+"/"+opening.id+" preserves the full surveyed opening")
			var world_at := FixedWorldProvider.point(construction.local_origin_map)*float(construction.scale.x)+p
			if global_points.has(opening.id):
				check(world_at.distance_to(global_points[opening.id])<.01,opening.id+" shares one world-space player crossing point")
			global_points[opening.id]=world_at
		var result := WorldContentRoomBridge.check_passages(doc, catalog, complete)
		check(result.ok, "%s: %s" % [room_id, result])
		for link: Dictionary in catalog.connections(room_id).rows:
			if link.connection_type != "physical": continue
			var expected := catalog.physical_passage(room_id, link.id)
			var exists: bool = doc.get("exits", {}).has(link.id)
			if not documents.has(expected.destination):
				check(not exists and not complete,room_id+" must not open into an unbuilt room "+str(link.id))
				continue
			check(exists and documents.get(expected.destination, {}).get("exits", {}).has(link.id),
				"%s/%s must pair with %s" % [room_id, link.id, expected.destination])
			checked_ends += 1

func counterexamples() -> void:
	var field: Dictionary = documents.P02
	var grass: Dictionary = documents.P16
	check(catalog.physical_passage("P02","d009").direction == Vector2.DOWN and catalog.physical_passage("P16","d009").direction == Vector2.UP, "grass mouth connects the lower P02 edge to the upper P16 edge")
	for doc: Dictionary in [field,grass]:
		var wrong := doc.duplicate(true)
		wrong.exits.d009.direction = [-1,0] if doc.room_id=="P02" else [1,0]
		check(not WorldContentRoomBridge.prepare(wrong,catalog).ok,"reject wrong side "+doc.room_id)
		var rescaled := doc.duplicate(true)
		rescaled.bounds[2]=float(rescaled.bounds[2])*.73
		check(not WorldContentRoomBridge.prepare(rescaled,catalog).ok,"reject compressed room "+doc.room_id)
		var shifted := doc.duplicate(true)
		shifted.exits.d009.span[0] += 20
		check(not WorldContentRoomBridge.prepare(shifted,catalog).ok,"reject moved opening "+doc.room_id)
	var wrong_edge := field.duplicate(true)
	wrong_edge.exits.d009.point[1] -= 70
	check(not WorldContentRoomBridge.prepare(wrong_edge,catalog).ok,"reject door away from its surveyed wall")
	var outside := grass.duplicate(true)
	outside.exits.d009.spawn = outside.exits.d009.point
	check(not WorldContentRoomBridge.prepare(outside,catalog).ok,"reject landing on the threshold")
	var missing := field.duplicate(true)
	missing.exits.erase("d009")
	check(not WorldContentRoomBridge.prepare(missing,catalog).ok,"reject incomplete authored room")

	var inward := grass.duplicate(true)
	inward.exits.d009.direction = [0,1]
	check(not WorldContentRoomBridge.prepare(inward,catalog).ok,"reject the correct axis facing into the room")
	var swapped := field.duplicate(true)
	swapped.exits.d009 = field.exits.d330
	swapped.exits.d330 = field.exits.d009
	check(not WorldContentRoomBridge.prepare(swapped,catalog).ok,"reject exchanging the two shaft entrances")
	var wrong_id := grass.duplicate(true)
	wrong_id.exits = {"d330":grass.exits.d009}
	check(not WorldContentRoomBridge.prepare(wrong_id,catalog).ok,"reject a door belonging to another pair of rooms")
	var invalid_site := field.duplicate(true)
	var observation: Dictionary = invalid_site.sites.discover_p02_low_slope
	observation.other_approaches = [[186]]
	check(not WorldContentRoomBridge.prepare(invalid_site,catalog).ok,"reject a malformed grass approach point")
	observation.erase("other_approaches")
	observation.approach_radius = 0
	check(not WorldContentRoomBridge.prepare(invalid_site,catalog).ok,"require a positive grass observation radius")

func _init() -> void:
	check(catalog.load_locked().ok and catalog.load_bindings("res://config/imported_world/bindings.json").ok,"load locked map and current room bindings")
	if failures == 0:
		collect()
		check(documents.has("P02") and documents.has("P16"), "P02 and its receiving apron are registered")
		check_rooms()
		check(checked_ends==14,"seven real reciprocal mouths")
		if documents.has("P02") and documents.has("P16"): counterexamples()
	print("WORLD ROOM PASSAGES failures=",failures," endpoints=",checked_ends)
	quit(1 if failures else 0)
