extends "res://tools/enemy_all_review_02_route_capture.gd"
## Original generated stage and existing enemy. Exactly one disclosed initial
## player review stand; thereafter only real Router input and production policy.
var only_species := ""
var review_enemy: EnemyMotor
var review_actor: EnemyActor
var review_identity := ""
var review_stand := Vector2.ZERO
var initial_player_reset := false
var initial_spawn := Vector2.ZERO
var target_death_frame := -1
var first_nonlethal_frame := -1
var target_attack_seen := false
var target_recovered := false
var jump_release_frame := -1
var initial_search: Array[Dictionary] = []

func _initialize() -> void:
	group = "formal_plains"
	route_seconds = 30
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--trace="): trace_path = argument.trim_prefix("--trace=")
		if argument.begins_with("--group="): group = argument.trim_prefix("--group=")
		if argument.begins_with("--seed="): seed_label = argument.trim_prefix("--seed=")
		if argument.begins_with("--species="): only_species = argument.trim_prefix("--species=")
		if argument.begins_with("--seconds="): route_seconds = clampi(int(argument.trim_prefix("--seconds=")),15,30)
	if group not in ["formal_plains","formal_forest"]:
		printerr("Expected formal_plains or formal_forest")
		quit(1)
		return
	start.call_deferred()

func start() -> void:
	root.size = Vector2i(1280,720)
	audio = GameAudio.new()
	root.add_child(audio)
	app = DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	root.add_child(overlay)
	# Bottom edge only: production top HUD and central foot/contact area remain
	# unobscured. No review camera, world label or replacement HUD is installed.
	heading = make_label("INITIAL REVIEW STAND / ORIGINAL FORMAL STAGE / NOT NATURAL ROUTE",Vector2(12,698),12)
	overlay.add_child(heading)
	detail = make_label("Loading original DemoApp stage; one safe initial player stand only",Vector2(12,680),12)
	overlay.add_child(detail)
	var forest := group == "formal_forest"
	var started := app.start_debug_region(&"thorn_forest",1,seed_label) if forest else app.start_plains(seed_label)
	if not started: failures.append("Original run entry refused")
	cases.append({"case":0,"id":"formal_forest_initial_review_stand" if forest else "formal_plains_initial_review_stand","definition":"actual existing generated enemy; selection pending","definition_path":"actual stage enemy definitions in inventory","scene":"res://game/application/demo.tscn","chain":"actual_DemoApp_generated_stage","renderer":"original stage-installed renderer and StageCameraRig","start_frame":1,"start_seconds":float(Engine.get_process_frames())/60,"movie_start_process_frame":Engine.get_process_frames(),"fixture":{"production_AI_enabled":true,"initial_player_reset":false,"false_natural_spawn":true,"natural_player_spawn":false,"natural_progression":false,"entry":"start_debug_region(thorn_forest,map1)" if forest else "start_plains","actor_positioning":"at most one initial player reset_at onto existing physically verified safe static support; no enemy placement","differences":["one disclosed initial player review stand","automated gamepad Router replaces keyboard/mouse adapter","permanent meta persistence disabled for review run"],"debug_region_admission":forest},"inventory":[],"events":[],"target_events":[],"player_events":[],"inputs":[],"shots":[],"states":[],"deaths":0,"coverage":{},"coverage_gaps":[]})
	process_frame.connect(drive)

func all_actual_enemies() -> Array[EnemyMotor]:
	var enemies: Array[EnemyMotor] = []
	if not is_instance_valid(app.stage): return enemies
	for child: Node in app.stage.find_children("*","",true,false):
		if child is EnemyMotor: enemies.append(child as EnemyMotor)
	return enemies

