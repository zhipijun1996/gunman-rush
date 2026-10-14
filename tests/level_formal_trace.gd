extends "res://tests/plains_region_trace.gd"
## Test-only router policy attached to the live DemoApp; no replacement world,
## manually stepped Motor, resource injection, disabled enemy or actor relocation.
const SNAPSHOT := preload("res://tools/level_capability_snapshot.gd")
var app: DemoApp
var formal_stage: PlainsRegionStage
var observed_frames: Array = []
var observed_edges: Array = []
var events: Array = []
var diagnostics: Array = []
var pending_events: Array = []
var finished := false
var terminated := false
var outcome := "running"
var strategy := "fast"
var phase_wait_ticks := 0
var frame_budget := 18000
var initial_capability: Dictionary = {}
var final_capability: Dictionary = {}
var initial_runtime: Dictionary = {}
var final_runtime: Dictionary = {}
var current_area := "area_0_1"
var current_edge := "tutorial"
var _reward_state := ""
var _mechanism_state := ""
var _recovery_serial := 0
var _last_recovery := 0

func attach(application: DemoApp, selected_strategy: String, wait_ticks: int) -> bool:
	app = application
	formal_stage = app.stage as PlainsRegionStage
	if formal_stage == null or not formal_stage.assembly_ok: return false
	tree = app.get_tree()
	world = app
	stage = formal_stage.assembler
	motor = app.player
	controller = app.controller
	region_state = app.region_state
	lifetime = app.lifetime
	shot_latch_encounter = formal_stage.shot_latch_encounter
	check = record_check
	strategy = selected_strategy
	phase_wait_ticks = wait_ticks
	if not controller.is_physics_processing() or not formal_stage.is_physics_processing(): return false
	controller.jump_ability.jumped.connect(func(): event("jump_accepted"))
	controller.shoot_ability.shot_fired.connect(func(direction: Vector2, id: int):
		shots += 1
		event("shot_accepted", {"direction": SNAPSHOT.pair(direction), "shot_id": id}))
	controller.landed.connect(func(): event("landed"))
	controller.segment_returned.connect(func():
		_recovery_serial += 1
		event("segment_returned", {"position": SNAPSHOT.pair(motor.global_position), "session_id": controller.session_id}))
	controller.died.connect(func(): event("died"))
	controller.energy_recovered.connect(func(amount: float, airborne: bool): event("energy_recovered", {"amount": amount, "airborne": airborne}))
	controller.router.action_rejected.connect(func(reason: String): event("input_rejected", {"reason": reason}))
	controller.actor_resources.health.changed.connect(func(result: ActorResourceResult):
		event("player_health", {"operation": str(result.operation), "amount": result.amount_applied, "status": int(result.status), "current": controller.actor_resources.health.current}))
	app.policy.batch_resolved.connect(func(results: Array[DamageResult]):
		for result: DamageResult in results:
			event("damage_committed", {"source": str(result.request.source_id), "target": str(result.request.target_id), "kind": int(result.request.kind), "amount": result.request.amount, "lethal": result.lethal}))
	app.director.run_ended.connect(func(result: DemoRunResult):
		final_capability = SNAPSHOT.capture(controller, app.build, "formal_run_end_before_cleanup")
		final_runtime = runtime_snapshot(true)
		event("run_ended", {"reason": str(result.reason)})
		terminated = true
		outcome = "run_ended/" + str(result.reason))
	initial_capability = SNAPSHOT.capture(controller, app.build, "live_formal_demo_app")
	initial_runtime = runtime_snapshot(true)
	return true

func event(kind: String, detail: Dictionary = {}) -> void:
	var value := {"tick": trace_ticks + 1, "kind": kind, "edge": current_edge}
	value.merge(detail)
	events.append(value)
	pending_events.append(value)

func record_check(ok: bool, label: String) -> void:
	if not ok:
		diagnostics.append({"tick": trace_ticks, "edge": current_edge, "message": label, "position": SNAPSHOT.pair(motor.global_position) if is_instance_valid(motor) else []})
		print("FORMAL DRIVER DIAGNOSTIC: ", label)

