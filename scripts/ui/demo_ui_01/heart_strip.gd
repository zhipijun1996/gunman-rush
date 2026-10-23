class_name DemoHeartStrip
extends Control
## One socket per real HP. Partial fill reflects actual fractional state only.
const COLORS := preload("res://scripts/ui/demo_ui_01/clockwork_theme.gd")
const SHAPE := [Vector2(1, 2), Vector2(3, 0), Vector2(6, 0), Vector2(8, 2), Vector2(10, 0), Vector2(13, 0), Vector2(15, 2), Vector2(15, 6), Vector2(8, 13), Vector2(1, 6)]
const HEART_SCALE := 1.125
var current := 0.0
var capacity := 0.0
var delayed := 0.0
var feedback := 0.0
var healing := false
var columns := 8
var cell := Vector2(25, 26)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func present(value: float, maximum: float) -> void:
	if capacity > 0.0 and value != current:
		healing = value > current
		feedback = 0.65
		if not healing: delayed = current
	else:
		if capacity <= 0.0: delayed = value
	current = value
	capacity = maximum
	var rows := ceili(ceilf(capacity) / float(columns))
	custom_minimum_size = Vector2(mini(ceili(capacity), columns) * cell.x, maxi(1, rows) * cell.y)
	size = custom_minimum_size
	queue_redraw()

func _process(delta: float) -> void:
	feedback = maxf(0.0, feedback - delta)
	if feedback < 0.32: delayed = move_toward(delayed, current, delta * maxf(4.0, capacity))
	queue_redraw()

func _heart(origin: Vector2, amount: float, color: Color) -> void:
	if amount <= 0.0: return
	var points := PackedVector2Array()
	for point: Vector2 in SHAPE: points.append(origin + point * HEART_SCALE)
	if amount >= 1.0:
		draw_colored_polygon(points, color)
		return
	# Clip the existing shape by the exact observed fraction; no half-heart rule.
	var height := 13.0 * HEART_SCALE
	var bottom := origin.y + height
	var cut := bottom - height * amount
	var clipped := PackedVector2Array()
	for i: int in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		if a.y >= cut: clipped.append(a)
		if (a.y >= cut) != (b.y >= cut): clipped.append(a.lerp(b, (cut - a.y) / (b.y - a.y)))
	if clipped.size() >= 3: draw_colored_polygon(clipped, color)

func _draw() -> void:
	for i: int in ceili(capacity):
		var origin := Vector2(i % columns, i / columns) * cell + Vector2(2, 4)
		var available := clampf(capacity - i, 0.0, 1.0)
		var outline := PackedVector2Array()
		for point: Vector2 in SHAPE: outline.append(origin + point * HEART_SCALE)
		outline.append(outline[0])
		# No surrounding sockets, panels or plates: outline only the heart itself.
		draw_polyline(outline, Color(COLORS.INK, 0.95), 3, false)
		_heart(origin, available, Color("48544f"))
		if not healing: _heart(origin, clampf(delayed - i, 0, available), COLORS.BRASS)
		_heart(origin, clampf(current - i, 0, available), COLORS.TEAL if healing and feedback > 0 else COLORS.CORAL)
		if current > i + 0.75: draw_line(origin + Vector2(4, 2), origin + Vector2(6, 2), COLORS.PAPER, 1, false)
