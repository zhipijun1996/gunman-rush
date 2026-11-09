extends SceneTree
## Generate real Godot TileSet terrain peering data from the shared blob47 contract.
## Run after PNG import: godot --headless --path godot --script res://terrain47/build_resources.gd

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://terrain47/manifest.json"))
	var resource_count := 0
	for region_id in manifest.regions:
		var region: Dictionary = manifest.regions[region_id]
		var tileset := TileSet.new()
		tileset.tile_size = Vector2i(32, 32)
		tileset.add_terrain_set()
		tileset.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
		tileset.add_terrain(0)
		tileset.set_terrain_name(0, 0, region.name)
		tileset.set_terrain_color(0, 0, Color(0.35, 0.66, 0.53))
		tileset.add_physics_layer()
		tileset.set_physics_layer_collision_layer(0, 1)
		tileset.set_physics_layer_collision_mask(0, 1)
		tileset.add_custom_data_layer()
		tileset.set_custom_data_layer_name(0, "blob_mask")
		tileset.set_custom_data_layer_type(0, TYPE_INT)
		var source := TileSetAtlasSource.new()
		source.texture = load(region.godotTexture)
		assert(source.texture != null, "Import the terrain47 PNG files before building resources.")
		source.texture_region_size = Vector2i(32, 32)
		tileset.add_source(source, 0)
		for raw_mask in manifest.masks:
			var mask := int(raw_mask)
			var coord: Array = region.maskToAtlas[str(mask)]
			var atlas_coord := Vector2i(coord[0], coord[1])
			source.create_tile(atlas_coord)
			var data := source.get_tile_data(atlas_coord, 0)
			data.terrain_set = 0
			data.terrain = 0
			data.set_custom_data("blob_mask", mask)
			for direction in manifest.bitOrder:
				var bit := int(manifest.bitOrder[direction])
				var peer := int(manifest.godotPeeringBits[direction].enum)
				assert(data.is_valid_terrain_peering_bit(peer))
				data.set_terrain_peering_bit(peer, 0 if mask & bit else -1)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]))
		var err := ResourceSaver.save(tileset, region.godotResource)
		assert(err == OK, "TileSet save failed for " + region_id)
		resource_count += 1
	print(JSON.stringify({"generatedTileSets": resource_count, "tiles": resource_count * 47}))
	quit(0)
