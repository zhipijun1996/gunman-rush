extends RefCounted
## Test-only formal App entry and read-only Bell evidence. No replacement map,
## collision, gameplay authority or strong scene-owner reference is stored here.
var platform_scope := ""
var platform_bell_events: Array[Dictionary] = []
var platform_fired_shots: Array[Dictionary] = []
var platform_damage_commits: Array[Dictionary] = []
var battle_boss_health: HealthState


static func create_formal_app(tree: SceneTree) -> DemoApp:
	var app := DemoApp.new()
	app.meta_persistence_enabled = false
	tree.root.add_child(app)
	app.start_plains("underworld-r3-continuous-boss")
	for _frame: int in 8:
		await tree.physics_frame
	return app


static func place_initial_entry(tree: SceneTree, app: DemoApp, boss: BossMotor) -> void:
	# The same disclosed one-time room-entry fixture used by the full consumer.
	app.player.reset_at(boss.global_position + Vector2(-250, 47))
	for _frame: int in 5:
		await tree.physics_frame


func validate_first_group(pilot: RefCounted, events: Array[Dictionary], lifecycle: Array[Dictionary], failures: Array[String]) -> Dictionary:
	return _validate(pilot, events, lifecycle, failures, 2)


func validate_full_fight(pilot: RefCounted, events: Array[Dictionary], lifecycle: Array[Dictionary], failures: Array[String]) -> Dictionary:
	return _validate(pilot, events, lifecycle, failures, 40)


static func reward_units(stage: PlainsRegionStage) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var source := BellstriderRewards.source_id(stage)
	for pickup: Dictionary in stage.pickups:
		if str(pickup.get("source",""))==source and pickup.get("kind","")=="coin": result.append(pickup.duplicate(true))
	return result


static func platform_observation(stage: PlainsRegionStage, player: PlayerMotor, controller: PlayerController, encounter: BellstriderEncounter) -> Dictionary:
	# Observe the already installed Module shapes and native Motor collisions.
	# This never creates shapes, raycasts a replacement floor or predicts physics.
	var result: Dictionary = {"valid": false, "platforms": [], "floor_contacts": [], "max_jumps": player.tuning.max_jumps, "effective_max_jumps": controller.jump_ability.maximum_jumps(), "hook_enabled": controller.traversal.hook_enabled, "rig_bounds": encounter.body_contact_rect()}
	var selected: PlatformingModule = null
	for module: PlatformingModule in stage.assembler.modules:
		if module.definition.module_id == &"plains_bellstrider_arena":
			if selected != null:
				return result
			selected = module
	if selected == null:
		return result
	for index: int in selected.definition.one_way_platform_indices:
		var body := selected.get_node_or_null("Platform%d" % index) as StaticBody2D
		var shape: CollisionShape2D = body.get_node_or_null("CollisionShape2D") as CollisionShape2D if body != null else null
		if shape == null or not shape.shape is RectangleShape2D or not shape.one_way_collision or shape.disabled or not body.is_in_group("one_way_platform"):
			return result
		var authored: Rect2 = selected.global_transform * selected.definition.platforms[index]
		var installed: Rect2 = shape.global_transform * shape.shape.get_rect()
		if not authored.is_equal_approx(installed):
			return result
		result.platforms.append({"path": str(body.get_path()), "body_id": body.get_instance_id(), "rect_xywh": [installed.position.x,installed.position.y,installed.size.x,installed.size.y], "module": str(selected.definition.module_id), "platform_index": index, "rect": installed})
	for index: int in player.get_slide_collision_count():
		var collision := player.get_slide_collision(index)
		var body := collision.get_collider() as PhysicsBody2D
		if body != null and collision.get_normal().dot(player.up_direction) > .7:
			result.floor_contacts.append({"path": str(body.get_path()), "body_id": body.get_instance_id(), "normal": [collision.get_normal().x,collision.get_normal().y], "point": [collision.get_position().x,collision.get_position().y]})
	var rig: Rect2 = result.rig_bounds
	result["rig_xywh"] = [rig.position.x,rig.position.y,rig.size.x,rig.size.y]
	result.valid = not result.platforms.is_empty()
	return result