func runtime_snapshot(all_enemies: bool = false) -> Dictionary:
	if not is_instance_valid(formal_stage) or not is_instance_valid(motor): return {}
	var enemies: Array = []
	for i: int in formal_stage.enemies.size():
		var enemy: EnemyMotor = formal_stage.enemies[i]
		if not is_instance_valid(enemy): continue
		if not all_enemies and enemy.global_position.distance_to(motor.global_position) > 950.0: continue
		var actor := enemy.get_node("Actor") as EnemyActor
		var attack := actor.attack_behavior
		enemies.append({"id": str(formal_stage.enemy_manifest[i].id), "position": SNAPSHOT.pair(enemy.global_position), "velocity": SNAPSHOT.pair(enemy.velocity), "health": actor.health.current, "terminal": actor.health.terminal, "motor_self_physics_processing": enemy.is_physics_processing(), "actor_physics_processing": actor.is_physics_processing(), "attack_state": str(attack.state) if attack != null else "none", "attack_clock": attack.state_time if attack != null else 0.0, "attack_serial": attack._serial if attack != null else 0, "attack_cooldown": attack.cooldown if attack != null else 0.0})
	var camera: Dictionary = {}
	if is_instance_valid(app._run_camera):
		camera = {"position": SNAPSHOT.pair(app._run_camera.global_position), "screen_center": SNAPSHOT.pair(app._run_camera.get_screen_center_position()), "zoom": SNAPSHOT.pair(app._run_camera.zoom), "viewport_size": SNAPSHOT.pair(app.get_viewport_rect().size), "follow_trace": app._run_camera.follow_trace.duplicate(true)}
	var chests: Array = []
	for chest: Dictionary in formal_stage.chests: chests.append({"id": str(chest.id), "claimed": bool(chest.claimed), "tier": str(chest.tier)})
	var pickups: Array = []
	for pickup: Dictionary in formal_stage.pickups: pickups.append({"id": str(pickup.get("id", "")), "claimed": bool(pickup.claimed)})
	var mechanisms: Array = []
	for i: int in formal_stage.shot_latches.size():
		var latch: ShotLatch = formal_stage.shot_latches[i]
		mechanisms.append({"id": str(formal_stage.generated.manifest.shot_latch_plan.latches[i].id), "open": latch.is_open, "open_count": latch.open_count, "sequence_step": latch.sequence_step, "clock": latch._clock, "motion_running": latch.motion_target.motion_running if latch.motion_mode else false})
	return {"enemies": enemies, "enemy_count": formal_stage.enemies.size(), "contact_emitters": app._enemy_contacts.size(), "camera": camera, "chests": chests, "pickups": pickups, "mechanisms": mechanisms, "coins": app.wallet.balance, "claimed_ids": region_state.claimed.keys(), "opened_ids": region_state.opened.keys(), "boss_started": app._boss_started, "app_status": app._status, "paused": tree.paused}

func tick(count: int = 1) -> void:
	for unused: int in count:
		# On fatal cleanup keep the driver suspended while the capture owner saves
		# the observed failure. Never run legacy helper code against freed actors.
		while terminated or not is_instance_valid(motor): await tree.process_frame
		if trace_ticks >= frame_budget:
			outcome = "frame_budget_exhausted"
			terminated = true
			while terminated: await tree.process_frame
		var requests: Array = []
		for action: Dictionary in controller.router._queue: requests.append({"type": str(action.type), "direction": SNAPSHOT.pair(action.direction), "sequence": action.sequence})
		var axis := controller.router.axis
		var before := motor.global_position
		await tree.physics_frame
		await tree.process_frame
		trace_ticks += 1
		while terminated or not is_instance_valid(motor): await tree.process_frame
		var collisions: Array = []
		for i: int in motor.get_slide_collision_count():
			var collision := motor.get_slide_collision(i)
			collisions.append({"normal": SNAPSHOT.pair(collision.get_normal()), "position": SNAPSHOT.pair(collision.get_position()), "collider": str(collision.get_collider().get_path()) if is_instance_valid(collision.get_collider()) else "freed"})
		var frame := {"tick": trace_ticks, "controller_tick": controller._tick, "position": SNAPSHOT.pair(motor.global_position), "velocity": SNAPSHOT.pair(motor.velocity), "grounded": motor.is_on_floor(), "health": controller.actor_resources.health.current, "shot_energy": controller.actor_resources.stamina.current, "shots": controller.action_resources.shot_charges, "shot_cooldown": controller.shoot_ability.cooldown_remaining, "used_jumps": controller.jump_ability.used_jumps, "axis": axis, "input_requests": requests, "accepted_events": pending_events.duplicate(true), "collisions": collisions, "edge": current_edge, "session_id": controller.session_id, "recovery_count": _recovery_serial, "displacement": before.distance_to(motor.global_position)}
		pending_events.clear()
		if trace_ticks % 6 == 0 or _last_recovery != _recovery_serial:
			frame["runtime"] = runtime_snapshot()
		_last_recovery = _recovery_serial
		observed_frames.append(frame)
		final_capability = SNAPSHOT.capture(controller, app.build, "live_formal_demo_app")
		if _recovery_serial > 0: safe_trace = false

