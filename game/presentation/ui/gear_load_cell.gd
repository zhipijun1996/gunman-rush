@static_unload
extends Control
## Native load indicator: one cog per gear slot, without runtime art assets.
const COLORS := preload("res://game/presentation/ui/demo_ui_01/clockwork_theme.gd")
var occupied := false

func _init() -> void:
	custom_minimum_size = Vector2(26, 26)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED: queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.46
	var outline: PackedVector2Array = []
	for index: int in 32:
		var angle := TAU * float(index) / 32.0
		var tooth := 1.0 if index % 4 in [1, 2] else 0.77
		outline.append(center + Vector2.from_angle(angle) * radius * tooth)
	var edge := COLORS.TEAL if occupied else COLORS.MUTED.darkened(0.4)
	draw_colored_polygon(outline, edge if occupied else COLORS.INK.lightened(0.07))
	outline.append(outline[0])
	draw_polyline(outline, edge, 1.0, false)
	draw_circle(center, radius * 0.34, COLORS.INK)
	draw_arc(center, radius * 0.34, 0, TAU, 16, edge, 1.0, false)