func safe_stand_near(motor: EnemyMotor) -> Dictionary:
	var collision := app.player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or not collision.shape is RectangleShape2D: return {}
	var rectangle := collision.shape as RectangleShape2D
	var space := app.player.get_world_2d().direct_space_state
	for distance: float in [128.0,160.0,96.0,192.0]:
		for side: float in [-1.0,1.0]:
			var x := motor.global_position.x+side*distance
			var ray := PhysicsRayQueryParameters2D.create(Vector2(x,motor.global_position.y-128),Vector2(x,motor.global_position.y+224),app.player.collision_mask,[app.player.get_rid(),motor.get_rid()])
			var ground := space.intersect_ray(ray)
			if ground.is_empty() or not ground.collider is StaticBody2D or (ground.normal as Vector2).dot(Vector2.UP)<0.7: continue
			# Match the real player's rectangle and its local shape offset.
			var location := (ground.position as Vector2)-collision.position-Vector2(0,rectangle.size.y*0.5)
			if app.segment == null or not app.segment.is_safe(location): continue
			var shape_query := PhysicsShapeQueryParameters2D.new()
			shape_query.shape = rectangle
			shape_query.transform = Transform2D(0.0,location+collision.position-Vector2(0,0.05))
			shape_query.collision_mask = app.player.collision_mask
			shape_query.exclude = [app.player.get_rid()]
			shape_query.margin = 0.0
			if not space.intersect_shape(shape_query).is_empty(): continue
			var nearby_danger := false
			var clearance := Rect2(location-rectangle.size*0.5-Vector2(16,4),rectangle.size+Vector2(32,8))
			for danger: Rect2 in app.segment.danger_bounds:
				if danger.intersects(clearance,true): nearby_danger = true
			if nearby_danger: continue
			var lane := PhysicsRayQueryParameters2D.create(location,motor.global_position,app.player.collision_mask,[app.player.get_rid(),motor.get_rid()])
			if not space.intersect_ray(lane).is_empty(): continue
			# Recoil must have actual safe terrain to recover on; do not invent
			# a platform, move support, or accept a mere central ray over a ledge.
			if not app.segment.is_safe(location+Vector2(-32,0)) or not app.segment.is_safe(location+Vector2(32,0)): continue
			var isolated := true
			for other: EnemyMotor in all_actual_enemies():
				if other!=motor and not (other.get_node("Actor") as EnemyActor).health.terminal and other.global_position.distance_to(location)<60: isolated = false
			if not isolated: continue
			return {"location":location,"support_path":String((ground.collider as Node).get_path()),"support_point":ground.position,"support_normal":ground.normal,"offset":side*distance,"shape_size":rectangle.size,"checks":"StaticBody2D UP ray + actual RectangleShape2D clearance + SegmentRespawn.is_safe including danger bounds and three foot rays + hazard margin + unobstructed target lane + supported recoil corridor"}
	return {}

func select_initial_review_stand() -> void:
	initial_spawn = app.player.global_position
	var priorities: Array[String] = []
	priorities.assign(["forest_lantern","forest_bark_beetle"] if group=="formal_forest" else ["plains_charger","plains_diver"])
	if not only_species.is_empty(): priorities.assign([only_species])
	for ident: String in priorities:
		for motor: EnemyMotor in all_actual_enemies():
			var actor := motor.get_node("Actor") as EnemyActor
			if String(actor.definition.stable_id)!=ident or actor.health.terminal: continue
			var found := safe_stand_near(motor)
			initial_search.append({"definition":ident,"enemy_path":String(motor.get_path()),"enemy_position":[motor.global_position.x,motor.global_position.y],"safe_stand_found":not found.is_empty()})
			if found.is_empty(): continue
			review_enemy = motor
			review_actor = actor
			review_identity = String(motor.get_path())+":"+str(actor.health.epoch)
			review_stand = found.location
			app.controller.router.clear("enemy_all_02_disclosed_initial_review_stand")
			app.player.reset_at(review_stand)
			initial_player_reset = true
			cases[0].definition = ident
			cases[0].fixture["initial_player_reset"] = true
			cases[0].fixture["initial_natural_spawn_position"] = [initial_spawn.x,initial_spawn.y]
			cases[0].fixture["review_stand"] = [review_stand.x,review_stand.y]
			cases[0].fixture["selected_enemy"] = review_identity
			cases[0].fixture["selected_enemy_initial_position"] = [motor.global_position.x,motor.global_position.y]
			cases[0].fixture["support"] = {"path":found.support_path,"point":[found.support_point.x,found.support_point.y],"normal":[found.support_normal.x,found.support_normal.y],"horizontal_offset":found.offset,"actual_player_shape_size":[found.shape_size.x,found.shape_size.y],"checks":found.checks}
			actor.health.changed.connect(func(result: ActorResourceResult) -> void:
				if result.operation!=&"damage" or result.status!=ActorResourceResult.Status.APPLIED: return
				cases[0].target_events.append({"frame":frame,"local_frame":gameplay_frame,"event_id":String(result.event_id),"amount":result.amount_applied,"HP":result.snapshot.current,"epoch":result.snapshot.epoch,"terminal":result.snapshot.terminal})
				if result.snapshot.terminal:
					if target_death_frame<0: target_death_frame = frame
				elif result.amount_applied<0 and first_nonlethal_frame<0: first_nonlethal_frame = frame)
			return
	cases[0].fixture["initial_search"] = initial_search
	cases[0].coverage_gaps.append("No existing preferred enemy with a verified safe supported initial review stand; no reset, spawn or fallback terrain fabricated")

