extends SceneTree
var failures:=0
func _initialize()->void:call_deferred("run")
func radius_for(solids:Array[Rect2])->float:
	var art:=PlainsTileComposer.build_rectangles(solids)
	var radius:=-1.0
	for child:Polygon2D in art.get_children():
		var material:ShaderMaterial=child.material
		var count:int=material.get_shader_parameter("corner_count")
		var corners:PackedVector4Array=material.get_shader_parameter("outer_corners")
		for i:int in count:
			if Vector2(corners[i].x,corners[i].y)==Vector2.ZERO:radius=corners[i].w
	art.free()
	return radius
func run()->void:
	var whole:=radius_for([Rect2(0,0,100,20)])
	var split:=radius_for([Rect2(0,0,2,20),Rect2(2,0,98,20)])
	var narrow:=radius_for([Rect2(0,0,1,10)])
	var beside:=radius_for([Rect2(0,0,1,10),Rect2(4,0,10,10)])
	print("INDEPENDENT REGION CORNERS whole=%s split=%s narrow=%s beside=%s"%[whole,split,narrow,beside])
	if not is_equal_approx(whole,split):failures+=1
	if not is_equal_approx(narrow,beside):failures+=1
	print("INDEPENDENT REGION GEOMETRY: 2 checks, %s failures"%failures)
	quit(1 if failures else 0)
