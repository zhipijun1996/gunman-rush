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
var _unwind_requested := false
var _observation_sealed := false
var _cleanup_accepted_events: Array = []
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
var encounter_policy := "blind_legacy"
var policy_observations: Array = []
var resource_receipts: Array = []
var _enemy_policy_busy := false
var critical_traversal := 0
var allow_expected_recovery := false
var _enemy_transitions: Dictionary = {}
var _policy_attempts: Dictionary = {}
var _bypass_until: Dictionary = {}
var _claimed_required: Array = []
var _resource_seen: Dictionary = {}
var _passed_enemies: Dictionary = {}
var policy_move_goal := INF
var probe_reward_errors := false
var preferred_reward_resource := ""
# Visible capture transport only. Logical/headless traces retain the original
# physics -> process scheduling; no queued timestamp or gameplay rule changes.
var visible_input_post_draw := false
var observe_input_timing := false

func is_trace_cancelled() -> bool:
	return _unwind_requested

func seal_test_observation() -> void:
	_observation_sealed = true

func request_test_unwind() -> bool:
	# Only the capture owner may open the cleanup phase, after immutable evidence.
	if not _observation_sealed: return false
	_unwind_requested = true
	return true

func cancellation_facts() -> Dictionary:
	var controller_live: bool = is_instance_valid(controller)
	var router_live: bool = controller_live and is_instance_valid(controller.router)
	return {
		"trace_ticks":trace_ticks,"controller_valid":controller_live,"motor_valid":is_instance_valid(motor),
		"controller_tick":controller._tick if controller_live else -1,
		"router_sequence":controller.router.sequence if router_live else -1,
		"router_epoch":controller.router.epoch if router_live else -1,
		"queued_actions":controller.router._queue.size() if router_live else -1,
		"router_axis":controller.router.axis if router_live else 0.0,
		"position":SNAPSHOT.pair(motor.global_position) if is_instance_valid(motor) else [],
		"health":controller.actor_resources.health.current if controller_live else null,
		"shot_energy":controller.actor_resources.stamina.current if controller_live else null,
		"events":events.size(),"frames":observed_frames.size(),"observations":policy_observations.size(),
		"receipts":resource_receipts.size(),"wallet":app.wallet.balance if is_instance_valid(app) else null,
		"claims":region_state.claimed.keys().duplicate(),"terminated":terminated,"finished":finished,
		"outcome":outcome,"shots":shots,"post_seal_accepted_events":_cleanup_accepted_events.duplicate(true)}

func disconnect_test_observers() -> int:
	# Retrieve actual Callables; default fatal cleanup may have freed the actor.
	var signals: Array[Signal] = []
	if is_instance_valid(app) and app.director != null: signals.append(app.director.run_ended)
	if is_instance_valid(controller):
		signals.append_array([controller.jump_ability.jumped,controller.shoot_ability.shot_fired,controller.landed,controller.segment_returned,controller.died,controller.energy_recovered,controller.router.action_rejected,controller.actor_resources.health.changed,controller.shoot_ability.shot_rejected])
	if is_instance_valid(app) and is_instance_valid(app.policy): signals.append(app.policy.batch_resolved)
	if is_instance_valid(formal_stage):
		for enemy: EnemyMotor in formal_stage.enemies:
			if not is_instance_valid(enemy): continue
			var actor := enemy.get_node("Actor") as EnemyActor
			if actor.attack_behavior != null: signals.append(actor.attack_behavior.state_changed)
	var removed := 0
	for observed: Signal in signals:
		for connection: Dictionary in observed.get_connections():
			var callback: Callable = connection["callable"]
			if callback.get_object() == self:
				observed.disconnect(callback)
				removed += 1
	return removed

func attach(application: DemoApp, selected_strategy: String, wait_ticks: int, selected_policy: String = "blind_legacy") -> bool:
	if selected_policy not in ["blind_legacy", "kill_from_bank_v1", "kill_from_bank_v2", "bait_then_bypass_v1"]: return false
	encounter_policy = selected_policy
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
		if _observation_sealed:
			event("shot_accepted", {"shot_id":id})
			return
		shots += 1
		var detail := {"direction": SNAPSHOT.pair(direction), "shot_id": id}
		for projectile: PlayerProjectile in controller.shoot_ability.get_projectiles():
			if projectile.shot_id == id:
				detail.merge({"owner_id": projectile.owner_id, "session_id": projectile.session_id, "packet_id": projectile.energy_receipt_id, "resource_epoch": controller.actor_resources.stamina.epoch, "event_id": "%s:%s:%s" % [projectile.owner_id, projectile.session_id, id], "muzzle": SNAPSHOT.pair(controller.shoot_ability.last_muzzle), "projectile_direction": SNAPSHOT.pair(projectile.direction), "fired_airborne": projectile.fired_airborne, "energy_after": controller.actor_resources.stamina.current})
		event("shot_accepted", detail))
	controller.landed.connect(func(): event("landed"))
	controller.segment_returned.connect(func():
		if _observation_sealed:
			event("segment_returned")
			return
		_recovery_serial += 1
		event("segment_returned", {"position": SNAPSHOT.pair(motor.global_position), "session_id": controller.session_id})
		if encounter_policy != "blind_legacy" and not allow_expected_recovery:
			outcome = "route_policy_failed"
			terminated = true
			final_capability = SNAPSHOT.capture(controller, app.build, "actual_segment_return")
			final_runtime = runtime_snapshot(true))
	controller.died.connect(func(): event("died"))
	controller.energy_recovered.connect(func(amount: float, airborne: bool): event("energy_recovered", {"amount": amount, "airborne": airborne}))
	controller.router.action_rejected.connect(func(reason: String): event("input_rejected", {"reason": reason}))
	controller.actor_resources.health.changed.connect(func(result: ActorResourceResult):
		event("player_health", {"operation": str(result.operation), "amount": result.amount_applied, "status": int(result.status), "current": controller.actor_resources.health.current}))
	app.policy.batch_resolved.connect(func(results: Array[DamageResult]):
		if _observation_sealed:
			for result: DamageResult in results: event("damage_committed", {"target":str(result.request.target_id)})
			return
		for result: DamageResult in results:
			collect_resource_receipts()
			event("damage_committed", {"source": str(result.request.source_id), "target": str(result.request.target_id), "damage_kind": int(result.request.kind), "event_id": str(result.request.event_id), "health_epoch": result.request.health_epoch, "actor_epoch": result.request.actor_epoch, "health_after": result.health.current, "amount": result.request.amount, "lethal": result.lethal}))
	app.director.run_ended.connect(func(result: DemoRunResult):
		if _observation_sealed:
			event("run_ended", {"reason":str(result.reason)})
			return
		final_capability = SNAPSHOT.capture(controller, app.build, "formal_run_end_before_cleanup")
		final_runtime = runtime_snapshot(true)
		event("run_ended", {"reason": str(result.reason)})
		terminated = true
		outcome = "run_ended/" + str(result.reason))
	controller.shoot_ability.shot_rejected.connect(func(reason: StringName): event("input_rejected", {"reason": str(reason), "source": "ShootAbility"}))

	for i: int in formal_stage.enemies.size():
		var enemy: EnemyMotor = formal_stage.enemies[i]
		var actor := enemy.get_node("Actor") as EnemyActor
		var id: String = str(formal_stage.enemy_manifest[i].id)
		_enemy_transitions[id] = 0
		if actor.attack_behavior != null:
			actor.attack_behavior.state_changed.connect(func(state: StringName):
				if _observation_sealed: return
				_enemy_transitions[id] = int(_enemy_transitions[id]) + 1
				policy_observations.append({"tick": trace_ticks + 1, "kind": "actual_enemy_transition", "enemy": id, "state": str(state), "transition_serial": _enemy_transitions[id], "position": SNAPSHOT.pair(enemy.global_position)}))
	initial_capability = SNAPSHOT.capture(controller, app.build, "live_formal_demo_app")
	initial_runtime = runtime_snapshot(true)
	return true

