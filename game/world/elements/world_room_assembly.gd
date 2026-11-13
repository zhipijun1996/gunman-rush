class_name WorldRoomAssembly
extends RefCounted
## Internal registered assembly service. Room data is already resolved by the catalog.
## Batches terrain for continuous surfaces; gameplay hosts keep stable instance IDs.

static func build(room: FixedWorldRoom) -> void:
	room.z_index = -1
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
		room.add_child(body)
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
		room.add_child(body)
	for door: Dictionary in room.doors:
		var blocker := StaticBody2D.new()
		blocker.position = FixedWorldProvider.point(door.position_candidate.local_world_units)
		if door.direction in ["left","right"]: blocker.position.y -= 48
		var shape := RectangleShape2D.new()
		shape.size = Vector2(32,96) if door.direction in ["left","right"] else Vector2(128,32)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		blocker.add_child(collision)
		room.add_child(blocker)
		room.door_blocks[door.id] = blocker
	if bool(Engine.get_meta("world_editor_graybox", false)):
		var graybox := WorldEditorGraybox.new()
		graybox.room = room
		room.add_child(graybox)
	else:
		for zone: Dictionary in room.contract.camera.get("zones",[]):
			var conceal: Array[Rect2] = []
			for raw: Array in zone.get("conceal",[]):conceal.append(FixedWorldProvider.rect(raw))
			if conceal.is_empty():continue
			var mask:=UnderworldTerrain.build(conceal)
			mask.z_index=2000
			if not room.interior_material().is_empty():TerrainMaterialRegistry.install_on(mask,"mill_masonry")
			room.add_child(mask);room.camera_concealers[str(zone.id)]=mask
		# Existing textured rock covers the near exterior. Deep opaque rock continues
		# past it at extreme aspect ratios without allocating an unbounded tile field.
		var exterior:=FixedWorldProvider.rect(room.contract.world_geometry.bounds_world_units).grow(512)
		for fill: Rect2 in [Rect2(-100000,-100000,200000,exterior.position.y+100000),Rect2(-100000,exterior.end.y,200000,100000),Rect2(-100000,exterior.position.y,exterior.position.x+100000,exterior.size.y),Rect2(exterior.end.x,exterior.position.y,100000,exterior.size.y)]:
			var backing:=Polygon2D.new()
			backing.polygon=PackedVector2Array([fill.position,Vector2(fill.end.x,fill.position.y),fill.end,Vector2(fill.position.x,fill.end.y)])
			backing.color=Color("0d101e");backing.z_index=1000;room.add_child(backing)
		room.add_child(TerrainComposer.build(room))
		var scenery:PlainsRoomArt=PlainsRoomArt.new() if room.region_preview.is_empty() else RegionThresholdArt.new();scenery.room=room;room.add_child(scenery)
	for rect: Rect2 in room.climbable_walls:
		var wall:=WorldClimbableWall.new();wall.bounds=rect;room.add_child(wall)
	for point: Vector2 in room.hook_points:
		var anchor:=GrappleAnchor.new();anchor.position=point;anchor.hang_enabled=true;anchor.material_family="rootbound" if room.room_id.begins_with("F-") or room.room_id.begins_with("M-") or room.room_id.begins_with("T-") else "clockwork";room.add_child(anchor)
	for sign: Dictionary in room.signs:
		var marker:=Sprite2D.new()
		marker.texture=WorldProps.prop("notice_board")
		marker.scale=Vector2.ONE*40/marker.texture.get_height()
		var point:=FixedWorldProvider.point(sign.point)
		var support:=INF
		for platform: Rect2 in room.platforms:
			if point.x>=platform.position.x and point.x<=platform.end.x and platform.position.y>=point.y:
				support=minf(support,platform.position.y)
		for polygon: Dictionary in room.terrain_polygons:
			support = minf(support, UnderworldPolygonTerrain.surface_below(polygon.points, point))
		if is_inf(support): support=point.y+40
		marker.position=Vector2(point.x,support-20)
		sign["interaction_point"]=Vector2(point.x,support-18)
		room.add_child(marker)


