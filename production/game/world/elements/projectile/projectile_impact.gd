class_name ProjectileImpact
extends RefCounted
const PROFILE_PATH := "res://config/mechanism_projectiles.json"
static var profiles: Dictionary = {}

static func profile(id: String) -> Dictionary:
	if profiles.is_empty():
		profiles = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
		for key: String in profiles:
			var data: Dictionary = profiles[key]
			if data.get("impact_effect")!="ember_pool": continue
			var pool: Dictionary = data.ember_pool
			if pool.hazard_profile=="inherit": pool.hazard_profile = data.get("bindings",{}).get("ember_hazard_profile","")
			if WorldHazardArea.profile(pool.hazard_profile).is_empty() or minf(pool.width,minf(pool.depth,pool.duration_s))<=0:
				push_error("Invalid ember profile "+key)
				profiles[key] = {}
	return profiles.get(id,{})

static func box(parent: Node2D, rect: Rect2, layer: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	body.position = rect.get_center()
	body.collision_layer = layer
	body.collision_mask = 0
	body.add_child(collision)
	parent.add_child(body)
	return body

static func blast_mechanisms(origin: Node, point: Vector2, radius: float, packet: Dictionary) -> void:
	var domain := ProjectileField.domain_for(origin)
	if not domain is OrdinaryRoomSession or domain.room==null: return
	for target: Node in domain.room.element_runtime.nodes.values():
		if target.has_method("receive_blast"): target.receive_blast(point,radius,packet)

static func submit_hit(host: Dictionary, target_id: String, source: String, receipt: String, unit: Vector2, profile_data: Dictionary, environment := true) -> void:
	var health: HealthState
	if target_id=="player":
		health = host.controller.actor_resources.health
	else:
		var actor: EnemyActor = host.room.enemies.get(target_id)
		if not is_instance_valid(actor) or not actor.damageable.can_receive_effects(): return
		health = actor.health
	if health.terminal or not host.lifetime.active: return
	var request := DamageRequest.new()
	request.token = host.lifetime.token()
	request.event_id = receipt
	request.source_id = source
	request.target_id = target_id
	request.actor_epoch = request.token.actor_epoch
	request.health_epoch = health.epoch
	request.kind = DamageRequest.Kind.ENVIRONMENT if environment else DamageRequest.Kind.MONSTER
	request.amount = profile_data.amount
	request.hazard_category = profile_data.get("category","solid")
	request.hit_direction = unit
	host.policy.submit(request)

static func bodies(host: Dictionary) -> Dictionary:
	var result := {"player":host.controller.motor}
	for id: String in host.room.enemies:
		var enemy: EnemyActor = host.room.enemies[id]
		if not enemy.health.terminal: result[id] = enemy.motor
	return result

static func bounds_of(body: Node2D) -> Rect2:
	var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision==null: return Rect2(body.global_position,Vector2.ZERO)
	return collision.global_transform*collision.shape.get_rect()

static func overlaps(polygon: PackedVector2Array, rect: Rect2) -> bool:
	var box_points := PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	return not Geometry2D.intersect_polygons(polygon,box_points).is_empty()
