class_name StyleTerrain
extends RefCounted
## Shared blob neighborhood rules; a real TileSet and TileMapLayer per candidate.
const STYLES := ["retro", "basic", "scribble", "underworld", "cavern"]

static func atlas_path(style_id: String) -> String:
	assert(style_id in STYLES)
	return "res://assets/style_exploration/%s/terrain.png" % style_id

static func create_tileset(style_id: String) -> TileSet:
	var saved_path := "res://assets/style_exploration/%s/terrain.tres" % style_id
	if ResourceLoader.exists(saved_path):
		return (load(saved_path) as TileSet).duplicate(true) as TileSet
	var atlas := load(atlas_path(style_id)) as Texture2D
	assert(atlas != null, "Missing comparison terrain: " + style_id)
	assert(atlas.get_width() % 8 == 0 and atlas.get_height() == atlas.get_width() / 8 * 6, "Atlas must be 8 columns by 6 rows without gutters")
	var tile_size := atlas.get_width() / 8
	var source := TileSetAtlasSource.new()
	source.texture = atlas
	source.texture_region_size = Vector2i.ONE * tile_size
	for mask: int in Blob47Rules.catalog_masks(): source.create_tile(Blob47Rules.atlas_coords(mask))
	var result := TileSet.new()
	result.tile_size = Vector2i.ONE * tile_size
	result.add_source(source, 0)
	return result

static func build(cells: Dictionary, style_id: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = "ComparisonSolid47"
	layer.tile_set = create_tileset(style_id)
	layer.scale = Vector2.ONE * float(StyleLayout.CELL) / layer.tile_set.tile_size.x
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for cell: Vector2i in cells:
		layer.set_cell(cell, 0, Blob47Rules.atlas_coords(Blob47Rules.mask_at(cells, cell)))
	return layer

static func change_style(layer: TileMapLayer, style_id: String) -> void:
	# Source coordinates and collision remain untouched when comparing art.
	layer.tile_set = create_tileset(style_id)
	layer.scale = Vector2.ONE * float(StyleLayout.CELL) / layer.tile_set.tile_size.x

static func add_collision(parent: Node2D, cells: Dictionary) -> void:
	Blob47Terrain.add_collision(parent, cells)
