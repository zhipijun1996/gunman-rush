extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(640,640)
	root.transparent_bg = true
	var points := PackedVector2Array([Vector2(0,0),Vector2(640,0),Vector2(640,640),Vector2(576,640),Vector2(576,320)])
	for i: int in range(1,65):
		var angle := PI*float(i)/64.0
		points.append(Vector2(roundf(320+256*cos(angle)),roundf(320-224*sin(angle))))
	points.append(Vector2(64,640));points.append(Vector2(0,640))
	var arch := Polygon2D.new()
	arch.polygon = points
	arch.color = Color("708291")
	root.add_child(arch)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://assets/kit_reuse/source/arch-guide.png")==OK)
	var report := {"native_size":[640,640],"repeat_stride":576,"pier_width":64,"arch_spring_y":320,"arch_crown_y":96,"polygon":[]}
	for p: Vector2 in points: report.polygon.append([p.x,p.y])
	var file := FileAccess.open("res://assets/kit_reuse/source/arch-geometry.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	quit()
