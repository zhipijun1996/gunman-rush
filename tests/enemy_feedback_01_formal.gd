## v8: restored strict persistent-corpse assertions from 0d5b72c following the
## latest user rejection of exploded disappearance and custom death sound.
extends SceneTree
## Real DemoApp default start_plains / generated spawn / damage / drop / rebuild.
## Each target uses one explicitly recorded initial player Motor positioning on
## existing safe terrain. Subsequent movement and shooting use InputRouter.
## No enemy, AI, HP, collider, damage, reward, manifest or energy is altered.
const TARGETS: Array[StringName] = [&"plains_charger", &"plains_diver"]
var checks := 0
var failures: Array[String] = []
var inventory: Array[Dictionary] = []
var results: Array[Dictionary] = []
var events: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var app: DemoApp
var original_manifest := ""
var ready_receipts: Array[Dictionary] = []
var remains_teardown: Array[WeakRef] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func actual_final_body(art: UnderworldEnemy) -> bool:
	var remains := art.feedback_remains
	# Keep this consumer's dependency one-way. Inferring the nested rig type
	# here retains a GDScript resource graph even in a load-only/no-instance
	# probe; use the exact concrete script and actual runtime capability instead.
	var visual: Variant = art.get("revision_visual")
	if visual != null:
		var rig: RefCounted = visual.get("rig") as RefCounted
		return remains.get_script().resource_path=="res://game/enemies/presentation/plains_revision_remains.gd" and remains.frame_index==7 and bool(remains.get("_finished_death")) and remains.get("_rig")==rig and remains.source==rig.get("texture") and remains.bounds==rig.get("bounds")
	var frames: RefCounted = art.get("feedback_frames") as RefCounted
	return frames!=null and remains.frame_index==7 and remains.source==frames.call("texture",7) and remains.bounds==frames.call("bounds",7)

func stage_ready(phase: String) -> bool:
	var started := Time.get_ticks_msec()
	var frames := 0
	while Time.get_ticks_msec() - started < 60000 and frames < 3600:
		if not app._stage_pending and is_instance_valid(app.stage) and app.stage is PlainsRegionStage and (app.stage as PlainsRegionStage).assembly_ok and app._can_interact():
			ready_receipts.append({"phase": phase, "frames": frames, "milliseconds": Time.get_ticks_msec() - started, "assembly_ok": true, "stage_pending": false})
			return true
		await physics_frame
		await process_frame
		frames += 1
	ready_receipts.append({"phase": phase, "frames": frames, "milliseconds": Time.get_ticks_msec() - started, "assembly_ok": false, "stage_pending": app._stage_pending})
	return false

func ticks(count: int, phase: String) -> void:
	for _frame: int in count:
		await physics_frame
		await process_frame
		if is_instance_valid(app.controller):
			trace.append({"phase": phase, "tick": Engine.get_physics_frames(), "player_position": app.player.position, "HP": app.controller.actor_resources.health.current, "energy": app.controller.actor_resources.stamina.current, "actor_epoch": app.lifetime.actor_epoch, "drop_count": app.region_state.drops.size() if app.region_state != null else -1})

func clear_terrain_line(from: Vector2, to: Vector2) -> bool:
	var space := app.player.get_world_2d().direct_space_state
	for y_offset: float in [-3.0, 0.0, 3.0]:
		var query := PhysicsRayQueryParameters2D.create(from + Vector2(0, y_offset), to + Vector2(0, y_offset), 1, [app.player.get_rid()])
		if not space.intersect_ray(query).is_empty():
			return false
	return true

func find_initial_fixture(stable_id: StringName) -> Dictionary:
	var stage := app.stage as PlainsRegionStage
	var space := app.player.get_world_2d().direct_space_state
	for index: int in stage.enemies.size():
		var motor := stage.enemies[index]
		var actor := motor.get_node("Actor") as EnemyActor
		if actor.definition.stable_id != stable_id or actor.health.terminal:
			continue
		for x_offset: float in [-160.0, 160.0, -220.0, 220.0, -110.0, 110.0, -280.0, 280.0]:
			var x := motor.global_position.x + x_offset
			var ray := PhysicsRayQueryParameters2D.create(Vector2(x, motor.global_position.y - 60), Vector2(x, motor.global_position.y + 280), 1, [app.player.get_rid()])
			var ground := space.intersect_ray(ray)
			if ground.is_empty() or (ground.normal as Vector2).dot(Vector2.UP) < .7:
				continue
			var location := (ground.position as Vector2) - Vector2(0, 18)
			if not app.segment.is_safe(location) or not clear_terrain_line(location, motor.global_position):
				continue
			var retreat_side := signf(x_offset)
			var supported := true
			for travel: float in [24.0, 48.0, 72.0, 96.0]:
				if not app.segment.is_safe(location + Vector2(retreat_side * travel, 0)):
					supported = false
			if not supported:
				continue
			var isolated := true
			for other: EnemyMotor in stage.enemies:
				if other != motor and other.global_position.distance_to(location) < 85:
					isolated = false
			if isolated:
				return {"index": index, "id": str(stage.enemy_manifest[index].id), "stable_id": str(stable_id), "location": location, "target_initial": motor.global_position, "positioning": "one initial player.motor.reset_at on existing SegmentRespawn.is_safe terrain; not natural traversal"}
	return {}

