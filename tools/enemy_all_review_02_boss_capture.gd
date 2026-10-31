extends SceneTree
## Nine actual scene/Definition combinations, explicit initial combat fixtures.
## AI, gates, HP, collision and player resources retain their original owners.
const BOSSES: Array[String] = ["clockwork_guardian", "bellstrider", "windkeeper", "windkeeper_storm", "thorn_guardian", "thorn_queen", "rootbell_guardian_v2", "thorn_queen_v2", "thorn_queen_canopy"]
const MAX_FRAMES := 3600
const HOLD_FRAMES := 210
class ContactGate extends Node:
	var source: DemoContactEmitter
	var encounter: BossEncounter
	func _physics_process(_delta: float) -> void:
		source.enabled = is_instance_valid(encounter) and encounter.body_contact_enabled()
var trace_path := ""
var only_species := ""
var seed_label := "enemy-all-review-02"
var world: Node2D
var fixture: Node2D
var motor: BossMotor
var encounter: BossEncounter
var controller: PlayerController
var policy: FrameDamagePolicy
var audio: GameAudio
var camera: Camera2D
var heading: Label
var detail: Label
var manifest: Array[String] = []
var cases: Array[Dictionary] = []
var rows: Array[Dictionary] = []
var failures: Array[String] = []
var index := 0
var frame := 0
var local_frame := 0
var first_hit_frame := -1
var death_frame := -1
var last_shot_frame := -1000
var last_jump_frame := -1000
var last_attack_frame := -1000
var busy := false
var geometry: Dictionary = {}
var arena_rect := Rect2()
var last_hook_bell := -1
var rootbell_arrived := false
var last_root_warning := ""
var root_direction := 1.0
var root_jump_until := -1
var root_jump_held := false
var wind_module: PlatformingModule
var wind_cross_axis := 0.0
var wind_jump_active := false
var wind_jump_until := -1
var wind_desired_x := 0.0
var forest_jump_until := -1
var forest_jump_held := false

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--trace="): trace_path = argument.trim_prefix("--trace=")
		if argument.begins_with("--species="): only_species = argument.trim_prefix("--species=")
		if argument.begins_with("--seed="): seed_label = argument.trim_prefix("--seed=")
	start.call_deferred()

