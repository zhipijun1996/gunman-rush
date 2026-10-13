extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var whole:Array[Rect2]=[Rect2(0,0,100,20)]
	var split:Array[Rect2]=[]
	for x:int in 100:split.append(Rect2(x,0,1,20))
	var a:=PlainsTileComposer.build_rectangles(whole)
	var b:=PlainsTileComposer.build_rectangles(split)
	print("INDEPENDENT SAME UNION: whole_present=%s hundred_strips_present=%s"%[a!=null,b!=null])
	var failed:bool=a!=null and b==null
	if a!=null:a.free()
	if b!=null:b.free()
	quit(1 if failed else 0)
