class_name PlayerProjectile
extends Node2D

var shot_id: int
var owner_id: int
var session_id: int
var faction: StringName = &"player"
var direction := Vector2.RIGHT
var speed := 1200.0
var radius := 3.0
var damage := 1.0
var lifetime := 2.0
var owner_controller: PlayerController
var owner_body: CollisionObject2D
var spent := false
var _age := 0.0
var _shape := CircleShape2D.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_shape.radius = radius
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.78, 0.25))

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if spent:
		return
	if not is_instance_valid(owner_controller) or not owner_controller.active or session_id != owner_controller.session_id:
		dispose()
		return
	_age += delta
	if _age >= lifetime:
		dispose()
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0.0, global_position)
	query.motion = direction * speed * delta
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var excluded: Array[RID] = []
	if is_instance_valid(owner_body):
		excluded.append(owner_body.get_rid())
	var space := get_world_2d().direct_space_state
	# Ignore friendly hurtboxes while retaining geometry as blockers. Re-query
	# after each excluded RID so a friendly body cannot hide a wall behind it.
	for _attempt: int in 128:
		query.exclude = excluded
		var overlaps := space.intersect_shape(query, 128)
		var hit: Dictionary = {}
		if not overlaps.is_empty():
			hit = overlaps[0]
		else:
			var fractions := space.cast_motion(query)
			if fractions.size() != 2 or fractions[0] >= 1.0:
				global_position += query.motion
				return
			# get_rest_info ignores query.motion; query at unsafe contact point.
			query.transform.origin = global_position + query.motion * minf(1.0, fractions[1] + 0.0001)
			var contacts := space.intersect_shape(query, 128)
			if contacts.is_empty():
				dispose()
				return
			hit = contacts[0]
		var collider: Object = hit.get("collider")
		var receiver: Damageable = null
		if collider is Node:
			receiver = (collider as Node).get_node_or_null("Damageable") as Damageable
		if collider is Area2D and receiver == null:
			excluded.append(hit.rid)
			query.transform.origin = global_position
			continue
		if receiver != null and (receiver.faction == faction or receiver.actor_id == owner_id or not receiver.active):
			excluded.append(hit.rid)
			query.transform.origin = global_position
			continue
		if receiver != null:
			receiver.receive_damage({"session_id": session_id, "event_id": "%d:%d:%d" % [owner_id, session_id, shot_id], "source_actor_id": owner_id, "target_actor_id": receiver.actor_id, "target_epoch": receiver.damage_epoch, "attack_id": shot_id, "shot_id": shot_id, "amount": damage, "damage_type": &"projectile", "hit_direction": direction, "source_faction": faction})
		dispose()
		return
	# Pathological overlapping geometry fails closed rather than tunnelling.
	dispose()

func dispose() -> void:
	spent = true
	set_physics_process(false)
	queue_free()