func make_label(value: String, point: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = point
	label.add_theme_font_size_override("font_size",font_size)
	return label

func start() -> void:
	root.size = Vector2i(1280,720)
	for id: String in BOSSES:
		if only_species.is_empty() or id in only_species.split(","): manifest.append(id)
	if manifest.is_empty():
		printerr("Unsupported actual Boss id: ",only_species)
		quit(1)
		return
	world = Node2D.new()
	root.add_child(world)
	audio = GameAudio.new()
	world.add_child(audio)
	camera = Camera2D.new()
	world.add_child(camera)
	var overlay := CanvasLayer.new()
	world.add_child(overlay)
	heading = make_label("",Vector2(28,91),18)
	overlay.add_child(heading)
	detail = make_label("",Vector2(28,115),13)
	overlay.add_child(detail)
	overlay.add_child(make_label("ENEMY ALL 02 / BOSS / ACTUAL GODOT / 60 FPS / NORMAL SPEED / STEREO",Vector2(28,643),17))
	overlay.add_child(make_label("Initial actual arena fixture. Real gates / AI / player damage. Missing actions or defeat are reported as coverage gaps.",Vector2(28,675),15))
	await make_case()
	process_frame.connect(drive)
	RenderingServer.frame_post_draw.connect(capture_post_draw)

func point(values: Array) -> Vector2:
	return Vector2(float(values[0]),float(values[1]))

func slab(row: Dictionary) -> void:
	var rect: Array = row.rect
	var bounds := Rect2(rect[0],rect[1],rect[2],rect[3])
	var body := StaticBody2D.new()
	body.name = String(row.id)
	body.position = bounds.get_center()
	body.set_meta("support_world_rect",bounds)
	body.set_meta("support_ids",[String(row.id)])
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = bounds.size
	shape.shape = rectangle
	shape.one_way_collision = bool(row.get("one_way",false))
	body.add_child(shape)
	if shape.one_way_collision: body.add_to_group(&"one_way_platform")
	var pixels := Polygon2D.new()
	pixels.polygon = PackedVector2Array([-bounds.size*.5,Vector2(bounds.size.x*.5,-bounds.size.y*.5),bounds.size*.5,Vector2(-bounds.size.x*.5,bounds.size.y*.5)])
	pixels.color = Color("51654f") if not shape.one_way_collision else Color("6b7651")
	body.add_child(pixels)
	fixture.add_child(body)

func make_case() -> void:
	local_frame = 0
	first_hit_frame = -1
	death_frame = -1
	last_shot_frame = -1000
	last_jump_frame = -1000
	last_attack_frame = -1000
	last_hook_bell = -1
	rootbell_arrived = false
	last_root_warning = ""
	root_direction = 1.0
	root_jump_until = -1
	root_jump_held = false
	wind_module = null
	wind_cross_axis = 0
	wind_jump_active = false
	wind_jump_until = -1
	wind_desired_x = 0
	forest_jump_until = -1
	forest_jump_held = false
	geometry = {}
	var id: String = manifest[index]
	fixture = Node2D.new()
	fixture.name = "BossFixture_%02d_%s" % [index,id]
	fixture.set_meta(&"forest_bible_actor_art",true)
	fixture.set_meta(&"underworld_formal_style",true)
	world.add_child(fixture)
	var modern: bool = id in ["rootbell_guardian_v2","thorn_queen_v2","thorn_queen_canopy"]
	var wind: bool = id in ["bellstrider","windkeeper","windkeeper_storm"]
	var player_spawn := Vector2(350,582)
	var boss_spawn := Vector2(740,558)
	arena_rect = Rect2(240,80,800,520)
	var module: PlatformingModule
	var definition_path := "res://resources/bosses/%s.tres" % id
	if modern:
		if id == "rootbell_guardian_v2": geometry = ForestBossArenaFactory.new().from_prep(Vector2(30,582),1,load(definition_path) as BossDuelDefinition)
		elif id == "thorn_queen_v2": geometry = ForestBossArenaFactory.new().queen_golden(load(definition_path) as ThornForestDefinition)
		else: geometry = (load(definition_path) as ThornQueenCanopyDefinition).build_geometry(Vector2.ZERO)
		if not geometry.get("ok",false):
			failures.append(id + ": actual arena factory rejected")
			await finish()
			return
		for row: Dictionary in geometry.platforms: slab(row)
		for row: Dictionary in geometry.hook_anchors:
			var anchor := GrappleAnchor.new()
			anchor.position = point(row.position)
			fixture.add_child(anchor)
		var arena: Array = geometry.boss_arena
		arena_rect = Rect2(arena[0],arena[1],arena[2],arena[3])
		player_spawn = point(geometry.counter_stands[0] if id == "rootbell_guardian_v2" else geometry.player_spawn)
		if id=="thorn_queen_v2": player_spawn = Vector2(450,342)
		boss_spawn = point(geometry.boss_position)
	elif wind:
		module = preload("res://game/world/generation/scenes/modules/plains_boss_arena.tscn").instantiate() as PlatformingModule
		fixture.add_child(module)
		wind_module = module
		player_spawn = Vector2(350,452)
		if id=="windkeeper_storm": player_spawn = Vector2(870,452)
		boss_spawn = Vector2(735,535)
		arena_rect = Rect2(220,70,820,530)
		geometry = {"source":"res://game/world/generation/scenes/modules/plains_boss_arena.tscn","platforms":module.definition.platforms}
	else:
		slab({"id":"floor","rect":[160,600,960,40],"one_way":false})
		slab({"id":"left_branch","rect":[300,470,180,20],"one_way":true})
		slab({"id":"right_branch","rect":[790,470,180,20],"one_way":true})
		geometry = {"source":"explicit initial two-branch support fixture","platforms":[[160,600,960,40],[300,470,180,20],[790,470,180,20]]}
		if id != "clockwork_guardian": boss_spawn.y = 552
	camera.position = arena_rect.get_center()+Vector2(0,15)
	var fit := minf(1.25,1100.0/maxf(1,arena_rect.size.x))
	camera.zoom = Vector2(fit,fit)
	var player: PlayerMotor = preload("res://game/player/player.tscn").instantiate()
	player.position = player_spawn
	fixture.add_child(player)
	controller = player.get_node("Controller") as PlayerController
	player.get_node("KeyboardMouseAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	controller.router.activate_device(&"gamepad")
	if modern:
		# Same explicitly granted candidate-fixture capabilities as existing
		# Queen/Guardian real-input fixtures; trace discloses the grant.
		controller.enable_shot_energy()
		controller.traversal.grant(&"grapple")
	policy = FrameDamagePolicy.new()
	policy.lifetime = DemoLifetime.new()
	fixture.add_child(policy)
	policy.register_player_controller(controller)
	if not policy.register_target(&"player",controller.actor_resources.health,true): failures.append(id + ": player policy registration failed")
	var scene_id := "windkeeper" if id == "windkeeper_storm" else id
	var scene_path := "res://scenes/bosses/%s.tscn" % scene_id
	motor = (load(scene_path) as PackedScene).instantiate() as BossMotor
	encounter = motor.get_node("Encounter") as BossEncounter
	if id == "windkeeper_storm": encounter.definition = load(definition_path) as BossDefinition
	motor.position = boss_spawn
	fixture.add_child(motor)
	if not policy.bind_damageable(&"review_boss",encounter.damageable,encounter.health): failures.append(id + ": boss policy binding failed")
	var setup: Dictionary = {}
	if id == "rootbell_guardian_v2":
		setup["initial_player_stand"] = "actual geometry.counter_stands[0], supported by the unmodified counter_branch; not a natural entrance traversal"
	if id=="thorn_queen_v2":
		setup["initial_player_stand"] = "midplatform (450,342), actual geometry platform Rect2(300,360,300,20); not a natural entrance traversal"
	if id=="windkeeper_storm":
		setup["initial_player_stand"] = "actual module right shelf (870,452), supported by original Rect2(810,470,190,20); not a natural entrance traversal"
	if modern:
		setup["bind_duel"] = bool(encounter.call("bind_duel",geometry,controller,policy,policy.lifetime))
		if not setup.bind_duel: failures.append(id + ": actual bind_duel rejected geometry")
		# Same real walls and normal delayed full-body arming as the existing
		# native Queen/Guardian fixtures. No restore_closed or player movement.
		var seal := BossArenaSeal.new()
		fixture.add_child(seal)
		seal.setup(arena_rect,arena_rect.grow(100),controller,encounter,policy.lifetime)
		setup["real_arena_seal_armed"] = seal.arm()
	if not encounter.configure_arena(arena_rect.position.x,arena_rect.end.x,player): failures.append(id + ": arena configure failed")
	if encounter is ThornForestEncounter: (encounter as ThornForestEncounter).configure_forest_floor(arena_rect.end.y)
	if wind:
		var segment := SegmentRespawn.new()
		segment.configure(controller,policy.lifetime)
		(encounter as WindkeeperEncounter).bind_stage_geometry(module,controller,policy,policy.lifetime,segment)
		setup["bind_stage_geometry"] = true
		setup["segment_return"] = "not automatically invoked; arena/bridge geometry remains real, no mid-case teleport"
	var contact := DemoContactEmitter.new()
	contact.policy = policy
	contact.controller = controller
	contact.source_id = &"review_boss_contact"
	contact.half_size = encounter.definition.collision_size*.5
	if encounter is WindkeeperEncounter:
		contact.contact_rect_provider = (encounter as WindkeeperEncounter).body_contact_rect
	motor.add_child(contact)
	var gate := ContactGate.new()
	gate.source = contact
	gate.encounter = encounter
	gate.process_physics_priority = 850
	fixture.add_child(gate)
	var case_index := index
	var presentation := motor.get_node("Presentation")
	cases.append({"case":index,"id":id,"definition":String(encounter.definition.stable_id),"definition_path":definition_path,"scene":scene_path,"chain":"actual_boss_scene","renderer":(presentation.get_script() as Script).resource_path,"start_frame":frame+1,"start_seconds":float(Engine.get_process_frames()+1)/60,"movie_start_process_frame":Engine.get_process_frames()+1,"fixture":{"geometry":geometry,"player_spawn":[player_spawn.x,player_spawn.y],"boss_spawn":[boss_spawn.x,boss_spawn.y],"host_configuration":setup,"player_health":controller.actor_resources.health.current,"enemy_health":encounter.health.current,"forest_bible_actor_art":true,"underworld_formal_style":true,"grapple_and_shot_energy_candidate_fixture_grant":modern,"differences":["explicit initial arena geometry and spawn","automated gamepad input replaces KeyboardMouseAdapter"],"production_AI_enabled":encounter.is_physics_processing()},"events":[],"player_events":[],"inputs":[],"shots":[],"states":[],"attacks":[],"deaths":0,"coverage":{},"coverage_gaps":[]})
	cases[case_index]["encounter_events"] = []
	if encounter.has_signal(&"duel_event"):
		encounter.connect(&"duel_event",func(event: Dictionary) -> void:
			var receipt := event.duplicate(true)
			receipt["frame"] = frame
			receipt["local_frame"] = local_frame
			cases[case_index].encounter_events.append(receipt)
			if String(event.get("event","")) in ["bell_launch","body_launch"]:
				cases[case_index].attacks.append({"frame":frame,"local_frame":local_frame,"event":"actual_encounter_attack_event","source_event":receipt})
				last_attack_frame = local_frame)
	controller.traversal.action_changed.connect(func(state: StringName) -> void:
		var target := controller.traversal.hook_target
		var bell_target: bool = is_instance_valid(target) and target is GuardianRootBellV2
		if bell_target and state in [&"hook_contact_kick",&"hook_kick"]: rootbell_arrived = true
		cases[case_index].encounter_events.append({"event":"actual_traversal","frame":frame,"state":String(state),"bell_target":bell_target}))
	encounter.health.changed.connect(func(result: ActorResourceResult) -> void:
		if result.operation == &"damage" and result.status == ActorResourceResult.Status.APPLIED:
			cases[case_index].events.append({"frame":frame,"local_frame":local_frame,"event_id":String(result.event_id),"amount":result.amount_applied,"HP":result.snapshot.current,"epoch":result.snapshot.epoch,"terminal":result.snapshot.terminal})
			if not result.snapshot.terminal and first_hit_frame<0: first_hit_frame = frame
			if result.snapshot.terminal: death_frame = frame)
	controller.actor_resources.health.changed.connect(func(result: ActorResourceResult) -> void:
		if result.operation == &"damage" and result.status == ActorResourceResult.Status.APPLIED:
			cases[case_index].player_events.append({"frame":frame,"amount":result.amount_applied,"HP":result.snapshot.current,"event_id":String(result.event_id),"terminal":result.snapshot.terminal}))
	encounter.defeated.connect(func(_dead: BossEncounter) -> void: cases[case_index].deaths += 1)
	encounter.projectile_created.connect(func(projectile: BossProjectile) -> void:
		last_attack_frame = local_frame
		cases[case_index].attacks.append({"frame":frame,"local_frame":local_frame,"event":"actual_projectile_created","script":(projectile.get_script() as Script).resource_path})
		projectile.hit.connect(func(body: Node2D,event_id: StringName,amount: float) -> void:
			if body != controller.motor or not policy.lifetime.active: return
			var request := DamageRequest.new()
			request.token = policy.lifetime.token()
			request.actor_epoch = policy.lifetime.actor_epoch
			request.health_epoch = controller.actor_resources.health.epoch
			request.target_id = &"player"
			request.source_id = &"review_boss_projectile"
			request.event_id = event_id
			request.amount = amount
			request.hit_direction = (controller.motor.global_position-projectile.global_position).normalized()
			policy.submit(request)))
	controller.shoot_ability.shot_fired.connect(func(direction: Vector2,shot_id: int) -> void:
		cases[case_index].shots.append({"frame":frame,"shot_id":shot_id,"direction":[direction.x,direction.y]}))
	setup["activate"] = encounter.activate()
	if not setup.activate: failures.append(id + ": original activation refused")
	heading.text = "%02d / %02d   %s   [ACTUAL BOSS]" % [index+1,manifest.size(),id]
	update_boss_camera(true)
	await process_frame

func update_boss_camera(immediate := false) -> void:
	# The complete arena and current whole bodies fit in the safe display band
	# y140..620. Original Boss HUD/seal labels own y0..85; capture labels use
	# y91..135 and y643..700. No new frame/viewport or actor motion is created.
	var bounds := arena_rect
	bounds = bounds.merge(Rect2(controller.motor.global_position-Vector2(36,80),Vector2(72,110)))
	var horizontal := maxf(90,encounter.definition.collision_size.x*.7)
	var upper := maxf(125,encounter.definition.collision_size.y+40)
	var lower := maxf(65,encounter.definition.collision_size.y*.6)
	bounds = bounds.merge(Rect2(motor.global_position-Vector2(horizontal,upper),Vector2(horizontal*2,upper+lower)))
	var desired_zoom := minf(1120.0/maxf(1,bounds.size.x),440.0/maxf(1,bounds.size.y))
	var desired_position := bounds.get_center()+Vector2(0,-20.0/desired_zoom)
	var weight := 1.0 if immediate else 1.0-exp(-8.0/60.0)
	camera.zoom = camera.zoom.lerp(Vector2(desired_zoom,desired_zoom),weight)
	camera.position = camera.position.lerp(desired_position,weight)

func optional_property(object: Object, property_name: StringName) -> Variant:
	if object == null: return null
	for property: Dictionary in object.get_property_list():
		if StringName(property.name) == property_name: return object.get(property_name)
	return null

func visual_receipt() -> Dictionary:
	var host := motor.get_node("Presentation") as Node2D
	var sample: EnemyFeedback01
	if host.has_meta(EnemyHitTemplate.METADATA):
		var template := host.get_meta(EnemyHitTemplate.METADATA) as EnemyHitTemplate
		if template != null: sample = template.sample
	return {"host_visible":host.is_visible_in_tree(),"host_alpha":host.modulate.a*host.self_modulate.a,"hurt_remaining":optional_property(sample,&"hurt_remaining"),"hurt_frame_index":null,"hurt_frame_index_reason":"actual Boss renderer consumes shared accepted-hit pose/tint; no exposed authored hurt cells","death_frame_index":null,"death_frame_index_reason":"original Boss terminal renderer exposes no authored corpse frame index","remains":{}}

func request_input(action: StringName,direction := Vector2.ZERO) -> void:
	var submitted := controller.router.request_action(action,direction)
	cases[index].inputs.append({"frame":frame,"local_frame":local_frame,"type":String(action),"direction":[direction.x,direction.y],"router_submitted":submitted})

func clear_body_aim() -> Dictionary:
	if encounter is ThornQueenV2: return weave_body_aim(encounter as ThornQueenV2)
	# Same six physically ray-tested body offsets as the existing successful
	# forest_depth_guardian_pilot.fire. Bell geometry remains real occlusion.
	var half := encounter.definition.collision_size*.5-Vector2(4,4)
	var offsets: Array[Vector2] = [Vector2.ZERO,Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(0,-half.y),Vector2(-half.x,half.y),Vector2(half.x,half.y)]
	if encounter is WindkeeperEncounter and (encounter as WindkeeperEncounter).continuous_combat(): offsets.push_front(Vector2(0,-95))
	if encounter is WindkeeperEncounter and not (encounter as WindkeeperEncounter).continuous_combat(): offsets = [(encounter as WindkeeperEncounter).core_offset()]
	for offset: Vector2 in offsets:
		var target := motor.global_position+offset
		var query := PhysicsRayQueryParameters2D.create(controller.motor.global_position+Vector2(0,-6),target,13,[controller.motor.get_rid()])
		query.collide_with_areas = true
		var collider: Variant = motor.get_world_2d().direct_space_state.intersect_ray(query).get("collider")
		var hits_body: bool = collider == motor or (collider is Node and motor.is_ancestor_of(collider))
		if not hits_body: continue
		if encounter is RootbellGuardianV2 and (encounter as RootbellGuardianV2).mode==&"pursuit_flight":
			var duel := encounter as RootbellGuardianV2
			var config := duel.definition as BossDuelDefinition
			var lead := minf(controller.motor.global_position.distance_to(target)/controller.motor.tuning.projectile_speed,maxf(0,config.pursuit_flight_seconds-duel._flight_age))
			target += motor.velocity*lead+Vector2(0,.5*config.pursuit_gravity*lead*lead)
		return {"target":target,"clear":true,"body_offset":[offset.x,offset.y]}
	return {"target":motor.global_position+encounter.definition.collision_offset,"clear":false,"body_offset":null}

func weave_future(queen: ThornQueenV2, seconds: float) -> Vector2:
	var at := motor.global_position
	var remaining := seconds
	if queen.motion_mode=="perched": remaining = maxf(0,remaining-queen.motion_clock-(queen.definition as ThornQueenWeaveDefinition).migration_preview_seconds)
	elif queen.motion_mode in ["migration_preview","phase_preview"]: remaining = maxf(0,remaining-queen.motion_clock)
	var path := queen.motion_path()
	for leg: int in range(queen.motion_leg,maxi(queen.motion_leg,path.size()-1)):
		var goal: Vector2 = path[leg+1]
		var duration := at.distance_to(goal)/(queen.definition as ThornQueenWeaveDefinition).migration_speed
		if remaining<=duration: return at.move_toward(goal,remaining*(queen.definition as ThornQueenWeaveDefinition).migration_speed)
		remaining -= duration
		at = goal
	return at

func clear_projectile_segment(first: Vector2,last: Vector2) -> bool:
	var circle := CircleShape2D.new()
	circle.radius = controller.shoot_ability.tuning.projectile_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0,first)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = true
	query.exclude = [controller.motor.get_rid(),motor.get_rid()]
	var space := motor.get_world_2d().direct_space_state
	if not space.intersect_shape(query,1).is_empty(): return false
	query.motion = last-first
	var sweep := space.cast_motion(query)
	return sweep.size()==2 and sweep[0]>=.99999

func weave_body_aim(queen: ThornQueenV2) -> Dictionary:
	var half := queen.definition.collision_size*.5-Vector2(2,2)
	var samples: Array[Vector2] = [Vector2.ZERO,Vector2(0,-half.y),Vector2(-half.x,0),Vector2(half.x,0),Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(-half.x,half.y),Vector2(half.x,half.y),Vector2(0,half.y)]
	var visual := controller.motor.get_node("CourierVisual") as CourierVisual
	for sample: Vector2 in samples:
		var target := motor.global_position+sample
		var aim := (target-controller.motor.global_position).normalized()
		var muzzle := visual.muzzle_position(aim)
		for unused: int in 4:
			target = weave_future(queen,muzzle.distance_to(target)/controller.shoot_ability.tuning.projectile_speed)+sample
			aim = (target-muzzle).normalized()
			muzzle = visual.muzzle_position(aim)
		if clear_projectile_segment(controller.motor.global_position,muzzle) and clear_projectile_segment(muzzle,target): return {"target":target,"clear":true,"body_offset":[sample.x,sample.y],"prediction":"actual motion_path/leg/clock, original projectile speed and swept radius"}
	return {"target":motor.global_position,"clear":false,"body_offset":null}

func rootbell_hook_input(bell: GuardianRootBellV2) -> void:
	if controller.traversal.state!=&"free" or controller.traversal.hook_used or last_hook_bell==bell.get_instance_id() or bell.state not in [&"outbound",&"returning"]: return
	var start := controller.motor.global_position+Vector2(0,-6)
	if start.distance_to(bell.global_position)>=controller.traversal.definition.hook_range-12: return
	var ray := PhysicsRayQueryParameters2D.create(start,bell.global_position,0xFFFFFFFF,[controller.motor.get_rid()])
	ray.collide_with_areas = true
	if motor.get_world_2d().direct_space_state.intersect_ray(ray).get("collider")!=bell: return
	# Existing pilot's moving target lead; no target/state/position rewrite.
	var predicted := bell.global_position
	for unused: int in 3:
		var seconds := controller.traversal.definition.hook_windup+start.distance_to(predicted)/controller.traversal.definition.hook_flight_speed
		predicted = bell.global_position+bell.velocity*seconds
		if bell.state==&"outbound": predicted += Vector2(0,.5*bell.config.bell_gravity*seconds*seconds)
	last_hook_bell = bell.get_instance_id()
	request_input(&"grapple",(predicted-start).normalized())

func windkeeper_input(boss: WindkeeperEncounter) -> float:
	# Input strategy from capture_underworld_r3_boss_fight.gd, with the same
	# real shelf positions, locked roll crossings and phase-three bridge logic.
	var player := controller.motor
	var dx := motor.global_position.x-player.global_position.x
	var grounded := player.is_on_floor()
	var axis := 0.0
	if boss is BellstriderEncounter:
		if boss.mode==&"roll" and signf(dx)==-boss.direction and absf(dx)<195 and grounded and wind_cross_axis==0:
			wind_cross_axis = -boss.direction
			wind_start_jump()
		if wind_cross_axis!=0:
			axis = wind_cross_axis
			if grounded and not wind_jump_active: wind_cross_axis = 0
		else:
			var desired := clampf(motor.global_position.x-signf(dx)*220,arena_rect.position.x+55,arena_rect.end.x-55)
			wind_desired_x = desired
			axis = clampf((desired-player.global_position.x)/45,-1,1)
		if boss.mode==&"rings" and grounded and boss.clock<.5 and not wind_jump_active:
			wind_start_jump()
	else:
		var desired := motor.global_position.x-signf(dx)*240
		if boss.stage_phase>=2 and is_instance_valid(wind_module):
			var shelf_centers: Array[float] = []
			for shelf: int in [1,2,3]: shelf_centers.append(wind_module.to_global(wind_module.definition.platforms[shelf].get_center()).x)
			# Historical core needs no rune/shore password. Keep its receiving
			# shelf instead of crossing the broken bridge to follow each pier.
			desired = wind_module.to_global(Vector2(440,452)).x
			if String(encounter.definition.resource_path).ends_with("windkeeper_storm.tres"): desired = wind_module.to_global(Vector2(920,452)).x
			if grounded and player.global_position.y>boss._floor_y-130 and not wind_jump_active:
				wind_start_jump()
		wind_desired_x = desired
		axis = clampf((desired-player.global_position.x)/45,-1,1)
		if grounded and boss.mode==&"stomp_warning" and boss.clock<.3 and not wind_jump_active:
			wind_start_jump()
		if grounded and boss.stage_phase>=2 and player.global_position.distance_to(motor.global_position)<190 and not wind_jump_active: wind_start_jump()
		if grounded and absf(axis)>.1 and not wind_jump_active:
			var ahead := player.global_position+Vector2(signf(axis)*45,17)
			var support := motor.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(ahead,ahead+Vector2(0,80),1,[player.get_rid()]))
			if support.is_empty(): wind_start_jump()
	if wind_jump_active and local_frame>=wind_jump_until:
		request_input(&"jump_release")
		wind_jump_active = false
	return axis

