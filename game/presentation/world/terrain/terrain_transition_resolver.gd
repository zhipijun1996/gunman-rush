class_name TerrainTransitionResolver
extends RefCounted
## Only shared opposite edges are seams. Unsupported pairs/directions use a
## deterministic hard material boundary, with no new air-facing border.
static func resolve(groups: Array[Dictionary]) -> Array[Dictionary]:
	var edges: Array = []
	var shapes: Array = []
	for group: Dictionary in groups:
		var plan := TerrainGeometry.plan(group.solids, group.polygons)
		edges.append(plan.edges)
		shapes.append(plan.shapes)
	var result: Array[Dictionary] = []
	for i: int in groups.size():
		for j: int in range(i+1, groups.size()):
			if groups[i].bare or groups[j].bare: continue
			var first := str(groups[i].material_id)
			var second := str(groups[j].material_id)
			if first == second: continue
			var pair: Array[String] = [first, second]; pair.sort()
			var registered: Dictionary = TerrainMaterialRegistry.catalog().transitions.get("|".join(pair), {})
			if registered.is_empty(): continue
			for a: Vector4 in edges[i]:
				if a.x != a.z: continue
				for b: Vector4 in edges[j]:
					if b.x != b.z or not is_equal_approx(a.x, b.x) or (a.w-a.y)*(b.w-b.y) >= 0: continue
					var start := maxf(minf(a.y,a.w), minf(b.y,b.w))
					var end := minf(maxf(a.y,a.w), maxf(b.y,b.w))
					if end <= start: continue
					result.append({"x":a.x, "start":start, "end":end, "stone_on_right":(first == "mill_masonry") == (a.w < a.y), "texture":registered.texture, "shapes":shapes[i]+shapes[j]})
	# Coalesce split inputs and keep a stable order for junction ownership.
	result.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
		if a.x != b.x: return a.x < b.x
		return a.start < b.start)
	var merged: Array[Dictionary] = []
	for seam: Dictionary in result:
		if not merged.is_empty():
			var previous: Dictionary = merged[-1]
			if previous.x == seam.x and previous.stone_on_right == seam.stone_on_right and seam.start <= previous.end+.01:
				previous.end = maxf(previous.end,seam.end); continue
		merged.append(seam)
	return merged
