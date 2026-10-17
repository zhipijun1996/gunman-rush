class_name PlainsEnvironmentTerrain
extends RefCounted
## Finite, constant-scale painted strata clipped to the shared natural polygon.
## This consumer never creates collision or turns a complete object into a rectangle.

static func build(solid: Dictionary, sections: Array, quiet_color: Color) -> Node2D:
	var root := Node2D.new()
	root.name = "NaturalBank_" + str(solid.id)
	var polygon := points(solid.points)
	if polygon.size() < 3:
		root.free()
		return null
	var fill := Polygon2D.new()
	fill.polygon = polygon
	fill.color = quiet_color
	fill.z_as_relative = false
	fill.z_index = -3
	root.add_child(fill)
	var bounds := polygon_bounds(polygon)
	var cursor := bounds.position.x
	var page := 0
	var receipts: Array[Dictionary] = []
	while cursor < bounds.end.x - 0.01 and page < 64:
		if sections.is_empty():
			break
		var spec: Dictionary = (sections[page % sections.size()] as Dictionary).duplicate(true)
		spec["world_top_polyline"] = solid.get("paint_top", [])
		var path := str(spec.get("texture", ""))
		var texture := load(path) as Texture2D if ResourceLoader.exists(path) else null
		if texture == null:
			break
		var ppu := float(spec.get("source_pixels_per_world_unit", 1.0))
		if ppu <= 0.0:
			break
		var margin := float(spec.get("source_margin", 16.0))
		var overlap := float(spec.get("overlap_world", 32.0)) if page > 0 else 0.0
		var width := (texture.get_width() - margin * 2.0) / ppu
		if width <= overlap + 1.0:
			break
		var finish := minf(bounds.end.x, cursor + width)
		var data := mesh_data()
		var columns := maxi(1, ceili((finish - cursor) / 20.0))
		for column: int in columns:
			var left := lerpf(cursor, finish, float(column) / columns)
			var right := lerpf(cursor, finish, float(column + 1) / columns)
			var top_left := surface_y(polygon, spec, left + 0.001)
			var top_right := surface_y(polygon, spec, right - 0.001)
			var minimum := minf(top_left, top_right)
			var rows := maxi(1, ceili((bounds.end.y - minimum) / 28.0))
			for row: int in rows:
				var upper := lerpf(minimum, bounds.end.y, float(row) / rows)
				var lower := lerpf(minimum, bounds.end.y, float(row + 1) / rows)
				var quad := PackedVector2Array([Vector2(left, upper), Vector2(right, upper), Vector2(right, lower), Vector2(left, lower)])
				for clipped: PackedVector2Array in Geometry2D.intersect_polygons(quad, polygon):
					append_piece(data, clipped, polygon, cursor, margin, ppu, texture.get_size(), spec, overlap)
		install_mesh(root, data, texture, -2, "FiniteStrata_%02d" % page)
		# The grass/upper plane is sampled at the same finite local scale. Its
		# geometry follows the real standing edge; it is not a second platform.
		var grass := mesh_data()
		var back := float(spec.get("back_world_depth", 24.0))
		for column: int in (columns if bool(solid.get("paint_grass", true)) else 0):
			var left := lerpf(cursor, finish, float(column) / columns)
			var right := lerpf(cursor, finish, float(column + 1) / columns)
			var top_line: Array = spec.world_top_polyline
			if top_line.size() >= 2:
				left = maxf(left, float(top_line[0][0]))
				right = minf(right, float(top_line[-1][0]))
			if right <= left:
				continue
			var a := Vector2(left, surface_y(polygon, spec, left + 0.001))
			var b := Vector2(right, surface_y(polygon, spec, right - 0.001))
			var quad := PackedVector2Array([a - Vector2(0, back), b - Vector2(0, back), b + Vector2(0, 1), a + Vector2(0, 1)])
			append_piece(grass, quad, polygon, cursor, margin, ppu, texture.get_size(), spec, overlap)
		install_mesh(root, grass, texture, -1, "PaintedGrass_%02d" % page)
		receipts.append({"source":path, "source_sha256":FileAccess.get_sha256(path), "world_span":[cursor, finish], "pixels_per_world_unit":ppu, "whole_object_stretched":false, "overlap_world":overlap})
		if finish >= bounds.end.x - 0.01:
			cursor = finish
			break
		cursor = finish - minf(float(spec.get("overlap_world", 32.0)), width * 0.2)
		page += 1
	root.set_meta("environment_terrain", {"solid_id":solid.id, "collision_points":solid.points, "natural_boundary":"shared plan polygon", "pages":receipts, "source_exhausted":cursor < bounds.end.x - 0.01, "quiet_fill":"declared source-family inner color; no invented strata", "collision_changed":false})
	return root

