class_name BossProjectile
extends Node2D

signal hit(target_body: Node2D, event_id: StringName, amount: float)
var event_id: StringName
var amount := 0.0
var direction := Vector2.LEFT
var speed := 0.0
var radius := 0.0
var lifetime := 0.0
var spent := false
var _target: Node2D
var _owner_body: PhysicsBody2D
var _shape := CircleShape2D.new()

func configure(definition: BossDefinition, attack_id: StringName, aim: Vector2, target: Node2D, owner_body: PhysicsBody2D) -> void:
	event_id = attack_id
	amount = definition.projectile_damage
	direction = aim.normalized() if aim.length_squared() > 0.001 else Vector2.LEFT
	speed = definition.projectile_speed
	radius = definition.projectile_radius
	lifetime = definition.projectile_lifetime
	_target = target
	_owner_body = owner_body
	_shape.radius = radius

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if spent or not is_inside_tree() or not is_finite(delta) or delta <= 0.0:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		dispose()
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0.0, global_position)
	var motion := direction * speed * delta
	query.collision_mask = 1
	if is_instance_valid(_owner_body):
		query.exclude = [_owner_body.get_rid()]
	var space := get_world_2d().direct_space_state
	var initial := space.intersect_shape(query, 8)
	var fraction := 0.0 if not initial.is_empty() else 1.0
	var contact_fraction := fraction
	if initial.is_empty():
		query.motion = motion
		var cast := space.cast_motion(query)
		fraction = cast[0] if cast.size() == 2 else 1.0
		contact_fraction = cast[1] if cast.size() == 2 else fraction
	var contact_point := global_position + motion * contact_fraction
	global_position += motion * fraction
	if not initial.is_empty() or fraction < 1.0:
		query.motion = Vector2.ZERO
		query.transform.origin = contact_point + direction * 0.1
		var collisions := initial if not initial.is_empty() else space.intersect_shape(query, 8)
		spent = true
		for collision: Dictionary in collisions:
			if is_instance_valid(_target) and collision.get("collider") == _target:
				hit.emit(_target, event_id, amount)
				break
		queue_free()

func dispose() -> void:
	if spent:
		return
	spent = true
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 3.0, Color(0.95, 0.24, 0.13, 0.3))
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.64, 0.25))
