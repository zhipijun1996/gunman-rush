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
	if _callback_is_trace_cancelled(p_tick): return false
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
		var _cancel_await_23: bool = await load("res://tests/challenge_ferry_tests.gd").new().traverse(module,motor,tick,check,latch)
		if is_trace_cancelled(): return false
		return _cancel_await_23
	if module.definition.module_id in [&"plains_windchime_lesson", &"plains_windchime_sequence", &"plains_windchime_timed"]:
		var _cancel_await_25: bool = not await move_to(_x(140))
		if is_trace_cancelled(): return false
		if _cancel_await_25: return false
		controller.router.request_action(&"shoot_release", _aim_at(latch.bell_body.global_position).rotated(angle))
		await tick.call(30)
		if is_trace_cancelled(): return false
		var _cancel_await_28: bool = not await land()
		if is_trace_cancelled(): return false
		if _cancel_await_28: return false
		if module.definition.module_id == &"plains_windchime_sequence":
			check.call(latch.sequence_step == 1 and not latch.is_open,"first actual bell preserves closed gate until second in visible order")
			var _cancel_await_31: bool = not await move_to(_x(210))
			if is_trace_cancelled(): return false
			if _cancel_await_31: return false
			controller.router.request_action(&"shoot_release", _aim_at(latch._second_body.global_position).rotated(angle))
			await tick.call(30)
			if is_trace_cancelled(): return false
			var _cancel_await_34: bool = not await land()
			if is_trace_cancelled(): return false
			if _cancel_await_34: return false
	else:
		var _cancel_await_36: bool = not await move_to(_x(277))
		if is_trace_cancelled(): return false
		if _cancel_await_36: return false
		if combo:
			controller.router.set_move_axis(_forward())
			controller.router.request_action(&"jump")
			await tick.call(14)
			if is_trace_cancelled(): return false
			var height := motor.global_position.y
			controller.router.request_action(&"shoot_release", _aim_at(latch.bell_body.global_position).rotated(angle))
			await tick.call(10)
			if is_trace_cancelled(): return false
			check.call(latch.is_open and motor.global_position.y < height - 100, "same actual downward projectile opens well gate and recoils player upward")
			controller.router.request_action(&"jump_release")
		else:
			controller.router.request_action(&"shoot_release", _aim_at(latch.bell_body.global_position).rotated(angle))
			await tick.call(30)
			if is_trace_cancelled(): return false
			var _cancel_await_49: bool = not await land()
			if is_trace_cancelled(): return false
			if not _cancel_await_49:
				_cancel_await_49 = not await move_to(_x(250))
				if is_trace_cancelled(): return false
			if _cancel_await_49: return false
			controller.router.set_move_axis(_forward())
			controller.router.request_action(&"jump")
			await tick.call(8)
			if is_trace_cancelled(): return false
	check.call(latch.is_open and latch.open_count == 1, "real shot collision opens the intended physical gate exactly once")
	if not latch.is_open: return false
	var _cancel_await_55: bool = not await move_to(module.world_exit().x, 200)
	if is_trace_cancelled(): return false
	if not _cancel_await_55:
		_cancel_await_55 = not await land()
		if is_trace_cancelled(): return false
	if _cancel_await_55: return false
	check.call(controller.shoot_ability._shot_serial == before + (2 if module.definition.module_id == &"plains_windchime_sequence" else 1), "windchime route consumes its exact actual shot budget")
	check.call(motor.global_position.distance_to(module.world_exit()) < 1 and motor.is_on_floor(), "windchime reaches exact authored grounded exit")
	return motor.global_position.distance_to(module.world_exit()) < 1 and motor.is_on_floor()

func _x(value: float) -> float:
	return module.global_position.x + (module.definition.world_bounds.position.x + module.definition.world_bounds.end.x - value if module.definition.mirrored_horizontal else value)
func _forward() -> float:
	return signf(module.world_exit().x - module.world_entry().x)
func move_to(target: float, budget := 200) -> bool:
	if is_trace_cancelled(): return false
	for unused: int in budget:
		controller.router.set_move_axis(clampf((target - motor.global_position.x) / 5.5, -1, 1))
		await tick.call(1)
		if is_trace_cancelled(): return false
		if absf(target - motor.global_position.x) < .6:
			controller.router.set_move_axis(0)
			await tick.call(2)
			if is_trace_cancelled(): return false
			return true
	return false
func land() -> bool:
	if is_trace_cancelled(): return false
	controller.router.set_move_axis(0)
	for unused: int in 120:
		if motor.is_on_floor():
			await tick.call(3)
			if is_trace_cancelled(): return false
			return true
		await tick.call(1)
		if is_trace_cancelled(): return false
	return false

func _aim_at(target: Vector2) -> Vector2:
	# Real pointer basis; retain the original +/-0.05 rad angle perturbations,
	# same-shot bell/recoil, one jump, exact shot budget and no-hazard assertions.
	return (motor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter).world_direction(motor.get_canvas_transform()*target)

func _callback_is_trace_cancelled(callback: Callable) -> bool:
	if not callback.is_valid(): return false
	var owner := callback.get_object()
	return is_instance_valid(owner) and owner.has_method("is_trace_cancelled") and bool(owner.call("is_trace_cancelled"))

func is_trace_cancelled() -> bool:
	return _callback_is_trace_cancelled(tick)
