extends SceneTree
var lab: StyleLab
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	lab = load("res://scenes/style_exploration/style_lab.tscn").instantiate() as StyleLab
	lab.default_style = "basic"
	root.add_child(lab)
	for item: Dictionary in [{"id":"left","player_x":80.0,"expected":640.0},{"id":"middle","player_x":1060.0,"expected":1280.0},{"id":"right","player_x":2480.0,"expected":1920.0}]:
		lab.controller.reset_at(Vector2(item.player_x,588))
		for frame: int in 150: await physics_frame
		await RenderingServer.frame_post_draw
		var center := lab.camera.get_screen_center_position()
		assert(absf(center.x - item.expected) < 2)
		var panorama: Sprite2D = lab.scenery._parallax[0].node.get_child(0)
		var bounds: Rect2 = panorama.global_transform * panorama.get_rect()
		assert(bounds.encloses(Rect2(center - Vector2(640,360), Vector2(1280,720))))
		var visible_lights := 0
		for source: Dictionary in lab.scenery._light_sources:
			if source.glow.is_visible_in_tree(): visible_lights += 1
			assert(source.glow.global_position.distance_to(source.source.to_global(source.local)) < 0.01)
		assert(visible_lights > 0 and visible_lights <= 2)
		lab.scenery.set_lights_enabled(false)
		for source: Dictionary in lab.scenery._light_sources: assert(not source.glow.is_visible_in_tree())
		lab.scenery.set_lights_enabled(true)
		lab.scenery.set_decor_enabled(false)
		lab.scenery._process(0)
		for source: Dictionary in lab.scenery._light_sources: assert(not source.glow.is_visible_in_tree())
		lab.scenery.set_decor_enabled(true)
		lab.scenery._process(0)
		await RenderingServer.frame_post_draw
		var image_path := "res://build/style_exploration/scenery_validation/basic_follow_after_" + str(item.id) + ".png"
		assert(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(image_path)) == OK)
		print("FOLLOW_LIMIT_OK case=",item.id," player_x=",lab.player.position.x," requested_camera_x=",lab.camera.position.x," actual_center_x=",center.x," visible_bound_lights=",visible_lights," image=",image_path)
	lab.leave()
	lab.free()
	print("FOLLOW_CAMERA_GPU_OK cases=3; endpoint relocation fixture, not traversal proof")
	quit()
