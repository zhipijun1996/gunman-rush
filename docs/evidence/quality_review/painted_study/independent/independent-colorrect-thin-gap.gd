extends SceneTree
func _initialize()->void:
	var solids:Array[Rect2]=[Rect2(0,0,10,10),Rect2(10.005,0,10,10)]
	var art:=PlainsTileComposer.build_rectangles(solids)
	var refused:=art==null
	var filled:=false
	if art!=null:
		for polygon:ColorRect in art.get_children():
			var rect:=Rect2(polygon.position,polygon.size)
			filled=filled or rect.has_point(Vector2(10.0025,5))
		art.free()
	print("INDEPENDENT THIN GAP: refused=%s empty_gap_painted=%s"%[refused,filled])
	quit(1 if filled else 0)
