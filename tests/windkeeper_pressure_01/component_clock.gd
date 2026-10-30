extends SceneTree
## Controlled actual scenes/geometry with explicit stage/group/time fixtures.
## Manual encounter ticks test its owner clocks, not player evasion. Physical
## seeds still run their real node/space collision; no hit signal is fabricated.
const TEARDOWN := preload("res://tests/audio_teardown.gd")
const MOVES := [&"stomp", &"lunge", &"sweep", &"gust", &"seeds", &"platform"]
var assertions := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var world: Node2D
var module: PlatformingModule
var boss: BossMotor
var encounter: WindkeeperPressureEncounter
var target: CharacterBody2D
var actual_hits: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func ticks(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func cleanup() -> void:
	if is_instance_valid(world):
		if is_instance_valid(encounter): encounter.cancel()
		check(await TEARDOWN.drain_world(world), "actual component scene/audio drains")
		world.free()
	await ticks(2)

func fixture(at: Vector2 = Vector2(820, 452), restored_health: float = -1, activate_owner: bool = true, use_real_motor: bool = false) -> bool:
	await cleanup()
	actual_hits.clear()
	world = Node2D.new()
	root.add_child(world)
	module = load("res://scenes/generation/modules/plains_boss_arena.tscn").instantiate() as PlatformingModule
	world.add_child(module)
	target = PlayerMotor.new() if use_real_motor else CharacterBody2D.new()
	if target is PlayerMotor: (target as PlayerMotor).tuning = PlayerTuning.load_default()
	target.collision_layer = 1
	target.collision_mask = 1 if use_real_motor else 0
	target.position = at
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 36)
	collision.shape = shape
	target.add_child(collision)
	world.add_child(target)
	check(target.get_node_or_null("CollisionShape2D") == collision, "fixture uses the actual canonical player collision-node contract")
	boss = BossFactory.create(&"windkeeper_storm")
	check(boss != null, "actual formal factory creates pressure candidate")
	if boss == null: return false
	boss.position = Vector2(560, 535)
	if restored_health >= 0:
		# Explicit saved-health load fixture, before ready/health binding. This
		# does not inflict fresh damage to manufacture an old terminal save.
		var prepared := boss.get_node("Encounter") as WindkeeperPressureEncounter
		if prepared == null:
			check(false, "saved-health fixture has actual pressure subclass")
			return false
		var config := prepared.definition.duplicate(true) as WindkeeperPressureDefinition
		var saved_health := config.health_definition.duplicate(true) as HealthDefinition
		saved_health.initial_current = restored_health
		config.health_definition = saved_health
		prepared.definition = config
	world.add_child(boss)
	encounter = boss.get_node("Encounter") as WindkeeperPressureEncounter
	check(encounter != null, "formal factory selects pressure subclass")
	if encounter == null: return false
	encounter.set_physics_process(false)
	await ticks(3)
	var configured := encounter.configure_arena(125, 995, target)
	if activate_owner:
		check(configured and encounter.activate(), "actual component arena/owner activates")
		encounter.skip_intro()
	else:
		check(configured and not encounter.active and encounter.health.terminal,
			"explicit terminal save loads without activating or replaying a fresh defeat")
	encounter.reward_stands.assign([Vector2(350,452), Vector2(640,452), Vector2(870,452)])
	encounter.projectile_created.connect(func(shot: BossProjectile) -> void:
		shot.hit.connect(func(body: Node2D, event: StringName, amount: float) -> void:
			actual_hits.append({"body_is_target": body == target, "event": String(event), "amount": amount, "mode": String(encounter.mode), "point": shot.global_position})))
	return configured and (encounter.active if activate_owner else encounter.health.terminal and not encounter.active)

func plan(attacks: Array, phase: int = 1) -> void:
	encounter.cancel_pending_attacks()
	encounter.stage_phase = phase
	encounter._group_plan = {"attacks": attacks.duplicate(), "phase": phase,
		"sweep_high": true, "double_stomp": attacks.size() > 1 and attacks[0] == &"stomp" and attacks[1] == &"stomp"}
	encounter._attack_index = 0
	encounter.sweep_high = true

