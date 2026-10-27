extends SceneTree
## Real actor, ownership and paused-equipment transactions, not a parallel model.
const EQUIP := preload("res://tests/gear_inventory_support.gd")
var assertions := 0
var failures := 0
var fixture: Variant
var actor: PlayerController
var build: BuildState
var lifetime: DemoLifetime

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func fresh() -> void:
	paused = false
	if build != null: build.clear()
	if fixture != null and is_instance_valid(fixture.world): fixture.world.free()
	fixture = preload("res://tests/combat_tests.gd").new()
	fixture.tree = self
	await fixture.fixture(Vector2(80,20))
	actor = fixture.controller
	lifetime = DemoLifetime.new()
	build = BuildState.new()
	build.configure(actor,lifetime,&"v5_inventory_fixture")

func own(id: StringName, source: StringName) -> bool:
	return build.add_item(source,ItemCatalogV5.get_item(id))

func equip(sources: Array[StringName]) -> bool:
	return EQUIP.equip_sources(build,sources)

func growth_and_receipts() -> void:
	await fresh()
	var definition := ItemCatalogV5.get_item(&"B11")
	check(definition != null and definition.max_level == 3,"growth fixture uses the actual level-three catalog definition")
	check(own(&"B11",&"cache/one"),"first cache adds level one")
	var initial := build.inventory.instance_for_source(&"cache/one")
	var identity := initial.instance_id
	check(build.add_item(&"shop/two",definition,&"shop") and build.inventory.instances().size() == 1,"second provenance upgrades one owned instance")
	var grown := build.inventory.instance_for_source(&"shop/two")
	check(grown.instance_id == identity and grown.level == 2 and grown.source_id == &"cache/one" and grown.origin == &"pickup","growth retains stable original identity and provenance")
	check(build.inventory.source_receipt(&"shop/two").origin == &"shop" and build.inventory.source_receipt(&"shop/two").level == 2,"each growth provenance has its own immutable receipt")
	check(build.add_item(&"shop/two",definition,&"shop") and build.inventory.get_instance(identity).level == 2,"same shop source cannot upgrade again")
	check(not build.add_item(&"shop/two",definition,&"pickup") and build.inventory.get_instance(identity).level == 2,"same source with changed origin is rejected")
	check(own(&"B11",&"cache/three") and build.inventory.get_instance(identity).level == 3,"third unique source reaches level three")
	check(not build.can_add(definition) and build.inventory.validation_reason(definition) == &"maximum_level","maximum level becomes ineligible for future offers")
	check(not own(&"B11",&"cache/four") and build.inventory.instances().size() == 1,"a fourth unique source adds neither copies nor levels")
	check(own(&"B11",&"cache/one") and build.inventory.get_instance(identity).level == 3,"historical source replay remains readable at maximum level")
	var mutated := definition.duplicate(true) as ItemDefinition
	mutated.definition_version += 1
	check(not build.add_item(&"changed/version",mutated),"same stable definition rejects a conflicting version")
	grown.level = 999
	grown.effect_state["broken"] = true
	check(build.inventory.get_instance(identity).level == 3 and build.inventory.effect_state(identity).is_empty(),"owned instance snapshots cannot mutate level or progress")
	check(build.inventory.patch_effect_state(identity,{"damage_hits":2,"nested":{"a":1,"b":[2,3]}},&"progress/one"),"finite owned state patch commits")
	check(build.inventory.patch_effect_state(identity,{"nested":{"b":[2,3],"a":1},"damage_hits":2},&"progress/one"),"equivalent reordered patch replays the same receipt")
	check(not build.inventory.patch_effect_state(identity,{"damage_hits":0},&"progress/one"),"same progress receipt cannot reset damage counters")
	check(not build.inventory.patch_effect_state(identity,{"bad":NAN}) and not build.inventory.patch_effect_state(identity,{"object":actor}),"nonfinite values and live nodes cannot enter persistent item state")
	var snapshot := build.inventory.effect_state(identity)
	snapshot.nested.b[0] = 999
	check(build.inventory.effect_state(identity).nested.b[0] == 2,"nested progress is copied deeply")
	check(equip([&"cache/one"]) and build.equipment.snapshot().used == definition.gear_cost,"level-three item consumes its one original gear cost")
	check(equip([]) and build.inventory.get_instance(identity).level == 3 and build.inventory.effect_state(identity).damage_hits == 2,"unloading retains level and persistent state")
	lifetime.stage_epoch += 1
	check(build.inventory.get_instance(identity).level == 3 and build.inventory.effect_state(identity).damage_hits == 2,"stage epoch transition retains owned growth and progress")
	check(build.clear() and build.inventory.instances().is_empty() and build.inventory.source_receipt(&"cache/one").is_empty(),"real run cleanup clears instances and all source receipts")
	var legacy := ItemDefinition.new()
	legacy.stable_id = &"lookup_legacy"
	legacy.duplicate_policy = ItemDefinition.DuplicatePolicy.STACK
	legacy.stack_limit = 2
	var modifier := BuildModifier.new()
	modifier.stat_id = &"projectile_damage"
	modifier.value = 1
	legacy.modifiers.assign([modifier])
	var lookup := RunInventory.new(&"lookup")
	check(lookup.add_item(&"z",legacy) and lookup.add_item(&"a",legacy) and lookup.instance_for_definition(legacy.stable_id).instance_id == &"lookup/a","definition lookup retains lexical first-instance semantics despite reverse insertion")
	var chosen := lookup.instance_for_definition(legacy.stable_id)
	chosen.item.modifiers[0].value = 999
	chosen.effect_state["progress"] = 999
	check(lookup.instance_for_source(&"a").item.modifiers[0].value == 1 and lookup.effect_state(&"lookup/a").is_empty() and lookup.instances().size() == 2,"optimized lookup only returns a deep copy and cannot mutate other owned instances")