func event(kind: String, detail: Dictionary = {}) -> void:
	if _observation_sealed:
		if kind in ["jump_accepted","shot_accepted","landed","segment_returned","died","damage_committed","run_ended","reward_modal_submission","player_health","energy_recovered"]:
			_cleanup_accepted_events.append({"kind":kind,"detail":detail.duplicate(true)})
		return
	var value := {"tick": trace_ticks + 1, "kind": kind, "edge": current_edge}
	value.merge(detail)
	events.append(value)
	pending_events.append(value)

func record_check(ok: bool, label: String) -> void:
	if _observation_sealed: return
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
		enemies.append({"id": str(formal_stage.enemy_manifest[i].id), "position": SNAPSHOT.pair(enemy.global_position), "velocity": SNAPSHOT.pair(enemy.velocity), "health": actor.health.current, "terminal": actor.health.terminal, "motor_self_physics_processing": enemy.is_physics_processing(), "actor_physics_processing": actor.is_physics_processing(), "attack_state": str(attack.state) if attack != null else "none", "attack_clock": attack.state_time if attack != null else 0.0, "attack_serial": attack._serial if attack != null else 0, "attack_cooldown": attack.cooldown if attack != null else 0.0, "body_size": SNAPSHOT.pair(actor.definition.collision_size), "behavior": str(actor.definition.behavior_id), "transition_serial": _enemy_transitions.get(str(formal_stage.enemy_manifest[i].id), 0), "home": SNAPSHOT.pair(attack.home) if attack != null else [], "locked_direction": SNAPSHOT.pair(attack.locked_direction) if attack != null else [], "attack_origin": SNAPSHOT.pair(attack.attack_origin) if attack != null else [], "attack_goal": SNAPSHOT.pair(attack.attack_goal) if attack != null else [], "activation_range": actor.definition.activation_range, "engagement_in_range": motor.global_position.distance_to(attack.home) <= actor.definition.activation_range if attack != null else false, "projectiles": enemy_projectiles(attack)})
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
	if is_trace_cancelled(): return
	for unused: int in count:
		# On fatal cleanup keep the driver suspended while the capture owner saves
		# the observed failure. Never run legacy helper code against freed actors.
		while terminated or not is_instance_valid(motor):
			if is_trace_cancelled(): return
			await tree.process_frame
		if trace_ticks >= frame_budget:
			outcome = "frame_budget_exhausted"
			terminated = true
			while terminated:
				if is_trace_cancelled(): return
				await tree.process_frame
		if encounter_policy != "blind_legacy" and not _enemy_policy_busy and critical_traversal == 0 and motor.is_on_floor() and controller.router._queue.is_empty():
			var original_axis := controller.router.axis
			_enemy_policy_busy = true
			var safe := await prepare_threats()
			if is_trace_cancelled(): return
			_enemy_policy_busy = false
			if not safe:
				outcome = "route_policy_failed"
				terminated = true
				final_runtime = runtime_snapshot(true)
				final_capability = SNAPSHOT.capture(controller, app.build, "bounded_policy_stop")
				while terminated:
					if is_trace_cancelled(): return
					await tree.process_frame
			controller.router.set_move_axis(original_axis)
		var requests: Array = []
		for action: Dictionary in controller.router._queue:
			var request := {"type": str(action.type), "direction": SNAPSHOT.pair(action.direction), "sequence": action.sequence}
			if observe_input_timing:
				request.merge({"timestamp_seconds": action.timestamp, "epoch": action.epoch})
			requests.append(request)
		var axis := controller.router.axis
		var before := motor.global_position
		await tree.physics_frame
		if is_trace_cancelled(): return
		var input_timing: Dictionary = {}
		if observe_input_timing:
			var boundary_usec := Time.get_ticks_usec()
			var queued: Array = []
			for action: Dictionary in controller.router._queue:
				queued.append({"sequence": action.sequence, "type": str(action.type), "timestamp_seconds": action.timestamp, "epoch": action.epoch, "age_seconds": boundary_usec / 1000000.0 - float(action.timestamp)})
			input_timing = {"scope": "observer_preconsume_boundary_not_controller_receipt", "physics_frame_signal_usec": boundary_usec, "controller_tick_before": controller._tick, "router_epoch": controller.router.epoch, "max_age_seconds": InputRouter.MAX_AGE_SECONDS, "queued": queued}
		await tree.process_frame
		if is_trace_cancelled(): return
		trace_ticks += 1
		collect_resource_receipts(trace_ticks)
		while terminated or not is_instance_valid(motor):
			if is_trace_cancelled(): return
			await tree.process_frame
		var collisions: Array = []
		for i: int in motor.get_slide_collision_count():
			var collision := motor.get_slide_collision(i)
			collisions.append({"normal": SNAPSHOT.pair(collision.get_normal()), "position": SNAPSHOT.pair(collision.get_position()), "collider": str(collision.get_collider().get_path()) if is_instance_valid(collision.get_collider()) else "freed"})
		var frame := {"tick": trace_ticks, "controller_tick": controller._tick, "position": SNAPSHOT.pair(motor.global_position), "velocity": SNAPSHOT.pair(motor.velocity), "grounded": motor.is_on_floor(), "health": controller.actor_resources.health.current, "resource_epoch": controller.actor_resources.stamina.epoch, "shot_energy": controller.actor_resources.stamina.current, "shots": controller.action_resources.shot_charges, "shot_cooldown": controller.shoot_ability.cooldown_remaining, "used_jumps": controller.jump_ability.used_jumps, "axis": axis, "input_requests": requests, "accepted_events": pending_events.duplicate(true), "collisions": collisions, "edge": current_edge, "session_id": controller.session_id, "recovery_count": _recovery_serial, "displacement": before.distance_to(motor.global_position)}
		if observe_input_timing: frame["input_timing"] = input_timing
		pending_events.clear()
		if trace_ticks % 6 == 0 or _last_recovery != _recovery_serial:
			frame["runtime"] = runtime_snapshot()
		_last_recovery = _recovery_serial
		observed_frames.append(frame)
		final_capability = SNAPSHOT.capture(controller, app.build, "live_formal_demo_app")
		if _recovery_serial > 0: safe_trace = false
		# Helpers resume at the observed frame_post_draw boundary. This does not
		# guarantee MovieWriter encoding or other post-draw subscribers have ended.
		if visible_input_post_draw:
			await RenderingServer.frame_post_draw
			if is_trace_cancelled(): return

