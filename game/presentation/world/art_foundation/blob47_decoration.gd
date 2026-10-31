class_name Blob47Decoration
extends Node2D
## Cosmetic RNG is coordinate-addressed. Never consumes a layout/gameplay stream.
const PROPS := preload("res://assets/art_foundation_v1/props.svg")
const PROP_SCALE := .43
var placements: Array[Dictionary] = []
var lights_enabled := true
var _glow: Texture2D

func configure(cells: Dictionary, keepouts: Array[Rect2], seed_text: String) -> void:
	placements.clear()
	var profile := Blob47Rules.DECORATION_PROFILE
	var budgets: Dictionary = {}
	var ordered: Array = cells.keys()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
	for cell: Vector2i in ordered:
		if cells.has(cell + Vector2i.UP): continue
		var roll := posmod((seed_text + ":decoration-v1:" + str(cell)).hash(), 1000)
		# A deterministic quiet interval keeps large surfaces from being carpeted.
		if roll > int(profile.threshold_per_thousand) or posmod(cell.x, 17) in [0, 1, 2]: continue
		var point := Vector2(cell * Blob47Rules.CELL) + Vector2(16, 0)
		var kind := roll % 6
		var bucket := Vector2i(floori(float(cell.x) / profile.screen_cells.x), floori(float(cell.y) / profile.screen_cells.y))
		var budget: Vector2i = budgets.get(bucket, Vector2i.ZERO)
		if budget.x >= int(profile.max_props_per_screen_bucket): continue
		if kind == 4 and budget.y >= int(profile.max_lamps_per_screen_bucket): continue
		var box := Rect2(point - Vector2(14, 38), Vector2(28, 38))
		var valid := true
		for keepout: Rect2 in keepouts:
			if keepout.grow(10).intersects(box): valid = false; break
		# Root and full prop width must be supported. Narrow corners stay quiet.
		if not cells.has(cell + Vector2i.LEFT) or not cells.has(cell + Vector2i.RIGHT): valid = false
		for previous: Dictionary in placements:
			var distance := point.distance_to(previous.position)
			if distance < float(profile.min_spacing): valid = false; break
			if kind == 4 and int(previous.kind) == 4 and distance < float(profile.lamp_spacing): valid = false; break
		if valid:
			placements.append({"position": point, "kind": kind, "bounds": box, "bucket": bucket})
			budgets[bucket] = budget + Vector2i(1, 1 if kind == 4 else 0)
	queue_redraw()

func _ready() -> void:
	z_index = -2
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, .82, .37, Blob47Rules.DECORATION_PROFILE.glow_alpha), Color(1, .82, .37, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5, .5)
	texture.fill_to = Vector2(1, .5)
	_glow = texture

func _draw() -> void:
	for item: Dictionary in placements:
		var point: Vector2 = item.position
		if int(item.kind) == 4 and lights_enabled and _glow != null:
			var radius: float = Blob47Rules.DECORATION_PROFILE.glow_radius
			draw_texture_rect(_glow, Rect2(point + Vector2(6, -34) - Vector2.ONE * radius, Vector2.ONE * radius * 2), false)
		draw_texture_rect_region(PROPS, Rect2(point - Vector2(32, 88) * PROP_SCALE, Vector2(64, 96) * PROP_SCALE), Rect2(int(item.kind) * 64, 0, 64, 96))
