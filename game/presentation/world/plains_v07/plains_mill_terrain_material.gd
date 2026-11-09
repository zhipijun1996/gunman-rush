class_name PlainsMillTerrainMaterial
extends RefCounted
## Windmill masonry reuses the existing exact-boundary geometry and lighting.
const SOURCE: Texture2D=preload("res://assets/plains_v07/native/mill_masonry_source.png")
const ATLAS: Texture2D=preload("res://assets/plains_v07/native/mill_masonry_atlas47.png")
static func install_on(terrain: UnderworldTerrain) -> void:
	var tiles:=terrain.core_layer.tile_set.duplicate(true) as TileSet
	var atlas:=tiles.get_source(0) as TileSetAtlasSource
	atlas.texture=ATLAS;terrain.core_layer.tile_set=tiles
	for child: Node in terrain.get_children():
		if child is ColorRect or child is Polygon2D:
			var material: ShaderMaterial=(child as CanvasItem).material as ShaderMaterial
			material.set_shader_parameter("source_pixels",SOURCE)
			material.set_shader_parameter("source_size",Vector2(SOURCE.get_size()))
