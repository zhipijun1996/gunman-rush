extends RefCounted
## Input-only traversal shared by isolated and complete generated world proofs.
var module: PlatformingModule
var motor: PlayerMotor
var controller: PlayerController
var tick: Callable
var check: Callable
var latch: ShotLatch
var aim_offset := 0.0

func traverse(p_module: PlatformingModule, p_motor: PlayerMotor, p_tick: Callable, p_check: Callable, p_latch: ShotLatch, combo := false, angle := 0.0) -> bool:
	module = p_module
	motor = p_motor
	controller = motor.get_node("Controller") as PlayerController
	tick = p_tick
	check = p_check
	latch = p_latch
	aim_offset = angle
	var before := controller.shoot_ability._shot_serial
	check.call(is_instance_valid(latch) and not latch.is_open, "generated windchime starts with its real linked gate closed")
	if not is_instance_valid(latch): return false
	if module.definition.module_id == &"plains_windchime_ferry":
		return await load("res://tests/challenge_ferry_tests.gd").new().traverse(module,motor,tick,check,latch)
	if module.definition.module_id in [&"plains_windchime_lesson", &"plains_windchime_sequence", &"plains_windchime_timed"]:
		if not await move_to(_x(140)): return false
		controller.router.request_action(&"shoot_release", _aim_at(latch.bell_body.global_position).rotated(angle))
		await tick.call(30)
		if not await land(): return false
		if module.definition.module_id == &"plains_windchime_sequence":
			check.call(latch.sequence_step == 1 and not latch.is_open,"first actual bell preserves closed gate until second in visible order")
			if not await move_to(_x(210)): return false
			controller.router.request_action(&"shoot_release", _aim_at(latch._second_body.global_position).rotated(angle))
			await tick.call(30)
			if not await land(): return false
	else:
		if not await move_to(_x(277)): return false
		if combo:
			controller.router.set_move_axis(_forward())
			controller.router.request_action(&"jump")
			await tick.call(14)
			var height := motor.global_position.y
			controller.router.request_action(&"shoot_release", _aim_at(latch.bell_body.global_position).rotated(angle))
			await tick.call(10)
			check.call(latch.is_open and motor.global_position.y < height - 100, "same actual downward projectile opens well gate and recoils player upward")
			controller.router.request_action(&"jump_release")
		else:
			controller.router.request_action(&"shoot_release", _aim_at(latch.bell_body.global_position).rotated(angle))
			await tick.call(30)
			if not await land() or not await move_to(_x(250)): return false
			controller.router.set_move_axis(_forward())
			controller.router.request_action(&"jump")
			await tick.call(8)
	check.call(latch.is_open and latch.open_count == 1, "real shot collision opens the intended physical gate exactly once")
	if not latch.is_open: return false
	if not await move_to(module.world_exit().x, 200) or not await land(): return false
	check.call(controller.shoot_ability._shot_serial == before + (2 if module.definition.module_id == &"plains_windchime_sequence" else 1), "windchime route consumes its exact actual shot budget")
	check.call(motor.global_position.distance_to(module.world_exit()) < 1 and motor.is_on_floor(), "windchime reaches exact authored grounded exit")
	return motor.global_position.distance_to(module.world_exit()) < 1 and motor.is_on_floor()

func _x(value: float) -> float:
	return module.global_position.x + (module.definition.world_bounds.position.x + module.definition.world_bounds.end.x - value if module.definition.mirrored_horizontal else value)
func _forward() -> float:
	return signf(module.world_exit().x - module.world_entry().x)
func move_to(target: float, budget := 200) -> bool:
	for unused: int in budget:
		controller.router.set_move_axis(clampf((target - motor.global_position.x) / 5.5, -1, 1))
		await tick.call(1)
		if absf(target - motor.global_position.x) < .6:
			controller.router.set_move_axis(0)
			await tick.call(2)
			return true
	return false
func land() -> bool:
	controller.router.set_move_axis(0)
	for unused: int in 120:
		if motor.is_on_floor():
			await tick.call(3)
			return true
		await tick.call(1)
	return false

func _aim_at(target: Vector2) -> Vector2:
	# Real pointer basis; retain the original +/-0.05 rad angle perturbations,
	# same-shot bell/recoil, one jump, exact shot budget and no-hazard assertions.
	return (motor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter).world_direction(motor.get_canvas_transform()*target)