func walk_edge(edge: Dictionary, forward: bool) -> bool:
	if is_trace_cancelled(): return false
	current_edge = str(edge.id)
	var start := trace_ticks + 1
	# Production shortcut opening must go through nearby input interaction.
	if edge.condition == "backside" and not region_state.opened.has(edge.id):
		if forward: return false
		controller.router.request_action(&"interact")
		await tick(3)
		if is_trace_cancelled(): return false
		if not region_state.opened.has(edge.id):
			record_check(false, "formal shortcut interaction not accepted from this position")
			return false
	var protected_motion: bool = edge.kind in ["stairs", "diagonal", "drop"]
	if protected_motion and encounter_policy != "blind_legacy":
		_enemy_policy_busy = true
		var ready := await prepare_threats()
		if is_trace_cancelled(): return false
		_enemy_policy_busy = false
		if not ready: return false
		critical_traversal += 1
	var ok: bool = await super.walk_edge(edge, forward)
	if is_trace_cancelled(): return false
	if protected_motion and encounter_policy != "blind_legacy": critical_traversal -= 1
	observed_edges.append({"id": str(edge.id), "forward": forward, "start_tick": start, "end_tick": trace_ticks, "reached": ok, "recovery_count": _recovery_serial})
	return ok

func follow_to(goal: String) -> bool:
	if is_trace_cancelled(): return false
	var path := path_to(current_area, goal)
	if current_area != goal and path.is_empty():
		record_check(false, "no declared accessible path: " + current_area + " -> " + goal)
		return false
	for step: Dictionary in path:
		if not await walk_edge(step.edge, step.forward): return false
		current_area = str(step.edge.b if step.forward else step.edge.a)
	return true

func claim_nearby_reward() -> void:
	if is_trace_cancelled(): return
	if formal_stage.nearby_chest(motor.global_position) < 0: return
	controller.router.request_action(&"interact")
	await tick(2)
	if is_trace_cancelled(): return
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
	if is_trace_cancelled(): return

func reward_transaction_state() -> Dictionary:
	var health_receipts: Dictionary = {}
	for id: Variant in controller.actor_resources.health._receipts:
		var entry: Dictionary = controller.actor_resources.health._receipts[id]
		var result: ActorResourceResult = entry.result
		health_receipts[str(id)] = {"operation":str(entry.operation),"requested_amount":entry.amount,"event_id":str(result.event_id),"status":int(result.status),"amount_applied":result.amount_applied,"current":result.snapshot.current,"capacity":result.snapshot.capacity,"epoch":result.snapshot.epoch}
	return {"coins":app.wallet.balance,"wallet_grants":app.wallet._grants.duplicate(true),"health":controller.actor_resources.health.current,"health_capacity":controller.actor_resources.health.capacity,"health_epoch":controller.actor_resources.health.epoch,"health_receipts":health_receipts,"meta":app.meta.snapshot(),"meta_receipts":app.meta._receipts.duplicate(true)}

func reward_offer_snapshot() -> Dictionary:
	var choices: Array = []
	for candidate: ItemDefinition in app._region_offer.candidates:
		var resource := candidate as ResourceRewardChoice
		choices.append({"id":str(candidate.stable_id),"kind":"resource" if resource!=null else "item","resource":resource.resource_kind if resource!=null else "item","amount":resource.amount if resource!=null else 0,"valid":candidate.is_valid()})
	return {"offer_id":str(app._region_offer.offer_id),"candidates":choices}

