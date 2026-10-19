extends SceneTree
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scenery_script := load("res://scripts/style_exploration/style_scenery.gd")
	var actor_script := load("res://scripts/style_exploration/style_actor_visual.gd")
	var scenery: Node2D = scenery_script.new()
	root.add_child(scenery)
	var camera := Camera2D.new()
	root.add_child(camera)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 2560
	camera.limit_bottom = 736
	camera.make_current()
	var actor: Node2D = actor_script.new()
	root.add_child(actor)
	var combinations := 0
	for style: String in ["retro", "basic", "scribble", "underworld", "cavern"]:
		for sample_seed: int in [0,101,307,911]:
			scenery.configure(style, StyleLayout.generate(sample_seed), camera)
			assert(scenery._parallax.size() == 3)
			for camera_x: float in [300.0,640.0,1280.0,1920.0,2240.0]:
				camera.position = Vector2(camera_x,360)
				camera.force_update_scroll()
				var actual_center := camera.get_screen_center_position()
				assert(absf(actual_center.x - clampf(camera_x,640,1920)) < 1)
				scenery._process(0.016)
				var panorama: Sprite2D = scenery._parallax[0].node.get_child(0)
				var panorama_bounds: Rect2 = panorama.global_transform * panorama.get_rect()
				assert(panorama_bounds.encloses(Rect2(actual_center - Vector2(640,360),Vector2(1280,720))))
				var visible_glows := 0
				for source: Dictionary in scenery._light_sources:
					if source.glow.visible: visible_glows += 1
					assert(source.glow.global_position.distance_to(source.source.to_global(source.local)) < 0.01)
				assert(visible_glows > 0 and visible_glows <= 2)
				scenery.set_lights_enabled(false)
				for source: Dictionary in scenery._light_sources: assert(not source.glow.is_visible_in_tree())
				scenery.set_lights_enabled(true)
				scenery.set_decor_enabled(false)
				scenery._process(0.016)
				for source: Dictionary in scenery._light_sources: assert(not source.glow.visible)
				scenery.set_decor_enabled(true)
				scenery.set_background_enabled(false)
				scenery.set_background_enabled(true)
			combinations += 1
		actor.configure(style)
		assert(actor.get_meta("visual_status") == "generated_experimental_player")
	print("SCENERY_VALIDATION_OK combinations=",combinations," camera_samples=100 camera_limit_cases=3 depth_layers=3 bound_light_max=2 generated_players=5")
	scenery.free()
	actor.free()
	camera.free()
	quit()
