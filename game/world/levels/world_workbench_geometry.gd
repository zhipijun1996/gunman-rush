class_name WorldWorkbenchGeometry
extends RefCounted
## Preview adapter for existing construction geometry, not a second gate compiler.
## Existing identities/qualifications stay in the compiled contract.
static func apply(source: Dictionary, draft: Dictionary) -> Dictionary:
	if not WorldRoomDraft.rectangle(draft.get("bounds")) or not draft.get("space_rects") is Array:
		return {"error":"geometry_shape_invalid"}
	var extent := FixedWorldProvider.rect(draft.bounds)
	if extent.position != Vector2.ZERO: return {"error":"geometry_origin_must_be_zero"}
	var spaces: Array[Rect2] = []
	var actual := Rect2()
	if draft.space_rects.is_empty() or draft.space_rects.size() > 128: return {"error":"geometry_chamber_count"}
	for raw: Variant in draft.space_rects:
		if not WorldRoomDraft.rectangle(raw): return {"error":"geometry_chamber_invalid"}
		var rect := FixedWorldProvider.rect(raw)
		actual = rect if spaces.is_empty() else actual.merge(rect)
		spaces.append(rect)
	if not actual.is_equal_approx(extent): return {"error":"geometry_extent_mismatch"}
	var plan := PixelFormalTerrain.geometry_plan(spaces)
	var links: Dictionary = {}
	for edge: Vector4 in plan.edges:
		var a := Vector2(edge.x, edge.y)
		if links.has(a): return {"error":"geometry_corner_only_connection"}
		links[a] = Vector2(edge.z, edge.w)
	if links.is_empty(): return {"error":"geometry_empty"}
	var first: Vector2 = links.keys()[0]
	for vertex: Vector2 in links:
		if vertex.y < first.y or (vertex.y == first.y and vertex.x < first.x): first = vertex
	var cursor := first
	var outline: Array = []
	var boundary: Array = []
	while links.has(cursor):
		var next: Vector2 = links[cursor]
		outline.append([cursor.x, cursor.y])
		var side := ("up" if next.x > cursor.x else "down") if is_equal_approx(cursor.y, next.y) else ("right" if next.y > cursor.y else "left")
		boundary.append({"side":side, "from":[cursor.x,cursor.y], "to":[next.x,next.y]})
		links.erase(cursor)
		cursor = next
		if cursor == first: break
	if not links.is_empty() or cursor != first: return {"error":"geometry_disconnected_or_enclosed_hole"}
	var row := source.duplicate(true)
	row.world_geometry.bounds_world_units = draft.bounds.duplicate()
	row.world_geometry.space_rects = draft.space_rects.duplicate(true)
	row.world_geometry.boundary = boundary
	row.world_geometry.outline_candidate_local = outline
	var originals: Dictionary = {}
	for door: Dictionary in source.doors: originals[str(door.id)] = door
	var changed: Dictionary = {}
	if draft.has("doors"):
		if not draft.doors is Array or draft.doors.size() != originals.size(): return {"error":"door_topology_requires_compiled_runtime"}
		row.doors = []
		for candidate: Variant in draft.doors:
			if not candidate is Dictionary or not originals.has(str(candidate.get("id", ""))): return {"error":"door_identity_unknown"}
			var id := str(candidate.id)
			if changed.has(id): return {"error":"door_identity_duplicate"}
			var original: Dictionary = originals[id]
			for key: String in ["room_id", "target_room", "target_door_id", "direction", "requires", "outbound_allowed"]:
				if JSON.stringify(candidate.get(key), "", true) != JSON.stringify(original.get(key), "", true): return {"error":"door_rule_change_requires_compiled_runtime:"+key}
			if not candidate.get("position_candidate") is Dictionary or not WorldRoomDraft.vector(candidate.position_candidate.get("local_world_units")): return {"error":"door_position_invalid"}
			if not candidate.get("landing_contract") is Dictionary: return {"error":"door_landing_missing"}
			for key: String in ["safe_standing_position_world_units", "entry_position_world_units"]:
				if not WorldRoomDraft.vector(candidate.landing_contract.get(key)): return {"error":"door_landing_invalid:"+key}
			var door := original.duplicate(true)
			door.position_candidate = candidate.position_candidate.duplicate(true)
			door.landing_contract = candidate.landing_contract.duplicate(true)
			row.doors.append(door)
			changed[id] = door
	for door: Dictionary in row.doors:
		if not on_boundary(boundary, door): return {"error":"door_aperture_off_boundary:"+str(door.id)}
	for spawn: Dictionary in row.entry_spawns:
		var door_id := str(spawn.entry_door)
		if not changed.has(door_id): continue
		var landing: Dictionary = changed[door_id].landing_contract
		spawn.position_candidate_world_units = landing.entry_position_world_units.duplicate()
		spawn.eventual_standing_position_world_units = landing.safe_standing_position_world_units.duplicate()
	for anchor: Dictionary in row.get("terrain_failure", {}).get("challenge_entries", []):
		if changed.has(str(anchor.approach_door)):
			anchor.position_candidate_world_units = changed[str(anchor.approach_door)].landing_contract.safe_standing_position_world_units.duplicate()
	for reserved: Dictionary in row.world_geometry.get("required_reserved_areas", []):
		var id := str(reserved.get("door_ref", ""))
		if not changed.has(id): continue
		var delta := FixedWorldProvider.point(changed[id].position_candidate.local_world_units)-FixedWorldProvider.point(originals[id].position_candidate.local_world_units)
		reserved.rect_world_units[0] += delta.x
		reserved.rect_world_units[1] += delta.y
	return {"room":row}

