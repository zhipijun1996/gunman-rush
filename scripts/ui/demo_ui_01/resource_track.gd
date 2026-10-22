class_name DemoResourceTrack
extends Control
## A calibrated linear track, not an extra gameplay resource.
const COLORS := preload("res://scripts/ui/demo_ui_01/clockwork_theme.gd")
var current := 0.0
var capacity := 1.0
var step_size := 0.0
var color := COLORS.BRASS
var flash := 0.0
var _previous := -1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO: custom_minimum_size = Vector2(206, 12)

func present(value: float, maximum: float, unit: float = 0.0) -> void:
	if _previous >= 0.0 and value > _previous: flash = 0.45
	_previous = value
	current = value
	capacity = maximum
	step_size = unit
	queue_redraw()

func _process(delta: float) -> void:
	flash = maxf(0, flash - delta)
	if flash > 0: queue_redraw()

func _draw() -> void:
	var bounds := Rect2(0, 1, size.x, 10)
	draw_style_box(COLORS.plate(Color(COLORS.INK, 0.96), COLORS.EDGE, 0), bounds)
	var fraction := clampf(current / maxf(capacity, 0.001), 0, 1)
	draw_rect(Rect2(2, 3, (size.x - 4) * fraction, 6), COLORS.TEAL if flash > 0 else color)
	if step_size > 0.0:
		for i: int in mini(100, floori(capacity / step_size)):
			var x := 2 + (size.x - 4) * (i + 1) * step_size / capacity
			if x < size.x - 2: draw_line(Vector2(x, 2), Vector2(x, 10), COLORS.INK, 2)