func target_visual() -> Dictionary:
	var result := {"hurt_remaining":null,"hurt_frame":null,"body_visible":false,"remains_active":false,"remains_settled":false,"remains_visible":false}
	if not is_instance_valid(review_enemy): return result
	var host := review_enemy.get_node_or_null("Presentation") as Node2D
	if host == null: return result
	result.body_visible = host.is_visible_in_tree()
	result.hurt_frame = optional_property(host,&"feedback_frame_index")
	var sample := optional_property(host,&"feedback_sample") as EnemyFeedback01
	if sample == null:
		var hit := host.get_meta(EnemyHitTemplate.METADATA) as EnemyHitTemplate if host.has_meta(EnemyHitTemplate.METADATA) else null
		if is_instance_valid(hit): sample = hit.sample
	if sample != null: result.hurt_remaining = sample.hurt_remaining
	var remains := optional_property(host,&"feedback_remains") as Node2D
	if is_instance_valid(remains):
		result.remains_active = optional_property(remains,&"active")
		result.remains_settled = optional_property(remains,&"settled")
		result.remains_visible = remains.is_visible_in_tree()
	return result

func safe_router_movement(axis: float) -> float:
	if is_zero_approx(axis) or not app.player.is_on_floor(): return axis
	if app.segment == null or not app.segment.is_safe(app.player.global_position+Vector2(axis*28,0)): return 0.0
	return axis

