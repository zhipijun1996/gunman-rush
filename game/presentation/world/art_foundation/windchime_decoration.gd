class_name WindchimeDecoration
extends Node2D
## A separate coordinate-addressed cosmetic stream. No collision or gameplay RNG.
const PROPS := preload("res://assets/windchime_plains/props.svg")
const PROP_SCALE := 0.43
const PROFILE := {
	"id": "windchime-sparse-v1", "threshold_per_thousand": 360,
	"min_spacing": 64.0, "screen_cells": Vector2i(40, 23),
	"max_props_per_screen_bucket": 12, "max_lamps_per_screen_bucket": 2,
	"lamp_spacing": 192.0, "glow_radius": 48.0, "glow_alpha": 0.18
}
const SOURCE_BOXES := [
	Rect2(6, 69, 54, 53), Rect2(0, 80, 57, 41), Rect2(12, 72, 39, 49),
	Rect2(29, 35, 31, 86), Rect2(7, 10, 52, 111), Rect2(9, 15, 47, 106),
	Rect2(13, 41, 39, 80), Rect2(10, 49, 44, 72)
]
var placements: Array[Dictionary] = []
var lights_enabled := true
var _glow: Texture2D

func configure(cells: Dictionary, keepouts: Array[Rect2], seed_text: String) -> void:
	placements.clear()
	var budgets: Dictionary = {}
	var ordered: Array = cells.keys()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
	for cell: Vector2i in ordered:
		if cells.has(cell + Vector2i.UP): continue
		var roll := posmod((seed_text + ":windchime-decor-v1:" + str(cell)).hash(), 1000)
		# Keep long stretches quiet and avoid any grid-like decoration cadence.
		if roll >= int(PROFILE.threshold_per_thousand): continue
		var kind := posmod((seed_text + ":windchime-kind-v1:" + str(cell)).hash(), 16)
		# Flowers/grasses occur more often than architecture and ornate objects.
		if kind >= 8: kind = 0 if kind < 12 else 1
		var point := Vector2(cell * Blob47Rules.CELL) + Vector2(16, 0)
		var bucket := Vector2i(floori(float(cell.x) / PROFILE.screen_cells.x), floori(float(cell.y) / PROFILE.screen_cells.y))
		var budget: Vector2i = budgets.get(bucket, Vector2i.ZERO)
		if budget.x >= int(PROFILE.max_props_per_screen_bucket): continue
		if kind == 3 and budget.y >= int(PROFILE.max_lamps_per_screen_bucket): continue
		var source_box: Rect2 = SOURCE_BOXES[kind]
		var box := Rect2(point + (source_box.position - Vector2(32, 120)) * PROP_SCALE, source_box.size * PROP_SCALE)
		var valid := true
		for keepout: Rect2 in keepouts:
			if keepout.grow(10).intersects(box): valid = false; break
		# Grounded props require a continuous ledge, never a one-way or moving slab.
		if not cells.has(cell + Vector2i.LEFT) or not cells.has(cell + Vector2i.RIGHT): valid = false
		for previous: Dictionary in placements:
			var distance := point.distance_to(previous.position)
			if distance < float(PROFILE.min_spacing): valid = false; break
			if kind == 3 and int(previous.kind) == 3 and distance < float(PROFILE.lamp_spacing): valid = false; break
		if valid:
			placements.append({"position": point, "kind": kind, "bounds": box, "bucket": bucket})
			budgets[bucket] = budget + Vector2i(1, 1 if kind == 3 else 0)
	queue_redraw()

func _ready() -> void:
	z_index = -2
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.97, 0.85, 0.52, PROFILE.glow_alpha), Color(0.97, 0.85, 0.52, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	_glow = texture

func _draw() -> void:
	for item: Dictionary in placements:
		var point: Vector2 = item.position
		if int(item.kind) == 3 and lights_enabled and _glow != null:
			var radius: float = PROFILE.glow_radius
			draw_texture_rect(_glow, Rect2(point + Vector2(8, -19) - Vector2.ONE * radius, Vector2.ONE * radius * 2), false)
		draw_texture_rect_region(PROPS, Rect2(point - Vector2(32, 120) * PROP_SCALE, Vector2(64, 128) * PROP_SCALE), Rect2(int(item.kind) * 64, 0, 64, 128))