func wind_start_jump() -> void:
	request_input(&"jump")
	wind_jump_active = true
	wind_jump_until = local_frame+23

func drive() -> void:
	if busy: return
	frame += 1
	local_frame += 1
	var id: String = manifest[index]
	var raw_mode: Variant = optional_property(encounter,&"mode")
	var state := String(raw_mode) if raw_mode != null else ("telegraph" if encounter.pattern.telegraphing else "patrol")
	var states: Array = cases[index].states
	if states.is_empty() or states.back().state != state:
		states.append({"frame":frame,"local_frame":local_frame,"state":state})
		if state in ["pursuit_flight","roll","charge","thorn_patch","rings","lob","flight","phase_flight"]:
			cases[index].attacks.append({"frame":frame,"local_frame":local_frame,"event":"actual_original_AI_commit_state","state":state})
	var aim_receipt := clear_body_aim()
	var target: Vector2 = aim_receipt.target
	var direction := (target-controller.motor.global_position).normalized()
	controller.router.set_aim(&"gamepad",direction,false)
	var move_axis := 0.0
	var in_danger: bool = state in ["bell_watch","seed_flight","thorn_patch","pursuit_flight","roll","charge","chase","stomp","rings","lob"]
	if not encounter.health.terminal and not controller.actor_resources.health.terminal:
		if in_danger:
			move_axis = -signf(motor.global_position.x-controller.motor.global_position.x)
			if controller.motor.global_position.x < arena_rect.position.x+70: move_axis = 1
			if controller.motor.global_position.x > arena_rect.end.x-70: move_axis = -1
		if encounter is RootbellGuardianV2:
			var duel := encounter as RootbellGuardianV2
			var bell := duel._bell
			if rootbell_arrived and state not in ["pursuit_warning","pursuit_flight"]:
				var dx := motor.global_position.x-controller.motor.global_position.x
				root_direction = signf(dx) if absf(dx)>165 else 0
			if not rootbell_arrived and state in ["bell_warning","bell_watch"] and is_instance_valid(bell):
				var branch: Dictionary = geometry.side_branches[0 if bell.facing<0 else 1]
				var dx := float(branch.rect[0])+float(branch.rect[2])*.5-controller.motor.global_position.x
				root_direction = signf(dx) if absf(dx)>4 else 0
			if is_instance_valid(bell): rootbell_hook_input(bell)
			var warning := "%s/%s" % [state,duel._attack_serial]
			if state=="pursuit_warning" and warning!=last_root_warning:
				last_root_warning = warning
				root_direction = signf(controller.motor.global_position.x-duel.attack_goal.x)
				if root_direction==0: root_direction = -signf(motor.global_position.x-controller.motor.global_position.x)
				root_jump_until = local_frame+12
			if controller.motor.global_position.x<arena_rect.position.x+100: root_direction = 1
			if controller.motor.global_position.x>arena_rect.end.x-110: root_direction = -1
			move_axis = root_direction
			var desired_hold: bool = local_frame<root_jump_until
			if desired_hold!=root_jump_held:
				request_input(&"jump" if desired_hold else &"jump_release")
				root_jump_held = desired_hold
		if encounter is ThornForestEncounter and id in ["thorn_guardian","thorn_queen"] and (encounter as ThornForestEncounter).stage_phase>1:
			# The old forest gate is directional. Reach its advertised side
			# with real horizontal input rather than rewriting weak_side.
			var desired_x: float = motor.global_position.x+float((encounter as ThornForestEncounter).weak_side)*160
			if absf(desired_x-controller.motor.global_position.x)>25: move_axis = signf(desired_x-controller.motor.global_position.x)
			if controller.motor.is_on_floor() and absf(motor.global_position.x-controller.motor.global_position.x)<140 and not forest_jump_held:
				request_input(&"jump")
				forest_jump_held = true
				forest_jump_until = local_frame+23
		if forest_jump_held and local_frame>=forest_jump_until:
			request_input(&"jump_release")
			forest_jump_held = false
		if encounter is WindkeeperEncounter: move_axis = windkeeper_input(encounter as WindkeeperEncounter)
		# Original recoil remains active. Walk inward early enough that a real
		# shot cannot push the player off the edge of the initial arena floor.
		if not encounter is RootbellGuardianV2:
			if controller.motor.global_position.x<arena_rect.position.x+165: move_axis = 1
			if controller.motor.global_position.x>arena_rect.end.x-165: move_axis = -1
		var jump_needed: bool = id not in ["thorn_guardian","thorn_queen"] and not encounter is RootbellGuardianV2 and not encounter is WindkeeperEncounter and (local_frame-last_attack_frame in range(12,22) or in_danger) and controller.motor.is_on_floor() and local_frame-last_jump_frame>65
		if jump_needed:
			request_input(&"jump")
			last_jump_frame = local_frame
		if local_frame-last_jump_frame == 12: request_input(&"jump_release")
	controller.router.set_source_axis(&"gamepad",move_axis)
	var accepted_attack: bool = not cases[index].attacks.is_empty()
	var recovered_shot_cadence: bool = first_hit_frame>=0 and frame-first_hit_frame>100
	var shot_clock_ready: bool = (controller.shoot_ability.cooldown_remaining<=0 and controller.shoot_ability.rounds_remaining==0) if recovered_shot_cadence else local_frame-last_shot_frame>=100
	var queued_jump: bool = encounter is WindkeeperEncounter and wind_jump_active
	var fire_grounded: bool = controller.motor.is_on_floor() and not queued_jump
	var actual_recoil_distance: float = controller.motor.weapon_motion.base_distance(controller.motor.tuning,fire_grounded)
	var predicted_recoil_x: float = controller.motor.global_position.x+controller.motor.velocity.x/60.0-direction.x*actual_recoil_distance+controller.motor.normal_velocity.x*.06
	if not encounter is WindkeeperEncounter or encounter is BellstriderEncounter: predicted_recoil_x = controller.motor.global_position.x-direction.x*105
	var recoil_stays_inside: bool = predicted_recoil_x>=arena_rect.position.x+30 and predicted_recoil_x<=arena_rect.end.x-30
	var terrain_blocked: bool = not bool(aim_receipt.clear)
	var original_receiver_direction_allowed := true
	if id in ["thorn_guardian","thorn_queen"]:
		var forest := encounter as ThornForestEncounter
		original_receiver_direction_allowed = forest.core_open and forest.accepts_core_direction({"amount":1.0,"hit_direction":direction})
	if encounter is WindkeeperEncounter and not (encounter as WindkeeperEncounter).continuous_combat():
		var wind := encounter as WindkeeperEncounter
		original_receiver_direction_allowed = wind.core_open and wind.accepts_core_direction({"amount":1.0,"hit_direction":direction})
	var wind_reposition_fire_hold := false
	if encounter is WindkeeperEncounter and not encounter is BellstriderEncounter and (encounter as WindkeeperEncounter).stage_phase>=2:
		var wind := encounter as WindkeeperEncounter
		var shelf: Rect2 = wind_module.definition.platforms[3 if id=="windkeeper_storm" else 1]
		var expected_full_foot: bool = predicted_recoil_x-12>=shelf.position.x+2 and predicted_recoil_x+12<=shelf.end.x-2
		var support_ray := PhysicsRayQueryParameters2D.create(Vector2(predicted_recoil_x,shelf.position.y-3),Vector2(predicted_recoil_x,shelf.position.y+5),1,[controller.motor.get_rid(),motor.get_rid()])
		var support := motor.get_world_2d().direct_space_state.intersect_ray(support_ray)
		var actual_support: bool = not support.is_empty() and support.get("collider") is StaticBody2D and (support.normal as Vector2).y<-.5
		wind_reposition_fire_hold = not expected_full_foot or not actual_support or controller.motor.global_position.y+18>shelf.position.y+2 or controller.motor.recoil_burst_remaining>0
	var commitment_clearance := true
	if encounter is RootbellGuardianV2 and state in ["pursuit_warning","pursuit_flight"]:
		commitment_clearance = controller.motor.global_position.distance_to((encounter as RootbellGuardianV2).attack_goal-Vector2(0,18))>=encounter.definition.collision_size.x+24
	if encounter is BellstriderEncounter and wind_cross_axis!=0 and signf(motor.global_position.x-controller.motor.global_position.x)==wind_cross_axis: commitment_clearance = false
	if local_frame>=210 and accepted_attack and shot_clock_ready and recoil_stays_inside and commitment_clearance and original_receiver_direction_allowed and not wind_reposition_fire_hold and not terrain_blocked and not controller.traversal.busy() and controller.traversal.state!=&"hook_kick" and not encounter.health.terminal and not controller.actor_resources.health.terminal:
		request_input(&"shoot_release",direction)
		last_shot_frame = local_frame
	var visual := visual_receipt()
	update_boss_camera()
	rows.append({"frame":frame,"sampling_phase":"SceneTree.process_frame_before_node_process","movie_process_frame":Engine.get_process_frames(),"case":index,"local_frame":local_frame,"camera_position":[camera.position.x,camera.position.y],"camera_zoom":camera.zoom.x,"camera_safe_screen_y":[140,620],"player_position":[controller.motor.global_position.x,controller.motor.global_position.y],"player_velocity":[controller.motor.velocity.x,controller.motor.velocity.y],"enemy_position":[motor.global_position.x,motor.global_position.y],"enemy_velocity":[motor.velocity.x,motor.velocity.y],"HP":encounter.health.current,"player_HP":controller.actor_resources.health.current,"state":state,"stage_phase":optional_property(encounter,&"stage_phase"),"weak_side":optional_property(encounter,&"weak_side"),"core_open":optional_property(encounter,&"core_open"),"aim_terrain_blocked":terrain_blocked,"aim_target":[target.x,target.y],"original_receiver_direction_allowed":original_receiver_direction_allowed,"wind_reposition_fire_hold":wind_reposition_fire_hold,"pilot_axis":move_axis,"predicted_recoil_inside_arena":recoil_stays_inside,"visual":visual})
	if first_hit_frame>=0 and not encounter.health.terminal and frame-first_hit_frame>=30 and visual.hurt_remaining != null and float(visual.hurt_remaining)<=0: cases[index].coverage["recovered_after_nonlethal"] = true
	detail.text = "AI: %s   BOSS HP: %.0f / %.0f   PLAYER HP: %.0f   SHOTS: %d   %.1fs | %s" % [state.to_upper(),encounter.health.current,encounter.health.capacity,controller.actor_resources.health.current,cases[index].shots.size(),float(local_frame)/60,"TERMINAL OBSERVATION / original exit policy" if encounter.health.terminal else "REAL AIM / EVADE INPUT"]
	var finished := death_frame>=0 and frame-death_frame>=HOLD_FRAMES and local_frame>=600
	var player_out := controller.motor.global_position.y>arena_rect.end.y+250
	# The combat budget remains 3600 frames. A death already committed within
	# that bound gets its original 210-frame observation, without more combat.
	var combat_budget_exhausted: bool = local_frame>=MAX_FRAMES and death_frame<0
	var absolute_budget_exhausted: bool = local_frame>=MAX_FRAMES+HOLD_FRAMES
	if finished or combat_budget_exhausted or absolute_budget_exhausted or ((controller.actor_resources.health.terminal or player_out) and local_frame>=600):
		if player_out: cases[index].coverage_gaps.append("player left supported arena through real motion")
		busy = true
		finish_case.call_deferred()

