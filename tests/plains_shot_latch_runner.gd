extends SceneTree
var assertions := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var tuning := PlayerTuning.load_default()
	for index:int in [1,3,7]:
		for kind:StringName in [&"combat",&"coin_reward",&"item_reward"]:
			for seed:int in 3:
				var data:=PlainsStageGenerator.new().generate("visible-bell-%s"%seed,index,kind,tuning)
				check(data.ok,"windchime formal generation succeeds")
				if not data.ok: continue
				check(PlainsShotLatchPlanner.validate(data.manifest),"precise versioned windchime plan validates")
				check(data.manifest.shot_latch_plan.latches.size()==1,"formal action room contains exactly one staged windchime encounter")
				var latch:Dictionary=data.manifest.shot_latch_plan.latches[0]
				check(latch.kind==("safe_lesson" if index==1 else "shot_recoil_combo"),"first common lesson and later challenge combo follow introduction")
				check(data.manifest.common_path.has(latch.node_index) if index==1 else data.manifest.terminal_paths[0].has(latch.node_index),"windchime belongs to actual common/challenge graph")
				check(not data.manifest.terminal_paths[1].has(latch.node_index),"ordinary route stays free of windchime gate requirement")
				if index >= 3:
					var path: Array = data.manifest.terminal_paths[0]
					check(data.manifest.nodes[path[1]].module_id == "plains_micro_landing" and data.manifest.nodes[path[2]].module_id == "plains_recoil_step", "forgiving windchime well supplements safe recovery then required recoil ascent")
					check(RandomStageGenerator.new().definition_for(data.manifest.nodes[path[2]].module_id).requires_burst, "followup is a real required-recoil height challenge")
				var replay:=PlainsStageGenerator.new().generate("visible-bell-%s"%seed,index,kind,tuning)
				check(data.manifest==replay.manifest,"same Seed records identical geometry and windchime configuration")
				var altered:Dictionary=data.manifest.duplicate(true)
				altered.shot_latch_plan.latches[0].bell[0]+=1
				altered.manifest_hash=RandomStageGenerator.new()._manifest_hash(altered)
				check(not RandomStageGenerator.new().validate_manifest(altered,tuning).ok,"changed bell collision location rejected even after recomputing layout hash")
				altered=data.manifest.duplicate(true)
				altered.shot_latch_plan.configuration.version+=1
				altered.manifest_hash=RandomStageGenerator.new()._manifest_hash(altered)
				check(not RandomStageGenerator.new().validate_manifest(altered,tuning).ok,"unrecognized latch configuration version rejected")
	for kind:StringName in [&"shop",&"health_reward",&"boss"]:
		var data:=PlainsStageGenerator.new().generate("visible-bell-rest",8 if kind==&"boss" else 3,kind,tuning)
		check(data.ok and data.manifest.shot_latch_plan.latches.is_empty(),"service rooms and Boss core stay outside new windchime pool")
	await app_integration()
	if "--inject-failure" in OS.get_cmdline_user_args(): check(false,"injected failure exit-code probe")
	print("PLAINS SHOT LATCH: %s assertions, %s failures"%[assertions,failures])
	quit(1 if failures else 0)
func frames(count:int) -> void:
	for _frame:int in count: await physics_frame
func app_integration() -> void:
	var app:=preload("res://scenes/demo/demo.tscn").instantiate() as DemoApp
	app.meta_persistence_enabled=false
	root.add_child(app)
	await frames(2)
	var meta_before:=app.meta.snapshot().duplicate(true)
	check(app.start_plains("first-visible-bell"),"default formal run starts through real App")
	await frames(7)
	var stage:=app.stage as GeneratedDemoStage
	check(stage!=null and stage.shot_latches.size()==1,"formal first room installs actual ShotLatch through production setup")
	if stage==null or stage.shot_latches.size()!=1:
		app.queue_free()
		await frames(2)
		return
	var latch:=stage.shot_latches[0]
	var bell:=latch.bell_body.global_position
	check(bell==Vector2(370,235) and latch.prompt_text=="SHOOT BELL","first bell has its deterministic initial-screen world position and visible user prompt")
	# Real input-only walk from spawn to safe firing position.
	app.controller.set_physics_process(false)
	for _step:int in 95:
		app.controller.router.set_move_axis(clampf((330.0-app.player.position.x)/5.0,-1,1))
		await physics_frame
		app.controller.physics_tick(1.0/60)
		if absf(app.player.position.x-330)<2 and app.player.is_on_floor(): break
	app.controller.router.set_move_axis(0)
	check(app.player.position.x>325 and app.player.is_on_floor(),"actual Motor reaches safe teaching firing point from initial spawn without teleport")
	var hp:=app.controller.actor_resources.health.current
	app.controller.router.request_action(&"shoot_release",(bell-app.player.position).normalized())
	for _step:int in 22:
		await physics_frame
		app.controller.physics_tick(1.0/60)
	check(latch.is_open and latch.open_count==1 and not latch.gate_body.collision_layer,"real formal released projectile opens real solid first gate once")
	check(app.controller.actor_resources.health.current==hp and app.player.is_on_floor(),"first visible windchime firing and ground recoil are safe at actual approach position")
	var map_before:Dictionary=stage.generated.manifest.duplicate(true)
	app.policy.clock+=2
	check(submit_damage(app,&"visible_bell_return",1),"formal environmental damage enters actual shared batch")
	app.policy.resolve_batch()
	check(latch.is_open and latch.open_count==1 and stage.generated.manifest==map_before and app.controller.actor_resources.health.current==hp-1,"formal segment return preserves open gate and manifest while retaining spent health")
	var snapshot:=app.director.manifest.snapshot()
	check(RunManifest.compatible(snapshot),"full formal RunManifest validates recorded windchime output")
	var altered:Dictionary=snapshot.duplicate(true)
	altered.stages[0].outputs.shot_latch_layout.latches[0].gate[0]+=10
	check(not RunManifest.compatible(altered),"full RunManifest rejects separately forged windchime output")
	app.controller.set_physics_process(true)
	app._pause_for_menu()
	check(paused and latch.is_open and app.controller.shoot_ability.get_projectiles().is_empty(),"formal pause preserves opened state and cancels old switch projectile work")
	app._resume_from_menu()
	await frames(2)
	check(latch.is_open and app.meta.snapshot()==meta_before,"formal latch opening does not mutate permanent progress")
	app.abandon_run()
	await frames(4)
	check(app.director.state==DemoRunDirector.State.HOME,"leaving formal windchime run returns Home normally")
	app.queue_free()
	await frames(2)
func submit_damage(app:DemoApp,id:StringName,amount:float) -> bool:
	var request:=DamageRequest.new()
	request.token=app.lifetime.token()
	request.actor_epoch=app.lifetime.actor_epoch
	request.health_epoch=app.controller.actor_resources.health.epoch
	request.target_id=&"player"
	request.source_id=id
	request.event_id=id
	request.amount=amount
	request.kind=DamageRequest.Kind.ENVIRONMENT
	return app.policy.submit(request)
