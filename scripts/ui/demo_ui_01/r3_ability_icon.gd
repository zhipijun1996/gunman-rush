class_name DemoAbilityIcon
extends Control
## Availability is set by the HUD from the existing traversal/jump states.
const COLORS := preload("res://scripts/ui/demo_ui_01/clockwork_theme.gd")
var kind: StringName = &"double_jump"
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(25, 26)
func _draw() -> void:
	if kind == &"grapple":
		var rope := PackedVector2Array([Vector2(4, 21), Vector2(7, 16), Vector2(15, 12), Vector2(18, 8), Vector2(18, 4)])
		draw_polyline(rope, COLORS.INK, 5, false)
		draw_polyline(rope, COLORS.PAPER, 2, false)
		draw_arc(Vector2(15, 5), 5, -PI * 0.5, PI * 0.8, 12, COLORS.INK, 5, false)
		draw_arc(Vector2(15, 5), 5, -PI * 0.5, PI * 0.8, 12, COLORS.BRASS, 2, false)
	else:
		for y: int in [9, 18]:
			var arrow := PackedVector2Array([Vector2(4, y + 2), Vector2(12, y - 5), Vector2(20, y + 2)])
			draw_polyline(arrow, COLORS.INK, 6, false)
			draw_polyline(arrow, COLORS.PAPER, 3, false)
