class_name ForestFruitBough
extends RefCounted
## V14-only local foliage behind terrain; never creates a collision or top line.
static func draw(canvas: Node2D, row: Dictionary) -> void:
	_draw_path(canvas,row.points,float(row.get("base_width",8.0)))
	for branch: Array in row.get("branches",[]):
		_draw_path(canvas,branch,5.0)

static func _draw_path(canvas: Node2D, points: Array, base_width: float) -> void:
	for index: int in range(1,points.size()):
		var from := Vector2(points[index-1][0],points[index-1][1])
		var to := Vector2(points[index][0],points[index][1])
		var thickness := lerpf(base_width,2.5,float(index)/float(points.size()-1))
		canvas.draw_line(from,to,Color("394637"),thickness,false)
		# Broken, low-contrast grain belongs to the curved wood, not a bright
		# walkable horizon. Sparse leaves leave the fruit and cast lines clear.
		if index < points.size()-1:
			_leaf(canvas,to+Vector2(-7,-10),-1.0)
			if index%2 == 1:_leaf(canvas,to+Vector2(9,6),1.0)
		else:
			_leaf(canvas,to+Vector2(-8,-6),-1.0)

static func _leaf(canvas: Node2D, at: Vector2, direction: float) -> void:
	var shape := PackedVector2Array([Vector2(-11,0),Vector2(-7,-5),Vector2(2,-7),Vector2(10,-4),Vector2(5,1),Vector2(-4,3)])
	for index: int in shape.size():shape[index]=(at+Vector2(shape[index].x*direction,shape[index].y)).round()
	canvas.draw_colored_polygon(shape,Color("495b3c"))
