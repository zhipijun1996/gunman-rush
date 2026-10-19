extends "res://tests/root_bell_formal_trace.gd"
## Real Router/Motor route on the explicit experimental stage. No world writes.
var spatial_phase := "full"
var spatial_mutation := ""
var spatial_cases: Array = []
var _spatial_start := 0
var _spatial_name := ""
var _starting_health := 0.0
var _starting_session := 0
var _saw_airborne := false
var spatial_route_contract: Dictionary = {}
var _route_waypoints: Dictionary = {}
var _route_failure_y := 0.0

func attach(application: DemoApp, selected_strategy: String, wait_ticks: int, selected_policy: String = "blind_legacy") -> bool:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--spatial-phase="): spatial_phase = arg.trim_prefix("--spatial-phase=")
		elif arg.begins_with("--spatial-mutation="): spatial_mutation = arg.trim_prefix("--spatial-mutation=")
	if spatial_phase not in ["probe", "full"] or spatial_mutation not in ["", "no-gun", "remove-recovery-bank"]: return false
	if not super.attach(application, selected_strategy, wait_ticks, selected_policy): return false
	# Consume the same realized contract as the polygon/camera consumers. Missing
	# route data is a setup failure, never an excuse to use old layout coordinates.
	var realized: Variant = application.stage.get("golden_manifest")
	if not realized is Dictionary or not realized.get("route_waypoints") is Dictionary: return false
	var points: Dictionary = realized.route_waypoints
	for key: String in ["entry", "takeoff", "recovery", "root_approach", "root_observe", "root_takeoff", "root_receiver", "root_pass", "gear_start", "gear_receiver", "lookback", "return_gear_takeoff", "return_root_takeoff", "return_primary_takeoff", "return_primary_receiver"]:
		var point: Variant = points.get(key)
		if not point is Array or point.size() != 2: return false
		for coordinate: Variant in point:
			if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)): return false
	var failure_y: Variant = realized.get("route_failure_y")
	if not (failure_y is int or failure_y is float) or not is_finite(float(failure_y)): return false
	_route_waypoints = points.duplicate(true)
	_route_failure_y = float(failure_y)
	spatial_route_contract = {"version": realized.get("version", ""), "contract_sha256": realized.get("contract_sha256", ""),
		"waypoints": _route_waypoints.duplicate(true), "failure_y": _route_failure_y,
		"scope": "x guides real Router input; waypoint y records intended position and never writes body state"}
	event("spatial_route_contract", spatial_route_contract)
	_enemy_policy_busy = true # Input policy keeps real enemies alive; never disables AI.
	_starting_health = controller.actor_resources.health.current
	_starting_session = controller.session_id
	return true

func route_x(id: String) -> float:
	return float(_route_waypoints[id][0])

func tick(count: int = 1) -> void:
	for unused: int in count:
		await super.tick()
		if trace_cancelled(): return
		if observed_frames.is_empty(): continue
		observed_frames[-1]["spatial_golden"] = {"case": _spatial_name,
			"full_body_supported": full_body_supported(), "phase": spatial_phase, "mutation": spatial_mutation}
		if is_instance_valid(app._run_camera):
			observed_frames[-1]["actual_camera"] = {"position": SNAPSHOT.pair(app._run_camera.global_position),
				"center": SNAPSHOT.pair(app._run_camera.get_screen_center_position()),
				"zoom": SNAPSHOT.pair(app._run_camera.zoom), "viewport_size": SNAPSHOT.pair(app.get_viewport_rect().size)}

func full_body_supported() -> bool:
	if not is_instance_valid(motor) or not motor.is_on_floor(): return false
	var collision := motor.get_node("CollisionShape2D") as CollisionShape2D
	var half: Vector2 = collision.shape.get_rect().size * .5
	var feet := motor.global_position + Vector2(0, half.y)
	for side: float in [-.9, 0, .9]:
		var point := feet + Vector2(half.x * side, 0)
		var query := PhysicsRayQueryParameters2D.create(point + Vector2(0, -8), point + Vector2(0, 12), motor.collision_mask, [motor.get_rid()])
		var hit := motor.get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or not hit.collider is StaticBody2D or (hit.normal as Vector2).dot(Vector2.UP) < .7: return false
	return true

func begin_spatial(id: String) -> void:
	_spatial_name = id
	current_edge = id
	_spatial_start = trace_ticks + 1
	event("spatial_case_begin", {"id": id, "position": SNAPSHOT.pair(motor.global_position)})