static func spawn_enemy(room: FixedWorldRoom, placement: Dictionary,controller: PlayerController,policy: FrameDamagePolicy,lifetime: DemoLifetime,saved: Dictionary,entry_anchor: Vector2) -> EnemyActor:
	var id := str(placement.id)
	# Practice targets always return to their authored perch, including old saves
	# that recorded a former combat flyer under the same placement identity.
	if str(placement.behavior) == "chime_target": saved = {}
	var body := EnemyFactory.create_for_behavior(StringName(placement.behavior))
	body.position = FixedWorldProvider.point(saved.get("position",placement.point))
	var actor := body.get_node("Actor") as EnemyActor
	body.ground_recovery_enabled=true
	actor.set_meta(&"world_persistent_corpse",true)
	if placement.has("max_health"):
		actor.definition=actor.definition.duplicate(true) as EnemyDefinition
		actor.definition.health_definition.max_health=float(placement.max_health)
		actor.definition.health_definition.initial_current=float(placement.max_health)
	# Authored points and older saves can use player-height references; settle the actual enemy sole
	# onto its nearby authored platform before home/AI/visual anchors are bound.
	if not actor.definition.aerial:
		var sole := body.position.y + actor.definition.collision_size.y*.5
		for surface: Rect2 in room.platforms:
			if absf(surface.position.y-sole)<=8 and body.position.x>=surface.position.x and body.position.x<=surface.end.x:
				body.position.y=surface.position.y-actor.definition.collision_size.y*.5
				break
	room.add_child(body)
	EnemyPresentationBinding.replace(actor,&"underworld")
	policy.bind_damageable(StringName(id),actor.damageable,actor.health)
	actor.bind_encounter(controller,policy,lifetime,StringName(id),[entry_anchor])
	if saved.has("direction"): actor.brain.direction=int(saved.direction)
	if saved.has("health"): actor.restore_instance_health(float(saved.health))
	if not saved.is_empty() and not actor.health.terminal and actor.attack_behavior != null:
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


static func install(room: FixedWorldRoom, controller: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, saved_enemies: Dictionary, boss_defeated: bool, entry_anchor: Vector2) -> void:
	room.element_policy = policy
	for placement: Dictionary in room.enemy_placements:
		room.spawn_enemy(placement,controller,policy,lifetime,saved_enemies.get(str(placement.id),{}),entry_anchor)
	for index: int in room.hazards.size():
		room.add_child(DemoContactEmitter.environment_rect(room.hazards[index],policy,controller,StringName(room.room_id+":terrain:"+str(index))))
	for strip: Dictionary in room.spike_strips:
		room.add_child(DemoContactEmitter.environment_rect(FixedWorldProvider.rect(strip.bounds),policy,controller,StringName(room.room_id+":spikes:"+str(strip.id))))
	if room.boss_identity.is_empty() or boss_defeated:
		room.battle_finished = not room.boss_identity.is_empty()
		return
	if room.boss_binding==null:
		push_error("Boss room requires its owned encounter binding: "+room.room_id)
		return
	var binding: RefCounted=room.boss_binding.new()
	var installed: Dictionary=binding.call("install",room,room.boss_identity,room.boss_position,room.arena_bounds,controller,policy,lifetime)
	room.boss=installed.boss;room.encounter=installed.encounter;room.boss_contact=installed.contact
	for x: float in [room.arena_bounds.position.x,room.arena_bounds.end.x]:
		var seal := StaticBody2D.new()
		seal.position = Vector2(x,room.arena_bounds.end.y-room.arena_door_height*.5)
		seal.collision_layer = 0
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(12,room.arena_door_height)
		collision.shape = shape
		seal.add_child(collision)
		room.add_child(seal)
		room.seals.append(seal)


static func bind_services(room: FixedWorldRoom, value: WorldServices,controller: PlayerController,policy: FrameDamagePolicy,lifetime: DemoLifetime) -> void:
	room.services=value
	for platform: Node in room.find_children("*","WorldMovingPlatform",true,false): platform.bind_activation(value.state)
	var regional_art := room.get_node_or_null("RegionalArt") as PlainsRoomArt
	if regional_art != null: regional_art.player=controller.motor
	for pickup: Dictionary in room.services.definitions.get("pickups",[]):
		if pickup.room_id!=room.room_id:continue
		var art:=WorldSpriteAnimation.new();art.asset_id="equipment"
		art.position=FixedWorldProvider.point(pickup.point)+Vector2(0,18);room.add_child(art)
		room.service_pickup_sprites[pickup.id]=art
	room.services.state.committed.connect(room._refresh_service_pickups);room._refresh_service_pickups(0)
	for node: Node in room.find_children("*","WorldRoomInteraction",true,false):
		var host:=node as WorldRoomInteraction
		host.bind(value.state);room.interaction_hosts.append(host)
	if room.rest_point!=Vector2.ZERO:
		room.station_animation=WorldChargingStation.new();room.station_animation.position=room.rest_point+Vector2(0,18);room.add_child(room.station_animation)
	room.loot=WorldCoinDrops.new();room.loot.services=value;room.loot.controller=controller;room.loot.room_id=room.room_id;room.loot.arena_bounds=room.arena_bounds
	room.add_child(room.loot)
	for presentation: Node in room.find_children("*","WorldFlagPresentation",true,false): presentation.bind(value.state.has)
	for zone: Dictionary in room.environment_zones:
		var fixture:=WorldEnvironmentZone.new()
		fixture.name=str(zone.id)
		fixture.bounds=FixedWorldProvider.rect(zone.bounds)
		fixture.mode=zone.mode;fixture.services=value
		fixture.controller=controller;fixture.policy=policy;fixture.lifetime=lifetime
		room.add_child(fixture)
	room.queue_redraw()

