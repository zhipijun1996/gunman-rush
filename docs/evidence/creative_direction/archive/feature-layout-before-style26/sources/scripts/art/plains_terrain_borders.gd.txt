class_name PlainsTerrainBorders
extends RefCounted
## Union-of-solids boundary extraction. Art follows geometry; no gameplay writes.
const DIRECTIONS := ["top", "right", "bottom", "left"]
const QUADRANTS := [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]
const CORNERS := ["top_left","top_right","bottom_left","bottom_right"]

static func occupied(point:Vector2,solids:Array[Rect2])->bool:
	for solid:Rect2 in solids:
		if solid.has_point(point):return true
	return false

## Symbolic one-sided limits: finite probes can jump across narrow empty gaps.
static func occupied_side(point:Vector2,direction:Vector2,solids:Array[Rect2])->bool:
	for solid:Rect2 in solids:
		var x_inside:=point.x>solid.position.x and point.x<=solid.end.x if direction.x<0 else point.x>=solid.position.x and point.x<solid.end.x
		var y_inside:=point.y>solid.position.y and point.y<=solid.end.y if direction.y<0 else point.y>=solid.position.y and point.y<solid.end.y
		if x_inside and y_inside:return true
	return false

static func _closed_neighbours(rect:Rect2,solids:Array[Rect2])->Array[Rect2]:
	# Every plan query lies on rect's closed boundary. A solid excluded here
	# cannot contain that point under any exact one-sided occupancy predicate.
	# Keep touching edges/corners and the original input order, without epsilon.
	if not rect.has_area() or not rect.position.is_finite() or not rect.size.is_finite() or not rect.end.is_finite():return solids
	var nearby:Array[Rect2]=[]
	for other:Rect2 in solids:
		# Preserve historical behaviour for exceptional inputs rather than
		# assuming a normalized finite rectangle in the broad phase.
		if not other.has_area() or not other.position.is_finite() or not other.size.is_finite() or not other.end.is_finite():return solids
		if other.position.x>rect.end.x or other.end.x<rect.position.x or other.position.y>rect.end.y or other.end.y<rect.position.y:continue
		nearby.append(other)
	return nearby

static func plan(rect:Rect2,solids:Array[Rect2])->Dictionary:
	var faces:Array[Dictionary]=[]
	var points:Array[Vector2]=[]
	var nearby:=_closed_neighbours(rect,solids)
	for side:String in DIRECTIONS:
		var vertical:=side in ["left","right"]
		var axis:=rect.position.x if side=="left" else rect.end.x if side=="right" else rect.position.y if side=="top" else rect.end.y
		var lo:=rect.position.y if vertical else rect.position.x
		var hi:=rect.end.y if vertical else rect.end.x
		var cuts:Array[float]=[lo,hi]
		for other:Rect2 in solids:
			var a:=other.position.y if vertical else other.position.x
			var b:=other.end.y if vertical else other.end.x
			if a>lo and a<hi:cuts.append(a)
			if b>lo and b<hi:cuts.append(b)
		cuts.sort()
		var normal:=Vector2(-1,0) if side=="left" else Vector2(1,0) if side=="right" else Vector2(0,-1) if side=="top" else Vector2(0,1)
		for i:int in cuts.size()-1:
			if cuts[i+1]<=cuts[i]:continue
			var middle:=Vector2(axis,(cuts[i]+cuts[i+1])/2) if vertical else Vector2((cuts[i]+cuts[i+1])/2,axis)
			if occupied_side(middle,normal,nearby):continue
			var start:=Vector2(axis,cuts[i]) if vertical else Vector2(cuts[i],axis)
			var finish:=Vector2(axis,cuts[i+1]) if vertical else Vector2(cuts[i+1],axis)
			faces.append({"side":side,"start":start,"finish":finish})
			if start not in points:points.append(start)
			if finish not in points:points.append(finish)
	var corners:Array[Dictionary]=[]
	for point:Vector2 in points:
		var filled:Array[int]=[]
		for q:int in 4:
			if occupied_side(point,QUADRANTS[q],nearby):filled.append(q)
		if filled.size()==1:
			# Solid lower-right gives an exposed upper-left convex corner.
			corners.append({"kind":"outer", "direction":CORNERS[3-filled[0]], "point":point})
		elif filled.size()==3:
			for q:int in 4:
				if q not in filled:corners.append({"kind":"inner","direction":CORNERS[q],"point":point})
	return {"faces":faces,"corners":corners}
