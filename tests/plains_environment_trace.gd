extends "res://tests/level_formal_trace.gd"
## Input-only traversal of the same resolved plan as collision and rendering.
var environment_phase := "full"
var environment_mutation := ""
var environment_route_contract: Dictionary = {}
var environment_cases: Array = []
var _points: Dictionary = {}
var _plan: Dictionary = {}
var _health := 0.0
var _session := 0

func attach(application: DemoApp, selected_strategy: String, wait_ticks: int, selected_policy: String = "blind_legacy") -> bool:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--environment-phase="): environment_phase = arg.trim_prefix("--environment-phase=")
		elif arg.begins_with("--environment-mutation="): environment_mutation = arg.trim_prefix("--environment-mutation=")
	if environment_phase not in ["probe", "full"] or environment_mutation not in ["", "no-gun"] or selected_strategy != "fast" or selected_policy != "blind_legacy": return false
	if not super.attach(application, selected_strategy, wait_ticks, selected_policy): return false
	var resolved: Variant = application.stage.get("environment_plan")
	if not resolved is Dictionary or not resolved.get("route_waypoints") is Array or not resolved.get("safe_stands") is Array: return false
	_plan = resolved.duplicate(true)
	if application.stage.generated.manifest.get("environment_plan") != _plan: return false
	for row: Variant in _plan.route_waypoints:
		if not row is Dictionary or not row.get("id") is String or _points.has(row.id): return false
		var point: Variant = row.get("position")
		if not point is Array or point.size() != 2: return false
		for coordinate: Variant in point:
			if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)): return false
		if row.get("intent") not in ["walk", "jump_recoil", "wait_hop", "observe", "arrive"]: return false
		var tolerance: Variant = row.get("tolerance")
		if not (tolerance is int or tolerance is float) or not is_finite(float(tolerance)) or float(tolerance) <= 0 or float(tolerance) > 22: return false
		if row.get("require_grounded") is not bool or row.get("direction") not in [-1, 1]: return false
		if row.has("wait_ticks") and (not row.wait_ticks is int or row.wait_ticks < 0 or row.wait_ticks > 180): return false
		_points[row.id] = row
	for key: String in ["route_forward", "route_return"]:
		if not _plan.get(key) is Array or _plan[key].is_empty(): return false
		for id: Variant in _plan[key]:
			if not id is String or not _points.has(id): return false
	environment_route_contract = {"phase": environment_phase, "mutation": environment_mutation, "plan": _plan.duplicate(true), "scope": "Actual resolved body-centre destinations guide real Router requests only; never assign player position, physics, resources or enemy state"}
	_health = controller.actor_resources.health.current
	_session = controller.session_id
	event("environment_route_contract", environment_route_contract)
	return true

func supported() -> bool:
	if not is_instance_valid(motor) or not motor.is_on_floor(): return false
	var shape := motor.get_node("CollisionShape2D") as CollisionShape2D
	var half := shape.shape.get_rect().size * .5
	for side: float in [-.9, 0, .9]:
		var feet := motor.global_position + Vector2(half.x * side, half.y)
		var query := PhysicsRayQueryParameters2D.create(feet + Vector2(0, -8), feet + Vector2(0, 12), motor.collision_mask, [motor.get_rid()])
		var hit := motor.get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector2).dot(Vector2.UP) < .7: return false
	return true

func settle(count: int) -> bool:
	controller.router.set_move_axis(0)
	for unused: int in count:
		await tick()
		if trace_cancelled() or not supported(): return false
	return true

func jump_towards(target: Vector2, recoil: bool) -> bool:
	if not supported(): return false
	var direction := signf(target.x - motor.global_position.x)
	var airborne := false
	controller.router.set_move_axis(direction)
	controller.router.request_action(&"jump")
	for frame: int in 180:
		controller.router.set_move_axis(clampf((target.x - motor.global_position.x) / 5.5, -1, 1))
		if recoil and environment_mutation != "no-gun" and frame == 18:
			controller.router.request_action(&"shoot_release", Vector2(-direction, 1).normalized())
		if frame == 28: controller.router.request_action(&"jump_release")
		await tick()
		if trace_cancelled() or _recovery_serial > 0: return false
		if not motor.is_on_floor(): airborne = true
		if airborne and motor.is_on_floor():
			controller.router.request_action(&"jump_release")
			return absf(motor.global_position.y - target.y) <= 22 and await move_to(target.x, 120) and await settle(12)
	return false

func visit(id: String) -> bool:
	var row: Dictionary = _points[id]
	var target := Vector2(row.position[0], row.position[1])
	current_edge = id
	var start := trace_ticks + 1
	var ok := false
	match str(row.intent):
		"walk", "arrive": ok = await move_to(target.x, 500) and await settle(maxi(12, int(row.get("wait_ticks", 12))))
		"jump_recoil": ok = await jump_towards(target, true)
		"wait_hop":
			ok = await settle(int(row.get("wait_ticks", 0)))
			if ok: ok = await jump_towards(target, false)
		"observe": ok = await move_to(target.x, 500) and await settle(int(row.get("wait_ticks", 90)))
	if trace_cancelled(): return false
	ok = ok and motor.global_position.distance_to(target) <= float(row.tolerance) and (not row.require_grounded or supported()) and controller.actor_resources.health.current == _health and controller.session_id == _session and _recovery_serial == 0
	var result := {"id": id, "intent": row.intent, "start_tick": start, "end_tick": trace_ticks, "passed": ok, "target": row.position, "position": SNAPSHOT.pair(motor.global_position), "grounded": motor.is_on_floor(), "supported": supported(), "health": controller.actor_resources.health.current, "session": controller.session_id}
	environment_cases.append(result)
	observed_edges.append({"id": id, "start_tick": start, "end_tick": trace_ticks, "reached": ok})
	event("environment_waypoint", result)
	return ok

func run_route() -> void:
	if environment_phase == "probe":
		current_edge = "initial_stand_probe"
		var ok := await settle(180)
		environment_cases.append({"id": current_edge, "start_tick": 1, "end_tick": trace_ticks, "passed": ok, "position": SNAPSHOT.pair(motor.global_position), "supported": supported()})
		observed_edges.append({"id": current_edge, "start_tick": 1, "end_tick": trace_ticks, "reached": ok})
		if not trace_cancelled(): finish(ok, "environment_probe_complete" if ok else "environment_initial_support_failed")
		return
	if not await settle(30):
		if not trace_cancelled(): finish(false, "environment_initial_support_failed")
		return
	for key: String in ["route_forward", "route_return"]:
		for id: String in _plan[key]:
			if not await visit(id):
				if not trace_cancelled(): finish(false, "environment_waypoint_failed/" + id)
				return
	if not trace_cancelled(): finish(true, "route_target_reached")
