class_name TerrainGeometry
extends RefCounted
## A read-only shared union. Material partitions never become collision sources.
static func plan(solids: Array[Rect2], polygons: Array[Dictionary]) -> Dictionary:
	var result := UnderworldTerrain.geometry_plan(solids)
	var shapes: Array[PackedVector2Array] = []
	for rect: Rect2 in result.pieces: shapes.append(UnderworldPolygonTerrain.rectangle_points(rect))
	for row: Dictionary in polygons:
		var points := PackedVector2Array()
		for pair: Array in row.points: points.append(Vector2(float(pair[0]), float(pair[1])))
		shapes.append(UnderworldPolygonTerrain.clockwise(points))
	if not polygons.is_empty(): result.edges = UnderworldPolygonTerrain.boundary(shapes)
	result["has_polygons"] = not polygons.is_empty()
	result["areas"] = cell_areas(result.pieces)
	result["shapes"] = shapes
	result["corners"] = UnderworldTerrain._corners(result.edges, result.pieces) if polygons.is_empty() else PackedVector4Array()
	return result

static func paint_rect(groups: Array[Dictionary], region: Rect2, material_id: String, bare := false) -> void:
	var painted: Array[Rect2] = []
	var painted_polygons: Array[Dictionary] = []
	for group: Dictionary in groups:
		for solid: Rect2 in group.solids:
			var part := solid.intersection(region)
			if part.has_area(): painted.append(part)
		var typed_solids: Array[Rect2] = []; typed_solids.assign(group.solids)
		group.solids = WorldRoomSpace.exposed_parts(typed_solids, [region])
		var outside: Array[Dictionary] = []
		for polygon: Dictionary in group.polygons:
			var points := PackedVector2Array()
			for pair: Array in polygon.points: points.append(Vector2(float(pair[0]), float(pair[1])))
			var box := UnderworldPolygonTerrain.bounds(points)
			var hit := box.intersection(region)
			if not hit.has_area(): outside.append(polygon); continue
			# Intersect triangles with disjoint rectangles; unlike polygon subtraction
			# this cannot return an inner contour mistaken for a filled island.
			var triangles := Geometry2D.triangulate_polygon(points)
			var remainder := WorldRoomSpace.exposed_parts([box], [region])
			for index: int in range(0, triangles.size(), 3):
				var triangle := PackedVector2Array([points[triangles[index]], points[triangles[index+1]], points[triangles[index+2]]])
				for clip: Rect2 in remainder:
					_append_intersections(outside, triangle, clip)
				_append_intersections(painted_polygons, triangle, hit)
		group.polygons = outside
	if not painted.is_empty() or not painted_polygons.is_empty():
		groups.append({"material_id":material_id, "solids":painted, "polygons":painted_polygons, "bare":bare})

static func _append_intersections(target: Array[Dictionary], points: PackedVector2Array, clip: Rect2) -> void:
	for shape: PackedVector2Array in Geometry2D.intersect_polygons(points, UnderworldPolygonTerrain.rectangle_points(clip)):
		if shape.size() < 3: continue
		var pairs: Array = []
		for point: Vector2 in shape: pairs.append([point.x, point.y])
		target.append({"points":pairs})

static func cell_areas(pieces: Array[Rect2]) -> Dictionary:
	var areas: Dictionary = {}
	for rect: Rect2 in pieces:
		for y: int in range(floori(rect.position.y/32),ceili(rect.end.y/32)):
			for x: int in range(floori(rect.position.x/32),ceili(rect.end.x/32)):
				var key := Vector2i(x,y)
				areas[key] = float(areas.get(key,0.0))+rect.intersection(Rect2(Vector2(key*32),Vector2(32,32))).get_area()
	return areas
