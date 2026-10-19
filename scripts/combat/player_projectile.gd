class_name PlayerProjectile
extends Node2D

signal impacted(point: Vector2, direction: Vector2)

var weapon_epoch := -1
var energy_receipt_id := 0
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
var art_kind: StringName = &"bullet"
var skill_attack := false
var spent := false
var fired_airborne := false
var _age := 0.0
var _visual_launched := false
var launch_motion := Vector2.ZERO
var trail: Array[Vector2] = []
## Optional sample skin; movement, swept contacts and damage remain here.
var presentation: CanvasItem
const ART := preload("res://assets/plains_v4/spatial/actors.png")
var _shape := CircleShape2D.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 8
	_shape.radius = radius
	queue_redraw()

func _draw() -> void:
	if is_instance_valid(presentation): return
	if UnderworldProjectileVisual.enabled(self):
		UnderworldProjectileVisual.paint(self,direction,radius,_age,trail,art_kind,true,skill_attack,weapon_blade_texture())
		return
	for i: int in range(1, trail.size()):
		draw_line(to_local(trail[i-1]), to_local(trail[i]), Color(1,.83,.38,float(i)/trail.size()*.7), 2.5)
	draw_set_transform(Vector2.ZERO, direction.angle())
	if art_kind == &"blade":
		var art: Dictionary = owner_controller.shoot_ability.behavior().art_catalog()
		if not art.is_empty():
			draw_set_transform(Vector2.ZERO,_age*20)
			draw_texture_rect(PlainsActorAssets.region_texture(art.texture,art.regions[1]),Rect2(-11,-11,22,22),false)
			draw_set_transform(Vector2.ZERO)
		return
	# AI painted head/trail; 3px gameplay radius remains unchanged.
	draw_texture_rect_region(ART, Rect2(-38,-8,46,16), Rect2(80,690,650,240))
	draw_set_transform(Vector2.ZERO)

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	trail.append(global_position)
	if trail.size() > 7: trail.pop_front()
	queue_redraw()
	if delta > 0 and not launch_motion.is_zero_approx():
		advance(0.0) # Same swept collision contract through the short barrel path.
	if spent:
		return
	if not is_instance_valid(owner_controller) or not owner_controller.active or session_id != owner_controller.session_id or (weapon_epoch>=0 and weapon_epoch!=owner_controller.shoot_ability.weapon_epoch):
		dispose()
		return
	_age += delta
	if _age >= lifetime:
		dispose()
		return
	if not _visual_launched:
		_visual_launched = true
		UnderworldProjectileVisual.emit(self,global_position+launch_motion,direction,true,false)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0.0, global_position)
	query.motion = launch_motion if not launch_motion.is_zero_approx() else direction * speed * delta
	launch_motion = Vector2.ZERO
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
		# Godot intersects the whole supplied motion. Initial overlaps must be
		# stationary; cast_motion then selects the first swept contact.
		var travel:Vector2=query.motion
		query.motion=Vector2.ZERO
		var overlaps := space.intersect_shape(query, 128)
		query.motion=travel
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
			query.motion=Vector2.ZERO
			var contacts := space.intersect_shape(query, 128)
			query.motion=travel
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
			receiver.receive_damage({"session_id": session_id, "event_id": "%d:%d:%d" % [owner_id, session_id, shot_id], "source_actor_id": owner_id, "target_actor_id": receiver.actor_id, "target_epoch": receiver.damage_epoch, "attack_id": shot_id, "shot_id": shot_id, "amount": damage, "damage_type": &"projectile", "hit_direction": direction, "fired_airborne": fired_airborne, "source_faction": faction, "hit_point": query.transform.origin, "on_committed": owner_controller.on_weapon_damage.bind(session_id,energy_receipt_id if energy_receipt_id > 0 else shot_id,shot_id,fired_airborne,(receiver.actor_id if receiver.actor_id!=0 else receiver.get_instance_id()) if receiver.faction==&"enemy" else 0,skill_attack,receiver,weapon_epoch)})
		# Boss armour/core presentation subscribes to armour contact / committed HP.
		if receiver == null or receiver.impact_style() != &"boss":
			UnderworldProjectileVisual.emit(self,query.transform.origin,direction,true,true)
			impacted.emit(query.transform.origin, direction)
		dispose()
		return
	# Pathological overlapping geometry fails closed rather than tunnelling.
	dispose()

func dispose() -> void:
	spent = true
	set_physics_process(false)
	queue_free()

func weapon_blade_texture() -> Texture2D:
	if art_kind != &"blade" or not is_instance_valid(owner_controller): return null
	var catalog: Dictionary = owner_controller.shoot_ability.behavior().art_catalog()
	if catalog.is_empty(): return null
	return PlainsActorAssets.region_texture(catalog.texture,catalog.regions[1])
