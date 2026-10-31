extends SceneTree
## The existing successful actual-App R3 Boss pilot, without post-victory
## placement/reward callbacks. Only initial map/room placement is a fixture.
var app: DemoApp
var encounter: WindkeeperEncounter
var boss: BossMotor
var trace_path := ""
var seed_label := "underworld-r3-continuous-boss"
var map_index := 2
var frame := 0
var cross_axis := 0
var jump_active := false
var first_hit_frame := -1
var death_frame := -1
var rows: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var failures: Array[String] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--trace="): trace_path = arg.trim_prefix("--trace=")
		if arg.begins_with("--seed="): seed_label = arg.trim_prefix("--seed=")
		if arg.begins_with("--map="): map_index = clampi(int(arg.trim_prefix("--map=")),1,2)
	run.call_deferred()

func ready_stage() -> bool:
	for unused: int in 3600:
		if not app._stage_pending and is_instance_valid(app.stage) and app.stage is PlainsRegionStage and (app.stage as PlainsRegionStage).assembly_ok and app._can_interact(): return true
		await process_frame
	return false

func ticks(count: int) -> void:
	for unused: int in count: await physics_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	app = DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	if not app.start_plains(seed_label) or not await ready_stage():
		printerr("Actual formal Boss initial stage not ready")
		quit(1)
		return
	if map_index==2:
		# Same initial map selection as the existing successful full-fight
		# driver; no enemy HP, phase, weakpoint or battle state is assigned.
		app.director.stage_index = 2
		app.director.region_map_index = 2
		app._load_stage()
		if not await ready_stage():
			printerr("Actual formal map2 Boss stage not ready")
			quit(1)
			return
	var stage := app.stage as PlainsRegionStage
	boss = stage.boss as BossMotor
	encounter = boss.get_node("Encounter") as WindkeeperEncounter
	app.player.get_node("KeyboardMouseAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	# Exactly the original full-fight driver's one initial room placement.
	app.player.reset_at(boss.global_position+Vector2(-250,47))
	await ticks(5)
	if not app._boss_started or encounter.health.current!=encounter.health.capacity: failures.append("Actual full-health Boss room activation failed")
	var id := "windkeeper_storm_formal_app" if map_index==2 else "bellstrider_formal_app"
	cases.append({"case":0,"id":id,"chain":"actual_formal_App","definition":String(encounter.definition.stable_id),"definition_path":encounter.definition.resource_path,"scene":"res://game/application/demo.tscn","renderer":(boss.get_node("Presentation").get_script() as Script).resource_path,"start_frame":1,"start_seconds":float(Engine.get_process_frames())/60,"movie_start_process_frame":Engine.get_process_frames(),"fixture":{"production_AI_enabled":encounter.is_physics_processing(),"initial_map_selection":map_index,"initial_room_player_position":[app.player.global_position.x,app.player.global_position.y],"initial_enemy_health":encounter.health.current,"initial_player_health":app.controller.actor_resources.health.current,"manifest_hash":String(stage.generated.manifest.manifest_hash),"manifest_seed":String(stage.generated.manifest.seed),"differences":["one initial original-room player reset_at only","map2 selected before battle using original successful native-driver entry","automated Router input replaces keyboard","permanent meta persistence disabled"],"scope":"Actual formal stage and original App gameplay; initial room entry is a fixture, not natural traversal"},"events":[],"player_events":[],"inputs":[],"shots":[],"states":[],"attacks":[],"deaths":0,"coverage":{},"coverage_gaps":[]})
	encounter.health.changed.connect(func(result: ActorResourceResult) -> void:
		if result.operation==&"damage" and result.status==ActorResourceResult.Status.APPLIED:
			cases[0].events.append({"frame":frame,"local_frame":frame,"event_id":String(result.event_id),"amount":result.amount_applied,"HP":result.snapshot.current,"epoch":result.snapshot.epoch,"terminal":result.snapshot.terminal})
			if not result.snapshot.terminal and first_hit_frame<0: first_hit_frame = frame
			if result.snapshot.terminal: death_frame = frame)
	encounter.defeated.connect(func(_boss: BossEncounter) -> void: cases[0].deaths += 1)
	encounter.projectile_created.connect(func(projectile: BossProjectile) -> void:
		cases[0].attacks.append({"frame":frame,"event":"actual_App_BossProjectile_created","script":(projectile.get_script() as Script).resource_path}))
	app.controller.actor_resources.health.changed.connect(func(result: ActorResourceResult) -> void:
		if result.operation==&"damage" and result.status==ActorResourceResult.Status.APPLIED:
			cases[0].player_events.append({"frame":frame,"amount":result.amount_applied,"HP":result.snapshot.current,"terminal":result.snapshot.terminal,"event_id":String(result.event_id)}))
	app.controller.shoot_ability.shot_fired.connect(func(direction: Vector2,serial: int) -> void:
		cases[0].shots.append({"frame":frame,"shot_id":serial,"direction":[direction.x,direction.y]}))
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	root.add_child(overlay)
	var label := Label.new()
	label.position = Vector2(12,704)
	label.add_theme_font_size_override("font_size",10)
	label.add_theme_color_override("font_outline_color",Color.BLACK)
	label.add_theme_constant_override("outline_size",2)
	label.text = "ACTUAL FORMAL APP / original AI, HP, damage and camera / one initial map-room entry fixture / no mid-battle placement or reward reset"
	overlay.add_child(label)
	process_frame.connect(observe)
	RenderingServer.frame_post_draw.connect(post_draw)
	for tick: int in 7200:
		if not is_instance_valid(app.controller) or app.director.state!=DemoRunDirector.State.IN_STAGE or encounter.health.terminal: break
		var player := app.player as PlayerMotor
		var controller := app.controller
		var dx := boss.global_position.x-player.global_position.x
		var grounded := player.is_on_floor()
		var axis := 0.0
		if map_index==1:
			if encounter.mode==&"roll" and signf(dx)==-encounter.direction and absf(dx)<195 and grounded and cross_axis==0:
				cross_axis = -encounter.direction
				controller.router.set_jump_held(&"r3_fight",true)
				jump_active = true
			if cross_axis!=0:
				axis = float(cross_axis)
				if grounded and not jump_active: cross_axis = 0
			else:
				var desired := clampf(boss.global_position.x-signf(dx)*220,stage.boss_arena.position.x+55,stage.boss_arena.end.x-55)
				axis = clampf((desired-player.global_position.x)/45,-1,1)
			if encounter.mode==&"rings" and grounded and encounter.clock<.5:
				controller.router.set_jump_held(&"r3_fight",true)
				jump_active = true
		else:
			var module: PlatformingModule
			for candidate: PlatformingModule in stage.assembler.modules:
				if candidate.definition.module_id==&"plains_boss_arena": module = candidate; break
			var desired := boss.global_position.x-signf(dx)*240
			if encounter.stage_phase>=2 and module!=null:
				var shelf_centers: Array[float] = []
				for index: int in [1,2,3]: shelf_centers.append(module.to_global(module.definition.platforms[index].get_center()).x)
				desired = shelf_centers[0] if encounter.stage_phase==2 else shelf_centers[clampi(encounter.chase_segment+1,0,2)]
				if grounded and player.global_position.y>encounter._floor_y-130:
					controller.router.set_jump_held(&"r3_fight",true)
					jump_active = true
			axis = clampf((desired-player.global_position.x)/45,-1,1)
			if grounded and encounter.mode==&"stomp_warning" and encounter.clock<.3:
				controller.router.set_jump_held(&"r3_fight",true)
				jump_active = true
		if jump_active and player.normal_velocity.y>=0:
			controller.router.set_jump_held(&"r3_fight",false)
			jump_active = false
		controller.router.set_move_axis(axis)
		var can_shoot := encounter.mode!=&"intro" and controller.shoot_ability.cooldown_remaining<=0 and controller.shoot_ability.rounds_remaining==0
		if map_index==1 and cross_axis!=0 and signf(dx)==float(cross_axis): can_shoot = false
		if can_shoot:
			var aim_point := boss.global_position+Vector2(0,-20 if player.global_position.y>boss.global_position.y else -95)
			var aim := (aim_point-player.global_position).normalized()
			var accepted := controller.router.request_action(&"shoot_release",aim)
			cases[0].inputs.append({"frame":frame,"type":"shoot_release","direction":[aim.x,aim.y],"router_submitted":accepted})
		await ticks(1)
	app.controller.router.set_move_axis(0)
	app.controller.router.set_jump_held(&"r3_fight",false)
	if death_frame>=0:
		while frame-death_frame<210: await process_frame
	await RenderingServer.frame_post_draw
	await finish()

func visual_receipt() -> Dictionary:
	var host := boss.get_node("Presentation") as Node2D
	var sample: EnemyFeedback01
	if host.has_meta(EnemyHitTemplate.METADATA): sample = (host.get_meta(EnemyHitTemplate.METADATA) as EnemyHitTemplate).sample
	return {"host_visible":host.is_visible_in_tree(),"host_alpha":host.modulate.a*host.self_modulate.a,"hurt_remaining":sample.hurt_remaining if sample!=null else null,"hurt_frame_index":null,"death_frame_index":null,"frame_index_reason":"original Boss procedural renderer, no authored cell interface"}

func observe() -> void:
	frame += 1
	var visual := visual_receipt()
	var states: Array = cases[0].states
	if states.is_empty() or states.back().state!=String(encounter.mode): states.append({"frame":frame,"local_frame":frame,"state":String(encounter.mode),"phase":encounter.stage_phase})
	rows.append({"frame":frame,"sampling_phase":"SceneTree.process_frame_before_node_process","movie_process_frame":Engine.get_process_frames(),"case":0,"local_frame":frame,"player_position":[app.player.global_position.x,app.player.global_position.y],"player_velocity":[app.player.velocity.x,app.player.velocity.y],"enemy_position":[boss.global_position.x,boss.global_position.y],"HP":encounter.health.current,"player_HP":app.controller.actor_resources.health.current,"state":String(encounter.mode),"stage_phase":encounter.stage_phase,"axis":app.controller.router.axis,"visual":visual})
	if first_hit_frame>=0 and not encounter.health.terminal and frame-first_hit_frame>=8 and visual.hurt_remaining!=null and float(visual.hurt_remaining)<=0: cases[0].coverage["recovered_after_nonlethal"] = true

func post_draw() -> void:
	if rows.is_empty(): return
	var row: Dictionary = rows.back()
	row["visual_after_draw"] = visual_receipt()
	row["movie_process_frame_after_draw"] = Engine.get_process_frames()
	row["visual_after_draw_sampling_phase"] = "RenderingServer.frame_post_draw_read_only"

func finish() -> void:
	process_frame.disconnect(observe)
	RenderingServer.frame_post_draw.disconnect(post_draw)
	var result: Dictionary = cases[0]
	result["end_frame"] = frame
	result["end_seconds"] = float(Engine.get_process_frames())/60
	result["movie_end_process_frame"] = Engine.get_process_frames()
	result["post_death_observation_frames"] = frame-death_frame if death_frame>=0 else 0
	result.coverage["actual_AI_commitment"] = not result.attacks.is_empty()
	result.coverage["nonlethal_HP_commit"] = first_hit_frame>=0
	result.coverage["recovered_after_nonlethal"] = result.coverage.get("recovered_after_nonlethal",false)
	result.coverage["lethal_HP_commit"] = encounter.health.terminal and result.deaths==1
	result.coverage["terminal_observed_210_frames"] = death_frame>=0 and frame-death_frame>=210
	result.coverage["player_survived"] = not app.controller.actor_resources.health.terminal and app.lifetime.active
	result["terminal_policy_observation"] = {"policy":"original actual App Boss exit and original stage reward readiness; no reward/reset callbacks invoked","terminal":encounter.health.terminal}
	for key: String in ["actual_AI_commitment","nonlethal_HP_commit","recovered_after_nonlethal","lethal_HP_commit","terminal_observed_210_frames","player_survived"]:
		if not result.coverage[key]: result.coverage_gaps.append(key)
	# End capture authority before teardown. Do not call abandon_run(), which
	# would fabricate an audible failure cue after a successful Boss victory.
	app.controller.router.clear("review_capture_complete")
	app.lifetime.end()
	encounter.cancel()
	if not await load("res://tests/audio_teardown.gd").drain_world(app): failures.append("Original App audio ownership did not release")
	var cues: Dictionary = {}
	# Observe the actual App-owned service without adding a second service or
	# a static audio-script dependency to this SceneTree driver.
	for node: Node in app.find_children("*","",true,false):
		if not node.has_method(&"play_director_event") or not node.has_method(&"shutdown"): continue
		var played: Variant = node.get("played")
		if not played is Dictionary: continue
		for key: Variant in played:
			cues[String(key)] = int(cues.get(String(key),0))+int(played[key])
	var output := {"task":"ENEMY-ALL-02","complete":true,"group":"formal_boss","frames":rows,"cases":cases,"failures":failures,"coverage_gap_count":result.coverage_gaps.size(),"audio_events":cues,"conditions":{"fps":60,"resolution":[1280,720],"playback_speed":1,"original_formal_stage":true,"original_stage_camera":true,"initial_room_placement_only":true,"source_HP_state_AI_injection":false,"pilot_source":"tests/underworld_plains/capture_underworld_r3_boss_fight.gd pre-victory loop"},"not_verified":["natural room entry or campaign progression","human visual approval","physical device performance"]}
	var file := FileAccess.open(trace_path,FileAccess.WRITE)
	if file==null: quit(1); return
	file.store_string(JSON.stringify(output,"\t"))
	file.close()
	app.free()
	await process_frame
	await process_frame
	print("ENEMY ALL REVIEW 02: complete; cases=1; frames=%d; coverage_gaps=%d" % [frame,result.coverage_gaps.size()])
	quit(0 if failures.is_empty() else 1)
