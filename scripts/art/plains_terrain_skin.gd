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
const SAW: Texture2D = preload("res://assets/plains_v3/objects.png")
const PAINTED_GRASS: Texture2D = preload("res://assets/plains_v3/terrain/grass_limestone.png")
const PAINTED_WOOD: Texture2D = preload("res://assets/plains_v3/terrain/brass_wood_bridge.png")
const PAINTED_ANCHOR: Texture2D = preload("res://assets/plains_v3/objects.png")
# Fixed uniform art scale; cap pixels never stretch to match gameplay lengths.
const PAINT_SCALE := 0.2
const PAINTED_ROCK: Texture2D = preload("res://assets/plains_v3/terrain/organic_cliff_fill.png")

static func draw_platform(canvas: CanvasItem, rect: Rect2, one_way: bool = false) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if rect.size.y > 32.0:
		_draw_rock(canvas, rect)
	_draw_surface(canvas, rect, surface_id(one_way))
	# Exact physical standing edge, subtler than the former bright yellow stripe.
	canvas.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color("c6c99a"), 1.0)

static func surface_id(one_way: bool) -> String:
	return "brass_wood_bridge" if one_way else "grass_limestone"

static func draw_support(canvas: CanvasItem, rect: Rect2) -> void:
	_draw_rock(canvas, rect)

static func _draw_rock(canvas: CanvasItem, rect: Rect2) -> void:
	# Alternate mirror tiles: matching border pixels, no ordinary repeat claim.
	canvas.draw_rect(rect, Color("686b50"))
	var tile := PAINTED_ROCK.get_size() * PAINT_SCALE
	var row := 0
	var y := rect.position.y
	while y < rect.end.y - 0.001:
		var height := minf(tile.y, rect.end.y - y)
		var col := 0
		var x := rect.position.x
		while x < rect.end.x - 0.001:
			var width := minf(tile.x, rect.end.x - x)
			var flip := Vector2(-1 if col % 2 else 1, -1 if row % 2 else 1)
			canvas.draw_set_transform(Vector2(x + width if flip.x < 0 else x, y + height if flip.y < 0 else y), 0.0, flip)
			var origin := Vector2((tile.x - width) / PAINT_SCALE if flip.x < 0 else 0.0, (tile.y - height) / PAINT_SCALE if flip.y < 0 else 0.0)
			canvas.draw_texture_rect_region(PAINTED_ROCK, Rect2(Vector2.ZERO, Vector2(width, height)), Rect2(origin, Vector2(width, height) / PAINT_SCALE))
			canvas.draw_set_transform(Vector2.ZERO)
			x += width
			col += 1
		y += height
		row += 1

static func draw_moving_platform(canvas: CanvasItem, rect: Rect2) -> void:
	_draw_surface(canvas, rect, "grass_limestone")
	canvas.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color("d6ce8c"), 1.5)

static func draw_anchor(canvas: CanvasItem, feet_point: Vector2) -> void:
	var texture := PlainsV3Assets.texture("objects.json", "checkpoint")
	var size := texture.get_size() * (40.0 / texture.get_height())
	canvas.draw_texture_rect(texture, Rect2(feet_point - Vector2(size.x / 2, size.y), size), false)

static func draw_saw(canvas: CanvasItem, radius: float) -> void:
	var texture := PlainsV3Assets.texture("objects.json", "saw")
	canvas.draw_texture_rect(texture, Rect2(Vector2.ONE * -radius, Vector2.ONE * radius * 2.0), false)
	canvas.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color("d39964"), 1.0)

static func surface_pieces(rect: Rect2, id: String) -> Array[Dictionary]:
	var item := PlainsV3Assets.entry("terrain/manifest.json", id)
	var scale_value := float(item.uniform_scale)
	var left := PlainsV3Assets.rect(item.regions.left_cap)
	var middle := PlainsV3Assets.rect(item.regions.middle)
	var right := PlainsV3Assets.rect(item.regions.right_cap)
	var cap := minf(left.size.x * scale_value, rect.size.x / 2)
	var above := (float(item.standline_y) - left.position.y) * scale_value
	var height := minf(left.size.y * scale_value, rect.size.y + above)
	var y := rect.position.y - above
	var result: Array[Dictionary] = []
	result.append({"destination": Rect2(rect.position.x, y, cap, height), "source": Rect2(left.position, Vector2(cap, height) / scale_value)})
	var x := rect.position.x + cap
	var end := rect.end.x - cap
	while x < end - 0.001:
		var width := minf(middle.size.x * scale_value, end - x)
		result.append({"destination": Rect2(x, y, width, height), "source": Rect2(middle.position, Vector2(width, height) / scale_value)})
		x += width
	result.append({"destination": Rect2(end, y, cap, height), "source": Rect2(right.end.x - cap / scale_value, right.position.y, cap / scale_value, height / scale_value)})
	return result

static func _draw_surface(canvas: CanvasItem, rect: Rect2, id: String) -> void:
	var texture := PAINTED_WOOD if id == "brass_wood_bridge" else PAINTED_GRASS
	for piece: Dictionary in surface_pieces(rect, id):
		canvas.draw_texture_rect_region(texture, piece.destination, piece.source)

static func _draw_region(canvas: CanvasItem, texture: Texture2D, destination: Rect2, source: Rect2, clip: Rect2) -> void:
	var visible := destination.intersection(clip)
	if not visible.has_area():
		return
	var source_origin := source.position + (visible.position - destination.position) / ART_SCALE
	canvas.draw_texture_rect_region(texture, visible, Rect2(source_origin, visible.size / ART_SCALE))
