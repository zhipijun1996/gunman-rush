class_name DemoResourceTrack
extends Control
## Read-only calibrated linear reserve. Marks represent the real unit cost.
const COLORS := preload("res://scripts/ui/demo_ui_01/clockwork_theme.gd")
var current := 0.0
var capacity := 1.0
var step_size := 0.0
var color := COLORS.BRASS
var flash := 0.0
var _previous := -1.0
var _spent := 0.0
var _ghost := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO: custom_minimum_size = Vector2(186, 14)

func present(value: float, maximum: float, unit: float = 0.0) -> void:
	if _previous >= 0.0:
		if value > _previous: flash = 0.40
		elif value < _previous - 0.1:
			_spent = 0.30
			_ghost = maxf(_ghost, _previous)
	else:
		_ghost = value
	_previous = value
	current = value
	capacity = maximum
	step_size = unit
	queue_redraw()

func _process(delta: float) -> void:
	flash = maxf(0, flash - delta)
	_spent = maxf(0, _spent - delta)
	if _spent <= 0: _ghost = move_toward(_ghost, current, delta * maxf(1, capacity) * 4)
	if flash > 0 or _spent > 0 or not is_equal_approx(_ghost, current): queue_redraw()

func _draw() -> void:
	var height := minf(14, size.y)
	var bounds := Rect2(0, (size.y - height) * 0.5, size.x, height)
	var rim := COLORS.plate(Color(COLORS.INK, 0.98), Color(COLORS.BRASS, 0.76), 0)
	rim.set_corner_radius_all(5)
	rim.shadow_size = 0
	draw_style_box(rim, bounds)
	var inner := bounds.grow(-3)
	if not inner.has_area(): return
	var fraction := clampf(current / maxf(capacity, 0.001), 0, 1)
	var ghost_fraction := clampf(_ghost / maxf(capacity, 0.001), fraction, 1)
	if _spent > 0:
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * ghost_fraction, inner.size.y)), Color(COLORS.CORAL, 0.65))
	if fraction > 0:
		var fill := COLORS.TEAL if flash > 0 else color
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * fraction, inner.size.y)), fill)
		draw_line(inner.position, inner.position + Vector2(inner.size.x * fraction, 0), Color(COLORS.PAPER, 0.65), 1, false)
	if step_size > 0.0:
		for i: int in mini(100, floori(capacity / step_size)):
			var x := inner.position.x + inner.size.x * (i + 1) * step_size / maxf(capacity, 0.001)
			if x < inner.end.x: draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(COLORS.INK, 0.85), 2, false)
	if current <= 0:
		draw_line(inner.position, inner.end, Color(COLORS.CORAL, 0.65), 1, false)
