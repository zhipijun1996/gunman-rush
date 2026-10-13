class_name PlainsTerrainSkin
extends RefCounted

# Presentation only. The supplied Rect2 remains the collision and standing plane.
# Verified fallback fill uses 2 art pixels per unit; painted surfaces below
# use their package standing anchors and fixed proportional scale.
const COHESION_VERSION := "plains-connected-terrain-v2"
const ROOT_BANDS: Texture2D = preload("res://assets/plains_v4/ground/soil_root_bands.png")
const ROOT_SCALE := 0.17
const SOIL_SOURCE := Rect2(232, 210, 1714, 200)
const THORN_ROOT_SOURCE := Rect2(232, 460, 1714, 155)
const SOIL_ANCHOR := 235.0
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
	canvas.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(.70,.78,.55,.35), 1.0)

# Presentation-only shared top edge. Earlier slabs own overlapping pixels so
# translucent roots do not become dark double-painted bars at module seams.
static func configure_ground_edges(modules: Array[PlatformingModule],columns:Array[Rect2]=[]) -> void:
	var seen: Array[Rect2] = []
	var all_stone: Array[Rect2] = columns.duplicate()
	for module: PlatformingModule in modules:
		for index: int in module.definition.platforms.size():
			if index in module.definition.one_way_platform_indices or index in module.floating_solid_indices: continue
			var slab: Rect2 = module.definition.platforms[index]
			all_stone.append(Rect2(slab.position + module.position, slab.size))
	# Boundary artwork includes floating solids, while legacy foundation ownership stays separate.
	var union_solids:Array[Rect2]=columns.duplicate()
	for module:PlatformingModule in modules:
		for index:int in module.definition.platforms.size():
			if index in module.definition.one_way_platform_indices:continue
			var slab:Rect2=module.definition.platforms[index]
			union_solids.append(Rect2(slab.position+module.global_position,slab.size))
	for module:PlatformingModule in modules:
		module.terrain_border_plans.clear()
		for index:int in module.definition.platforms.size():
			if index in module.definition.one_way_platform_indices:continue
			var slab:Rect2=module.definition.platforms[index]
			module.terrain_border_plans[index]=PlainsTerrainBorders.plan(Rect2(slab.position+module.global_position,slab.size),union_solids)
	for module: PlatformingModule in modules:
		module.ground_surface_regions.clear()
		module.exposed_surface_edges.clear()
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
			module.exposed_surface_edges[index]=exposed_faces(world,all_stone,module.position)
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
	var start := rect.position.x + left_width
	var finish := rect.end.x - right_width
	var middle_target := Rect2(start, y, maxf(0.0, finish - start), height)
	result.append_array(clipped_strip_pieces(middle_target, middle_target, world_origin, Rect2(middle.position, Vector2(middle.size.x, height / PAINT_SCALE)), PAINT_SCALE))
	if right_width > 0:
		result.append({"destination": Rect2(finish, y, right_width, height), "source": Rect2(right.end.x - right_width / PAINT_SCALE, right.position.y, right_width / PAINT_SCALE, height / PAINT_SCALE)})
	return result

static func _draw_ground_edge(canvas: CanvasItem, rect: Rect2, joined_left: bool, joined_right: bool) -> void:
	PlainsCohesionArt.draw_surface(canvas,rect,false,joined_left,joined_right)

