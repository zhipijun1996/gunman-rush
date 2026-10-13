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

static func plan(rect:Rect2,solids:Array[Rect2])->Dictionary:
	var faces:Array[Dictionary]=[]
	var points:Array[Vector2]=[]
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
			if cuts[i+1]-cuts[i]<.001:continue
			var middle:=Vector2(axis,(cuts[i]+cuts[i+1])/2) if vertical else Vector2((cuts[i]+cuts[i+1])/2,axis)
			if occupied(middle+normal*.01,solids):continue
			var start:=Vector2(axis,cuts[i]) if vertical else Vector2(cuts[i],axis)
			var finish:=Vector2(axis,cuts[i+1]) if vertical else Vector2(cuts[i+1],axis)
			faces.append({"side":side,"start":start,"finish":finish})
			if start not in points:points.append(start)
			if finish not in points:points.append(finish)
	var corners:Array[Dictionary]=[]
	for point:Vector2 in points:
		var filled:Array[int]=[]
		for q:int in 4:
			if occupied(point+QUADRANTS[q]*.01,solids):filled.append(q)
		if filled.size()==1:
			# Solid lower-right gives an exposed upper-left convex corner.
			corners.append({"kind":"outer", "direction":CORNERS[3-filled[0]], "point":point})
		elif filled.size()==3:
			for q:int in 4:
				if q not in filled:corners.append({"kind":"inner","direction":CORNERS[q],"point":point})
	return {"faces":faces,"corners":corners}
