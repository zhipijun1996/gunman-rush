extends RefCounted
## Action-only trace helpers. The consumer supplies ticking and full-body sweeps.
var module: PlatformingModule
var motor: PlayerMotor
var controller: PlayerController
var tick_callback: Callable
var check: Callable
var shot_count := 0
var rise_shot_delay := 18
var rise_shot_direction := Vector2.DOWN

func traverse(p_module: PlatformingModule, p_motor: PlayerMotor, p_tick: Callable, p_check: Callable) -> bool:
	module = p_module
	motor = p_motor
	controller = motor.get_node("Controller") as PlayerController
	tick_callback = p_tick
	check = p_check
	shot_count = 0
	var count_shot := func(_direction: Vector2, _id: int): shot_count += 1
	controller.shoot_ability.shot_fired.connect(count_shot)
	var result := false
	var id := str(module.definition.module_id)
	if id == "plains_recovery_bridge":
		result = await load("res://tests/recoil_recovery_tests.gd").new().traverse(module, motor, tick_callback, check)
	elif id in ["plains_ferry_one", "plains_ferry_two"]:
		result = await load("res://tests/challenge_ferry_tests.gd").new().traverse(module, motor, tick_callback, check)
	elif id in ["plains_recoil_step", "plains_recoil_double"]:
		result = await recoil_rises(1 if id == "plains_recoil_step" else 2)
	elif id in ["plains_recoil_chasm", "plains_recoil_chasm_wide"]:
		result = await recoil_chasm()
	elif id in ["plains_gear_brook", "plains_gear_glade"]:
		result = await gear_hop()
	elif not module.definition.main_route.is_empty():
		result = await path(module.definition.main_route)
	else:
		result = await move_to(module.world_exit().x)
	controller.shoot_ability.shot_fired.disconnect(count_shot)
	if result:
		controller.router.set_move_axis(0)
		await advance(3)
		check.call(motor.is_on_floor() and motor.global_position.distance_to(module.world_exit()) < 1, id + " actual exit has full-body standing support")
	return result

func follow_path(p_module: PlatformingModule, p_motor: PlayerMotor, p_tick: Callable, p_check: Callable, route: Variant) -> bool:
	module = p_module
	motor = p_motor
	controller = motor.get_node("Controller") as PlayerController
	tick_callback = p_tick
	check = p_check
	return await path(route)

func advance(count := 1) -> void:
	await tick_callback.call(count)

func move_to(x: float, budget := 310) -> bool:
	for unused: int in budget:
		controller.router.set_move_axis(clampf((x - motor.global_position.x) / 5.5, -1, 1))
		await advance()
		if absf(x - motor.global_position.x) < 0.6:
			controller.router.set_move_axis(0)
			await advance(2)
			return true
	return false

func land(budget := 110) -> bool:
	controller.router.set_move_axis(0)
	for unused: int in budget:
		if motor.is_on_floor():
			await advance(3)
			return true
		await advance()
	return false

func jump_to(target: Vector2) -> bool:
	controller.router.request_action(&"jump")
	for frame: int in 110:
		controller.router.set_move_axis(clampf((target.x - motor.global_position.x) / 5.5, -1, 1))
		await advance()
		if frame > 3 and motor.is_on_floor():
			controller.router.request_action(&"jump_release")
			controller.router.set_move_axis(0)
			await advance(2)
			var success := absf(target.y - motor.global_position.y) < 1 and _floor_contains_segment(motor.global_position - module.global_position, target - module.global_position)
			if success:
				success = await move_to(target.x)
			if not success:
				print("BRANCH PATH FAILED id=%s target=%s actual=%s" % [module.definition.module_id, target, motor.global_position])
			return success
	return false

func _floor_contains_segment(a: Vector2, b: Vector2) -> bool:
	if absf(a.y - b.y) > 0.1:
		return false
	var covered := minf(a.x, b.x)
	var end := maxf(a.x, b.x)
	var floors: Array[Rect2] = module.definition.platforms.duplicate()
	floors.sort_custom(func(first: Rect2, second: Rect2): return first.position.x < second.position.x)
	for floor_rect: Rect2 in floors:
		if absf(floor_rect.position.y - a.y - 18) < 0.1 and floor_rect.position.x <= covered and floor_rect.end.x > covered:
			covered = floor_rect.end.x
	return covered >= end

func path(route: Variant) -> bool:
	for step: int in range(1, route.size()):
		var previous := module.definition.anchors[route[step - 1]]
		var target := module.definition.anchors[route[step]]
		if _floor_contains_segment(previous, target):
			if not await move_to(module.position.x + target.x): return false
		else:
			var direction := signf(target.x - previous.x)
			var takeoff := previous.x
			for floor_rect: Rect2 in module.definition.platforms:
				if absf(floor_rect.position.y - previous.y - 18) < 0.1 and floor_rect.has_point(previous + Vector2(0, 19)):
					takeoff = floor_rect.end.x - 40 if direction > 0 else floor_rect.position.x + 40
					if floor_rect.size.x > 400: takeoff = previous.x + direction * 20
					break
			if not await move_to(module.position.x + takeoff): return false
			var reached := await jump_to(module.to_global(target))
			check.call(reached, "authored path uses actual jump for a rise or separated equal-height floor")
			if not reached: return false
		check.call(motor.is_on_floor() and absf(motor.global_position.y - module.position.y - target.y) < 1, "authored receiver has exact grounded height")
	return true

