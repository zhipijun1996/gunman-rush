class_name PlainsTerrainSkin
extends RefCounted

# Presentation only. The supplied Rect2 remains the collision and standing plane.
# The tile atlas uses 2 art pixels per unit and a standing anchor at source y=16.
const ART_SCALE := 0.5
const TILE := 64.0
const SURFACE_OVERHANG := 8.0
const GRASS_LEFT: Texture2D = preload("res://assets/terrain/plains/grass_left_1.svg")
const GRASS_MIDDLE: Texture2D = preload("res://assets/terrain/plains/grass_middle_1.svg")
const GRASS_RIGHT: Texture2D = preload("res://assets/terrain/plains/grass_right_1.svg")
const ROCK: Texture2D = preload("res://assets/terrain/plains/rock_fill_1.svg")
const THIN_LEFT: Texture2D = preload("res://assets/terrain/plains/thin_platform_left.svg")
const THIN_MIDDLE: Texture2D = preload("res://assets/terrain/plains/thin_platform_middle.svg")
const THIN_RIGHT: Texture2D = preload("res://assets/terrain/plains/thin_platform_right.svg")
const MOVING: Texture2D = preload("res://assets/objects/moving_platform.svg")
const SAW: Texture2D = preload("res://assets/objects/saw_wheel.svg")

static func draw_platform(canvas: CanvasItem, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	canvas.draw_rect(rect, Color("424d42"))
	var thin := rect.size.y <= 32.0
	var top_height := 24.0 if thin else TILE
	var clip := Rect2(rect.position - Vector2(0, SURFACE_OVERHANG), rect.size + Vector2(0, SURFACE_OVERHANG))
	var left: Texture2D = THIN_LEFT if thin else GRASS_LEFT
	var middle: Texture2D = THIN_MIDDLE if thin else GRASS_MIDDLE
	var right: Texture2D = THIN_RIGHT if thin else GRASS_RIGHT
	var cap_width := minf(TILE, rect.size.x / 2.0)
	var y := rect.position.y - SURFACE_OVERHANG
	_draw_region(canvas, left, Rect2(Vector2(rect.position.x, y), Vector2(cap_width, top_height)), Rect2(0, 0, cap_width / ART_SCALE, top_height / ART_SCALE), clip)
	var cursor := rect.position.x + cap_width
	var middle_end := rect.end.x - cap_width
	while cursor < middle_end - 0.001:
		var width := minf(TILE, middle_end - cursor)
		_draw_region(canvas, middle, Rect2(Vector2(cursor, y), Vector2(width, top_height)), Rect2(0, 0, width / ART_SCALE, top_height / ART_SCALE), clip)
		cursor += width
	_draw_region(canvas, right, Rect2(Vector2(middle_end, y), Vector2(cap_width, top_height)), Rect2(128.0 - cap_width / ART_SCALE, 0, cap_width / ART_SCALE, top_height / ART_SCALE), clip)
	# The top row's anchor leaves 56 units of rock beneath the standing plane.
	var fill_y := maxf(rect.position.y, y + top_height)
	while fill_y < rect.end.y - 0.001:
		var height := minf(TILE, rect.end.y - fill_y)
		cursor = rect.position.x
		while cursor < rect.end.x - 0.001:
			var width := minf(TILE, rect.end.x - cursor)
			_draw_region(canvas, ROCK, Rect2(Vector2(cursor, fill_y), Vector2(width, height)), Rect2(0, 0, width / ART_SCALE, height / ART_SCALE), rect)
			cursor += width
		fill_y += height
	# A fine uninterrupted landing edge matches the exact physical plane, including
	# tiny pieces and dock overlaps. No independent random stream changes geometry.
	canvas.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color("d6ce8c"), 1.0)

static func draw_moving_platform(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Color("535b56"))
	# Fixed-size end caps retain their proportions; crop the center repeat and
	# underside to arbitrary gameplay sizes instead of stretching the whole image.
	var cap_width := minf(24.0, rect.size.x / 2.0)
	var height := minf(27.5, rect.size.y)
	var left := Rect2(rect.position, Vector2(cap_width, height))
	_draw_region(canvas, MOVING, left, Rect2(4, 5, cap_width / ART_SCALE, height / ART_SCALE), rect)
	var right_x := rect.end.x - cap_width
	var cursor := rect.position.x + cap_width
	while cursor < right_x - 0.001:
		var width := minf(76.0, right_x - cursor)
		_draw_region(canvas, MOVING, Rect2(Vector2(cursor, rect.position.y), Vector2(width, height)), Rect2(52, 5, width / ART_SCALE, height / ART_SCALE), rect)
		cursor += width
	_draw_region(canvas, MOVING, Rect2(Vector2(right_x, rect.position.y), Vector2(cap_width, height)), Rect2(252.0 - cap_width / ART_SCALE, 5, cap_width / ART_SCALE, height / ART_SCALE), rect)
	canvas.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color("d6ce8c"), 1.5)

static func draw_saw(canvas: CanvasItem, radius: float) -> void:
	# SVG pivot (64,64), tooth vertex radius=60 plus a 1.5px stroke.
	# The exact radius outline communicates the gameplay circle at every size.
	var scale_factor := radius / 61.5
	var image_radius := 64.0 * scale_factor
	canvas.draw_texture_rect(SAW, Rect2(Vector2.ONE * -image_radius, Vector2.ONE * image_radius * 2.0), false)
	canvas.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color("d39964"), 1.0)

static func _draw_region(canvas: CanvasItem, texture: Texture2D, destination: Rect2, source: Rect2, clip: Rect2) -> void:
	var visible := destination.intersection(clip)
	if not visible.has_area():
		return
	var source_origin := source.position + (visible.position - destination.position) / ART_SCALE
	canvas.draw_texture_rect_region(texture, visible, Rect2(source_origin, visible.size / ART_SCALE))
