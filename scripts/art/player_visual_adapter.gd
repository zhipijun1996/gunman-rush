class_name PlayerVisualAdapter
extends Node
## Read-only presentation consumer. Never consumes input or changes Motor/resources.
const RECOIL_POSE_SECONDS := 0.14
@export var motor: PlayerMotor
@export var controller: PlayerController
@export var visual: CourierVisual
var _recoil_remaining := 0.0
var _dead := false
var _session := -1

func _ready() -> void:
	process_priority = -10
	_session = controller.session_id
	controller.died.connect(_on_died)
	controller.shoot_ability.shot_fired.connect(_on_shot_fired)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if controller.session_id != _session:
		_session = controller.session_id
		_recoil_remaining = 0.0
	if _dead:
		if not controller.active:
			return
		_dead = false
	# Temporary inactive states (menus, overview, stage completion) are not death.
	if not controller.active:
		return
	_recoil_remaining = maxf(0.0, _recoil_remaining - delta)
	var aim := controller.router.aim_direction
	if not aim.is_zero_approx():
		visual.set_aim_direction(aim)
		if not is_zero_approx(aim.x):
			visual.set_facing(aim.x)
	elif _recoil_remaining <= 0.0 and absf(motor.normal_velocity.x) > 1.0:
		visual.set_facing(motor.normal_velocity.x)
		visual.set_aim_direction(Vector2(visual.facing, 0.0))
	if _recoil_remaining > 0.0:
		visual.set_state(&"recoil")
	elif not motor.is_on_floor():
		visual.set_state(&"jump" if motor.velocity.y < -1.0 else &"fall")
	elif absf(motor.normal_velocity.x) > 1.0:
		visual.set_state(&"run")
	else:
		visual.set_state(&"idle")

func _on_shot_fired(direction: Vector2, _shot_id: int) -> void:
	if _dead:
		return
	visual.set_aim_direction(direction)
	if not is_zero_approx(direction.x):
		visual.set_facing(direction.x)
	_recoil_remaining = RECOIL_POSE_SECONDS
	visual.set_state(&"recoil")

func _on_died() -> void:
	_dead = true
	_recoil_remaining = 0.0
	visual.set_state(&"death")
