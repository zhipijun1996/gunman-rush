class_name FixedWorldRoom
extends Node2D
## Authored geometry and placements. Reads contract interfaces; never grants progress.
var document_error := ""
@export var document_ref := "":
	set(value):
		document_ref = value
		if not value.is_empty():
			var document := WorldRoomDocument.read(value)
			document_error = str(document.error) if document.has("error") else WorldRoomDocument.apply(self, document)
@export var room_id := ""
@export var arrival_text: String
@export var traveler_point := Vector2.ZERO
@export var route_guide: Dictionary = {}
@export var intro_sequence: Dictionary = {}
@export var onboarding: Dictionary = {}
@export var wave_encounter: Dictionary = {}
@export var tutorial_action: String
@export var tutorial_target: String
@export var tutorial_min_move:=100.0
@export var tutorial_recoil_finish_x:=1540.0
@export var section_volumes: Array[Dictionary] = []
@export var retry_anchors: Array[Dictionary] = []
var camera_concealers: Dictionary = {}
var boundary_art_rock: Array[Rect2] = []
@export var art_placements: Array[Dictionary] = []
@export var art_profile := "meadow"
## Explicit regional threshold sample; empty for authored full rooms.
@export var region_preview := ""
@export var bell_mechanisms: Array[Dictionary] = []
var mechanisms: Dictionary={}
var element_runtime := WorldElementRuntime.new()
var element_policy: FrameDamagePolicy
@export_storage var platform_appearances: Dictionary = {}
var station_animation: WorldChargingStation
var interaction_hosts: Array[WorldRoomInteraction] = []
var service_pickup_sprites: Dictionary={}
@export var platforms: Array[Rect2] = []
## Authored polygon geometry; the same vertices feed physics and presentation.
@export var terrain_polygons: Array[Dictionary] = []
## Optional versioned appearance; authoritative solids and hazards remain separate.
@export var terrain_paint: Dictionary = {}
## Stable authoring identities for legacy indexed arrays. Never used as progress.
@export var workbench_entity_ids: Dictionary = {}
@export var one_way_indices: Array[int] = []
## Explicit scenery supplies the surface image; authored rectangles still collide.
@export var illustrated_platform_indices: Array[int] = []
@export var masonry_platform_indices: Array[int] = []
@export var start_point := Vector2(144,512)
@export var rest_point := Vector2.ZERO
@export var reward_point := Vector2.ZERO
@export var enemy_placements: Array[Dictionary] = []
@export var signs: Array[Dictionary] = []
@export var hazards: Array[Rect2] = []
@export var spike_strips: Array[Dictionary] = []
@export var gear_obstacles: Array[Dictionary] = []
@export var story_sequence: Dictionary = {}
@export var hook_points: Array[Vector2] = []
@export var climbable_walls: Array[Rect2] = []
@export var environment_zones: Array[Dictionary] = []
var interaction_point:=Vector2.INF
var cycle_at_load := 0
var door_open: Dictionary={}
var services: WorldServices
var loot: WorldCoinDrops

@export var boss_identity: StringName
@export var boss_binding: Script
@export var defeat_action: String
@export var defeat_flag: String
@export var reward_action: String
@export var reward_text: String
@export var boss_position := Vector2.ZERO
@export var arena_bounds := Rect2()
@export var battle_entry_anchor := Vector2.ZERO
@export var arena_door_height := 192.0
var contract: Dictionary = {}
var doors: Array = []
var door_blocks: Dictionary = {}
var enemies: Dictionary = {}
var boss: BossMotor
var encounter: BossEncounter
var boss_contact: DemoContactEmitter
var seals: Array[StaticBody2D] = []
var battle_started := false
var battle_finished := false

static func material_for_profile(profile: String) -> String:
	return {"clockheart":"mill","mill":"mill","barn":"barn","cellar":"cellar","secret":"cellar","well":"well"}.get(profile,"")
func interior_material() -> String:
	return material_for_profile(art_profile)

func platform_index(id: String) -> int:
	return workbench_entity_ids.get("platforms",[]).find(id)