func advance_to_warning(expected: StringName) -> bool:
	# Component fixtures must execute the owner's real turn/approach states.
	# They may not call release while the guardian is still turning.
	for index: int in 90:
		if encounter.mode == expected: return true
		encounter.physics_tick(1.0 / 60)
	check(encounter.mode == expected, "real owner reaches requested warning through its normal preparation")
	return encounter.mode == expected

func resource_and_selection() -> void:
	if not await fixture(): return
	var config := encounter._config()
	check(config != null and config.is_valid(), "actual pressure Definition validates")
	check(encounter.health.capacity == 60 and encounter.health.current == 60, "requested60HP is actual resource state")
	check(config.phase_three_health < config.phase_two_health, "three authoritative health bands remain ordered")
	for phase: int in [1, 2, 3]:
		encounter.stage_phase = phase
		encounter._recent_groups.clear()
		var previous := ""
		var repeats := 0
		var distinct: Dictionary = {}
		for index: int in 36:
			encounter._select_group()
			var frozen: Dictionary = encounter._group_plan.duplicate(true)
			var attacks: Array = frozen.attacks
			var key: String = encounter._group_key(attacks)
			check(attacks.size() >= 1 and attacks.size() <= 3, "actual selected group never exceeds three main attacks")
			check(attacks.size() == 2 if phase == 2 else attacks.size() >= 2 if phase == 3 else attacks.size() <= 2, "actual group length follows its stage grammar")
			check(attacks.all(func(move: Variant) -> bool: return move in MOVES), "selected group contains actual supported moves")
			if phase == 1: check(attacks.all(func(move: Variant) -> bool: return move in [&"stomp", &"lunge", &"seeds"]), "phase one does not leak later-stage attacks")
			if phase < 3: check(not (&"platform" in attacks), "platform strike remains phase three")
			repeats = repeats + 1 if key == previous else 1
			check(repeats <= config.maximum_group_repeats, "actual weighted selections enforce consecutive-group bound")
			previous = key
			distinct[key] = true
			# A copied read-only metric cannot rewrite the real committed group.
			var exported: Dictionary = encounter.combat_metrics()
			exported.group_plan.attacks.append(&"forged_fourth_attack")
			check(encounter._group_plan == frozen, "exported metrics are detached from frozen real group")
		check(distinct.size() > 1, "stage selection has actual variation without fixed-order routing")
		observations.append({"case": "weighted selection", "stage_fixture": phase, "distinct_groups": distinct.keys()})
	# Position/height/camping alter candidate weights before random selection.
	encounter.stage_phase = 1
	encounter._recent_groups.clear()
	target.position = Vector2(900, 582)
	var far: Array[Dictionary] = encounter._selection_candidates()
	target.position = Vector2(650, 582)
	var near: Array[Dictionary] = encounter._selection_candidates()
	check(float(far[0].weight) > float(near[0].weight), "far target raises actual short-pounce group selection weight")
	encounter._camp_age = config.camping_seconds + .01
	var camp: Array[Dictionary] = encounter._selection_candidates()
	check(float(camp[1].weight) > float(near[1].weight), "stationary target raises actual pressure followup weight")

func locked_lunge_and_actual_rise() -> void:
	if not await fixture(Vector2(900,452)): return
	plan([&"lunge"])
	encounter._begin_attack()
	var ready := advance_to_warning(&"lunge_warning")
	check(encounter.mode == &"lunge_warning", "lunge warning begins before actual execution")
	if not ready: return
	var frozen: Dictionary = encounter._group_plan.duplicate(true)
	var locked := encounter.locked_direction
	var start := boss.global_position
	target.position = Vector2(300,452) # Explicit moving-target lock adversary.
	encounter._release_attack()
	var minimum_y := start.y
	for index: int in 40:
		encounter.physics_tick(1.0 / 60)
		minimum_y = minf(minimum_y, boss.global_position.y)
		if encounter.mode != &"lunge": break
	check(encounter.locked_direction == locked and locked == 1, "short pounce never retargets direction after takeoff")
	check(boss.global_position.x > start.x + 50, "pounce creates real forward BossMotor displacement")
	check(minimum_y < start.y - encounter._config().lunge_height * .7, "actual BossMotor rises off the support plane")
	check(absf(boss.global_position.y - start.y) < .1, "real pounce returns to its actual takeoff support height")
	check(encounter.mode == &"recover" and encounter._group_plan == frozen, "last pounce ends in real group recovery without rewriting chosen plan")
	observations.append({"case": "actual short-pounce movement", "start": start, "end": boss.global_position, "highest_y": minimum_y, "direction": locked})

