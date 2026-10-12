class_name PlainsExplorationTopology
extends RefCounted
## Connected chamber footprints with voids, interrupted galleries and return loops.
## Cells are construction coordinates, not three player-facing routes.
static func make(rng: RunRandomStream, family: String, count: int) -> Dictionary:
	var width:=4 if family=="linked_rings" else 6 if family=="crossroads" else 5
	var height:=5 if family=="linked_rings" else 4
	var cells: Array[Vector2i]=[]
	var fallback:=false
	for y: int in height:
		for x: int in width: cells.append(Vector2i(x,y))
	# Keep two separated optional challenge entrances, and the tutorial junction.
	var protected: Array[Vector2i]=[Vector2i(0,1),Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0)]
	for attempt: int in 240:
		if cells.size()<=count: break
		var at:=rng.next_int(cells.size());var cell:=cells[at]
		if cell in protected: continue
		cells.remove_at(at)
		if not connected(cells) or cycles(cells)<7 or not boss_cell(cells): cells.insert(at,cell)
	# Deterministic complete chamber fallback, never a line.
	if cells.size()!=count:
		fallback=true
		cells.clear()
		for y: int in 4:
			for x: int in 4:
				if count==15 and x==3 and y==3: continue
				cells.append(Vector2i(x,y))
		if count==18: cells.append_array([Vector2i(4,1),Vector2i(4,2)])
	cells.sort_custom(func(a: Vector2i,b: Vector2i): return a.y<b.y or (a.y==b.y and a.x<b.x))
	width=0;height=0
	for c: Vector2i in cells: width=maxi(width,c.x+1);height=maxi(height,c.y+1)
	var result: Array=[]
	for c: Vector2i in cells: result.append([c.x,c.y])
	return {"cells":result,"recipe":"courtyard_weave" if family=="woven_layers" else "offset_well_rings" if family=="linked_rings" else "hub_satellites","grid_width":width,"grid_height":height,"footprint_fallback":fallback}
static func connected(cells: Array[Vector2i]) -> bool:
	if cells.is_empty(): return false
	var seen: Dictionary={cells[0]:true}
	for unused: int in cells.size():
		for c: Vector2i in cells:
			if seen.has(c): continue
			for delta: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if seen.has(c+delta): seen[c]=true;break
	return seen.size()==cells.size()
static func cycles(cells: Array[Vector2i]) -> int:
	var edges:=0
	for c: Vector2i in cells:
		if c+Vector2i.RIGHT in cells: edges+=1
		if c+Vector2i.DOWN in cells: edges+=1
	return edges-cells.size()+1

static func boss_cell(cells: Array[Vector2i]) -> bool:
	var far:=0
	for c: Vector2i in cells: far=maxi(far,c.x)
	for c: Vector2i in cells:
		if c.x!=far: continue
		var degree:=0
		for d: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if c+d in cells: degree+=1
		if degree>=2: return true
	return false
