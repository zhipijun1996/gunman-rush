class_name WorldRoomAssembly
extends RefCounted
## Internal registered assembly service. Room data is already resolved by the catalog.
## Batches terrain for continuous surfaces; gameplay hosts keep stable instance IDs.

static func build_collision(room: FixedWorldRoom, parent: Node) -> void:
	var boundary:=WorldRoomSpace.boundary_platforms(room.contract.world_geometry,room.doors)
	var exterior_solid:=WorldRoomSpace.exterior_fill(room.contract.world_geometry,room.doors)
	room.boundary_art_rock=exterior_solid.duplicate()
	room.boundary_art_rock.append_array(boundary)
	room.platforms.append_array(boundary)
	# The displayed exterior is actual rock, not an empty pocket behind a thin shell.
	# Keep authored platform indices stable for one-way/art bindings.
	var collision_platforms: Array[Rect2]=room.platforms.duplicate()
	collision_platforms.append_array(exterior_solid)
	for index: int in collision_platforms.size():
		var body := StaticBody2D.new()
		body.position = collision_platforms[index].get_center()
		body.set_meta(&"world_ground",collision_platforms[index])
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape := RectangleShape2D.new()
		shape.size = collision_platforms[index].size
		collision.shape = shape
		collision.one_way_collision = index in room.one_way_indices
		if collision.one_way_collision: body.add_to_group("one_way_platform")
		body.add_child(collision)
		parent.add_child(body)
	for polygon: Dictionary in room.terrain_polygons:
		var body := StaticBody2D.new()
		body.name = "Polygon_"+str(polygon.id).replace(":", "_")
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta(&"world_ground_polygon", str(polygon.id))
		var shape := CollisionPolygon2D.new()
		var points := PackedVector2Array()
		for pair: Array in polygon.points: points.append(FixedWorldProvider.point(pair))
		shape.polygon = points
		body.add_child(shape)
		parent.add_child(body)
	for door: Dictionary in room.doors:
		var blocker := StaticBody2D.new()
		blocker.position = FixedWorldProvider.point(door.position_candidate.local_world_units)
		if door.direction in ["left","right"]: blocker.position.y -= 48
		var shape := RectangleShape2D.new()
		shape.size = Vector2(32,96) if door.direction in ["left","right"] else Vector2(128,32)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		blocker.add_child(collision)
		parent.add_child(blocker)
		room.door_blocks[door.id] = blocker

static func build(room: FixedWorldRoom) -> void:
	room.z_index = -1
	build_collision(room, room)
	for zone: Dictionary in room.contract.camera.get("zones",[]):
		var conceal: Array[Rect2] = []
		for raw: Array in zone.get("conceal",[]):conceal.append(FixedWorldProvider.rect(raw))
		if conceal.is_empty():continue
		var mask:=UnderworldTerrain.build(conceal)
		mask.z_index=2000
		TerrainMaterialRegistry.install_on(mask,room.terrain_material)
		room.add_child(mask);room.camera_concealers[str(zone.id)]=mask
	# Existing textured rock covers the near exterior. Deep opaque rock continues
	# past it at extreme aspect ratios without allocating an unbounded tile field.
	var exterior:=FixedWorldProvider.rect(room.contract.world_geometry.bounds_world_units).grow(WorldRoomSpace.EXTERIOR_DEPTH)
	for fill: Rect2 in [Rect2(-100000,-100000,200000,exterior.position.y+100000),Rect2(-100000,exterior.end.y,200000,100000),Rect2(-100000,exterior.position.y,exterior.position.x+100000,exterior.size.y),Rect2(exterior.end.x,exterior.position.y,100000,exterior.size.y)]:
		var backing:=Polygon2D.new()
		backing.polygon=PackedVector2Array([fill.position,Vector2(fill.end.x,fill.position.y),fill.end,Vector2(fill.position.x,fill.end.y)])
		backing.color=Color("0d101e");backing.z_index=1000;room.add_child(backing)
	room.add_child(TerrainComposer.build(room))
	if not room.spike_strips.is_empty():
		var spikes := WorldSpikeArt.new()
		spikes.setup(room)
		room.add_child(spikes)
	for rect: Rect2 in room.climbable_walls:
		var wall:=WorldClimbableWall.new();wall.bounds=rect;room.add_child(wall)
	for index: int in room.hook_points.size():
		var anchor := GrappleAnchor.new()
		anchor.position = room.hook_points[index]
		anchor.hang_enabled = true
		var ids: Array = room.entity_ids.get("hook_points",[])
		if index < ids.size():
			anchor.element_id = ids[index]
			var props: Dictionary = room.get_meta("editor_element_rows",{}).get(ids[index],{}).get("properties",{})
			for field: String in ["cooldown_s","initial_available","reactivate_warning_s","section_id","state_scope"]:
				if props.has(field): anchor.set(field,props[field])
		room.add_child(anchor)
	for sign: Dictionary in room.signs:
		var marker := RoomWaymarker.new()
		marker.notice = true
		var point:=FixedWorldProvider.point(sign.point)
		var support:=INF
		for platform: Rect2 in room.platforms:
			if point.x>=platform.position.x and point.x<=platform.end.x and platform.position.y>=point.y:
				support=minf(support,platform.position.y)
		for polygon: Dictionary in room.terrain_polygons:
			support = minf(support, UnderworldPolygonTerrain.surface_below(polygon.points, point))
		if is_inf(support): support=point.y+40
		marker.position=Vector2(point.x,support)
		sign["interaction_point"]=Vector2(point.x,support-18)
		room.add_child(marker)
	for anchor: Dictionary in room.retry_anchors:
		var marker := RoomWaymarker.new()
		marker.position = FixedWorldProvider.point(anchor.point)+Vector2(0,18)
		marker.z_index = -1
		room.add_child(marker)
		room.recovery_markers[anchor.id] = marker


