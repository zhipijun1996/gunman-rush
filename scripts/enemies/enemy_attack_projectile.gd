class_name EnemyAttackProjectile
extends Node2D
## A single slow, locked-aim seed. Owner/actor/stage cancellation is immediate.
var behavior: EnemyAttackBehavior
var event_id: StringName
var token: DemoToken
var direction := Vector2.RIGHT
var speed := 240.0
var radius := 4.0
var remaining := 0.9
var spent := false
var _shape := CircleShape2D.new()
var _visual_age := 0.0
var _visual_launched := false
var _visual_trail: Array[Vector2] = []

func _ready() -> void:
	if UnderworldProjectileVisual.enabled(self): z_index = 8

func configure(owner_behavior: EnemyAttackBehavior, id: StringName, aim: Vector2) -> void:
	behavior = owner_behavior
	event_id = id
	token = behavior.lifetime.token()
	direction = aim.normalized()
	speed = behavior.actor.definition.projectile_speed
	remaining = behavior.actor.definition.projectile_lifetime
	_shape.radius = radius
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _physics_process(delta: float) -> void:
	if spent: return
	if not is_instance_valid(behavior) or not behavior._active() or not behavior.lifetime.accepts(token):
		dispose()
		return
	remaining -= delta
	if remaining <= 0:
		dispose()
		return
	for point: Vector2 in behavior.protected_points:
		if DemoContactEmitter.segment_intersects_bounds(global_position, global_position + direction * speed * delta, Rect2(point - Vector2.ONE * behavior.actor.definition.protected_radius, Vector2.ONE * behavior.actor.definition.protected_radius * 2.0)):
			dispose()
			return
	_visual_age += delta
	_visual_trail.append(global_position)
	if _visual_trail.size() > 7: _visual_trail.pop_front()
	if not _visual_launched:
		_visual_launched = true
		UnderworldProjectileVisual.emit(self,global_position,direction,false,false)
	queue_redraw()
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0, global_position)
	query.motion = direction * speed * delta
	query.collision_mask = 1
	query.exclude = [behavior.actor.motor.get_rid()]
	var space := get_world_2d().direct_space_state
	var overlaps := space.intersect_shape(query, 8)
	var fraction := 0.0 if not overlaps.is_empty() else 1.0
	if overlaps.is_empty():
		var cast := space.cast_motion(query)
		fraction = cast[1] if cast.size() == 2 else 1.0
	if fraction < 1.0 or not overlaps.is_empty():
		query.transform.origin += query.motion * minf(1, fraction + 0.001)
		query.motion = Vector2.ZERO
		var hits := overlaps if not overlaps.is_empty() else space.intersect_shape(query, 8)
		UnderworldProjectileVisual.emit(self,query.transform.origin,direction,false,true)
		# Simultaneous wall/target contact is occluded by the wall, independent
		# of physics query result ordering.
		if hits.any(func(hit: Dictionary): return hit.get("collider") != behavior.controller.motor):
			dispose()
			return
		for hit: Dictionary in hits:
			if hit.get("collider") == behavior.controller.motor:
				var request := DamageRequest.new()
				request.token = token
				request.event_id = event_id
				request.source_id = behavior.source_id
				request.target_id = &"player"
				request.amount = 1
				request.hit_direction = direction
				request.actor_epoch = token.actor_epoch
				request.health_epoch = behavior.controller.actor_resources.health.epoch
				behavior.policy.submit(request)
				break
		dispose()
		return
	global_position += query.motion

func dispose() -> void:
	if spent: return
	spent = true
	queue_free()

func _draw() -> void:
	if UnderworldProjectileVisual.enabled(self):
		UnderworldProjectileVisual.paint(self,direction,radius,_visual_age,_visual_trail,&"seed",false)
		return
	if PixelFormalActors.pixel_context(self):
		PixelFormalActors.projectile(self,radius,direction)
		return
	ProjectileArt.paint(self, 0, direction, radius)