# Atlas strips retain natural scale and are clipped to existing geometry. The
# horizontal sample is anchored to world space, so adjoining authored modules
# cannot restart their soil pattern or create a rectangular edge cap.
static func clipped_strip_pieces(target: Rect2, clip: Rect2, world_origin: Vector2, source: Rect2, uniform_scale: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if uniform_scale <= 0.0 or not target.has_area() or not source.has_area(): return result
	var visible := target.intersection(clip)
	visible = visible.intersection(Rect2(target.position, Vector2(target.size.x, source.size.y * uniform_scale)))
	if not visible.has_area(): return result
	var tile_width := source.size.x * uniform_scale
	# Integer tile enumeration bounds allocations by geometry width. Iterative
	# fposmod + x += width can produce a sub-ULP width at a tile boundary,
	# leaving x unchanged forever and appending until OOM.
	var world_start := visible.position.x + world_origin.x
	var world_finish := visible.end.x + world_origin.x
	for column: int in range(floori(world_start / tile_width), ceili(world_finish / tile_width)):
		var start := maxf(world_start, float(column) * tile_width)
		var finish := minf(world_finish, float(column + 1) * tile_width)
		if finish <= start: continue
		var offset := start - float(column) * tile_width
		var width := finish - start
		result.append({"destination": Rect2(start - world_origin.x, visible.position.y, width, visible.size.y), "source": Rect2(source.position + Vector2(offset, visible.position.y - target.position.y) / uniform_scale, Vector2(width, visible.size.y) / uniform_scale)})
	return result

# A root bed can occupy the existing bottom of a hazard silhouette. Anything
# below it must be inside a real authored solid: never paint a false pit floor.
static func thorn_root_clips(danger: Rect2, solids: Array[Rect2]) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if not danger.has_area(): return result
	result.append(Rect2(danger.position.x, danger.end.y - minf(12.0, danger.size.y), danger.size.x, minf(12.0, danger.size.y)))
	var below := Rect2(danger.position.x, danger.end.y, danger.size.x, 18.0)
	for solid: Rect2 in solids:
		var part := below.intersection(solid)
		if part.has_area(): result.append(part)
	return result

static func draw_rooted_bramble(canvas: CanvasItem, danger: Rect2, solids: Array[Rect2]) -> void:
	# Existing thorn tips stay visible; the low rhizome layer only replaces the
	# abrupt bottom edge, not the attack silhouette or standing plane.
	PlainsRefreshAssets.draw_bramble(canvas, danger)
	var roots := Rect2(danger.position.x, danger.end.y - minf(12.0, danger.size.y), danger.size.x, THORN_ROOT_SOURCE.size.y * ROOT_SCALE)
	for clip: Rect2 in thorn_root_clips(danger, solids):
		for piece: Dictionary in clipped_strip_pieces(roots, clip, canvas.get_global_transform().origin, THORN_ROOT_SOURCE, ROOT_SCALE):
			canvas.draw_texture_rect_region(ROOT_BANDS, piece.destination, piece.source)

static func surface_id(one_way: bool) -> String:
	return "brass_wood_bridge" if one_way else "grass_limestone"

static func draw_support(canvas: CanvasItem, rect: Rect2) -> void:
	_draw_rock(canvas, rect)

# Rock wall texture is continuous in world space, even where separate module
# collision slabs and foundation rectangles meet. Broad stone forms, not tiny tiles.
const ROCK_SCALE := 0.36
static func _draw_rock(canvas: CanvasItem, rect: Rect2) -> void:
	PlainsCohesionArt.draw_fill(canvas,rect)

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
	PlainsCohesionArt.draw_surface(canvas,rect,false)

static func draw_moving_platform(canvas: CanvasItem, rect: Rect2) -> void:
	PlainsCohesionArt.draw_surface(canvas,rect,true)

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
	PlainsCohesionArt.draw_surface(canvas,rect,id=="brass_wood_bridge")

static func _draw_region(canvas: CanvasItem, texture: Texture2D, destination: Rect2, source: Rect2, clip: Rect2) -> void:
	var visible := destination.intersection(clip)
	if not visible.has_area():
		return
	var source_origin := source.position + (visible.position - destination.position) / ART_SCALE
	canvas.draw_texture_rect_region(texture, visible, Rect2(source_origin, visible.size / ART_SCALE))

static func exposed_faces(world:Rect2,solids:Array[Rect2],origin:Vector2=Vector2.ZERO)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for side:String in ["left","right","bottom"]:
		var vertical:bool=side!="bottom"
		var intervals:Array=[Vector2(world.position.y,world.end.y) if vertical else Vector2(world.position.x,world.end.x)]
		for other:Rect2 in solids:
			if other==world:continue
			var touches:bool=absf(other.end.x-world.position.x)<.01 if side=="left" else absf(other.position.x-world.end.x)<.01 if side=="right" else absf(other.position.y-world.end.y)<.01
			if not touches:continue
			var cut:=Vector2(other.position.y,other.end.y) if vertical else Vector2(other.position.x,other.end.x)
			var next:Array=[]
			for span:Vector2 in intervals:
				if cut.y<=span.x or cut.x>=span.y:next.append(span);continue
				if cut.x>span.x:next.append(Vector2(span.x,minf(cut.x,span.y)))
				if cut.y<span.y:next.append(Vector2(maxf(cut.y,span.x),span.y))
			intervals=next
		for span:Vector2 in intervals:
			var point:=Vector2(world.position.x if side=="left" else world.end.x,span.x) if vertical else Vector2(span.x,world.end.y)
			result.append({"side":side,"rect":Rect2(point-origin,Vector2(0,span.y-span.x) if vertical else Vector2(span.y-span.x,0))})
	return result
