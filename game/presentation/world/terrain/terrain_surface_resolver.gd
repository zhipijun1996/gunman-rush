class_name TerrainSurfaceResolver
extends RefCounted
## Surfaces consume exposed union edges. Hazard data stays with WorldSpikeStrip.
static func bands(edges: PackedVector4Array, requests: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in requests:
		var bounds := FixedWorldProvider.rect(row.bounds)
		var facing := str(row.facing)
		for edge: Vector4 in edges:
			var a := Vector2(edge.x, edge.y)
			var b := Vector2(edge.z, edge.w)
			var face := ""
			if a.y == b.y: face = "up" if b.x > a.x else "down"
			elif a.x == b.x: face = "right" if b.y > a.y else "left"
			if face != facing: continue
			var rect: Rect2
			if face in ["up", "down"]:
				if a.y < bounds.position.y-.01 or a.y > bounds.end.y+.01: continue
				var start := maxf(minf(a.x, b.x), bounds.position.x)
				var end := minf(maxf(a.x, b.x), bounds.end.x)
				if end <= start: continue
				rect = Rect2(start, a.y if face == "up" else a.y-16, end-start, 16)
			else:
				if a.x < bounds.position.x-.01 or a.x > bounds.end.x+.01: continue
				var start := maxf(minf(a.y, b.y), bounds.position.y)
				var end := minf(maxf(a.y, b.y), bounds.end.y)
				if end <= start: continue
				rect = Rect2(a.x if face == "left" else a.x-16, start, 16, end-start)
			var band := row.duplicate(true)
			band["rect"] = rect
			result.append(band)
	return result

static func hazard_requests(strips: Array[Dictionary]) -> Array:
	var result: Array = []
	for strip: Dictionary in strips:
		var danger := FixedWorldProvider.rect(strip.bounds)
		var face := str(strip.get("facing", "up"))
		# Query only the root plane, not any unrelated exposed edge inside danger.
		var root := danger
		if face == "up": root.position.y = danger.end.y; root.size.y = 0
		elif face == "down": root.size.y = 0
		elif face == "left": root.position.x = danger.end.x; root.size.x = 0
		else: root.size.x = 0
		result.append({"id":"hazard:"+str(strip.id), "bounds":[root.position.x,root.position.y,root.size.x,root.size.y], "facing":face, "surface_id":"bare", "priority":2147483647})
	return result

static func apply(groups: Array[Dictionary], spans: Array[Dictionary]) -> void:
	for span: Dictionary in spans:
		if span.surface_id == "material":
			TerrainGeometry.paint_rect(groups, span.rect, str(span.material_id))
		else:
			# Strip the original border using its own material's core pixels.
			var count := groups.size()
			for index: int in count:
				var selected: Array[Dictionary] = [groups[index]]
				TerrainGeometry.paint_rect(selected, span.rect, str(groups[index].material_id), true)
				if selected.size() > 1: groups.append(selected[1])
