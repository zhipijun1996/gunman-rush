class_name Blob47Terrain
extends RefCounted
## Atlas is actual 47-state art; TileMapLayer is presentation only. Collision is
## merged from the very same cells, with no snapping of existing module geometry.
const ATLAS := preload("res://assets/art_foundation_v1/sandstone_blob47.svg")

static func build(cells: Dictionary, seed_text: String, atlas: Texture2D = ATLAS, family: StringName = &"sandstone") -> TileMapLayer:
	var source := TileSetAtlasSource.new()
	source.texture = atlas
	source.texture_region_size = Vector2i.ONE * Blob47Rules.SOURCE_SIZE
	source.margins = Vector2i.ONE * Blob47Rules.GUTTER
	source.separation = Vector2i.ONE * Blob47Rules.GUTTER * 2
	for mask: int in Blob47Rules.catalog_masks():
		for variant: int in Blob47Rules.VARIANTS:
			source.create_tile(Blob47Rules.atlas_coords(mask, variant))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i.ONE * Blob47Rules.SOURCE_SIZE
	tile_set.add_source(source, 0)
	var layer := TileMapLayer.new()
	layer.name = "SolidTiles47"
	layer.tile_set = tile_set
	layer.scale = Vector2.ONE * float(Blob47Rules.CELL) / Blob47Rules.SOURCE_SIZE
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for cell: Vector2i in cells:
		assert(cells[cell] == family, "Material needs its own admitted 47-tile family")
		layer.set_cell(cell, 0, Blob47Rules.atlas_coords(Blob47Rules.mask_at(cells, cell), Blob47Rules.variant_at(seed_text, cell)))
	return layer

static func collision_rectangles(cells: Dictionary) -> Array[Rect2]:
	var ordered: Array = cells.keys()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
	var remaining := cells.duplicate()
	var result: Array[Rect2] = []
	for cell: Vector2i in ordered:
		if not remaining.has(cell): continue
		var width := 1
		while remaining.has(cell + Vector2i(width, 0)): width += 1
		var height := 1
		while true:
			var full := true
			for x: int in width:
				if not remaining.has(cell + Vector2i(x, height)): full = false; break
			if not full: break
			height += 1
		for y: int in height:
			for x: int in width: remaining.erase(cell + Vector2i(x, y))
		result.append(Rect2(Vector2(cell * Blob47Rules.CELL), Vector2(width, height) * Blob47Rules.CELL))
	return result

static func add_collision(parent: Node2D, cells: Dictionary) -> void:
	for rect: Rect2 in collision_rectangles(cells):
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = rect.size
		shape.shape = rectangle
		body.add_child(shape)
		parent.add_child(body)
