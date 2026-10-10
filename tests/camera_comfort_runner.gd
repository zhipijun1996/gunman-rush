extends SceneTree
const PLAYER := preload("res://scenes/player/player.tscn")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node2D.new()
	root.add_child(world)
	var motor: PlayerMotor = PLAYER.instantiate()
	world.add_child(motor)
	var controller: PlayerController = motor.get_node("Controller")
	controller.set_physics_process(false)
	var camera := StageCameraRig.new()
	world.add_child(camera)
	camera.set_physics_process(false)
	camera.configure(motor, Rect2(-10000, -10000, 20000, 20000))
	var start := camera.global_position
	for tick: int in 120:
		camera.advance_follow(Vector2(sin(tick * 0.1) * 20, sin(tick * 0.1) * 45), 0, 300, 1.0 / 60)
	check(camera.global_position.distance_to(start) < 0.001, "dead zone holds small movements without camera bob")
	var ends: Array[Vector2] = []
	for fps: int in [30, 60, 120]:
		camera.snap_to_target()
		for tick: int in fps:
			camera.advance_follow(Vector2(160, -100), 0, 300, 1.0 / fps)
		ends.append(camera.global_position)
	check(ends[0].distance_to(ends[2]) < 0.01, "exact damping converges identically at 30/60/120 Hz for held target")
	camera.snap_to_target()
	var old_center := start
	var old_look := 0.0
	var peak_old := 0.0
	var peak_new := 0.0
	# Actual Motor ballistic jump and recoil, with the previous camera as a baseline.
	controller.router.request_action(&"jump")
	motor.normal_velocity.y = -666
	for tick: int in 100:
		await physics_frame
		if tick == 12:
			check(controller.shoot_ability.try_fire(Vector2.DOWN, false), "actual airborne recoil fires")
		var dt := 1.0 / 60.0
		motor.step(0.0, dt)
		var before := camera.global_position
		camera._physics_process(dt)
		var blend := 1.0 - exp(-8.0 * dt)
		old_look = lerpf(old_look, clampf((motor.normal_velocity.x + motor.recoil_velocity.x) / 300, -1, 1) * 130, blend)
		var next_old := old_center.lerp(motor.global_position + Vector2(old_look, -80), blend)
		# Measure ascent only; indefinite freefall intentionally hits the safety frame.
		if tick < 35:
			peak_old = maxf(peak_old, absf(next_old.y - old_center.y) / dt)
			peak_new = maxf(peak_new, absf(camera.global_position.y - before.y) / dt)
		old_center = next_old
		check(absf(motor.global_position.y - camera.global_position.y) <= 720 / 3.9 - 47.9, "burst/fall preserves vertical actor visibility")
	check(peak_new < peak_old, "airborne recoil ascent peak camera speed reduced against old algorithm")
	print("CAMERA ascent peak world units/s: old=%.2f new=%.2f" % [peak_old, peak_new])
	# Run, reverse, then stop: lookahead changes at a fixed rate and settles.
	motor.reset_at(Vector2.ZERO)
	camera.snap_to_target()
	var point := Vector2.ZERO
	for tick: int in 360:
		var speed := 300.0 if tick < 120 else (-300.0 if tick < 240 else 0.0)
		var dt := (0.2 if tick >= 180 and tick < 240 else 1.0) / 60.0
		point.x += speed * dt
		var previous_ahead := camera._lookahead
		camera.advance_follow(point, speed, 300, dt)
		check(absf(camera._lookahead - previous_ahead) <= camera.lookahead_speed * dt + 0.001, "reverse/focus lookahead has no impulse")
		check(absf(point.x - camera.global_position.x) < 1280 / 3.9 - 47.9, "run/reversal player remains visible")
	check(camera._spring_velocity.length() < 0.1, "stop settles without perpetual drift")
	motor.reset_at(Vector2.ZERO)
	camera.snap_to_target()
	motor.recoil_velocity = Vector2(1100, 0)
	camera._physics_process(1.0 / 60)
	check(is_zero_approx(camera._lookahead), "recoil cannot flip or drive lookahead")
	controller.return_to_segment(Vector2(4000, -2000))
	camera._physics_process(1.0 / 60)
	check(camera.global_position == camera.bounded_center(motor.global_position + Vector2(0, -80)), "segment return cuts directly to safe spawn")
	check(camera._spring_velocity == Vector2.ZERO, "respawn clears residual camera momentum")
	camera.snap_to_target()
	var ahead := camera._lookahead
	camera.advance_follow(motor.global_position, 300, 300, 0.02)
	check(camera._lookahead - ahead <= 1.501, "lookahead slew bounded")
	var held := camera.global_position
	camera.advance_follow(motor.global_position + Vector2(1000, 0), 300, 300, 0)
	check(camera.global_position == held, "pause does not move camera")
	camera.world_bounds = Rect2(0, 0, 100, 100)
	check(camera.bounded_center(Vector2(800, 800)) == Vector2(50, 50), "small rooms remain centered")
	if "--prove-failure" in OS.get_cmdline_user_args():
		check(false, "intentional failure verifies exit status")
	world.free()
	print("CAMERA COMFORT: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
