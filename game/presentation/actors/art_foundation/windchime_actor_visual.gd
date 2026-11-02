class_name WindchimeActorVisual
extends Node2D
## Silhouette courier presentation. Reads the production Motor and accepted shots.
var motor: PlayerMotor
var controller: PlayerController
var _clock := 0.0
var _flash := 0.0

func _ready() -> void:
	controller.shoot_ability.shot_fired.connect(func(_direction: Vector2, _id: int) -> void: _flash = .07)

func _process(delta: float) -> void:
	_clock += delta
	_flash = maxf(0, _flash - delta)
	var anchor := motor.get_node("CourierVisual") as CourierVisual
	anchor.muzzle_position(controller.router.aim_direction.normalized())
	queue_redraw()

func _draw() -> void:
	var ink := Color("23362e")
	var cream := Color("f4e6bd")
	var coral := Color("d96c57")
	var facing := 1.0 if controller.router.aim_direction.x >= 0 else -1.0
	var moving := motor.is_on_floor() and absf(motor.velocity.x) > 10
	var stride := sin(_clock * 16) * 5.5 if moving else 0.0
	var bob := absf(sin(_clock * 16)) if moving else sin(_clock * 2) * .4
	draw_set_transform(Vector2(0, -bob), 0, Vector2(facing, 1))
	# Wind-blown cloth extends behind the body, always above the real feet.
	var flutter := sin(_clock * 6) * 2
	draw_colored_polygon(PackedVector2Array([Vector2(-5,-7), Vector2(-18,-8+flutter), Vector2(-31,-3+flutter), Vector2(-24,0+flutter), Vector2(-30,3+flutter), Vector2(-14,1), Vector2(-3,-2)]), coral)
	draw_line(Vector2(-4,7), Vector2(-6 + stride,16), ink, 5, true)
	draw_line(Vector2(4,7), Vector2(6 - stride,16), ink, 5, true)
	draw_line(Vector2(-6 + stride,16), Vector2(-1 + stride,16), ink, 3, true)
	draw_line(Vector2(6 - stride,16), Vector2(10 - stride,16), ink, 3, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-7,-6),Vector2(6,-6),Vector2(8,8),Vector2(-9,8)]), cream)
	draw_colored_polygon(PackedVector2Array([Vector2(-7,-5),Vector2(-3,-4),Vector2(-4,8),Vector2(-9,8)]), Color("a59e83"))
	draw_circle(Vector2(0,-13), 10, coral)
	draw_circle(Vector2(3,-12), 7.2, ink)
	draw_circle(Vector2(6,-13), 1.8, cream)
	draw_line(Vector2(-3,0),Vector2(8,2), ink, 5, true)
	draw_set_transform(Vector2.ZERO)
	var aim := controller.router.aim_direction.normalized()
	var shoulder := Vector2(facing * 3, -1 - bob)
	# Input aiming and swept barrel travel already share this technical anchor.
	# Draw the new weapon at that same point, retaining the verified aim contract.
	var anchor := motor.get_node("CourierVisual") as CourierVisual
	var muzzle := to_local(anchor.visible_muzzle_position())
	draw_line(shoulder, muzzle, ink, 6, true)
	draw_line(shoulder + aim * 10 + Vector2(0,-2), muzzle + Vector2(0,-2), Color("bdab77"), 2, true)
	if _flash > 0:
		draw_circle(muzzle + aim * 6, 5, cream)
