extends Control
## Native title ornament. It owns no input, clock, resource or game state.
var reduced_effects := false
var _time := 0.0
const BRASS := Color("bca36d")
const DARK := Color("172d2c")
const LIGHT := Color("e8d7ab")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if not reduced_effects:
		_time += delta
		queue_redraw()

func _point(center: Vector2, radius: float, angle: float) -> Vector2:
	return (center + Vector2.from_angle(angle) * radius).snapped(Vector2(2, 2))

func _ring(center: Vector2, radius: float, color: Color, width: float = 2.0) -> void:
	var points := PackedVector2Array()
	for i: int in 97:
		points.append(_point(center, radius, TAU * i / 96.0))
	draw_polyline(points, color, width, false)

func _draw() -> void:
	var center := size * Vector2(0.5, 0.40)
	var radius := minf(size.x * 0.35, size.y * 0.32)
	var shadow := Color(DARK, 0.8)
	draw_circle(center + Vector2(8, 10), radius + 16, shadow, true, -1, false)
	_ring(center, radius + 16, Color(BRASS, 0.22), 3)
	_ring(center, radius + 8, Color(BRASS, 0.65), 2)
	_ring(center, radius - 4, Color(BRASS, 0.18), 2)
	_ring(center, radius * 0.57, Color(BRASS, 0.13), 2)
	for i: int in 60:
		var angle := TAU * i / 60.0 - PI * 0.5
		var major := i % 5 == 0
		var inner := radius - (18.0 if major else 8.0)
		draw_line(_point(center, inner, angle), _point(center, radius - 2, angle), Color(BRASS, 0.78 if major else 0.25), 4 if major else 2, false)
	for i: int in 4:
		var angle := TAU * i / 4.0 - PI * 0.5
		var p := _point(center, radius - 35, angle)
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(LIGHT, 0.7))
	# Two different rates and an off-centre broken hand suggest disorder.
	var minute := -PI * 0.5 + _time * 0.025
	var hour := PI * 0.58 - _time * 0.009
	draw_line(center, _point(center, radius * 0.70, minute), Color(LIGHT, 0.84), 4, false)
	draw_line(center, _point(center, radius * 0.45, hour), BRASS, 6, false)
	draw_line(center + Vector2(18, -10), _point(center, radius * 0.42, 0.13), Color(BRASS, 0.3), 2, false)
	draw_rect(Rect2(center - Vector2(7, 7), Vector2(14, 14)), DARK)
	draw_rect(Rect2(center - Vector2(3, 3), Vector2(6, 6)), LIGHT)
	var pivot := center + Vector2(0, radius + 17)
	var swing := sin(_time * 1.5) * 0.08
	var bob := pivot + Vector2(sin(swing), cos(swing)) * radius * 0.63
	draw_line(pivot, bob, Color(BRASS, 0.55), 3, false)
	_ring(bob, 17, Color(BRASS, 0.64), 3)
	draw_rect(Rect2(bob - Vector2(5, 5), Vector2(10, 10)), Color(BRASS, 0.55))
	# Hanging wind chimes remain a quiet silhouette behind the clock.
	for i: int in 3:
		var x := center.x + radius + 36 + i * 22
		var length := 70.0 + i * 28.0
		var drift := sin(_time * 0.8 + i) * 2
		draw_line(Vector2(x, center.y - 78), Vector2(x + drift, center.y - 78 + length), Color(BRASS, 0.20), 2, false)
		draw_rect(Rect2(x - 4 + drift, center.y - 78 + length, 8, 29 - i * 5), Color(BRASS, 0.35))