func recoil_rises(legs: int) -> bool:
	var pairs := [Vector2(170, 400), Vector2(430, 640)]
	for leg: int in legs:
		var pair: Vector2 = pairs[leg]
		if not await move_to(_world_x(pair.x)): return false
		controller.router.set_move_axis(_forward())
		controller.router.request_action(&"jump")
		await advance(rise_shot_delay)
		var before := shot_count
		controller.router.request_action(&"shoot_release", rise_shot_direction)
		await advance()
		check.call(shot_count == before + 1 and motor.recoil_burst_remaining > 0 and controller.action_resources.shot_charges == motor.tuning.max_air_shots - 1, "authored rise consumes one real downward projectile and creates upward burst")
		await advance(9)
		controller.router.request_action(&"jump_release")
		if not await move_to(_world_x(pair.y), 100) or not await land(): return false
		check.call(controller.action_resources.shot_charges == motor.tuning.max_air_shots and controller.jump_ability.used_jumps == 0, "high receiver restores charges only on real floor landing")
	check.call(shot_count == legs, "rise emits exactly one projectile per authored ascent")
	return await move_to(module.world_exit().x)

func recoil_chasm() -> bool:
	if not await move_to(_world_x(240)): return false
	controller.router.set_move_axis(_forward())
	controller.router.request_action(&"jump")
	await advance(18)
	controller.router.request_action(&"shoot_release", Vector2.LEFT * _forward())
	await advance()
	check.call(shot_count == 1 and motor.recoil_burst_remaining > 0, "wide chasm first release starts a real horizontal burst")
	await advance(16)
	controller.router.request_action(&"shoot_release", Vector2.LEFT * _forward())
	await advance()
	check.call(shot_count == 2 and motor.recoil_burst_remaining > 0, "wide chasm second burst respects actual shot cooldown")
	await advance(9)
	controller.router.request_action(&"jump_release")
	controller.router.request_action(&"jump")
	await advance()
	check.call(controller.jump_ability.used_jumps == 2 and motor.normal_velocity.y < 0, "wide chasm uses configured second jump instead of invented airtime")
	var target := 990.0 if module.definition.module_id == &"plains_recoil_chasm_wide" else 930.0
	if not await move_to(_world_x(target), 140) or not await land(): return false
	controller.router.request_action(&"jump_release")
	check.call(shot_count == 2, "wide chasm emits exactly two real projectiles")
	return await move_to(module.world_exit().x)

func no_recoil_chasm_falls(p_module: PlatformingModule, p_motor: PlayerMotor, p_tick: Callable, p_check: Callable) -> bool:
	module = p_module
	motor = p_motor
	controller = motor.get_node("Controller") as PlayerController
	tick_callback = p_tick
	check = p_check
	shot_count = 0
	var count_shot := func(_direction: Vector2, _id: int): shot_count += 1
	controller.shoot_ability.shot_fired.connect(count_shot)
	if not await move_to(_world_x(240)):
		controller.shoot_ability.shot_fired.disconnect(count_shot)
		return false
	controller.router.request_action(&"jump")
	controller.router.set_move_axis(_forward())
	await advance(38)
	controller.router.request_action(&"jump_release")
	controller.router.request_action(&"jump")
	await advance()
	check.call(controller.jump_ability.used_jumps == 2, "negative chasm genuinely uses normal second jump with unchanged default jump physics")
	var missed := false
	var far_bank := 920.0 if module.definition.module_id == &"plains_recoil_chasm_wide" else 860.0
	for unused: int in 100:
		await advance()
		if motor.global_position.y > module.world_entry().y + 80 and not motor.is_on_floor():
			missed = _forward() * (motor.global_position.x - _world_x(far_bank)) < -12
			break
	controller.router.set_move_axis(0)
	controller.shoot_ability.shot_fired.disconnect(count_shot)
	check.call(shot_count == 0, "negative normal-double-jump trace emits no projectiles")
	print("CHASM NO RECOIL: id=%s pos=%s receiver=%s missed=%s" % [module.definition.module_id, motor.global_position, _world_x(far_bank), missed])
	return missed

func gear_hop() -> bool:
	var saw := module.definition.saws[0]
	var takeoff := saw.origin.x - 90 * _forward()
	var receiver := saw.origin.x + 90 * _forward()
	if not await move_to(module.position.x + takeoff): return false
	if not await jump_to(module.to_global(Vector2(receiver, module.definition.entry_port.position.y))): return false
	return await move_to(module.world_exit().x)

func _forward() -> float:
	return -1 if module.definition.mirrored_horizontal else 1

func _world_x(authored: float) -> float:
	var sum := module.definition.world_bounds.position.x + module.definition.world_bounds.end.x
	return module.position.x + (sum - authored if module.definition.mirrored_horizontal else authored)