func fire_at_actual_target(motor: EnemyMotor, fixture_location: Vector2) -> bool:
	var actor := motor.get_node("Actor") as EnemyActor
	for attempt: int in 12:
		if actor.health.terminal:
			return true
		if not app._can_interact():
			return false
		# Legitimate movement returns from recoil toward the recorded supported
		# starting point. Never reset the body or regenerate resources here.
		for _frame: int in 120:
			var offset := fixture_location.x - app.player.global_position.x
			app.controller.router.set_move_axis(signf(offset) if absf(offset) > 8 else 0)
			if absf(offset) <= 8 and app.player.is_on_floor() and app.controller.shoot_ability.cooldown_remaining <= 0 and app.controller.shot_energy.can_fire():
				break
			await ticks(1, "natural_recoil_recovery")
			if not app._can_interact():
				return false
		app.controller.router.set_move_axis(0)
		var distance := app.player.global_position.distance_to(motor.global_position)
		var predicted := motor.global_position + motor.velocity * minf(.20, distance / app.player.tuning.projectile_speed)
		var direction := (predicted - app.player.global_position).normalized()
		app.controller.router.aim_direction = direction
		app.controller.router.request_action(&"shoot_release", direction)
		await ticks(32, "actual_router_shot_%s" % attempt)
	app.controller.router.set_move_axis(0)
	return actor.health.terminal

func verify_target(stable_id: StringName) -> void:
	var fixture := find_initial_fixture(stable_id)
	check(not fixture.is_empty(), "actual generated %s has a safe supported shooting fixture" % stable_id)
	if fixture.is_empty():
		results.append({"stable_id": str(stable_id), "status": "UNVERIFIED", "reason": "No safe supported unobstructed initial player position in this actual map; no fixture enemy injected"})
		return
	var stage := app.stage as PlainsRegionStage
	var motor := stage.enemies[int(fixture.index)]
	var actor := motor.get_node("Actor") as EnemyActor
	var art := motor.get_node("Presentation") as UnderworldEnemy
	check(art != null and art.feedback_sample != null, "default formal installer owns selected shared component for " + str(stable_id))
	if art == null or art.feedback_sample == null:
		return
	var initial_hp := actor.health.current
	var before_events := events.size()
	var before_shots := shots.size()
	var enemy_id := str(fixture.id)
	check(not app.region_state.drops.has(enemy_id), "actual live generated identity has no settled drop before shooting")
	actor.damageable.damaged.connect(func(context: Dictionary) -> void:
		events.append({"enemy_id": enemy_id, "tick": Engine.get_physics_frames(), "event_id": str(context.get("event_id", "")), "context": context.duplicate(), "HP": actor.health.current}))
	var player_hp := app.controller.actor_resources.health.current
	var player_energy := app.controller.actor_resources.stamina.current
	app.player.reset_at(fixture.location)
	app.controller.router.clear("enemy_feedback_01_initial_position_fixture")
	check(app.controller.actor_resources.health.current == player_hp and app.controller.actor_resources.stamina.current == player_energy, "initial positioning preserves real HP and energy")
	await ticks(4, "initial_position_fixture")
	check(app.player.is_on_floor(), "initial fixture reaches actual Motor-supported floor")
	var killed := await fire_at_actual_target(motor, fixture.location)
	check(killed and actor.health.terminal, "actual formal Router projectiles kill generated " + str(stable_id))
	check(shots.size() > before_shots and events.size() - before_events == ceili(initial_hp), "actual accepted projectile contexts account for original enemy HP")
	if not killed:
		results.append({"stable_id": str(stable_id), "id": enemy_id, "status": "UNVERIFIED", "fixture": fixture, "reason": "Bounded actual shooting did not kill target", "remaining_HP": actor.health.current})
		return
	check(art.feedback_sample.accepted_hit_count == ceili(initial_hp) - 1 and art.feedback_sample.accepted_death_count == 1, "actual formal consumer performs one death and each nonlethal hurt")
	check(art.feedback_particles.emitted_bursts == ceili(initial_hp) and art.feedback_sample.impact_serial == ceili(initial_hp), "actual default formal projectiles emit exactly one pixel burst per accepted HP receipt including death")
	check(art.feedback_remains.active and not art.feedback_remains.restored and art.feedback_remains.accepted_starts == 1 and art.feedback_remains.get_parent() == stage, "actual generated enemy has one accepted corpse owned by its real stage")
	await ticks(3, "formal_drop_settlement")
	check(app.region_state.drops.has(enemy_id), "DemoApp itself settles actual generated terminal identity")
	if not app.region_state.drops.has(enemy_id):
		return
	var drop: Dictionary = app.region_state.drops[enemy_id].duplicate(true)
	var drops_before := JSON.stringify(app.region_state.drops)
	var drop_state_before := observe_drop_state()
	var source_before := formal_source_summary(drop_state_before, enemy_id)
	check(formal_snapshot_errors(drop_state_before).is_empty(), "all actual physical units have valid types, values, live motion and receipt ownership")
	check(drop.get("units") is Array and int(source_before.count) == drop.units.size() and formal_number(drop.get("coin_total"), true, 0) and int(source_before.coin_total) == int(drop.coin_total), "all source unit identities, quantities and denominations equal the complete coin entitlement")
	var duplicate_count := stage.pickups.filter(func(row: Dictionary) -> bool: return str(row.id) == "drop_" + enemy_id).size()
	check(duplicate_count == (0 if drop.kind == "none" else 1), "formal terminal drop has exactly one pickup instance or configured none")
	if events.size() > before_events:
		check(not actor.damageable.receive_damage(events.back().context), "replayed actual projectile context cannot settle another lethal hit")
	await ticks(45, "formal_duplicate_ticks")
	var drop_state_after45 := observe_drop_state()
	var transition45 := formal_transition_errors(drop_state_before, drop_state_after45)
	check(transition45.is_empty(), "repeated official damage settlement ticks preserve exact drop receipt")
	check(formal_exact(formal_source_summary(drop_state_after45, enemy_id), source_before), "replay and repeated ticks preserve every source denomination identity and value")
	check(stage.pickups.filter(func(row: Dictionary) -> bool: return str(row.id) == "drop_" + enemy_id).size() == duplicate_count, "repeated ticks and replay never add another pickup")
	check(art.feedback_sample.flash_strength() == 0 and art.feedback_particles.active_bursts() == 0 and art.feedback_particles.emitted_bursts == ceili(initial_hp), "actual formal terminal replay adds no pixel burst and all impact effects expire")
	await ticks(130, "formal_persistent_corpse_over_two_seconds")
	check(art._death >= .65 and not art.visible and art.feedback_remains.active and art.feedback_remains.visible and art.feedback_remains.is_visible_in_tree(), "actual generated corpse remains visible for over two seconds after inherited parent fade")
	check(actual_final_body(art), "actual generated accepted corpse persists on its final current rig source or authored rest frame 7")
	var drop_state_after175 := observe_drop_state()
	var transition175 := formal_transition_errors(drop_state_before, drop_state_after175)
	check(art.feedback_remains.accepted_starts == 1 and transition175.is_empty(), "persistent corpse and repeated formal settlement preserve one death and exact drop receipt")
	check(formal_exact(formal_source_summary(drop_state_after175, enemy_id), source_before), "persistent observation preserves the full source unit set and every coin value")
	drop_observations.append({"enemy_id": enemy_id, "before": drop_state_before, "after45": drop_state_after45, "after175": drop_state_after175, "errors45": transition45, "errors175": transition175, "legacy_byte_comparison_before": drops_before})
	formal_derived_counterexamples(drop_state_before, drop_state_after175, enemy_id)
	results.append({"stable_id": str(stable_id), "id": enemy_id, "status": "verified", "fixture": fixture, "initial_HP": initial_hp, "projectile_contexts": events.size() - before_events, "shots": shots.size() - before_shots, "drop": drop, "pickup_instances": duplicate_count, "source_units": source_before, "hurt_count": art.feedback_sample.accepted_hit_count, "death_count": art.feedback_sample.accepted_death_count, "remains_age": art.feedback_remains.age, "remains_phase": str(art.feedback_remains.phase), "remains_accepted_starts": art.feedback_remains.accepted_starts})

