class_name RegionThresholdMaterial
extends RefCounted
## Regional source pixels on the existing geometry/lighting renderer; owns no collision.
static func install_on(terrain: UnderworldTerrain, family: String) -> void:
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/world-art-v2/assets/terrain47/manifest.json"))
	terrain.position.y=-float(catalog.regions[family].surfaceY)
	var root := "res://assets/region_thresholds/native/"+family
	var source := load(root+"_source.png") as Texture2D
	var atlas_texture := load(root+"_atlas47.png") as Texture2D
	var tiles := terrain.core_layer.tile_set.duplicate(true) as TileSet
	var atlas := tiles.get_source(0) as TileSetAtlasSource
	atlas.texture=atlas_texture;terrain.core_layer.tile_set=tiles
	for child: Node in terrain.get_children():
		if child is ColorRect or child is Polygon2D:
			var shader_material := (child as CanvasItem).material as ShaderMaterial
			shader_material.set_shader_parameter("source_pixels",source)
			shader_material.set_shader_parameter("source_size",Vector2(source.get_size()))
