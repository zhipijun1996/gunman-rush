class_name PlainsArchitecturalFacing
extends RefCounted
## An authored cutaway shares UVs across the rear recess and real solid faces.
## Geometry remains owned by the room; the painting cannot add collision.
static func attach(art: PlainsRoomArt, rear: Sprite2D, placement: Dictionary) -> void:
	var origin := rear.position + rear.offset
	var image_bounds := Rect2(origin, rear.texture.get_size())
	var contours: Array[PackedVector2Array] = []
	for row: Dictionary in art.room.terrain_polygons:
		if str(row.id) in placement.facing_polygons:
			var points := PackedVector2Array()
			for pair: Array in row.points: points.append(FixedWorldProvider.point(pair))
			contours.append(points)
	var indices: Array = placement.get("facing_platforms", []).duplicate()
	for id: String in placement.get("facing_platform_ids", []): indices.append(art.room.platform_index(id))
	for index: int in indices:
		var area := art.room.platforms[index].intersection(image_bounds)
		if area.has_area():
			contours.append(PackedVector2Array([area.position, Vector2(area.end.x,area.position.y), area.end, Vector2(area.position.x,area.end.y)]))
	if placement.get("facing_boundary",false):
		for wall: Rect2 in art.room.boundary_art_rock:
			var area:=wall.intersection(image_bounds)
			if area.has_area():
				contours.append(PackedVector2Array([area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)]))
	for points: PackedVector2Array in contours:
		var face := Polygon2D.new()
		face.name = "ArchitecturalFace"
		face.polygon = points
		var uv := PackedVector2Array()
		for point: Vector2 in points: uv.append(point-origin)
		face.uv = uv
		face.texture = rear.texture
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		face.z_index = 1
		art.add_child(face)
	# The rear painting is visible only inside the actual walkable recess. Its
	# generated silhouette must not invent extra solid-looking space outside it.
	var recess := FixedWorldProvider.rect(placement.facing_recess)
	rear.region_enabled = true
	rear.region_rect = Rect2(recess.position-origin,recess.size)
	rear.position = recess.position
	rear.offset = Vector2.ZERO
