class_name BellstriderBellProjectile
extends BossProjectile
## Physical copper bell. Curved motion is split into swept geometry segments.
## Exactly one real surface impact may create one local shock through its owner.
signal impacted(point: Vector2, normal: Vector2)
var flight_velocity := Vector2.ZERO
var gravity := 860.0
var landing_point := Vector2.ZERO
var _attack_owner: WeakRef
var _epoch := -1
var _impact_emitted := false
var _shadow_point := Vector2.ZERO
var _shadow_visible := false


func bind_attack(owner: Node, epoch: int) -> void:
	_attack_owner = weakref(owner)
	_epoch = epoch


func _owned() -> bool:
	if _attack_owner == null:
		return true
	var owner := _attack_owner.get_ref() as Node
	return (
		is_instance_valid(owner)
		and owner.active
		and not owner.health.terminal
		and owner.attack_epoch == _epoch
	)


func aim_landing(point: Vector2, duration: float = 1.05) -> void:
	landing_point = point
	duration = maxf(.1, duration)
	# Shell centre reaches the supported surface; collision naturally occurs
	# slightly earlier at the shell edge, at the actual wall/platform/ground.
	flight_velocity = (point - global_position) / duration - Vector2(0, gravity * duration * .5)


func advance(delta: float) -> void:
	if spent or not is_inside_tree() or delta <= 0.0 or not is_finite(delta):
		return
	if not _owned():
		dispose()
		return
	lifetime -= delta
	if lifetime <= 0.0:
		dispose()
		return
	_visual_age += delta
	_visual_trail.append(global_position)
	if _visual_trail.size() > 7:
		_visual_trail.pop_front()
	_visual_launched = true
	# At 120Hz segment size, curvature error stays below .01 world units.
	var slices := maxi(1, ceili(delta * 120.0))
	var step := delta / float(slices)
	for index: int in slices:
		var motion := flight_velocity * step + Vector2(0, gravity * step * step * .5)
		flight_velocity.y += gravity * step
		direction = motion.normalized()
		speed = flight_velocity.length()
		if _sweep(motion):
			return
	_update_shadow()
	queue_redraw()


func _update_shadow() -> void:
	var query := PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2(0, 900), 1
	)
	var excluded: Array[RID] = []
	if is_instance_valid(_owner_body):
		excluded.append(_owner_body.get_rid())
	if _target is CollisionObject2D:
		excluded.append((_target as CollisionObject2D).get_rid())
	query.exclude = excluded
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	_shadow_visible = not result.is_empty()
	if _shadow_visible:
		_shadow_point = result.position


func _sweep(motion: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 1
	if is_instance_valid(_owner_body):
		query.exclude = [_owner_body.get_rid()]
	var space := get_world_2d().direct_space_state
	var initial := space.intersect_shape(query, 16)
	query.motion = motion
	var cast := space.cast_motion(query)
	var fraction := 0.0 if not initial.is_empty() else float(cast[0]) if cast.size() == 2 else 1.0
	if initial.is_empty() and fraction >= 1.0:
		global_position += motion
		return false
	var unsafe_fraction := float(cast[1]) if cast.size() == 2 and initial.is_empty() else fraction
	var centre := global_position + motion * unsafe_fraction
	query.motion = Vector2.ZERO
	query.transform.origin = centre + direction * .1
	var contacts := initial if not initial.is_empty() else space.intersect_shape(query, 16)
	var terrain := false
	for contact: Dictionary in contacts:
		if contact.get("collider") != _target:
			terrain = true
	global_position += motion * fraction
	spent = true
	if terrain or contacts.is_empty():
		# Rest info reports actual geometry contact and surface normal, including
		# high platforms, wall corners, and platform edges; never a fake floor.
		var rest := space.get_rest_info(query)
		var normal: Vector2 = rest.get("normal", -direction)
		var point: Vector2 = rest.get("point", centre - normal * radius)
		if not _impact_emitted and _owned():
			_impact_emitted = true
			impacted.emit(point, normal)
	elif is_instance_valid(_target):
		hit.emit(_target, event_id, amount)
	queue_free()
	return true


func advance_frozen_contact() -> void:
	if spent or not is_inside_tree():
		return
	if not _owned():
		dispose()
		return
	# Zero-motion sweep observes entry without advancing flight, gravity or age.
	_sweep(Vector2.ZERO)


func _draw() -> void:
	if _shadow_visible:
		draw_set_transform(to_local(_shadow_point) + Vector2(0, -2), 0, Vector2(1, .22))
		draw_circle(Vector2.ZERO, 12, Color(.12, .11, .08, .4))
		draw_set_transform(Vector2.ZERO)
	# Readable independent copper projectile; the main weak bell stays on boss.
	var angle := _visual_age * 7.0
	draw_set_transform(Vector2.ZERO, angle)
	draw_polygon(
		PackedVector2Array([Vector2(-7, -8), Vector2(7, -8), Vector2(10, 7), Vector2(-10, 7)]),
		PackedColorArray([Color("a67b43")])
	)
	draw_rect(Rect2(-10, 5, 20, 4), Color("e2ba72"))
	draw_line(Vector2(-5, -6), Vector2(5, -6), Color("dbb06a"), 2)
	draw_circle(Vector2(0, 10), 2.5, Color("483d2d"))
	draw_set_transform(Vector2.ZERO)
