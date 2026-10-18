class_name ForestSceneLanguage
extends RefCounted
## Semantic presentation of real support rectangles. Never creates physics or RNG.
const VERSION := 1
const KINDS := ["root_earth", "living_bough", "hollow_bark", "fallen_log", "canopy_perch"]
const STRUCTURE_KINDS := ["hollow_tree", "fallen_trunk", "bough_relay", "river_boughs", "canopy_arch", "root_hollow", "rootland", "root_group", "bough_group"]

static func annotate(m: Dictionary, overrides: Dictionary = {}) -> void:
	var owners: Dictionary = {}
	var structures: Array[Dictionary] = []
	for instance: Dictionary in m.get("geometry_instances", []):
		var sid := str(instance.id)
		for original: Variant in instance.get("platform_id_map", {}):
			owners[str(instance.platform_id_map[original])] = sid
		var voids: Array = []
		var geometry: Dictionary = instance.get("local_geometry", {})
		var translation: Array = instance.get("translation", [0.0, 0.0])
		for window: Dictionary in geometry.get("windows", []):
			var local: Array = window.get("clear_rect", [])
			if local.size() == 4:
				voids.append([float(local[0])+float(translation[0]), float(local[1])+float(translation[1]), local[2], local[3]])
		structures.append({"id":sid,"kind":str(m.get("scene_structure_kinds",{}).get(sid,"hollow_tree" if not voids.is_empty() else "bough_group")),"member_support_ids":[],"open_voids":voids})
	var groups: Dictionary = {}
	for row: Dictionary in m.get("platforms", []):
		var rect := _rect(row.rect)
		var chosen: Dictionary = overrides.get(str(row.id), {})
		# Explicit row semantics win; geometric fallback keeps new structures usable
		# without guessing their names or treating every solid as a tree wall.
		var fallback := "living_bough" if bool(row.one_way) else ("hollow_bark" if rect.size.y > 80.0 else "root_earth")
		row.scene_kind = str(chosen.get("scene_kind", row.get("scene_kind", fallback)))
		row.structure_id = str(chosen.get("structure_id", row.get("structure_id", owners.get(str(row.id), "forest_roots" if row.scene_kind == "root_earth" else "forest_boughs"))))
		row.surface_role = str(chosen.get("surface_role", row.get("surface_role", "bough_top" if bool(row.one_way) else ("inner_bark" if row.scene_kind == "hollow_bark" else "root_top"))))
		if not groups.has(row.structure_id): groups[row.structure_id] = []
		groups[row.structure_id].append(str(row.id))
	for structure: Dictionary in structures:
		structure.member_support_ids = groups.get(structure.id, [])
		groups.erase(structure.id)
	for sid: Variant in groups:
		structures.append({"id":str(sid),"kind":str(m.get("scene_structure_kinds",{}).get(str(sid),"bough_group")),"member_support_ids":groups[sid],"open_voids":[]})
	var presentations: Array = m.get("danger_presentations", []).duplicate(true)
	while presentations.size() < m.get("dangers", []).size(): presentations.append({})
	for i: int in m.get("dangers", []).size():
		var hazard := _rect(m.dangers[i])
		var nearest: Dictionary = {}
		var distance := INF
		for row: Dictionary in m.platforms:
			if bool(row.one_way): continue
			var support := _rect(row.rect)
			var point := Vector2(clampf(hazard.get_center().x,support.position.x,support.end.x),clampf(hazard.get_center().y,support.position.y,support.end.y))
			var candidate := point.distance_squared_to(hazard.get_center())
			if candidate < distance: nearest = row; distance = candidate
		var display: Dictionary = presentations[i]
		display.scene_kind = "thorn_growth"
		display.host_structure_id = str(nearest.get("structure_id", "free_thorn"))
		display.host_support_id = str(nearest.get("id", ""))
		if not display.has("facing"):
			display.facing = "down" if not nearest.is_empty() and _rect(nearest.rect).get_center().y < hazard.get_center().y else "up"
	m.danger_presentations = presentations
	m.scene_structures = structures
	m.scene_language_version = VERSION