func _ready() -> void:
	z_index = -1
	var boundary:=WorldRoomSpace.boundary_platforms(contract.world_geometry,doors)
	var exterior_solid:=WorldRoomSpace.exterior_fill(contract.world_geometry,doors)
	boundary_art_rock=exterior_solid.duplicate()
	boundary_art_rock.append_array(boundary)
	platforms.append_array(boundary)
	# The displayed exterior is actual rock, not an empty pocket behind a thin shell.
	# Keep authored platform indices stable for one-way/art bindings.
	var collision_platforms: Array[Rect2]=platforms.duplicate()
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
		collision.one_way_collision = index in one_way_indices
		if collision.one_way_collision: body.add_to_group("one_way_platform")
		body.add_child(collision)
		add_child(body)
	for polygon: Dictionary in terrain_polygons:
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
		add_child(body)
	for door: Dictionary in doors:
		var blocker := StaticBody2D.new()
		blocker.position = FixedWorldProvider.point(door.position_candidate.local_world_units)
		if door.direction in ["left","right"]: blocker.position.y -= 48
		var shape := RectangleShape2D.new()
		shape.size = Vector2(32,96) if door.direction in ["left","right"] else Vector2(128,32)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		blocker.add_child(collision)
		add_child(blocker)
		door_blocks[door.id] = blocker
	if bool(Engine.get_meta("world_editor_graybox", false)):
		var graybox := WorldEditorGraybox.new()
		graybox.room = self
		add_child(graybox)
	else:
		for zone: Dictionary in contract.camera.get("zones",[]):
			var conceal: Array[Rect2] = []
			for raw: Array in zone.get("conceal",[]):conceal.append(FixedWorldProvider.rect(raw))
			if conceal.is_empty():continue
			var mask:=UnderworldTerrain.build(conceal)
			mask.z_index=2000
			if not interior_material().is_empty():TerrainMaterialRegistry.install_on(mask,"mill_masonry")
			add_child(mask);camera_concealers[str(zone.id)]=mask
		# Existing textured rock covers the near exterior. Deep opaque rock continues
		# past it at extreme aspect ratios without allocating an unbounded tile field.
		var exterior:=FixedWorldProvider.rect(contract.world_geometry.bounds_world_units).grow(512)
		for fill: Rect2 in [Rect2(-100000,-100000,200000,exterior.position.y+100000),Rect2(-100000,exterior.end.y,200000,100000),Rect2(-100000,exterior.position.y,exterior.position.x+100000,exterior.size.y),Rect2(exterior.end.x,exterior.position.y,100000,exterior.size.y)]:
			var backing:=Polygon2D.new()
			backing.polygon=PackedVector2Array([fill.position,Vector2(fill.end.x,fill.position.y),fill.end,Vector2(fill.position.x,fill.end.y)])
			backing.color=Color("0d101e");backing.z_index=1000;add_child(backing)
		add_child(TerrainComposer.build(self))
		var scenery:PlainsRoomArt=PlainsRoomArt.new() if region_preview.is_empty() else RegionThresholdArt.new();scenery.room=self;add_child(scenery)
	for rect: Rect2 in climbable_walls:
		var wall:=WorldClimbableWall.new();wall.bounds=rect;add_child(wall)
	for point: Vector2 in hook_points:
		var anchor:=GrappleAnchor.new();anchor.position=point;anchor.hang_enabled=true;anchor.material_family="rootbound" if room_id.begins_with("F-") or room_id.begins_with("M-") or room_id.begins_with("T-") else "clockwork";add_child(anchor)
	for sign: Dictionary in signs:
		var marker:=Sprite2D.new()
		marker.texture=WorldProps.prop("notice_board")
		marker.scale=Vector2.ONE*40/marker.texture.get_height()
		var point:=FixedWorldProvider.point(sign.point)
		var support:=INF
		for platform: Rect2 in platforms:
			if point.x>=platform.position.x and point.x<=platform.end.x and platform.position.y>=point.y:
				support=minf(support,platform.position.y)
		for polygon: Dictionary in terrain_polygons:
			support = minf(support, UnderworldPolygonTerrain.surface_below(polygon.points, point))
		if is_inf(support): support=point.y+40
		marker.position=Vector2(point.x,support-20)
		sign["interaction_point"]=Vector2(point.x,support-18)
		add_child(marker)

