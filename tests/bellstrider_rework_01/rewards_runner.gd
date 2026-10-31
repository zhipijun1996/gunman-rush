extends SceneTree
## Isolated translated physical floor and real Boss/Health/loot/save components.
## Explicit lethal damage and death ticks are fixtures, not an App win or fight.
const AUDIO_TEARDOWN := preload("res://tests/audio_teardown.gd")
var assertions := 0
var failures: Array[String] = []
var stage: RewardStage
var encounter: BellstriderEncounter
var floor_body: StaticBody2D
var observed_events: Array[StringName] = []
var observed_defeats := 0

class RewardStage:
	extends PlainsRegionStage
	func _ready() -> void:
		assembly_ok = true
	func _physics_process(_delta: float) -> void:
		pass # Explicit component fixture; no generated map/capture is claimed.

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func frames(count: int) -> void:
	for _i: int in count:
		await physics_frame
		await process_frame

func fixture(saved: Dictionary = {}) -> void:
	if is_instance_valid(stage):
		check(await AUDIO_TEARDOWN.drain_world(stage), "fixture observes actual bounded audio teardown")
		stage.free()
		await frames(2)
	stage = RewardStage.new()
	stage.position = Vector2(400, 70)
	stage.clock = 10.0
	stage.boss_arena = Rect2(100, 300, 1000, 300)
	stage.region_state = PlainsRegionState.new()
	check(stage.region_state.bind_map("bellstrider-reward-floor"), "component ledger binds its explicit map")
	if not saved.is_empty():
		check(stage.region_state.restore(saved, "bellstrider-reward-floor"), "actual durable region state restores")
	root.add_child(stage)
	floor_body = StaticBody2D.new()
	floor_body.position = Vector2(600, 650)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(1600, 100)
	shape.shape = rectangle
	floor_body.add_child(shape)
	stage.add_child(floor_body)
	stage.boss = preload("res://scenes/bosses/bellstrider.tscn").instantiate()
	stage.boss.position = Vector2(600, 535)
	stage.add_child(stage.boss)
	encounter = stage.boss.get_node("Encounter") as BellstriderEncounter
	encounter.set_physics_process(false)
	observed_events.clear()
	observed_defeats = 0
	# Subscribe before terminal Health is loaded, not after history is restored.
	encounter.presentation_event.connect(func(row: Dictionary) -> void: observed_events.append(StringName(row.event)))
	encounter.defeated.connect(func(_source: BossEncounter) -> void: observed_defeats += 1)
	await frames(3)
	if not saved.is_empty():
		var health := encounter.definition.health_definition.duplicate(true) as HealthDefinition
		health.initial_current = float(saved.boss_state.health)
		if health.initial_current <= 0: encounter.prepare_terminal_restore()
		check(encounter.health.configure(health), "terminal fixture restores actual HealthState")
		encounter.damageable.bind_health(encounter.health)
		stage.boss.position = Vector2(saved.boss_state.position[0], saved.boss_state.position[1])
		encounter.restore_combat_state(saved.boss_state)
		check(observed_defeats == 0, "listener installed before terminal Health load observes no new defeated receipt")
		check(not observed_events.any(func(event: StringName) -> bool: return event in [&"bellstrider_death", &"bellstrider_death_jam", &"bellstrider_death_impact", &"bellstrider_death_final"]), "listener installed before terminal Health load observes no replayed presentation death event")
		for identity: String in stage.region_state.drops:
			var drop: Dictionary = stage.region_state.drops[identity]
			stage.restore_drop_pickups(drop, identity, stage.region_state.claimed)
			if identity == BellstriderRewards.source_id(stage): BellstriderRewards.restore_pickup_lock(stage, drop)

func kill() -> void:
	var request := ActorResourceRequest.new()
	request.event_id = &"reward-component-lethal"
	request.amount = encounter.health.current
	request.expected_epoch = encounter.health.epoch
	request.expected_instance_id = encounter.health.get_instance_id()
	check(encounter.health.apply_damage(request).accepted(), "explicit component damage commits one real terminal health transaction")
	check(observed_defeats == 1 and observed_events.count(&"bellstrider_death") == 1, "live signal listeners observe exactly one genuine lethal defeat and death cue")

func snapshot() -> Dictionary:
	stage._persist_pickup_motion()
	stage.region_state.boss_state = encounter.combat_snapshot()
	stage.region_state.boss_state.health = encounter.health.current
	stage.region_state.boss_state.position = [stage.boss.position.x, stage.boss.position.y]
	return stage.region_state.snapshot()

func total() -> int:
	var coins := 0
	for pickup: Dictionary in stage.pickups: coins += int(pickup.amount)
	return coins