func claim_required_chest(id: String) -> bool:
	if is_trace_cancelled(): return false
	var index := -1
	for i: int in formal_stage.chests.size():
		if str(formal_stage.chests[i].id) == id: index = i
	if index < 0: return false
	var chest: Dictionary = formal_stage.chests[index]
	if chest.claimed: return region_state.claimed.has(id)
	if not motor.is_on_floor() or motor.global_position.distance_to(chest.position) >= 80: return false
	if probe_reward_errors:
		var unopened_submission:=app._claim_modal_item(&"not_a_real_offered_choice")
		policy_observations.append({"tick":trace_ticks,"kind":"unopened_modal_rejected","accepted":unopened_submission,"chest":id})
		if unopened_submission:return false
	var transaction_before := reward_transaction_state()
	var before := {"coins": app.wallet.balance, "health": controller.actor_resources.health.current, "meta": app.meta.snapshot(), "position": SNAPSHOT.pair(motor.global_position)}
	controller.router.request_action(&"interact")
	# Modal opens from the normal end-of-frame action queue; do not await a
	# permanently paused controller before giving the real UI submission.
	await tick()
	if is_trace_cancelled(): return false
	for unused: int in 30:
		if app.reward_modal.opened: break
		await tree.process_frame
		if is_trace_cancelled(): return false
	if not app.reward_modal.opened or app._region_offer == null or str(app._region_offer.offer_id) != id: return false
	if probe_reward_errors:
		var wrong_queued:=app._claim_modal_item(&"not_a_real_offered_choice")
		await tick(2)
		if is_trace_cancelled(): return false
		var wrong_rejected:bool=wrong_queued and not chest.claimed and app.reward_modal.opened and not app._region_pending_claim
		policy_observations.append({"tick":trace_ticks,"kind":"actual_wrong_choice_rejected","chest":id,"queued":wrong_queued,"claimed":chest.claimed,"modal_opened":app.reward_modal.opened,"rejected":wrong_rejected})
		if not wrong_rejected:return false
	var selected: ItemDefinition = app._region_offer.candidates[0]
	for candidate: ItemDefinition in app._region_offer.candidates:
		if candidate is ResourceRewardChoice and (preferred_reward_resource.is_empty() or (candidate as ResourceRewardChoice).resource_kind == preferred_reward_resource):
			selected = candidate
			break
	var offered := reward_offer_snapshot()
	if not selected is ResourceRewardChoice: return false # This proof tests resource choices; it does not remove native item options.
	if not preferred_reward_resource.is_empty() and (selected as ResourceRewardChoice).resource_kind!=preferred_reward_resource:return false
	event("reward_modal_submission", {"choice": str(selected.stable_id), "offer_id": id, "input_scope": "production_modal_callback_not_device_GUI"})
	var queued := app._claim_modal_item(selected.stable_id)
	if not queued: return false
	await tick(3)
	if is_trace_cancelled(): return false
	var claimed: bool = chest.claimed and region_state.claimed.has(id) and not app.reward_modal.opened and app._region_chest == -1
	policy_observations.append({"tick": trace_ticks, "kind": "actual_cache_claim", "chest": id, "choice": str(selected.stable_id), "queued": queued, "claimed": claimed, "before": before, "after": {"coins": app.wallet.balance, "health": controller.actor_resources.health.current, "meta": app.meta.snapshot()}, "wallet_receipts": app.wallet._grants.duplicate(true), "transaction": {"schema_version":1,"stage_index":app.director.stage_index,"receipt_prefix":app._run_receipt_prefix,"offer":offered,"before":transaction_before,"after":reward_transaction_state()}, "claim_output": app.director.manifest.snapshot().stages[app.director.stage_index-1].outputs.get("cache/"+id,{}), "position": SNAPSHOT.pair(motor.global_position)})
	if claimed and probe_reward_errors:
		var balance:=app.wallet.balance
		var grants:Dictionary=app.wallet._grants.duplicate(true)
		var duplicate_submission:=app._claim_modal_item(selected.stable_id)
		controller.router.request_action(&"interact")
		await tick(2)
		if is_trace_cancelled(): return false
		var duplicate_rejected:bool=not duplicate_submission and chest.claimed and app.wallet.balance==balance and app.wallet._grants==grants and not app.reward_modal.opened
		policy_observations.append({"tick":trace_ticks,"kind":"actual_duplicate_claim_rejected","chest":id,"accepted":duplicate_submission,"rejected":duplicate_rejected,"balance":app.wallet.balance})
		if not duplicate_rejected:return false
	return claimed

func aware_growth() -> bool:
	if is_trace_cancelled(): return false
	var rewards: Array = stage.manifest.rewards.filter(func(c: Dictionary): return c.tier == "medium")
	if rewards.size() != 2: return false
	for reward: Dictionary in rewards:
		var id := PlainsRegionCampaign.prefix(formal_stage.map_index) + str(reward.id)
		if reward.has("approach"):
			var approach: Dictionary = reward.approach
			if not await follow_to(str(approach.entry_area)): return false
			var module := named(str(approach.module))
			var bank := named(str(approach.bank))
			if module == null or bank == null: return false
			if not await move_to(module.world_entry().x, 500): return false
			_enemy_policy_busy = true
			var ready := await prepare_threats()
			if is_trace_cancelled(): return false
			_enemy_policy_busy = false
			if not ready: return false
			var branch = load("res://tests/branch_module_driver.gd").new()
			branch.module = module; branch.motor = motor; branch.controller = controller; branch.tick_callback = tick; branch.check = check
			module.set_meta("discovery_latch", shot_latch_encounter.for_module(module))
			var claim_state := {"accepted": false}
			var claim := func():
				var accepted: bool = await claim_required_chest(id)
				if is_trace_cancelled(): return
				claim_state.accepted = accepted
			current_edge = ""
			for edge: Dictionary in stage.manifest.connections:
				if str(edge.a) == str(approach.entry_area) and str(edge.b) == str(approach.exit_area): current_edge = str(edge.id)
			if current_edge.is_empty(): return false
			var begin := trace_ticks + 1
			critical_traversal += 1
			var reached: bool = await load("res://tests/plains_creek_discovery_motion.gd").traverse(branch, module, bank, claim)
			if is_trace_cancelled(): return false
			critical_traversal -= 1
			observed_edges.append({"id": current_edge, "forward": true, "start_tick": begin, "end_tick": trace_ticks, "reached": reached and bool(claim_state.accepted), "kind": "actual_creek_reward_and_return"})
			if not reached or not claim_state.accepted: return false
			current_area = str(approach.exit_area)
			if not await move_to(float(PlainsRegionGenerator.new()._area(stage.manifest,current_area).position[0]), 500): return false
		else:
			if not await follow_to(str(reward.area)): return false
			if not await move_to(float(reward.position[0]), 500): return false
			if not await claim_required_chest(id): return false
		_claimed_required.append(id)
	return await follow_to(str(stage.manifest.merchant_id))