func drive() -> void:
	if busy: return
	frame += 1
	if not ready and is_ready():
		ready = true
		app.player.get_node("KeyboardMouseAdapter").process_mode = Node.PROCESS_MODE_DISABLED
		app.controller.router.activate_device(&"gamepad")
		app.controller.shoot_ability.shot_fired.connect(func(direction: Vector2,id: int) -> void: cases[0].shots.append({"frame":frame,"shot_id":id,"direction":[direction.x,direction.y],"player_position":[app.player.global_position.x,app.player.global_position.y]}))
		app.controller.actor_resources.health.changed.connect(func(result: ActorResourceResult) -> void:
			if result.operation==&"damage" and result.status==ActorResourceResult.Status.APPLIED:
				cases[0].player_events.append({"frame":frame,"amount":result.amount_applied,"HP":result.snapshot.current,"event_id":String(result.event_id),"terminal":result.snapshot.terminal})
				if result.snapshot.terminal and terminal_frame<0: terminal_frame = frame)
		if app.stage is GeneratedDemoStage: manifest_at_start = JSON.stringify((app.stage as GeneratedDemoStage).generated.manifest)
		cases[0].fixture["manifest_at_start_sha256"] = manifest_at_start.sha256_text()
		cases[0].fixture["ready_at_movie_process_frame"] = Engine.get_process_frames()
		observe_stage()
		select_initial_review_stand()
	var player_position := Vector2.ZERO
	var hp := -1.0
	var state := "loading_original_formal_stage"
	var visible_enemies: Array[Dictionary] = []
	var visual := target_visual()
	if ready and is_instance_valid(app.player) and is_instance_valid(app.controller):
		gameplay_frame += 1
		player_position = app.player.global_position
		hp = app.controller.actor_resources.health.current
		state = "no_verified_initial_stand" if not initial_player_reset else "original_formal_combat"
		for motor: EnemyMotor in all_actual_enemies():
			var actor := motor.get_node("Actor") as EnemyActor
			if motor.global_position.distance_to(player_position)<750:
				visible_enemies.append({"id":String(actor.definition.stable_id),"position":[motor.global_position.x,motor.global_position.y],"HP":actor.health.current,"state":String(actor.attack_behavior.state) if actor.attack_behavior!=null else "patrol"})
		var target_alive := is_instance_valid(review_actor) and not review_actor.health.terminal
		if is_instance_valid(review_actor):
			state = String(review_actor.attack_behavior.state) if review_actor.attack_behavior!=null else "patrol"
			var states: Array = cases[0].states
			if states.is_empty() or states.back().state!=state: states.append({"frame":frame,"local_frame":gameplay_frame,"state":state})
			if state in ["attack","travel","hold","extend","flight"]: target_attack_seen = true
			if first_nonlethal_frame>=0 and target_alive and frame-first_nonlethal_frame>=30 and visual.hurt_remaining!=null and float(visual.hurt_remaining)<=0: target_recovered = true
		if app._can_interact() and not app.controller.actor_resources.health.terminal and initial_player_reset:
			var axis := 0.0
			if target_alive and is_instance_valid(review_enemy):
				var target_distance := player_position.distance_to(review_enemy.global_position)
				var aim := (review_enemy.global_position+review_enemy.velocity*minf(0.16,target_distance/maxf(app.player.tuning.projectile_speed,1.0))-player_position).normalized()
				app.controller.router.set_aim(&"gamepad",aim,false)
				# Counter real recoil using movement, never a second placement.
				var return_offset := review_stand.x-player_position.x
				if absf(return_offset)>9: axis = signf(return_offset)
				var behavior := review_actor.attack_behavior
				var warning_late: bool = behavior!=null and state=="telegraph" and behavior.state_time>review_actor.definition.telegraph_duration*0.55
				var close_attack := target_distance<150 and state in ["attack","hold","extend"]
				var shielded := review_actor.definition.stable_id==&"forest_bark_beetle"
				if app.player.is_on_floor() and gameplay_frame-last_jump>75 and (warning_late or close_attack or (shielded and target_attack_seen and gameplay_frame-last_shot>70)):
					app.controller.router.set_jump_held(&"gamepad",true)
					cases[0].inputs.append({"frame":frame,"local_frame":gameplay_frame,"type":"jump_held","value":true})
					last_jump = gameplay_frame
					jump_release_frame = gameplay_frame+18
				# Let one real attack play before firing. Distinct shots are100
				# frames apart so actual nonlethal hurt can finish before lethal.
				var recovery_observed := first_nonlethal_frame<0 or target_recovered
				if target_attack_seen and gameplay_frame>=150 and gameplay_frame-last_shot>=100 and recovery_observed:
					request_input(&"shoot_release",aim)
					last_shot = gameplay_frame
			app.controller.router.set_source_axis(&"gamepad",safe_router_movement(axis))
			if jump_release_frame>=0 and gameplay_frame>=jump_release_frame:
				app.controller.router.set_jump_held(&"gamepad",false)
				cases[0].inputs.append({"frame":frame,"local_frame":gameplay_frame,"type":"jump_held","value":false})
				jump_release_frame = -1
		else:
			app.controller.router.set_source_axis(&"gamepad",0.0)
			app.controller.router.set_jump_held(&"gamepad",false)
	if terminal_frame<0 and ready and not app.lifetime.active: terminal_frame = frame
	frames.append({"frame":frame,"sampling_phase":"SceneTree.process_frame_before_node_process","movie_process_frame":Engine.get_process_frames(),"case":0,"local_frame":gameplay_frame,"ready":ready,"player_position":[player_position.x,player_position.y],"player_HP":hp,"state":state,"enemies":visible_enemies,"target":review_identity,"target_HP":review_actor.health.current if is_instance_valid(review_actor) else null,"visual":visual,"camera_position":[app._run_camera.global_position.x,app._run_camera.global_position.y] if is_instance_valid(app._run_camera) else null})
	detail.text = "%s / %s / %s / %.1fs / %d target HP commits / original HUD + camera" % [group,cases[0].definition,state,float(gameplay_frame)/60,cases[0].target_events.size()]
	if (not ready and frame>=STARTUP_FRAME_BUDGET) or gameplay_frame>=route_seconds*60 or (target_death_frame>=0 and frame-target_death_frame>=210) or (terminal_frame>=0 and frame-terminal_frame>=210):
		busy = true
		finish.call_deferred()

