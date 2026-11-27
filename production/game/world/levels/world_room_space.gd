class_name WorldRoomSpace
extends RefCounted
## Boundary collision consumes the same traced chamber union as the region map.
const EXTERIOR_DEPTH := 512.0

static func document_geometry(bounds: Array, exits: Dictionary) -> Dictionary:
	var outer := FixedWorldProvider.rect(bounds).grow(EXTERIOR_DEPTH)
	var channels: Array[Rect2] = []
	for gate: Dictionary in exits.values():
		if not gate.has("span"): continue
		var point := FixedWorldProvider.point(gate.point)
		var extent := FixedWorldProvider.point(gate.span)
		var direction := FixedWorldProvider.point(gate.direction)
		var start := Vector2(point.x, extent.x)
		var end := Vector2(outer.end.x, extent.y)
		if direction == Vector2.LEFT:
			start.x = outer.position.x
			end.x = point.x
		elif direction == Vector2.UP:
			start = Vector2(extent.x, outer.position.y)
			end = Vector2(extent.y, point.y)
		elif direction == Vector2.DOWN:
			start = Vector2(extent.x, point.y)
			end = Vector2(extent.y, outer.end.y)
		elif direction != Vector2.RIGHT:
			continue
		var channel := Rect2(start, end-start).intersection(outer)
		if channel.has_area(): channels.append(channel)
	return {"bounds_world_units":bounds, "space_rects":[bounds], "boundary":[], "door_channels":channels}

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
			if door.get("front_door",false):continue
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
	# Shared physical/presentation mass: room rock continues beyond the chamber.
	# Actual doorway apertures remain open through the surrounding mass.
	var outer:=FixedWorldProvider.rect(geometry.bounds_world_units).grow(EXTERIOR_DEPTH)
	var open: Array[Rect2]=[]
	for raw: Array in geometry.space_rects:open.append(FixedWorldProvider.rect(raw))
	open.append_array(geometry.get("door_channels", []))
	for door: Dictionary in doors:
		if door.get("front_door",false):continue
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

static func exposed_parts(surfaces: Array[Rect2], rock: Array[Rect2]) -> Array[Rect2]:
	# Presentation only. Trim inserted ends against the physical room wall and
	# exterior mass; do not trim against other authored platforms or change bodies.
	var pieces: Array[Rect2] = surfaces.duplicate()
	for wall: Rect2 in rock:
		var remaining: Array[Rect2] = []
		for piece: Rect2 in pieces:
			var overlap:=piece.intersection(wall)
			if not overlap.has_area():
				remaining.append(piece);continue
			for part: Rect2 in [
				Rect2(piece.position,Vector2(piece.size.x,overlap.position.y-piece.position.y)),
				Rect2(piece.position.x,overlap.end.y,piece.size.x,piece.end.y-overlap.end.y),
				Rect2(piece.position.x,overlap.position.y,overlap.position.x-piece.position.x,overlap.size.y),
				Rect2(overlap.end.x,overlap.position.y,piece.end.x-overlap.end.x,overlap.size.y)]:
				if part.has_area():remaining.append(part)
		pieces=remaining
	return pieces
