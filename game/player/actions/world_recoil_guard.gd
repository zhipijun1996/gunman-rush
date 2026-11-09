class_name WorldRecoilGuard
extends Node
## Q is a permission on real recoil movement, never a global invulnerability flag.
var controller: PlayerController
var owned := false
# Kept as the existing public field; landing and real traversal refills rearm it.
var landing_ready := false
var cooldown_seconds := 2.0
var cooldown := 0.0
var active := false
var _packet := -1
var _last_position := Vector2.ZERO
var _moving := false

func _ready() -> void:
	process_physics_priority = 500
	_last_position = controller.motor.position
	controller.landed.connect(func() -> void: landing_ready = true)
	controller.traversal.traversal_resources_refilled.connect(func(_source: StringName) -> void: landing_ready = true)
	controller.router.cancelled.connect(func(_reason: String) -> void: cancel())
	controller.shoot_ability.shot_fired.connect(_shot)

func _shot(_direction: Vector2,_shot_id: int) -> void:
	var packet := controller.shoot_ability.packet_id
	if packet == _packet: return
	_packet = packet
	if owned and landing_ready and cooldown<=0 and controller.active:
		active = true
		landing_ready = false
		cooldown = cooldown_seconds

func _physics_process(delta: float) -> void:
	if controller.active and not get_tree().paused: cooldown = maxf(0,cooldown-delta)
	var motor := controller.motor
	_moving = motor.position.distance_to(_last_position)>0.05 and motor.recoil_burst_remaining>0 and not motor.recoil_velocity.is_zero_approx()
	_last_position = motor.position
	if active and not _moving: cancel()

func protects(request: DamageRequest) -> bool:
	return owned and active and _moving and (request.kind==DamageRequest.Kind.MONSTER or request.hazard_category==&"phase_light")

func cancel() -> void:
	active = false
	_moving = false
