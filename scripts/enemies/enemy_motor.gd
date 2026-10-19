class_name EnemyMotor
extends CharacterBody2D

var patrol_speed := 0.0
var _ground_actor := false
var _knockback_requires_floor := false
var _knockback := Vector2.ZERO
var _knockback_seconds := 0.0
var _attraction_tick := -1
var _attraction := Vector2.ZERO
var _attraction_limit := 0.0

func configure(definition: EnemyDefinition) -> void:
	patrol_speed = definition.patrol_speed
	_ground_actor = not definition.aerial
	var shape := RectangleShape2D.new()
	shape.size = definition.collision_size
	($CollisionShape2D as CollisionShape2D).shape = shape

func step(intent: EnemyIntent, delta: float) -> bool:
	velocity = Vector2.ZERO
	if intent == null or not is_finite(delta) or delta <= 0.0 or intent.move_axis not in [-1, 0, 1] or not is_finite(intent.travel_limit) or intent.travel_limit < 0.0:
		return false
	# This first enemy is a hovering patrol fixture, not a ground/gravity policy.
	var distance := minf(patrol_speed * delta, intent.travel_limit)
	velocity.x = float(intent.move_axis) * distance / delta
	var attraction := _attraction if _attraction_tick==Engine.get_physics_frames() else Vector2.ZERO
	var motion := Vector2(float(intent.move_axis)*distance,0)+attraction.limit_length(_attraction_limit/delta)*delta
	if _knockback_seconds>0:
		var hit_motion := _knockback*minf(delta,_knockback_seconds)
		# The existing ground motor has no gravity recovery. Do not push a
		# ground actor into permanent air; aerial definitions retain full force.
		if _knockback_requires_floor and not hit_motion.is_zero_approx() and not _hit_landing_supported(motion+hit_motion):
			_knockback=Vector2.ZERO
			hit_motion=Vector2.ZERO
		motion+=hit_motion
		_knockback_seconds=maxf(0,_knockback_seconds-delta)
	_attraction=Vector2.ZERO
	velocity = motion / delta
	var collision := move_and_collide(motion) if not motion.is_zero_approx() else null
	if collision != null and _knockback.dot(collision.get_normal()) < 0:
		_knockback = _knockback.slide(collision.get_normal())
	return collision != null

func stop() -> void:
	_knockback_requires_floor = false
	_knockback=Vector2.ZERO;_knockback_seconds=0;_attraction=Vector2.ZERO;_attraction_tick=-1
	velocity = Vector2.ZERO

func reset_at(location: Vector2) -> void:
	stop()
	global_position = location

func move_attack(motion: Vector2, require_floor: bool, delta: float) -> bool:
	if not motion.is_finite() or not is_finite(delta) or delta <= 0: return false
	if require_floor:
		var feet := global_position + Vector2(signf(motion.x) * 15, 18)
		var ray := PhysicsRayQueryParameters2D.create(feet + motion + Vector2(0, -2), feet + motion + Vector2(0, 8), 1, [get_rid()])
		if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			velocity = Vector2.ZERO
			return false
	velocity = motion / delta
	return move_and_collide(motion) == null

func request_attraction(center: Vector2, speed: float, stop_ring: float) -> void:
	var offset := center-global_position
	_attraction_tick=Engine.get_physics_frames()
	_attraction_limit=maxf(0,offset.length()-stop_ring)
	_attraction=offset.normalized()*speed

func request_knockback(velocity_value: Vector2, seconds: float, require_floor: bool = false) -> void:
	_knockback=velocity_value;_knockback_seconds=seconds
	_knockback_requires_floor = require_floor and _ground_actor

# Local accepted-hit path only. Ordinary patrol/attack/attraction stay unchanged.
# Like move_attack(require_floor), probe the next leading foot, but use the
# actual configured collision volume and a standable normal, not artwork size.
func _hit_landing_supported(motion: Vector2) -> bool:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or not collision.shape is RectangleShape2D: return false
	var half := (collision.shape as RectangleShape2D).size*.5
	var feet := collision.global_position+motion+Vector2(signf(motion.x)*maxf(0,half.x-1),half.y)
	var ray := PhysicsRayQueryParameters2D.create(feet+Vector2(0,-2),feet+Vector2(0,8),collision_mask,[get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and (hit.normal as Vector2).dot(Vector2.UP)>.7
