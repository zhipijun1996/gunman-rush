extends SceneTree
## Actual MovieMaker chapters. Only initial fixtures are authored here.
## No HP/state writes, target teleports, AI suspension or damageable shortcuts.
const PLAINS: Array[String] = ["patrol_drone", "plains_charger", "plains_diver", "plains_hopper", "plains_sentry", "plains_fan_sentry", "plains_root_bell"]
const FOREST: Array[String] = ["forest_bark_beetle", "forest_swing_pod", "forest_lantern", "forest_seed_sentry", "forest_thread_spider", "forest_crossbranch", "forest_bible_weaver"]
const PROTOTYPES: Array[String] = ["candidate_lure_guard", "candidate_crosswind_moth"]
const INSTALLER := preload("res://game/presentation/actors/underworld_plains/underworld_actor_installer.gd")
const MAX_CASE_FRAMES := 1200
const HOLD_FRAMES := 210
var trace_path := ""
var group := "plains"
var chains := "primary"
var only_species := ""
var seed_label := "enemy-all-review-02"
var require_remains := false
var world: Node2D
var fixture: Node2D
var camera: Camera2D
var controller: PlayerController
var enemy: EnemyMotor
var actor: EnemyActor
var policy: FrameDamagePolicy
var audio: GameAudio
var heading: Label
var detail: Label
var manifest: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var rows: Array[Dictionary] = []
var failures: Array[String] = []
var index := 0
var frame := 0
var local_frame := 0
var last_shot_frame := -1000
var death_frame := -1
var first_hit_frame := -1
var settled_frame := -1
var persistent_remains_component := false
var attack_seen := false
var busy := false

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--trace="): trace_path = argument.trim_prefix("--trace=")
		if argument.begins_with("--group="): group = argument.trim_prefix("--group=")
		if argument.begins_with("--chains="): chains = argument.trim_prefix("--chains=")
		if argument.begins_with("--species="): only_species = argument.trim_prefix("--species=")
		if argument.begins_with("--seed="): seed_label = argument.trim_prefix("--seed=")
		if argument == "--require-remains": require_remains = true
	start.call_deferred()