func verify_actual_reload() -> void:
	var old_stage: WeakRef = weakref(app.stage)
	var drops_before := JSON.stringify(app.region_state.drops)
	var audio := app.get_tree().get_first_node_in_group(&"game_audio") as GameAudio
	var defeat_cues := int(audio.played.get(&"enemy_defeat", 0))
	var old_epoch := app.lifetime.actor_epoch
	var previous_remains: Array[WeakRef] = []
	for child: Node in app.stage.get_children():
		if child is EnemyFeedback01Remains:
			previous_remains.append(weakref(child))
	app._stage_pending = true
	app.controller.router.clear("stage_transition")
	app.call_deferred("_load_stage")
	var rebuilt := await stage_ready("actual_same_map_reload")
	check(rebuilt, "formal same-map _load_stage completes actual asynchronous assembly")
	if not rebuilt:
		return
	await ticks(3, "rebuilt_stage_ready")
	check(old_stage.get_ref() == null, "actual reload frees previous formal stage")
	check(previous_remains.all(func(reference: WeakRef) -> bool: return reference.get_ref() == null), "actual stage rebuild releases every prior stage sibling corpse")
	check(app.lifetime.actor_epoch > old_epoch, "actual reload cancels prior actor epoch")
	check(JSON.stringify(app.region_state.drops) == drops_before, "actual reload preserves drop receipt byte representation")
	check(int(audio.played.get(&"enemy_defeat", 0)) == defeat_cues, "actual saved dead actors produce no second defeat audio")
	var stage := app.stage as PlainsRegionStage
	check(JSON.stringify(stage.generated.manifest) == original_manifest, "actual reload uses unchanged generated Manifest")
	for result: Dictionary in results:
		if result.status != "verified":
			continue
		var found := false
		for index: int in stage.enemies.size():
			if str(stage.enemy_manifest[index].id) != str(result.id):
				continue
			found = true
			var motor := stage.enemies[index]
			var actor := motor.get_node("Actor") as EnemyActor
			var art := motor.get_node("Presentation") as UnderworldEnemy
			check(actor.health.terminal and not motor.visible, "official saved terminal actor stays dead and hidden after reload")
			check(art != null and art.feedback_sample != null and art.feedback_sample.restored_terminal and not art.feedback_sample.death_active and art.feedback_sample.accepted_death_count == 0 and art.feedback_sample.accepted_hit_count == 0, "actual restored corpse never starts new hurt or death performance")
			check(art.feedback_particles.emitted_bursts == 0 and art.feedback_particles.active_bursts() == 0 and art.feedback_sample.flash_strength() == 0, "official reload of dead actor emits no pixel particles or body flash")
			check(art.feedback_remains.active and art.feedback_remains.restored and art.feedback_remains.settled and art.feedback_remains.accepted_starts == 0, "official dead snapshot reconstructs static remains without replaying death motion")
			check(actual_final_body(art), "official dead reload directly reconstructs final current body source without new death animation")
			check(art.feedback_remains.get_parent() == stage and art.feedback_remains.visible and art.feedback_remains.is_visible_in_tree(), "official restored corpse stays visible despite hidden saved EnemyMotor")
			var expected := 0 if result.drop.kind == "none" else 1
			check(stage.pickups.filter(func(row: Dictionary) -> bool: return str(row.id) == "drop_" + str(result.id)).size() == expected, "official rebuild restores one existing drop instance")
			var restored_observation := observe_drop_state()
			check(formal_snapshot_errors(restored_observation).is_empty() and formal_exact(formal_source_summary(restored_observation, str(result.id)), result.source_units), "official rebuild restores every original source unit and exact denomination total without extra units")
		check(found, "same generated enemy identity restored for " + str(result.stable_id))

