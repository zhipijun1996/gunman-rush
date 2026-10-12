extends SceneTree
var assertions := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute("res://build/verification/camera-traces")
	var driver = load("res://tests/plains_camera_trace_driver.gd").new()
	driver.tree = self
	driver.check = check
	var data := PlainsStageGenerator.new().generate("polish-camera",5,&"combat",PlayerTuning.load_default())
	check(data.ok,"actual seeded multi-module route generates")
	if data.ok:
		driver.output = FileAccess.open("res://build/verification/camera-traces/polish-camera.csv",FileAccess.WRITE)
		driver.output.store_line("tick,actor_x,actor_y,camera_x,camera_y,anchor_x,anchor_y,session,landings,bounds_clamp,safety_correction,grounded")
		await driver.route(data.manifest,PlayerTuning.load_default(),"camera5 fixed Seed actual upper/lower")
		driver.output.close()
	if is_instance_valid(driver.world): driver.world.free()
	var boss_camera := StageCameraRig.new()
	root.add_child(boss_camera)
	boss_camera.zoom = Vector2.ONE * boss_camera.viewing_zoom
	boss_camera.world_bounds = Rect2(0,-800,2000,1450)
	boss_camera.route_focus = Vector2(1000,452)
	boss_camera._anchor = Vector2(800,200)
	boss_camera.global_position = boss_camera._anchor
	for unused: int in 300: boss_camera.advance_follow(Vector2(800,452),0,260,1.0/60)
	var bridge_screen_y := 360 + (452 - boss_camera.global_position.y) * boss_camera.zoom.y
	var guardian_foot_screen_y := 360 + (582 - boss_camera.global_position.y) * boss_camera.zoom.y
	check(bridge_screen_y > 180 and bridge_screen_y < 560,"Boss bridge player stays below HUD and above controls")
	check(guardian_foot_screen_y < 700,"Tall guardian feet share the frame with bridge-height player")
	boss_camera.free()
	if "--failure-probe" in OS.get_cmdline_user_args(): check(false,"intentional camera failure probe")
	print("PLAINS CAMERA TRACE: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)
