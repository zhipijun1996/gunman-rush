extends RefCounted
## Isolated fixtures for authored scenes awaiting the current area geometry.
## Tests may inspect their actual actors/terrain without opening them in the game.
static func install(app: FixedWorldApp, rid: String) -> void:
	if not app.content.room(rid).is_empty(): return
	var scene := (load("res://game/world/regions/P/rooms/"+rid+".tscn") as PackedScene).instantiate() as FixedWorldRoom
	var size := scene.start_point + Vector2(128,128)
	for platform: Rect2 in scene.platforms: size = size.max(platform.end)
	scene.free()
	var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://build/world/contracts.json"))
	for original: Dictionary in all.rooms:
		if str(original.room_id) != rid: continue
		var value := original.duplicate(true)
		value.doors = []; value.entry_spawns = []
		value.world_geometry = {"bounds_world_units":[0,0,size.x,size.y], "space_rects":[[0,0,size.x,size.y]], "boundary":[{"side":"up","from":[0,0],"to":[size.x,0]},{"side":"down","from":[0,size.y],"to":[size.x,size.y]},{"side":"left","from":[0,0],"to":[0,size.y]},{"side":"right","from":[size.x,0],"to":[size.x,size.y]}]}
		value.camera = {"profile":"bounded_follow", "zones":[], "links":[], "transition":"occluded"}
		app.content.data.rooms[rid] = value
		return
