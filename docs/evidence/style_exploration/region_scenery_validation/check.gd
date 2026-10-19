extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scenery := StyleScenery.new()
	root.add_child(scenery)
	var camera := Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 2560
	camera.limit_bottom = 736
	root.add_child(camera)
	camera.make_current()
	var combinations := 0
	for style: String in ["underworld", "cavern"]:
		for biome: String in ["plains", "forest", "gear"]:
			scenery.style_id = style
			scenery.biome_id = biome
			var asset_root := scenery._art_root()
			assert(ResourceLoader.exists(asset_root + "background_sky.png"), "missing region panorama: " + asset_root)
			assert(ResourceLoader.exists(asset_root + "chime_props.png"), "missing region prop source: " + asset_root)
			for seed_value: int in [0,101,307,911]:
				scenery.configure(style, StyleLayout.generate(seed_value), camera, biome)
				assert(scenery.biome_id == biome)
				assert(scenery._parallax.size() == 3)
				assert(scenery._light_sources.size() > 0)
				for child: Node in scenery._decor.get_children():
					if biome != "plains":
						assert(child.has_meta("biome") and child.get_meta("biome") == biome)
						var sprite := child.get_child(0) as Sprite2D
						assert(sprite.texture is AtlasTexture)
						assert(sprite.texture.atlas.resource_path == asset_root + "chime_props.png")
				for requested_x: float in [300.0,640.0,1280.0,1920.0,2700.0]:
					camera.position = Vector2(requested_x,360)
					camera.force_update_scroll()
					scenery._process(0.016)
					var center := camera.get_screen_center_position()
					assert(absf(center.x - clampf(requested_x,640,1920)) < 1)
					var panorama := scenery._parallax[0].node.get_child(0) as Sprite2D
					var bounds: Rect2 = panorama.global_transform * panorama.get_rect()
					assert(bounds.encloses(Rect2(center - Vector2(640,360),Vector2(1280,720))))
					var light_count := 0
					for source: Dictionary in scenery._light_sources:
						if source.glow.is_visible_in_tree(): light_count += 1
						assert(source.glow.global_position.distance_to(source.source.to_global(source.local)) < 0.01)
					assert(light_count > 0 and light_count <= 2)
					scenery.set_lights_enabled(false)
					for source: Dictionary in scenery._light_sources: assert(not source.glow.is_visible_in_tree())
					scenery.set_lights_enabled(true)
					scenery.set_decor_enabled(false)
					scenery._process(0)
					for source: Dictionary in scenery._light_sources: assert(not source.glow.is_visible_in_tree())
					scenery.set_decor_enabled(true)
				combinations += 1
	print("REGION_SCENERY_VALIDATION_OK styles=2 biomes=3 seeds=4 combinations=",combinations," camera_samples=120 rooted_light_max=2 foreign_decor_sources=0")
	scenery.free()
	camera.free()
	quit()