func platform_approach_and_lock() -> void:
	if not await fixture(Vector2(870,452)): return
	plan([&"platform", &"gust", &"seeds"], 3)
	var start := boss.global_position
	encounter._begin_attack()
	for index: int in 120:
		encounter.physics_tick(1.0 / 60)
		if encounter.mode == &"platform_warning": break
	check(encounter.mode == &"platform_warning", "platform preparation approaches into real limb reach instead of stalling at ordinary range")
	check(boss.global_position.distance_to(start) > 50, "platform preparation uses real travel to target shelf")
	var locked := encounter.locked_target
	check(absf(locked.y - 470) < .1 and locked.x >= 810 and locked.x <= 1000, "locked foot target belongs to actual existing third shelf surface")
	target.position = Vector2(350,452) # Explicit late platform-switch adversary.
	for index: int in 42:
		encounter.physics_tick(1.0 / 60)
		if encounter.mode != &"platform_warning": break
	check(encounter.locked_target == locked, "late target movement never silently switches the warned shelf")
	if encounter.mode == &"platform_warning": encounter._release_attack()
	for index: int in 18:
		encounter.physics_tick(1.0 / 60)
		if is_instance_valid(encounter._active_strike): break
	var pose := encounter.rig_pose()
	var foot: Vector2 = boss.to_global(pose.feet[encounter.foot_index])
	check(is_instance_valid(encounter._active_strike), "actual platform impact creates a physical strike entity")
	if is_instance_valid(encounter._active_strike):
		check(encounter._active_strike.start_world.distance_to(foot) < .1, "physical platform strike begins at the same actual rendered front foot")
	check(foot.distance_to(locked) < 20, "fully extended attacking limb really reaches its warned platform")
	observations.append({"case": "real platform approach and lock", "initial_Boss": start, "actual_Boss": boss.global_position, "locked_surface": locked, "actual_foot": foot})

func rig_damage_alignment() -> void:
	if not await fixture(): return
	for side: int in [-1, 1]:
		encounter.direction = side
		encounter.stage_phase = 3
		for move: StringName in MOVES:
			for warning: bool in [true, false]:
				plan([move, &"seeds"], 3)
				encounter.direction = side
				encounter.locked_target = boss.global_position + Vector2(side * 145, -65)
				encounter._enter(StringName("%s_warning" % move) if warning else move, 1.0)
				encounter._state_age = .65 # Explicit mid-action, beyond accepted pose blend.
				encounter._update_combat_shapes()
				var pose := encounter.rig_pose()
				var hull := boss.get_node("CollisionShape2D") as CollisionShape2D
				check((hull.shape as ConvexPolygonShape2D).points == pose.body_shape_points, "real hull polygon shares visible body pose")
				check((encounter._head_shape.shape as ConvexPolygonShape2D).points == pose.head_shape_points, "real head polygon shares visible head pose")
				check(encounter._core.transform.is_equal_approx(pose.core_transform), "real core damage anchor shares rendered clock pose")
				check(pose.feet.size() == 4 and pose.hips.size() == 4 and pose.knees.size() == 4, "all four actual limbs retain independent joint chains")
				for index: int in 4:
					check(encounter._foot_shapes[index].position.is_equal_approx(pose.feet[index]), "real foot collision follows its actual rendered endpoint")
				for index: int in 8:
					var leg := index >> 1
					var a: Vector2 = pose.hips[leg] if index % 2 == 0 else pose.knees[leg]
					var b: Vector2 = pose.knees[leg] if index % 2 == 0 else pose.feet[leg]
					var actual: Transform2D = encounter._limb_shapes[index].transform
					check(actual.origin.distance_to((a+b)*.5) < .1, "real limb capsule centre follows corresponding rendered bone")
				var core_world: Vector2 = boss.to_global(pose.core_transform.origin)
				check(encounter.body_contact_sweep(boss.global_position, core_world - boss.global_position, core_world, Vector2(12,18)), "actual visible clock core cannot be omitted from contact damage")
				if move == &"sweep" and not warning:
					encounter._new_strike(&"sweep")
					check(encounter._active_strike.start_world.distance_to(boss.to_global(pose.blade_start)) < .1 and encounter._active_strike.end_world.distance_to(boss.to_global(pose.blade_end)) < .1, "real sweep capsule uses the same visible leaf endpoints")
				encounter._clear_attacks()
	observations.append({"case": "shared rig collision matrix", "facings": 2, "moves": 6, "warning_and_execute": true, "sampling": "explicit .65 midaction; geometry only, not art acceptance"})