func section_at(point: Vector2) -> String:
	for volume: Dictionary in section_volumes:
		if FixedWorldProvider.rect(volume.bounds).has_point(point): return str(volume.id)
	return "main"

func physical_action(id: String) -> WorldRoomInteraction:
	for host: WorldRoomInteraction in interaction_hosts:
		if host.action_id==id: return host
	return null

func install_mechanisms(controller: PlayerController,lifetime: DemoLifetime,saved: Dictionary,submit: Callable) -> void:
	# The older workbench adapter still supplies array rows. Convert at this
	# boundary; all runtime dispatch and persistence uses the same elements.
	for row: Dictionary in bell_mechanisms:
		var source := WorldElementSwitch.new()
		source.element_id = str(row.id); source.position = FixedWorldProvider.point(row.bell)
		source.duration = float(row.get("open_seconds",0))
		source.state_scope = "attempt" if source.duration>0 else "permanent"
		for point: Array in row.get("access_bells",[]): source.access_points.append(FixedWorldProvider.point(point))
		var target_id := source.element_id+"/gate"
		if row.has("carrier"):
			var carrier := get_node(str(row.carrier)) as WorldMovingPlatform
			if carrier.element_id.is_empty(): carrier.element_id = room_id+":node:"+str(row.carrier)
			carrier.state_scope = source.state_scope
			target_id = carrier.element_id; source.repeat_enabled = true
		else:
			var gate := WorldElementGate.new(); gate.element_id = target_id
			gate.bounds = FixedWorldProvider.rect(row.gate); gate.state_scope = source.state_scope
			add_child(gate)
		source.links = [{"output":"active","target":target_id,"input":"set_active"}]
		add_child(source)
	for node: Node in find_children("*","WorldMovingPlatform",true,false):
		if node.element_id.is_empty(): node.element_id = room_id+":node:"+str(get_path_to(node))
	element_runtime.bind(self,controller,element_policy,lifetime,saved,submit)

func mechanism_snapshot() -> Dictionary:
	return element_runtime.snapshot()

func configure(row: Dictionary) -> void:
	contract = row
	# Logical sections may gain explicit trigger volumes in the editor. Existing
	# authored volumes remain the fallback when a section has no spatial extent.
	for section: Dictionary in row.get("sections", []):
		if not section.get("bounds") is Array or section.bounds.size() != 4: continue
		var found := false
		for volume: Dictionary in section_volumes:
			if volume.id == section.id:
				volume.bounds = section.bounds.duplicate()
				found = true
				break
		if not found: section_volumes.append({"id":section.id, "bounds":section.bounds.duplicate()})
	doors = row.doors.filter(func(door: Dictionary) -> bool: return door.get("target_implemented",false))
	queue_redraw()

func _draw() -> void:
	if contract.is_empty(): return
	var bounds := FixedWorldProvider.rect(contract.world_geometry.bounds_world_units)
	for i: int in platforms.size():
		if i in one_way_indices and i not in illustrated_platform_indices: UnderworldTerrain.draw_one_way(self,platforms[i])
	for door: Dictionary in doors:
		if door.get("front_door",false) or door.get("npc_guard",false):continue
		var p := FixedWorldProvider.point(door.position_candidate.local_world_units)
		var rect:=Rect2(p-Vector2(16,96),Vector2(32,96)) if door.direction in ["left","right"] else Rect2(p-Vector2(64,16),Vector2(128,32))
		if not door_open.get(door.id,false):
			if art_placements.any(func(p:Dictionary)->bool: return p.get("closed_gate_for","")==str(door.id)):
				UnderworldTerrain.draw_mechanism_beam(self,rect)
				continue
			draw_rect(rect,Color("3c4b44"))
			draw_rect(rect,Color("9f8b67"),false,3)
			draw_line(rect.position,rect.end,Color("9f8b67"),3)
			draw_line(Vector2(rect.end.x,rect.position.y),Vector2(rect.position.x,rect.end.y),Color("9f8b67"),3)

	if not boss_identity.is_empty():
		for x: float in [arena_bounds.position.x,arena_bounds.end.x]:
			var doorway:=Rect2(x-6,arena_bounds.end.y-arena_door_height,12,arena_door_height)
			if battle_started and not battle_finished: draw_rect(doorway,Color("d8b35d"))

	if interaction_point.is_finite():
		var tip:=interaction_point+Vector2(0,-55)
		draw_polyline(PackedVector2Array([tip+Vector2(-5,5),tip,tip+Vector2(5,5)]),DemoClockworkTheme.PAPER,2)
	if reward_point != Vector2.ZERO and battle_finished and services!=null and not services.state.value.receipts.has(reward_action):
		WorldProps.draw_icon(self,ItemPresentation.icon(&"echo"),reward_point,30)

