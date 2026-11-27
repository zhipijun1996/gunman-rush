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
var flight := ProjectileFlight.new()
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
	var step := minf(delta,remaining)
	remaining -= delta
	if step <= 0:
		dispose()
		return
	_visual_age += delta
	_visual_trail.append(global_position)
	if _visual_trail.size() > 7: _visual_trail.pop_front()
	if not _visual_launched:
		_visual_launched = true
		UnderworldProjectileVisual.emit(self,global_position,direction,false,false)
	queue_redraw()
	flight.advance(self,behavior.controller,"enemy",direction*speed,step,_move_swept)
	if not spent and remaining <= 0: dispose()

## Placement clearance only: no flight/lifetime/visual clock advances. Reuses
## the ordinary real-volume sweep and original damage Policy/contact handling.
func launch_to_muzzle(destination: Vector2) -> bool:
	if spent: return false
	if not destination.is_finite() or not is_inside_tree() or not is_instance_valid(behavior) or not behavior._active() or not behavior.lifetime.accepts(token):
		dispose()
		return false
	var motion := destination-global_position
	if motion.is_zero_approx(): return true
	flight.advance(self,behavior.controller,"enemy",motion,1.0,_move_swept,{},INF,true)
	return not spent

func _crosses_protected_point(motion: Vector2) -> bool:
	for point: Vector2 in behavior.protected_points:
		if DemoContactEmitter.segment_intersects_bounds(global_position,global_position+motion,Rect2(point-Vector2.ONE*behavior.actor.definition.protected_radius,Vector2.ONE*behavior.actor.definition.protected_radius*2.0)):
			return true
	return false

func _move_swept(motion: Vector2) -> void:
	if _crosses_protected_point(motion):
		dispose()
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0, global_position)
	query.motion = motion
	query.collision_mask = 1
	var exclusions: Array[RID] = flight.grate_excludes.duplicate()
	exclusions.append(behavior.actor.motor.get_rid())
	query.exclude = exclusions
	var space := get_world_2d().direct_space_state
	query.motion = Vector2.ZERO
	var overlaps := space.intersect_shape(query, 8)
	query.motion = motion
	var fraction := 0.0 if not overlaps.is_empty() else 1.0
	if overlaps.is_empty():
		var cast := space.cast_motion(query)
		fraction = cast[1] if cast.size() == 2 else 1.0
	if behavior.controller.item_runtime != null and behavior.controller.item_runtime.scene.intercept(self,motion,fraction): return
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

# Stationary contact observation only. Owner, stage and actor-token guards are
# identical to ordinary simulation; no motion/lifetime/visual clock advances.
func advance_frozen_contact() -> void:
	if spent or not is_inside_tree(): return
	if not is_instance_valid(behavior) or not behavior._active() or not behavior.lifetime.accepts(token):
		dispose()
		return
	for point: Vector2 in behavior.protected_points:
		if DemoContactEmitter.segment_intersects_bounds(global_position,global_position,Rect2(point-Vector2.ONE*behavior.actor.definition.protected_radius,Vector2.ONE*behavior.actor.definition.protected_radius*2.0)):
			dispose()
			return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0.0,global_position)
	query.collision_mask = 1
	var exclusions: Array[RID] = flight.grate_excludes.duplicate()
	exclusions.append(behavior.actor.motor.get_rid())
	query.exclude = exclusions
	var hits := get_world_2d().direct_space_state.intersect_shape(query,8)
	if hits.is_empty(): return
	if hits.any(func(contact: Dictionary) -> bool: return contact.get("collider") != behavior.controller.motor):
		dispose()
		return
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
	UnderworldProjectileVisual.emit(self,global_position,direction,false,true)
	dispose()

func dispose() -> void:
	if spent: return
	spent = true
	queue_free()

func _draw() -> void:
	if is_instance_valid(behavior) and behavior.actor.definition.behavior_id in [&"forest_antler",&"forest_mentor"]:
		paint_forest_attack()
		return
	if UnderworldProjectileVisual.enabled(self):
		UnderworldProjectileVisual.paint(self,direction,radius,_visual_age,_visual_trail,&"seed",false)
		return
	if PixelFormalActors.pixel_context(self):
		PixelFormalActors.projectile(self,radius,direction)
		return
	ProjectileArt.paint(self, 0, direction, radius)


func paint_forest_attack() -> void:
	if behavior.actor.definition.behavior_id == &"forest_mentor":
		draw_set_transform(Vector2.ZERO,_visual_age*12.0)
		for i: int in 4:
			var vane := PackedVector2Array([Vector2(0,0),Vector2(4,-2),Vector2(6,-7),Vector2(1,-4)])
			for j: int in vane.size(): vane[j] = vane[j].rotated(i*PI/2.0)
			draw_colored_polygon(vane,Color("dce3c8") if i%2 else Color("798a85"))
		draw_circle(Vector2.ZERO,1.5,Color("474f49"))
	else:
		draw_set_transform(Vector2.ZERO,0,Vector2(signf(direction.x),1))
		draw_colored_polygon(PackedVector2Array([Vector2(-11,4),Vector2(-7,0),Vector2(-8,-8),Vector2(-3,-4),Vector2(1,0),Vector2(3,-10),Vector2(6,-3),Vector2(9,-5),Vector2(6,4)]),Color("795236"))
		draw_polyline(PackedVector2Array([Vector2(-9,3),Vector2(-3,-1),Vector2(2,1),Vector2(5,-6)]),Color("ced99c"),1)