func run() -> void:
	await fixture()
	check(BellstriderRewards.settle(stage, encounter).is_empty() and stage.pickups.is_empty(), "living Boss cannot create a reward")
	stage.boss.position.x = 665.0 # A reload at the default spawn would be wrong.
	kill()
	var definition := encounter.definition as BellstriderDefinition
	encounter.physics_tick(definition.reward_impact_seconds - .01)
	check(BellstriderRewards.settle(stage, encounter).is_empty() and stage.region_state.drops.is_empty(), "terminal health alone cannot spray before the major impact")
	encounter.physics_tick(.02)
	floor_body.collision_layer = 0
	await frames(2)
	check(BellstriderRewards.settle(stage, encounter).is_empty() and stage.region_state.drops.is_empty(), "no real floor means no fabricated safe landing or reward receipt")
	floor_body.collision_layer = 1
	await frames(2)
	var output := BellstriderRewards.settle(stage, encounter)
	check(not output.is_empty() and output.coin_total == 12 and total() == 12 and stage.pickups.size() == 4, "configured twelve coins create exactly four physical entitlements")
	var values: Array[int] = []
	var identities: Dictionary = {}
	var body: Transform2D = encounter.rig_pose().body_transform
	var origin := stage.to_local(stage.boss.to_global(body * Vector2(0, 10)))
	var supported := true
	for pickup: Dictionary in stage.pickups:
		values.append(int(pickup.amount))
		identities[pickup.id] = true
		supported = supported and pickup.position == origin and absf(pickup.loot_safe.y - 600.0) < .01 and is_equal_approx(pickup.ready_at - stage.clock, definition.reward_pickup_lock_seconds)
	check(values == [5,5,1,1] and identities.size() == 4, "real denomination service yields unique five-five-one-one units")
	check(supported, "translated world rays find real floor while spray starts inside the shared chassis and respects configured lock")
	var recorded := JSON.stringify(output)
	var replay := BellstriderRewards.settle(stage, encounter)
	check(JSON.stringify(replay) == recorded and stage.pickups.size() == 4, "repeated settlement returns the same receipt without new units")
	replay.units[0].amount = 99
	check(JSON.stringify(BellstriderRewards.settle(stage, encounter)) == recorded, "returned receipt cannot mutate the durable ledger")
	for _i: int in 6:
		stage.clock += 1.0 / 60.0
		for pickup: Dictionary in stage.pickups: PlainsLootMotion.advance(pickup, 1.0 / 60.0, stage)
	var saved := snapshot()
	var saved_pose := encounter.rig_pose()
	var saved_position := stage.boss.position
	await fixture(saved)
	var actual_pose := encounter.rig_pose()
	var pose_differences: Dictionary = {}
	for key: String in saved_pose:
		if actual_pose.get(key) != saved_pose[key]: pose_differences[key] = {"saved":var_to_str(saved_pose[key]), "restored":var_to_str(actual_pose.get(key))}
	print("BELLSTRIDER_REWARD_RESTORE_POSE_DIFF " + JSON.stringify(pose_differences))
	check(actual_pose == saved_pose, "terminal combat restore retains every exact local corpse rig field")
	check(stage.boss.position == saved_position and not encounter.active, "terminal combat restore preserves the nondefault corpse position and inactive state")
	var repeated_death := (encounter.combat_metrics().events as Array).any(func(row: Dictionary) -> bool: return row.event in [&"bellstrider_death", &"bellstrider_death_jam", &"bellstrider_death_impact", &"bellstrider_death_final"])
	check(not repeated_death, "terminal restore does not replay death events; lifecycle audio cancellation remains valid")
	check(stage.pickups.size() == 4 and total() == 12 and JSON.stringify(stage.region_state.drops) == JSON.stringify(saved.drops), "actual restore keeps every durable unit and immutable receipt")
	var remaining := definition.reward_pickup_lock_seconds - float(stage.pickups[0].loot_age)
	check(is_equal_approx(stage.pickups[0].ready_at - stage.clock, maxf(0.0, remaining)), "reload preserves the Boss-specific remaining pickup lock")
	check(not BellstriderRewards.settle(stage, encounter).is_empty() and stage.pickups.size() == 4, "terminal reload settlement never repeats the spray")
	for _i: int in 20:
		stage.clock += 1.0 / 60.0
		for pickup: Dictionary in stage.pickups: PlainsLootMotion.advance(pickup, 1.0 / 60.0, stage)
	check(stage.clock >= stage.pickups[0].ready_at, "claim-ledger fixture begins only after the actual configured pickup lock")
	stage.pickups[0].claimed = true
	stage.region_state.claimed[stage.pickups[0].id] = true
	saved = snapshot()
	await fixture(saved)
	check(stage.pickups.size() == 4 and total() == 12 and stage.pickups[0].claimed and stage.region_state.claimed.has(stage.pickups[0].id), "claimed unit identity survives actual save/restore without another entitlement")
	await fixture()
	var tuned := encounter.definition.duplicate(true) as BellstriderDefinition
	tuned.reward_coin_total = 7
	encounter.definition = tuned
	kill()
	encounter.physics_tick(tuned.reward_impact_seconds)
	output = BellstriderRewards.settle(stage, encounter)
	check(output.get("coin_total") == 7 and total() == 7 and stage.pickups.size() == 3, "Boss reward amount is independent declarative tuning rather than a hardcoded portal payment")
	check(await AUDIO_TEARDOWN.drain_world(stage), "final reward fixture drains actual audio")
	stage.free()
	await frames(2)
	print("BELLSTRIDER_REWARDS checks=%s failures=%s" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
