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

static func draw_platform(canvas: CanvasItem, rect: Rect2, one_way: bool = false, floating_solid: bool = false, surface_region: Dictionary = {}) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if floating_solid:
		draw_suspended_solid(canvas, rect)
		return
	if not one_way:
		_draw_rock(canvas, rect)
	if one_way:
		_draw_surface(canvas, rect, surface_id(one_way))
	else:
		_draw_ground_edge(canvas, surface_region.get("rect", rect), bool(surface_region.get("left", false)), bool(surface_region.get("right", false)))
	# Exact physical standing edge, subtler than the former bright yellow stripe.
	canvas.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color("c6c99a"), 1.0)

# Presentation-only shared top edge. Earlier slabs own overlapping pixels so
# translucent roots do not become dark double-painted bars at module seams.
static func configure_ground_edges(modules: Array[PlatformingModule]) -> void:
	var seen: Array[Rect2] = []
	var all_stone: Array[Rect2] = []
	for module: PlatformingModule in modules:
		for index: int in module.definition.platforms.size():
			if index in module.definition.one_way_platform_indices or index in module.floating_solid_indices: continue
			var slab: Rect2 = module.definition.platforms[index]
			all_stone.append(Rect2(slab.position + module.position, slab.size))
	for module: PlatformingModule in modules:
		module.ground_surface_regions.clear()
		for index: int in module.definition.platforms.size():
			if index in module.definition.one_way_platform_indices or index in module.floating_solid_indices: continue
			var slab: Rect2 = module.definition.platforms[index]
			var world := Rect2(slab.position + module.position, slab.size)
			var joined_left := false
			var joined_right := false
			for other: Rect2 in all_stone:
				if not is_equal_approx(other.position.y, world.position.y): continue
				joined_left = joined_left or (other.position.x < world.position.x and other.end.x >= world.position.x)
				joined_right = joined_right or (other.end.x > world.end.x and other.position.x <= world.end.x)
			var visible := world
			for previous: Rect2 in seen:
				if is_equal_approx(previous.position.y, world.position.y) and previous.position.x <= visible.position.x and previous.end.x > visible.position.x:
					var start := minf(visible.end.x, previous.end.x)
					visible = Rect2(start, visible.position.y, visible.end.x - start, visible.size.y)
			module.ground_surface_regions[index] = {"rect": Rect2(visible.position - module.position, visible.size), "left": joined_left, "right": joined_right}
			seen.append(world)

