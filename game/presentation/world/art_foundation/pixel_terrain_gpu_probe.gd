class_name PixelTerrainGpuProbe
extends RefCounted
## Diagnostic-only real GPU oracle: equivalent unions must yield same pixels.
static func run(host: Node) -> Dictionary:
	var checks := 0
	var failures: Array[String] = []
	var cases: Array[Array] = [
		[Rect2(24,24,320,28),Rect2(24,52,28,160),Rect2(316,52,28,160),Rect2(24,184,320,28)],
		[Rect2(20,20,24,18),Rect2(44,38,100,20),Rect2(144,58,25,120)],
		[Rect2(20,20,160,100),Rect2(100,80,200,120),Rect2(300,80,24,120)],
	]
	for number: int in cases.size():
		var solids: Array[Rect2] = []
		solids.assign(cases[number])
		var split: Array[Rect2] = []
		for rect: Rect2 in solids:
			split.append(Rect2(rect.position,Vector2(rect.size.x*.5,rect.size.y)))
			split.append(Rect2(rect.position+Vector2(rect.size.x*.5,0),Vector2(rect.size.x*.5,rect.size.y)))
		split.reverse()
		var views: Array[SubViewport] = []
		for variant: int in 2:
			var view := SubViewport.new()
			view.size = Vector2i(384,240)
			view.transparent_bg = true
			view.disable_3d = true
			host.add_child(view)
			view.add_child(PixelFormalTerrain.build(solids if variant==0 else split))
			view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			views.append(view)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var a := views[0].get_texture().get_image()
		var b := views[1].get_texture().get_image()
		for y: int in 240:
			for x: int in 384:
				checks+=1
				if a.get_pixel(x,y)!=b.get_pixel(x,y):
					if failures.size()<20: failures.append("partition case%d pixel%d,%d"%[number,x,y])
				var occupied := false
				for rect: Rect2 in solids:
					if rect.has_point(Vector2(x+.5,y+.5)):occupied=true;break
				checks+=1
				if (a.get_pixel(x,y).a>.5)!=occupied:
					if failures.size()<20:failures.append("occupancy case%d pixel%d,%d"%[number,x,y])
		for view: SubViewport in views:view.queue_free()
	var result := {"gpu_oracle":true,"checks":checks,"failures":failures,"cases":cases.size(),"scope":"real rendered opaque occupancy and repartition pixel equality; not visual acceptance"}
	print("PIXEL_GPU ",JSON.stringify(result))
	return result
