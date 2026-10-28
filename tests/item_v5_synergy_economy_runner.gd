extends SceneTree
## Initialized native fixture, not a natural-route recording. Every synergy
## runs through the real ItemRuntime, catalog, inventory, equipment and wallet;
## no substitute host reports invented recovery, synergy or kill outcomes.
const SUPPORT := preload("res://tests/gear_inventory_support.gd")
var assertions := 0
var failures := 0
var fixture: Variant
var actor: PlayerController
var build: BuildState
var life: DemoLifetime
var wallet: RunWallet
var runtime: ItemRuntime
var cues: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func fresh() -> void:
	paused = false
	if runtime != null: runtime.clear()
	if fixture != null and is_instance_valid(fixture.world): fixture.world.free()
	fixture = preload("res://tests/combat_tests.gd").new()
	fixture.tree = self
	await fixture.fixture(Vector2(80, 150))
	actor = fixture.controller
	life = DemoLifetime.new()
	build = BuildState.new()
	build.configure(actor, life, &"synergy_economy_fixture")
	wallet = RunWallet.new()
	runtime = ItemRuntime.new()
	runtime.configure(actor, build, life, wallet)
	cues.clear()
	runtime.effect_cued.connect(func(kind: StringName, point: Vector2, detail: Dictionary) -> void:
		cues.append({"kind":kind, "point":point, "detail":detail.duplicate(true)}))
	runtime.bind_world(fixture.world, &"synergy/map_1")
	check(runtime.is_live(), "real runtime binds the living focused actor and original stage epochs")

func equip(wanted: Array[StringName]) -> bool:
	var ids: Array[StringName] = []
	for id: StringName in wanted:
		if build.inventory.instance_for_definition(id) == null:
			if not build.add_item(StringName("fixture/%s" % id), ItemCatalogV5.get_item(id)): return false
		ids.append(build.inventory.instance_for_definition(id).instance_id)
	var accepted := SUPPORT.equip_ids(build, ids)
	runtime.sync()
	return accepted

func cue_count(kind: StringName) -> int:
	var count := 0
	for row: Dictionary in cues:
		if row.kind == kind: count += 1
	return count

func s10_row() -> Dictionary:
	return (runtime.state(&"G07").get("synergy_s10_maps", {}) as Dictionary).get(String(runtime.map_key()), {})

func recovered() -> float:
	var row: Dictionary = (runtime.state(&"G07").get("recovery_maps", {}) as Dictionary).get(String(runtime.map_key()), {})
	return float(row.get("recovered", 0.0))

func kill(index: int) -> Damageable:
	var body: StaticBody2D = fixture.body(Rect2(300 + index * 24, 110, 16, 24), &"enemy")
	body.set_meta("item_v5_enemy_id", "synergy_enemy_%s" % index)
	var receiver := body.get_node("Damageable") as Damageable
	receiver.actor_id = body.get_instance_id()
	check(receiver.receive_damage({"event_id":"fixture/lethal/%s" % index, "amount":99.0, "source_faction":&"player"}) and not receiver.active, "actual Damageable commits fixture lethal hit %s" % index)
	runtime.on_hit({"receiver":receiver, "session":actor.session_id, "weapon_epoch":actor.shoot_ability.weapon_epoch, "packet":index + 1, "shot":index + 1, "point":body.position, "direction":Vector2.RIGHT, "amount":99.0, "skill":false, "airborne":false})
	return receiver

