extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<20:printerr("FAIL "+label)
func pieces(solids:Array[Rect2])->Array[Rect2]:
	var art:=PlainsTileComposer.build_rectangles(solids)
	var result:Array[Rect2]=[]
	check(art!=null,"builder accepts bounded case")
	if art==null:return result
	for child:ColorRect in art.get_children():
		var rect:=Rect2(child.position,child.size)
		result.append(rect)
		check(rect==child.get_meta("authored_piece"),"actual ColorRect equals recorded piece")
		check(child.mouse_filter==Control.MOUSE_FILTER_IGNORE and child.focus_mode==Control.FOCUS_NONE,"art quad cannot consume pointer/focus")
		check(child.material.get_shader_parameter("shape_origin")==child.position,"local shader origin matches actual Control transform")
		check(int(child.material.get_shader_parameter("face_count"))<=64 and int(child.material.get_shader_parameter("corner_count"))<=32,"actual uniforms within local budgets")
	art.free()
	return result
func run()->void:
	var cases:Array=JSON.parse_string(FileAccess.get_file_as_string("res://build/verification/independent-canonical-cases.json"))
	for index:int in cases.size():
		var solids:Array[Rect2]=[]
		for v:Array in cases[index]:solids.append(Rect2(v[0],v[1],v[2],v[3]))
		var original:=solids.duplicate()
		var baseline:=pieces(solids)
		var alternative:Array[Rect2]=[]
		for rect:Rect2 in solids:
			alternative.append(Rect2(rect.position,Vector2(rect.size.x*.25,rect.size.y)))
			alternative.append(Rect2(rect.position+Vector2(rect.size.x*.25,0),Vector2(rect.size.x*.75,rect.size.y)))
		alternative.reverse()
		check(baseline==pieces(alternative),"canonical geometry invariant under unequal split and reverse case %s"%index)
		var duplicates:Array[Rect2]=solids.duplicate();duplicates.append_array(solids)
		check(baseline==pieces(duplicates),"duplicate authored coverage unchanged case %s"%index)
		var xs:Array[float]=[];var ys:Array[float]=[]
		for rect:Rect2 in solids+baseline:
			for x:float in [rect.position.x,rect.end.x]:
				if x not in xs:xs.append(x)
			for y:float in [rect.position.y,rect.end.y]:
				if y not in ys:ys.append(y)
		xs.sort();ys.sort()
		for x:int in xs.size()-1:
			for y:int in ys.size()-1:
				var point:=Vector2((xs[x]+xs[x+1])/2,(ys[y]+ys[y+1])/2)
				var occupied:=false
				for rect:Rect2 in solids:occupied=occupied or rect.has_point(point)
				var count:=0
				for rect:Rect2 in baseline:
					if rect.has_point(point):count+=1
				check(count==(1 if occupied else 0),"actual canonical output exact coverage case %s"%index)
		check(solids==original,"no input geometry mutation")
	print("INDEPENDENT COLORRECT CANONICAL BANDS: %s cases, %s checks, %s failures"%[cases.size(),checks,failures])
	quit(1 if failures else 0)
