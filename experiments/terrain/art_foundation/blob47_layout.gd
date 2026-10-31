class_name Blob47Layout
extends RefCounted
## New, isolated tile-first sample. No legacy geometry or art is sampled.
## Validation proves grid/semantic/port contracts, not actual Motor traversal.

const CELL: int = Blob47Rules.CELL
const VERSION: String = "blob47-layout-v1"
const MODULE_SIZE := Vector2i(20, 25)
const MATERIAL: StringName = &"sandstone"
const MODULE_COUNT: int = 4
const VISUAL_ROLES: Dictionary = {
	"terraced_court": "stepped_court_and_upper_shelf",
	"open_arch": "open_arch_and_cave",
	"sheltered_basin": "sheltered_basin_and_underpass"}


static func generate(seed_text: String) -> Dictionary:
	var pool: Array[Dictionary] = module_catalog()
	for candidate: Dictionary in pool:
		var check: Dictionary = validate_module(candidate)
		if not check.ok:
			return _failed(seed_text, check.errors)
	var rng := RandomNumberGenerator.new()
	rng.seed = ("blob47-layout/gameplay/" + seed_text).hash()
	var chosen: Array[Dictionary] = []
	# Shuffling a complete three-module bag guarantees actual shape variety.
	var bag: Array[int] = [0, 1, 2]
	for index: int in range(bag.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var value: int = bag[index]
		bag[index] = bag[other]
		bag[other] = value
	for index: int in range(MODULE_COUNT):
		chosen.append(pool[bag[index % bag.size()]].duplicate(true))
	var chain: Dictionary = validate_chain(chosen)
	if not chain.ok:
		return _failed(seed_text, chain.errors)
	var cells: Dictionary = {}
	var one_way: Array[Rect2] = []
	var moving: Array[Dictionary] = []
	var hazards: Array[Rect2] = []
	var keepouts: Array[Rect2] = []
	var manifests: Array[Dictionary] = []
	for index: int in range(chosen.size()):
		var module: Dictionary = chosen[index]
		var origin := Vector2i(index * MODULE_SIZE.x, 0)
		for tile: Dictionary in module.tiles:
			var rect: Rect2i = tile.rect
			for y: int in range(rect.position.y, rect.end.y):
				for x: int in range(rect.position.x, rect.end.x):
					cells[origin + Vector2i(x, y)] = tile.material
		for rect: Rect2i in module.one_way:
			one_way.append(_pixels(rect, origin))
		for platform: Dictionary in module.moving:
			moving.append({"rect": _pixels(platform.rect, origin),
				"travel": Vector2(platform.travel) * CELL, "period": platform.period})
		for rect: Rect2i in module.hazards:
			hazards.append(_pixels(rect, origin))
		for rect: Rect2i in module.keepouts:
			keepouts.append(_pixels(rect, origin))
		manifests.append({"id": module.id, "version": module.version,
			"origin": origin, "entry": origin + module.entry,
			"exit": origin + module.exit, "size": module.size,
			"family_ids": module.family_ids.duplicate(), "tile_size": module.tile_size,
			"ports_and_halo": module.ports_and_halo.duplicate(true),
			"density_profile": module.density_profile, "background_profile": module.background_profile,
			"visual_role": module.visual_role, "exceptions": module.exceptions.duplicate(true),
			"tiles": module.tiles.duplicate(true),
			"one_way": module.one_way.duplicate(true),
			"moving": module.moving.duplicate(true),
			"hazards": module.hazards.duplicate(true),
			"keepouts": module.keepouts.duplicate(true)})
	return {"ok": true, "cells": cells, "one_way": one_way,
		"moving": moving, "hazards": hazards, "keepouts": keepouts,
		"spawn": Vector2(2.5, 19.0) * CELL,
		"bounds": Rect2(Vector2.ZERO, Vector2(MODULE_SIZE.x * MODULE_COUNT, MODULE_SIZE.y) * CELL),
		"modules": manifests, "seed": seed_text, "version": VERSION}


static func module_catalog() -> Array[Dictionary]:
	var terrace: Dictionary = _base("terraced_court")
	terrace.tiles.append_array([_solid(4, 19, 7, 1), _solid(5, 18, 5, 1),
		_solid(12, 14, 5, 2)])
	terrace.one_way.append(Rect2i(9, 16, 3, 1))
	terrace.moving.append({"rect": Rect2i(13, 12, 2, 1),
		"travel": Vector2i(2, 0), "period": 4.0})
	terrace.keepouts.append(Rect2i(4, 16, 7, 4))
	var arch: Dictionary = _base("open_arch")
	arch.tiles.append_array([_solid(3, 19, 3, 1), _solid(4, 18, 2, 1),
		_solid(7, 12, 7, 2), _solid(7, 14, 2, 3), _solid(12, 14, 2, 3),
		_solid(15, 17, 3, 1)])
	# A low y16 bridge formerly caught a main-route jump against the y12 roof.
	# Keep this bridge in the optional upper route instead of raising the player
	# into a side wall that a basic short jump cannot clear.
	arch.one_way.append(Rect2i(5, 14, 2, 1))
	arch.hazards.append(Rect2i(11, 11, 1, 1))
	arch.keepouts.append(Rect2i(10, 10, 3, 2))
	var alcove: Dictionary = _base("sheltered_basin")
	# End the step a cell before the underpass, leaving room for the whole
	# body to descend before it meets the floating basin's lower corner.
	alcove.tiles.append_array([_solid(4, 19, 3, 1), _solid(8, 16, 8, 2),
		_solid(8, 14, 2, 2), _solid(14, 14, 2, 2)])
	alcove.one_way.append(Rect2i(5, 14, 3, 1))
	alcove.hazards.append(Rect2i(12, 15, 1, 1))
	alcove.moving.append({"rect": Rect2i(10, 12, 2, 1),
		"travel": Vector2i(2, 0), "period": 5.0})
	alcove.keepouts.append(Rect2i(11, 14, 3, 2))
	return [terrace, arch, alcove]


static func validate_module(module: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if typeof(module.get("id")) != TYPE_STRING or str(module.get("id", "")).is_empty():
		errors.append("missing module id")
	if typeof(module.get("version")) != TYPE_STRING or module.get("version") != VERSION:
		errors.append("unknown module version")
	if typeof(module.get("family_ids")) != TYPE_ARRAY or module.get("family_ids") != [MATERIAL]:
		errors.append("module must declare the known sandstone tile family")
	if typeof(module.get("tile_size")) != TYPE_INT or module.get("tile_size") != CELL:
		errors.append("module tile_size must match Blob47Rules.CELL")
	if typeof(module.get("ports_and_halo")) != TYPE_DICTIONARY:
		errors.append("missing ports_and_halo contract")
	else:
		var halo: Dictionary = module.ports_and_halo
		if typeof(halo.get("halo_cells")) != TYPE_INT or int(halo.get("halo_cells", 0)) < 1:
			errors.append("ports require at least one integer halo cell")
		if halo.get("owner") != "merged_world_cells":
			errors.append("unknown port halo ownership")
	if module.get("density_profile") != "garden-sparse-v1":
		errors.append("unknown decoration density profile")
	if module.get("background_profile") != "garden-depth-v1":
		errors.append("unknown background depth profile")
	if str(module.get("visual_role", "")).is_empty() or module.get("visual_role") != VISUAL_ROLES.get(module.get("id"), ""):
		errors.append("missing or unknown module visual role")
	if typeof(module.get("exceptions")) != TYPE_ARRAY or module.get("exceptions") != []:
		errors.append("unhandled module exceptions")
	if typeof(module.get("size")) != TYPE_VECTOR2I or module.get("size") != MODULE_SIZE:
		errors.append("size must be integer 20 by 25 cells")
	if typeof(module.get("entry")) != TYPE_VECTOR2I or module.get("entry") != Vector2i(0, 20):
		errors.append("entry must be the integer left ground port")
	if typeof(module.get("exit")) != TYPE_VECTOR2I or module.get("exit") != Vector2i(20, 20):
		errors.append("exit must be the integer right ground port")
	for key: String in ["tiles", "one_way", "moving", "hazards", "keepouts"]:
		if typeof(module.get(key)) != TYPE_ARRAY:
			errors.append("missing array: " + key)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	var occupied: Dictionary = {}
	for tile: Variant in module.tiles:
		if typeof(tile) != TYPE_DICTIONARY:
			errors.append("tile must be a semantic dictionary")
			continue
		if tile.get("material") != MATERIAL:
			errors.append("unknown tile material")
		if tile.get("semantic") != &"solid":
			errors.append("unknown tile semantic")
		if not _valid_rect(tile.get("rect")):
			errors.append("tile rect must be positive integer cells inside module")
			continue
		var rect: Rect2i = tile.rect
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				if occupied.has(cell):
					errors.append("overlapping solid tiles")
				occupied[cell] = true
	# Both seam lanes must remain clear and have a solid two-cell landing.
	for x: int in [0, 1, 18, 19]:
		if not occupied.has(Vector2i(x, 20)):
			errors.append("unsupported port")
		for y: int in range(17, 20):
			if occupied.has(Vector2i(x, y)):
				errors.append("blocked port clearance")
	# The sample's protected lower lane has no gaps; only <= two-cell steps.
	var main_floors: Array[int] = []
	for x: int in range(MODULE_SIZE.x):
		if not occupied.has(Vector2i(x, 20)):
			errors.append("missing safe main floor")
		if occupied.has(Vector2i(x, 17)) and occupied.has(Vector2i(x, 18)):
			errors.append("main route wall exceeds two-cell step contract")
		var floor_y: int = 20
		while floor_y > 18 and occupied.has(Vector2i(x, floor_y - 1)):
			floor_y -= 1
		main_floors.append(floor_y)
		for y: int in range(floor_y - 2, floor_y):
			if occupied.has(Vector2i(x, y)):
				errors.append("main route lacks two-cell body clearance")
	# A downward step must not deliver the body directly into a low ceiling.
	# Test both directions so the player can retreat as well as advance.
	for x: int in range(MODULE_SIZE.x):
		for neighbor: int in [x - 1, x + 1]:
			if neighbor < 0 or neighbor >= MODULE_SIZE.x or main_floors[neighbor] <= main_floors[x]:
				continue
			for y: int in range(main_floors[x] - 2, main_floors[x]):
				if occupied.has(Vector2i(neighbor, y)):
					errors.append("downward step pinches main body against adjacent ceiling")
	var objects: Array[Rect2i] = []
	for key: String in ["one_way", "hazards"]:
		for value: Variant in module[key]:
			if not _valid_rect(value):
				errors.append(key + " must use positive integer cell rects")
				continue
			var rect: Rect2i = value
			if rect.size.y != 1:
				errors.append(key + " must be one cell thick")
			if key == "hazards" and rect.end.y > 18:
				errors.append("hazard enters protected main route")
			if key == "one_way" and rect.position.y >= 16:
				# A low one-way can catch the jump over a ground step. Never
				# deliver that landing directly into an unjumpable upper wall.
				var wall_top: int = rect.position.y
				if occupied.has(Vector2i(rect.end.x, rect.position.y)):
					while occupied.has(Vector2i(rect.end.x, wall_top - 1)):
						wall_top -= 1
					if rect.position.y - wall_top > 2:
						errors.append("low one-way delivers main route into a wall over two cells high")
			_check_object(rect, occupied, objects, errors)
			objects.append(rect)
	for value: Variant in module.moving:
		if typeof(value) != TYPE_DICTIONARY:
			errors.append("moving platform must be a dictionary")
			continue
		if not _valid_rect(value.get("rect")) or typeof(value.get("travel")) != TYPE_VECTOR2I:
			errors.append("moving platform needs integer rect and travel")
			continue
		if typeof(value.get("period")) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value.get("period", 0.0))) or float(value.get("period", 0.0)) <= 0.0:
			errors.append("moving period must be positive")
			continue
		var rect: Rect2i = value.rect
		var travel: Vector2i = value.travel
		if travel == Vector2i.ZERO or (travel.x != 0 and travel.y != 0):
			errors.append("sample supports one-axis nonzero moving travel")
			continue
		var sweep: Rect2i = rect.merge(Rect2i(rect.position + travel, rect.size))
		if not _valid_rect(sweep) or sweep.end.y > 16:
			errors.append("moving sweep leaves optional upper lane")
			continue
		_check_object(sweep, occupied, objects, errors)
		objects.append(sweep)
	for value: Variant in module.keepouts:
		if not _valid_rect(value):
			errors.append("keepout must be a positive integer cell rect")
	return {"ok": errors.is_empty(), "errors": errors}


