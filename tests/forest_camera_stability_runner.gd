extends SceneTree
## Real Motor jump/landing fixture; authored observation focus must not toggle the view.
const PLAYER := preload("res://scenes/player/player.tscn")
const DT := 1.0 / 60.0
var checks := 0
var failures := 0
var world: Node2D
var motor: PlayerMotor
var controller: PlayerController
var camera: StageCameraRig
var samples: Array[Dictionary] = []
var baseline_mode := "--baseline-camera" in OS.get_cmdline_user_args()

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func tick() -> void:
	await physics_frame
	controller.physics_tick(DT)
	camera._physics_process(DT)
	samples.append({"body":[motor.position.x,motor.position.y],"camera":[camera.position.x,camera.position.y],"grounded":motor.is_on_floor(),"zoom":camera.zoom.y})

func run() -> void:
	root.size = Vector2i(1280,720)
	world = Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(4000,40)
	collision.shape = shape
	floor_body.position.y = 200
	floor_body.add_child(collision)
	world.add_child(floor_body)
	motor = PLAYER.instantiate()
	motor.position = Vector2(0,162)
	world.add_child(motor)
	controller = motor.get_node("Controller")
	controller.set_physics_process(false)
	camera = StageCameraRig.new()
	world.add_child(camera)
	camera.set_physics_process(false)
	camera.use_stable_forest_view()
	camera.region_composition = true
	if baseline_mode:
		# Reproduce main's pre-fix presentation only; the same real body/input runs.
		camera.stable_vertical_follow = false
		camera.dead_zone.y = 12.0
		camera.vertical_lower_zone = 72.0
		camera.response_time = Vector2(0.12,0.05)
	camera.configure(motor,Rect2(-4000,-4000,8000,8000))
	if baseline_mode: camera.zoom = Vector2.ONE*camera.viewing_zoom
	# Forest-specific zoom is part of the actual configure policy, not an extra cut.
	check(camera.zoom == Vector2.ONE * camera.viewing_zoom,"forest configure preserves its authored wide zoom")
	for unused: int in 120:
		await tick()
	check(motor.is_on_floor(),"actual Motor settled on real support")
	var standing := camera.position
	# This is the actual vertical expedition observation offset, previously applied
	# only on ground and removed on the very first airborne physics frame.
	camera.observation_focus = motor.position + Vector2(40,-320)
	for unused: int in 60:
		await tick()
	check(camera.position.distance_to(standing) < 0.1,"automatic observation hint does not pan the stable forest view")
	var start := camera.position
	var apex := motor.position.y
	var previous := camera.position
	var peak_step := 0.0
	var peak_camera_excursion := 0.0
	var airborne := false
	controller.router.set_jump_held(&"camera_test",true)
	for index: int in 100:
		if index == 2: controller.router.set_jump_held(&"camera_test",false)
		# Walking across a hint boundary and leaving the ground must both be smooth.
		if index == 7: camera.observation_focus = Vector2.INF
		await tick()
		airborne = airborne or not motor.is_on_floor()
		apex = minf(apex,motor.position.y)
		peak_step = maxf(peak_step,camera.position.distance_to(previous))
		peak_camera_excursion = maxf(peak_camera_excursion,absf(camera.position.y-start.y))
		check(camera.zoom == Vector2.ONE * camera.viewing_zoom,"jump and landing never alter camera zoom")
		previous = camera.position
	check(airborne and 162-apex > 35,"short jump actually left the ground and rose")
	check(motor.is_on_floor(),"short jump returned to the same real floor")
	check(peak_camera_excursion <= 12,"ordinary short jump keeps the world vertically stable")
	check(peak_step <= 6,"ground to air and hint exit have no abrupt camera impulse")
	check(camera.position.distance_to(start) <= 12,"landing does not recenter the entire screen")
	# The same stable policy still follows a genuine long recoil ascent and keeps
	# the full body visible. No body coordinates or resources are changed in flight.
	controller.router.set_jump_held(&"camera_test",true)
	var ascent_start := motor.position.y
	var ascent_camera := camera.position.y
	var climb := 0.0
	var follow := 0.0
	for index: int in 95:
		if index == 9:
			controller.router.set_jump_held(&"camera_test",false)
			controller.router.request_action(&"shoot_release",Vector2.DOWN)
		await tick()
		climb = maxf(climb,ascent_start-motor.position.y)
		follow = maxf(follow,ascent_camera-camera.position.y)
		var visible_margin := root.size.y/(2.0*camera.zoom.y)-48.0
		check(absf(motor.position.y-camera.position.y) <= visible_margin+0.01,"long jump and recoil retain full actor visibility")
	check(climb > 150 and follow > 20,"real sustained ascent still produces smooth vertical camera travel")
	var path := "res://build/forest_revision04/camera/"+("baseline.json" if baseline_mode else "trace.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"real_collision_jump_and_recoil_camera_fixture_not_device_approval","checks":checks,"failures":failures,"short_jump_excursion":peak_camera_excursion,"short_jump_peak_step":peak_step,"climb":climb,"follow":follow,"frames":samples}))
	file.close()
	world.free()
	await process_frame
	await process_frame
	if "--prove-failure" in OS.get_cmdline_user_args(): check(false,"intentional camera failure probe")
	print("FOREST CAMERA STABILITY: %d assertions, %d failures" % [checks,failures])
	quit(1 if failures else 0)