func capture_post_draw() -> void:
	if rows.is_empty() or not is_instance_valid(motor) or not motor.is_inside_tree(): return
	var row: Dictionary = rows.back()
	if int(row.case) != index: return
	row["visual_after_draw"] = visual_receipt()
	row["movie_process_frame_after_draw"] = Engine.get_process_frames()
	row["visual_after_draw_sampling_phase"] = "RenderingServer.frame_post_draw_read_only"

func finish_case() -> void:
	await RenderingServer.frame_post_draw
	var result: Dictionary = cases[index]
	result["end_frame"] = frame
	result["end_seconds"] = float(Engine.get_process_frames())/60
	result["movie_end_process_frame"] = Engine.get_process_frames()
	result["post_death_observation_frames"] = frame-death_frame if death_frame>=0 else 0
	var states: Array[String] = []
	for row: Dictionary in result.states: states.append(row.state)
	var warning := false
	var physical_attack: bool = not result.attacks.is_empty()
	var migration := false
	for state: String in states:
		if "warning" in state or "preview" in state or state == "telegraph": warning = true
		if state in ["pursuit_flight","roll","charge","thorn_patch","rings","lob"]: physical_attack = true
		if state in ["migrating","migration","flight","fly","perch_flight"]: migration = true
	var coverage: Dictionary = result.coverage
	coverage["actual_AI_commitment"] = physical_attack or migration
	coverage["nonlethal_HP_commit"] = first_hit_frame>=0
	coverage["recovered_after_nonlethal"] = coverage.get("recovered_after_nonlethal",false)
	coverage["lethal_HP_commit"] = encounter.health.terminal and result.deaths==1
	coverage["terminal_observed_210_frames"] = death_frame>=0 and frame-death_frame>=HOLD_FRAMES
	coverage["player_damage_authority_registered"] = true
	coverage["player_survived"] = not controller.actor_resources.health.terminal
	coverage["warning"] = "observed" if warning else "missing_or_species_internal_field"
	coverage["persistent_remains"] = "not_required_original_boss_policy"
	var moved := false
	var spawn := point(result.fixture.boss_spawn)
	for row: Dictionary in rows:
		if row.case==index and point(row.enemy_position).distance_to(spawn)>3: moved = true
	coverage["locomotion"] = "observed" if moved else "no_body_translation_observed"
	result["terminal_policy_observation"] = {"policy":"original Boss body/exit; no added ordinary corpse","terminal":encounter.health.terminal,"final_visual":visual_receipt(),"observation_frames":result.post_death_observation_frames}
	for key: String in ["actual_AI_commitment","nonlethal_HP_commit","recovered_after_nonlethal","lethal_HP_commit","terminal_observed_210_frames","player_survived"]:
		if not coverage[key]: result.coverage_gaps.append(key)
	controller.shoot_ability.clear_projectiles()
	fixture.queue_free()
	await process_frame
	await process_frame
	index += 1
	if index>=manifest.size(): await finish()
	else:
		await make_case()
		busy = false