static func on_boundary(boundary: Array, door: Dictionary) -> bool:
	var point := FixedWorldProvider.point(door.position_candidate.local_world_units)
	var horizontal: bool = str(door.direction) in ["up", "down"]
	var aperture := Vector2(point.x-64, point.x+64) if horizontal else Vector2(point.y-96, point.y)
	for edge: Dictionary in boundary:
		if edge.side != door.direction: continue
		var a := FixedWorldProvider.point(edge.from)
		var b := FixedWorldProvider.point(edge.to)
		if not is_equal_approx(point.y if horizontal else point.x, a.y if horizontal else a.x): continue
		var span := Vector2(minf(a.x,b.x), maxf(a.x,b.x)) if horizontal else Vector2(minf(a.y,b.y), maxf(a.y,b.y))
		if aperture.x >= span.x and aperture.y <= span.y: return true
	return false

static func refresh_map(bundle: Dictionary) -> String:
	var rooms: Dictionary = bundle.rooms
	var start := str(bundle.start.room)
	if not rooms.has(start): return "map_start_missing"
	var origins: Dictionary = {start:Vector2.ZERO}
	var pending: Array[String] = [start]
	var opposite := {"up":"down", "down":"up", "left":"right", "right":"left"}
	while not pending.is_empty():
		var id: String = pending.pop_back()
		for door: Dictionary in rooms[id].doors:
			var target := str(door.target_room)
			if not rooms.has(target): continue
			var paired: Dictionary = {}
			for candidate: Dictionary in rooms[target].doors:
				if candidate.id == door.target_door_id: paired = candidate;break
			if paired.is_empty() or paired.target_room != id or paired.target_door_id != door.id: return "map_door_pair_invalid"
			if opposite.get(str(door.direction), "") != str(paired.direction): return "map_door_directions_invalid"
			var proposed: Vector2 = origins[id]+FixedWorldProvider.point(door.position_candidate.local_world_units)-FixedWorldProvider.point(paired.position_candidate.local_world_units)
			if origins.has(target):
				if not (origins[target] as Vector2).is_equal_approx(proposed): return "map_seam_conflict:"+str(door.id)
			else:
				origins[target] = proposed
				pending.append(target)
	if origins.size() != rooms.size(): return "map_disconnected"
	var placed: Array[Dictionary] = []
	for id: String in rooms:
		for raw: Array in rooms[id].world_geometry.space_rects:
			var rect := FixedWorldProvider.rect(raw)
			rect.position += origins[id]
			for previous: Dictionary in placed:
				if previous.id != id and (previous.rect as Rect2).intersects(rect): return "map_room_overlap:"+id+"/"+str(previous.id)
			placed.append({"id":id, "rect":rect})
	for row: Dictionary in bundle.get("map_rooms", []):
		if not origins.has(str(row.id)): continue
		var origin: Vector2 = origins[str(row.id)]
		row.origin = [origin.x, origin.y]
		row.polygon = []
		for point: Array in rooms[str(row.id)].world_geometry.outline_candidate_local:
			row.polygon.append([float(point[0])+origin.x, float(point[1])+origin.y])
		var first_chamber := FixedWorldProvider.rect(rooms[str(row.id)].world_geometry.space_rects[0])
		var center := origin+first_chamber.get_center()
		row.map_centre = [center.x, center.y]
	return ""
