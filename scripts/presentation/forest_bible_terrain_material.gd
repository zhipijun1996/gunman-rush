class_name ForestBibleTerrainMaterial
extends RefCounted
## Forest material extension of the same 47-tile / exact-boundary family.
## Owns no geometry, collision, masks, neighbors, or shader implementation.
const SOURCE: Texture2D = preload("res://assets/forest_bible_v2/native/bark_source_v3.png")
const ATLAS: Texture2D = preload("res://assets/forest_bible_v2/native/bark_atlas47_v3.png")

static func install_on(terrain: UnderworldTerrain) -> bool:
	if not is_instance_valid(terrain) or not is_instance_valid(terrain.core_layer): return false
	if SOURCE.get_size() != Vector2(176, 144) or ATLAS.get_size() != Vector2(128, 96): return false
	var original: TileSet = terrain.core_layer.tile_set
	if original == null or original.tile_size != Vector2i(16, 16): return false
	if not original.has_source(0) or not original.get_source(0) is TileSetAtlasSource: return false
	# Validate every adapter consumer before changing either material path.
	var adapters: Array[ColorRect] = []
	for child: Node in terrain.get_children():
		if not child is ColorRect: continue
		var quad := child as ColorRect
		if not quad.material is ShaderMaterial: return false
		var material := quad.material as ShaderMaterial
		if material.shader != UnderworldTerrain.SHADER: return false
		if material.get_shader_parameter("source_size") != Vector2(176, 144): return false
		adapters.append(quad)
	var tiles: TileSet = original.duplicate(true) as TileSet
	var atlas: TileSetAtlasSource = tiles.get_source(0) as TileSetAtlasSource
	atlas.texture = ATLAS
	terrain.core_layer.tile_set = tiles
	for quad: ColorRect in adapters:
		var material: ShaderMaterial = quad.material.duplicate() as ShaderMaterial
		material.set_shader_parameter("source_pixels", SOURCE)
		quad.material = material
	return true
