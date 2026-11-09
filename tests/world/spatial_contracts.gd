extends SceneTree
## Concave collision, camera chambers and the map must describe one room.
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: ",label)
func _initialize() -> void:
	var content := FixedWorldProvider.new()
	check(content.open(),"compiled physical region loads")
	for id: String in content.data.rooms:
		var room := content.room(id)
		var doors: Array = []
		for door: Dictionary in room.doors:
			if not content.room(door.target_room).is_empty(): doors.append(door)
		var solids := WorldRoomSpace.boundary_platforms(room.world_geometry,doors)
		for door: Dictionary in doors:
			var point := FixedWorldProvider.point(door.position_candidate.local_world_units)
			var aperture := Rect2(point+Vector2(-12,-90),Vector2(24,84)) if door.direction in ["left","right"] else Rect2(point-Vector2(58,12),Vector2(116,24))
			for solid: Rect2 in solids: check(not solid.intersects(aperture),id+" open physical aperture "+door.id)
		check(room.camera.profile in ["bounded_follow","horizontal_follow","vertical_follow","fixed_arena"],id+" formal camera template")
	print("WORLD SPACE: ",failures," failures")
	quit(failures)
