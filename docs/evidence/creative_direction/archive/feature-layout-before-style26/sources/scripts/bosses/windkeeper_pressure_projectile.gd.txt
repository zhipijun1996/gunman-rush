class_name WindkeeperPressureProjectile
extends BossProjectile
## Real finite seed or supported ground wave; cancel ownership precedes contact.
var wave := false
var _attack_owner: WeakRef
var _owner_epoch := -1

func bind_attack(owner: Node, epoch: int) -> void:
	_attack_owner = weakref(owner)
	_owner_epoch = epoch

func _owned() -> bool:
	if _attack_owner == null: return false
	var owner := _attack_owner.get_ref() as WindkeeperEncounter
	return is_instance_valid(owner) and owner.active and not owner.health.terminal and owner.attack_epoch == _owner_epoch

func advance(delta: float) -> void:
	if spent or not is_inside_tree() or delta <= 0 or not is_finite(delta): return
	if not _owned():
		dispose()
		return
	if wave:
		var next := global_position + direction * speed * delta
		var exclude: Array[RID] = []
		if is_instance_valid(_owner_body): exclude.append(_owner_body.get_rid())
		if _target is CollisionObject2D: exclude.append((_target as CollisionObject2D).get_rid())
		var support := PhysicsRayQueryParameters2D.create(next, next + Vector2(0, radius + 12), 1, exclude)
		if get_world_2d().direct_space_state.intersect_ray(support).is_empty():
			dispose()
			return
	super.advance(delta)

func advance_frozen_contact() -> void:
	if not _owned():
		dispose()
		return
	super.advance_frozen_contact()

func _draw() -> void:
	if wave:
		var color := Color("d2c386")
		# Paint the full real circle: no invisible upper half above a low arc.
		draw_circle(Vector2.ZERO, radius, Color(color, .12))
		draw_arc(Vector2.ZERO, radius, PI, TAU, 12, color, 1.5, false)
		draw_arc(Vector2.ZERO, radius, 0, PI, 12, Color("8d9979"), 1.5, false)
	else:
		var angle := direction.angle()
		draw_set_transform(Vector2.ZERO, angle, Vector2.ONE * maxf(1, radius) / 9.0)
		draw_colored_polygon(PackedVector2Array([Vector2(9,0),Vector2(-3,-5),Vector2(-8,0),Vector2(-3,5)]), Color("b0b585"))
		draw_line(Vector2(-5,0),Vector2(6,0),Color("e0c789"),2)
		draw_set_transform(Vector2.ZERO)
