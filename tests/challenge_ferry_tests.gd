extends "res://tests/dynamic_module_tests.gd"

# Reused by a genuinely assembled whole-stage Motor trace. The callback retains
# that consumer's full-body hazard sweeps; no helper translates the player.
func traverse(p_module: PlatformingModule, p_motor: PlayerMotor, p_tick: Callable, p_check: Callable) -> bool:
	var p_controller := p_motor.get_node("Controller") as PlayerController
	var stations: Array[Vector2] = [Vector2(150, 932), Vector2(710, 682), Vector2(360, 380)]
	var receivers: Array[Vector2] = [Vector2(680, 682), Vector2(390, 380), Vector2(840, 78)]
	if p_module.definition.mirrored_horizontal:
		var reflection_x := p_module.definition.world_bounds.position.x + p_module.definition.world_bounds.end.x
		for index: int in stations.size():
			stations[index].x = reflection_x - stations[index].x
			receivers[index].x = reflection_x - receivers[index].x
	for index: int in p_module.moving_platforms.size():
		var carrier: ModuleMovingPlatform = p_module.moving_platforms[index]
		var station := p_module.to_global(stations[index])
		var receiver := p_module.to_global(receivers[index])
		var approached := await _approach(p_motor, p_tick, station.x)
		p_check.call(approached and p_motor.is_on_floor(), "ascent %d reaches grounded safe boarding bank" % index)
		if not approached:
			return false
		var start := p_module.to_global(carrier.definition.start)
		var finish := p_module.to_global(carrier.definition.finish)
		var boarded := false
		for unused: int in 650:
			if carrier.global_position.distance_to(start) < 2.0:
				boarded = true
				break
			await p_tick.call(1)
		p_check.call(boarded, "ascent %d bounded wait finds boarding dwell" % index)
		if not boarded:
			return false
		p_controller.router.request_action(&"jump")
		var landed := false
		for frame: int in 100:
			p_controller.router.set_move_axis(clampf((carrier.global_position.x - p_motor.global_position.x) / 5.5, -1.0, 1.0))
			await p_tick.call(1)
			var feet := p_motor.global_position.y + 18.0
			if frame > 5 and p_motor.is_on_floor() and absf(feet - (carrier.global_position.y - carrier.definition.size.y / 2)) < 3.0:
				landed = true
				break
		p_controller.router.request_action(&"jump_release")
		p_controller.router.set_move_axis(0.0)
		await p_tick.call(3)
		p_check.call(landed, "ascent %d one actual held jump boards moving AnimatableBody" % index)
		if not landed:
			return false
		var relative := p_motor.global_position - carrier.global_position
		var ride_start := p_motor.global_position
		var max_drift := 0.0
		var engine_carry := false
		var arrived := false
		for unused: int in 260:
			await p_tick.call(1)
			max_drift = maxf(max_drift, (p_motor.global_position - carrier.global_position - relative).length())
			engine_carry = engine_carry or p_motor.get_platform_velocity().length() > 20.0
			if carrier.global_position.distance_to(finish) < 2.0:
				arrived = true
				break
		p_check.call(arrived and ride_start.y - p_motor.global_position.y > 100.0, "ascent %d neutral-input ride gains real vertical height" % index)
		p_check.call(max_drift < 5.0 and engine_carry and absf(p_motor.normal_velocity.x) < 0.01, "ascent %d Motor uses engine carrying without player teleport or idle sliding" % index)
		if not arrived:
			return false
		p_controller.router.request_action(&"jump")
		var received := false
		for frame: int in 100:
			p_controller.router.set_move_axis(clampf((receiver.x - p_motor.global_position.x) / 5.5, -1.0, 1.0))
			await p_tick.call(1)
			if frame > 5 and p_motor.is_on_floor() and absf(p_motor.global_position.y - receiver.y) < 3.0:
				received = true
				break
		p_controller.router.request_action(&"jump_release")
		p_controller.router.set_move_axis(0.0)
		await p_tick.call(3)
		p_check.call(received, "ascent %d lands on next stationary recovery bank" % index)
		if not received:
			return false
	return await _approach(p_motor, p_tick, p_module.world_exit().x)

func _approach(p_motor: PlayerMotor, p_tick: Callable, x: float) -> bool:
	var p_controller := p_motor.get_node("Controller") as PlayerController
	for unused: int in 300:
		p_controller.router.set_move_axis(clampf((x - p_motor.global_position.x) / 5.5, -1.0, 1.0))
		await p_tick.call(1)
		if absf(x - p_motor.global_position.x) < 0.6:
			p_controller.router.set_move_axis(0.0)
			await p_tick.call(3)
			return true
	return false

func run(p_tree: SceneTree, p_check: Callable) -> void:
	tree = p_tree
	check = p_check
	for phase: float in [0.0, 0.25]:
		await fixture("challenge_ferry_ascent", phase, 1)
		for carrier: ModuleMovingPlatform in module.moving_platforms:
			carrier.definition.initial_phase = phase
		await tick(2)
		var label := "vertical ferry phase %.2f" % phase
		check.call(module.definition.is_valid() and module.definition.supports(motor.tuning), label + " typed definition supports one jump and zero shots")
		check.call(module.world_entry().y - module.world_exit().y > 800.0, label + " route climbs a genuinely tall zigzag space")
		for anchor: Vector2 in module.world_anchors():
			check.call(respawn.is_safe(anchor), label + " static recovery anchor has full-body clearance and support")
		check.call(await traverse(module, motor, tick, check), label + " continuous action-only route completes three real carriers")
		await finish(label)
	world.free()