func gust_then_sweep_reaches_actual_actor() -> void:
	# Explicit two-move/phase fixture. The target is now an actual PlayerMotor
	# on the original ground, with zero move input. Wind displaces it through
	# the original local-velocity/step path; no target position is fabricated.
	if not await fixture(Vector2(830,582), -1, true, true): return
	var player := target as PlayerMotor
	check(player != null and player.tuning != null, "gust-range fixture uses actual configured PlayerMotor")
	if player == null: return
	plan([&"gust", &"sweep"], 2)
	encounter.sweep_high = false
	encounter._group_plan.sweep_high = false
	var frozen := encounter._group_plan.duplicate(true)
	var boss_start := boss.global_position
	var target_start := player.global_position
	encounter._begin_attack()
	var gust_seen := false
	var pursuit_seen := false
	var loaded_pursuit := false
	var warning_seen := false
	for tick: int in 240:
		encounter.physics_tick(1.0 / 60)
		player.step(0.0, 1.0 / 60)
		await ticks(1)
		if encounter.mode == &"gust": gust_seen = true
		if gust_seen and encounter.mode == &"approach":
			pursuit_seen = true
			var pose := encounter.rig_pose()
			if encounter._state_age >= .10 and float(pose.sail_tension) >= .7:
				loaded_pursuit = true
		if encounter.mode == &"sweep_warning":
			warning_seen = true
			break
	check(gust_seen and player.global_position.x > target_start.x + 20,
		"actual directed gust pushes the standing Motor away before the follow-up")
	check(pursuit_seen and boss.global_position.x > boss_start.x + 100,
		"gust-to-sweep uses real intervening Boss travel rather than attacking empty range")
	check(loaded_pursuit, "mid-combo pursuit retains loaded sail tension instead of a recovery pose")
	check(warning_seen and absf(player.global_position.x - boss.global_position.x) <= encounter._config().sweep_approach_range + 4,
		"follow-up warning begins only inside the authoritative physical sweep approach range")
	check(encounter._group_plan == frozen and encounter._attack_index == 1,
		"physical pursuit retains the already announced gust-to-sweep group and its second member")
	if not warning_seen: return
	for tick: int in 100:
		encounter.physics_tick(1.0 / 60)
		player.step(0.0, 1.0 / 60)
		await ticks(1)
		if not actual_hits.is_empty() or encounter.mode == &"recover": break
	check(not actual_hits.is_empty() and actual_hits[0].body_is_target and str(actual_hits[0].event).begins_with("windkeeper_sweep-"),
		"actual rendered follow-up blade physically intersects the real standing Motor after closing")
	observations.append({"case": "actual gust-to-sweep range", "fixture": "phase2 frozen group; real Motor zero input/real gravity and gust", "boss_start": boss_start,
		"boss_end": boss.global_position, "target_start": target_start, "target_end": player.global_position,
		"actual_hits": actual_hits.duplicate(true), "group_preserved": encounter._group_plan == frozen})

