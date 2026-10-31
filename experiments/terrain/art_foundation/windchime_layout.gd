class_name WindchimeLayout
extends RefCounted
## Hand-composed MAP-01 consumer. This is not a replacement random generator.
## Every stone silhouette, including the arch intrados, is actual tile occupancy.

const CELL: int = Blob47Rules.CELL
const SIZE := Vector2i(80, 28)
const MATERIAL: StringName = &"windchime_stone"
const VERSION := "windchime-map01-v1"


static func build_map(seed_text: String = "windchime-01") -> Dictionary:
	var cells: Dictionary = {}
	# Entry: a substantial ruin deck, quiet enough to learn the silhouette.
	_fill(cells, Rect2i(0, 18, 14, 6))
	_fill(cells, Rect2i(0, 24, 11, 2))
	_fill(cells, Rect2i(0, 26, 7, 2))
	_fill(cells, Rect2i(6, 17, 3, 1))
	# A two-cell sky gap introduces commitment; the next broad landing is visible.
	_fill(cells, Rect2i(16, 19, 13, 5))
	_fill(cells, Rect2i(17, 24, 10, 2))
	_fill(cells, Rect2i(19, 26, 6, 2))
	_fill(cells, Rect2i(20, 18, 2, 1))
	# One architectural focal point: broad deck, two piers and stepped soffit.
	# This opening is empty in the collision map, not a painted black arch.
	_fill(cells, Rect2i(29, 19, 18, 3))
	_fill(cells, Rect2i(29, 22, 3, 6))
	_fill(cells, Rect2i(44, 22, 3, 6))
	_fill(cells, Rect2i(32, 22, 2, 2))
	_fill(cells, Rect2i(42, 22, 2, 2))
	_fill(cells, Rect2i(34, 22, 1, 1))
	_fill(cells, Rect2i(41, 22, 1, 1))
	# Optional climb begins at the low terrace; it can always drop to the court.
	_fill(cells, Rect2i(24, 16, 3, 1))
	_fill(cells, Rect2i(28, 14, 3, 2))
	_fill(cells, Rect2i(33, 14, 5, 2))
	_fill(cells, Rect2i(34, 16, 3, 1))
	_fill(cells, Rect2i(45, 16, 3, 1))
	# Wood bridge then a second short gap; rests are wider than either action.
	_fill(cells, Rect2i(47, 20, 2, 5))
	_fill(cells, Rect2i(54, 19, 10, 5))
	_fill(cells, Rect2i(55, 24, 8, 2))
	_fill(cells, Rect2i(57, 26, 4, 2))
	_fill(cells, Rect2i(60, 18, 2, 1))
	_fill(cells, Rect2i(66, 19, 14, 5))
	_fill(cells, Rect2i(67, 24, 13, 2))
	_fill(cells, Rect2i(70, 26, 10, 2))
	# A high end wall frames the clearing without blocking the return route.
	_fill(cells, Rect2i(78, 14, 2, 5))
	var one_way: Array[Rect2] = [_rect(49, 20, 5, 1)]
	var moving: Array[Dictionary] = [{"rect": Rect2(38 * CELL, 15 * CELL, 3 * CELL, 16),
		"travel": Vector2(3 * CELL, 0), "period": 4.8}]
	var keepouts: Array[Rect2] = [
		_rect(0, 15, 5, 4), _rect(12, 15, 6, 5),
		_rect(21, 15, 4, 5), _rect(26, 12, 3, 5),
		_rect(30, 11, 4, 5), _rect(37, 12, 9, 5),
		_rect(46, 17, 9, 4), _rect(62, 16, 6, 4),
		_rect(75, 16, 4, 4)]
	var sockets: Array[Dictionary] = [
		{"kind": &"entry_chime", "position": Vector2(4.5, 18) * CELL},
		{"kind": &"hero_landmark", "position": Vector2(35.5, 14) * CELL,
			"support": _rect(33, 14, 5, 2), "visual_role": &"brass_windchime_and_banner"},
		{"kind": &"enemy", "position": Vector2(40, 19) * CELL,
			"patrol": Vector2(38 * CELL, 43 * CELL), "optional": true},
		{"kind": &"enemy", "position": Vector2(57.5, 19) * CELL,
			"patrol": Vector2(55.5 * CELL, 59 * CELL), "optional": true},
		{"kind": &"reward", "position": Vector2(35.5, 14) * CELL,
			"optional": true, "sample_only": true},
		{"kind": &"endpoint", "position": Vector2(76, 19) * CELL}]
	var route: Array[Vector2] = [Vector2(80, 558), Vector2(384, 558),
		Vector2(560, 590), Vector2(928, 590), Vector2(1472, 590),
		Vector2(1760, 590), Vector2(1984, 590), Vector2(2240, 590), Vector2(2432, 590)]
	var reverse := route.duplicate()
	reverse.reverse()
	var upper: Array[Vector2] = [Vector2(672, 558), Vector2(800, 494),
		Vector2(944, 430), Vector2(1104, 430), Vector2(1488, 494), Vector2(1536, 622)]
	return {"ok": true, "cells": cells, "one_way": one_way, "moving": moving,
		"hazards": [], "keepouts": keepouts, "spawn": route[0],
		"bounds": Rect2(Vector2.ZERO, Vector2(SIZE * CELL)),
		"modules": _cards(), "seed": seed_text, "version": VERSION,
		"sockets": sockets, "landmarks": [sockets[1]], "route": route,
		"routes": {"main_forward": route, "main_return": reverse, "upper_reward": upper},
		"production_pool": false, "layout_kind": "handmade_golden_sample"}


