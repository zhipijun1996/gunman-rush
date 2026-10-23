extends SceneTree
## Checkpoint-only observer of unmodified production consumers. Selection uses
## the existing application API (not pointer/GUI proof); movement/shots use Router.
## No transforms, HP, grants, weapon Definitions or gameplay results are injected.
var app: DemoApp
var consumer := "home"
var output := "res://build/player_presentation_01/checkpoint_01/home.json"
var capture := false
var rows: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var errors: Array[String] = []
var seed_value := "player-presentation-01/baseline-01"

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--consumer="): consumer = argument.trim_prefix("--consumer=")
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument == "--capture": capture = true
	run.call_deferred()

func advance() -> void:
	if capture: await RenderingServer.frame_post_draw
	else: await process_frame
	await physics_frame

func run() -> void:
	root.size = Vector2i(1280, 720)
	app = preload("res://scenes/demo/demo.tscn").instantiate()
	app.meta_persistence_enabled = false
	root.add_child(app)
	await advance()
	if consumer == "home":
		app.menu.requested_enter_home.emit()
	elif consumer == "plains":
		if not app.start_plains(seed_value): errors.append("formal start rejected")
	else:
		errors.append("unsupported consumer")
	for unused: int in 120:
		await advance()
		if consumer == "home" and is_instance_valid(app.home_scene): break
		if consumer == "plains" and not app._stage_pending and app.stage is PlainsRegionStage: break
	var motor: PlayerMotor = app.home_scene.player if consumer == "home" and is_instance_valid(app.home_scene) else app.player
	if not is_instance_valid(motor):
		errors.append("production player not ready")
		await finish()
		return
	var controller := motor.get_node("Controller") as PlayerController
	var anchor := motor.get_node("CourierVisual") as CourierVisual
	var art: UnderworldPlayer
	for child: Node in motor.get_children():
		if child is UnderworldPlayer: art = child
	if art == null:
		errors.append("actual UnderworldPlayer absent")
		await finish()
		return
	var avatar := app.get_meta("avatar_presentation") as AvatarPresentation
	controller.router.activate_device(&"gamepad")
	controller.shoot_ability.shot_fired.connect(func(direction: Vector2, id: int) -> void:
		shots.append({"sample":rows.size(),"id":id,"direction":[direction.x,direction.y]}))
	var tuning_sha := FileAccess.get_sha256("res://config/player_tuning.json")
	for tick: int in 720:
		if not is_instance_valid(motor) or not is_instance_valid(controller):
			errors.append("consumer unloaded before observation completed")
			break
		if consumer == "home" and tick % 240 == 0:
			var id: String = ["courier", "p1_traveller", "p1_girl"][tick / 240]
			if not avatar.select_avatar(id): errors.append("existing selection rejected " + id)
		# Keep this observation near the real spawn, without moving any transform.
		var cycle := tick % 120
		controller.router.set_move_axis(1.0 if cycle < 45 else -1.0 if cycle < 90 else 0.0)
		controller.router.set_aim(&"gamepad", Vector2(1, -.35).normalized(), false)
		if cycle == 35 or cycle == 75:
			controller.router.request_action(&"shoot_release", Vector2(1, -.35).normalized())
		await advance()
		var receipt := art.animation_receipt()
		rows.append({"sample":tick,"physics_tick":Engine.get_physics_frames(),
			"position":[motor.position.x,motor.position.y],"normal_velocity":[motor.normal_velocity.x,motor.normal_velocity.y],
			"motion_steps":motor.motion_steps,"health":controller.actor_resources.health.current,
			"body_state":receipt.state,"body_facing":receipt.facing,"body_visible":art.visible,
			"courier_state":str(anchor.state),"courier_facing":anchor.facing,"courier_visible":anchor.visible,
			"adapter_disabled":motor.get_node("PlayerVisualAdapter").process_mode == Node.PROCESS_MODE_DISABLED,
			"weapon_id":str(controller.shoot_ability.weapon.id),"weapon_mode":int(controller.shoot_ability.weapon.mode),
			"anchor_weapon_mode":anchor.weapon_mode,"muzzle":[receipt.muzzle_world.x,receipt.muzzle_world.y],
			"avatar":avatar.snapshot(),"router_epoch":controller.router.epoch})
	controller.router.clear("checkpoint_observation_complete")
	if rows.size() != 720: errors.append("incomplete observation")
	if shots.is_empty(): errors.append("no real accepted shot observed")
	if not rows.any(func(row: Dictionary) -> bool: return absf(row.normal_velocity[0]) > 10): errors.append("no real locomotion observed")
	if FileAccess.get_sha256("res://config/player_tuning.json") != tuning_sha: errors.append("tuning changed")
	await finish()

func finish() -> void:
	var report := {"consumer":consumer,"seed":seed_value,"engine":Engine.get_version_info().string,
		"status":"passed" if errors.is_empty() else "failed","errors":errors,"rows":rows,"shots":shots,
		"scope":"Baseline observation of actual DemoApp/HomeScene or formal PlainsRegionStage. Existing select_avatar API is a selection fixture, not GUI click proof. No damage/death or complete route claim; no presentation improvement.",
		"user_acceptance":"unverified","device_acceptance":"unverified"}
	if is_instance_valid(app):
		report["audio_released"] = await load("res://tests/audio_teardown.gd").drain_world(app)
		if not report.audio_released:
			errors.append("audio teardown failed")
			report.status = "failed"
		app.free()
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		printerr("Cannot save checkpoint observation")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	for unused: int in 4: await process_frame
	print("PLAYER PRESENTATION BASELINE: consumer=",consumer," samples=",rows.size()," shots=",shots.size()," errors=",errors.size())
	quit(0 if errors.is_empty() else 1)