static func append_piece(data: Dictionary, polygon: PackedVector2Array, outline: PackedVector2Array, page_start: float, margin: float, ppu: float, texture_size: Vector2, spec: Dictionary, overlap: float) -> void:
	if polygon.size() < 3:
		return
	var base: int = data.vertices.size()
	for point: Vector2 in polygon:
		var sx := margin + (point.x - page_start) * ppu
		var surface := source_surface(spec, sx)
		var depth := point.y - surface_y(outline, spec, point.x)
		var sy := surface + depth * ppu
		# An exhausted painted depth fades to the declared quiet inner fill.
		# It never stretches the final source row into a long stripe.
		var bottom_fade := 1.0 - smoothstep(texture_size.y - 64.0, texture_size.y - 1.0, sy)
		var side_fade := smoothstep(page_start, page_start + overlap, point.x) if overlap > 0.0 else 1.0
		data.vertices.append(point)
		data.uv.append(Vector2(sx, clampf(sy, 0.0, texture_size.y - 1.0)) / texture_size)
		data.colors.append(Color(1, 1, 1, bottom_fade * side_fade))
	for index: int in Geometry2D.triangulate_polygon(polygon):
		data.indices.append(base + index)

static func source_surface(spec: Dictionary, x: float) -> float:
	var profile: Array = spec.get("source_surface_profile", [])
	if profile.is_empty():
		return float(spec.get("source_surface_y", 256.0))
	for index: int in profile.size() - 1:
		var a: Array = profile[index]
		var b: Array = profile[index + 1]
		if x <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), clampf((x - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])), 0.0, 1.0))
	return float(profile[-1][1])

static func surface_y(outline: PackedVector2Array, spec: Dictionary, x: float) -> float:
	var line: Array = spec.get("world_top_polyline", [])
	if line.size() < 2:
		return top_y(outline, x)
	for index: int in line.size() - 1:
		var a: Array = line[index]
		var b: Array = line[index + 1]
		if x <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), clampf((x - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])), 0.0, 1.0))
	return float(line[-1][1])

static func top_y(polygon: PackedVector2Array, x: float) -> float:
	var bounds := polygon_bounds(polygon)
	var sample_x := clampf(x, bounds.position.x + 0.001, bounds.end.x - 0.001)
	var result := INF
	for index: int in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		if absf(a.x - b.x) < 0.0001:
			continue
		if sample_x >= minf(a.x, b.x) and sample_x <= maxf(a.x, b.x):
			result = minf(result, lerpf(a.y, b.y, (sample_x - a.x) / (b.x - a.x)))
	return result if is_finite(result) else bounds.position.y

static func mesh_data() -> Dictionary:
	return {"vertices":PackedVector2Array(), "uv":PackedVector2Array(), "indices":PackedInt32Array(), "colors":PackedColorArray()}

static func install_mesh(parent: Node2D, data: Dictionary, texture: Texture2D, order: int, label: String) -> void:
	if data.indices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.vertices
	arrays[Mesh.ARRAY_TEX_UV] = data.uv
	arrays[Mesh.ARRAY_INDEX] = data.indices
	arrays[Mesh.ARRAY_COLOR] = data.colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	var node := MeshInstance2D.new()
	node.name = label
	node.mesh = mesh
	node.texture = texture
	node.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	node.z_as_relative = false
	node.z_index = order
	parent.add_child(node)

static func points(raw: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Array in raw:
		result.append(Vector2(point[0], point[1]))
	return result

static func polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	var result := Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon:
		result = result.expand(point)
	return result
