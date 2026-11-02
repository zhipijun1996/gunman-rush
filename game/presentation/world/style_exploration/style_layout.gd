class_name StyleLayout
extends RefCounted
## One geometry contract across all five art candidates. Decoration owns no cells.
const VERSION := "windchime-comparison-layout-v2"
const CELL := 32
const SIZE := Vector2i(80, 23)
const SEEDS := [0, 101, 307, 911]
const FAMILY: StringName = &"windchime_solid"

static func generate(sample_seed: int = 0) -> Dictionary:
	var order: Array[int] = [0, 1, 2, 3]
	var rng := RandomNumberGenerator.new()
	rng.seed = ("style-lab/geometry/v1/" + str(sample_seed)).sha256_text().substr(0, 15).hex_to_int()
	if sample_seed != 0:
		for i: int in range(3, 0, -1):
			var other := rng.randi_range(0, i)
			var saved := order[i]
			order[i] = order[other]
			order[other] = saved
	var cells: Dictionary = {}
	var one_way: Array[Rect2] = []
	var modules: Array[Dictionary] = []
	var keepouts: Array[Rect2] = []
	for module_index: int in 4:
		var origin := module_index * 20
		var kind := order[module_index]
		# Three-cell ravines expose cliff sides; thin bridges are genuinely one-way.
		for x: int in range(origin, origin + 20):
			if x - origin in [13, 14, 15]: continue
			_fill(cells, Rect2i(x, 19, 1, 4))
		one_way.append(Rect2(Vector2(origin + 13, 19) * CELL, Vector2(3 * CELL, 8)))
		keepouts.append(Rect2(Vector2(origin + 12, 16) * CELL, Vector2(5, 3) * CELL))
		match kind:
			0: # Rising meadow and a high overlook.
				_fill(cells, Rect2i(origin + 4, 18, 6, 1))
				_fill(cells, Rect2i(origin + 5, 17, 4, 1))
				_fill(cells, Rect2i(origin + 7, 12, 5, 2))
				one_way.append(Rect2(Vector2(origin + 2, 15) * CELL, Vector2(3 * CELL, 8)))
			1: # Broad elevated arch: open air under the roof, no main-route pinch.
				_fill(cells, Rect2i(origin + 3, 10, 9, 2))
				_fill(cells, Rect2i(origin + 3, 12, 2, 2))
				_fill(cells, Rect2i(origin + 10, 12, 2, 2))
				_fill(cells, Rect2i(origin + 6, 18, 4, 1))
				one_way.append(Rect2(Vector2(origin + 1, 15) * CELL, Vector2(3 * CELL, 8)))
				one_way.append(Rect2(Vector2(origin + 1, 12) * CELL, Vector2(2 * CELL, 8)))
			2: # Floating bowl with two readable solid lips.
				_fill(cells, Rect2i(origin + 4, 12, 8, 2))
				_fill(cells, Rect2i(origin + 4, 10, 2, 2))
				_fill(cells, Rect2i(origin + 10, 10, 2, 2))
				_fill(cells, Rect2i(origin + 5, 18, 4, 1))
				one_way.append(Rect2(Vector2(origin + 1, 15) * CELL, Vector2(3 * CELL, 8)))
				one_way.append(Rect2(Vector2(origin + 1, 12) * CELL, Vector2(2 * CELL, 8)))
			3: # Stepped wind terrace and detached upper island.
				_fill(cells, Rect2i(origin + 4, 18, 6, 1))
				_fill(cells, Rect2i(origin + 6, 17, 3, 1))
				_fill(cells, Rect2i(origin + 7, 11, 5, 2))
				one_way.append(Rect2(Vector2(origin + 2, 14) * CELL, Vector2(3 * CELL, 8)))
		modules.append({"id": ["meadow", "arch", "bowl", "wind_terrace"][kind], "origin": Vector2i(origin, 0), "entry": Vector2i(origin, 19), "exit": Vector2i(origin + 20, 19), "halo_owner": "merged_world_cells", "halo_cells": 1})
	var spawn := Vector2(2.5 * CELL, 19 * CELL - 20)
	keepouts.append(Rect2(spawn - Vector2(48, 64), Vector2(96, 96)))
	return {"ok": true, "version": VERSION, "seed": sample_seed, "cells": cells,
		"one_way": one_way, "moving": [], "hazards": [], "modules": modules,
		"keepouts": keepouts, "spawn": spawn, "bounds": Rect2(Vector2.ZERO, Vector2(SIZE) * CELL)}

static func _fill(cells: Dictionary, rect: Rect2i) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x): cells[Vector2i(x, y)] = FAMILY

static func validate(layout: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if layout.get("version") != VERSION: errors.append("unknown layout version")
	for cell: Vector2i in layout.cells:
		if not Rect2i(Vector2i.ZERO, SIZE).has_point(cell): errors.append("cell outside bounds")
		if layout.cells[cell] != FAMILY: errors.append("unknown terrain family")
	for rect: Rect2 in layout.one_way:
		for cell: Vector2i in layout.cells:
			if rect.intersects(Rect2(Vector2(cell) * CELL, Vector2.ONE * CELL)):
				errors.append("one-way intersects solid")
	for x: int in SIZE.x:
		var supported: bool = layout.cells.has(Vector2i(x, 19))
		for rect: Rect2 in layout.one_way:
			if is_equal_approx(rect.position.y, 19 * CELL) and rect.has_point(Vector2(x * CELL + 1, 19 * CELL + 1)): supported = true
		if not supported: errors.append("main route has unsupported column")
	return errors