static func validate_chain(modules: Array, origins: Array = []) -> Dictionary:
	var errors: Array[String] = []
	if modules.is_empty() or modules.size() > MODULE_COUNT:
		errors.append("chain must contain one to four bounded modules")
		return {"ok": false, "errors": errors}
	if not origins.is_empty() and origins.size() != modules.size():
		errors.append("origin count differs from module count")
		return {"ok": false, "errors": errors}
	var previous_exit := Vector2i.ZERO
	var occupied_bounds: Array[Rect2i] = []
	for index: int in range(modules.size()):
		if typeof(modules[index]) != TYPE_DICTIONARY:
			errors.append("module must be a dictionary")
			continue
		var module: Dictionary = modules[index]
		var check: Dictionary = validate_module(module)
		if not check.ok:
			errors.append_array(check.errors)
			continue
		var value: Variant = Vector2i(index * MODULE_SIZE.x, 0) if origins.is_empty() else origins[index]
		if typeof(value) != TYPE_VECTOR2I:
			errors.append("module origin must be integer grid coordinates")
			continue
		var origin: Vector2i = value
		if index > 0 and origin + module.entry != previous_exit:
			errors.append("module ports do not coincide")
		previous_exit = origin + module.exit
		var bounds := Rect2i(origin, module.size)
		for existing: Rect2i in occupied_bounds:
			if bounds.intersects(existing):
				errors.append("overlapping module bounds")
		occupied_bounds.append(bounds)
	return {"ok": errors.is_empty(), "errors": errors}