static func validate(m: Dictionary) -> bool:
	if m.get("scene_language_version") != VERSION: return false
	if not m.get("scene_structures") is Array: return false
	var membership: Dictionary = {}
	for structure: Variant in m.scene_structures:
		if not structure is Dictionary or not structure.get("id") is String or structure.id.is_empty() or membership.has(structure.id): return false
		if structure.get("kind") not in STRUCTURE_KINDS: return false
		if not structure.get("member_support_ids") is Array or not structure.get("open_voids") is Array: return false
		var ids: Dictionary = {}
		for id: Variant in structure.member_support_ids:
			if not id is String or id.is_empty() or ids.has(id): return false
			ids[id] = true
		membership[structure.id] = ids
		for value: Variant in structure.open_voids:
			if not _valid_rect(value): return false
	var seen: Dictionary = {}
	for row: Dictionary in m.get("platforms", []):
		if row.get("scene_kind") not in KINDS or not row.get("structure_id") is String or not row.get("surface_role") is String or row.surface_role.is_empty(): return false
		if not membership.has(row.structure_id) or not membership[row.structure_id].has(str(row.id)): return false
		if bool(row.one_way) and row.scene_kind in ["root_earth", "hollow_bark"]: return false
		seen[str(row.id)] = true
	for sid: Variant in membership:
		for id: Variant in membership[sid]:
			if not seen.has(id): return false
	var displays: Variant = m.get("danger_presentations")
	if not displays is Array or displays.size() != m.get("dangers", []).size(): return false
	for display: Variant in displays:
		if not display is Dictionary or display.get("scene_kind") != "thorn_growth" or display.get("facing") not in ["up", "down"]: return false
		if not display.get("host_structure_id") is String or not display.get("host_support_id") is String: return false
	return true

static func _valid_rect(value: Variant) -> bool:
	if not value is Array or value.size() != 4: return false
	for number: Variant in value:
		if not (number is int or number is float) or not is_finite(float(number)): return false
	return float(value[2]) > 0 and float(value[3]) > 0

static func draw_structure_backdrops(canvas: Node2D, m: Dictionary) -> void:
	# Only known clear cavities receive a low-contrast interior. No rectangle
	# around an entire structure: that would imply walls across real exits.
	for structure: Dictionary in m.get("scene_structures", []):
		for clear: Array in structure.get("open_voids", []):
			canvas.draw_rect(_rect(clear), Color("102622"))

static func draw_surface(canvas: Node2D, row: Dictionary) -> void:
	var rect := _rect(row.rect)
	var kind := str(row.scene_kind)
	var one_way := bool(row.one_way)
	var wood := kind in ["living_bough", "canopy_perch", "fallen_log"]
	canvas.draw_rect(rect, Color("65513c") if wood else Color("3d4230") if kind == "root_earth" else Color("4a4034"))
	if kind == "root_earth":
		# Horizontal soil beds contrast with vertical bark; all strokes stay
		# inside real support bounds, never invent a solid under a one-way top.
		for layer: int in range(1, int(rect.size.y/11.0)):
			var y := rect.position.y+layer*11.0
			canvas.draw_line(Vector2(rect.position.x+3,y),Vector2(rect.end.x-3,y),Color("303a2b"),2.0,true)
		for i: int in range(1, int(rect.size.x/95.0)):
			var x := rect.position.x+i*95.0
			canvas.draw_line(Vector2(x,rect.position.y+5),Vector2(x+minf(24,rect.end.x-x),rect.end.y-2),Color("596045"),2.0,true)
	elif kind == "hollow_bark":
		for i: int in range(1, int(rect.size.x/25.0)):
			var x := rect.position.x+i*25.0
			var points := PackedVector2Array([Vector2(x,rect.position.y+2),Vector2(x-5,rect.position.y+rect.size.y*.34),Vector2(x+4,rect.position.y+rect.size.y*.68),Vector2(x,rect.end.y-2)])
			canvas.draw_polyline(points,Color("322e29"),3.0,true)
		canvas.draw_rect(rect.grow(-2),Color("827056"),false,2.0)
	else:
		# Longitudinal grain, cut end and downward forks make a branch a
		# branch without adding a false collision wall below its thin top.
		var middle := rect.position.y+rect.size.y*.56
		canvas.draw_line(Vector2(rect.position.x+3,middle),Vector2(rect.end.x-3,middle),Color("3c352a"),2.0,true)
		var radius := minf(7,rect.size.y*.32)
		if rect.size.x > radius*4:
			canvas.draw_arc(Vector2(rect.end.x-radius-2,middle),radius,-PI*.5,PI*.5,10,Color("aa8d62"),2.0,true)
		for i: int in range(1,int(rect.size.x/80.0)):
			var x := rect.position.x+i*80.0
			canvas.draw_line(Vector2(x,middle),Vector2(x+12,rect.end.y-2),Color("99815b"),2.0,true)
		if kind == "canopy_perch":
			for i: int in range(1,int(rect.size.x/45.0)):
				var x := rect.position.x+i*45.0
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(x-10,rect.end.y-2),Vector2(x,rect.position.y+4),Vector2(x+12,rect.end.y-2)]),Color("69754a"))
	# Full top marks actual support; side/bottom outlines are restricted to
	# the existing rectangle. Danger envelopes are drawn afterwards.
	canvas.draw_line(rect.position,Vector2(rect.end.x,rect.position.y),Color("c9cd89"),3.0,true)
	canvas.draw_line(Vector2(rect.position.x,rect.end.y),rect.end,Color("293629"),2.0,true)
	if not one_way and kind == "fallen_log":
		canvas.draw_rect(rect.grow(-3),Color("aa8d62"),false,1.0)

static func _rect(value: Array) -> Rect2:
	return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))