func finish() -> void:
	if process_frame.is_connected(drive): process_frame.disconnect(drive)
	if RenderingServer.frame_post_draw.is_connected(capture_post_draw): RenderingServer.frame_post_draw.disconnect(capture_post_draw)
	var sound_events: Dictionary = audio.played.duplicate(true)
	if not await audio.shutdown(): failures.append("GameAudio ownership did not release")
	var gaps := 0
	for result: Dictionary in cases: gaps += result.coverage_gaps.size()
	var output := {"task":"ENEMY-ALL-02","complete":cases.size()==manifest.size(),"seed_label":seed_label,"group":"boss","chains":"actual","frames":rows,"cases":cases,"failures":failures,"coverage_gap_count":gaps,"audio_events":sound_events,"conditions":{"fps":60,"resolution":[1280,720],"playback_speed":1,"max_case_frames":MAX_FRAMES+HOLD_FRAMES,"combat_frame_budget":MAX_FRAMES,"absolute_frame_budget":MAX_FRAMES+HOLD_FRAMES,"terminal_hold_frames":HOLD_FRAMES,"source_HP_state_AI_injection":false,"scope":"Explicit actual arena/initial spawn, original Boss AI and receiver gates, real input and player damage. Default Windkeeper and formal storm are distinct cases."},"not_verified":["natural campaign route","physical device performance","human visual approval"]}
	var file := FileAccess.open(trace_path,FileAccess.WRITE)
	if file == null:
		printerr("Cannot write complete Boss capture trace")
		quit(1)
		return
	file.store_string(JSON.stringify(output,"\t"))
	file.close()
	world.free()
	await process_frame
	await process_frame
	print("ENEMY ALL REVIEW 02: complete; cases=%d; frames=%d; coverage_gaps=%d" % [cases.size(),frame,gaps])
	quit(0 if failures.is_empty() else 1)
