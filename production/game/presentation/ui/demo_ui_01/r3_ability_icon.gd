class_name DemoAbilityIcon
extends Control
## Availability is set by the HUD from the existing traversal/jump states.
const COLORS := preload("res://game/presentation/ui/demo_ui_01/clockwork_theme.gd")
var kind: StringName = &"double_jump"
var guard_ready := false
var guard_active := false
var guard_cooldown := 0.0
var guard_fraction := 0.0
func present_guard(ready: bool, active: bool, cooldown: float, fraction: float) -> void:
	guard_ready=ready;guard_active=active;guard_cooldown=cooldown;guard_fraction=fraction
	queue_redraw()
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(25, 26)
func _draw() -> void:
	if kind == &"recoil_guard":
		var ink := COLORS.PAPER if guard_active else COLORS.BRASS if guard_ready else COLORS.MUTED
		var shield := PackedVector2Array([Vector2(3,5),Vector2(12,2),Vector2(22,5),Vector2(20,17),Vector2(12,24),Vector2(5,17),Vector2(3,5)])
		draw_polyline(shield,COLORS.INK,5,false)
		draw_polyline(shield,ink,2,false)
		var bolt := PackedVector2Array([Vector2(15,6),Vector2(8,14),Vector2(13,14),Vector2(10,20),Vector2(18,11),Vector2(12,11)])
		draw_colored_polygon(bolt,ink)
		if guard_cooldown>0:
			draw_arc(Vector2(12,13),12,-PI*.5,-PI*.5+TAU*(1-guard_fraction),24,COLORS.BRASS,2,false)
	elif kind == &"grapple":
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