func shared_coin_budget() -> void:
	await fresh()
	check(equip([&"B16", &"B01"]), "real purse plus magnet fit ordinary loadout")
	check(runtime.has(&"B16") and runtime.has(&"B01"), "S07 uses both actual equipped sources without synthetic host effects")
	var first := kill(0)
	check(wallet.balance == 1 and cue_count(&"coin") == 1, "first accepted kill mints one original wallet coin and one cue")
	var cue: Dictionary = cues.back()
	check(bool(cue.detail.get("magnet_bonus", false)) and int(cue.detail.get("amount", 0)) == 1, "S07 marks only the established one-coin event for visual magnet return")
	runtime.on_hit({"receiver":first, "session":actor.session_id, "packet":1})
	check(wallet.balance == 1 and cue_count(&"coin") == 1, "same dead receiver cannot duplicate wallet grant or visual return")
	var purse := runtime.instance(&"B16")
	var receipt := StringName("item/B16/%s/%s/kill/synergy_enemy_0" % [purse.instance_id, runtime.map_key()])
	check(wallet.grant(1, receipt) and wallet.balance == 1 and not wallet.grant(2, receipt), "real original wallet replays same grant and rejects changed amount under the same receipt")
	check(equip([&"B16"]), "removing magnet leaves the same owned purse")
	kill(1)
	check(wallet.balance == 2 and not bool(cues.back().detail.get("magnet_bonus", false)), "without magnet the same purse budget pays once with no S07 visual flag")
	check(equip([&"B16", &"B01"]), "magnet returns without replacing the purse instance")
	for index: int in range(2, 11): kill(index)
	var maps: Dictionary = runtime.state(&"B16").get("kill_maps", {})
	var row: Dictionary = maps[String(runtime.map_key())]
	check(wallet.balance == 8 and int(row.coins) == 8 and (row.rewarded_enemies as Dictionary).size() == 8, "S07 keeps B16's shared eight-coin budget, never historical sixteen or a second magnet allowance")
	check(cue_count(&"coin") == 8, "no visual coin is emitted for over-budget kills")
	check(equip([]) and equip([&"B16", &"B01"]), "both synergy sources can leave and return")
	kill(11)
	check(wallet.balance == 8 and cue_count(&"coin") == 8, "unequipping the combination cannot refresh the shared owned map budget")
	life.stage_epoch += 1
	runtime.bind_world(fixture.world, &"synergy/map_2")
	kill(12)
	check(wallet.balance == 9 and cue_count(&"coin") == 9, "next real stage epoch grants exactly its own first map coin")
	await fresh()
	check(equip([&"B16", &"B01"]), "conflicting receipt counterexample equips actual S07")
	purse = runtime.instance(&"B16")
	receipt = StringName("item/B16/%s/%s/kill/synergy_enemy_0" % [purse.instance_id, runtime.map_key()])
	check(wallet.grant(7, receipt), "explicit initialization seeds a conflicting original-wallet transaction")
	var previous := runtime.state(&"B16")
	var revision := build.inventory.revision
	kill(0)
	check(wallet.balance == 7 and runtime.state(&"B16") == previous and build.inventory.revision == revision and cue_count(&"coin") == 0, "wallet conflict restores shared purse budget, inventory revision and emits no S07 coin")

