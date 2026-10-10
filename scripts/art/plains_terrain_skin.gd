class_name PlainsTerrainSkin
extends RefCounted

# Presentation only. The supplied Rect2 remains the collision and standing plane.
# Verified fallback fill uses 2 art pixels per unit; painted surfaces below
# use their package standing anchors and fixed proportional scale.
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
const SAW: Texture2D = preload("res://assets/painterly_v2/objects/saw.png")
const PAINTED_GRASS: Texture2D = preload("res://assets/painterly_v2/terrain/grass_ledge.png")
const PAINTED_WOOD: Texture2D = preload("res://assets/painterly_v2/terrain/wood_bridge.png")
const PAINTED_ANCHOR: Texture2D = preload("res://assets/painterly_v2/objects/checkpoint.png")
# Fixed uniform art scale; cap pixels never stretch to match gameplay lengths.
const PAINT_SCALE := 0.14

static func draw_platform(canvas: CanvasItem, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	# Keep verified seamless SVG fill until painted rock receives actual repeat
	# approval. The painted strip is cropped separately at its standing anchor.
	canvas.draw_rect(rect, Color("424d42"))
	var y := rect.position.y
	while y < rect.end.y - 0.001:
		var height := minf(TILE, rect.end.y - y)
		var x := rect.position.x
		while x < rect.end.x - 0.001:
			var width := minf(TILE, rect.end.x - x)
			_draw_region(canvas, ROCK, Rect2(x, y, width, height), Rect2(0, 0, width / ART_SCALE, height / ART_SCALE), rect)
			x += width
		y += height
	if rect.size.y <= 32.0:
		_painted_strip(canvas, PAINTED_WOOD, rect, 43.0, 1935.0, 295.0, 272.0, 522.0)
	else:
		_painted_strip(canvas, PAINTED_GRASS, rect, 81.0, 1902.0, 324.0, 289.0, 681.0)
	# Precise cosmetic landing line makes the physical plane readable despite
	# natural grass contours; neither image bounds nor contour becomes collision.
	canvas.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color("d6ce8c"), 1.0)

static func draw_moving_platform(canvas: CanvasItem, rect: Rect2) -> void:
	_painted_strip(canvas, PAINTED_WOOD, rect, 43.0, 1935.0, 295.0, 272.0, 522.0)
	canvas.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color("d6ce8c"), 1.5)

static func draw_anchor(canvas: CanvasItem, feet_point: Vector2) -> void:
	# Segment marker only; artwork does not restore HP, resources, or world state.
	var source := Rect2(194, 59, 924, 1066)
	var factor := 40.0 / source.size.y
	var destination := Rect2(feet_point - Vector2(source.size.x * factor / 2.0, 40.0), source.size * factor)
	canvas.draw_texture_rect_region(PAINTED_ANCHOR, destination, source)

static func draw_saw(canvas: CanvasItem, radius: float) -> void:
	# Candidate manifest center (626.5,617.5), max opaque tooth radius <=551.
	# Transparent source margins are cropped, and hazard radius stays authoritative.
	var source := Rect2(75.5, 66.5, 1102, 1102)
	canvas.draw_texture_rect_region(SAW, Rect2(Vector2.ONE * -radius, Vector2.ONE * radius * 2.0), source)
	canvas.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color("d39964"), 1.0)

static func _painted_strip(canvas: CanvasItem, texture: Texture2D, rect: Rect2, first: float, last: float, stand_y: float, top: float, bottom: float) -> void:
	# Intact source end caps with a cropped middle. It is a presentation assembly,
	# not a claim that the source image is a seamless tile; asset repeat remains
	# unapproved. Cropping preserves size/anchor even on tiny boards and tall walls.
	var cap := minf(28.0, rect.size.x / 2.0)
	var height := minf((bottom - top) * PAINT_SCALE, rect.size.y + (stand_y - top) * PAINT_SCALE)
	var y := rect.position.y - (stand_y - top) * PAINT_SCALE
	canvas.draw_texture_rect_region(texture, Rect2(rect.position.x, y, cap, height), Rect2(first, top, cap / PAINT_SCALE, height / PAINT_SCALE))
	var x := rect.position.x + cap
	var end := rect.end.x - cap
	while x < end - 0.001:
		var width := minf(112.0, end - x)
		canvas.draw_texture_rect_region(texture, Rect2(x, y, width, height), Rect2(550, top, width / PAINT_SCALE, height / PAINT_SCALE))
		x += width
	canvas.draw_texture_rect_region(texture, Rect2(end, y, cap, height), Rect2(last - cap / PAINT_SCALE, top, cap / PAINT_SCALE, height / PAINT_SCALE))

static func _draw_region(canvas: CanvasItem, texture: Texture2D, destination: Rect2, source: Rect2, clip: Rect2) -> void:
	var visible := destination.intersection(clip)
	if not visible.has_area():
		return
	var source_origin := source.position + (visible.position - destination.position) / ART_SCALE
	canvas.draw_texture_rect_region(texture, visible, Rect2(source_origin, visible.size / ART_SCALE))