func deep_trial(id: String) -> bool:
	if is_trace_cancelled(): return false
	current_edge = id
	if encounter_policy!="blind_legacy":
		# The next authored ascent is not the previous horizontal waypoint.
		# Observe from the real starting junction before committing its first jump.
		policy_move_goal=INF
		_enemy_policy_busy=true
		var ready:=await prepare_threats()
		if is_trace_cancelled(): return false
		_enemy_policy_busy=false
		if not ready:return false
	# Parent bundles traversal and evacuation. Claim at the authored reward point
	# via move_to override before its production drop-through input begins.
	var start := trace_ticks + 1
	var ok: bool = await super.deep_trial(id)
	if is_trace_cancelled(): return false
	observed_edges.append({"id": id, "forward": true, "kind": "challenge_and_evacuation", "start_tick": start, "end_tick": trace_ticks, "reached": ok, "recovery_count": _recovery_serial})
	return ok

func move_to(x: float, budget: int = 310) -> bool:
	if is_trace_cancelled(): return false
	var previous_goal:=policy_move_goal
	policy_move_goal=x
	var ok: bool = await super.move_to(x, budget)
	if is_trace_cancelled(): return false
	policy_move_goal=previous_goal
	if ok and encounter_policy == "blind_legacy" and strategy in ["growth", "deep", "return"] and formal_stage.nearby_chest(motor.global_position) >= 0:
		await claim_nearby_reward()
		if is_trace_cancelled(): return false
	if ok and encounter_policy!="blind_legacy" and strategy in ["deep","return"]:
		var nearby:=formal_stage.nearby_chest(motor.global_position)
		if nearby>=0 and str(formal_stage.chests[nearby].tier) in ["high","region_top"]:
			if not await claim_required_chest(str(formal_stage.chests[nearby].id)):return false
	return ok

func run_route() -> void:
	if is_trace_cancelled(): return
	await tick(phase_wait_ticks)
	if is_trace_cancelled(): return
	var ok: bool = await tutorial()
	if is_trace_cancelled(): return
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
	elif strategy == "growth" and encounter_policy != "blind_legacy":
		if not await aware_growth():
			finish(false, "growth_policy_failed")
			return
	elif strategy == "growth":
		var rewards: Array = stage.manifest.rewards.filter(func(c: Dictionary): return c.tier == "medium")
		if rewards.is_empty() or not await follow_to(str(rewards[0].area)) or not await follow_to(str(stage.manifest.merchant_id)):
			finish(false, "growth_policy_failed")
			return
	var goal := "area_0_1" if strategy == "return" else str(stage.manifest.prep_id)
	ok = await follow_to(goal)
	if is_trace_cancelled(): return
	finish(ok, "route_target_reached" if ok else "route_policy_failed")

func finish(ok: bool, status: String) -> void:
	if _observation_sealed or is_trace_cancelled(): return
	controller.router.set_move_axis(0)
	outcome = status
	finished = true
	final_runtime = runtime_snapshot(true)
	final_capability = SNAPSHOT.capture(controller, app.build, "live_formal_demo_app")
	print("FORMAL ROUTE: strategy=%s outcome=%s ticks=%s enemies=%s returns=%s shots=%s" % [strategy, status, trace_ticks, formal_stage.enemies.size(), _recovery_serial, shots])

func enemy_projectiles(attack: EnemyAttackBehavior) -> Array:
	var values: Array = []
	if attack == null: return values
	for projectile: EnemyAttackProjectile in attack._projectiles:
		if not is_instance_valid(projectile) or projectile.spent: continue
		values.append({"event_id": str(projectile.event_id), "position": SNAPSHOT.pair(projectile.global_position), "direction": SNAPSHOT.pair(projectile.direction), "speed": projectile.speed, "radius": projectile.radius, "remaining": projectile.remaining})
	return values

func bank_supported(point: Vector2, retreat: Vector2 = Vector2.ZERO) -> bool:
	var collision := motor.get_node("CollisionShape2D") as CollisionShape2D
	var shape := collision.shape as RectangleShape2D
	var half := shape.size * .5
	var space := motor.get_world_2d().direct_space_state
	# Every recoil-path sample needs the actual full footprint, not just a
	# centre ray. A moving deck is never an opportunistic shooting bank.
	for fraction: float in [0.0, .25, .5, .75, 1.0]:
		var centre := point + retreat * fraction
		for x: float in [-half.x + 1, 0.0, half.x - 1]:
			var feet := centre + Vector2(x, half.y)
			var ray := PhysicsRayQueryParameters2D.create(feet + Vector2(0, -1), feet + Vector2(0, 8), 1, [motor.get_rid()])
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or hit.collider is ModuleMovingPlatform or (hit.normal as Vector2).dot(Vector2.UP) < .7: return false
		var body := Rect2(centre - half, shape.size)
		for danger: Rect2 in stage.world_static_dangers():
			if danger.intersects(body, true): return false
		for module: PlatformingModule in stage.modules:
			for hazard: ModuleSawHazard in module.hazards:
				if SawHazard.swept_contact(centre-hazard.global_position, centre-hazard.global_position, half, hazard.definition.radius): return false
	return true

func clear_shot(enemy: EnemyMotor) -> bool:
	var aim := enemy.global_position - motor.global_position
	if aim.is_zero_approx(): return false
	# Bells are layer8 real projectile blockers, not terrain layer1. Shooting
	# through one to a flying enemy would toggle a ferry and is not clear aim.
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius=motor.tuning.projectile_radius
	query.shape=shape;query.transform=Transform2D(0,motor.global_position)
	query.motion=aim;query.collision_mask=9;query.exclude=[motor.get_rid(),enemy.get_rid()]
	var result := motor.get_world_2d().direct_space_state.cast_motion(query)
	return result.size()==2 and result[0]>=1.0

