extends SceneTree
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var painter := Node2D.new()
	root.add_child(painter)
	painter.draw.connect(func() -> void:
		for bounds: Rect2 in [Rect2(0, 100, 12, 16), Rect2(40, 100, 96, 20), Rect2(150, 100, 340, 80), Rect2(500, 100, 1800, 500)]:
			PlainsTerrainSkin.draw_platform(painter, bounds)
		PlainsTerrainSkin.draw_moving_platform(painter, Rect2(100, 220, 80, 20))
		PlainsTerrainSkin.draw_anchor(painter, Vector2(200, 100))
		for radius: float in [12.0, 30.0, 64.0]:
			PlainsTerrainSkin.draw_saw(painter, radius)
	)
	painter.queue_redraw()
	for texture: Texture2D in [PlainsTerrainSkin.PAINTED_GRASS, PlainsTerrainSkin.PAINTED_WOOD, PlainsTerrainSkin.PAINTED_ANCHOR, PlainsTerrainSkin.SAW]:
		_check(texture != null and texture.get_width() > 1000, "latest original PNG imported")
	_check(PlainsTerrainSkin.PAINT_SCALE == 0.2, "caps use fixed proportional scale")
	var background := PlainsBackground.new()
	background.continuous_panorama=false # Explicit legacy multi-layer skin regression.
	background.shared_environment_enabled=false # Select the historical consumer too.
	root.add_child(background)
	await process_frame
	await process_frame
	_check(background.layer == -100 and background.surface != null, "shared background keeps gameplay canvas independent")
	_check(PlainsBackground.TEXTURES[0].get_size() == Vector2(1672, 941), "original finite sky remains imported")
	for index: int in range(1, PlainsBackground.TEXTURES.size()):
		var texture: Texture2D = PlainsBackground.TEXTURES[index]
		_check(texture is AtlasTexture and texture.get_width() == 1672 and texture.get_height() >= 230, "generated pasture layer atlas imported")
		var band := PlainsBackground.landscape_rect(Vector2(1280, 720), Vector2.ZERO, index)
		_check(band.position.y < 720 and band.end.y > 400, "pasture silhouette is visible below sky at screen horizon")
	for size: Vector2 in [Vector2(1280, 720), Vector2(720, 1280), Vector2(2560, 720)]:
		for index: int in PlainsBackground.TEXTURES.size():
			for offset: Vector2 in [Vector2(-100000, -100000), Vector2.ZERO, Vector2(100000, 100000)]:
				var rect := PlainsBackground.panel_rect(size, offset, index)
				_check(rect.position.x <= 0.0 and rect.position.y <= 0.0 and rect.end.x >= size.x and rect.end.y >= size.y, "finite panorama covers camera extremes without panel repeat or blank gaps")
	for index: int in range(1, PlainsBackground.TEXTURES.size()):
		var panel := background.panels[index]
		var rect := Rect2(panel.position - panel.texture.get_size() * panel.scale / 2, panel.texture.get_size() * panel.scale)
		_check(rect.end.y > 720, "painted lower baseline extends outside visible screen instead of exposing sky seam")
		_check(float((panel.material as ShaderMaterial).get_shader_parameter("content_fraction")) < 1.0, "shader preserves upper silhouette and extends only lower pasture")
	var sky := PlainsBackground.panel_rect(Vector2(1280, 720), Vector2(1000, 0), 0)
	var meadow := PlainsBackground.panel_rect(Vector2(1280, 720), Vector2(1000, 0), 2)
	var sky_zero := PlainsBackground.panel_rect(Vector2(1280, 720), Vector2.ZERO, 0)
	var meadow_zero := PlainsBackground.panel_rect(Vector2(1280, 720), Vector2.ZERO, 2)
	_check(absf(meadow.position.x - meadow_zero.position.x) > absf(sky.position.x - sky_zero.position.x) * 3.0, "near and far painting layers visibly scroll at different rates")
	_check(absf(meadow.position.x - meadow_zero.position.x) > 200.0, "near scenery has substantial travel rather than tiny oscillation")
	_check(background.panels.size() == 3 and background.panels[1].material is ShaderMaterial, "sky and two v3 pasture layers use independent materials")
	background.free()
	await _check_default_environment()
	painter.free()
	print("PAINTERLY SKIN: %d assertions, %d failures; real raster appearance/device performance pending" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _check_default_environment() -> void:
	# Construct the current consumer with both environment defaults untouched.
	# These are geometry/source checks; raster appearance remains a separate gate.
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(720, 1280), Vector2i(2560, 720)]:
		var viewport := SubViewport.new()
		viewport.size = size
		root.add_child(viewport)
		var background := PlainsBackground.new()
		viewport.add_child(background)
		await process_frame
		await process_frame
		_check(background.shared_environment_enabled and background.continuous_panorama, "unmodified defaults select current shared environment")
		_check(background.layer == -100 and background.surface != null and background.panels.size() == 2, "current consumer really constructs sky and ridge on independent gameplay canvas")
		if background.panels.size() != 2:
			viewport.free()
			continue
		var sky := background.panels[0]
		var ridge := background.panels[1]
		_check(sky.get_parent() == background.surface and ridge.get_parent() == background.surface and not sky.centered and not ridge.centered, "current measured sprites are actual uncentered surface children")
		_check(sky.texture == PlainsBackground.TEXTURES[0] and sky.texture.resource_path == "res://assets/plains_v3/background_layers/sky.png", "current sky uses its original independent sky source")
		_check(ridge.texture == PlainsBackground.RIDGE and ridge.texture.resource_path == "res://assets/region_production_v3/spaces/distant_limestone_ridge_v1/source.png", "current geology uses its actual admitted ridge source")
		_check(sky.material is ShaderMaterial and ridge.material is ShaderMaterial and sky.material != ridge.material, "current planes own separate real ShaderMaterials")
		if sky.material is ShaderMaterial and ridge.material is ShaderMaterial:
			var sky_material := sky.material as ShaderMaterial
			var ridge_material := ridge.material as ShaderMaterial
			_check(sky_material.shader == PlainsBackground.DISTANCE_SHADER and ridge_material.shader == PlainsBackground.DISTANCE_SHADER, "both actual materials bind the admitted distance shader")
			var original_mist: Variant = sky_material.get_shader_parameter("mist")
			var ridge_mist: Variant = ridge_material.get_shader_parameter("mist")
			sky_material.set_shader_parameter("mist", 0.93)
			_check(ridge_material.get_shader_parameter("mist") == ridge_mist and sky_material.get_shader_parameter("mist") != ridge_mist, "changing sky material cannot mutate the ridge material")
			sky_material.set_shader_parameter("mist", original_mist)
		var domain := background._shared_domain()
		var center := domain.get_center()
		var middle: Array[Vector2] = []
		var horizontal: Array[Vector2] = []
		var vertical: Array[Vector2] = []
		for location: Vector2 in [center, center + Vector2(1000, 0), center + Vector2(0, 1000), domain.position, Vector2(domain.end.x, domain.position.y), domain.end, Vector2(domain.position.x, domain.end.y)]:
			viewport.canvas_transform = Transform2D(0.0, Vector2(size) * 0.5 - location)
			background._update_panels()
			var positions: Array[Vector2] = []
			for index: int in background.panels.size():
				var panel := background.panels[index]
				var rect := Rect2(panel.position, panel.texture.get_size() * panel.scale)
				positions.append(panel.position)
				_check(panel.visible and panel.scale.x > 0 and is_equal_approx(panel.scale.x, panel.scale.y), "actual current plane keeps uniform visible source scale at all camera-domain corners")
				_check(rect.position.x <= 0 and rect.end.x >= size.x and rect.end.y >= size.y, "actual current sky/ridge covers horizontal extremes and lower screen at three aspect ratios")
				if index == 0:
					_check(rect.position.y <= 0, "actual current sky also covers vertical camera-domain extremes")
				else:
					_check(rect.position.y <= size.y * 0.5, "actual ridge source bounds reach the horizon without treating transparent skyline as full-screen sky")
			if location == center: middle = positions
			elif location == center + Vector2(1000, 0): horizontal = positions
			elif location == center + Vector2(0, 1000): vertical = positions
		_check(horizontal[0].x < middle[0].x and horizontal[1].x < middle[1].x and absf(horizontal[1].x - middle[1].x) > absf(horizontal[0].x - middle[0].x) * 3.0, "actual current ridge and sky have different horizontal camera travel")
		_check(vertical[0].y < middle[0].y and vertical[1].y < middle[1].y and absf(vertical[1].y - middle[1].y) > absf(vertical[0].y - middle[0].y) * 3.0, "actual current ridge and sky have different vertical camera travel")
		_check(is_equal_approx(horizontal[0].y, middle[0].y) and is_equal_approx(horizontal[1].y, middle[1].y) and is_equal_approx(vertical[0].x, middle[0].x) and is_equal_approx(vertical[1].x, middle[1].x), "actual default environment preserves independent camera axes")
		viewport.free()
