extends "res://tests/branch_library_runner.gd"
## Practical timing/aim tolerance, using actual Motor and continuous hazard sweep.
func _run() -> void:
	for mirrored: bool in [false, true]:
		for delay: int in range(12, 31):
			for angle: float in [-10.0, 0.0, 10.0]:
				await fixture("plains_recoil_step", mirrored, 0)
				var driver = load("res://tests/branch_module_driver.gd").new()
				driver.rise_shot_delay = delay
				driver.rise_shot_direction = Vector2.DOWN.rotated(deg_to_rad(angle))
				var label := "190px rise mirror=%s release=%d aim=%s" % [mirrored, delay, angle]
				check(await driver.traverse(module, motor, tick, check), label + " one-jump / one-shot route completes")
				await finish(label, module.world_exit(), 1)
		await fixture("plains_recoil_step", mirrored, 0)
		var driver = load("res://tests/branch_module_driver.gd").new()
		driver.module = module
		driver.motor = motor
		driver.controller = controller
		driver.tick_callback = tick
		driver.check = check
		await driver.move_to(driver._world_x(170))
		controller.router.set_move_axis(driver._forward())
		controller.router.request_action(&"jump")
		var peak := motor.global_position.y
		for frame: int in 65:
			await tick()
			peak = minf(peak, motor.global_position.y)
		check(peak > module.world_exit().y + 30, "held single jump alone has at least 30px deficit: recoil still required")
		check(shots == 0, "negative control emits no projectile")
	if is_instance_valid(world): world.free()
	if "--intentional-failure" in OS.get_cmdline_user_args(): check(false, "nonzero exit proof")
	print("PLAINS RECOIL MARGIN: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
