extends SceneTree
## Actual unchanged formal Home geometry, normal spawn and real Router/Motor.
## Two terrace ascents and192wu drops; no placement/HP/resource/grant injection.
var app: PlayerMotionCandidatePreview
var actor: PlayerMotor
var controller: PlayerController
var visual: PlayerMotionCandidateVisual
var capture := false
var enabled_candidate := true
var output := ""
var rows: Array[Dictionary] = []
var events: Array[Dictionary] = []
var errors: Array[String] = []
var checks := 0
var pending_pointer := false

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg=="--capture": capture=true
		if arg=="--candidate=off": enabled_candidate=false
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: errors.append(label)

func frames(count: int) -> void:
	for unused: int in count:
		if pending_pointer:
			var pointer := InputEventMouseMotion.new()
			pointer.position = Vector2(870,300)
			Input.parse_input_event(pointer)
			pending_pointer = false
		if capture: await RenderingServer.frame_post_draw
		else: await process_frame
		await physics_frame
		if not is_instance_valid(actor):
			errors.append("formal Home actor disappeared")
			return
		var muzzle := (actor.get_node("CourierVisual") as CourierVisual).visible_muzzle_position()
		var transform := actor.get_canvas_transform()
		var feel := actor.get_node("MotionFeel") as PlayerMotionFeel
		rows.append({"sample":rows.size(),"tick":Engine.get_physics_frames(),"draw_counter":Engine.get_frames_drawn(),"position":[actor.position.x,actor.position.y],"velocity":[actor.velocity.x,actor.velocity.y],"normal":[actor.normal_velocity.x,actor.normal_velocity.y],"recoil":[actor.recoil_velocity.x,actor.recoil_velocity.y],"motion_steps":actor.motion_steps,"hp":controller.actor_resources.health.current,"stamina":controller.actor_resources.stamina.current,"muzzle":[muzzle.x,muzzle.y],"aim":[controller.router.aim_direction.x,controller.router.aim_direction.y],"canvas":[transform.x.x,transform.x.y,transform.y.x,transform.y.y,transform.origin.x,transform.origin.y],"camera_offset":[app.home_scene.camera.offset.x,app.home_scene.camera.offset.y],"body":visual.animation_state,"render_body":visual.displayed_state,"recovery":visual._heavy_recovery,"heavy_count":visual.heavy_land_count,"shake_remaining":feel._remaining,"dust":visual._dust.size()})
		check(app.motion_audio._voices.size()==GameAudio.MAX_VOICES,"same twelve voices,including legacy and motion")
		check(app.home_scene.camera.offset==Vector2.ZERO,"shake never changes camera/input canvas")
		if rows.size()>900:
			errors.append("bounded real route exceeded900 samples")
			return

func walk_to(x: float) -> void:
	controller.router.activate_device(&"gamepad")
	for unused: int in 240:
		if absf(actor.position.x-x)<4: break
		controller.router.set_move_axis(signf(x-actor.position.x))
		await frames(1)
	controller.router.set_move_axis(0)
	await frames(3)
	check(absf(actor.position.x-x)<9,"real walk reaches terrace overlap")

func jump_to(y: float) -> void:
	controller.router.set_jump_held(&"feel",true)
	await frames(36)
	controller.router.set_jump_held(&"feel",false)
	await frames(12)
	check(actor.is_on_floor() and absf(actor.position.y+18-y)<4,"normal single jump reaches terrace")

func terrace_drop() -> void:
	await walk_to(825)
	await jump_to(336)
	await jump_to(240)
	await walk_to(940)
	controller.router.request_action(&"drop_through")
	for unused: int in 60:
		await frames(1)
		if actor.is_on_floor() and actor.position.y>400: break
	check(actor.is_on_floor() and absf(actor.position.y+18-432)<4,"actual192wu drop lands on safe grass floor")
	check(visual.last_landing.get("drop",0)>=190,"real drop classified from actual flight geometry")

func run() -> void:
	root.size=Vector2i(1280,720)
	if output.is_empty() or FileAccess.file_exists(output): quit(1);return
	app=preload("res://scenes/dev/player_presentation_01/landing_feel.tscn").instantiate()
	app.motion_enabled=enabled_candidate
	root.add_child(app)
	for unused: int in 120:
		await physics_frame
		if is_instance_valid(app.motion_visual): break
	check(is_instance_valid(app.motion_visual) and is_instance_valid(app.home_scene),"actual formal Home ready")
	if not is_instance_valid(app.motion_visual): await finish();return
	actor=app.home_scene.player
	controller=app.home_scene.controller
	visual=app.motion_visual
	visual.motion_land.connect(func(drop:float,speed:float,heavy:bool,airborne:bool)->void:
		events.append({"event":"land","sample":rows.size(),"drop":drop,"speed":speed,"heavy":heavy,"airborne":airborne})
		if drop>180: pending_pointer=true)
	visual.motion_jump.connect(func()->void:events.append({"event":"jump","sample":rows.size()}))
	controller.router.activate_device(&"gamepad")
	await frames(30)
	# A normal short jump must not shake or use the heavy pose.
	controller.router.set_jump_held(&"feel",true)
	await frames(7)
	controller.router.set_jump_held(&"feel",false)
	await frames(35)
	check(visual.heavy_land_count==0,"ordinary jump never triggers high-fall feedback")
	await terrace_drop()
	await frames(24) # Let first real heavy pose and shake complete normally.
	check(visual._heavy_recovery==0,"heavy pose has bounded natural recovery")
	await terrace_drop()
	await frames(2)
	check(not enabled_candidate or visual._heavy_recovery>0,"second drop has visible recovery before cancellation")
	var jumped_before := visual.accepted_jumps
	controller.router.set_jump_held(&"feel",true)
	await frames(1)
	check(visual.accepted_jumps==jumped_before+1 and visual._heavy_recovery==0,"legal next jump is immediate during visual recovery")
	controller.router.request_action(&"jump") # rejected airborne intent
	await frames(6)
	controller.router.set_jump_held(&"feel",false)
	await frames(35)
	check(visual.accepted_jumps==jumped_before+1,"airborne rejected intent adds no new accepted audio/jump")
	while rows.size()<780: await frames(1)
	controller.router.clear("feel_complete")
	check(controller.actor_resources.health.current==5,"safe Home drops never change HP")
	check(not enabled_candidate or visual.heavy_land_count==2,"exactly two actual high landings")
	check(not enabled_candidate or int(app.motion_audio.played.get(&"motion_heavy",0))==2,"one heavy cue per accepted high landing,no legacy duplicate")
	check(not enabled_candidate or int(app.motion_audio.played.get(&"jump",0))==0,"old jump cue suppressed only for this active task consumer")
	await finish()

func finish() -> void:
	var data := {"checks":checks,"errors":errors,"rows":rows,"events":events,"candidate_enabled":enabled_candidate,"scope":"Real unmodified Home spawn/terraces/Router/Motor,two192wu safe drops and immediate recovery jump.No actor placement/physics/HP/resources/grants changes.Camera/input transforms unchanged;screen shader only.","audio_events":app.motion_audio.motion_events if is_instance_valid(app) and is_instance_valid(app.motion_audio) else []}
	if is_instance_valid(app):
		check(await load("res://tests/audio_teardown.gd").drain_world(app),"all shared audio voices actually release")
		app.free()
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	data["checks"] = checks
	data["errors"] = errors
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	for unused: int in 4: await process_frame
	for error:String in errors: printerr(error)
	print("FEEL TRACE: samples=",rows.size()," checks=",checks," errors=",errors.size())
	quit(0 if errors.is_empty() else 1)
