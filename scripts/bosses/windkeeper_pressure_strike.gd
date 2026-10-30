class_name WindkeeperPressureStrike
extends BossProjectile
## The rendered blade/foot supplies both endpoints, never the target location.
## Collision is shape-vs-shape against the actual Player collider, then the
## original App hit signal/policy. No target-teleported projectile is fabricated.
var _attack_owner: WeakRef
var _owner_epoch := -1
var start_world := Vector2.ZERO
var end_world := Vector2.ZERO
var previous_start := Vector2.ZERO
var previous_end := Vector2.ZERO
var thickness := 12.0
var _has_previous := false
var _capsule := CapsuleShape2D.new()

func bind_attack(owner: Node, epoch: int) -> void:
	_attack_owner = weakref(owner)
	_owner_epoch = epoch

func _owned() -> bool:
	if _attack_owner == null: return false
	var owner := _attack_owner.get_ref() as WindkeeperEncounter
	return is_instance_valid(owner) and owner.active and not owner.health.terminal and owner.attack_epoch == _owner_epoch

func set_segment(a: Vector2, b: Vector2, width: float) -> void:
	previous_start = start_world if _has_previous else a
	previous_end = end_world if _has_previous else b
	start_world = a
	end_world = b
	thickness = maxf(2, width)
	_has_previous = true
	global_position = (a + b) * .5
	direction = (b - a).normalized() if a.distance_squared_to(b) > .01 else Vector2.DOWN

func _physics_process(_delta: float) -> void:
	# Encounter owns the same fixed-tick pose and samples after updating it.
	pass

func advance(delta: float) -> void:
	if spent or not is_inside_tree() or delta <= 0 or not is_finite(delta): return
	if not _owned():
		dispose()
		return
	lifetime -= delta
	if lifetime <= 0:
		dispose()
		return
	_test_segment()

func _test_segment(current_only: bool = false) -> void:
	if spent or not _has_previous or not is_instance_valid(_target): return
	var target_shape := _target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if target_shape == null or target_shape.disabled or target_shape.shape == null: return
	# Endpoint motion is bounded to <=4wu per sample, including zero-motion
	# overlap. This follows the actual rig's sweep rather than its broad AABB.
	# Freeze entry observes only the current held blade. Replaying its last
	# live sweep would turn already vacated space into an invisible hazard.
	var from_start := start_world if current_only else previous_start
	var from_end := end_world if current_only else previous_end
	var travel := maxf(from_start.distance_to(start_world), from_end.distance_to(end_world))
	var samples := maxi(1, ceili(travel / 4.0))
	for index: int in samples + 1:
		var fraction := float(index) / float(samples)
		var a := from_start.lerp(start_world, fraction)
		var b := from_end.lerp(end_world, fraction)
		var axis := b - a
		_capsule.radius = thickness * .5
		_capsule.height = maxf(thickness, axis.length() + thickness)
		var transform := Transform2D(axis.angle() - PI * .5, (a + b) * .5)
		if _capsule.collide(transform, target_shape.shape, target_shape.global_transform):
			spent = true
			hit.emit(_target, event_id, amount)
			queue_free()
			return

func advance_frozen_contact() -> void:
	if not _owned():
		dispose()
		return
	_test_segment(true)

func _draw() -> void:
	# The body renderer paints the exact authored limb/blade. No helper stripe.
	pass
