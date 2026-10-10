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
		draw_line(aim * 22, aim * 68, Color(0.55, 0.9, 0.95, 0.8), 2)
		draw_arc(aim * 72, 5, 0, TAU, 16, Color(0.75, 0.95, 1), 1.5)