func end_spatial(ok: bool, detail: Dictionary = {}) -> bool:
	var row := {"id": _spatial_name, "start_tick": _spatial_start, "end_tick": trace_ticks,
		"passed": ok, "position": SNAPSHOT.pair(motor.global_position), "full_body_supported": full_body_supported(),
		"health": controller.actor_resources.health.current, "shot_energy": controller.actor_resources.stamina.current,
		"session": controller.session_id}
	row.merge(detail)
	spatial_cases.append(row)
	observed_edges.append({"id": _spatial_name, "start_tick": _spatial_start, "end_tick": trace_ticks, "reached": ok})
	event("spatial_case_end", row)
	if not ok: record_check(false, "spatial golden actual input case failed: " + _spatial_name)
	return ok

func settle(count: int = 12) -> bool:
	controller.router.set_move_axis(0)
	for unused: int in count:
		await tick()
		if trace_cancelled() or not full_body_supported(): return false
	return true

func cross_gap(takeoff_x: float, receiver_x: float, recoil: bool) -> bool:
	if trace_cancelled() or not await move_to(takeoff_x, 220) or not full_body_supported(): return false
	var direction := signf(receiver_x - takeoff_x)
	var initial_recoveries := _recovery_serial
	var fired := false
	_saw_airborne = false
	controller.router.set_move_axis(direction)
	controller.router.request_action(&"jump")
	for frame: int in 150:
		if trace_cancelled(): return false
		controller.router.set_move_axis(clampf((receiver_x - motor.global_position.x) / 5.5, -1, 1))
		if recoil and frame == 18:
			controller.router.request_action(&"shoot_release", Vector2(-direction, 1).normalized())
			fired = true
		if frame == 28: controller.router.request_action(&"jump_release")
		await tick()
		if trace_cancelled() or _recovery_serial != initial_recoveries: return false
		if not motor.is_on_floor(): _saw_airborne = true
		if _saw_airborne and motor.is_on_floor():
			controller.router.request_action(&"jump_release")
			if direction * (motor.global_position.x - (takeoff_x + receiver_x) * .5) <= 0: return false
			return full_body_supported() and await move_to(receiver_x, 120) and await settle() and (not recoil or fired)
		if motor.global_position.y > _route_failure_y: return false
	return false

func stop_failed(label: String) -> void:
	end_spatial(false)
	finish(false, label)

func run_route() -> void:
	begin_spatial("entry_and_primary_recoil_gap")
	await tick(6)
	if trace_cancelled(): return
	if spatial_phase == "full" and not await settle(90):
		stop_failed("spatial_entry_support_failed"); return
	if not await cross_gap(route_x("takeoff"), route_x("recovery"), spatial_mutation != "no-gun"):
		stop_failed("spatial_primary_gap_failed")
		return
	if not end_spatial(true, {"scope": "single actual jump/recoil and stable receiver; no invented energy or body writes"}): return
	if spatial_phase == "probe":
		finish(true, "route_target_reached")
		return
	begin_spatial("rootbell_warning_and_bypass")
	if not await move_to(route_x("root_approach"), 160) or not await move_to(route_x("root_observe"), 80) or not await warning() or not await move_to(route_x("root_takeoff"), 120):
		stop_failed("spatial_warning_failed"); return
	if not await cross_gap(route_x("root_takeoff"), route_x("root_receiver"), false) or not await move_to(route_x("root_pass"), 100):
		stop_failed("spatial_root_bypass_failed"); return
	if not end_spatial(controller.actor_resources.health.current == _starting_health):
		finish(false, "spatial_actual_damage_failed"); return
	begin_spatial("short_gear_gap_and_lookback")
	if not await cross_gap(route_x("gear_start"), route_x("gear_receiver"), true) or not await move_to(route_x("lookback"), 120):
		stop_failed("spatial_gear_gap_failed"); return
	if not await settle(114): stop_failed("spatial_lookback_support_failed"); return
	if not end_spatial(controller.actor_resources.health.current == _starting_health):
		finish(false, "spatial_actual_damage_failed"); return
	begin_spatial("continuous_return_to_entry")
	if not await cross_gap(route_x("return_gear_takeoff"), route_x("gear_start"), true): stop_failed("spatial_return_gear_failed"); return
	await wait_for_safe_return_approach(route_x("return_root_takeoff"))
	if not await cross_gap(route_x("return_root_takeoff"), route_x("root_observe"), false) or not await cross_gap(route_x("return_primary_takeoff"), route_x("return_primary_receiver"), true):
		stop_failed("spatial_return_gap_failed"); return
	if not await move_to(route_x("entry"), 220) or not await settle(18): stop_failed("spatial_entry_return_failed"); return
	var ok := controller.actor_resources.health.current == _starting_health and controller.session_id == _starting_session and root_actor.health.current > 0
	end_spatial(ok, {"same_session": controller.session_id == _starting_session, "enemy_alive": root_actor.health.current > 0})
	finish(ok, "route_target_reached" if ok else "spatial_continuous_return_failed")