func observe_bell_event(value: Dictionary) -> void:
	# Observe the real signal before its production 256-row history can roll off.
	# No authority, callback mutation, replay or replacement of damage processing.
	if value.get("event", &"") in [&"bellstrider_group", &"bellstrider_bell_hit", &"bellstrider_death"]:
		platform_bell_events.append({"tick": Engine.get_physics_frames(), "actual": value.duplicate(true)})


func _validate(bell_pilot: RefCounted, damage_events: Array[Dictionary], lifecycle_events: Array[Dictionary], failure: Array[String], expected_hits: int) -> Dictionary:
	if platform_scope.is_empty():
		return {}
	var checks: Dictionary = {"actual_Bell_pilot_observed": bell_pilot != null}
	var ledger: Array = bell_pilot.platform_trials if bell_pilot != null else []
	checks["no_platform_strategy_failure"] = bell_pilot != null and str(bell_pilot.platform_failure).is_empty()
	var committed: Dictionary = {}
	var impact_hits: Array[Dictionary] = []
	var death: Dictionary = {}
	for row: Dictionary in platform_bell_events:
		var event: Dictionary = row.actual
		var group_id := int(event.get("group", -1))
		if event.get("event", &"") == &"bellstrider_group":
			committed[group_id] = event.get("plan", {}).duplicate(true)
		elif event.get("event", &"") == &"bellstrider_bell_hit":
			impact_hits.append(row)
		elif event.get("event", &"") == &"bellstrider_death":
			death = row
	var attribution := _join_platform_shot_hits(impact_hits, damage_events, expected_hits)
	checks.merge(attribution.checks, true)
	var hits: Dictionary = attribution.hits_by_fire_group
	var fired_counts: Dictionary = attribution.fired_counts
	var submitted: Dictionary = {}
	if bell_pilot != null:
		for row: Dictionary in bell_pilot.input_rows:
			if row.get("action", "") == "shoot_release" and bool(row.get("submitted", false)):
				var group_id := int(row.get("group", -1))
				submitted[group_id] = int(submitted.get(group_id, 0)) + 1
	for group_id: int in submitted:
		checks["group_%d_original_two_shot_cap" % group_id] = int(submitted[group_id]) <= 2
	for group_id: int in committed:
		var group_hits: Array = hits.get(group_id, [])
		checks["fire_group_%d_two_actual_shots_two_base_one_hits" % group_id] = int(fired_counts.get(group_id, 0)) == 2 and group_hits.size() == 2 and group_hits.all(func(row: Dictionary) -> bool: return is_equal_approx(float(row.actual.get("amount", 0)), 1.0))
	var expected: Array[int] = []
	for group_id: int in committed:
		if str(committed[group_id].get("kind", "")) == "roll" and (platform_scope == "all" or group_id == 1):
			expected.append(group_id)
	checks["at_least_one_actual_eligible_roll"] = not expected.is_empty()
	var observed: Array[int] = []
	for trial: Dictionary in ledger:
		var group_id := int(trial.group)
		observed.append(group_id)
		var prefix := "group_%d_" % group_id
		checks[prefix + "actual_committed_plan"] = committed.has(group_id) and trial.plan == committed[group_id]
		checks[prefix + "completed_actual_observation"] = str(trial.phase) == "complete"
		checks[prefix + "HP_unchanged"] = is_equal_approx(float(trial.HP_start), float(trial.HP_min))
		var first_tick := int(trial.get("first_tick", -1))
		var complete_tick := int(trial.get("complete_tick", -1))
		var player_events := 0
		for event: Dictionary in damage_events:
			if event.target == "player" and int(event.tick) >= first_tick and int(event.tick) <= complete_tick:
				player_events += 1
		checks[prefix + "whole_group_no_player_settlement_inclusive"] = first_tick >= 0 and complete_tick >= first_tick and player_events == 0
		var expected_legs := 2 if bool(trial.plan.get("return_roll", false)) else 1
		checks[prefix + "every_committed_leg_observed"] = trial.legs.size() == expected_legs
		for index: int in trial.legs.size():
			var leg: Dictionary = trial.legs[index]
			var key := prefix + "leg_%d_" % index
			checks[key + "actual_warning_identity"] = int(leg.index) == index and str(leg.warning) == ("roll_warning" if index == 0 else "combo_warning")
			checks[key + "actual_support_before_request"] = int(leg.get("support_tick", -1)) >= int(leg.warning_tick) and int(leg.get("trigger_tick", -1)) > int(leg.get("support_tick", -1))
			checks[key + "actual_evade_chain"] = bool(leg.evade_requested) and bool(leg.evade_airborne) and bool(leg.crossed_airborne) and bool(leg.landed) and int(leg.get("trigger_tick", -1)) < int(leg.get("takeoff_tick", -1)) and int(leg.get("takeoff_tick", -1)) <= int(leg.get("crossing_tick", -1)) and int(leg.get("crossing_tick", -1)) < int(leg.get("landing_tick", -1))
			if index == 1:
				var previous: Dictionary = trial.legs[0]
				checks[key + "previous_real_landing_same_support"] = int(previous.get("landing_tick", -1)) <= int(leg.get("support_tick", -1)) and previous.target.body_id == leg.target.body_id
		var actual_hits: Array = hits.get(group_id, [])
		checks[prefix + "two_requests_two_actual_base_one_hits"] = int(submitted.get(group_id, 0)) == 2 and int(fired_counts.get(group_id, 0)) == 2 and actual_hits.size() == 2 and actual_hits.all(func(row: Dictionary) -> bool: return is_equal_approx(float(row.actual.get("amount", 0)), 1.0))
		if str(trial.get("completion_reason", "")) == "actual_terminal_pending_receipt_proof":
			checks[prefix + "terminal_has_real_death_event"] = not death.is_empty() and int(death.actual.get("group", -1)) == group_id and int(death.tick) <= complete_tick
	observed.sort()
	expected.sort()
	checks["every_eligible_roll_group_exactly_once"] = observed == expected
	# Terminal is never inferred from invalid scene objects. The original real
	# HealthState owners and defeated observer survive arena teardown independently.
	if not death.is_empty() or (battle_boss_health != null and battle_boss_health.terminal):
		var group_id := int(death.get("actual", {}).get("group", -1))
		var final_hits: Array = hits.get(group_id, [])
		checks["terminal_actual_health_death_and_defeated"] = not death.is_empty() and battle_boss_health != null and battle_boss_health.terminal and is_zero_approx(battle_boss_health.current) and lifecycle_events.any(func(row: Dictionary) -> bool: return row.get("event", "") == "boss_defeated" and bool(row.get("terminal", false)) and is_zero_approx(float(row.get("health", -1))))
		checks["terminal_group_two_real_hits_not_extra_shots"] = int(submitted.get(group_id, 0)) == 2 and int(fired_counts.get(group_id, 0)) == 2 and final_hits.size() == 2 and final_hits.all(func(row: Dictionary) -> bool: return is_equal_approx(float(row.actual.get("amount", 0)), 1.0))
	if expected_hits == 2:
		checks["first_group_only_current_forty_to_thirty_eight"] = platform_scope == "first" and committed.size() == 1 and committed.has(1) and ledger.size() == 1 and int(ledger[0].group) == 1 and battle_boss_health != null and not battle_boss_health.terminal and is_equal_approx(battle_boss_health.capacity, 40.0) and is_equal_approx(battle_boss_health.current, 38.0)
	for key: String in checks:
		if not bool(checks[key]):
			failure.append("platform diagnostic failed: " + key)
	if bell_pilot != null:
		# Full history is emitted once here, not nested into every frame/event.
		bell_pilot.input_rows.append({"action": "platform_trial_receipt_verdict", "scope": platform_scope, "checks": checks, "ledger": ledger.duplicate(true), "actual_bell_event_stream": platform_bell_events.duplicate(true), "actual_fired_shots": platform_fired_shots.duplicate(true), "actual_damage_contexts": platform_damage_commits.duplicate(true), "shot_hit_attribution": attribution.joined, "note": "R3-CURRENT-CONTENT-CONTRACT-01; first group or full fight shares actual support and the same four-source shot identity join"})

	return checks


