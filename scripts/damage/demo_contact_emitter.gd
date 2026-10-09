class_name DemoContactEmitter
extends Node2D

# A local contact source with stable exposure IDs and game-clock cadence.
var policy: FrameDamagePolicy
var controller: PlayerController
var source_id: StringName = &"contact"
var kind := DamageRequest.Kind.MONSTER
var amount := 1.0
var half_size := Vector2(14, 16)
var interval := 0.7
var enabled := true
var _was_touching := false
var _exposure := 0
var _pulse := 0
var _next_pulse := 0.0
var _last_actor_epoch := -1
var _previous_relative := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 900

func _physics_process(_delta: float) -> void:
	if policy == null or policy.lifetime == null or not policy.lifetime.active or not is_instance_valid(controller) or not controller.active:
		return
	var life := policy.lifetime
	var relative := controller.motor.global_position - global_position
	if _last_actor_epoch != life.actor_epoch:
		_previous_relative = relative
		_was_touching = false
		_last_actor_epoch = life.actor_epoch
	var size := half_size + Vector2(12, 18)
	var touching := enabled and segment_intersects_bounds(_previous_relative, relative, Rect2(-size, size * 2.0))
	_previous_relative = relative
	if not touching:
		_was_touching = false
		return
	if not _was_touching:
		_exposure += 1
		_pulse = 0
		_next_pulse = policy.clock
	_was_touching = true
	if policy.clock < _next_pulse:
		return
	_next_pulse = policy.clock + maxf(interval, 0.01)
	_pulse += 1
	var request := DamageRequest.new()
	request.token = life.token()
	request.actor_epoch = life.actor_epoch
	request.health_epoch = controller.actor_resources.health.epoch
	request.target_id = &"player"
	request.source_id = source_id
	request.event_id = StringName("%s:%d:%d:%d" % [source_id, life.actor_epoch, _exposure, _pulse])
	request.kind = kind
	request.amount = amount
	request.physics_tick = Engine.get_physics_frames()
	policy.submit(request)

static func segment_intersects_bounds(start: Vector2, finish: Vector2, bounds: Rect2) -> bool:
	if bounds.has_point(start) or bounds.has_point(finish):
		return true
	var corners: Array[Vector2] = [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]
	for index: int in 4:
		if Geometry2D.segment_intersects_segment(start, finish, corners[index], corners[(index + 1) % 4]) != null:
			return true
	return false
