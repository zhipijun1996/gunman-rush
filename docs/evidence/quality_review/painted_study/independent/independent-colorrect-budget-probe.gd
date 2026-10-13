extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL "+label)
func run()->void:
	for macro:Vector2i in [Vector2i.ONE,Vector2i(1,2),Vector2i(2,1),Vector2i(2,2),Vector2i(4,2),Vector2i(4,4),Vector2i(16,1)]:
		for phase:int in 2:
			var cells:Dictionary={}
			for y:int in range(-2,macro.y+2):
				for x:int in range(-2,macro.x+2):
					if (x>=0 and x<macro.x and y>=0 and y<macro.y) or posmod(x+y,2)==phase:cells[Vector2i(x,y)]=true
			var art:=PlainsTileComposer.build(cells,macro)
			var seen:Dictionary={}
			for quad:ColorRect in art.get_children():
				var count:int=quad.material.get_shader_parameter("face_count")
				check(count<=64,"actual local boundary budget")
				check(quad.mouse_filter==Control.MOUSE_FILTER_IGNORE,"grid quad ignores pointer")
				var size:=Vector2i(quad.size/32)
				var start:=Vector2i(quad.position/32)
				check(Vector2(size*32)==quad.size and quad.position==Vector2(start*32),"actual quad remains grid aligned")
				check(size==quad.get_meta("macro_size"),"actual size matches macro metadata")
				for y:int in size.y:
					for x:int in size.x:
						var cell:=start+Vector2i(x,y)
						check(cells.has(cell) and not seen.has(cell),"actual quad coverage never fills hole or overlaps")
						seen[cell]=true
			check(seen.size()==cells.size(),"actual quads cover all solids")
			art.free()
	print("INDEPENDENT COLORRECT BUDGET: 14 cases, %s checks, %s failures"%[checks,failures])
	quit(1 if failures else 0)