func observe_actual_shot(shot_id: int, encounter: BellstriderEncounter, controller: PlayerController) -> void:
	# Actual ShootAbility signal, not a request ordinal or impact-time label.
	platform_fired_shots.append({"tick": Engine.get_physics_frames(), "shot_id": shot_id, "fire_group": int(encounter.combat_metrics().get("groups_started", -1)), "owner_id": controller.motor.get_instance_id(), "session_id": controller.session_id})


func observe_boss_damage(context: Dictionary) -> void:
	# The existing policy-bound receiver emits only after actual HP loss. Copy
	# primitive evidence only; never retain its Callable or receiver/controller.
	var row: Dictionary = {"tick": Engine.get_physics_frames()}
	for key: String in ["shot_id", "session_id", "source_actor_id", "target_actor_id", "target_epoch"]:
		if context.get(key) is int:
			row[key] = context[key]
	for key: String in ["event_id", "damage_type", "source_faction"]:
		if context.get(key) is String or context.get(key) is StringName:
			row[key] = str(context[key])
	if context.get("amount") is float or context.get("amount") is int:
		row.amount = float(context.amount)
	if context.get("skill_attack") is bool:
		row.skill_attack = context.skill_attack
	platform_damage_commits.append(row)


func _join_platform_shot_hits(impact_hits: Array, damage_events: Array[Dictionary], expected_hits: int) -> Dictionary:
	# Finite receipt join of three existing signal sources. Event IDs stay opaque;
	# their formatting and request/impact group are never used to infer a shot.
	var checks: Dictionary = {("forty_actual_shots_and_committed_hits" if expected_hits == 40 else "two_actual_shots_and_committed_hits"): platform_fired_shots.size() == expected_hits and platform_damage_commits.size() == expected_hits and impact_hits.size() == expected_hits, "actual_shot_identity_unique": true, "actual_owner_session_consistent": true, "committed_projectile_identity_complete": true, "opaque_event_join_unique": true, "real_shot_context_owner_session_match": true, "each_actual_shot_hits_once": true, "all_actual_hits_base_one": true, ("actual_HP_chain_forty_to_zero" if expected_hits == 40 else "actual_HP_chain_forty_to_thirty_eight"): true}
	var hp_chain_key := "actual_HP_chain_forty_to_zero" if expected_hits == 40 else "actual_HP_chain_forty_to_thirty_eight"
	var fired: Dictionary = {}
	var fired_counts: Dictionary = {}
	var owner := -1
	var session := -1
	for row: Dictionary in platform_fired_shots:
		var id := int(row.shot_id)
		if id <= 0 or int(row.owner_id) <= 0 or int(row.session_id) <= 0 or int(row.fire_group) <= 0 or fired.has(id):
			checks.actual_shot_identity_unique = false
			continue
		if owner < 0:
			owner = int(row.owner_id)
			session = int(row.session_id)
		if int(row.owner_id) != owner or int(row.session_id) != session:
			checks.actual_owner_session_consistent = false
		fired[id] = row
		var group_id := int(row.fire_group)
		fired_counts[group_id] = int(fired_counts.get(group_id, 0)) + 1
	var bell_by_event: Dictionary = {}
	var previous_hp: float = battle_boss_health.capacity if battle_boss_health != null else -1.0
	for row: Dictionary in impact_hits:
		var event: Dictionary = row.actual
		var id := str(event.get("event_id", ""))
		if id.is_empty() or bell_by_event.has(id):
			checks.opaque_event_join_unique = false
			continue
		bell_by_event[id] = row
		if not is_equal_approx(float(event.get("amount", 0)), 1.0):
			checks.all_actual_hits_base_one = false
		if not is_equal_approx(previous_hp - float(event.get("health", -1)), 1.0):
			checks[hp_chain_key] = false
		previous_hp = float(event.get("health", -1))
	checks[hp_chain_key] = bool(checks[hp_chain_key]) and battle_boss_health != null and is_equal_approx(battle_boss_health.capacity, 40.0) and is_equal_approx(previous_hp, battle_boss_health.capacity - expected_hits)
	var batch_by_event: Dictionary = {}
	for row: Dictionary in damage_events:
		if row.target != "boss":
			continue
		var id := str(row.event)
		if id.is_empty() or batch_by_event.has(id):
			checks.opaque_event_join_unique = false
			continue
		batch_by_event[id] = row
	var seen_context_events: Dictionary = {}
	var hit_shots: Dictionary = {}
	var hits_by_fire_group: Dictionary = {}
	var joined: Array[Dictionary] = []
	for context: Dictionary in platform_damage_commits:
		if not context.has_all(["shot_id", "session_id", "source_actor_id", "event_id", "amount", "damage_type", "source_faction", "skill_attack"]) or context.get("damage_type", "") != "projectile" or context.get("source_faction", "") != "player" or bool(context.get("skill_attack", true)):
			checks.committed_projectile_identity_complete = false
			continue
		var event_id := str(context.event_id)
		var shot_id := int(context.shot_id)
		if event_id.is_empty() or seen_context_events.has(event_id) or not bell_by_event.has(event_id) or not batch_by_event.has(event_id):
			checks.opaque_event_join_unique = false
			continue
		seen_context_events[event_id] = true
		if not fired.has(shot_id):
			checks.real_shot_context_owner_session_match = false
			continue
		var shot: Dictionary = fired[shot_id]
		if int(context.source_actor_id) != int(shot.owner_id) or int(context.session_id) != int(shot.session_id) or int(shot.tick) > int(context.tick):
			checks.real_shot_context_owner_session_match = false
			continue
		if hit_shots.has(shot_id):
			checks.each_actual_shot_hits_once = false
			continue
		hit_shots[shot_id] = true
		var bell: Dictionary = bell_by_event[event_id]
		var batch: Dictionary = batch_by_event[event_id]
		if not is_equal_approx(float(context.amount), 1.0) or not is_equal_approx(float(batch.amount), 1.0) or not is_equal_approx(float(batch.health), float(bell.actual.health)):
			checks.all_actual_hits_base_one = false
		var group_id := int(shot.fire_group)
		var row: Dictionary = {"tick": bell.tick, "actual": bell.actual, "fire": shot, "committed_context": context, "policy_batch": batch, "fire_group": group_id, "impact_group": int(bell.actual.group)}
		if not hits_by_fire_group.has(group_id): hits_by_fire_group[group_id] = []
		hits_by_fire_group[group_id].append(row)
		joined.append(row)
	checks["all_four_sources_one_to_one_forty" if expected_hits == 40 else "all_four_sources_one_to_one_two"] = fired.size() == expected_hits and hit_shots.size() == expected_hits and seen_context_events.size() == expected_hits and bell_by_event.size() == expected_hits and batch_by_event.size() == expected_hits and joined.size() == expected_hits
	return {"checks": checks, "hits_by_fire_group": hits_by_fire_group, "fired_counts": fired_counts, "joined": joined}
