class_name PlainsEnvironmentTerrain
extends RefCounted
## Finite, constant-scale painted strata clipped to the shared natural polygon.
## This consumer never creates collision or turns a complete object into a rectangle.

static func build(solid: Dictionary, sections: Array, quiet_color: Color) -> Node2D:
	var root := Node2D.new()
	root.name = "NaturalBank_" + str(solid.id)
	var polygon := points(solid.points)
	var top := points(solid.get("paint_top", []))
	if polygon.size() < 3 or top.size() < 2 or sections.is_empty():
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
	var world_origin_y := top[0].y
	for point: Vector2 in top:
		world_origin_y = minf(world_origin_y, point.y)
	while cursor < bounds.end.x - 0.01 and page < 64:
		var spec: Dictionary = (sections[page % sections.size()] as Dictionary).duplicate(true)
		spec["world_top_polyline"] = solid.paint_top
		var path := str(spec.texture)
		var texture := load(path) as Texture2D if ResourceLoader.exists(path) else null
		if texture == null:
			break
		var ppu := float(spec.source_pixels_per_world_unit)
		var margin := float(spec.source_margin)
		var width := (texture.get_width() - margin * 2.0) / ppu
		var finish := minf(bounds.end.x, cursor + width)
		var body := mesh_data()
		var columns := maxi(1, ceili((finish - cursor) / 24.0))
		var rows := maxi(1, ceili(bounds.size.y / 28.0))
		for column: int in columns:
			for row: int in rows:
				var left := lerpf(cursor, finish, float(column) / columns)
				var right := lerpf(cursor, finish, float(column + 1) / columns)
				var upper := lerpf(bounds.position.y, bounds.end.y, float(row) / rows)
				var lower := lerpf(bounds.position.y, bounds.end.y, float(row + 1) / rows)
				var quad := PackedVector2Array([Vector2(left, upper), Vector2(right, upper), Vector2(right, lower), Vector2(left, lower)])
				for clipped: PackedVector2Array in Geometry2D.intersect_polygons(quad, polygon):
					var base: int = body.vertices.size()
					for point: Vector2 in clipped:
						# Fixed world projection: no entire-wall vertical shear by top(x).
						var uv := Vector2(margin + (point.x - cursor) * ppu, float(spec.body_source_y) + (point.y - world_origin_y - float(spec.shoulder_world_depth)) * ppu)
						var depth := point.y - surface_y(polygon, spec, point.x)
						var edge_distance := minf(point.x - edge_x(polygon, point.y, true), edge_x(polygon, point.y, false) - point.x)
						var weight := smoothstep(float(spec.shoulder_world_depth) - 20.0, float(spec.shoulder_world_depth), depth)
						weight *= smoothstep(60.0, 150.0, edge_distance)
						weight *= 1.0 - smoothstep(texture.get_height() - 64.0, texture.get_height() - 1.0, uv.y)
						body.vertices.append(point)
						body.uv.append(Vector2(uv.x, clampf(uv.y, 0, texture.get_height() - 1.0)) / texture.get_size())
						body.colors.append(Color(1, 1, 1, weight))
					for index: int in Geometry2D.triangulate_polygon(clipped):
						body.indices.append(base + index)
		install_mesh(root, body, texture, -2, "FixedWorldDeepStrata_%02d" % page)
		receipts.append({"source":path, "source_sha256":FileAccess.get_sha256(path), "world_span":[cursor, finish], "pixels_per_world_unit":ppu, "mapping":"fixed world projection; complementary finite side ribbons", "whole_object_stretched":false})
		cursor = finish
		page += 1
	_build_top_band(root, top, polygon, sections[0])
	root.set_meta("environment_terrain", {"solid_id":solid.id, "collision_points":solid.points, "visual_envelope":solid.get("visual_envelope_points", solid.points), "pages":receipts, "source_exhausted":cursor < bounds.end.x - 0.01, "top_mapping":"arc normal thin shoulder clipped to natural envelope; finite ends withdraw into complete source turns", "deep_mapping":"fixed world projection", "side_mapping":"finite original-scale source-profile ribbons; no broad wall overlay", "geometry_revised":true})
	return root

