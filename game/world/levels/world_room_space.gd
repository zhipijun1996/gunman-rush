class_name WorldRoomSpace
extends RefCounted
## Boundary collision consumes the same traced chamber union as the region map.
static func boundary_platforms(geometry: Dictionary, doors: Array) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for edge: Dictionary in geometry.boundary:
		var side := str(edge.side)
		var a := FixedWorldProvider.point(edge.from)
		var b := FixedWorldProvider.point(edge.to)
		var horizontal := side in ["up","down"]
		var fixed := a.y if horizontal else a.x
		var start := minf(a.x,b.x) if horizontal else minf(a.y,b.y)
		var end := maxf(a.x,b.x) if horizontal else maxf(a.y,b.y)
		var gaps: Array[Vector2] = []
		for door: Dictionary in doors:
			if door.direction != side: continue
			var p := FixedWorldProvider.point(door.position_candidate.local_world_units)
			if not is_equal_approx(p.y if horizontal else p.x,fixed): continue
			var gap := Vector2(p.x-64,p.x+64) if horizontal else Vector2(p.y-96,p.y)
			if gap.x >= start and gap.y <= end: gaps.append(gap)
		gaps.sort_custom(func(first: Vector2,second: Vector2) -> bool: return first.x < second.x)
		gaps.append(Vector2(end,end))
		for gap: Vector2 in gaps:
			if gap.x > start:
				result.append(Rect2(start,fixed if side=="up" else fixed-32,gap.x-start,32) if horizontal else Rect2(fixed if side=="left" else fixed-32,start,32,gap.x-start))
			start = maxf(start,gap.y)
	return result

static func camera_envelope(geometry: Dictionary, point: Vector2, previous: Rect2) -> Rect2:
	var nearest := Rect2()
	var distance := INF
	for raw: Array in geometry.space_rects:
		var zone := FixedWorldProvider.rect(raw)
		# Keep the previous chamber while crossing its shared seam, then release.
		if zone == previous and zone.grow(24).has_point(point): return zone
		var delta := point.distance_squared_to(point.clamp(zone.position,zone.end))
		if delta < distance:
			distance = delta
			nearest = zone
	return nearest