func spawn_enemy(placement: Dictionary,controller: PlayerController,policy: FrameDamagePolicy,lifetime: DemoLifetime,saved: Dictionary,entry_anchor: Vector2) -> EnemyActor:
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
		for surface: Rect2 in platforms:
			if absf(surface.position.y-sole)<=8 and body.position.x>=surface.position.x and body.position.x<=surface.end.x:
				body.position.y=surface.position.y-actor.definition.collision_size.y*.5
				break
	add_child(body)
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
		remains.restore_presentation(saved.corpse,_corpse_support(saved.corpse))
	enemies[id] = actor
	return actor

func install(controller: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, saved_enemies: Dictionary, boss_defeated: bool, entry_anchor: Vector2) -> void:
	element_policy = policy
	for placement: Dictionary in enemy_placements:
		spawn_enemy(placement,controller,policy,lifetime,saved_enemies.get(str(placement.id),{}),entry_anchor)
	for index: int in hazards.size():
		add_child(DemoContactEmitter.environment_rect(hazards[index],policy,controller,StringName(room_id+":terrain:"+str(index))))
	for strip: Dictionary in spike_strips:
		add_child(DemoContactEmitter.environment_rect(FixedWorldProvider.rect(strip.bounds),policy,controller,StringName(room_id+":spikes:"+str(strip.id))))
	for spec: Dictionary in gear_obstacles:
		var gear:=WorldGearObstacle.new()
		gear.name=str(spec.id);gear.definition=spec;gear.controller=controller;gear.policy=policy
		add_child(gear)
	if boss_identity.is_empty() or boss_defeated:
		battle_finished = not boss_identity.is_empty()
		return
	if boss_binding==null:
		push_error("Boss room requires its owned encounter binding: "+room_id)
		return
	var binding: RefCounted=boss_binding.new()
	var installed: Dictionary=binding.call("install",self,boss_identity,boss_position,arena_bounds,controller,policy,lifetime)
	boss=installed.boss;encounter=installed.encounter;boss_contact=installed.contact
	for x: float in [arena_bounds.position.x,arena_bounds.end.x]:
		var seal := StaticBody2D.new()
		seal.position = Vector2(x,arena_bounds.end.y-arena_door_height*.5)
		seal.collision_layer = 0
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(12,arena_door_height)
		collision.shape = shape
		seal.add_child(collision)
		add_child(seal)
		seals.append(seal)

func update_battle(player_position: Vector2) -> void:
	if encounter == null or battle_finished: return
	if not battle_started and Rect2(arena_bounds.position+Vector2(8,0),arena_bounds.size-Vector2(16,0)).grow(.1).encloses(Rect2(player_position-Vector2(12,18),Vector2(24,36))):
		battle_started = encounter.activate()
		boss_contact.enabled = battle_started
		for seal: StaticBody2D in seals: seal.set_deferred("collision_layer",1)
		queue_redraw()
	if encounter.health.terminal: boss_contact.enabled = false

func finish_battle() -> void:
	battle_finished = true
	for seal: StaticBody2D in seals: seal.set_deferred("collision_layer",0)
	queue_redraw()