func actual_last_seed_reaches_target() -> void:
	if not await fixture(Vector2(900,452)): return
	plan([&"seeds"])
	encounter._begin_attack()
	if not advance_to_warning(&"seeds_warning"): return
	encounter._state_age = .60
	encounter._release_attack()
	check(encounter._projectiles.size() == 3, "actual final seed warning releases exactly three physical projectiles")
	if encounter._projectiles.size() < 3: return
	var origin: Vector2 = encounter._projectiles[1].global_position
	check(origin.distance_to(target.global_position) > 200, "real final-seed target is over200wu from actual muzzle")
	for index: int in 95:
		encounter.physics_tick(1.0 / 60)
		await ticks(1)
		if not actual_hits.is_empty(): break
	check(not actual_hits.is_empty() and actual_hits[0].body_is_target and str(actual_hits[0].event).begins_with("windkeeper_seed-"), "actual owner-created last wind seed reaches real distant actor rather than disappearing after its short launch pose")
	check(not actual_hits.is_empty() and float(actual_hits[0].amount) == encounter.definition.projectile_damage, "owner-created physical seed retains authoritative damage amount")
	var recovery_releases := encounter._event_history.filter(func(row: Dictionary) -> bool: return row.event in [&"windkeeper_seeds_release", &"windkeeper_stomp_strike", &"windkeeper_platform_impact"] and row.state == &"recover")
	check(recovery_releases.is_empty(), "recovery cannot create a new unannounced release while existing finite shots travel")
	observations.append({"case": "owner final wind seed", "origin": origin, "target": target.global_position, "actual_hits": actual_hits.duplicate(true)})

func frozen_group_snapshot_and_phase() -> void:
	if not await fixture(): return
	plan([&"stomp", &"seeds"])
	encounter._begin_attack()
	if not advance_to_warning(&"stomp_warning"): return
	var frozen: Dictionary = encounter._group_plan.duplicate(true)
	var direction := encounter.locked_direction
	var request := ActorResourceRequest.new(&"explicit-half-band-fixture", encounter.health.epoch, 20, encounter.health.get_instance_id())
	check(encounter.health.apply_damage(request).accepted(), "explicit stage threshold fixture uses authoritative Boss resource transaction")
	target.position = Vector2(350,452)
	encounter.physics_tick(.05)
	check(encounter.stage_phase == 1 and encounter._group_plan == frozen and encounter.locked_direction == direction, "health-band change and moved target do not rewrite committed group or current warning")
	encounter._finish_attack()
	check(encounter.mode == &"link" and not encounter.presentation_state().recovery_active, "intermediate attack retains combo posture instead of granting a false recovery")
	encounter._begin_attack()
	if not advance_to_warning(&"seeds_warning"): return
	encounter._finish_attack()
	check(encounter.mode == &"recover" and encounter.presentation_state().recovery_active, "only final attack enters declared group recovery")
	encounter.physics_tick(encounter._config().group_recovery_seconds + .01)
	check(encounter.stage_phase == 2 and encounter.mode == &"phase_transition", "pending stage change begins after original full group finishes")
	# Snapshot next-choice equivalence, using the owner's actual RNG stream.
	encounter._recent_groups.clear()
	encounter._select_group()
	var saved: Dictionary = encounter.combat_snapshot()
	encounter._select_group()
	var expected: Dictionary = encounter._group_plan.duplicate(true)
	var expected_rng: String = str(encounter._selection_rng.state)
	encounter.restore_combat_state(saved)
	encounter._select_group()
	check(encounter._group_plan == expected and str(encounter._selection_rng.state) == expected_rng, "snapshot restores actual RNG and next weighted group selection exactly")

