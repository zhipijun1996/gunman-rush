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

static func exterior_fill(geometry: Dictionary, doors: Array) -> Array[Rect2]:
	# Presentation only: room rock continues off screen instead of outlining sky.
	# Actual doorway apertures remain open through the surrounding mass.
	var outer:=FixedWorldProvider.rect(geometry.bounds_world_units).grow(512)
	var open: Array[Rect2]=[]
	for raw: Array in geometry.space_rects:open.append(FixedWorldProvider.rect(raw))
	for door: Dictionary in doors:
		var p:=FixedWorldProvider.point(door.position_candidate.local_world_units)
		match str(door.direction):
			"up":open.append(Rect2(p.x-64,outer.position.y,128,p.y-outer.position.y))
			"down":open.append(Rect2(p.x-64,p.y,128,outer.end.y-p.y))
			"left":open.append(Rect2(outer.position.x,p.y-96,p.x-outer.position.x,96))
			"right":open.append(Rect2(p.x,p.y-96,outer.end.x-p.x,96))
	var xs: Array[float]=[outer.position.x,outer.end.x]
	var ys: Array[float]=[outer.position.y,outer.end.y]
	for rect: Rect2 in open:
		for x: float in [rect.position.x,rect.end.x]:
			if x not in xs:xs.append(x)
		for y: float in [rect.position.y,rect.end.y]:
			if y not in ys:ys.append(y)
	xs.sort();ys.sort()
	var result: Array[Rect2]=[]
	for row: int in ys.size()-1:
		var start:=-1
		for col: int in xs.size():
			var filled:=col<xs.size()-1
			if filled:
				var at:=Vector2((xs[col]+xs[col+1])*.5,(ys[row]+ys[row+1])*.5)
				for rect: Rect2 in open:
					if rect.has_point(at):filled=false;break
			if filled and start<0:start=col
			if not filled and start>=0:
				result.append(Rect2(xs[start],ys[row],xs[col]-xs[start],ys[row+1]-ys[row]));start=-1
	return result