func snapshot() -> Dictionary:
	var result := {}
	for id: String in enemies:
		var actor: EnemyActor = enemies[id]
		if actor.get_meta("wave_attempt",false):continue
		if actor.definition.behavior_id == &"chime_target": continue
		result[id] = actor.region_snapshot()
		var remains:=EnemyPresentationBinding.remains(actor.motor.get_node("Presentation"))
		if actor.health.terminal and remains!=null:
			var support:=remains.support_node()
			if is_instance_valid(support) and support.has_meta(&"world_ground"):
				var rect: Rect2=support.get_meta(&"world_ground")
				var pose:=remains.presentation_snapshot({"kind":"ground","rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
				if not pose.is_empty(): result[id].corpse=pose
			elif is_instance_valid(support) and support.has_meta(&"world_ground_polygon"):
				var pose:=remains.presentation_snapshot({"kind":"ground_polygon","id":str(support.get_meta(&"world_ground_polygon"))})
				if not pose.is_empty(): result[id].corpse=pose
	return result

func refresh_doors(state: FixedWorldState, content: FixedWorldProvider) -> void:
	for door: Dictionary in doors:
		var opened := bool(door.outbound_allowed) and state.holds(door.requires) and not content.room(str(door.target_room)).is_empty()
		door_open[door.id]=opened
		(door_blocks[door.id] as StaticBody2D).set_deferred("collision_layer",0 if opened or door.get("front_door",false) or door.get("npc_guard",false) else 1)
	queue_redraw()

func bind_services(value: WorldServices,controller: PlayerController,policy: FrameDamagePolicy,lifetime: DemoLifetime) -> void:
	services=value
	for platform: Node in find_children("*","WorldMovingPlatform",true,false): platform.bind_activation(value.state)
	var regional_art := get_node_or_null("RegionalArt") as PlainsRoomArt
	if regional_art != null: regional_art.player=controller.motor
	for pickup: Dictionary in services.definitions.get("pickups",[]):
		if pickup.room_id!=room_id:continue
		var art:=WorldSpriteAnimation.new();art.asset_id="equipment"
		art.position=FixedWorldProvider.point(pickup.point)+Vector2(0,18);add_child(art)
		service_pickup_sprites[pickup.id]=art
	services.state.committed.connect(_refresh_service_pickups);_refresh_service_pickups(0)
	for node: Node in find_children("*","WorldRoomInteraction",true,false):
		var host:=node as WorldRoomInteraction
		host.bind(value.state);interaction_hosts.append(host)
	if rest_point!=Vector2.ZERO:
		station_animation=WorldChargingStation.new();station_animation.position=rest_point+Vector2(0,18);add_child(station_animation)
	loot=WorldCoinDrops.new();loot.services=value;loot.controller=controller;loot.room_id=room_id;loot.arena_bounds=arena_bounds
	add_child(loot)
	for presentation: Node in find_children("*","WorldFlagPresentation",true,false): presentation.bind(value.state.has)
	for zone: Dictionary in environment_zones:
		var fixture:=WorldEnvironmentZone.new()
		fixture.name=str(zone.id)
		fixture.bounds=FixedWorldProvider.rect(zone.bounds)
		fixture.mode=zone.mode;fixture.services=value
		fixture.controller=controller;fixture.policy=policy;fixture.lifetime=lifetime
		add_child(fixture)
	queue_redraw()

func _refresh_service_pickups(_revision: int) -> void:
	for id: String in service_pickup_sprites:service_pickup_sprites[id].visible=id not in services.ledger().collected

func celebrate_service_pickup(id: String) -> void:
	if not service_pickup_sprites.has(id):return
	var art:=WorldSpriteAnimation.new();art.asset_id="collection_burst";art.disposable=true
	art.position=service_pickup_sprites[id].position-Vector2(0,18);art.z_index=10;add_child(art)

func _corpse_support(pose: Dictionary) -> Node2D:
	for body: Node in find_children("*","StaticBody2D",true,false):
		if body.has_meta(&"world_ground_polygon") and pose.get("support", {}).get("kind") == "ground_polygon":
			if str(body.get_meta(&"world_ground_polygon")) == str(pose.support.get("id", "")): return body as Node2D
		if not body.has_meta(&"world_ground"): continue
		var rect: Rect2=body.get_meta(&"world_ground")
		if [rect.position.x,rect.position.y,rect.size.x,rect.size.y]==pose.get("support",{}).get("rect",[]): return body as Node2D
	return null

func update_camera_concealment(active: String, frame: Dictionary) -> void:
	for id: String in camera_concealers:
		var entering: bool=not frame.get("portal",{}).is_empty() and id in [str(frame.a.id),str(frame.b.id)]
		camera_concealers[id].visible = id!=active and not entering