func death_once() -> void:
	if not await fixture(): return
	plan([&"seeds"])
	encounter._begin_attack()
	if not advance_to_warning(&"seeds_warning"): return
	encounter._release_attack()
	check(encounter._projectiles.size() == 3, "real final seed fixture has three live owned projectiles before terminal damage")
	var defeats := [0]
	encounter.defeated.connect(func(_owner: BossEncounter) -> void: defeats[0] += 1)
	var request := ActorResourceRequest.new(&"explicit-terminal-resource-fixture", encounter.health.epoch, encounter.health.current, encounter.health.get_instance_id())
	check(encounter.health.apply_damage(request).accepted(), "explicit death fixture uses real authoritative health transaction")
	check(encounter.health.terminal and not encounter.active and not encounter.body_contact_enabled(), "terminal transaction immediately disables attacks and live body contact")
	check(encounter._projectiles.is_empty(), "terminal transaction immediately cancels all old owned projectiles")
	for index: int in 180: encounter.physics_tick(1.0 / 60)
	var impacts := encounter._event_history.filter(func(row: Dictionary) -> bool: return row.event == &"windkeeper_death_impact")
	var finals := encounter._event_history.filter(func(row: Dictionary) -> bool: return row.event == &"windkeeper_death_final")
	check(defeats[0] == 1 and impacts.size() == 1 and finals.size() == 1, "terminal defeat, major impact and final settlement each occur exactly once")
	check(boss.collision_layer == 0 and boss.collision_mask == 0, "settled dead guardian cannot block or damage traversal")
	observations.append({"case": "terminal once", "defeats": defeats[0], "impacts": impacts.size(), "finals": finals.size(), "death_age": encounter._death_age})

func legacy_snapshot(old_mode: StringName, phase: int, hp: float, active_owner: bool) -> Dictionary:
	# The old v5 shape is the original Windkeeper snapshot merged with the
	# Stage's health/phase/position fields. It deliberately has no pressure key.
	return {"health": hp, "phase": phase, "chase_segment": 1, "active": active_owner,
		"position": [boss.position.x, boss.position.y], "intro_duration": 3.2,
		"mode": String(old_mode), "clock": .4, "serial": 17, "direction": 1,
		"stomp_next": false, "blade_angle": .7, "phase_cycle": 2,
		"blade_last_hit": -1, "storm_fired": true, "locked_aim": [820,452],
		"motion_age": .2, "transition_target": phase, "pier_direction": 1,
		"rune_platform": -1, "seal_closed": active_owner}

func legacy_active_restore() -> void:
	var old_modes := [&"charge", &"blades", &"chase"]
	var old_health := [36.0, 20.0, 9.0]
	for index: int in 3:
		var phase := index + 1
		var hp: float = old_health[index]
		if not await fixture(Vector2(820,452), hp): return
		encounter.stage_phase = phase # The actual Stage applies this before restore.
		plan([&"seeds"], phase)
		encounter._begin_attack()
		if not advance_to_warning(&"seeds_warning"): return
		encounter._release_attack()
		check(encounter._projectiles.size() == 3,
			"legacy replacement fixture starts with real old-instance projectiles")
		var obsolete: Array[BossProjectile] = encounter._projectiles.duplicate()
		var position := boss.position
		var snapshot := legacy_snapshot(old_modes[index], phase, hp, true)
		check(not snapshot.has("pressure") and hp <= 36,
			"legacy fixture uses authentic v5 absolute HP and missing pressure payload")
		var event_start := encounter._event_history.size()
		encounter.restore_combat_state(snapshot)
		check(encounter.active and encounter.health.current == hp and encounter.stage_phase == phase
			and boss.position == position,
			"legacy active restore immediately preserves absolute HP, stage and world position")
		check(encounter.mode == &"observe" and encounter.clock == 0 and encounter._group_plan.is_empty(),
			"old execute mode is migrated into readable current preparation instead of an unhandled state")
		check(encounter._projectiles.is_empty() and obsolete.all(func(shot: BossProjectile) -> bool:
			return not is_instance_valid(shot) or shot.spent),
			"legacy replacement cancels actual old-instance projectiles before resuming")
		check(encounter._event_history.size() == event_start,
			"legacy restore itself emits no old release or fresh death event")
		var prepared := false
		for tick: int in 240:
			encounter.physics_tick(1.0 / 60)
			if String(encounter.mode).ends_with("_warning"):
				prepared = true
				break
		check(prepared and encounter.clock > 0,
			"restored old execute mode reaches a bounded new readable warning, not a zero-clock stall")
		check(encounter.health.current == hp,
			"normal preparation after legacy load does not rewrite saved absolute HP")
		var events: Array = encounter._event_history.slice(event_start)
		var unannounced := events.filter(func(row: Dictionary) -> bool:
			return row.event in [&"windkeeper_attack", &"windkeeper_seeds_release",
				&"windkeeper_stomp_strike", &"windkeeper_platform_impact", &"windkeeper_death_impact"])
		check(unannounced.is_empty(),
			"legacy load resumes through preparation before any current or old attack can release")
		observations.append({"case": "legacy v5 active restore", "source_maximum_HP": 36,
			"old_mode": String(old_modes[index]), "saved_HP": hp, "saved_phase": phase,
			"immediate_position": position, "resumed_mode": String(encounter.mode),
			"resumed_phase": encounter.stage_phase, "normal_new_threshold_upgrade_allowed": true})

