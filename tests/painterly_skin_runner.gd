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
	painter.free()
	print("PAINTERLY SKIN: %d assertions, %d failures; real raster appearance/device performance pending" % [checks, failures])
	quit(1 if failures > 0 else 0)
