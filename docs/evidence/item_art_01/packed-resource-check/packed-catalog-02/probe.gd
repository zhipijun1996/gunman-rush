extends SceneTree
func _initialize() -> void:
	var items := ItemCatalogV5.all_items()
	var ok := items.size() == 72
	var icon_regions: Dictionary = {}
	for item: ItemDefinition in items:
		var texture := ItemPresentation.icon(item.icon_key) as AtlasTexture
		ok = ok and texture != null and texture.atlas.resource_path.begins_with("res://assets/items/v5/") and texture.region.size.x > 0
		if texture != null: icon_regions[str(texture.atlas.resource_path)+str(texture.region)] = true
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/item_v5_art.json"))
	var frames := 0
	for key: String in registry.clips:
		var texture := ItemArtLibrary.frame_texture(StringName(key),0.0) as AtlasTexture
		if texture != null and texture.atlas != null: frames += 1
	var material := ItemArtLibrary.world_material()
	var art := ItemArtLibrary.diagnostics()
	ok = ok and icon_regions.size() == 72 and frames == 42 and material != null and material.shader != null and bool(art.valid)
	print("PACKED ITEM V5 FULL: items=",items.size()," distinct_icons=",icon_regions.size()," clips=",frames," art=",JSON.stringify(art)," passed=",ok)
	ItemArtLibrary.clear_cache()
	quit(0 if ok else 1)