func incoming_projectile(point: Vector2, horizon: float = .3) -> bool:
	var half := (motor.get_node("CollisionShape2D").shape as RectangleShape2D).size * .5
	for enemy: EnemyMotor in formal_stage.enemies:
		var actor := enemy.get_node("Actor") as EnemyActor
		if actor.attack_behavior == null: continue
		for shot: EnemyAttackProjectile in actor.attack_behavior._projectiles:
			if not is_instance_valid(shot) or shot.spent: continue
			var expanded := Rect2(point - half - Vector2.ONE * shot.radius, half * 2 + Vector2.ONE * shot.radius * 2)
			if DemoContactEmitter.segment_intersects_bounds(shot.global_position, shot.global_position + shot.direction * shot.speed * minf(horizon, shot.remaining), expanded): return true
	return false

func prepare_threats() -> bool:
	if is_trace_cancelled(): return false
	if encounter_policy == "blind_legacy" or not motor.is_on_floor(): return true
	# No intervention on a moving platform or after a jump/shot is committed.
	if not bank_supported(motor.global_position): return true
	for index: int in formal_stage.enemies.size():
		var enemy: EnemyMotor = formal_stage.enemies[index]
		var actor := enemy.get_node("Actor") as EnemyActor
		if actor.health.terminal: continue
		var offset := enemy.global_position - motor.global_position
		if offset.length() > 440: continue
		var id: String = str(formal_stage.enemy_manifest[index].id)
		if absf(offset.y) > 220:
			# The existing kill policy requires a full horizontal recoil footprint
			# before firing. Let Router movement reach that real bank first.
			var recoil_distance: float = motor.weapon_motion.base_distance(motor.tuning, true)
			var projected := Vector2(-offset.normalized().x * recoil_distance, 0)
			var horizontal := Vector2(-signf(offset.x) * recoil_distance, 0)
			var projected_supported := bank_supported(motor.global_position, projected)
			var horizontal_supported := bank_supported(motor.global_position, horizontal)
			policy_observations.append({"tick":trace_ticks,"kind":"high_target_actual_bank_readiness","enemy":id,"position":SNAPSHOT.pair(motor.global_position),"target":SNAPSHOT.pair(enemy.global_position),"projected_retreat":SNAPSHOT.pair(projected),"horizontal_retreat":SNAPSHOT.pair(horizontal),"projected_supported":projected_supported,"horizontal_supported":horizontal_supported})
			if not horizontal_supported: continue
		if is_finite(policy_move_goal):
			var travel_direction:=signf(policy_move_goal-motor.global_position.x)
			if travel_direction!=0 and travel_direction*(enemy.global_position.x-policy_move_goal)>actor.definition.collision_size.x*.5+28:continue
		if _passed_enemies.has(id):
			var passed_direction: float = float(_passed_enemies[id])
			if passed_direction*(enemy.global_position.x-motor.global_position.x)<-40 and passed_direction*controller.router.axis>=0:continue
		if int(_bypass_until.get(id, -1)) > trace_ticks: continue
		if not clear_shot(enemy):
			if offset.length() < 75:
				record_check(false, "no safe visible solution for nearby live enemy " + id)
				return false
			continue
		var count: int = int(_policy_attempts.get(id, 0))
		if count >= 6:
			record_check(false, "bounded enemy attempts exhausted " + id)
			return false
		var ok := await kill_from_bank(enemy, id) if encounter_policy in ["kill_from_bank_v1", "kill_from_bank_v2"] else await bait_then_bypass(enemy, id)
		if is_trace_cancelled(): return false
		if not ok: return false
	return true