static func build_material_fixture() -> Dictionary:
	var cells: Dictionary = {}
	_fill(cells, Rect2i(0, 20, 40, 4))
	_fill(cells, Rect2i(2, 16, 12, 1))
	_fill(cells, Rect2i(16, 16, 10, 2))
	_fill(cells, Rect2i(29, 14, 8, 4))
	for y: int in range(15, 17):
		for x: int in range(31, 35): cells.erase(Vector2i(x, y))
	_fill(cells, Rect2i(2, 8, 1, 5))
	_fill(cells, Rect2i(4, 10, 1, 1))
	_fill(cells, Rect2i(7, 10, 2, 1))
	_fill(cells, Rect2i(10, 9, 2, 3))
	_fill(cells, Rect2i(12, 11, 2, 1))
	_fill(cells, Rect2i(17, 9, 5, 1))
	_fill(cells, Rect2i(19, 10, 1, 3))
	return {"ok": true, "cells": cells, "one_way": [_rect(23, 12, 4, 1)],
		"moving": [{"rect": _rect(28, 9, 2, 1), "travel": Vector2(64, 0), "period": 4.8}],
		"hazards": [], "keepouts": [_rect(0, 17, 5, 4)],
		"spawn": Vector2(80, 622), "bounds": _rect(0, 0, 40, 24),
		"modules": [], "seed": "windchime-material-00", "version": "windchime-map00-v1",
		"sockets": [], "landmarks": [], "production_pool": false}


static func material_map(seed_text: String = "windchime-material-00") -> Dictionary:
	var fixture := build_material_fixture()
	fixture.seed = seed_text
	return fixture


static func _cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rows: Array[Array] = [
		["entry_observation", 0, 14, "learn_stone_silhouette"],
		["short_sky_gap", 14, 6, "read_next_broad_landing"],
		["optional_climb", 20, 9, "short_jump_branch_with_safe_drop"],
		["arch_court", 29, 9, "single_architectural_focal_point"],
		["copper_crossing", 38, 11, "observe_optional_carrier_from_safe_court"],
		["wood_bridge", 49, 5, "thin_pass_through_material"],
		["landing_encounter", 54, 12, "rest_then_short_jump"],
		["return_clearing", 66, 14, "endpoint_and_readable_return"]]
	for row: Array in rows:
		result.append({"id": row[0], "version": VERSION,
			"origin": Vector2i(row[1], 0), "size": Vector2i(row[2], SIZE.y),
			"family_ids": [MATERIAL], "tile_family_ids": [MATERIAL], "tile_size": CELL,
			"ports_and_halo": {"halo_cells": 1, "owner": "merged_world_cells"},
			"required_abilities": [], "required_weapon": "single_starting_weapon",
			"resource_contract": "no_required_shots_or_hit_refills",
			"density_profile": "windchime-sparse-v1", "background_profile": "windchime-sky-v1",
			"visual_role": row[3], "exceptions": [], "production_pool": false})
	return result


static func _fill(cells: Dictionary, rect: Rect2i) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			cells[Vector2i(x, y)] = MATERIAL


static func _rect(x: int, y: int, width: int, height: int) -> Rect2:
	return Rect2(Vector2(x, y) * CELL, Vector2(width, height) * CELL)