func equipped_growth_and_rollback() -> void:
	await fresh()
	var health := actor.actor_resources.health
	var base := health.capacity
	health.apply_damage(ActorResourceRequest.new(&"initial_hurt",health.epoch,2,health.get_instance_id()))
	var current := health.current
	check(own(&"B11",&"health/one") and health.capacity == base,"ownership does not apply level-one HP")
	check(equip([&"health/one"]) and health.capacity == base+1 and health.current == current,"equipping adds level-one maximum HP without healing")
	check(own(&"B11",&"health/two") and health.capacity == base+2 and health.current == current,"equipped upgrade synchronously recomputes level-two HP without healing")
	check(own(&"B11",&"health/three") and health.capacity == base+3 and health.current == current,"equipped upgrade selects level-three value instead of accumulating levels")
	var source_rows := build.effect_sources()
	var found := false
	for row: Dictionary in source_rows:
		if row.definition_id == &"B11" and row.effect_id == &"B11":
			found = row.level == 3 and row.parameters.max_hp_add == 3 and not row.parameters.has("max_hp_add_by_level")
	check(found,"equipped effect source carries the actual level and resolved parameters")
	check(equip([]) and health.capacity == base and health.current == current,"unloading fully restores base HP without healing")
	check(equip([&"health/one"]) and health.capacity == base+3 and health.current == current,"re-equipping level-three HP does not multiply or heal")
	await fresh()
	health = actor.actor_resources.health
	base = health.capacity
	var invalid_growth := ItemCatalogV5.get_item(&"B11")
	# Every authored parameter remains finite and nonnegative. Only composing the
	# next level's large HP addition with the real covenant multiplier overflows.
	# This reaches BuildState's transaction guard instead of testing a definition
	# that the stronger catalog validator already rejects before ownership.
	invalid_growth.effect_parameters["max_hp_add_by_level"] = [1,1.0e308,3]
	invalid_growth.effect_components[0].parameters["max_hp_add_by_level"] = [1,1.0e308,3]
	check(invalid_growth.is_valid() and build.add_item(&"invalid/one",invalid_growth) and own(&"P18",&"invalid/contract") and equip([&"invalid/one",&"invalid/contract"]),"boundary fixture owns valid finite definitions whose next-level composition would invalidate actor stats")
	var owned := build.inventory.instance_for_source(&"invalid/one")
	if owned == null:
		check(false,"rollback counterexample requires its authoritative level-one instance")
		return
	var revision := build.inventory.revision
	var capacity_before := health.capacity
	var current_before := health.current
	check(capacity_before == (base+1)*2 and not build.add_item(&"invalid/two",invalid_growth) and health.capacity == capacity_before and health.current == current_before,"invalid equipped growth rejects without changing actor attributes")
	check(build.inventory.get_instance(owned.instance_id).level == 1 and build.inventory.instance_for_source(&"invalid/two") == null and build.inventory.revision == revision,"rejected growth rolls back level, provenance receipt and inventory revision")