func kill_from_bank(enemy: EnemyMotor, id: String) -> bool:
	if is_trace_cancelled(): return false
	var actor := enemy.get_node("Actor") as EnemyActor
	var bank := motor.global_position
	var aim := (enemy.global_position - bank).normalized()
	var recoil_distance: float = motor.weapon_motion.base_distance(motor.tuning, true)
	var retreat := -aim * recoil_distance
	# Vertical aiming can lift the player; defer a high target to a real stable
	# landing after the shot. The horizontal footprint must remain supported.
	if not bank_supported(bank, Vector2(retreat.x, 0)):
		var found_bank := false
		var shifts: Array[float] = [16.0,32.0,48.0,64.0,-16.0,-32.0,-48.0,-64.0]
		if encounter_policy == "kill_from_bank_v2": shifts.append_array([80.0,96.0,-80.0,-96.0])
		for shift: float in shifts:
			var candidate := bank + Vector2(signf(aim.x)*shift,0)
			if encounter_policy == "kill_from_bank_v2":
				policy_observations.append({"tick": trace_ticks, "kind": "kill_bank_candidate_v2", "enemy": id, "origin": SNAPSHOT.pair(bank), "candidate": SNAPSHOT.pair(candidate), "shift": shift, "recoil_distance": recoil_distance, "path_supported": bank_supported(bank,candidate-bank), "recoil_supported": bank_supported(candidate,Vector2(retreat.x,0))})
			if not bank_supported(bank,candidate-bank) or not bank_supported(candidate,Vector2(retreat.x,0)):continue
			var enemy_min := enemy.global_position.x
			var enemy_max := enemy_min
			if actor.attack_behavior != null and actor.definition.behavior_id in [&"charger",&"patrol"]:
				enemy_min=actor.attack_behavior.home.x-actor.definition.patrol_half_width
				enemy_max=actor.attack_behavior.home.x+actor.definition.patrol_half_width
			var clearance := actor.definition.collision_size.x*.5+12+8
			if encounter_policy == "kill_from_bank_v2":
				policy_observations.append({"tick": trace_ticks, "kind": "kill_bank_candidate_clearance_v2", "enemy": id, "candidate": SNAPSHOT.pair(candidate), "enemy_min": enemy_min, "enemy_max": enemy_max, "required_clearance": clearance, "blocked": candidate.x>enemy_min-clearance and candidate.x<enemy_max+clearance})
			if candidate.x>enemy_min-clearance and candidate.x<enemy_max+clearance:continue
			for step: int in 40:
				controller.router.set_move_axis(clampf((candidate.x-motor.global_position.x)/5.5,-1,1))
				await tick()
				if is_trace_cancelled(): return false
				if absf(candidate.x-motor.global_position.x)<1:break
			if motor.is_on_floor() and absf(candidate.x-motor.global_position.x)<1:
				bank=motor.global_position;found_bank=true;break
		if not found_bank:
			record_check(false, "unsafe recoil bank before enemy shot " + id)
			return false
	var start := trace_ticks
	var initial_health := controller.actor_resources.health.current
	policy_observations.append({"tick": trace_ticks, "kind": "kill_bank_enter", "enemy": id, "position": SNAPSHOT.pair(bank), "enemy_health": actor.health.current, "recoil_clearance": recoil_distance, "target_screen": target_screen_facts(enemy)})
	for unused: int in 900:
		if actor.health.terminal:
			for settle: int in 110:
				controller.router.set_move_axis(clampf((bank.x-motor.global_position.x)/5.5,-1,1))
				await tick()
				if is_trace_cancelled(): return false
				if motor.is_on_floor() and absf(motor.global_position.x-bank.x)<1 and controller.shoot_ability.cooldown_remaining<=0: break
			policy_observations.append({"tick": trace_ticks, "kind": "actual_enemy_dead", "enemy": id, "health": actor.health.current, "position": SNAPSHOT.pair(enemy.global_position), "player_position": SNAPSHOT.pair(motor.global_position)})
			return motor.is_on_floor() and absf(motor.global_position.x-bank.x)<2
		if trace_ticks-start > 900 or controller.actor_resources.health.current < initial_health: break
		var separation := enemy.global_position-motor.global_position
		if absf(separation.y)<60 and absf(separation.x)<55 and (enemy.velocity.x*separation.x<0 or absf(separation.x)<35):
			var away := -signf(separation.x)
			if away==0:away=-1
			var retreat_bank := motor.global_position+Vector2(away*55,0)
			if bank_supported(motor.global_position,retreat_bank-motor.global_position) and bank_supported(retreat_bank,Vector2(away*recoil_distance,0)):
				bank=retreat_bank
				policy_observations.append({"tick":trace_ticks,"kind":"retreat_from_live_body","enemy":id,"enemy_position":SNAPSHOT.pair(enemy.global_position),"bank":SNAPSHOT.pair(bank)})
		controller.router.set_move_axis(clampf((bank.x-motor.global_position.x)/5.5,-1,1))
		if incoming_projectile(motor.global_position):
			# A bank with incoming locked fire is not made safe by waiting on it.
			var back := Vector2(-signf(enemy.global_position.x-bank.x)*55,0)
			if not bank_supported(bank,back): break
			controller.router.set_move_axis(signf(back.x))
			await tick(8)
			if is_trace_cancelled(): return false
			continue
		if motor.is_on_floor() and absf(motor.global_position.x-bank.x)<1 and absf(motor.global_position.y-bank.y)<2 and controller.shoot_ability.cooldown_remaining<=0 and controller.shot_energy.can_fire() and clear_shot(enemy):
			if not bank_supported(motor.global_position,Vector2(-signf(enemy.global_position.x-motor.global_position.x)*recoil_distance,0)): break
			var attempts: int = int(_policy_attempts.get(id,0))
			if attempts>=6: break
			_policy_attempts[id] = attempts+1
			var lead := enemy.velocity * minf(.3,motor.global_position.distance_to(enemy.global_position)/motor.tuning.projectile_speed)
			var direction := (motor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter).world_direction(motor.get_canvas_transform()*(enemy.global_position+lead))
			policy_observations.append({"tick":trace_ticks+1,"kind":"enemy_shot_request","enemy":id,"target_screen":target_screen_facts(enemy),"position":SNAPSHOT.pair(motor.global_position),"direction":SNAPSHOT.pair(direction)})
			controller.router.request_action(&"shoot_release",direction)
		await tick()
		if is_trace_cancelled(): return false
	record_check(false,"enemy bank unsafe/no damage progress within budget " + id)
	return false

func bait_then_bypass(enemy: EnemyMotor, id: String) -> bool:
	if is_trace_cancelled(): return false
	var actor := enemy.get_node("Actor") as EnemyActor
	var attack := actor.attack_behavior
	if attack == null: return false
	var bank := motor.global_position
	var direction := signf(controller.router.axis)
	if direction==0:direction=signf(enemy.global_position.x-bank.x)
	if direction==0:return false
	var distance:=bank.distance_to(attack.home)
	if distance>actor.definition.activation_range or distance>125:
		policy_observations.append({"tick":trace_ticks,"kind":"engagement_ineligible" if distance>actor.definition.activation_range else "supported_bait_approach","reason":"out_of_range" if distance>actor.definition.activation_range else "approach_actual_visible_target","enemy":id,"distance":distance,"actor_processing":actor.is_physics_processing(),"health":actor.health.current})
		_bypass_until[id]=trace_ticks+4
		return true
	_policy_attempts[id]=int(_policy_attempts.get(id,0))+1
	var initial_health:=controller.actor_resources.health.current
	var saw_telegraph:=attack.state==&"telegraph"
	var saw_attack:=attack.state==&"attack"
	var start_enemy:=enemy.global_position
	var transition_start:int=int(_enemy_transitions.get(id,0))
	var retreat_target:=bank-Vector2(direction*40,0)
	for unused:int in 300:
		if actor.health.terminal:return true
		if controller.actor_resources.health.current<initial_health:break
		if attack.state==&"telegraph":saw_telegraph=true
		if attack.state==&"attack":saw_attack=true
		if saw_attack and bank_supported(motor.global_position,retreat_target-motor.global_position):
			controller.router.set_move_axis(clampf((retreat_target.x-motor.global_position.x)/5.5,-1,1))
		else:controller.router.set_move_axis(0)
		if saw_telegraph and saw_attack and attack.state==&"recovery" and not incoming_projectile(motor.global_position,.7):
			var takeoff:=Vector2(enemy.global_position.x-direction*90,bank.y)
			var receiver:=Vector2(enemy.global_position.x+direction*95,bank.y)
			if absf(enemy.global_position.y-bank.y)>60:
				# An aerial target safely above a real floor can be passed beneath;
				# ordinary motion still performs the actual crossing afterward.
				_bypass_until[id]=trace_ticks+maxi(1,int((actor.definition.recovery_duration-attack.state_time)*60))
				policy_observations.append({"tick":trace_ticks,"kind":"actual_bait_window","enemy":id,"transition_start":transition_start,"transition_now":_enemy_transitions.get(id,0),"state":str(attack.state),"enemy_position":SNAPSHOT.pair(enemy.global_position),"player_position":SNAPSHOT.pair(motor.global_position),"target_screen":target_screen_facts(enemy),"strategy":"observed aerial recovery window; crossing not yet claimed"})
				return true
			if bank_supported(takeoff) and bank_supported(receiver) and absf(motor.global_position.x-takeoff.x)<200:
				if not await super.move_to(takeoff.x,120):break
				var crossed:bool=await jump_point(receiver)
				if is_trace_cancelled(): return false
				if crossed and controller.actor_resources.health.current==initial_health and not actor.health.terminal and direction*(motor.global_position.x-enemy.global_position.x)>30:
					_passed_enemies[id]=direction
					policy_observations.append({"tick":trace_ticks,"kind":"actual_nonkill_bypass","enemy":id,"enemy_health":actor.health.current,"transition_start":transition_start,"transition_now":_enemy_transitions.get(id,0),"enemy_displacement":enemy.global_position.distance_to(start_enemy),"player_position":SNAPSHOT.pair(motor.global_position),"enemy_position":SNAPSHOT.pair(enemy.global_position),"target_screen":target_screen_facts(enemy)})
					return true
				break
		await tick()
		if is_trace_cancelled(): return false
	record_check(false,"no safe non-kill recovery/crossing within budget "+id)
	return false

