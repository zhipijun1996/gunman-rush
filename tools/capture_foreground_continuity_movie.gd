extends SceneTree
## Real Home input, then live formal-world diagnostic camera sweeps. No route claim.
var app: DemoApp
var frame := 0
var phase := ""
var phase_frame := 0
var origin := Vector2.ZERO
var trace: Array[Dictionary] = []
var output := "res://build/foreground_continuity_08/movie_trace.json"
var smoke := false

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--trace="): output=arg.trim_prefix("--trace=")
		if arg=="--smoke":smoke=true
	start.call_deferred()

func start() -> void:
	app=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	await process_frame
	app._show_home()
	await process_frame
	app.home_scene.controller.router.activate_device(&"gamepad")
	phase="home_input"
	process_frame.connect(drive)

func drive() -> void:
	# Fresh input follows the completed render; retain the real Router TTL.
	await RenderingServer.frame_post_draw
	frame+=1;phase_frame+=1
	if phase=="loading": return
	if phase=="home_input":
		var controller:=app.home_scene.controller
		controller.router.set_move_axis(1 if phase_frame<410 else (-1 if phase_frame<650 else 0))
		if phase_frame in [100,270,460]:controller.router.request_action(&"jump")
		if phase_frame in [112,282,472]:controller.router.request_action(&"jump_release")
		if phase_frame%10==0:trace.append({"frame":frame,"phase":phase,"position":[controller.motor.position.x,controller.motor.position.y],"motion_steps":controller.motor.motion_steps,"foreground":foreground_receipt(app)})
		if smoke and phase_frame>=60:finish.call_deferred()
		elif phase_frame>=720: switch_map.call_deferred(1)
	else:
		var camera:=app._run_camera
		var t:=float(phase_frame)/720.0
		camera.position=origin+Vector2(sin(t*PI)*2600.0,-sin(t*TAU)*180.0)
		camera.force_update_scroll()
		if phase_frame%10==0:trace.append({"frame":frame,"phase":phase,"camera":[camera.position.x,camera.position.y],"seed":app.director.seed,"manifest":app.stage.generated.manifest.manifest_hash,"foreground":foreground_receipt(app)})
		if phase_frame>=720:finish.call_deferred()

func switch_map(index: int) -> void:
	phase="loading";phase_frame=0
	app.abandon_run()
	await load("res://tests/audio_teardown.gd").drain_world(app)
	app.free()
	await process_frame
	app=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	await process_frame
	if not app.start_debug_region(&"plains",index,"level-design-v2-baseline/08"):
		printerr("SPACE_MOVIE_FORMAL_ENTRY_FAILED");quit(1);return
	for i: int in 4:await process_frame
	app._run_camera.set_process(false);app._run_camera.set_physics_process(false)
	origin=app._run_camera.position
	phase="map_%d_camera_diagnostic"%index;phase_frame=0

func finish() -> void:
	phase="loading"
	process_frame.disconnect(drive)
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"task":"FOREGROUND-CONTINUITY-08","scope":"12s real Home Motor input; one 12s live-world outward/return camera diagnostic, not traversal; loading frames retained; no equal-input baseline movie","frames":trace},"  "))
	app.abandon_run();await load("res://tests/audio_teardown.gd").drain_world(app)
	app.free()
	for i: int in 4:await process_frame
	print("SPACE_MOVIE_DONE frames=%d trace=%d"%[frame,trace.size()])
	quit()

func foreground_receipt(node: Node) -> Dictionary:
	if node.get_script()!=null and str(node.get_script().resource_path).ends_with("underworld_foreground.gd"):return node.call("receipt")
	for child: Node in node.get_children():
		var found:=foreground_receipt(child)
		if not found.is_empty():return found
	return {}