static func _base(id: String) -> Dictionary:
	return {"id": id, "version": VERSION, "size": MODULE_SIZE,
		"family_ids": [MATERIAL], "tile_size": CELL,
		"ports_and_halo": {"halo_cells": 1, "owner": "merged_world_cells"},
		"density_profile": "garden-sparse-v1", "background_profile": "garden-depth-v1",
		"visual_role": VISUAL_ROLES[id], "exceptions": [],
		"entry": Vector2i(0, 20), "exit": Vector2i(20, 20),
		"tiles": [_solid(0, 20, 20, 5)], "one_way": [], "moving": [],
		"hazards": [], "keepouts": [Rect2i(0, 17, 3, 3), Rect2i(17, 17, 3, 3)]}


static func _solid(x: int, y: int, width: int, height: int) -> Dictionary:
	return {"rect": Rect2i(x, y, width, height), "material": MATERIAL, "semantic": &"solid"}


static func _valid_rect(value: Variant) -> bool:
	if typeof(value) != TYPE_RECT2I:
		return false
	var rect: Rect2i = value
	return rect.size.x > 0 and rect.size.y > 0 and Rect2i(Vector2i.ZERO, MODULE_SIZE).encloses(rect)


static func _check_object(rect: Rect2i, occupied: Dictionary, objects: Array[Rect2i], errors: Array[String]) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if occupied.has(Vector2i(x, y)):
				errors.append("object overlaps solid tile")
	for existing: Rect2i in objects:
		if rect.intersects(existing):
			errors.append("overlapping object or moving sweep")


static func _pixels(rect: Rect2i, origin: Vector2i) -> Rect2:
	return Rect2(Vector2(rect.position + origin) * CELL, Vector2(rect.size) * CELL)


static func _failed(seed_text: String, errors: Array) -> Dictionary:
	return {"ok": false, "cells": {}, "one_way": [], "moving": [],
		"hazards": [], "keepouts": [], "spawn": Vector2.ZERO,
		"bounds": Rect2(), "modules": [], "seed": seed_text,
		"version": VERSION, "errors": errors}
