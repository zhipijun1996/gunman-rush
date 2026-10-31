class_name Blob47PlayerVisual
extends Node2D
## New neutral scale actor for the foundation study; observes the real motor.
## It does not replace the production character or claim final animation.
var motor: PlayerMotor
var controller: PlayerController
var _clock := 0.0

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _draw() -> void:
	var ink := Color("353e44")
	var facing := 1.0 if controller.router.aim_direction.x >= 0 else -1.0
	var stride := sin(_clock * 13) * 3 if motor.is_on_floor() and absf(motor.velocity.x) > 10 else 0.0
	draw_line(Vector2(-5, 7), Vector2(-5 + stride, 16), ink, 7)
	draw_line(Vector2(5, 7), Vector2(5 - stride, 16), ink, 7)
	draw_style_box(Blob47Platform._box(Color("d8a54e"), ink), Rect2(-10, -7, 20, 18))
	draw_style_box(Blob47Platform._box(Color("f0dbb2"), ink), Rect2(-11, -19, 22, 17))
	draw_rect(Rect2(-12, -18, 24, 6), Color("678a85"))
	draw_circle(Vector2(facing * 6, -9), 2, ink)
	draw_polygon(PackedVector2Array([Vector2(-facing*8,-1), Vector2(-facing*24,-5+sin(_clock*5)*2), Vector2(-facing*20,2), Vector2(-facing*8,4)]), PackedColorArray([Color("b85d4e")]))
	var direction := controller.router.aim_direction.normalized()
	draw_line(Vector2(0, 2), direction * 20 + Vector2(0, 2), ink, 7)
	draw_line(direction * 10 + Vector2(0, 1), direction * 20 + Vector2(0, 1), Color("8fa5a0"), 3)