func broken_and_static_sources() -> void:
	await fresh()
	var health := actor.actor_resources.health
	var base := health.capacity
	check(own(&"B30",&"fragile") and equip([&"fragile"]),"fragile health item equips through ordinary capacity transaction")
	SupplyHealEffect.apply(health,99,&"fill_fragile")
	var owned := build.inventory.instance_for_source(&"fragile")
	var used: int = build.equipment.snapshot().used
	check(build.inventory.patch_effect_state(owned.instance_id,{"broken":true,"damage_hits":3},&"break") and build.refresh_equipped(),"broken state revokes static effects through an explicit refresh")
	check(health.capacity == base and health.current == base and build.equipment.snapshot().used == used and build.effect_sources().is_empty(),"broken equipment still costs gear and clamps HP while providing no effects")
	health.apply_damage(ActorResourceRequest.new(&"hurt_broken",health.epoch,1,health.get_instance_id()))
	var current := health.current
	check(build.inventory.patch_effect_state(owned.instance_id,{"broken":false,"damage_hits":0},&"repair") and build.refresh_equipped() and health.capacity == base+3 and health.current == current,"repair restores capacity without free healing")
	check(build.effect_sources().size() == 2 and build.inventory.effect_state(owned.instance_id).damage_hits == 0,"repair restores both stat and runtime effect sources")
	await fresh()
	var recoil := actor.motor.tuning.ground_recoil_multiplier
	var coyote := actor.motor.tuning.coyote_time
	var drain := actor.motor.tuning.focus_stamina_drain
	var recovery := actor.motor.tuning.focus_stamina_recovery
	check(own(&"B07",&"recoil") and own(&"B08",&"coyote") and own(&"B04",&"drain") and own(&"B09",&"recovery") and equip([&"recoil",&"coyote",&"drain",&"recovery"]),"independent static parameters equip within eight slots")
	check(is_equal_approx(actor.motor.tuning.ground_recoil_multiplier,recoil*.7) and is_equal_approx(actor.motor.tuning.coyote_time,coyote+.05) and is_equal_approx(actor.motor.tuning.focus_stamina_drain,drain*.82) and is_equal_approx(actor.motor.tuning.focus_stamina_recovery,recovery*1.25),"actual motor and focus consumers receive correct independent static changes")
	check(own(&"B04",&"drain/two") and is_equal_approx(actor.motor.tuning.focus_stamina_drain,drain*.72),"equipped focus upgrade replaces its previous multiplier")
	check(equip([]) and is_equal_approx(actor.motor.tuning.ground_recoil_multiplier,recoil) and is_equal_approx(actor.motor.tuning.coyote_time,coyote) and is_equal_approx(actor.motor.tuning.focus_stamina_drain,drain) and is_equal_approx(actor.motor.tuning.focus_stamina_recovery,recovery),"unloading revokes all static sources back to the sole base")

func covenant_atomic_lock() -> void:
	await fresh()
	var health := actor.actor_resources.health
	var base := health.capacity
	health.apply_damage(ActorResourceRequest.new(&"before_contract",health.epoch,2,health.get_instance_id()))
	var before := health.current
	check(own(&"P18",&"covenant") and own(&"B26",&"five_slots"),"covenant and a five-slot item can coexist in ownership")
	var covenant := build.inventory.instance_for_source(&"covenant")
	check(not equip([&"covenant",&"five_slots"]) and health.capacity == base and health.current == before and not health.normal_healing_blocked and build.inventory.effect_state(covenant.instance_id).is_empty(),"capacity failure leaves no partial lock, HP conversion or healing ban")
	var operations: Array[StringName] = []
	var observed_healing: Array[bool] = []
	var observer: Callable = func(result: ActorResourceResult) -> void:
		operations.append(result.operation)
		observed_healing.append(SupplyHealEffect.apply(health,1,&"observer_heal").accepted())
	health.changed.connect(observer)
	check(equip([&"covenant"]),"first legal covenant equipment transaction commits")
	health.changed.disconnect(observer)
	check(health.capacity == base*2 and health.current == before*2 and operations == [&"set_max_ratio"] and observed_healing == [false],"first covenant changes current and maximum proportionally in one receipt with healing blocked before observers")
	var progress := build.inventory.effect_state(covenant.instance_id)
	check(progress.get("locked",false) and progress.get("first_equip_ratio_applied",false),"first conversion has persistent owned lock and receipt flags")
	check(not equip([]) and health.capacity == base*2 and health.current == before*2,"covenant cannot be unloaded through a new valid session")
	check(not SupplyHealEffect.apply(health,1,&"blocked_supply").accepted() and health.current == before*2,"ordinary supply cannot bypass covenant healing prohibition")
	check(own(&"B11",&"growth_with_contract") and equip([&"covenant",&"growth_with_contract"]) and health.capacity == (base+1)*2 and health.current == before*2,"later maximum HP additions do not repeat covenant conversion")
	check(own(&"B11",&"growth_with_contract/two") and health.capacity == (base+2)*2 and health.current == before*2,"equipped growth under covenant still never heals")
	check(equip([&"covenant",&"growth_with_contract"]) and health.current == before*2,"resubmitting the same covenant cannot replay the proportional gain")
	check(build.clear() and not health.normal_healing_blocked and health.capacity == base and health.current == minf(before*2,base) and build.inventory.instances().is_empty(),"true run cleanup releases locks and healing ban without restoring resources")

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	if "--verify-failure-exit" in OS.get_cmdline_user_args():
		check(false,"intentional strict-exit counterexample")
		quit(1)
		return
	await growth_and_receipts()
	await equipped_growth_and_rollback()
	await broken_and_static_sources()
	await covenant_atomic_lock()
	paused = false
	if build != null: build.clear()
	build = null
	actor = null
	if fixture != null and is_instance_valid(fixture.world): fixture.world.free()
	fixture = null
	await process_frame
	print("ITEM V5 INVENTORY: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)
