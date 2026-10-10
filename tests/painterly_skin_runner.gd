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
	_check(PlainsTerrainSkin.PAINT_SCALE == 0.14, "caps use fixed proportional scale")
	var background := PlainsBackground.new()
	root.add_child(background)
	await process_frame
	await process_frame
	_check(background.layer == -100 and background.surface != null, "shared background keeps gameplay canvas independent")
	for texture: Texture2D in PlainsBackground.TEXTURES:
		_check(texture.get_width() == 1672 and texture.get_height() == 941, "latest finite background panels imported")
	for size: Vector2 in [Vector2(1280, 720), Vector2(720, 1280), Vector2(2560, 720)]:
		var factor := maxf(size.x / 1672.0, size.y / 941.0) * 1.12
		var width := 1672.0 * factor
		for drift: float in [-1.0, 0.0, 1.0]:
			var x := (size.x - width) * 0.5 - drift * (width - size.x) * 0.5 * 0.16
			_check(x <= 0.0 and x + width >= size.x and 941.0 * factor >= size.y, "overscan covers camera extremes without panel repeat or blank gaps")
	background.free()
	painter.free()
	print("PAINTERLY SKIN: %d assertions, %d failures; real raster appearance/device performance pending" % [checks, failures])
	quit(1 if failures > 0 else 0)