func forward_module(module: PlatformingModule) -> bool:
	if is_trace_cancelled(): return false
	if encounter_policy == "blind_legacy": return await super.forward_module(module)
	policy_move_goal=module.world_exit().x
	_enemy_policy_busy=true
	var ready := await prepare_threats()
	if is_trace_cancelled(): return false
	_enemy_policy_busy=false
	if not ready:return false
	critical_traversal+=1
	var ok: bool=await super.forward_module(module)
	if is_trace_cancelled(): return false
	critical_traversal-=1
	return ok

func reverse_module(module: PlatformingModule) -> bool:
	if is_trace_cancelled(): return false
	if encounter_policy == "blind_legacy": return await super.reverse_module(module)
	policy_move_goal=module.world_entry().x
	_enemy_policy_busy=true
	var ready := await prepare_threats()
	if is_trace_cancelled(): return false
	_enemy_policy_busy=false
	if not ready:return false
	critical_traversal+=1
	var ok: bool=await super.reverse_module(module)
	if is_trace_cancelled(): return false
	critical_traversal-=1
	return ok

func collect_resource_receipts(observed_tick: int = -1) -> void:
	if _observation_sealed: return
	var state := controller.actor_resources.stamina
	for id: StringName in state._receipts:
		var key := "%s/%s" % [state.epoch,id]
		if _resource_seen.has(key): continue
		_resource_seen[key]=true
		var value: Dictionary=state._receipts[id]
		var result: ActorResourceResult=value.result
		resource_receipts.append({"tick":trace_ticks+1 if observed_tick < 0 else observed_tick,"event_id":str(id),"operation":str(result.operation),"status":int(result.status),"amount_applied":result.amount_applied,"requested_amount":value.amount,"current":result.snapshot.current,"capacity":result.snapshot.capacity,"epoch":result.snapshot.epoch,"session_id":controller.session_id})

func path_to(from_id: String, to_id: String) -> Array:
	if encounter_policy=="blind_legacy":return super.path_to(from_id,to_id)
	# The aware policy chooses actual declared geometric distance, never enemy
	# deletion or a hidden test-only connection. This is not a Motor proof.
	var pending:Array=[from_id];var distances:Dictionary={from_id:0.0};var via:Dictionary={}
	while not pending.is_empty():
		pending.sort_custom(func(a,b):return float(distances[a])<float(distances[b]))
		var current:String=pending.pop_front()
		if current==to_id:break
		for edge:Dictionary in stage.manifest.connections:
			if edge.kind not in ["horizontal","stairs","diagonal","drop"] or (edge.kind=="drop" and not edge.has("path")) or (edge.condition!="open" and not region_state.opened.has(edge.id)):continue
			var next: String=str(edge.b) if edge.a==current else str(edge.a) if edge.b==current and edge.bidirectional else ""
			if next.is_empty():continue
			var a:Dictionary=PlainsRegionGenerator.new()._area(stage.manifest,current)
			var b:Dictionary=PlainsRegionGenerator.new()._area(stage.manifest,next)
			var weight:float=Vector2(a.position[0],a.position[1]).distance_to(Vector2(b.position[0],b.position[1]))
			var cost:float=float(distances[current])+weight
			if not distances.has(next) or cost<float(distances[next]):
				distances[next]=cost;via[next]={"edge":edge,"forward":edge.a==current,"previous":current}
				if not pending.has(next):pending.append(next)
	if not distances.has(to_id):return []
	var result:Array=[];var current:=to_id
	while current!=from_id:
		var step:Dictionary=via[current];result.push_front({"edge":step.edge,"forward":step.forward});current=str(step.previous)
	return result

func target_screen_facts(enemy: EnemyMotor) -> Dictionary:
	var actor:=enemy.get_node("Actor") as EnemyActor
	var half:=actor.definition.collision_size*.5
	var transform:=enemy.get_global_transform_with_canvas()
	var top_left:Vector2=transform*(-half)
	var bottom_right:Vector2=transform*half
	var rect:=Rect2(top_left,bottom_right-top_left).abs()
	var viewport:=app.get_viewport_rect()
	return {"body_aabb":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"viewport":[viewport.position.x,viewport.position.y,viewport.size.x,viewport.size.y],"intersects_viewport":viewport.intersects(rect),"fully_inside_viewport":viewport.encloses(rect),"scope":"actual canvas frustum only; HUD/occlusion/telegraph readability unverified; policy reads privileged manifest/AI state"}