func make_label(value: String, point: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = point
	label.add_theme_font_size_override("font_size", font_size)
	return label

func start() -> void:
	root.size = Vector2i(1280, 720)
	var selected: Array[String] = []
	if group in ["plains", "all"]: selected.append_array(PLAINS)
	if group in ["forest", "all"]: selected.append_array(FOREST)
	if group in ["prototypes", "all"]: selected.append_array(PROTOTYPES)
	for id: String in selected:
		if not only_species.is_empty() and id != only_species: continue
		var primary := "underworld" if id in PLAINS else "scene"
		manifest.append({"id": id, "chain": primary})
		if chains == "all" and id in PLAINS:
			manifest.append({"id": id, "chain": "scene"})
			if id == "plains_root_bell": manifest.append({"id": id, "chain": "root_bell"})
	if manifest.is_empty():
		printerr("Empty or unsupported roster selection: ", group, "/", only_species)
		quit(1)
		return
	world = Node2D.new()
	root.add_child(world)
	audio = GameAudio.new()
	world.add_child(audio)
	camera = Camera2D.new()
	camera.position = Vector2(610, 425)
	camera.zoom = Vector2(1.75, 1.75)
	world.add_child(camera)
	var overlay := CanvasLayer.new()
	world.add_child(overlay)
	heading = make_label("", Vector2(36, 30), 27)
	overlay.add_child(heading)
	detail = make_label("", Vector2(36, 73), 18)
	overlay.add_child(detail)
	overlay.add_child(make_label("ENEMY ALL 02 / ACTUAL GODOT / 60 FPS / NORMAL SPEED / STEREO", Vector2(36, 642), 18))
	overlay.add_child(make_label("Explicit initial arena fixture. Original definitions / AI / HP / weapon / player damage. Not a natural campaign route.", Vector2(36, 674), 15))
	await make_case()
	process_frame.connect(drive)
	RenderingServer.frame_post_draw.connect(capture_post_draw)

func solid(rect: Rect2, color: Color, support_id: String) -> void:
	var body := StaticBody2D.new()
	body.name = support_id
	body.position = rect.get_center()
	body.set_meta("support_world_rect", rect)
	body.set_meta("support_ids", [support_id])
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	var pixels := Polygon2D.new()
	pixels.polygon = PackedVector2Array([-rect.size*.5, Vector2(rect.size.x*.5,-rect.size.y*.5), rect.size*.5, Vector2(-rect.size.x*.5,rect.size.y*.5)])
	pixels.color = color
	body.add_child(pixels)
	fixture.add_child(body)

func make_case() -> void:
	local_frame = 0
	last_shot_frame = -1000
	death_frame = -1
	first_hit_frame = -1
	settled_frame = -1
	persistent_remains_component = false
	attack_seen = false
	var id: String = manifest[index].id
	fixture = Node2D.new()
	fixture.name = "Fixture_%02d_%s" % [index, id]
	# Same formal forest actor-art selection as the generated forest stage.
	# Omitting this selects its fallback renderer despite the same scene name.
	if id in FOREST: fixture.set_meta(&"forest_bible_actor_art",true)
	world.add_child(fixture)
	var geometry: Array[Dictionary] = []
	var floor_rect := Rect2(200,500,1050,40)
	geometry.append({"id":"floor","rect":[200,500,1050,40]})
	solid(floor_rect, Color("45564b"), "floor")
	# Bounding walls are real collision, outside all authored attack envelopes.
	solid(Rect2(200,270,20,230), Color("283a38"), "left_boundary")
	solid(Rect2(1230,270,20,230), Color("283a38"), "right_boundary")
	var enemy_spawn := Vector2(660,484)
	var player_spawn := Vector2(510,482)
	if id in ["forest_thread_spider", "forest_bible_weaver"]:
		enemy_spawn = Vector2(660,486)
	if id == "forest_crossbranch":
		# Two supported authored endpoints. Initial actor position is exact;
		# subsequent travel/landing belongs exclusively to its real behavior.
		var first := Rect2(580,500,150,40)
		var second := Rect2(800,440,150,30)
		solid(second,Color("657257"),"upper_shore")
		geometry.append({"id":"shore_a","rect":[580,500,150,40]})
		geometry.append({"id":"shore_b","rect":[800,440,150,30]})
		enemy_spawn = Vector2(650,484)
		# Starting on a separate raised observation ledge gives real shots a
		# clear line to both endpoint bodies without moving either actor later.
		solid(Rect2(365,440,180,30),Color("657257"),"player_ledge")
		geometry.append({"id":"player_ledge","rect":[365,440,180,30]})
		player_spawn = Vector2(470,422)
	var player: PlayerMotor = preload("res://game/player/player.tscn").instantiate()
	player.position = player_spawn
	fixture.add_child(player)
	controller = player.get_node("Controller") as PlayerController
	# The physical adapter is replaced by this explicit input driver. The
	# controller, Router, abilities, resources and physics remain enabled.
	player.get_node("KeyboardMouseAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	controller.router.activate_device(&"gamepad")
	var scene_path := EnemyBehaviorRegistry.scene_path(StringName(id) if id in FOREST else &"patrol")
	enemy = (load(scene_path) as PackedScene).instantiate() as EnemyMotor
	actor = enemy.get_node("Actor") as EnemyActor
	var definition_path := "res://resources/enemies/%s.tres" % id
	if id in PROTOTYPES:
		# Same candidate recipe as ModuleEnemyPrototypes.setup, not a new
		# production definition or invented extra-HP review target.
		var moth := id == "candidate_crosswind_moth"
		definition_path = "res://resources/enemies/plains_sentry.tres" if moth else "res://resources/enemies/plains_charger.tres"
		actor.definition = (load(definition_path) as EnemyDefinition).duplicate(true) as EnemyDefinition
		actor.definition.stable_id = StringName(id)
		actor.definition.aerial = moth
		actor.definition.collision_size = Vector2(32,36)
		actor.definition.patrol_half_width = 120
		if moth: actor.definition.patrol_speed = 45
		actor.definition.telegraph_duration = .8
		actor.definition.attack_duration = 1.1 if moth else .65
		actor.definition.recovery_duration = 1.1
		actor.definition.activation_range = 360
		var receiver := PrototypeEnemyDamageable.new()
		receiver.guard = not moth
		enemy.get_node("Damageable").free()
		receiver.name = "Damageable"
		enemy.add_child(receiver)
		actor.damageable = receiver
		enemy.get_node("Presentation").free()
		var art := PrototypeEnemyPresentation.new()
		art.actor = actor
		art.moth = moth
		art.name = "Presentation"
		enemy.add_child(art)
	else:
		actor.definition = load(definition_path) as EnemyDefinition
	if actor.definition.aerial: enemy_spawn.y = 405
	if id == "plains_diver": enemy_spawn.y = 434
	if not actor.definition.aerial: enemy_spawn.y = 500 - actor.definition.collision_size.y*.5
	enemy.position = enemy_spawn
	fixture.add_child(enemy)
	var chain: String = manifest[index].chain
	if chain == "underworld":
		var installed: Dictionary = INSTALLER.install(fixture)
		if installed.enemies != 1: failures.append(id + ": formal installer rejected fixture")
	elif chain == "root_bell":
		enemy.get_node("Presentation").free()
		var root_bell := RootBellPresentation.new()
		root_bell.name = "Presentation"
		root_bell.actor = actor
		enemy.add_child(root_bell)
	if id in FOREST:
		# Current formal bodies use the explicit binding installed by
		# ForestBibleActors, rather than ancestor metadata alone.
		fixture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var forest_host := enemy.get_node("Presentation")
		var binding := EnemyPresentationBinding.bind_existing(actor, forest_host, &"forest", &"forest_bible")
		if binding.is_empty() or binding.get("body_theme") != &"forest_bible":
			failures.append(id + ": current formal forest body binding rejected")
	policy = FrameDamagePolicy.new()
	policy.lifetime = DemoLifetime.new()
	fixture.add_child(policy)
	policy.register_player_controller(controller)
	if not policy.register_target(&"player", controller.actor_resources.health, true): failures.append(id + ": player registration failed")
	if not policy.bind_damageable(&"review_enemy", actor.damageable, actor.health): failures.append(id + ": enemy registration failed")
	if id in PROTOTYPES:
		actor.attack_behavior = PrototypeMothBehavior.new() if id == "candidate_crosswind_moth" else EnemyAttackBehavior.new()
		actor.add_child(actor.attack_behavior)
		actor.attack_behavior.configure(actor,controller,policy,policy.lifetime,&"review_enemy",[])
	else:
		actor.bind_encounter(controller,policy,policy.lifetime,&"review_enemy",[])
	var setup: Dictionary = {}
	if actor.attack_behavior is ForestCrossbranchBehavior:
		var shores: Array[Dictionary] = [{"id":"lower","rect":Rect2(580,500,150,40),"position":Vector2(650,484)}, {"id":"upper","rect":Rect2(800,440,150,30),"position":Vector2(870,424)}]
		setup = {"interface":"configure_shores","accepted":(actor.attack_behavior as ForestCrossbranchBehavior).configure_shores(shores),"positions":[[650,484],[870,424]]}
	elif actor.attack_behavior is ForestBibleWeaverBehavior:
		var strands: Array = [{"id":"upper","start":[600,420],"end":[700,420]}, {"id":"lower","start":[600,470],"end":[700,470]}]
		setup = {"interface":"configure_strands","strands":strands,"accepted":(actor.attack_behavior as ForestBibleWeaverBehavior).configure_strands(strands)}
	elif actor.attack_behavior is ForestThreadSpiderBehavior:
		setup = {"interface":"configure_line","start":[600,470],"end":[700,470],"accepted":(actor.attack_behavior as ForestThreadSpiderBehavior).configure_line(Vector2(600,470),Vector2(700,470))}
	if not setup.is_empty() and not setup.accepted: failures.append(id + ": authored host configuration rejected")
	var contact := DemoContactEmitter.new()
	contact.policy = policy
	contact.controller = controller
	contact.source_id = &"review_enemy_contact"
	contact.half_size = actor.definition.collision_size*.5
	enemy.add_child(contact)
	actor.defeated.connect(func(_dead: EnemyActor) -> void: contact.enabled = false)
	var case_index := index
	var presentation := enemy.get_node("Presentation")
	persistent_remains_component = optional_property(presentation,&"feedback_remains") is Node2D
	var remains_owner: Variant = optional_property(presentation,&"feedback_remains")
	if remains_owner is PlainsRevisionRemains:
		persistent_remains_component = (remains_owner as PlainsRevisionRemains).keeps_corpse()
	cases.append({"case":index,"id":id,"definition":String(actor.definition.stable_id),"definition_path":definition_path,"scene":scene_path,"chain":chain,"renderer":(presentation.get_script() as Script).resource_path,"start_frame":frame+1,"start_seconds":float(Engine.get_process_frames()+1)/60,"active_start_seconds":float(frame)/60,"movie_start_process_frame":Engine.get_process_frames()+1,"fixture":{"geometry":geometry,"player_spawn":[player_spawn.x,player_spawn.y],"enemy_spawn":[enemy_spawn.x,enemy_spawn.y],"host_configuration":setup,"player_health":controller.actor_resources.health.current,"enemy_health":actor.health.current,"forest_bible_actor_art":id in FOREST,"body_theme":String(EnemyPresentationBinding.view(presentation).get("body_theme",&"")),"differences":["explicit initial geometry and spawn","automated gamepad input replaces KeyboardMouseAdapter"],"production_AI_enabled":actor.is_physics_processing()},"events":[],"player_events":[],"inputs":[],"shots":[],"states":[],"deaths":0,"coverage":{},"coverage_gaps":[]})
	cases[case_index]["actual_strand_holds"] = []
	cases[case_index]["strand_hold_events"] = []
	cases[case_index]["persistent_remains_component"] = persistent_remains_component
	actor.health.changed.connect(func(result: ActorResourceResult) -> void:
		if result.operation == &"damage" and result.status == ActorResourceResult.Status.APPLIED:
			cases[case_index].events.append({"frame":frame,"local_frame":local_frame,"event_id":String(result.event_id),"amount":result.amount_applied,"HP":result.snapshot.current,"epoch":result.snapshot.epoch,"terminal":result.snapshot.terminal})
			if not result.snapshot.terminal and first_hit_frame < 0: first_hit_frame = frame
			if result.snapshot.terminal: death_frame = frame)
	controller.actor_resources.health.changed.connect(func(result: ActorResourceResult) -> void:
		if result.operation == &"damage" and result.status == ActorResourceResult.Status.APPLIED:
			cases[case_index].player_events.append({"frame":frame,"amount":result.amount_applied,"HP":result.snapshot.current,"event_id":String(result.event_id),"terminal":result.snapshot.terminal}))
	actor.defeated.connect(func(_dead: EnemyActor) -> void: cases[case_index].deaths += 1)
	controller.shoot_ability.shot_fired.connect(func(direction: Vector2, shot_id: int) -> void:
		cases[case_index].shots.append({"frame":frame,"shot_id":shot_id,"direction":[direction.x,direction.y]}))
	heading.text = "%02d / %02d   %s   [%s]" % [index+1,manifest.size(),id,chain]
	update_camera(true)
	await process_frame

func update_camera(immediate := false) -> void:
	# Camera observes real actor motion. Keep the player, full authored patrol /
	# dive / swing envelope and currently committed destination in the frame.
	# Camera changes never move an actor or alter its collision/AI trajectory.
	var player_position := controller.motor.global_position
	var enemy_position := enemy.global_position
	var bounds := Rect2(player_position-Vector2(35,80),Vector2(70,110))
	bounds = bounds.merge(Rect2(enemy_position-Vector2(55,100),Vector2(110,140)))
	var behavior := actor.attack_behavior
	if behavior != null and not actor.health.terminal:
		var radius := actor.definition.patrol_half_width
		var rise := 100.0
		var forest_rise: Variant = optional_property(actor.definition,&"swing_rise")
		if forest_rise != null: rise = maxf(rise,float(forest_rise)+50)
		bounds = bounds.merge(Rect2(behavior.home-Vector2(radius+55,rise),Vector2(radius*2+110,rise+actor.definition.dive_depth+65)))
		# Only these three original behaviors actually author attack_goal as
		# their movement commitment. Lantern inherits an unused (0,0) field;
		# its full home +/- patrol envelope already covers both destinations.
		if actor.definition.behavior_id in [&"charger",&"diver",&"hopper"] and behavior.state in [&"telegraph",&"attack"]:
			bounds = bounds.expand(behavior.attack_goal+Vector2(0,-45))
		if behavior is ForestCrossbranchBehavior:
			for shore: Dictionary in (behavior as ForestCrossbranchBehavior).shores:
				bounds = bounds.expand(shore.position-Vector2(0,75))
	var desired_zoom := clampf(minf(1100.0/maxf(1,bounds.size.x),480.0/maxf(1,bounds.size.y)),1.4,2.8)
	var desired_center := bounds.get_center()+Vector2(0,10)
	var smoothing := 1.0 if immediate else 1.0-exp(-7.0/60.0)
	camera.position = camera.position.lerp(desired_center,smoothing)
	camera.zoom = camera.zoom.lerp(Vector2(desired_zoom,desired_zoom),smoothing)

func optional_property(object: Object, property_name: StringName) -> Variant:
	if object == null: return null
	for property: Dictionary in object.get_property_list():
		if StringName(property.name) == property_name: return object.get(property_name)
	return null

func visual_receipt() -> Dictionary:
	var host := enemy.get_node("Presentation") as Node2D
	var sample: Variant = optional_property(host,&"feedback_sample")
	if sample == null and host.has_meta(EnemyHitTemplate.METADATA):
		var template := host.get_meta(EnemyHitTemplate.METADATA) as EnemyHitTemplate
		if template != null: sample = template.sample
	var owned: Variant = optional_property(host,&"feedback_remains")
	var remains: Dictionary = {}
	if owned is Node2D:
		var body := owned as Node2D
		var alpha := body.self_modulate.a
		var parent: Node = body
		while parent != null:
			if parent is CanvasItem: alpha *= (parent as CanvasItem).modulate.a
			parent = parent.get_parent()
		remains = {"visible":body.is_visible_in_tree(),"alpha":alpha,"position":[body.global_position.x,body.global_position.y],"rotation":body.global_rotation,"scale":[body.global_scale.x,body.global_scale.y],"settled":optional_property(body,&"settled"),"frame_index":optional_property(body,&"frame_index")}
	var host_index: Variant = optional_property(host,&"feedback_frame_index")
	var hurt_remaining: Variant = optional_property(sample,&"hurt_remaining")
	var hurt_index: Variant = host_index if host_index is int and host_index >= 0 and hurt_remaining != null and float(hurt_remaining)>0 else null
	var death_index: Variant = remains.get("frame_index",null)
	var motion: Variant = optional_property(host,&"body_motion")
	var motion_receipt: Dictionary = {}
	if motion is Object:
		for key: StringName in [&"clock",&"stride",&"tension",&"release",&"recovery",&"travel"]:
			var value: Variant = optional_property(motion,key)
			if value != null: motion_receipt[String(key)] = value
	return {"host_visible":host.is_visible_in_tree(),"host_alpha":host.modulate.a*host.self_modulate.a,"hurt_remaining":hurt_remaining,"host_feedback_frame_index":host_index,"host_feedback_frame_index_source":"Presentation.feedback_frame_index" if host_index != null else "not exposed by this species renderer; procedural/shared hit pose has no authored frame index","hurt_frame_index":hurt_index,"hurt_frame_index_reason":"Presentation.feedback_frame_index during accepted hurt" if hurt_index != null else ("not currently in an authored hurt frame" if host_index != null else "renderer does not expose authored hurt cells"),"death_frame_index":death_index,"death_frame_index_reason":"Presentation.feedback_remains.frame_index" if death_index != null else "original species terminal renderer has no exposed authored corpse cell","body_motion":motion_receipt,"remains":remains}

func drive() -> void:
	if busy: return
	frame += 1
	local_frame += 1
	# Observe the completed previous render without advancing the component.
	# Only species that already own persistent remains acquire a settled hold.
	if persistent_remains_component and settled_frame<0 and death_frame>=0 and not rows.is_empty():
		var previous: Dictionary = rows.back()
		if int(previous.case)==index and previous.has("visual_after_draw"):
			var remains: Dictionary = previous.visual_after_draw.remains
			if not remains.is_empty() and bool(remains.get("settled",false)) and bool(remains.get("visible",false)) and float(remains.get("alpha",0))>.05:
				settled_frame = int(previous.frame)
	var id: String = manifest[index].id
	var behavior := actor.attack_behavior
	var state := String(behavior.state) if behavior != null else "patrol"
	var strand_id := ""
	var strand_index := -1
	if behavior is ForestBibleWeaverBehavior:
		var weaver := behavior as ForestBibleWeaverBehavior
		strand_index = weaver.strand_index
		if strand_index>=0 and strand_index<weaver.strand_rows.size(): strand_id = String(weaver.strand_rows[strand_index].id)
	var states: Array = cases[index].states
	if states.is_empty() or states.back().state != state:
		states.append({"frame":frame,"local_frame":local_frame,"state":state,"strand_id":strand_id if not strand_id.is_empty() else null,"strand_index":strand_index if strand_index>=0 else null})
	if state=="hold" and not strand_id.is_empty() and not cases[index].actual_strand_holds.has(strand_id):
		cases[index].actual_strand_holds.append(strand_id)
		cases[index].strand_hold_events.append({"frame":frame,"local_frame":local_frame,"strand_id":strand_id,"strand_index":strand_index,"source":"actual ForestBibleWeaverBehavior.state + strand_index + strand_rows[index].id"})
	if state in ["attack","hold","flight","travel","swing"]: attack_seen = true
	var contact_only: bool = id in ["patrol_drone","forest_lantern","forest_swing_pod","forest_crossbranch"]
	var initial: Vector2 = Vector2(cases[index].fixture.enemy_spawn[0],cases[index].fixture.enemy_spawn[1])
	if contact_only and enemy.global_position.distance_to(initial)>3: attack_seen = true
	var direction := (enemy.global_position-controller.motor.global_position).normalized()
	controller.router.set_aim(&"gamepad", direction, false)
	var move_axis := 0.0
	# Preserve the actual shield. Cross the guard with real jump/move input;
	# never change its facing or accept a front hit artificially.
	if id == "forest_bark_beetle" and not actor.health.terminal and local_frame > 160:
		if actor.brain.direction < 0 and controller.motor.global_position.x < enemy.global_position.x+55:
			move_axis = 1.0
			if controller.motor.is_on_floor() and absf(enemy.global_position.x-controller.motor.global_position.x)<110:
				request_input(&"jump",Vector2.ZERO)
	if controller.motor.global_position.x < 300: move_axis = 1.0
	if controller.motor.global_position.x > 1120: move_axis = -1.0
	controller.router.set_source_axis(&"gamepad",move_axis)
	var ready_to_shoot := attack_seen and local_frame >= 210 and local_frame-last_shot_frame >= 100
	if id=="forest_bible_weaver":
		ready_to_shoot = ready_to_shoot and cases[index].actual_strand_holds.has("upper") and cases[index].actual_strand_holds.has("lower")
	# Guard candidate's ordinary front shots are accepted only in its original
	# recovery window. Waiting for that AI window does not alter its state.
	if id == "candidate_lure_guard" and state != "recovery": ready_to_shoot = false
	if ready_to_shoot and not actor.health.terminal and not controller.actor_resources.health.terminal:
		request_input(&"shoot_release",direction)
		last_shot_frame = local_frame
	var visual := visual_receipt()
	update_camera()
	rows.append({"frame":frame,"sampling_phase":"SceneTree.process_frame_before_node_process","movie_process_frame":Engine.get_process_frames(),"case":index,"local_frame":local_frame,"strand_id":strand_id if not strand_id.is_empty() else null,"strand_index":strand_index if strand_index>=0 else null,"camera_position":[camera.position.x,camera.position.y],"camera_zoom":camera.zoom.x,"player_position":[controller.motor.global_position.x,controller.motor.global_position.y],"player_velocity":[controller.motor.velocity.x,controller.motor.velocity.y],"enemy_position":[enemy.global_position.x,enemy.global_position.y],"enemy_velocity":[enemy.velocity.x,enemy.velocity.y],"HP":actor.health.current,"player_HP":controller.actor_resources.health.current,"state":state,"visual":visual})
	if first_hit_frame >= 0 and not actor.health.terminal and frame-first_hit_frame >= 30 and visual.hurt_remaining != null and float(visual.hurt_remaining) <= 0:
		cases[index].coverage["recovered_after_nonlethal"] = true
	detail.text = "AI: %s   PLAYER HP: %.0f   SHOTS: %d   %.1fs\n%s" % [state.to_upper(),controller.actor_resources.health.current,cases[index].shots.size(),float(local_frame)/60,"TERMINAL OBSERVATION / actual death policy" if actor.health.terminal else ("COMBAT / real Router shots" if attack_seen else "OBSERVE / wait for actual AI commitment")]
	var finished := death_frame >= 0 and frame-death_frame >= HOLD_FRAMES and local_frame >= 540
	if persistent_remains_component: finished = finished and settled_frame>=0 and frame-settled_frame>=HOLD_FRAMES
	# MAX_CASE_FRAMES is the combat bound. Accepted deaths retain their full
	# observed terminal hold; no case can exceed MAX_CASE_FRAMES+HOLD_FRAMES.
	var combat_budget_exhausted: bool = local_frame>=MAX_CASE_FRAMES and death_frame<0
	var absolute_budget_exhausted: bool = local_frame>=MAX_CASE_FRAMES+HOLD_FRAMES
	if finished or combat_budget_exhausted or absolute_budget_exhausted or (controller.actor_resources.health.terminal and local_frame >= 540):
		busy = true
		finish_case.call_deferred()

func request_input(action: StringName, direction: Vector2) -> void:
	var submitted := controller.router.request_action(action,direction)
	cases[index].inputs.append({"frame":frame,"local_frame":local_frame,"type":String(action),"direction":[direction.x,direction.y],"router_submitted":submitted})

func capture_post_draw() -> void:
	# Read-only renderer receipt after this movie frame has actually drawn.
	# Never advances a clock, samples AI intent or submits input/damage.
	if rows.is_empty() or not is_instance_valid(enemy) or not enemy.is_inside_tree(): return
	var row: Dictionary = rows.back()
	if int(row.case) != index: return
	row["sampling_phase"] = "SceneTree.process_frame_before_node_process"
	row["visual_after_draw"] = visual_receipt()
	row["movie_process_frame_after_draw"] = Engine.get_process_frames()
	row["visual_after_draw_sampling_phase"] = "RenderingServer.frame_post_draw_read_only"

func finish_case() -> void:
	# Preserve the last case image through its actual draw before teardown.
	await RenderingServer.frame_post_draw
	var result: Dictionary = cases[index]
	result["end_frame"] = frame
	result["end_seconds"] = float(Engine.get_process_frames())/60
	result["active_end_seconds"] = float(frame)/60
	result["movie_end_process_frame"] = Engine.get_process_frames()
	result["post_death_observation_frames"] = frame-death_frame if death_frame >= 0 else 0
	result["first_settled_post_draw_frame"] = settled_frame if settled_frame>=0 else null
	result["post_settled_observation_frames"] = frame-settled_frame if settled_frame>=0 else 0
	var coverage: Dictionary = result.coverage
	coverage["actual_AI_commitment"] = attack_seen
	coverage["nonlethal_HP_commit"] = first_hit_frame >= 0
	coverage["recovered_after_nonlethal"] = coverage.get("recovered_after_nonlethal",false)
	coverage["lethal_HP_commit"] = actor.health.terminal and result.deaths == 1
	coverage["terminal_observed_210_frames"] = death_frame >= 0 and frame-death_frame >= HOLD_FRAMES
	coverage["player_damage_authority_registered"] = true
	coverage["player_survived"] = not controller.actor_resources.health.terminal
	var observed_states: Array[String] = []
	for state_row: Dictionary in result.states: observed_states.append(state_row.state)
	var id: String = result.id
	if id=="forest_bible_weaver":
		coverage["authored_attack_variants"] = {"expected":["upper","lower"],"actual_hold_ids":result.actual_strand_holds,"source":"real state/strand_index/strand_rows, not a requested transition"}
		if not result.actual_strand_holds.has("upper") or not result.actual_strand_holds.has("lower"): result.coverage_gaps.append("both authored upper/lower holds not observed")
	var no_warning: bool = id in ["patrol_drone","forest_swing_pod"]
	coverage["warning"] = "not_applicable_contact_only" if no_warning else ("observed" if "telegraph" in observed_states else "missing")
	if not no_warning and "telegraph" not in observed_states: result.coverage_gaps.append("no actual telegraph observed")
	var initial: Vector2 = Vector2(result.fixture.enemy_spawn[0],result.fixture.enemy_spawn[1])
	var travelled := false
	var case_rows: Array[Dictionary] = []
	for row: Dictionary in rows:
		if row.case != index: continue
		case_rows.append(row)
		if Vector2(row.enemy_position[0],row.enemy_position[1]).distance_to(initial)>3: travelled = true
	var rooted: bool = actor.definition.behavior_id in [&"sentry",&"fan_sentry",&"root_bell",&"forest_seed_sentry",&"forest_thread_spider",&"forest_bible_weaver"] and id != "candidate_crosswind_moth"
	coverage["locomotion"] = "not_applicable_rooted_definition" if rooted else ("observed" if travelled else "missing")
	if not rooted and not travelled: result.coverage_gaps.append("no physical locomotion observed")
	var corpse_tail := true
	var stationary := true
	var anchor: Dictionary = {}
	var sampled := 0
	for row: Dictionary in case_rows:
		if row.frame <= frame-HOLD_FRAMES: continue
		sampled += 1
		var remains: Dictionary = row.visual.remains
		if remains.is_empty() or not remains.get("visible",false) or float(remains.get("alpha",0))<=.05:
			corpse_tail = false
			continue
		if anchor.is_empty(): anchor = remains
		elif remains.position != anchor.position or remains.rotation != anchor.rotation or remains.scale != anchor.scale: stationary = false
	result["terminal_policy_observation"] = {"visible_corpse_tail":corpse_tail and sampled==HOLD_FRAMES,"stationary_corpse_tail":corpse_tail and stationary and sampled==HOLD_FRAMES,"sampled_tail_frames":sampled,"final_visual":case_rows.back().visual,"interpretation":"Observed component/body visibility; human visual review remains pending."}
	coverage["persistent_remains"] = corpse_tail and stationary and sampled==HOLD_FRAMES
	if persistent_remains_component:
		coverage["settled_remains_observed_210_frames"] = settled_frame>=0 and frame-settled_frame>=HOLD_FRAMES
		if not coverage.settled_remains_observed_210_frames: result.coverage_gaps.append("persistent remains did not settle before a continuous 210-frame hold")
		if not coverage.persistent_remains: result.coverage_gaps.append("required persistent remains missing or moving in final 210 frames")
	for key: String in ["actual_AI_commitment","nonlethal_HP_commit","recovered_after_nonlethal","lethal_HP_commit","terminal_observed_210_frames","player_survived"]:
		if not coverage[key]: result.coverage_gaps.append(key)
	if require_remains and not coverage.persistent_remains: result.coverage_gaps.append("persistent_remains required but not observed")
	controller.shoot_ability.clear_projectiles()
	fixture.queue_free()
	await process_frame
	await process_frame
	index += 1
	if index >= manifest.size():
		await finish()
	else:
		await make_case()
		busy = false

func finish() -> void:
	process_frame.disconnect(drive)
	if RenderingServer.frame_post_draw.is_connected(capture_post_draw): RenderingServer.frame_post_draw.disconnect(capture_post_draw)
	var sound_events: Dictionary = audio.played.duplicate(true)
	if not await audio.shutdown(): failures.append("GameAudio ownership did not release")
	var gaps := 0
	for result: Dictionary in cases: gaps += result.coverage_gaps.size()
	var output := {"task":"ENEMY-ALL-02","complete":true,"seed_label":seed_label,"group":group,"chains":chains,"frames":rows,"cases":cases,"failures":failures,"coverage_gap_count":gaps,"audio_events":sound_events,"conditions":{"fps":60,"resolution":[1280,720],"playback_speed":1,"camera":{"mode":"smooth observed player/enemy/complete authored attack envelope","zoom_bounds":[1.4,2.8],"camera_state_recorded_per_frame":true},"max_case_frames":MAX_CASE_FRAMES+HOLD_FRAMES,"combat_frame_budget":MAX_CASE_FRAMES,"absolute_frame_budget":MAX_CASE_FRAMES+HOLD_FRAMES,"terminal_hold_frames":HOLD_FRAMES,"source_HP_state_AI_injection":false,"scope":"Explicit initial fixture, genuine Godot AI/InputRouter/projectile/damage. Not natural formal campaign traversal."},"not_verified":["natural campaign route","physical device performance","human visual approval"]}
	var file := FileAccess.open(trace_path,FileAccess.WRITE)
	if file == null:
		printerr("Cannot write complete capture trace: ",trace_path)
		quit(1)
		return
	file.store_string(JSON.stringify(output,"\t"))
	file.close()
	world.free()
	await process_frame
	await process_frame
	print("ENEMY ALL REVIEW 02: complete; cases=%d; frames=%d; coverage_gaps=%d" % [cases.size(),frame,gaps])
	quit(0 if failures.is_empty() else 1)
