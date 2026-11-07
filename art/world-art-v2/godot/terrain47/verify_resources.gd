extends SceneTree
## Focused terrain resource and engine autotile tests. No gameplay or full-project CI.

var failures: Array = []
var manifest: Dictionary
const DELTAS := [Vector2i(0,-1),Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(-1,-1)]

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://terrain47/manifest.json"))
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://terrain47/all47-fixture.json"))
	var cells: Array[Vector2i] = []
	for c in fixture.cells:
		cells.append(Vector2i(c[0], c[1]))
	var region_results: Array = []
	for region_id in manifest.regions:
		var region: Dictionary = manifest.regions[region_id]
		var tileset: TileSet = load(region.godotResource)
		check(tileset != null, region_id + ": resource exists")
		if tileset == null:
			continue
		check(tileset.tile_size == Vector2i(32, 32), region_id + ": native32 tile size")
		check(tileset.get_terrain_set_mode(0) == TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES, region_id + ": corner and side terrain mode")
		var source: TileSetAtlasSource = tileset.get_source(0)
		check(source.get_tiles_count() == 47, region_id + ": exactly47 tiles")
		for raw_mask in manifest.masks:
			var mask := int(raw_mask)
			var coord: Array = region.maskToAtlas[str(mask)]
			var data := source.get_tile_data(Vector2i(coord[0], coord[1]), 0)
			check(data.terrain_set == 0 and data.terrain == 0, region_id + ": terrain ids " + str(mask))
			check(data.get_custom_data("blob_mask") == mask, region_id + ": mask custom data " + str(mask))
			check(data.get_collision_polygons_count(0) == 1, region_id + ": full-cell collision " + str(mask))
			for direction in manifest.bitOrder:
				var expected := 0 if mask & int(manifest.bitOrder[direction]) else -1
				var actual := data.get_terrain_peering_bit(int(manifest.godotPeeringBits[direction].enum))
				check(actual == expected, region_id + ": bit " + direction + " of " + str(mask))
		var layer := TileMapLayer.new()
		layer.tile_set = tileset
		layer.collision_enabled = false
		root.add_child(layer)
		layer.set_cells_terrain_connect(cells, 0, 0, false)
		var matched := 0
		for target in fixture.centers:
			var cell := Vector2i(target.cell[0], target.cell[1])
			var data := layer.get_cell_tile_data(cell)
			var selected := int(data.get_custom_data("blob_mask")) if data else -1
			if selected == int(target.mask):
				matched += 1
			else:
				failures.append(region_id + ": engine selected " + str(selected) + " for fixture mask " + str(int(target.mask)))
		region_results.append({"region": region_id, "resourceTiles": source.get_tiles_count(), "engineFixtureMatches": matched})
		layer.free()
	# Exercise all raw diagonal combinations once; 16 sets share the same peering contract.
	var first_region: Dictionary = manifest.regions[manifest.regions.keys()[0]]
	var probe := TileMapLayer.new()
	probe.tile_set = load(first_region.godotResource)
	probe.collision_enabled = false
	root.add_child(probe)
	var normalized_matches := 0
	for raw_mask in range(256):
		probe.clear()
		var neighborhood: Array[Vector2i] = [Vector2i.ZERO]
		for index in range(8):
			if raw_mask & (1 << index):
				neighborhood.append(DELTAS[index])
		probe.set_cells_terrain_connect(neighborhood, 0, 0, false)
		var data := probe.get_cell_tile_data(Vector2i.ZERO)
		var selected := int(data.get_custom_data("blob_mask")) if data else -1
		var expected := int(manifest.normalizeTable[raw_mask])
		if selected == expected:
			normalized_matches += 1
		else:
			failures.append("raw " + str(raw_mask) + ": engine " + str(selected) + " expected " + str(expected))
	probe.free()
	var report := {"status": "passed" if failures.is_empty() else "failed", "godotVersion": Engine.get_version_info(),
		"regionCount": region_results.size(), "tileCount": region_results.size() * 47,
		"allRawMaskEngineMatches": normalized_matches, "regions": region_results, "failures": failures,
		"scope": "Headless resource import, terrain peering bits, full-cell collision, native engine terrain selection. No GPU or artistic quality claim."}
	var file := FileAccess.open("res://terrain47/godot-validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify({"status": report.status, "regions": region_results.size(), "rawMaskMatches": normalized_matches, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
