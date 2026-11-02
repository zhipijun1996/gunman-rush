class_name WindchimeMasonry
extends Node2D
## Cross-cell stone courses and weathering. Clipped to the SAME occupied cells.
## Cosmetic coordinate hashes only; never changes collision, masks or gameplay.
const CELL: int = Blob47Rules.CELL
var patches: Array[Dictionary] = []
var grain: Array[Vector3] = []
var enabled := true:
	set(value):
		enabled = value
		queue_redraw()

func configure(cells: Dictionary) -> void:
	patches.clear()
	grain.clear()
	var bounds := Rect2i()
	for cell: Vector2i in cells:
		bounds = bounds.expand(cell)
	# Irregular large slabs cross tile boundaries instead of repeating per-cell.
	for row: int in range(floori(bounds.position.y * float(CELL) / 44)-1, ceili(bounds.end.y * float(CELL) / 44)+1):
		var x := bounds.position.x * float(CELL) - 140 + (67 if posmod(row,2) else 0)
		var index := 0
		while x < bounds.end.x * CELL:
			var h := posmod(("limestone-course:"+str(row)+":"+str(index)).hash(), 1000)
			var w := 64.0 + h % 81
			var y := row*44.0 + (h % 7)-3
			var tall := 29.0 + h % 13
			var poly := PackedVector2Array([Vector2(x+4,y),Vector2(x+w-8,y-1),Vector2(x+w,y+6),Vector2(x+w-3,y+tall-4),Vector2(x+w-12,y+tall),Vector2(x+2,y+tall-2),Vector2(x,y+9)])
			var colors: Array[Color] = [Color("72755e"),Color("6d715b"),Color("777962"),Color("62684f")]
			_clip_patch(poly,colors[h%colors.size()],cells)
			# Short upper bevels fade into the quiet stone rather than outlining bricks.
			if h % 4 != 0:
				_clip_patch(PackedVector2Array([Vector2(x+8,y+1),Vector2(x+w*.64,y),Vector2(x+w*.64-4,y+2),Vector2(x+6,y+3)]),Color("81846a"),cells)
			x += w + 3 + h%5
			index += 1
	for cell: Vector2i in cells:
		var box := _interior(cell,cells)
		for i: int in 11:
			var h := posmod(("limestone-grain:"+str(cell)+":"+str(i)).hash(),100000)
			var p := Vector2(cell*CELL)+Vector2(h%(CELL-1),(h/(CELL-1))%(CELL-1))
			if box.has_point(p) and box.has_point(p+Vector2(2,1)):
				grain.append(Vector3(p.x,p.y,float(h%3)))
	queue_redraw()

func _interior(cell: Vector2i, cells: Dictionary) -> Rect2:
	var left := 2.0 if not cells.has(cell+Vector2i.LEFT) else 0.0
	var top := 7.0 if not cells.has(cell+Vector2i.UP) else 0.0
	var right := 2.0 if not cells.has(cell+Vector2i.RIGHT) else 0.0
	var bottom := 3.0 if not cells.has(cell+Vector2i.DOWN) else 0.0
	return Rect2(Vector2(cell*CELL)+Vector2(left,top),Vector2(CELL-left-right,CELL-top-bottom))

func _clip_patch(poly: PackedVector2Array, color: Color, cells: Dictionary) -> void:
	var box := Rect2(poly[0],Vector2.ZERO)
	for p: Vector2 in poly: box = box.expand(p)
	for y: int in range(floori(box.position.y/float(CELL)),floori(box.end.y/float(CELL))+1):
		for x: int in range(floori(box.position.x/float(CELL)),floori(box.end.x/float(CELL))+1):
			var cell := Vector2i(x,y)
			if not cells.has(cell): continue
			var r := _interior(cell,cells)
			var corners := PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
			for clipped: PackedVector2Array in Geometry2D.intersect_polygons(poly,corners):
				if clipped.size() >= 3: patches.append({"points":clipped,"color":color})

func _draw() -> void:
	if not enabled: return
	for item: Dictionary in patches: draw_colored_polygon(item.points,item.color)
	for p: Vector3 in grain:
		var color := Color(.91,.86,.64,.09) if p.z > 0 else Color(.2,.28,.2,.11)
		draw_line(Vector2(p.x,p.y),Vector2(p.x+1+p.z*.4,p.y+.4),color,.7)
