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

const ATLAS := preload("res://assets/plains_v7/terrain_borders_candidate.png")
const TILE := 48.0
# Measured normalized regions exclude the candidate sheet's panel dividers.
const SOURCES := {
	"top_left":Rect2(.004,.004,.242,.242),"top":Rect2(.252,.004,.242,.242),"top_right":Rect2(.503,.004,.242,.242),
	"left":Rect2(.004,.253,.242,.242),"fill":Rect2(.252,.253,.242,.242),"right":Rect2(.503,.253,.242,.242),
	"bottom_left":Rect2(.004,.505,.242,.175),"bottom":Rect2(.252,.505,.242,.175),"bottom_right":Rect2(.503,.505,.242,.175),
	"inner_top_left":Rect2(.004,.691,.242,.304),"inner_top_right":Rect2(.252,.691,.242,.304),
	"inner_bottom_left":Rect2(.503,.691,.242,.304),"inner_bottom_right":Rect2(.753,.691,.242,.304)}

static func draw_clipped(canvas:CanvasItem,target:Rect2,source:Rect2,clip:Rect2,flip:Vector2=Vector2.ONE)->void:
	var visible:=target.intersection(clip)
	if not visible.has_area():return
	var ratio:=source.size/target.size
	var offset:=visible.position-target.position
	if flip.x<0:offset.x=target.size.x-offset.x-visible.size.x
	if flip.y<0:offset.y=target.size.y-offset.y-visible.size.y
	var sample:=Rect2(source.position+offset*ratio,visible.size*ratio)
	canvas.draw_set_transform(visible.get_center(),0,flip)
	canvas.draw_texture_rect_region(ATLAS,Rect2(-visible.size/2,visible.size),sample)
	canvas.draw_set_transform(Vector2.ZERO)

static func source(id:String)->Rect2:
	var r:Rect2=SOURCES[id]
	return Rect2(r.position*ATLAS.get_size(),r.size*ATLAS.get_size())

static func draw_solid(canvas:CanvasItem,rect:Rect2,boundary:Dictionary)->void:
	# World-anchored mirrored interior: adjoining slabs use exactly the same sample.
	var origin:=canvas.get_global_transform().origin
	var world:=Rect2(rect.position+origin,rect.size)
	var fill:=source("fill")
	canvas.draw_rect(rect,Color("555744"))
	for y:int in range(floori(world.position.y/TILE),ceili(world.end.y/TILE)):
		for x:int in range(floori(world.position.x/TILE),ceili(world.end.x/TILE)):
			var cell:=Rect2(Vector2(x,y)*TILE,Vector2.ONE*TILE)
			var part:=world.intersection(cell)
			var flip:=Vector2(-1 if absi(x)%2 else 1,-1 if absi(y)%2 else 1)
			var offset:=part.position-cell.position
			if flip.x<0:offset.x=TILE-offset.x-part.size.x
			if flip.y<0:offset.y=TILE-offset.y-part.size.y
			var sample:=Rect2(fill.position+offset/TILE*fill.size,part.size/TILE*fill.size)
			canvas.draw_set_transform(part.get_center()-origin,0,flip)
			canvas.draw_texture_rect_region(ATLAS,Rect2(-part.size/2,part.size),sample)
	canvas.draw_set_transform(Vector2.ZERO)
	for face:Dictionary in boundary.faces:
		var side:String=face.side
		var start:Vector2=face.start-origin
		var finish:Vector2=face.finish-origin
		var vertical:=side in ["left","right"]
		var length:=start.distance_to(finish)
		var first:float=face.start.y if vertical else face.start.x
		var last:float=face.finish.y if vertical else face.finish.x
		for i:int in range(floori(first/TILE),ceili(last/TILE)):
			var position:=Vector2(start.x,i*TILE-origin.y) if vertical else Vector2(i*TILE-origin.x,start.y)
			if side=="right":position.x-=TILE
			if side=="bottom":position.y-=TILE
			var target:=Rect2(position,Vector2.ONE*TILE)
			var clip:=Rect2(start,Vector2(rect.size.x/2,length)) if side=="left" else Rect2(start-Vector2(rect.size.x/2,0),Vector2(rect.size.x/2,length)) if side=="right" else Rect2(start,Vector2(length,rect.size.y/2)) if side=="top" else Rect2(start-Vector2(0,rect.size.y/2),Vector2(length,rect.size.y/2))
			draw_clipped(canvas,target,source(side),rect.intersection(clip),Vector2(1,-1 if absi(i)%2 else 1) if vertical else Vector2(-1 if absi(i)%2 else 1,1))
	for corner:Dictionary in boundary.corners:
		var point:Vector2=corner.point-origin
		var direction:String=corner.direction
		var offset:=Vector2(-TILE if direction.ends_with("right") else 0,-TILE if direction.begins_with("bottom") else 0)
		if corner.kind=="inner":offset=Vector2.ONE*(-TILE/2)
		draw_clipped(canvas,Rect2(point+offset,Vector2.ONE*TILE),source(("inner_" if corner.kind=="inner" else "")+direction),rect)