func run() -> void:
	app = DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	check(app.start_plains("enemy-feedback-01-formal"), "actual default start_plains accepts task seed")
	var ready := await stage_ready("default_start_plains")
	check(ready, "actual stage readiness and assembly observed before any fixture")
	if ready:
		app.player.get_node("KeyboardMouseAdapter").process_mode = Node.PROCESS_MODE_DISABLED
		app.controller.shoot_ability.shot_fired.connect(func(direction: Vector2, id: int) -> void:
			shots.append({"id": id, "tick": Engine.get_physics_frames(), "direction": direction, "muzzle": app.controller.shoot_ability.last_muzzle, "player": app.player.position}))
		var stage := app.stage as PlainsRegionStage
		original_manifest = JSON.stringify(stage.generated.manifest)
		for index: int in stage.enemies.size():
			var actor := stage.enemies[index].get_node("Actor") as EnemyActor
			inventory.append({"id": stage.enemy_manifest[index].id, "stable_id": str(actor.definition.stable_id), "behavior": str(actor.definition.behavior_id), "position": stage.enemies[index].position, "presentation": stage.enemies[index].get_node("Presentation").get_class()})
		for stable_id: StringName in TARGETS:
			await verify_target(stable_id)
		check(JSON.stringify((app.stage as PlainsRegionStage).generated.manifest) == original_manifest, "initial fixture and real combat never mutate generated Manifest")
		await verify_actual_reload()
		if is_instance_valid(app.stage):
			for child: Node in app.stage.get_children():
				if child is EnemyFeedback01Remains:
					remains_teardown.append(weakref(child))
	app.abandon_run()
	check(await load("res://tests/audio_teardown.gd").drain_world(app), "formal consumer teardown observes bounded actual audio release")
	app.free()
	for _frame: int in 4:
		await process_frame
	check(remains_teardown.all(func(reference: WeakRef) -> bool: return reference.get_ref() == null), "abandon and full DemoApp unload release all remaining corpse siblings")
	DirAccess.make_dir_recursive_absolute("res://build/enemy_feedback_01/v8")
	var output := {"feedback_revision": "dedicated_species_frames_and_persistent_corpse_v8", "task": "ENEMY-FEEDBACK-01", "checks": checks, "failures": failures, "ready": ready_receipts, "inventory": inventory, "targets": results, "shots": shots, "accepted_events": events, "trace": trace, "drop_observations": drop_observations, "scope": "real default DemoApp/start_plains generated actors, Router/projectile damage, official drop ledger and same-map rebuild; explicitly positioned player fixtures, not natural traversal", "not_verified": ["full natural traversal", "GPU visual quality", "user acceptance", "physical device"]}
	var file := FileAccess.open("res://build/enemy_feedback_01/v8/formal_runtime.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	print("ENEMY_FEEDBACK_01_FORMAL checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


# The old whole-drop byte guard covered immutable settlement, not the new
# Stage-owned physical animation. Keep every other field (including claimed,
# safe, unknown metadata, RNG and bonus receipt) exact in this formal fixture.
# Finite envelope checks catch corrupt animation state; dedicated loot-motion
# tests still own exact collision/return trajectories. No entitlement is relaxed.
const FORMAL_MOTION_EPSILON := 0.001
const FORMAL_UNIT_MOTION_FIELDS := ["position", "velocity", "age", "bounces", "rotation", "settled", "returning"]
var drop_observations: Array[Dictionary] = []

func observe_drop_state() -> Dictionary:
	var pickup_rows: Array[Dictionary] = []
	for pickup: Dictionary in (app.stage as PlainsRegionStage).pickups:
		var row := pickup.duplicate(true)
		# This optional raw flag is absent until a real void-return starts.
		row["loot_returning"] = pickup.get("loot_returning", false)
		for key: String in ["position", "spawn_origin", "loot_velocity", "loot_safe", "claimed_position"]:
			if row.get(key) is Vector2:
				var point: Vector2 = row[key]
				row[key] = [point.x, point.y]
		pickup_rows.append(row)
	return {"drops": app.region_state.drops.duplicate(true), "pickups": pickup_rows, "claimed": app.region_state.claimed.duplicate(true), "wallet_grants": app.wallet._grants.duplicate(true), "wallet_balance": app.wallet.balance, "prefix": str(app._run_receipt_prefix), "stage_index": app.director.stage_index, "stage_clock": (app.stage as PlainsRegionStage).clock, "physics_frame": Engine.get_physics_frames(), "physics_ticks_per_second": Engine.physics_ticks_per_second, "stage_instance_id": app.stage.get_instance_id(), "actor_epoch": app.lifetime.actor_epoch}

static func formal_number(value: Variant, integer := false, minimum := -INF) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and (not integer or float(value) == floorf(float(value)))

static func formal_pair(value: Variant) -> bool:
	return value is Array and value.size() == 2 and formal_number(value[0]) and formal_number(value[1])

static func formal_exact(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right): return false
	if left is Dictionary:
		var a: Dictionary = left
		var b: Dictionary = right
		if a.keys() != b.keys(): return false
		for key: Variant in a:
			if not b.has(key) or not formal_exact(a[key], b[key]): return false
		return true
	if left is Array:
		var a: Array = left
		var b: Array = right
		if a.size() != b.size(): return false
		for index: int in a.size():
			if not formal_exact(a[index], b[index]): return false
		return true
	if left is float: return is_finite(left) and left == right
	return left == right

static func formal_entitlements(drops: Dictionary) -> Dictionary:
	var result := drops.duplicate(true)
	for source: Variant in result:
		var drop: Dictionary = result[source]
		for unit: Dictionary in drop.get("units", []):
			for field: String in FORMAL_UNIT_MOTION_FIELDS: unit.erase(field)
	return result

static func formal_expected_units(drop: Dictionary, source: String, errors: Array[String]) -> Array[Dictionary]:
	var rewards: Array = []
	if drop.has("rewards"):
		if not drop.rewards is Array:
			errors.append("reward_shape/" + source)
			return []
		rewards = drop.rewards
	elif drop.get("kind", "none") != "none":
		rewards = [{"kind": drop.get("kind"), "amount": drop.get("amount")}]
	var result: Array[Dictionary] = []
	for value: Variant in rewards:
		if not value is Dictionary:
			errors.append("reward_shape/" + source)
			continue
		var reward: Dictionary = value
		if reward.get("kind") not in ["coin", "note", "heart"] or not formal_number(reward.get("amount"), true, 1):
			errors.append("reward_value/" + source)
			continue
		var amount := int(reward.amount)
		var amounts: Array[int] = []
		if reward.kind == "coin":
			for _i: int in amount / 5: amounts.append(5)
			for _i: int in amount % 5: amounts.append(1)
		else: amounts.append(amount)
		for denomination: int in amounts:
			var index := result.size()
			result.append({"id": "drop_" + source + ("" if index == 0 else "/unit_%s" % index), "source": source, "kind": str(reward.kind), "amount": denomination})
	return result

static func formal_source_summary(state: Dictionary, source: String) -> Dictionary:
	var units: Dictionary = {}
	var coins := 0
	for row: Dictionary in state.pickups:
		if str(row.get("source", "")) != source: continue
		units[str(row.id)] = {"kind": str(row.kind), "amount": row.amount}
		if row.kind == "coin": coins += int(row.amount)
	var identities: Array = units.keys()
	identities.sort()
	return {"ids": identities, "count": units.size(), "values": units, "coin_total": coins}

static func formal_receipt(state: Dictionary, identity: String) -> String:
	return "%s/stage_%s/%s" % [state.prefix, int(state.stage_index), identity]

static func formal_grants(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in state.wallet_grants: result[str(key)] = state.wallet_grants[key]
	return result

static func formal_unit_valid(unit: Dictionary, errors: Array[String], source: String) -> bool:
	var valid := true
	for field: String in ["id", "source", "kind"]:
		if not unit.get(field) is String or str(unit.get(field, "")).is_empty(): valid = false
	if not formal_number(unit.get("amount"), true, 1): valid = false
	for field: String in ["position", "velocity", "safe"]:
		if not formal_pair(unit.get(field)): valid = false
	if not formal_number(unit.get("age"), false, 0) or not formal_number(unit.get("bounces"), true, 0) or not formal_number(unit.get("rotation")): valid = false
	for field: String in ["settled", "returning", "claimed"]:
		if not unit.get(field) is bool: valid = false
	if not valid: errors.append("unit_motion_or_shape/" + source)
	return valid

static func formal_snapshot_errors(state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for field: String in ["drops", "claimed", "wallet_grants"]:
		if not state.get(field) is Dictionary: errors.append("observation_shape/" + field)
	if not state.get("pickups") is Array or not state.get("prefix") is String or str(state.get("prefix", "")).is_empty() or not formal_number(state.get("stage_index"), true, 0) or not formal_number(state.get("wallet_balance"), true, 0) or not formal_number(state.get("stage_clock"), false, 0) or not formal_number(state.get("physics_frame"), true, 0) or not formal_number(state.get("physics_ticks_per_second"), true, 1) or not formal_number(state.get("stage_instance_id"), true, 1) or not formal_number(state.get("actor_epoch"), true, 0): errors.append("observation_shape/scalars")
	if not errors.is_empty(): return errors
	var grants := formal_grants(state)
	for key: Variant in state.wallet_grants:
		if str(key).is_empty() or not formal_number(state.wallet_grants[key], true, 0): errors.append("wallet_grant_shape")
	var pickups: Dictionary = {}
	for value: Variant in state.pickups:
		if not value is Dictionary:
			errors.append("pickup_shape")
			continue
		var pickup: Dictionary = value
		var identity := str(pickup.get("id", ""))
		if identity.is_empty() or pickups.has(identity): errors.append("pickup_duplicate_or_missing_id/" + identity)
		pickups[identity] = pickup
	var recorded_ids: Dictionary = {}
	for source_value: Variant in state.drops:
		var source := str(source_value)
		if source.is_empty() or not state.drops[source_value] is Dictionary:
			errors.append("drop_shape/" + source)
			continue
		var drop: Dictionary = state.drops[source_value]
		if not drop.get("units") is Array:
			errors.append("drop_units_missing/" + source)
			continue
		var expected := formal_expected_units(drop, source, errors)
		if drop.units.size() != expected.size(): errors.append("unit_count/" + source)
		var coins := 0
		for index: int in drop.units.size():
			if not drop.units[index] is Dictionary:
				errors.append("unit_shape/" + source)
				continue
			var unit: Dictionary = drop.units[index]
			if not formal_unit_valid(unit, errors, source): continue
			var identity := str(unit.id)
			if recorded_ids.has(identity): errors.append("unit_duplicate_id/" + identity)
			recorded_ids[identity] = true
			if index >= expected.size() or unit.id != expected[index].id or unit.source != source: errors.append("unit_identity/" + identity)
			elif unit.kind != expected[index].kind or unit.amount != expected[index].amount: errors.append("unit_value/" + identity)
			if unit.kind == "coin": coins += int(unit.amount)
			if not pickups.has(identity):
				errors.append("unit_missing_live_pickup/" + identity)
				continue
			var pickup: Dictionary = pickups[identity]
			if not pickup.get("loot_motion", false) is bool or not bool(pickup.get("loot_motion", false)) or pickup.get("source") != source or pickup.get("kind") != unit.kind or pickup.get("amount") != unit.amount: errors.append("unit_live_identity/" + identity)
			for pair: Array in [["position", "position"], ["velocity", "loot_velocity"], ["safe", "loot_safe"]]:
				if not formal_pair(pickup.get(pair[1])) or pickup[pair[1]][0] != unit[pair[0]][0] or pickup[pair[1]][1] != unit[pair[0]][1]: errors.append("unit_live_motion/" + identity + "/" + pair[0])
			for pair: Array in [["age", "loot_age"], ["bounces", "loot_bounces"], ["rotation", "loot_rotation"], ["settled", "loot_settled"], ["returning", "loot_returning"], ["claimed", "claimed"]]:
				if not pickup.has(pair[1]) or not formal_exact(pickup[pair[1]], unit[pair[0]]): errors.append("unit_live_motion/" + identity + "/" + pair[0])
			var ledger_claimed: bool = state.claimed.get(identity, false) == true
			if unit.claimed != ledger_claimed or (state.claimed.has(identity) and not state.claimed[identity] is bool): errors.append("claim_ledger/" + identity)
			if unit.kind == "coin":
				var receipt := formal_receipt(state, identity)
				if bool(unit.claimed) != grants.has(receipt) or (bool(unit.claimed) and grants.get(receipt) != unit.amount): errors.append("coin_receipt/" + identity)
		if drop.has("coin_total") and (not formal_number(drop.coin_total, true, 0) or int(drop.coin_total) != coins): errors.append("coin_total/" + source)
		var summary := formal_source_summary(state, source)
		if int(summary.count) != drop.units.size() or int(summary.coin_total) != coins: errors.append("source_count_or_sum/" + source)
	for identity: String in pickups:
		var source := str(pickups[identity].get("source", ""))
		if (not source.is_empty() or pickups[identity].get("loot_motion", false) == true) and (not state.drops.has(source) or not recorded_ids.has(identity)): errors.append("extra_source_unit/" + identity)
	return errors

static func formal_transition_errors(before: Dictionary, after: Dictionary) -> Array[String]:
	var errors := formal_snapshot_errors(before)
	errors.append_array(formal_snapshot_errors(after))
	if not errors.is_empty(): return errors
	if not formal_exact(formal_entitlements(before.drops), formal_entitlements(after.drops)): errors.append("entitlement_changed")
	if before.prefix != after.prefix or before.stage_index != after.stage_index or before.stage_instance_id != after.stage_instance_id or before.actor_epoch != after.actor_epoch: errors.append("receipt_scope_changed")
	# This formal fixture deliberately leaves the actual drops uncollected.
	# Preserve all claim/wallet history, including unknown and previous-stage
	# receipts, rather than opening a new generic collection transition here.
	if not formal_exact(before.claimed, after.claimed): errors.append("claimed_ledger_changed")
	if not formal_exact(before.wallet_grants, after.wallet_grants): errors.append("wallet_grants_changed")
	if before.wallet_balance != after.wallet_balance: errors.append("wallet_delta")
	var frames := int(after.physics_frame) - int(before.physics_frame)
	var elapsed := float(after.stage_clock) - float(before.stage_clock)
	if before.physics_ticks_per_second != after.physics_ticks_per_second or frames < 0 or elapsed < 0.0 or elapsed > float(frames) / float(before.physics_ticks_per_second) + FORMAL_MOTION_EPSILON:
		errors.append("observation_clock_progress")
		return errors
	var dt := maxf(0.0, elapsed)
	for source: Variant in before.drops:
		if not after.drops.has(source): continue
		var now_by_id: Dictionary = {}
		for unit: Dictionary in after.drops[source].units: now_by_id[str(unit.id)] = unit
		for unit: Dictionary in before.drops[source].units:
			if not now_by_id.has(str(unit.id)): continue
			var now: Dictionary = now_by_id[str(unit.id)]
			var identity := str(unit.id)
			var age_delta := float(now.age) - float(unit.age)
			if age_delta < 0.0: errors.append("age_rewind/" + identity)
			if age_delta > dt + FORMAL_MOTION_EPSILON: errors.append("age_progress/" + identity)
			var contacts := int(now.bounces) - int(unit.bounces)
			if contacts < 0: errors.append("bounce_rewind/" + identity)
			if contacts > frames: errors.append("bounce_progress/" + identity)
			var vx := absf(float(unit.velocity[0]))
			var vy := absf(float(unit.velocity[1]))
			if absf(float(now.velocity[0])) > vx + FORMAL_MOTION_EPSILON: errors.append("horizontal_speed_progress/" + identity)
			if absf(float(now.velocity[1])) > vy + PlainsLootMotion.GRAVITY * dt + FORMAL_MOTION_EPSILON: errors.append("vertical_speed_progress/" + identity)
			# Return moves at 260wu/s. Leading-edge ray corrections can add up
			# to 2wu per axis/contact; final return snapping adds under 1wu.
			# Allow 3wu per physics frame on each axis, not an exact trajectory.
			var correction := 3.0 * float(frames) + FORMAL_MOTION_EPSILON
			if absf(float(now.position[0]) - float(unit.position[0])) > (vx + 260.0) * dt + correction: errors.append("horizontal_position_progress/" + identity)
			if absf(float(now.position[1]) - float(unit.position[1])) > (vy + PlainsLootMotion.GRAVITY * dt + 260.0) * dt + correction: errors.append("vertical_position_progress/" + identity)
			if absf(float(now.rotation) - float(unit.rotation)) > vx * dt * 0.022 + FORMAL_MOTION_EPSILON: errors.append("rotation_progress/" + identity)

	return errors

static func formal_pickup_index(state: Dictionary, identity: String) -> int:
	for index: int in state.pickups.size():
		if str(state.pickups[index].get("id", "")) == identity: return index
	return -1

static func formal_set_motion(clone: Dictionary, source: String, index: int, field: String, value: Variant) -> void:
	var unit: Dictionary = clone.drops[source].units[index]
	unit[field] = value
	var keys := {"position": "position", "velocity": "loot_velocity", "safe": "loot_safe", "age": "loot_age", "bounces": "loot_bounces", "rotation": "loot_rotation", "settled": "loot_settled", "returning": "loot_returning", "claimed": "claimed"}
	clone.pickups[formal_pickup_index(clone, str(unit.id))][keys[field]] = value

func formal_reject_clone(before: Dictionary, invalid: Dictionary, label: String, expected_error: String) -> void:
	var errors := formal_transition_errors(before, invalid)
	check(errors.any(func(value: String) -> bool: return value.begins_with(expected_error)), "observed drop clone rejects " + label)

func formal_derived_counterexamples(before: Dictionary, after: Dictionary, source: String) -> void:
	check(formal_transition_errors(before, after).is_empty(), "unmodified actual before/after observations satisfy the full entitlement-motion guard")
	var invalid := after.duplicate(true)
	invalid.drops[source].units.remove_at(invalid.drops[source].units.size() - 1)
	formal_reject_clone(before, invalid, "missing denomination unit", "unit_count/")
	invalid = after.duplicate(true)
	invalid.drops[source].units.append(invalid.drops[source].units[0].duplicate(true))
	formal_reject_clone(before, invalid, "additional denomination unit", "unit_count/")
	invalid = after.duplicate(true)
	invalid.drops[source].units[0].id = "drop_changed_identity"
	formal_reject_clone(before, invalid, "changed unit identity", "unit_identity/")
	invalid = after.duplicate(true)
	invalid.drops[source].units[0].amount = int(invalid.drops[source].units[0].amount) + 1
	formal_reject_clone(before, invalid, "changed denomination value", "unit_value/")
	invalid = after.duplicate(true)
	invalid.drops[source].coin_total = int(invalid.drops[source].coin_total) + 1
	formal_reject_clone(before, invalid, "changed total coin entitlement", "coin_total/")
	invalid = after.duplicate(true)
	invalid.drops[source].roll = int(invalid.drops[source].roll) + 1
	formal_reject_clone(before, invalid, "changed reward RNG receipt", "entitlement_changed")
	invalid = after.duplicate(true)
	var old_safe: Array = invalid.drops[source].units[0].safe
	formal_set_motion(invalid, source, 0, "safe", [float(old_safe[0]) + 1.0, old_safe[1]])
	formal_reject_clone(before, invalid, "changed immutable safe anchor", "entitlement_changed")
	var unknown_before := before.duplicate(true)
	var unknown_after := after.duplicate(true)
	unknown_before.drops[source].units[0]["guard_unknown_metadata"] = {"nested": [1, "retained"]}
	unknown_after.drops[source].units[0]["guard_unknown_metadata"] = {"nested": [1, "retained"]}
	check(formal_transition_errors(unknown_before, unknown_after).is_empty(), "unchanged unknown unit metadata remains part of the immutable entitlement")
	unknown_after.drops[source].units[0].guard_unknown_metadata.nested[0] = 2
	formal_reject_clone(unknown_before, unknown_after, "changed unknown unit metadata", "entitlement_changed")
	invalid = after.duplicate(true)
	formal_set_motion(invalid, source, 0, "velocity", [NAN, 0.0])
	formal_reject_clone(before, invalid, "nonfinite physical velocity", "unit_motion_or_shape/")
	invalid = after.duplicate(true)
	formal_set_motion(invalid, source, 0, "age", "reset")
	formal_reject_clone(before, invalid, "invalid motion field type", "unit_motion_or_shape/")
	invalid = after.duplicate(true)
	formal_set_motion(invalid, source, 0, "age", maxf(0.0, float(before.drops[source].units[0].age) - 0.1))
	formal_reject_clone(before, invalid, "physical age rewind", "age_rewind/")
	var bounce_source := ""
	var bounce_index := -1
	for candidate: String in after.drops:
		for index: int in after.drops[candidate].units.size():
			if int(after.drops[candidate].units[index].bounces) > 0:
				bounce_source = candidate; bounce_index = index
	check(bounce_index >= 0, "actual observed ledger contains a completed contact for the bounce-rewind counterexample")
	if bounce_index >= 0:
		invalid = after.duplicate(true)
		formal_set_motion(invalid, bounce_source, bounce_index, "bounces", int(after.drops[bounce_source].units[bounce_index].bounces) - 1)
		formal_reject_clone(after, invalid, "contact counter rewind", "bounce_rewind/")
	invalid = after.duplicate(true)
	var identity := str(invalid.drops[source].units[0].id)
	formal_set_motion(invalid, source, 0, "claimed", true)
	formal_reject_clone(before, invalid, "claimed unit without actual claim ledger", "claim_ledger/")
	invalid.claimed[identity] = true
	formal_reject_clone(before, invalid, "coin claim without actual wallet receipt", "coin_receipt/")
	invalid = after.duplicate(true)
	invalid.wallet_balance = int(invalid.wallet_balance) + 1
	formal_reject_clone(before, invalid, "wallet inflation without a new receipt", "wallet_delta")
	# A duplicate payout fault is derived from the actual unit entitlement and
	# receipt scope in clones only. No live App/wallet/claim state is written.
	invalid = after.duplicate(true)
	var amount := int(invalid.drops[source].units[0].amount)
	formal_set_motion(invalid, source, 0, "claimed", true)
	invalid.claimed[identity] = true
	invalid.wallet_grants[StringName(formal_receipt(invalid, identity))] = amount
	invalid.wallet_balance = int(invalid.wallet_balance) + amount * 2
	formal_reject_clone(before, invalid, "same receipt paid twice", "wallet_delta")
	invalid.wallet_grants[StringName(formal_receipt(invalid, identity) + "/replay")] = amount
	formal_reject_clone(before, invalid, "extra replay receipt not owned by a physical coin", "wallet_grants_changed")
	invalid = after.duplicate(true)
	var extra: Dictionary = invalid.pickups[formal_pickup_index(invalid, identity)].duplicate(true)
	extra.id = str(extra.id) + "/unrecorded"
	invalid.pickups.append(extra)
	formal_reject_clone(before, invalid, "unrecorded physical unit in actual pickup pool", "extra_source_unit/")

	invalid = after.duplicate(true)
	invalid.claimed["guard_ghost_claim"] = true
	formal_reject_clone(before, invalid, "new ghost claim with no actual owner", "claimed_ledger_changed")
	# These deliberately synchronize corrupt persisted and live motion. Exact
	# saved/live agreement alone must not admit an exploding animation state.
	for row: Array in [["age", 1.0e9, "age_progress/"], ["bounces", 1000000000, "bounce_progress/"], ["position", [1.0e20, 1.0e20], "horizontal_position_progress/"], ["velocity", [1.0e20, 1.0e20], "horizontal_speed_progress/"], ["velocity", [0.0, 1.0e20], "vertical_speed_progress/"], ["position", [after.drops[source].units[0].position[0], 1.0e20], "vertical_position_progress/"], ["rotation", 1.0e20, "rotation_progress/"]]:
		invalid = after.duplicate(true)
		formal_set_motion(invalid, source, 0, row[0], row[1])
		formal_reject_clone(before, invalid, "synchronized unbounded " + str(row[0]), row[2])
	var future_before := before.duplicate(true)
	future_before.stage_clock = float(after.stage_clock) + 1.0
	formal_reject_clone(future_before, after, "stage clock rewind", "observation_clock_progress")
	invalid = after.duplicate(true)
	invalid.stage_clock = float(after.stage_clock) + 1000.0
	formal_reject_clone(before, invalid, "stage time beyond observed physics frames", "observation_clock_progress")
	invalid = after.duplicate(true)
	invalid.physics_frame = int(before.physics_frame) - 1
	formal_reject_clone(before, invalid, "physics frame rewind", "observation_clock_progress")
	# Nonempty historical grants are an explicit clone model, not a claim
	# that this actual fixture collected anything. Preserve history exactly.
	var history_before := before.duplicate(true)
	var history_after := after.duplicate(true)
	var historical_receipt := StringName("guard_model/previous_stage/already_paid")
	history_before.wallet_grants[historical_receipt] = 5
	history_after.wallet_grants[historical_receipt] = 5
	history_before.wallet_balance = int(history_before.wallet_balance) + 5
	history_after.wallet_balance = int(history_after.wallet_balance) + 5
	check(formal_transition_errors(history_before, history_after).is_empty(), "nonempty historical grant clone model preserves old receipt and balance")
	invalid = history_after.duplicate(true)
	invalid.wallet_grants.erase(historical_receipt)
	formal_reject_clone(history_before, invalid, "removed historical grant in clone model", "wallet_grants_changed")
	invalid = history_after.duplicate(true)
	invalid.wallet_grants[historical_receipt] = 6
	formal_reject_clone(history_before, invalid, "changed historical amount in clone model", "wallet_grants_changed")
	invalid = history_after.duplicate(true)
	invalid.wallet_grants[StringName(str(historical_receipt) + "/replay")] = 5
	invalid.wallet_balance = int(invalid.wallet_balance) + 5
	formal_reject_clone(history_before, invalid, "added historical replay receipt in clone model", "wallet_grants_changed")
	invalid = history_after.duplicate(true)
	invalid.wallet_balance = int(invalid.wallet_balance) + 5
	formal_reject_clone(history_before, invalid, "old historical receipt paid twice in clone model", "wallet_delta")
