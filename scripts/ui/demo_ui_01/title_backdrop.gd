extends Control
## Title illustration only. Menu actions remain independent native Controls.
const BACKGROUND := preload("res://assets/ui/demo_ui_01/r2/title_impression.png")
const LOGO := preload("res://assets/ui/demo_ui_01/r2/title_logo.png")
var _logo: TextureRect
var reduced_effects := false
var _time := 0.0
var _logo_origin := Vector2.ZERO
var _physical_width := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scene := TextureRect.new()
	scene.texture = BACKGROUND
	scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scene)
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.025, 0.045, 0.065, 0.78), Color(0.025, 0.045, 0.065, 0.22), Color.TRANSPARENT])
	gradient.offsets = PackedFloat32Array([0.0, 0.39, 0.70])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2.RIGHT
	shade.texture = texture
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_logo = TextureRect.new()
	_logo.texture = LOGO
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	if not is_instance_valid(_logo): return
	_physical_width = size.x
	var compact := _physical_width < 900
	_logo_origin = Vector2(size.x * (0.54 if compact else 0.40), size.y * 0.025)
	_logo.position = _logo_origin
	_logo.size = Vector2(size.x * (0.45 if compact else 0.59), size.y * 0.95)

func _process(delta: float) -> void:
	if not is_equal_approx(_physical_width, size.x): _layout()
	if reduced_effects: return
	_time += delta
	# A restrained camera-like drift, not a painted imitation of a moving hand.
	_logo.position = _logo_origin + Vector2(0, roundf(sin(_time * 0.6) * 2.0))
	queue_redraw()

func _draw() -> void:
	if reduced_effects: return
	# A few low-contrast windborne motes; no particle emitter or gameplay state.
	for i: int in 9:
		var travel := fmod(_time * 11.0 + i * 157.0, maxf(1, size.x))
		var altitude := size.y * (0.63 + fmod(i * 0.137, 0.34)) - sin(_time * 0.4 + i) * 9
		draw_rect(Rect2(Vector2(travel, altitude), Vector2(2, 2)), Color(0.91, 0.77, 0.45, 0.22))
