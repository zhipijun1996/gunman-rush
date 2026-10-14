extends "res://tests/branch_library_runner.gd"
func _run() -> void:
	for mirrored: bool in [false,true]:
		await fixture("plains_windchime_timed",mirrored,0)
		var latch := ShotLatch.new()
		latch.position = module.position
		latch.open_seconds = .4
		world.add_child(latch)
		var bell := Vector2(170,235)
		var gate := Rect2(320,80,24,220)
		if mirrored:
			bell.x = 480-bell.x
			gate.position.x = 480-gate.end.x
		var life := DemoLifetime.new()
		latch.setup(controller,life,bell,gate)
		var driver = load("res://tests/shot_latch_module_driver.gd").new()
		driver.module = module
		driver.motor = motor
		driver.controller = controller
		driver.tick = tick
		check(await driver.move_to(module.to_global(Vector2(140 if not mirrored else 340,282)).x),"actual waiting bank approach")
		controller.router.request_action(&"shoot_release",(latch.bell_body.global_position-motor.global_position).normalized())
		await tick(12)
		check(latch.is_open and latch.open_count == 1,"actual shot opens short timed window")
		var before := latch._clock
		paused = true
		await process_frame
		await process_frame
		check(latch._clock == before and latch.is_open,"pause freezes actual timed gate")
		paused = false
		await tick(60)
		check(not latch.is_open and latch.gate_body.collision_layer == 1,"missed window closes with intact waiting bank")
		check(await driver.move_to(module.to_global(Vector2(140 if not mirrored else 340,282)).x),"actual repeated bank approach")
		controller.router.request_action(&"shoot_release",(latch.bell_body.global_position-motor.global_position).normalized())
		await tick(12)
		check(latch.is_open and latch.open_count == 2,"same real bell reopens after a missed opportunity")
		var hit_count := latch.open_count
		latch.cancel_pending()
		check(latch.open_count == hit_count and latch.is_open,"return cancellation retains already committed window")
	# Real App menu freezes every P3 state, not only a standalone SceneTree.
	var app := preload("res://scenes/demo/demo.tscn").instantiate() as DemoApp
	app.meta_persistence_enabled = false
	root.add_child(app)
	await physics_frame
	check(app.start_plains_regression("polish-menu"),"real App starts")
	await physics_frame
	await physics_frame
	app.director._enter_stage(8,&"boss")
	app.lifetime.stage_epoch += 7
	app.lifetime.actor_epoch += 7
	app._load_stage()
	for unused: int in 5: await physics_frame
	var boss := app.stage.boss.get_node("Encounter") as WindkeeperEncounter
	boss.activate()
	boss.stage_phase = 3
	boss.health.apply_damage(ActorResourceRequest.new(&"phase_fixture",boss.health.epoch,8,boss.health.get_instance_id()))
	for state: StringName in [&"intro",&"phase_transition",&"chase",&"pier_warning",&"pier_impact",&"pier_open",&"final_hold"]:
		boss._enter(state,2)
		var position_before := boss.motor.global_position
		var attack_before := boss.attack_epoch
		app._pause_for_menu()
		await process_frame
		check(boss.mode == state and boss.clock == 2 and boss.motor.global_position == position_before and boss.attack_epoch == attack_before,"App pause preserves %s rather than cancelling into observe" % state)
		app._resume_from_menu()
	paused = false
	app.menu.show_settings(true)
	var controls: Array[CheckButton] = []
	for child: Node in app.menu._content.get_children():
		if child is CheckButton: controls.append(child)
	check(controls.size() == 2,"real settings expose decorative effects and audio controls")
	for control: CheckButton in controls: control.button_pressed = true
	app._process(0)
	check(app._reduced_effects and not (app.player.get_node("PlayerFeedback") as PlayerFeedback).effects_enabled,"actual setting clears decorative feedback")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),"actual mute control reaches Master audio bus")
	check(boss.active and is_instance_valid(boss._core),"muted/reduced mode retains the real guardian and core")
	for control: CheckButton in controls: control.button_pressed = false
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),"actual audio setting restores sound")
	app._resume_from_menu()
	app.free()
	world.free()
	await process_frame
	print("PLAINS POLISH LIFECYCLE: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)
