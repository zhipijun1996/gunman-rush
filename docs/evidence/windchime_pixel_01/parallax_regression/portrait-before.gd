extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720,1280)
	root.add_child(viewport)
	var background := PixelPlainsParallax.new()
	viewport.add_child(background)
	var camera := Camera2D.new()
	viewport.add_child(camera)
	camera.make_current()
	camera.force_update_scroll()
	await process_frame
	background._update()
	var panel := background.panels[0]
	var bounds := Rect2(panel.position,panel.texture.get_size()*panel.scale)
	print("PORTRAIT_BEFORE size=",viewport.size," sky_bounds=",bounds," uncovered_top=",bounds.position.y>0," camera=",viewport.get_camera_2d()==camera)
	viewport.free()
	await process_frame
	quit()
