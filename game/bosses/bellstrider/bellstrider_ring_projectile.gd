class_name BellstriderRingProjectile
extends BossProjectile
## Horizontal wave or one local surface shock. Terrain remains authoritative.
var local_surface := false
var surface_normal := Vector2.UP
var _attack_owner: WeakRef
var _epoch := -1
var _local_shape: RectangleShape2D


func bind_attack(owner: Node, epoch: int) -> void:
	_attack_owner = weakref(owner)
	_epoch = epoch


func configure_local(width: float, normal: Vector2) -> void:
	local_surface = true
	surface_normal = normal.normalized() if normal.length_squared() > .001 else Vector2.UP
	# Long tangent, shallow normal. The visible ground ring has this same extent.
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(width * 2.0, 14.0)
	_local_shape = rectangle
	radius = width


func advance(delta: float) -> void:
	if spent or not is_inside_tree() or delta <= 0.0 or not is_finite(delta):
		return
	if not accepts_optional_encounter_epoch(_attack_owner, _epoch):
		dispose()
		return
	if not local_surface:
		if not _supported_ahead(delta):
			dispose()
			return
		super.advance(delta)
		return
	if spent or not is_inside_tree() or delta <= 0.0 or not is_finite(delta):
		return
	lifetime -= delta
	_visual_age += delta
	if lifetime <= 0.0:
		dispose()
		return
	_test_local_contact()
	queue_redraw()


func _supported_ahead(delta: float) -> bool:
	if not is_inside_tree():
		return false
	var next := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(next, next + Vector2(0, radius + 8.0), 1)
	var excluded: Array[RID] = []
	if is_instance_valid(_owner_body):
		excluded.append(_owner_body.get_rid())
	if _target is CollisionObject2D:
		excluded.append((_target as CollisionObject2D).get_rid())
	query.exclude = excluded
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _test_local_contact() -> void:
	if spent or not is_instance_valid(_target):
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _local_shape
	query.transform = Transform2D(surface_normal.angle() + PI * .5, global_position)
	query.collision_mask = 1
	if is_instance_valid(_owner_body):
		query.exclude = [_owner_body.get_rid()]
	var contacts := get_world_2d().direct_space_state.intersect_shape(query, 8)
	# Cast to the target centre prevents a surface shock reaching through walls.
	var ray := PhysicsRayQueryParameters2D.create(global_position, _target.global_position, 1)
	if is_instance_valid(_owner_body):
		ray.exclude = [_owner_body.get_rid()]
	var blocker := get_world_2d().direct_space_state.intersect_ray(ray)
	if not blocker.is_empty() and blocker.get("collider") != _target:
		return
	for contact: Dictionary in contacts:
		if contact.get("collider") == _target:
			spent = true
			hit.emit(_target, event_id, amount)
			queue_free()
			return


func advance_frozen_contact() -> void:
	if not accepts_optional_encounter_epoch(_attack_owner, _epoch):
		dispose()
		return
	if local_surface:
		_test_local_contact()
	else:
		super.advance_frozen_contact()


func _draw() -> void:
	if not local_surface:
		super._draw()
		return
	var progress := clampf(_visual_age / .2, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, surface_normal.angle() + PI * .5)
	var color := Color("d8bd76")
	color.a = 1.0 - progress
	# The local damage slab is 2*radius wide and14 high. Show its complete
	# boundary immediately; an expanding40-high semicircle overstated its reach.
	var outline := PackedVector2Array()
	for index: int in 9:
		var x := lerpf(-radius, radius, float(index) / 8.0)
		outline.append(Vector2(x, -6.0 * sin(float(index) / 8.0 * PI)).round())
	draw_rect(Rect2(-radius, -7, radius * 2.0, 14), Color(color, .08 * color.a))
	draw_polyline(outline, color, 2.0, false)
	draw_line(Vector2(-radius, 0), Vector2(radius, 0), Color(color, .4 * color.a), 2.0)
	draw_set_transform(Vector2.ZERO)
