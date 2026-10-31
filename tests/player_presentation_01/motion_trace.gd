extends SceneTree
## Real App/Router/Motor observer. No transforms, HP, equipment, grants or force
## injection. Initial normal formal spawn and collision/AI/resources are intact.
var app: PlayerMotionCandidatePreview
var enabled_candidate := true
var capture := false
var output := ""
var rows: Array[Dictionary] = []
var events: Array[Dictionary] = []
var errors: Array[String] = []
var checks := 0
var trace_samples := 1080

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--candidate=off": enabled_candidate = false
		if arg == "--capture": capture = true
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--samples="): trace_samples = arg.trim_prefix("--samples=").to_int()
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: errors.append(label)

func advance() -> void:
	if capture: await RenderingServer.frame_post_draw
	else: await process_frame
	await physics_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	if output.is_empty() or FileAccess.file_exists(output) or trace_samples not in [600,1080]:
		printerr("MOTION TRACE requires unique new --output path")
		quit(1)
		return
	app = preload("res://scenes/dev/player_presentation_01/motion_candidate.tscn").instantiate()
	app.motion_enabled = enabled_candidate
	root.add_child(app)
	for unused: int in 160:
		await advance()
		if is_instance_valid(app.motion_visual): break
	check(is_instance_valid(app.motion_visual),"actual formal visual ready")
	if not is_instance_valid(app.motion_visual):
		await finish()
		return
	var actor := app.player
	var control := app.controller
	var visual := app.motion_visual
	var anchor := actor.get_node("CourierVisual") as CourierVisual
	var collision_before := (actor.get_node("CollisionShape2D").shape as RectangleShape2D).size
	var tuning_sha := FileAccess.get_sha256("res://config/player_tuning.json")
	var manifest_hash: String = app.stage.generated.manifest.manifest_hash
	control.router.activate_device(&"gamepad")
	control.jump_ability.jumped.connect(func() -> void: events.append({"sample":rows.size(),"event":"accepted_jump","tick":Engine.get_physics_frames()}))
	control.landed.connect(func() -> void: events.append({"sample":rows.size(),"event":"accepted_land","tick":Engine.get_physics_frames()}))
	for sample: int in trace_samples:
		if not is_instance_valid(actor) or not is_instance_valid(control):
			errors.append("formal actor unloaded before end")
			break
		var axis := 0.0
		if sample >= 240 and sample < 336: axis = 1.0 if (sample - 240) % 24 < 12 else -1.0
		if sample >= 800 and sample < 850: axis = 1.0
		control.router.set_move_axis(axis)
		if sample in [360,520]: control.router.set_jump_held(&"motion_sample",true)
		if sample in [374,546]: control.router.set_jump_held(&"motion_sample",false)
		# An airborne request must not emit a new accepted jump by itself.
		if sample == 366: control.router.request_action(&"jump")
		if sample == 370: control.router.request_action(&"jump_release")
		if sample == 363:
			control.router.clear("motion_pause_fixture")
			var age_before := visual._state_age
			var point_before := actor.position
			var dust_before := visual._dust.duplicate(true)
			check(not enabled_candidate or not dust_before.is_empty(),"pause fixture includes live accepted takeoff particles")
			paused = true
			for unused: int in 4: await process_frame
			check(age_before == visual._state_age and actor.position == point_before and visual._dust == dust_before,"pause freezes body dust and Motor")
			paused = false
		await advance()
		var muzzle_before := anchor.visible_muzzle_position()
		var arm_before := anchor.arm.transform
		var receipt := visual.candidate_receipt()
		check(muzzle_before == anchor.visible_muzzle_position() and arm_before == anchor.arm.transform,"receipt is pure and keeps authority muzzle")
		check(visual._dust.size() <= visual.profile.particle_cap,"bounded particles")
		rows.append({"sample":sample,"physics_tick":Engine.get_physics_frames(),"render_frame_counter":Engine.get_frames_drawn(),
			"position":[actor.position.x,actor.position.y],"normal_velocity":[actor.normal_velocity.x,actor.normal_velocity.y],
			"velocity":[actor.velocity.x,actor.velocity.y],"recoil":[actor.recoil_velocity.x,actor.recoil_velocity.y],
			"motion_steps":actor.motion_steps,"hp":control.actor_resources.health.current,"terminal":control.actor_resources.health.terminal,
			"energy":control.actor_resources.stamina.current,
			"muzzle":[muzzle_before.x,muzzle_before.y],"body_state":visual.animation_state,"body_facing":visual.facing,
			"candidate_state":receipt.state,"candidate_frame":receipt.frame,"dust":receipt.dust_count,
			"accepted_jumps":receipt.accepted_jumps,"accepted_lands":receipt.accepted_lands,
			"camera":[app._run_camera.get_screen_center_position().x,app._run_camera.get_screen_center_position().y],
			"manifest_hash":manifest_hash,"session":control.session_id,"weapon_epoch":control.shoot_ability.weapon_epoch})
	control.router.clear("motion_sample_complete")
	check(rows.size() == trace_samples,"full requested actual observation;600 includes both accepted jumps and landings,1080 additionally long fall and return")
	check(events.filter(func(e: Dictionary) -> bool: return e.event == "accepted_jump").size() == 2,"two accepted jumps;airborne rejected intent adds none")
	check(visual.accepted_lands >= 2,"two actual landings observed")
	check((actor.get_node("CollisionShape2D").shape as RectangleShape2D).size == collision_before,"collision dimensions retained")
	check(FileAccess.get_sha256("res://config/player_tuning.json") == tuning_sha,"tuning byte unchanged")
	await finish()

func finish() -> void:
	var result := {"checks":checks,"errors":errors,"candidate_enabled":enabled_candidate,"capture":capture,"rows":rows,"events":events,
		"scope":"Task dev subclass of actual formal player;original world/camera/Router/Motor;normal spawn;no actor/HP/equipment writes.Only idle/fall source candidate,distance-phase old run,and accepted takeoff/landing dust.No complete weapon/three-avatar/region/device claim."}
	if is_instance_valid(app):
		result["audio_released"] = await load("res://tests/audio_teardown.gd").drain_world(app)
		if not result.audio_released: errors.append("audio teardown failed")
		app.free()
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	for unused: int in 4: await process_frame
	print("MOTION TRACE: samples=",rows.size()," checks=",checks," errors=",errors.size())
	quit(0 if errors.is_empty() else 1)