func legacy_terminal_restore() -> void:
	if not await fixture(Vector2(820,452), 0, false): return
	encounter.stage_phase = 3
	var position := boss.position
	var snapshot := legacy_snapshot(&"pier_open", 3, 0, false)
	var defeats := [0]
	encounter.defeated.connect(func(_owner: BossEncounter) -> void: defeats[0] += 1)
	var event_start := encounter._event_history.size()
	encounter.restore_combat_state(snapshot)
	check(encounter.health.terminal and encounter.health.current == 0 and not encounter.active
		and encounter.stage_phase == 3 and boss.position == position,
		"legacy terminal restore preserves actual saved zero health, stage and position")
	check(encounter.mode == &"dead" and encounter._death_age == encounter._config().death_seconds
		and encounter._death_impact_sent and encounter._death_final_sent,
		"legacy terminal is already settled instead of replaying a fresh death clock")
	check(not encounter.physical_reward_expected,
		"legacy zero-HP save creates no new physical coin entitlement")
	check(not encounter.body_contact_enabled() and boss.collision_layer == 0 and boss.collision_mask == 0,
		"imported old corpse remains harmless and nonblocking")
	for tick: int in 180: encounter.physics_tick(1.0 / 60)
	check(defeats[0] == 0 and encounter._event_history.size() == event_start,
		"advancing imported corpse cannot replay defeat, death impact, final event or reward trigger")
	var resaved := encounter.combat_snapshot()
	check(resaved.has("pressure") and resaved.pressure.get("physical_reward_expected", true) == false,
		"new pressure snapshot persists imported terminal's no-new-reward entitlement")
	encounter.restore_combat_state(resaved)
	for tick: int in 180: encounter.physics_tick(1.0 / 60)
	check(not encounter.physical_reward_expected and encounter.mode == &"dead" and encounter.health.current == 0,
		"resaving and reloading imported corpse cannot regain physical reward entitlement")
	check(defeats[0] == 0 and encounter._event_history.size() == event_start,
		"new-format reload of imported terminal still cannot replay death or reward events")
	observations.append({"case": "legacy v5 terminal restore", "source_maximum_HP": 36,
		"no_new_physical_reward": not encounter.physical_reward_expected,
		"fresh_defeats": defeats[0], "events_before_and_after": [event_start, encounter._event_history.size()],
		"settled_age": encounter._death_age, "second_format": "pressure payload persists false entitlement"})

func run() -> void:
	await resource_and_selection()
	await locked_lunge_and_actual_rise()
	await platform_approach_and_lock()
	await rig_damage_alignment()
	await gust_then_sweep_reaches_actual_actor()
	await actual_last_seed_reaches_target()
	await frozen_group_snapshot_and_phase()
	await death_once()
	await legacy_active_restore()
	await legacy_terminal_restore()
	await cleanup()
	DirAccess.make_dir_recursive_absolute("res://build/windkeeper_pressure_01")
	var file := FileAccess.open("res://build/windkeeper_pressure_01/component_clock.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"assertions": assertions, "failures": failures, "observations": observations,
		"scope": "actual component scenes/owner clocks/rig/entity collisions with explicit stage, group, target and time fixtures; direct Boss health transactions only for declared phase/death fixtures; legacy v5 absolute-health initialization and missing-pressure save fixtures declared; not natural player battle, visual/listening/device approval"}, "\t"))
	file.close()
	print("WINDKEEPER PRESSURE COMPONENT CLOCK: ", assertions, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