func idle_credit_once_per_map() -> void:
	await fresh()
	check(equip([&"G07", &"P02", &"B33"]), "real recovery, reducer and blast active fit five gear")
	check(runtime.select_active(&"B33"), "actual item active is selected")
	check(is_equal_approx(runtime.skill_cost(30), 27), "ordinary P02 first applies current 0.90 active multiplier")
	check(runtime.grant_energy(100, &"fixture/full") == 100, "explicit resource initialization fills actual energy")
	runtime.advance(20, 0)
	check(recovered() == 0 and s10_row().is_empty() and cue_count(&"skill_credit_ready") == 0, "elapsed idle while full creates neither actual recovery nor S10 credit")
	check(actor.combat_energy.consume("fixture/open_room", 40), "original energy ledger opens forty real capacity")
	paused = true
	var before_clock := runtime.now()
	runtime.advance(100, 100)
	paused = false
	check(runtime.now() == before_clock and recovered() == 0 and cue_count(&"skill_credit_ready") == 0, "paused advance cannot move the live clock or arm credit")
	runtime.advance(6, 0)
	runtime.advance(2, 0)
	check(is_equal_approx(recovered(), 4) and is_equal_approx(float(s10_row().get("recovered", 0)), 4) and not bool(s10_row().get("armed", false)) and cue_count(&"skill_credit_ready") == 0, "four actually recovered energy remains below the five-point synergy threshold")
	runtime.advance(0.5, 0)
	check(is_equal_approx(recovered(), 5) and bool(s10_row().get("armed", false)) and cue_count(&"skill_credit_ready") == 1, "only fifth actual recovery arms the credit and emits one readiness cue")
	var ready: Dictionary = {}
	for row: Dictionary in cues:
		if row.kind == &"skill_credit_ready": ready = row.detail
	check(ready.get("origin") == &"G07" and is_equal_approx(float(ready.get("amount", 0)), 5), "readiness cue records the real G07 origin and five-point credit")
	check(is_equal_approx(runtime.skill_cost(30), 22) and is_equal_approx(runtime.skill_cost(10), 15), "armed S10 subtracts five after P02 while keeping minimum cost fifteen")
	var energy := actor.combat_energy.current
	check(not runtime.activate_selected(Vector2.ZERO).accepted and actor.combat_energy.current == energy and bool(s10_row().armed), "rejected active direction neither debits energy nor consumes credit")
	check(equip([&"G07", &"B33"]) and is_equal_approx(runtime.skill_cost(30), 30) and bool(s10_row().armed), "removing P02 disables discount while preserving the owned pending credit")
	check(equip([&"G07", &"P02", &"B33"]) and is_equal_approx(runtime.skill_cost(30), 22) and cue_count(&"skill_credit_ready") == 1, "re-equipping P02 restores existing credit without a new cue")
	energy = actor.combat_energy.current
	var result := runtime.activate_selected(Vector2.RIGHT)
	check(bool(result.accepted) and is_equal_approx(float(result.get("cost", 0)), 22) and is_equal_approx(energy - actor.combat_energy.current, 22), "accepted real blast active pays exactly twenty-two once through original energy ledger")
	check(not bool(s10_row().armed) and bool(s10_row().consumed) and is_equal_approx(runtime.skill_cost(30), 27), "accepted active consumes credit and next price returns to ordinary P02")
	energy = actor.combat_energy.current
	check(not runtime.activate_selected(Vector2.RIGHT).accepted and actor.combat_energy.current == energy, "immediate cooldown rejection cannot consume or refund another energy payment")
	runtime.advance(10, 0)
	energy = actor.combat_energy.current
	result = runtime.activate_selected(Vector2.RIGHT)
	check(bool(result.accepted) and is_equal_approx(energy - actor.combat_energy.current, 27), "next accepted active on the same map receives no second credit")
	runtime.advance(30, 0)
	check(is_equal_approx(recovered(), 20) and bool(s10_row().consumed) and not bool(s10_row().armed) and cue_count(&"skill_credit_ready") == 1, "remaining recovery ends at original twenty budget and cannot rearm consumed map credit")
	check(equip([&"B33"]) and equip([&"G07", &"P02", &"B33"]), "both economic sources can be removed and re-equipped")
	runtime.advance(10, 0)
	check(is_equal_approx(recovered(), 20) and not bool(s10_row().armed) and is_equal_approx(runtime.skill_cost(30), 27) and cue_count(&"skill_credit_ready") == 1, "re-equipping cannot reset either twenty recovery or consumed credit")
	life.stage_epoch += 1
	runtime.bind_world(fixture.world, &"synergy/map_2")
	check(s10_row().is_empty() and recovered() == 0 and cue_count(&"skill_credit_ready") == 1, "map binding alone emits no recovery credit or cue")
	runtime.advance(6, 0)
	runtime.advance(2, 0)
	check(not bool(s10_row().get("armed", false)) and cue_count(&"skill_credit_ready") == 1, "second map still requires its own full actual five energy threshold")
	runtime.advance(0.5, 0)
	check(is_equal_approx(recovered(), 5) and bool(s10_row().armed) and cue_count(&"skill_credit_ready") == 2, "second map earns one independent credit and exactly one new cue")
	energy = actor.combat_energy.current
	result = runtime.activate_selected(Vector2.RIGHT)
	check(bool(result.accepted) and is_equal_approx(energy - actor.combat_energy.current, 22) and bool(s10_row().consumed), "second-map real active consumes only its newly earned credit")

func ordinary_grants_and_floor() -> void:
	await fresh()
	check(equip([&"G07", &"P02", &"B33"]), "floor control equips actual reducer and active")
	check(runtime.grant_energy(50, &"fixture/ordinary_energy") == 50 and s10_row().is_empty() and cue_count(&"skill_credit_ready") == 0, "ordinary non-idle energy grant cannot arm recovery synergy")
	var before := actor.combat_energy.current
	check(runtime.spend_energy(10, &"fixture/floor") and is_equal_approx(before - actor.combat_energy.current, 15), "actual active-resource debit respects P02 minimum fifteen")
	before = actor.combat_energy.current
	check(not runtime.spend_energy(10, &"fixture/floor") and actor.combat_energy.current == before, "same active-spend receipt cannot debit twice")
	check(runtime.spend_energy(10, &"fixture/passive", false) and is_equal_approx(before - actor.combat_energy.current, 10), "non-active payment bypasses P02 floor and credit")
	check(equip([&"G07", &"B33"]), "control removes reducer while leaving recovery and active")
	runtime.advance(8.5, 0)
	check(is_equal_approx(recovered(), 5) and s10_row().is_empty() and cue_count(&"skill_credit_ready") == 0 and is_equal_approx(runtime.skill_cost(10), 10), "G07 alone really recovers five but has neither S10 credit nor P02 floor")
	check(equip([&"G07", &"P02", &"B33"]) and not bool(s10_row().get("armed", false)), "equipping P02 cannot retroactively count earlier solo recovery")

func _run() -> void:
	await shared_coin_budget()
	await idle_credit_once_per_map()
	await ordinary_grants_and_floor()
	if runtime != null: runtime.clear()
	if fixture != null and is_instance_valid(fixture.world): fixture.world.free()
	print("ITEM V5 SYNERGY ECONOMY: %s checks, %s failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
