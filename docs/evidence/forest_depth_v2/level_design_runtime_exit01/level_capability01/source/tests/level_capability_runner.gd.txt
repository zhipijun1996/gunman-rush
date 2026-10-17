extends SceneTree
const SNAPSHOT := preload("res://tools/level_capability_snapshot.gd")
var assertions := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func verify(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error("LEVEL CAPABILITY: " + label)

func run() -> void:
	var motor := preload("res://scenes/player/player.tscn").instantiate() as PlayerMotor
	root.add_child(motor)
	var actor := motor.get_node("Controller") as PlayerController
	actor.set_physics_process(false)
	verify(actor.enable_shot_energy(), "real energy policy enabled")
	var build := BuildState.new()
	build.configure(actor)
	var baseline := SNAPSHOT.capture(actor, build)
	verify(baseline.equipped_weapon.id == "pulse_gun" and baseline.granted_actions == ["jump", "shot_recoil"], "formal default does not inherit studio grants")
	verify(SNAPSHOT.matches_tuning(actor, PlayerTuning.load_default()), "actual default matches request")
	var wrong := PlayerTuning.load_default()
	wrong.max_air_shots += 1
	verify(not SNAPSHOT.matches_tuning(actor, wrong), "different requested capacity rejected")
	var driver = preload("res://tests/level_design_trace.gd").new()
	var rejections: Array = []
	driver.tree = self
	driver.check = func(ok: bool, label: String) -> void:
		if not ok: rejections.append(label)
	verify(not await driver.fixture({}, wrong) and driver.capability_mismatch and not rejections.is_empty() and driver.observed_frames.is_empty(), "actual route driver rejects mismatch before creating evidence")
	verify(actor.traversal.grant(&"double_jump") and actor.traversal.grant(&"grapple"), "grant real independent abilities")
	var granted := SNAPSHOT.capture(actor)
	verify(granted.effective_max_jumps == 2 and granted.tuning.max_jumps == 1 and "grapple" in granted.granted_actions, "effective capacity includes real grant without rewriting tuning")
	for index: int in WeaponCatalog.IDS.size():
		var definition := WeaponCatalog.get_loadout(index)
		verify(actor.shoot_ability.equip(definition), "equip real weapon/" + str(definition.id))
		var snapshot := SNAPSHOT.capture(actor)
		verify(snapshot.equipped_weapon.id == str(definition.id) and snapshot.equipped_weapon.tier == definition.tier and not snapshot.has("combined_weapon_abilities"), "one current weapon/" + str(definition.id))
	var energy := actor.actor_resources.stamina
	verify(energy.consume_continuous(energy.current - 7.0, energy.epoch).accepted(), "low-energy fixture uses real resource transaction")
	actor.combat_energy.current = 3.0
	actor.shoot_ability.cooldown_remaining = 0.25
	var low := SNAPSHOT.capture(actor)
	verify(low.shot_energy.current == 7.0 and low.combat_energy.current == 3.0 and low.shot_cooldown == 0.25, "low-resource and cooldown observation is exact")
	var runtime_before := actor.shoot_ability.runtime
	var before := JSON.stringify(low)
	verify(JSON.stringify(SNAPSHOT.capture(actor)) == before and actor.shoot_ability.runtime == runtime_before, "observation does not mutate or refill actor")
	verify(low.equipment_capacity.inventory_capacity == "unimplemented", "missing inventory rule is not fabricated")
	motor.free()
	await process_frame
	print("LEVEL CAPABILITY: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
