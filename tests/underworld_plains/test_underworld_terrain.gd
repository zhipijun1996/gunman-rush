extends SceneTree
var checks:=0
var failures:Array[String]=[]
func _initialize()->void: run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok and failures.size()<30: failures.append(label)
func covers(rects:Array[Rect2],point:Vector2)->bool:
	for rect:Rect2 in rects:
		if rect.has_point(point): return true
	return false
func run()->void:
	var cases:Array[Array]=[
		[Rect2(24,24,320,28),Rect2(24,52,28,160),Rect2(316,52,28,160),Rect2(24,184,320,28)],
		[Rect2(20,20,24,18),Rect2(44,38,100,20),Rect2(144,58,25,120)],
		[Rect2(20,20,160,100),Rect2(100,80,200,120),Rect2(300,80,24,120)],
		[Rect2(16.25,16.5,350.5,200.25)],
		[Rect2(0,0,384,240)]]
	var gpu:bool="--gpu" in OS.get_cmdline_user_args()
	var output:="res://build/underworld_plains/terrain"
	DirAccess.make_dir_recursive_absolute(output)
	for number:int in cases.size():
		var solids:Array[Rect2]=[];solids.assign(cases[number])
		var split:Array[Rect2]=[]
		for rect:Rect2 in solids:
			split.append(Rect2(rect.position,Vector2(rect.size.x/2,rect.size.y)))
			split.append(Rect2(rect.position+Vector2(rect.size.x/2,0),Vector2(rect.size.x/2,rect.size.y)))
		split.reverse();split.append(split[0])
		var views:Array[SubViewport]=[]
		var arts:Array[UnderworldTerrain]=[]
		for source:Array[Rect2] in [solids,split]:
			var art:=UnderworldTerrain.build(source)
			check(art!=null,"builder accepts case %d"%number)
			arts.append(art)
			check(art.core_layer is TileMapLayer,"real TileMapLayer consumer")
			check(art.find_children("*","CollisionObject2D",true,false).is_empty(),"no art collision conversion")
			var drawn:Array[Rect2]=art.boundary_pieces.duplicate()
			for key:Vector2i in art.core_cells: drawn.append(Rect2(Vector2(key*32),Vector2(32,32)))
			for y:int in range(-2,244,2):
				for x:int in range(-2,388,2): check(covers(drawn,Vector2(x+.5,y+.5))==covers(solids,Vector2(x+.5,y+.5)),"exact drawing-geometry occupancy case%d pixel%d,%d"%[number,x,y])
			if gpu:
				var view:=SubViewport.new();view.size=Vector2i(384,240);view.transparent_bg=true;view.disable_3d=true
				root.add_child(view);view.add_child(art);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;views.append(view)
		check(arts[0].union_edges==arts[1].union_edges,"canonical union edge invariance")
		check(arts[0].union_corners==arts[1].union_corners,"canonical native corner invariance")
		check(arts[0].core_cells==arts[1].core_cells,"canonical TileMap cell invariance")
		check(arts[0].boundary_pieces==arts[1].boundary_pieces,"canonical adapter quad invariance")
		if gpu:
			await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
			var a:=views[0].get_texture().get_image();var b:=views[1].get_texture().get_image()
			a.save_png(output+"/golden_%d.png"%number)
			var differences:=0;var spill:=0;var transparent_native:=0
			for y:int in 240:
				for x:int in 384:
					if a.get_pixel(x,y)!=b.get_pixel(x,y): differences+=1
					if not covers(solids,Vector2(x+.5,y+.5)) and a.get_pixel(x,y).a>.01: spill+=1
					if covers(solids,Vector2(x+.5,y+.5)) and a.get_pixel(x,y).a<.5: transparent_native+=1
			check(differences==0,"actual GPU repartition equality case%d differences%d"%[number,differences])
			check(spill==0,"actual GPU remains inside exact union case%d spill%d"%[number,spill])
			print("UNDERWORLD_GPU case=",number," equal_differences=",differences," outside_spill=",spill," native_alpha_inside=",transparent_native," tilemap_core=",arts[0].core_cells.size())
			for view:SubViewport in views: view.queue_free()
			await process_frame
		else:
			for art:UnderworldTerrain in arts:art.free()
	var result:={"checks":checks,"failures":failures,"gpu":gpu,"cases":cases.size(),"scope":"Exact geometry coverage and native-pixel partition equality; original source alpha can round convex silhouette. Not aesthetic acceptance."}
	FileAccess.open(output+"/result_gpu.json" if gpu else output+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("UNDERWORLD_TERRAIN ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
