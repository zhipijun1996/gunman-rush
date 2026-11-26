class_name WorldPushCrate
extends MechanismSolid

@export var body_size := Vector2(64,64)
@export var max_push_speed := 100.0
@export var pressure_weight := false
var fall_speed := 0.0
var grounded := false

func _ready() -> void:
	make_solid(body_size)
	add_to_group(&"mechanism_pressure_weight")

func pressure_bounds() -> Rect2:
	if not pressure_weight or not grounded: return Rect2()
	return Rect2(body.global_position-body_size/2,body_size)

func _physics_process(delta: float) -> void:
	if controller == null or not lifetime.active: return
	grounded = travel_fraction(Vector2.DOWN*0.4,true) < 1.0
	var axis := controller.router.axis
	var motor := controller.motor
	var direction := 0.0
	if grounded and motor.is_on_floor() and controller.active and not controller.actor_resources.health.terminal:
		for i: int in motor.get_slide_collision_count():
			var hit := motor.get_slide_collision(i)
			if hit.get_collider() == body and hit.get_normal().x*axis < -0.01:
				direction = signf(axis)
	if direction != 0:
		var speed := minf(max_push_speed,motor.tuning.ground_speed*absf(axis))
		var shift := Vector2.RIGHT*direction*speed*delta
		body.position += shift*travel_fraction(shift,true)
	if direction != 0: body.force_update_transform()
	if grounded: fall_speed = 0
	else:
		fall_speed = minf(motor.tuning.max_normal_fall_speed,fall_speed+motor.tuning.gravity*delta)
		var shift := Vector2.DOWN*fall_speed*delta
		var rider := rider_contact()
		var ratio := travel_fraction(shift,not rider.is_empty())
		shift *= ratio
		if rider.is_empty() or rider_fits(shift):
			if not rider.is_empty(): move_rider(shift)
			body.position += shift
			body.force_update_transform()
		if ratio < 1.0: fall_speed = 0
	queue_redraw()

func element_state() -> Dictionary:
	return {"offset":[body.position.x,body.position.y],"fall_speed":fall_speed}
func element_restore(data: Dictionary) -> void:
	body.position = FixedWorldProvider.point(data.offset)
	fall_speed = data.fall_speed
	grounded = false
	queue_redraw()

func _draw() -> void:
	if body == null: return
	var bounds := Rect2(body.position-body_size/2,body_size)
	BeamHardware.ballast(self,bounds,pressure_weight,true)