# Some placements and older saves use player-height references. Preserve x and
# settle the actual enemy sole only when it already lies near a platform top.
static func _settled_enemy_point(room: FixedWorldRoom, definition: EnemyDefinition, point: Vector2) -> Vector2:
	if definition.aerial: return point
	var half_height := definition.collision_size.y*.5
	for surface: Rect2 in room.platforms:
		if absf(point.y+half_height-surface.position.y)<=8 and point.x>=surface.position.x and point.x<=surface.end.x:
			return Vector2(point.x,surface.position.y-half_height)
	return point


static func spawn_enemy(room: FixedWorldRoom, placement: Dictionary,controller: PlayerController,policy: FrameDamagePolicy,lifetime: DemoLifetime,saved: Dictionary,entry_anchor: Vector2) -> EnemyActor:
	var id := str(placement.id)
	# Practice targets always return to their authored perch, including old saves
	# that recorded a former combat flyer under the same placement identity.
	if str(placement.behavior) == "chime_target": saved = {}
	var body := EnemyFactory.create_for_behavior(StringName(placement.behavior))
	var actor := body.get_node("Actor") as EnemyActor
	body.ground_recovery_enabled = actor.definition.behavior_id != &"forest_crossbranch"
	actor.set_meta(&"world_persistent_corpse",true)
	if placement.has("max_health"):
		actor.definition=actor.definition.duplicate(true) as EnemyDefinition
		actor.definition.health_definition.max_health=float(placement.max_health)
		actor.definition.health_definition.initial_current=float(placement.max_health)
	# _ready binds the patrol's home. The persisted motor position describes
	# where its current trip resumes, even after several visits to this room.
	body.position = _settled_enemy_point(room,actor.definition,FixedWorldProvider.point(placement.point))
	room.add_child(body)
	if saved.has("position"):
		body.position = _settled_enemy_point(room,actor.definition,FixedWorldProvider.point(saved.position))
	EnemyPresentationBinding.replace(actor,&"underworld")
	policy.bind_damageable(StringName(id),actor.damageable,actor.health)
	actor.bind_encounter(controller,policy,lifetime,StringName(id),[entry_anchor])
	if saved.has("direction"): actor.brain.direction=int(saved.direction)
	if saved.has("health"): actor.restore_instance_health(float(saved.health))
	if actor.attack_behavior is ForestCrossbranchBehavior:
		var records := {id:saved} if saved.has("depth_state") else {}
		var error := actor.configure_region_placement(placement,StringName(id),true,records,func(): return actor.attack_behavior.max_concurrent_attacks)
		if not error.is_empty(): push_error(error + ": " + id)
	elif not saved.is_empty() and not actor.health.terminal and actor.attack_behavior != null:
		actor.attack_behavior.restore_region_state(saved)
	EnemyPresentationBinding.synchronize(actor)
	var contact:=DemoContactEmitter.attach(body,policy,controller,StringName(id+":contact"),DamageRequest.Kind.MONSTER,actor.definition.collision_size/2)
	contact.enabled=not actor.health.terminal and actor.definition.behavior_id != &"chime_target"
	actor.defeated.connect(func(_actor: EnemyActor) -> void: contact.enabled=false;contact.set_physics_process(false))
	var remains:=EnemyPresentationBinding.remains(body.get_node("Presentation"))
	if actor.health.terminal and remains!=null and saved.has("corpse"):
		remains.restore_presentation(saved.corpse,room._corpse_support(saved.corpse))
	room.enemies[id] = actor
	return actor


static func install(room: FixedWorldRoom, controller: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, saved_enemies: Dictionary, entry_anchor: Vector2) -> void:
	room.element_policy = policy
	for placement: Dictionary in room.enemy_placements:
		room.spawn_enemy(placement,controller,policy,lifetime,saved_enemies.get(str(placement.id),{}),entry_anchor)
	for index: int in room.hazards.size():
		room.add_child(DemoContactEmitter.environment_rect(room.hazards[index],policy,controller,StringName(room.room_id+":terrain:"+str(index)),true))
	for strip: Dictionary in room.spike_strips:
		room.add_child(DemoContactEmitter.environment_rect(FixedWorldProvider.rect(strip.bounds),policy,controller,StringName(room.room_id+":spikes:"+str(strip.id)),true))