static func ground_edge_pieces(rect: Rect2, world_origin: Vector2, joined_left: bool, joined_right: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if rect.size.x <= 0: return result
	var item := PlainsV3Assets.entry("terrain/manifest.json", "grass_limestone")
	var middle := PlainsV3Assets.rect(item.regions.middle)
	var left := PlainsV3Assets.rect(item.regions.left_cap)
	var right := PlainsV3Assets.rect(item.regions.right_cap)
	var above := (float(item.standline_y) - middle.position.y) * PAINT_SCALE
	var height := above + minf(14.0, rect.size.y)
	var left_width := 0.0 if joined_left else minf(left.size.x * PAINT_SCALE, rect.size.x / 2)
	var right_width := 0.0 if joined_right else minf(right.size.x * PAINT_SCALE, rect.size.x / 2)
	var y := rect.position.y - above
	if left_width > 0:
		result.append({"destination": Rect2(rect.position.x, y, left_width, height), "source": Rect2(left.position, Vector2(left_width, height) / PAINT_SCALE)})
	var x := rect.position.x + left_width
	var finish := rect.end.x - right_width
	while x < finish - 0.001:
		var offset := fposmod(x + world_origin.x, middle.size.x * PAINT_SCALE)
		var width := minf(finish - x, middle.size.x * PAINT_SCALE - offset)
		result.append({"destination": Rect2(x, y, width, height), "source": Rect2(middle.position + Vector2(offset / PAINT_SCALE, 0), Vector2(width, height) / PAINT_SCALE)})
		x += width
	if right_width > 0:
		result.append({"destination": Rect2(finish, y, right_width, height), "source": Rect2(right.end.x - right_width / PAINT_SCALE, right.position.y, right_width / PAINT_SCALE, height / PAINT_SCALE)})
	return result

static func _draw_ground_edge(canvas: CanvasItem, rect: Rect2, joined_left: bool, joined_right: bool) -> void:
	for piece: Dictionary in ground_edge_pieces(rect, canvas.get_global_transform().origin, joined_left, joined_right):
		var dst: Rect2 = piece.destination
		var src: Rect2 = piece.source
		var y := dst.position.y
		while y < dst.end.y - 0.001:
			var height := minf(2.0, dst.end.y - y)
			var depth := y + height * 0.5 - rect.position.y
			var alpha := 1.0 - clampf((depth - 3.0) / 11.0, 0.0, 1.0)
			canvas.draw_texture_rect_region(PAINTED_GRASS, Rect2(dst.position.x, y, dst.size.x, height), Rect2(src.position + Vector2(0, (y - dst.position.y) / PAINT_SCALE), Vector2(src.size.x, height / PAINT_SCALE)), Color(1, 1, 1, alpha))
			y += height

static func surface_id(one_way: bool) -> String:
	return "brass_wood_bridge" if one_way else "grass_limestone"

static func draw_support(canvas: CanvasItem, rect: Rect2) -> void:
	_draw_rock(canvas, rect)

# Rock wall texture is continuous in world space, even where separate module
# collision slabs and foundation rectangles meet. Broad stone forms, not tiny tiles.
const ROCK_SCALE := 0.36
static func _draw_rock(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Color("686b50"))
	var world_origin := canvas.get_global_transform().origin
	for piece: Dictionary in rock_pieces(rect, world_origin):
		var dst: Rect2 = piece.destination
		var flip: Vector2 = piece.flip
		canvas.draw_set_transform(dst.position + Vector2(dst.size.x if flip.x < 0 else 0.0, dst.size.y if flip.y < 0 else 0.0), 0.0, flip)
		canvas.draw_texture_rect_region(PAINTED_ROCK, Rect2(Vector2.ZERO, dst.size), piece.source)
	canvas.draw_set_transform(Vector2.ZERO)

static func rock_pieces(rect: Rect2, world_origin: Vector2) -> Array[Dictionary]:
	var tile := PAINTED_ROCK.get_size() * ROCK_SCALE
	var world := Rect2(rect.position + world_origin, rect.size)
	var result: Array[Dictionary] = []
	for row: int in range(floori(world.position.y / tile.y), ceili(world.end.y / tile.y)):
		for col: int in range(floori(world.position.x / tile.x), ceili(world.end.x / tile.x)):
			var cell := Rect2(Vector2(col, row) * tile, tile)
			var part := cell.intersection(world)
			if not part.has_area(): continue
			var flip := Vector2(-1 if absi(col) % 2 else 1, -1 if absi(row) % 2 else 1)
			var local := part.position - cell.position
			if flip.x < 0: local.x = tile.x - local.x - part.size.x
			if flip.y < 0: local.y = tile.y - local.y - part.size.y
			result.append({"destination": Rect2(part.position - world_origin, part.size), "source": Rect2(local / ROCK_SCALE, part.size / ROCK_SCALE), "flip": flip})
	return result

static func draw_suspended_solid(canvas: CanvasItem, rect: Rect2) -> void:
	# A boxed wooden/bronze deck is solid on its underside and both ends. Thin
	# one-way slats deliberately do not get these beams or side plates.
	canvas.draw_rect(rect, Color("514738"))
	_draw_surface(canvas, rect, "brass_wood_bridge")
	var beam := minf(6.0, rect.size.y * 0.3)
	canvas.draw_rect(Rect2(rect.position.x, rect.end.y - beam, rect.size.x, beam), Color("776047"))
	for x: float in [rect.position.x + 3.0, rect.end.x - 3.0]:
		canvas.draw_line(Vector2(x, rect.position.y + 2), Vector2(x, rect.end.y - 2), Color("bb9561"), 3.0)
		canvas.draw_circle(Vector2(x, rect.end.y - beam * 0.5), 1.5, Color("ead6a1"))
	canvas.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color("d6ce8c"), 1.5)

static func draw_moving_platform(canvas: CanvasItem, rect: Rect2) -> void:
	draw_suspended_solid(canvas, rect)

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
