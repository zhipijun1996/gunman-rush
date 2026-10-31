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
var _visual_age := 0.0
var _visual_launched := false
var _visual_trail: Array[Vector2] = []

# Bell attacks permit an unbound encounter; bound attacks require a live
# owner in the same epoch. Callers retain their weak reference and epoch.
static func accepts_optional_encounter_epoch(owner_ref: WeakRef, epoch: int) -> bool:
	if owner_ref == null:
		return true
	var owner := owner_ref.get_ref() as Node
	return (
		is_instance_valid(owner)
		and owner.active
		and not owner.health.terminal
		and owner.attack_epoch == epoch
	)


func _ready() -> void:
	if UnderworldProjectileVisual.enabled(self): z_index = 8

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
	_visual_age += delta
	_visual_trail.append(global_position)
	if _visual_trail.size() > 7: _visual_trail.pop_front()
	if not _visual_launched:
		_visual_launched = true
		if _visible_attack(): UnderworldProjectileVisual.emit(self,global_position,direction,false,false)
	queue_redraw()
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
		if _visible_attack(): UnderworldProjectileVisual.emit(self,contact_point,direction,false,true)
		spent = true
		# Terrain occludes simultaneous wall/actor contacts, independent of query order.
		for contact: Dictionary in collisions:
			if contact.get("collider") != _target:
				queue_free()
				return
		for collision: Dictionary in collisions:
			if is_instance_valid(_target) and collision.get("collider") == _target:
				hit.emit(_target, event_id, amount)
				break
		queue_free()

# WorldFreezeScope calls only this entry while ordinary processing is disabled.
# Keep the same current-shape/terrain ordering as advance(), without changing
# lifetime, trail, position, speed or visual age. The original coordinator's
# signal still enforces its run/arena/attack ownership admission.
func advance_frozen_contact() -> void:
	if spent or not is_inside_tree() or not is_instance_valid(_target) or not is_instance_valid(_owner_body): return
	var encounter := _owner_body.get_node_or_null("Encounter") as BossEncounter
	if encounter != null and (not encounter.active or encounter.health.terminal or (encounter.has_method("combat_target_active") and not bool(encounter.call("combat_target_active")))): return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0.0,global_position)
	query.collision_mask = 1
	query.exclude = [_owner_body.get_rid()]
	var contacts := get_world_2d().direct_space_state.intersect_shape(query,8)
	if contacts.is_empty(): return
	# An overlapping wall wins even if the player is also in the shape.
	if contacts.any(func(contact: Dictionary) -> bool: return contact.get("collider") != _target):
		dispose()
		return
	spent = true
	if _visible_attack(): UnderworldProjectileVisual.emit(self,global_position,direction,false,true)
	hit.emit(_target,event_id,amount)
	queue_free()

func dispose() -> void:
	if spent:
		return
	spent = true
	queue_free()

func _visible_attack() -> bool:
	return not (str(event_id).begins_with("windblade") or str(event_id).begins_with("pier-"))

func _draw() -> void:
	if not _visible_attack(): return
	if UnderworldProjectileVisual.enabled(self):
		UnderworldProjectileVisual.paint(self,direction,radius,_visual_age,_visual_trail,&"ring",false)
		return
	if PixelFormalActors.pixel_context(self):
		PixelFormalActors.projectile(self,radius,direction)
		return
	ProjectileArt.paint(self, 3 if (str(event_id).begins_with("windkeeper") or str(event_id).begins_with("bellstrider_ring")) else 2, direction, radius)
