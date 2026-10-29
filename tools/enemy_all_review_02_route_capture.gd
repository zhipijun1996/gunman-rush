extends SceneTree
## Continuous actual generated stage from its original spawn. Real route input;
## no target fixtures, actor reset/teleport, forced AI/HP or map mutation.
const STARTUP_FRAME_BUDGET := 3600
var trace_path := ""
var group := "route_plains"
var seed_label := "enemy-all-review-02-route"
var route_seconds := 45
var app: DemoApp
var audio: GameAudio
var heading: Label
var detail: Label
var frames: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var failures: Array[String] = []
var frame := 0
var gameplay_frame := 0
var terminal_frame := -1
var last_shot := -1000
var last_jump := -1000
var ready := false
var busy := false
var manifest_at_start := ""
var watched: Dictionary = {}

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--trace="): trace_path = argument.trim_prefix("--trace=")
		if argument.begins_with("--group="): group = argument.trim_prefix("--group=")
		if argument.begins_with("--seed="): seed_label = argument.trim_prefix("--seed=")
		if argument.begins_with("--seconds="): route_seconds = clampi(int(argument.trim_prefix("--seconds=")),15,120)
	start.call_deferred()

func make_label(text_value: String,position: Vector2,font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = position
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_outline_color",Color("10201d"))
	label.add_theme_constant_override("outline_size",4)
	return label

func start() -> void:
	root.size = Vector2i(1280,720)
	audio = GameAudio.new()
	root.add_child(audio)
	app = DemoApp.new()
	# Do not write a review run into the user's permanent local save. All
	# in-run economy, manifest, rewards, combat and map persistence are real.
	app.meta_persistence_enabled = false
	root.add_child(app)
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	root.add_child(overlay)
	heading = make_label("ENEMY ALL 02 / ACTUAL FORMAL STAGE / CONTINUOUS INPUT",Vector2(25,14),19)
	overlay.add_child(heading)
	detail = make_label("",Vector2(25,42),15)
	overlay.add_child(detail)
	overlay.add_child(make_label("Original stage spawn / terrain / AI / HUD / camera / HP / damage / drops. Automated Router input; no actor placement.",Vector2(25,688),14))
	var forest := group == "route_forest"
	var started := app.start_debug_region(&"thorn_forest",1,seed_label) if forest else app.start_plains(seed_label)
	if not started: failures.append("Original run entry refused")
	cases.append({"case":0,"id":"formal_forest_map1_debug_entry" if forest else "formal_plains_map1_default_entry","definition":"actual generated manifest","definition_path":"actual stage enemy definitions in inventory","scene":"res://scenes/demo/demo.tscn","chain":"actual_DemoApp_generated_stage","renderer":"actual installed stage/player/enemy renderers and original StageCameraRig","start_frame":1,"start_seconds":float(Engine.get_process_frames())/60,"movie_start_process_frame":Engine.get_process_frames(),"fixture":{"production_AI_enabled":true,"actor_positioning":"none; original generated spawn","entry":"start_debug_region(thorn_forest,map1)" if forest else "start_plains","natural_progression":not forest,"differences":["automated gamepad Router input replaces KeyboardMouseAdapter","permanent meta persistence disabled for review run"],"debug_region_admission":forest},"inventory":[],"events":[],"player_events":[],"inputs":[],"shots":[],"states":[],"deaths":0,"coverage":{},"coverage_gaps":[]})
	process_frame.connect(drive)

func optional_property(object: Object,property_name: StringName) -> Variant:
	if object == null: return null
	for property: Dictionary in object.get_property_list():
		if StringName(property.name)==property_name: return object.get(property_name)
	return null

func is_ready() -> bool:
	return not app._stage_pending and is_instance_valid(app.stage) and is_instance_valid(app.controller) and app._can_interact()

func observe_actor(motor: EnemyMotor) -> void:
	var actor := motor.get_node("Actor") as EnemyActor
	var key := String(motor.get_path())+":"+str(actor.health.epoch)
	if watched.has(key): return
	watched[key] = true
	var host := motor.get_node_or_null("Presentation")
	var renderer := (host.get_script() as Script).resource_path if host != null else "missing"
	cases[0].inventory.append({"id":key,"definition":String(actor.definition.stable_id),"behavior":String(actor.definition.behavior_id),"renderer":renderer,"initial_position":[motor.global_position.x,motor.global_position.y],"HP":actor.health.current,"actual_AI_enabled":actor.is_physics_processing()})
	actor.health.changed.connect(func(result: ActorResourceResult) -> void:
		if result.operation==&"damage" and result.status==ActorResourceResult.Status.APPLIED:
			cases[0].events.append({"frame":frame,"target":key,"definition":String(actor.definition.stable_id),"event_id":String(result.event_id),"amount":result.amount_applied,"HP":result.snapshot.current,"epoch":result.snapshot.epoch,"terminal":result.snapshot.terminal}))
	actor.defeated.connect(func(_dead: EnemyActor) -> void: cases[0].deaths += 1)

func observe_stage() -> void:
	if not is_instance_valid(app.stage): return
	for child: Node in app.stage.find_children("*","",true,false):
		if child is EnemyMotor: observe_actor(child as EnemyMotor)

func request_input(action: StringName,direction := Vector2.ZERO) -> void:
	var accepted := app.controller.router.request_action(action,direction)
	cases[0].inputs.append({"frame":frame,"local_frame":gameplay_frame,"type":String(action),"direction":[direction.x,direction.y],"router_submitted":accepted})

func drive() -> void:
	if busy: return
	frame += 1
	if not ready and is_ready():
		ready = true
		app.player.get_node("KeyboardMouseAdapter").process_mode = Node.PROCESS_MODE_DISABLED
		app.controller.router.activate_device(&"gamepad")
		app.controller.shoot_ability.shot_fired.connect(func(direction: Vector2,id: int) -> void:
			cases[0].shots.append({"frame":frame,"shot_id":id,"direction":[direction.x,direction.y],"player_position":[app.player.global_position.x,app.player.global_position.y]}))
		app.controller.actor_resources.health.changed.connect(func(result: ActorResourceResult) -> void:
			if result.operation==&"damage" and result.status==ActorResourceResult.Status.APPLIED:
				cases[0].player_events.append({"frame":frame,"amount":result.amount_applied,"HP":result.snapshot.current,"event_id":String(result.event_id),"terminal":result.snapshot.terminal})
				if result.snapshot.terminal and terminal_frame<0: terminal_frame = frame)
		if app.stage is GeneratedDemoStage:
			manifest_at_start = JSON.stringify((app.stage as GeneratedDemoStage).generated.manifest)
		cases[0].fixture["initial_player_position"] = [app.player.global_position.x,app.player.global_position.y]
		cases[0].fixture["manifest_at_start_sha256"] = manifest_at_start.sha256_text()
		cases[0].fixture["ready_at_movie_process_frame"] = Engine.get_process_frames()
		observe_stage()
	var target: EnemyMotor
	var target_actor: EnemyActor
	var target_distance := INF
	var visible_enemies: Array[Dictionary] = []
	var player_position := Vector2.ZERO
	var hp := -1.0
	var state := "loading_original_stage"
	if ready and is_instance_valid(app.player) and is_instance_valid(app.controller):
		gameplay_frame += 1
		player_position = app.player.global_position
		hp = app.controller.actor_resources.health.current
		state = "original_run_terminal" if hp<=0 or not app.lifetime.active else "natural_route_input"
		if is_instance_valid(app.stage):
			for child: Node in app.stage.find_children("*","",true,false):
				var motor := child as EnemyMotor
				if motor == null: continue
				var actor := motor.get_node("Actor") as EnemyActor
				var distance := motor.global_position.distance_to(player_position)
				if distance<=750:
					visible_enemies.append({"id":String(actor.definition.stable_id),"position":[motor.global_position.x,motor.global_position.y],"HP":actor.health.current,"state":String(actor.attack_behavior.state) if actor.attack_behavior != null else "patrol"})
				if not actor.health.terminal and distance<target_distance and absf(motor.global_position.x-player_position.x)<600:
					target = motor
					target_actor = actor
					target_distance = distance
		if app._can_interact() and not app.controller.actor_resources.health.terminal:
			var axis := 1.0
			var aim := Vector2.RIGHT
			if target != null:
				aim = (target.global_position+target.velocity*minf(.15,target_distance/700)-player_position).normalized()
				if target_distance<180: axis = 0
				if target_distance<70: axis = -signf(target.global_position.x-player_position.x)
				if gameplay_frame-last_shot>=60:
					request_input(&"shoot_release",aim)
					last_shot = gameplay_frame
			app.controller.router.set_aim(&"gamepad",aim,false)
			app.controller.router.set_source_axis(&"gamepad",axis)
			var space := app.player.get_world_2d().direct_space_state
			var wall := space.intersect_ray(PhysicsRayQueryParameters2D.create(player_position,player_position+Vector2(48,0),1,[app.player.get_rid()]))
			var ahead := player_position+Vector2(45,17)
			var floor := space.intersect_ray(PhysicsRayQueryParameters2D.create(ahead,ahead+Vector2(0,75),1,[app.player.get_rid()]))
			var attack_close: bool = target_actor != null and target_actor.attack_behavior != null and target_actor.attack_behavior.state in [&"attack",&"hold"] and target_distance<140
			if app.player.is_on_floor() and gameplay_frame-last_jump>70 and (not wall.is_empty() or floor.is_empty() or attack_close or gameplay_frame%150==0):
				request_input(&"jump")
				last_jump = gameplay_frame
			if gameplay_frame-last_jump==14: request_input(&"jump_release")
		else:
			app.controller.router.set_source_axis(&"gamepad",0)
	if terminal_frame<0 and ready and (not is_instance_valid(app.controller) or not app.lifetime.active): terminal_frame = frame
	frames.append({"frame":frame,"sampling_phase":"SceneTree.process_frame_before_node_process","movie_process_frame":Engine.get_process_frames(),"case":0,"local_frame":gameplay_frame,"ready":ready,"player_position":[player_position.x,player_position.y],"player_HP":hp,"state":state,"enemies":visible_enemies})
	detail.text = "%s / %s / %.1fs gameplay / %d actual HP commits / %d deaths\n%s" % [group,seed_label,float(gameplay_frame)/60,cases[0].events.size(),cases[0].deaths,"DEBUG MAP ENTRY; original map/spawn; no natural cross-region progression claim" if group=="route_forest" else "DEFAULT FORMAL ENTRY; original spawn; genuine walking, jumping and shooting"]
	if (not ready and frame>=STARTUP_FRAME_BUDGET) or gameplay_frame>=route_seconds*60 or (terminal_frame>=0 and frame-terminal_frame>=210):
		busy = true
		finish.call_deferred()

func finish() -> void:
	process_frame.disconnect(drive)
	var result: Dictionary = cases[0]
	result["end_frame"] = frame
	result["end_seconds"] = float(Engine.get_process_frames())/60
	result["movie_end_process_frame"] = Engine.get_process_frames()
	result["post_death_observation_frames"] = frame-terminal_frame if terminal_frame>=0 else 0
	var manifest_same := true
	if ready and is_instance_valid(app.stage) and app.stage is GeneratedDemoStage: manifest_same = JSON.stringify((app.stage as GeneratedDemoStage).generated.manifest)==manifest_at_start
	result.coverage["formal_stage_ready"] = ready
	result.coverage["actual_enemy_HP_commits"] = result.events.size()
	result.coverage["actual_enemy_deaths"] = result.deaths
	result.coverage["original_manifest_unchanged"] = manifest_same
	result.coverage["natural_player_spawn"] = true
	result.coverage["gameplay_seconds"] = float(gameplay_frame)/60
	result.coverage["human_visual_review"] = "pending"
	if not ready: result.coverage_gaps.append("formal stage did not become ready")
	if result.events.is_empty(): result.coverage_gaps.append("no enemy accepted damage encountered on this actual route")
	if not manifest_same: failures.append("Production manifest changed during route recording")
	result["terminal_policy_observation"] = {"policy":"actual generated stage and original run result","player_terminal_frame":terminal_frame,"scope":"continuous actual traversal; no all-roster or completed-campaign claim"}
	# Cleanup starts only after the recorded gameplay/terminal observation.
	app.abandon_run()
	if not await load("res://tests/audio_teardown.gd").drain_world(app): failures.append("Original DemoApp fallback audio failed to release")
	var sound_events: Dictionary = audio.played.duplicate(true)
	if not await audio.shutdown(): failures.append("GameAudio ownership did not release")
	var output := {"task":"ENEMY-ALL-02","complete":true,"seed_label":seed_label,"group":group,"frames":frames,"cases":cases,"failures":failures,"coverage_gap_count":result.coverage_gaps.size(),"audio_events":sound_events,"conditions":{"fps":60,"resolution":[1280,720],"playback_speed":1,"original_stage_camera":true,"actor_positioning":false,"source_HP_state_AI_injection":false,"scope":"Actual generated formal stage from original spawn with continuous Router input; forest direct debug entry is explicitly labelled when selected."},"not_verified":["full campaign completion","all species on this route","physical device performance","human visual approval"]}
	var file := FileAccess.open(trace_path,FileAccess.WRITE)
	if file == null:
		printerr("Cannot write actual formal-route trace")
		quit(1)
		return
	file.store_string(JSON.stringify(output,"\t"))
	file.close()
	app.free()
	audio.free()
	await process_frame
	await process_frame
	print("ENEMY ALL REVIEW 02: complete; cases=1; frames=%d; coverage_gaps=%d" % [frame,result.coverage_gaps.size()])
	quit(0 if failures.is_empty() else 1)