static func _build_top_band(parent: Node2D, top: PackedVector2Array, polygon: PackedVector2Array, spec: Dictionary) -> void:
	var texture := load(str(spec.texture)) as Texture2D
	var ppu := float(spec.source_pixels_per_world_unit)
	var shoulder := float(spec.shoulder_world_depth)
	var source_curve := points(spec.source_surface_profile)
	var source_lengths := cumulative(source_curve)
	var world_lengths := cumulative(top)
	var source_start := float(spec.source_margin)
	var budget := source_lengths[-1] - source_start - float(spec.source_margin)
	var data := mesh_data()
	var cursor := 0.0
	while cursor < world_lengths[-1] - 0.001:
		var next := minf(cursor + 10.0, world_lengths[-1])
		if cursor * ppu >= budget:
			push_error("Finite shoulder source exhausted: " + str(spec.texture))
			break
		var source_a := source_start + cursor * ppu
		var source_b := source_a + (next - cursor) * ppu
		if source_b > source_lengths[-1] - float(spec.source_margin):
			next = cursor + (source_lengths[-1] - float(spec.source_margin) - source_a) / ppu
			source_b = source_lengths[-1] - float(spec.source_margin)
		var world_a := curve_frame(top, world_lengths, cursor)
		var world_b := curve_frame(top, world_lengths, next)
		var source_frame_a := curve_frame(source_curve, source_lengths, source_a)
		var source_frame_b := curve_frame(source_curve, source_lengths, source_b)
		var depths: Array[float] = [-float(spec.back_world_depth), 0.0, 24.0, shoulder - 20.0, shoulder]
		for row: int in depths.size() - 1:
			var quad := PackedVector2Array()
			var uv := PackedVector2Array()
			var opacity := PackedFloat32Array()
			for corner: int in 4:
				var right := corner in [1, 2]
				var depth: float = depths[row + 1] if corner >= 2 else depths[row]
				var world: Dictionary = world_b if right else world_a
				var source: Dictionary = source_frame_b if right else source_frame_a
				quad.append((world.point as Vector2) + (world.normal as Vector2) * depth)
				uv.append(((source.point as Vector2) + (source.normal as Vector2) * depth * ppu) / texture.get_size())
				var arc := next if right else cursor
				var end_distance := minf(arc, world_lengths[-1] - arc)
				var weight := 1.0 - smoothstep(shoulder - 20.0, shoulder, depth)
				# At a real end the complete natural turn owns the shoulder.
				# Keep the zero-depth standing line, withdraw deeper cap paint.
				if depth < 0.0:
					weight *= smoothstep(0.0, 70.0, end_distance)
				else:
					weight *= lerpf(1.0, smoothstep(0.0, 120.0, end_distance), smoothstep(0.0, 24.0, depth))
				opacity.append(weight)
			append_top_quad(data, quad, uv, opacity, polygon, depths[row] >= 0.0)
		cursor = maxf(next, cursor + 0.001)
	install_mesh(parent, data, texture, -1, "ArcNormalGrassAndRootShoulder")

static func append_top_quad(data: Dictionary, quad: PackedVector2Array, uv: PackedVector2Array, opacity: PackedFloat32Array, polygon: PackedVector2Array, clip: bool) -> void:
	for indices: Array in [[0, 1, 2], [0, 2, 3]]:
		var triangle := PackedVector2Array([quad[indices[0]], quad[indices[1]], quad[indices[2]]])
		var denominator := (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0])
		if absf(denominator) < 0.00001:
			continue
		var pieces: Array[PackedVector2Array] = []
		if clip:
			pieces = Geometry2D.intersect_polygons(triangle, polygon)
		else:
			pieces.append(triangle)
		for piece: PackedVector2Array in pieces:
			var base: int = data.vertices.size()
			for point: Vector2 in piece:
				var relative := point - triangle[0]
				var b := relative.cross(triangle[2] - triangle[0]) / denominator
				var c := (triangle[1] - triangle[0]).cross(relative) / denominator
				var a := 1.0 - b - c
				data.vertices.append(point)
				data.uv.append(uv[indices[0]] * a + uv[indices[1]] * b + uv[indices[2]] * c)
				data.colors.append(Color(1, 1, 1, opacity[indices[0]] * a + opacity[indices[1]] * b + opacity[indices[2]] * c))
			for index: int in Geometry2D.triangulate_polygon(piece):
				data.indices.append(base + index)

static func cumulative(line: PackedVector2Array) -> PackedFloat32Array:
	var result := PackedFloat32Array([0.0])
	for index: int in line.size() - 1:
		result.append(result[-1] + line[index].distance_to(line[index + 1]))
	return result

static func curve_frame(line: PackedVector2Array, lengths: PackedFloat32Array, distance: float) -> Dictionary:
	for index: int in line.size() - 1:
		if distance <= lengths[index + 1] or index == line.size() - 2:
			var t := clampf((distance - lengths[index]) / maxf(0.001, lengths[index + 1] - lengths[index]), 0, 1)
			var tangent := vertex_tangent(line, index).lerp(vertex_tangent(line, index + 1), t).normalized()
			return {"point":line[index].lerp(line[index + 1], t), "normal":Vector2(-tangent.y, tangent.x)}
	return {"point":line[-1], "normal":Vector2.DOWN}

static func vertex_tangent(line: PackedVector2Array, index: int) -> Vector2:
	if index == 0:
		return (line[1] - line[0]).normalized()
	if index == line.size() - 1:
		return (line[-1] - line[-2]).normalized()
	return ((line[index] - line[index - 1]).normalized() + (line[index + 1] - line[index]).normalized()).normalized()

static func edge_x(polygon: PackedVector2Array, y: float, left: bool) -> float:
	var xs: Array[float] = []
	for index: int in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
			xs.append(lerpf(a.x, b.x, (y - a.y) / (b.y - a.y)))
	if xs.is_empty():
		return polygon_bounds(polygon).position.x if left else polygon_bounds(polygon).end.x
	xs.sort()
	return xs[0] if left else xs[-1]

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
