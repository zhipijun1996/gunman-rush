class_name UnderworldPolygonTerrain
extends RefCounted
## Exact polygon silhouettes, sampled from the same native Underworld source.
## Boundary clipping removes grass/wall strips buried inside adjoining solids.
static func clockwise(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	var area := 0.0
	for index: int in result.size():
		var a := result[index]
		var b := result[(index+1) % result.size()]
		area += a.x*b.y-b.x*a.y
	# Screen coordinates point down: positive signed area is the same orientation
	# as the existing rectangle adapter (top edge travels left to right).
	if area < 0.0: result.reverse()
	return result

static func rectangle_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])

static func bounds(points: PackedVector2Array) -> Rect2:
	var result := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points: result = result.expand(point)
	return result

static func surface_below(pairs: Array, point: Vector2) -> float:
	var shape := PackedVector2Array()
	for pair: Array in pairs: shape.append(Vector2(float(pair[0]), float(pair[1])))
	shape = clockwise(shape)
	var result := INF
	for index: int in shape.size():
		var a := shape[index]
		var b := shape[(index+1) % shape.size()]
		if b.x <= a.x or point.x < a.x or point.x > b.x: continue
		var y := lerpf(a.y, b.y, (point.x-a.x)/(b.x-a.x))
		if y >= point.y: result = minf(result, y)
	return result

static func inside(shapes: Array[PackedVector2Array], point: Vector2) -> bool:
	for shape: PackedVector2Array in shapes:
		if Geometry2D.is_point_in_polygon(point, shape): return true
	return false

static func boundary(shapes: Array[PackedVector2Array]) -> PackedVector4Array:
	var edges: Array[Dictionary] = []
	for shape: PackedVector2Array in shapes:
		for index: int in shape.size():
			var a := shape[index]
			var b := shape[(index+1) % shape.size()]
			edges.append({"a":a, "b":b})
	var result := PackedVector4Array()
	var seen: Dictionary = {}
	for edge: Dictionary in edges:
		var a: Vector2 = edge.a
		var b: Vector2 = edge.b
		var direction := b-a
		var length_squared := direction.length_squared()
		if length_squared < 0.001: continue
		var cuts: Array[float] = [0.0, 1.0]
		for other: Dictionary in edges:
			var hit: Variant = Geometry2D.segment_intersects_segment(a, b, other.a, other.b)
			if hit != null: cuts.append(clampf(((hit as Vector2)-a).dot(direction)/length_squared, 0.0, 1.0))
			# Collinear overlaps also need cuts; segment_intersects_segment returns
			# null for those, and ignoring them would expose a buried seam.
			for endpoint: Vector2 in [other.a, other.b]:
				var t := (endpoint-a).dot(direction)/length_squared
				if t > 0.0 and t < 1.0 and absf(direction.cross(endpoint-a)) < 0.01: cuts.append(t)
		cuts.sort()
		var outward := Vector2(direction.y, -direction.x).normalized()
		for index: int in cuts.size()-1:
			if cuts[index+1]-cuts[index] < 0.000001: continue
			var start := a+direction*cuts[index]
			var end := a+direction*cuts[index+1]
			var middle := (start+end)*0.5
			if inside(shapes, middle+outward*0.05): continue
			var key := "%0.4f,%0.4f,%0.4f,%0.4f" % [start.x, start.y, end.x, end.y]
			if seen.has(key): continue
			seen[key] = true
			result.append(Vector4(start.x, start.y, end.x, end.y))
	return result

static func install(node: Node2D, solids: Array[Rect2], polygons: Array[Dictionary], spec: Dictionary, texture: Texture2D, shader: Shader) -> void:
	var shapes: Array[PackedVector2Array] = []
	for rect: Rect2 in solids: shapes.append(rectangle_points(rect))
	for row: Dictionary in polygons:
		var points := PackedVector2Array()
		for pair: Array in row.points: points.append(Vector2(float(pair[0]), float(pair[1])))
		shapes.append(clockwise(points))
	var faces := boundary(shapes)
	node.set("union_edges", faces)
	for shape: PackedVector2Array in shapes: _piece(node, shape, faces, spec, texture, shader)

static func _piece(node: Node2D, points: PackedVector2Array, all_faces: PackedVector4Array, spec: Dictionary, texture: Texture2D, shader: Shader, depth := 0) -> void:
	var box := bounds(points)
	var faces := PackedVector4Array()
	for edge: Vector4 in all_faces:
		var a := Vector2(edge.x, edge.y)
		var b := Vector2(edge.z, edge.w)
		if box.grow(16.1).intersects(Rect2(a.min(b), a.max(b)-a.min(b)).grow(0.01)): faces.append(edge)
	if faces.size() > 64 and depth < 16:
		var first := box
		var second := box
		if box.size.x >= box.size.y:
			first.size.x *= 0.5
			second.position.x += first.size.x
			second.size.x -= first.size.x
		else:
			first.size.y *= 0.5
			second.position.y += first.size.y
			second.size.y -= first.size.y
		for half: Rect2 in [first, second]:
			for clipped: PackedVector2Array in Geometry2D.intersect_polygons(points, rectangle_points(half)):
				if clipped.size() >= 3: _piece(node, clockwise(clipped), all_faces, spec, texture, shader, depth+1)
		return
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("source_pixels", texture)
	material.set_shader_parameter("source_size", Vector2(texture.get_size()))
	material.set_shader_parameter("art_scale", float(spec.source_coordinate_scale))
	material.set_shader_parameter("shape_origin", Vector2.ZERO)
	material.set_shader_parameter("face_count", mini(faces.size(), 64))
	faces.resize(64)
	material.set_shader_parameter("faces", faces)
	material.set_shader_parameter("corner_count", 0)
	var corners := PackedVector4Array()
	corners.resize(64)
	material.set_shader_parameter("corners", corners)
	var surface := Polygon2D.new()
	surface.name = "NativePolygonSurface"
	surface.polygon = points
	surface.antialiased = false
	surface.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	surface.material = material
	node.add_child(surface)