func walk_edge(edge: Dictionary, forward: bool) -> bool:
	current_edge = str(edge.id)
	var start := trace_ticks + 1
	# Production shortcut opening must go through nearby input interaction.
	if edge.condition == "backside" and not region_state.opened.has(edge.id):
		if forward: return false
		controller.router.request_action(&"interact")
		await tick(3)
		if not region_state.opened.has(edge.id):
			record_check(false, "formal shortcut interaction not accepted from this position")
			return false
	var ok: bool = await super.walk_edge(edge, forward)
	observed_edges.append({"id": str(edge.id), "forward": forward, "start_tick": start, "end_tick": trace_ticks, "reached": ok, "recovery_count": _recovery_serial})
	return ok

func follow_to(goal: String) -> bool:
	var path := path_to(current_area, goal)
	if current_area != goal and path.is_empty():
		record_check(false, "no declared accessible path: " + current_area + " -> " + goal)
		return false
	for step: Dictionary in path:
		if not await walk_edge(step.edge, step.forward): return false
		current_area = str(step.edge.b if step.forward else step.edge.a)
	return true

func claim_nearby_reward() -> void:
	if formal_stage.nearby_chest(motor.global_position) < 0: return
	controller.router.request_action(&"interact")
	await tick(2)
	if not app.reward_modal.opened or app._region_offer == null: return
	# Invoke the same modal submission callback; no direct grant or stat edit.
	# Prefer resources so the baseline traversal policy is not silently retuned.
	var selected: ItemDefinition = app._region_offer.candidates[0]
	for option: ItemDefinition in app._region_offer.candidates:
		if option is ResourceRewardChoice:
			selected = option
			break
	event("reward_modal_submission", {"choice": str(selected.stable_id), "input_scope": "production_modal_callback_not_device_GUI"})
	app._claim_modal_item(selected.stable_id)
	await tick(3)

func deep_trial(id: String) -> bool:
	current_edge = id
	# Parent bundles traversal and evacuation. Claim at the authored reward point
	# via move_to override before its production drop-through input begins.
	var start := trace_ticks + 1
	var ok: bool = await super.deep_trial(id)
	observed_edges.append({"id": id, "forward": true, "kind": "challenge_and_evacuation", "start_tick": start, "end_tick": trace_ticks, "reached": ok, "recovery_count": _recovery_serial})
	return ok

func move_to(x: float, budget: int = 310) -> bool:
	var ok: bool = await super.move_to(x, budget)
	if ok and strategy in ["growth", "deep", "return"] and formal_stage.nearby_chest(motor.global_position) >= 0:
		await claim_nearby_reward()
	return ok

func run_route() -> void:
	await tick(phase_wait_ticks)
	var ok: bool = await tutorial()
	observed_edges.append({"id": "tutorial", "forward": true, "start_tick": phase_wait_ticks + 1, "end_tick": trace_ticks, "reached": ok})
	if not ok:
		finish(false, "tutorial_policy_failed")
		return
	if strategy == "deep" or strategy == "return":
		var deep_goals: Array = ["deep_high"] if strategy == "return" else ["deep_high", "deep_region_top"]
		for id: String in deep_goals:
			var entry := ""
			for edge: Dictionary in stage.manifest.connections:
				if edge.b == id and edge.kind == "challenge": entry = str(edge.a)
			if entry.is_empty() or not await follow_to(entry) or not await deep_trial(id):
				finish(false, "deep_policy_failed/" + id)
				return
			for edge: Dictionary in stage.manifest.connections:
				if edge.a == id and edge.kind == "drop": current_area = str(edge.b)
	elif strategy == "growth":
		var rewards: Array = stage.manifest.rewards.filter(func(c: Dictionary): return c.tier == "medium")
		if rewards.is_empty() or not await follow_to(str(rewards[0].area)) or not await follow_to(str(stage.manifest.merchant_id)):
			finish(false, "growth_policy_failed")
			return
	var goal := "area_0_1" if strategy == "return" else str(stage.manifest.prep_id)
	ok = await follow_to(goal)
	finish(ok, "route_target_reached" if ok else "route_policy_failed")

func finish(ok: bool, status: String) -> void:
	controller.router.set_move_axis(0)
	outcome = status
	finished = true
	final_runtime = runtime_snapshot(true)
	final_capability = SNAPSHOT.capture(controller, app.build, "live_formal_demo_app")
	print("FORMAL ROUTE: strategy=%s outcome=%s ticks=%s enemies=%s returns=%s shots=%s" % [strategy, status, trace_ticks, formal_stage.enemies.size(), _recovery_serial, shots])
