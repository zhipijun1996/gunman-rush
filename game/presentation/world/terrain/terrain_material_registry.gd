class_name TerrainMaterialRegistry
extends RefCounted
## Resource identity belongs to configuration; cached resources never own physics.
const PATH := "res://config/terrain_materials.json"
static var _catalog: Dictionary = {}
static var _textures: Dictionary = {}
static var _tilesets: Dictionary = {}

static func catalog() -> Dictionary:
	if _catalog.is_empty(): _catalog = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _catalog

static func known(id: String) -> bool:
	return catalog().materials.has(id)

static func definition(id: String) -> Dictionary:
	return catalog().materials.get(id, {})

static func texture(path: String) -> Texture2D:
	if not _textures.has(path): _textures[path] = load(path) as Texture2D
	return _textures[path]

static func appearance(id: String) -> Dictionary:
	var row := definition(id)
	assert(not row.is_empty(), "Unregistered terrain material: "+id)
	if not _tilesets.has(id):
		var tiles := (load(UnderworldTerrain.specification().tileset) as TileSet).duplicate(true) as TileSet
		(tiles.get_source(0) as TileSetAtlasSource).texture = texture(row.atlas)
		_tilesets[id] = tiles
	return {"id":id, "texture":texture(row.source), "tileset":_tilesets[id], "surface_y":float(row.surface_y)}

## Independent gates/concealers reuse the registry but keep their own lifecycle.
static func install_on(terrain: UnderworldTerrain, id: String) -> void:
	var selected := appearance(id)
	terrain.core_layer.tile_set = selected.tileset
	for child: Node in terrain.get_children():
		if child is ColorRect or child is Polygon2D:
			var material := (child as CanvasItem).material as ShaderMaterial
			if material == null or material.shader != UnderworldTerrain.SHADER: continue
			material.set_shader_parameter("source_pixels", selected.texture)
			material.set_shader_parameter("source_size", Vector2(selected.texture.get_size()))