func finish() -> void:
	await RenderingServer.frame_post_draw
	process_frame.disconnect(drive)
	var result: Dictionary = cases[0]
	result["end_frame"] = frame
	result["end_seconds"] = float(Engine.get_process_frames())/60
	result["movie_end_process_frame"] = Engine.get_process_frames()
	result["post_death_observation_frames"] = frame-target_death_frame if target_death_frame>=0 else 0
	result.fixture["initial_search"] = initial_search
	var manifest_same := true
	if ready and is_instance_valid(app.stage) and app.stage is GeneratedDemoStage: manifest_same = JSON.stringify((app.stage as GeneratedDemoStage).generated.manifest)==manifest_at_start
	result.coverage = {"formal_stage_ready":ready,"initial_player_reset":initial_player_reset,"natural_player_spawn":false,"false_natural_spawn":true,"original_manifest_unchanged":manifest_same,"actual_enemy_HP_commits":result.events.size(),"actual_enemy_deaths":result.deaths,"selected_target_HP_commits":result.target_events.size(),"selected_target_actual_attack":target_attack_seen,"selected_target_nonlethal_recovered":target_recovered,"selected_target_terminal":target_death_frame>=0,"terminal_observation_210_frames":target_death_frame>=0 and frame-target_death_frame>=210,"original_stage_camera":true,"gameplay_seconds":float(gameplay_frame)/60,"human_visual_review":"pending"}
	if not ready: result.coverage_gaps.append("Original formal stage did not become ready")
	if not target_attack_seen: result.coverage_gaps.append("No actual selected-target attack/travel/hold/extend/flight observed; no state forced")
	if first_nonlethal_frame<0: result.coverage_gaps.append("No accepted nonlethal selected-target hit from real projectile")
	if not target_recovered: result.coverage_gaps.append("No completed nonlethal hurt recovery observed")
	if target_death_frame<0: result.coverage_gaps.append("Selected original enemy did not reach accepted terminal")
	elif frame-target_death_frame<210: result.coverage_gaps.append("Target terminal tail shorter than210 frames")
	if not manifest_same: failures.append("Original generated manifest changed during review")
	if terminal_frame>=0: result.coverage_gaps.append("Original player/run became terminal during review; no health or respawn injected")
	result["terminal_policy_observation"] = {"policy":"selected original species policy; no corpse policy added","target_terminal_frame":target_death_frame,"player_terminal_frame":terminal_frame,"scope":"actual formal stage with one disclosed initial review stand; not natural traversal or all-roster proof"}
	app.abandon_run()
	if not await load("res://tests/audio_teardown.gd").drain_world(app): failures.append("Original DemoApp fallback audio failed to release")
	var sound_events: Dictionary = audio.played.duplicate(true)
	if not await audio.shutdown(): failures.append("GameAudio ownership did not release")
	var output := {"task":"ENEMY-ALL-02","complete":true,"seed_label":seed_label,"group":group,"frames":frames,"cases":cases,"failures":failures,"coverage_gap_count":result.coverage_gaps.size(),"audio_events":sound_events,"conditions":{"fps":60,"resolution":[1280,720],"playback_speed":1,"original_stage_camera":true,"initial_player_reset":initial_player_reset,"false_natural_spawn":true,"actor_positioning":"exactly one initial player review stand if safe support found; no later placement or enemy teleport","source_HP_state_AI_injection":false,"scope":"True DemoApp formal generated stage, original enemies/terrain/AI/HUD/StageCameraRig/policy; labelled initial player review stand, NOT NATURAL ROUTE. Forest uses explicit debug map1 admission."},"not_verified":["natural route from original spawn","full campaign completion","all species on this map","physical device performance","human visual approval"]}
	var file := FileAccess.open(trace_path,FileAccess.WRITE)
	if file == null:
		printerr("Cannot write actual formal-encounter trace")
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
