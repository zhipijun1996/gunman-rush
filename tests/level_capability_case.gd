extends Node
## The actual default DemoApp owns the actor/build; same41 capability checks.
var SNAPSHOT: Script
var lifecycle_ok := false
var assertions = 0
var failures = 0

func verify(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error("LEVEL CAPABILITY: " + label)

func run() -> void:
	var app=load("res://game/application/demo_app.gd").new()
	app.meta_persistence_enabled=false
	get_tree().root.add_child(app)
	if not app.start_plains("level-capability-default"):
		push_error("CAPABILITY APP: normal default start refused")
		app.free()
		return
	await get_tree().process_frame
	var motor=app.player
	var actor=app.controller
	actor.set_physics_process(false)
	verify(actor.enable_shot_energy(), "real energy policy enabled")
	var build = app.build
	SNAPSHOT=load("res://tools/level_capability_snapshot.gd")
	var baseline = SNAPSHOT.capture(actor, build)
	verify(baseline.equipped_weapon.id == "pulse_gun" and baseline.granted_actions == ["jump", "shot_recoil"], "formal default does not inherit studio grants")
	verify(SNAPSHOT.matches_tuning(actor, load("res://game/player/player_tuning.gd").load_default()), "actual default matches request")
	var wrong = load("res://game/player/player_tuning.gd").load_default()
	wrong.max_air_shots += 1
	verify(not SNAPSHOT.matches_tuning(actor, wrong), "different requested capacity rejected")
	var driver = load("res://tests/level_design_trace.gd").new()
	var rejections: Array = []
	driver.tree = get_tree()
	driver.check = func(ok: bool, label: String) -> void:
		if not ok: rejections.append(label)
	verify(not await driver.fixture({}, wrong) and driver.capability_mismatch and not rejections.is_empty() and driver.observed_frames.is_empty(), "actual route driver rejects mismatch before creating evidence")
	verify(actor.traversal.grant(&"double_jump") and actor.traversal.grant(&"grapple"), "grant real independent abilities")
	var granted = SNAPSHOT.capture(actor)
	verify(granted.effective_max_jumps == 2 and granted.tuning.max_jumps == 1 and "grapple" in granted.granted_actions, "effective capacity includes real grant without rewriting tuning")
	for index: int in load("res://game/combat/weapons/weapon_catalog.gd").IDS.size():
		var definition = load("res://game/combat/weapons/weapon_catalog.gd").get_loadout(index)
		verify(actor.shoot_ability.equip(definition), "equip real weapon/" + str(definition.id))
		var snapshot = SNAPSHOT.capture(actor)
		verify(snapshot.equipped_weapon.id == str(definition.id) and snapshot.equipped_weapon.tier == definition.tier and not snapshot.has("combined_weapon_abilities"), "one current weapon/" + str(definition.id))
	var energy = actor.actor_resources.stamina
	verify(energy.consume_continuous(energy.current - 7.0, energy.epoch).accepted(), "low-energy fixture uses real resource transaction")
	actor.combat_energy.current = 3.0
	actor.shoot_ability.cooldown_remaining = 0.25
	var low = SNAPSHOT.capture(actor)
	verify(low.shot_energy.current == 7.0 and low.combat_energy.current == 3.0 and low.shot_cooldown == 0.25, "low-resource and cooldown observation is exact")
	var runtime_before = actor.shoot_ability.runtime
	var before = JSON.stringify(low)
	verify(JSON.stringify(SNAPSHOT.capture(actor)) == before and actor.shoot_ability.runtime == runtime_before, "observation does not mutate or refill actor")
	verify(low.equipment_capacity.inventory_capacity == "unimplemented", "missing inventory rule is not fabricated")
	var app_ref: WeakRef=weakref(app)
	var motor_ref: WeakRef=weakref(motor)
	var controller_ref: WeakRef=weakref(actor)
	var drained: bool=await load("res://tests/audio_teardown.gd").drain_world(app)
	app.free()
	app=null
	motor=null
	actor=null
	build=null
	await get_tree().process_frame
	lifecycle_ok=drained and app_ref.get_ref()==null and motor_ref.get_ref()==null and controller_ref.get_ref()==null
	print("CAPABILITY APP LIFECYCLE ",JSON.stringify({"audio_drained":drained,"app_released":app_ref.get_ref()==null,"motor_released":motor_ref.get_ref()==null,"controller_released":controller_ref.get_ref()==null,"normal_default_entry":true}))
	print("LEVEL CAPABILITY: %d assertions, %d failures" % [assertions, failures])

