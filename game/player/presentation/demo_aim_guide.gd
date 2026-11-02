class_name DemoAimGuide
extends Node2D

var controller: PlayerController

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(controller) or not controller.active:
		return
	var aim := controller.router.aim_direction
	if not aim.is_zero_approx():
		var origin := Vector2.ZERO
		var visual := get_parent().get_node_or_null("CourierVisual") as CourierVisual
		if visual != null and visual.is_node_ready(): origin=to_local(visual.muzzle_position(aim))
		draw_line(origin + aim * 4, origin + aim * 60, Color(0.55, 0.9, 0.95, 0.8), 2)
		draw_arc(origin + aim * 64, 5, 0, TAU, 16, Color(0.75, 0.95, 1), 1.5)
