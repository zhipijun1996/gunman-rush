class_name PlayerVisualAdapter
extends Node
## Read-only presentation consumer. Never consumes input or changes Motor/resources.
const RECOIL_POSE_SECONDS := 0.14
@export var motor: PlayerMotor
@export var controller: PlayerController
@export var visual: CourierVisual
var _recoil_remaining := 0.0
var _hurt_remaining := 0.0
var _dead := false
var _session := -1
var _double_remaining := 0.0
var _land_remaining := 0.0
var _jump_start_remaining := 0.0

func _ready() -> void:
	process_priority = -10
	_session = controller.session_id
	controller.actor_resources.health.changed.connect(_on_health_changed)
	controller.segment_returned.connect(_on_segment_returned)
	controller.died.connect(_on_died)
	controller.landed.connect(func() -> void:
		visual.landing_pose = 1.0
		_land_remaining = .12)
	controller.jump_ability.jumped.connect(func() -> void:
		_jump_start_remaining = .085
		if controller.jump_ability.used_jumps >= 2:
			_double_remaining = .28
			visual.set_state(&"double_jump"))
	controller.shoot_ability.shot_fired.connect(_on_shot_fired)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if controller.session_id != _session:
		_session = controller.session_id
		_recoil_remaining = 0.0
		_hurt_remaining = 0.0
		visual.modulate = Color.WHITE
		_double_remaining = 0
		_land_remaining = 0
		visual.clear_transition()
	if _dead:
		if not controller.active:
			return
		_dead = false
	# Temporary inactive states (menus, overview, stage completion) are not death.
	if not controller.active:
		return
	_hurt_remaining = maxf(0.0, _hurt_remaining - delta)
	_double_remaining = maxf(0,_double_remaining-delta)
	_land_remaining = maxf(0,_land_remaining-delta)
	_jump_start_remaining = maxf(0,_jump_start_remaining-delta)
	visual.weapon_tier = controller.shoot_ability.weapon.tier
	visual.weapon_mode = controller.shoot_ability.weapon.mode
	visual.weapon_in_hand=visual.weapon_mode not in [5,7] or controller.shoot_ability.behavior().current_entities().is_empty()
	visual.modulate = Color(1.0, 0.3, 0.28) if _hurt_remaining > 0.0 and int(_hurt_remaining * 35.0) % 2 == 0 else Color.WHITE
	_recoil_remaining = maxf(0.0, _recoil_remaining - delta)
	visual.movement_speed = motor.normal_velocity.x
	var aim := controller.router.aim_direction
	if not aim.is_zero_approx():
		visual.set_aim_direction(aim)
		if not is_zero_approx(aim.x):
			visual.set_facing(aim.x)
	elif _recoil_remaining <= 0.0 and absf(motor.normal_velocity.x) > 1.0:
		visual.set_facing(motor.normal_velocity.x)
		visual.set_aim_direction(Vector2(visual.facing, 0.0))
	visual.wall_surface_x = visual.to_local(controller.traversal.wall_point).x
	if controller.traversal.state in [&"wall_attach",&"wall_kick"]:
		visual.set_facing(-controller.traversal.wall_normal)
	elif controller.traversal.state in [&"hook_cast",&"hook_fly",&"hook_pull",&"hook_kick",&"hook_contact_kick",&"hook_miss",&"hook_retract"]:
		visual.set_facing(controller.traversal.hook_forward)
	if _hurt_remaining > 0.0:
		visual.set_state(&"hurt")
	elif controller.traversal.state != &"free":
		visual.set_state(controller.traversal.state)
	elif controller.shoot_ability.behavior().visual_state()!=&"idle":
		var pose := controller.shoot_ability.behavior().visual_state()
		if pose==&"weapon_skill":
			pose=&"machine_recoil" if visual.weapon_mode==1 else &"laser_fire" if visual.weapon_mode==2 else &"blade_throw" if visual.weapon_mode in [3,4,5] else &"bomb_place" if visual.weapon_mode in [6,7] else &"weapon_skill"
		visual.set_state(pose)
	elif _double_remaining > 0:
		visual.set_state(&"double_jump")
	elif _recoil_remaining > 0.0:
		visual.set_state(&"machine_recoil" if controller.shoot_ability.weapon.mode==1 else &"recoil")
	elif _jump_start_remaining > 0 and not motor.is_on_floor():
		visual.set_state(&"jump_start")
	elif not motor.is_on_floor():
		visual.set_state(&"jump" if motor.velocity.y < -1.0 else &"fall")
	elif _land_remaining > 0 and motor.is_on_floor():
		visual.set_state(&"land")
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
	visual.shot_pose()
	_recoil_remaining = RECOIL_POSE_SECONDS
	visual.set_state(&"machine_recoil" if controller.shoot_ability.weapon.mode==1 else &"recoil")

func _on_died() -> void:
	_dead = true
	_hurt_remaining = 0.0
	visual.modulate = Color.WHITE
	_recoil_remaining = 0.0
	visual.set_state(&"death")

func _on_health_changed(result: ActorResourceResult) -> void:
	if result.operation == &"damage" and result.status == ActorResourceResult.Status.APPLIED and result.amount_applied < 0.0 and not result.snapshot.terminal:
		_hurt_remaining = 0.28
		visual.set_state(&"hurt")

func _on_segment_returned() -> void:
	_session = controller.session_id
	_recoil_remaining = 0.0
	_hurt_remaining = 0.28
	visual.set_state(&"hurt")
