@tool
extends TileMapLayer
## Same 8-neighbour masks as the Canvas renderer. Source PNGs remain untouched.

@export var region_id := "windchime_plains"

static func normalized_mask(value: int) -> int:
	var mask := value
	if (mask & 1) == 0 or (mask & 4) == 0:
		mask &= ~2
	if (mask & 4) == 0 or (mask & 16) == 0:
		mask &= ~8
	if (mask & 16) == 0 or (mask & 64) == 0:
		mask &= ~32
	if (mask & 64) == 0 or (mask & 1) == 0:
		mask &= ~128
	return mask

func _ready() -> void:
	if not FileAccess.file_exists("res://assets/terrain47-manifest.json"):
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/study.json"))
	var atlases: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/terrain47-manifest.json"))
	var grid: Dictionary = data.get("terrainGrid", {})
	for region in data.get("regions", []):
		if str(region["id"]) == region_id:
			grid = region.get("terrainGrid", grid)
			break
	if grid.is_empty() or not atlases.get("regions", {}).has(region_id):
		return
	var spec: Dictionary = atlases["regions"][region_id]
	var occupied := {}
	for cell in grid["cells"]:
		occupied[Vector2i(int(cell[0]), int(cell[1]))] = true
	var directions := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]
	clear()
	for cell: Vector2i in occupied:
		var mask := 0
		for i in directions.size():
			if occupied.has(cell + directions[i]):
				mask |= 1 << i
		mask = normalized_mask(mask)
		var atlas: Array = spec["maskToAtlas"][str(mask)]
		set_cell(cell, int(spec.get("sourceId", 0)), Vector2i(int(atlas[0]), int(atlas[1])))
	update_internals()
