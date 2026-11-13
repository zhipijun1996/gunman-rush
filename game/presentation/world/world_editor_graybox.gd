class_name WorldEditorGraybox
extends Node2D
## Presentation only. The normal room still owns every collision and mechanic.
var room: FixedWorldRoom
func _ready() -> void:
	z_index = -2
	queue_redraw()
func _draw() -> void:
	var bounds := FixedWorldProvider.rect(room.contract.world_geometry.bounds_world_units)
	draw_rect(bounds.grow(512), Color("14202b"))
	for index: int in room.platforms.size():
		var platform: Rect2 = room.platforms[index]
		if index in room.one_way_indices: draw_line(platform.position, Vector2(platform.end.x,platform.position.y), Color("d4c59e"), 4)
		else:
			draw_rect(platform, Color("405b65"))
			draw_line(platform.position, Vector2(platform.end.x,platform.position.y), Color("88b1b4"), 2)
	for raw: Dictionary in room.terrain_polygons:
		var points := PackedVector2Array()
		for point: Array in raw.points: points.append(FixedWorldProvider.point(point))
		draw_colored_polygon(points, Color("405b65"))
