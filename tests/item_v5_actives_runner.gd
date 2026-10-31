extends SceneTree
## Isolated module fixture, not a formal run or natural-route acceptance.
## Uses the actual Player scene, Motor floor contact, physics rays and Damageable;
## only the host's catalog/equipment and committed-damage bridge are isolated.
const ACTIVE := preload("res://scripts/items/v5/item_active_effects.gd")
const COMPANIONS := preload("res://scripts/items/v5/item_companion_effects.gd")
const DT := 1.0/60.0
var assertions := 0
var failures := 0
var fixture: Variant
var host: ModuleHost
var actives: ItemActiveEffects
var companions: ItemCompanionEffects

class ModuleHost extends RefCounted:
	var controller: PlayerController
	var world: Node2D
	var equipment: Dictionary = {}
	var states: Dictionary = {}
	var receipts: Dictionary = {}
	var targets_list: Array[Node2D] = []
	var marks: Dictionary = {}
	var dream_marks: Dictionary = {}
	var events: Array[Dictionary] = []
	var companion_module: RefCounted
	# One deliberate local bridge refusal checks that G08 consumes its mark only
	# after accepted Damageable HP settlement, not merely after target selection.
	var reject_deals: int = 0
	var clock := 0.0
	var map_id: StringName = &"fixture/map1"
	var live := true
	func actor() -> PlayerController: return controller
	func world_root() -> Node2D: return world
	func map_key() -> StringName: return map_id
	func now() -> float: return clock
	func is_live() -> bool: return live and is_instance_valid(controller) and controller.active and not controller.actor_resources.health.terminal
	func base_damage() -> float: return 10.0
	func selected_active() -> StringName: return &"B33"
	func effect(id: StringName) -> Dictionary: return equipment.get(id, {}).duplicate(true)
	func has(id: StringName) -> bool: return equipment.has(id)
	func state(id: StringName) -> Dictionary: return states.get(id, {}).duplicate(true)
	func patch_state(id: StringName, patch: Dictionary, receipt: StringName = &"") -> bool:
		if not receipt.is_empty() and receipts.has(receipt): return true
		var next: Dictionary = states.get(id, {}).duplicate(true)
		next.merge(patch.duplicate(true), true)
		states[id] = next
		if not receipt.is_empty(): receipts[receipt] = true
		return true
	func skill_cost(amount: float) -> float: return maxf(15, amount)
	func spend_energy(amount: float, receipt: StringName) -> bool:
		if not controller.combat_energy.consume(String(receipt), skill_cost(amount)): return false
		if companion_module != null: companion_module.call("on_energy_spent", skill_cost(amount), receipt)
		return true
	func clear_line(start: Vector2, finish: Vector2) -> bool:
		return controller.motor.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(start, finish, 1, [controller.motor.get_rid()])).is_empty()
	func targets(point: Vector2, radius: float) -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		for node: Node2D in targets_list:
			if not is_instance_valid(node): continue
			var receiver := node.get_node("Damageable") as Damageable
			if receiver.active and point.distance_to(node.global_position) <= radius: result.append({"node":node, "receiver":receiver})
		result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return point.distance_squared_to(a.node.global_position) < point.distance_squared_to(b.node.global_position))
		return result
	func deal(receiver: Damageable, amount: float, key: StringName, origin: StringName, after_commit: Callable = Callable()) -> bool:
		if not has(origin): return false
		if reject_deals > 0:
			reject_deals -= 1
			return false
		var result := receiver.receive_damage({"event_id":String(key), "amount":amount, "source_faction":&"player", "target_epoch":receiver.damage_epoch, "target_actor_id":receiver.actor_id})
		if result: events.append({"amount":amount, "receiver":receiver.get_instance_id(), "key":key, "origin":origin, "derived":true})
		if result and after_commit.is_valid(): after_commit.call()
		return result
	func deal_active(receiver: Damageable, amount: float, key: StringName, origin: StringName, packet: StringName) -> bool:
		var result := deal(receiver, amount, key, origin)
		if result:
			events[-1].derived = false
			events[-1]["packet"] = packet
		return result
	func is_marked(receiver: Damageable) -> bool: return not mark_key(receiver).is_empty()
	func mark_key(receiver: Damageable) -> StringName: return marks.get(receiver.get_instance_id(), &"")
	func is_dream_marked(receiver: Damageable) -> bool: return not dream_mark_key(receiver).is_empty()
	func dream_mark_key(receiver: Damageable) -> StringName:
		var row: Dictionary = dream_marks.get(receiver.get_instance_id(),{})
		return StringName(row.get("key",&"")) if clock < float(row.get("expires_at",0)) else &""
	func cue(_kind: StringName, _point: Vector2, _details: Dictionary = {}) -> void: pass

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+message)

func fresh(location := Vector2(80, 150)) -> void:
	if actives != null: actives.clear()
	if companions != null: companions.clear()
	if fixture != null and is_instance_valid(fixture.world): fixture.world.free()
	fixture = preload("res://tests/combat_tests.gd").new()
	fixture.tree = self
	await fixture.fixture(location)
	host = ModuleHost.new()
	host.controller = fixture.controller
	host.world = fixture.world
	host.controller.combat_energy.current = 100.0 # Explicit fixture funding, not a pickup trace.
	actives = ACTIVE.new()
	companions = COMPANIONS.new()
	actives.configure(host)
	companions.configure(host)
	host.companion_module = companions

func equip(id: StringName, level := 1) -> void:
	var item := ItemCatalogV5.get_item(id)
	check(item != null and item.is_valid(), "canonical definition exists: "+String(id))
	if item != null: host.equipment[id] = item.parameters_for_level(level)

func enemy(position: Vector2, size := Vector2(36,36)) -> Damageable:
	var body := fixture.body(Rect2(position-size*0.5, size), &"enemy") as StaticBody2D
	body.collision_layer = 2
	var receiver := body.get_node("Damageable") as Damageable
	receiver.max_health = 100.0
	receiver.reset()
	host.targets_list.append(body)
	return receiver

func advance(real_delta: float, world_delta: float) -> void:
	host.clock += real_delta
	actives.advance(real_delta, world_delta)
	companions.advance(real_delta, world_delta)

func run_frames(count: int) -> void:
	for _i: int in count:
		await physics_frame
		advance(DT, DT)

func patrol_locks() -> Dictionary:
	var counts: Dictionary = {}
	for drone: Dictionary in companions.snapshot():
		if drone.id != &"P14": continue
		var id := int(drone.target_lock_id)
		counts[id] = int(counts.get(id,0))+1
	return counts

func companion_visual(kind: StringName) -> WeakRef:
	for node: Node in host.world.get_children():
		if node is ItemV5Entity and (node as ItemV5Entity).kind == kind:
			return weakref(node)
	return null

func companion_lifetimes_and_damage() -> void:
	# Local module fixture: actual Damageable HP, catalog parameters, original
	# CombatEnergyState debit and real visual-node disposal. World delta is stepped
	# explicitly; this is not a formal App/real-time route or Runtime signal test.
	await fresh()
	equip(&"G05")
	var guard_target: Damageable = enemy(Vector2(180,150))
	await physics_frame
	check(companions.activate(&"G05",Vector2.RIGHT).accepted and host.controller.combat_energy.current == 50 and companions.snapshot().size() == 1,"G05 real local activation pays catalog 50 once and owns one large guard")
	var guard_visual: WeakRef = companion_visual(&"large_drone")
	check(guard_visual != null,"G05 lifetime fixture observes the actual large-guard visual node")
	advance(1.79,1.79)
	check(guard_target.health == 100 and host.events.is_empty(),"G05 does not apply damage before its 1.8 world-second attack interval")
	advance(.02,.02)
	check(is_equal_approx(guard_target.health,94) and host.events.size() == 1 and host.events[0].origin == &"G05" and host.events[0].derived,"G05 first actual Damageable hit is .60D at fixture D10, classified as derived")
	var guard_state: Array[Dictionary] = companions.snapshot()
	var guard_hp: float = guard_target.health
	advance(4,0)
	check(companions.snapshot() == guard_state and guard_target.health == guard_hp,"zero world delta suspends accepted G05 age and actual damage")
	advance(16.18,16.18)
	check(companions.snapshot().size() == 1 and float(companions.snapshot()[0].age) < 18,"G05 remains alive immediately before its actual 18 world-second lifetime")
	var guard_end_hp: float = guard_target.health
	var guard_end_events: int = host.events.size()
	advance(.02,.02)
	check(companions.snapshot().is_empty() and guard_target.health == guard_end_hp and host.events.size() == guard_end_events,"G05 expires before any attack at or beyond the 18-second boundary")
	# Queue-free is delivered at frame end; allow that boundary before observing
	# the weak reference, without changing the gameplay lifetime assertion above.
	for unused: int in 2: await process_frame
	check(guard_visual != null and guard_visual.get_ref() == null,"G05 lifetime expiration actually frees its owned entity node")
	advance(3,3)
	check(guard_target.health == guard_end_hp and host.events.size() == guard_end_events and host.controller.combat_energy.current == 50,"expired G05 cannot deal ghost damage or refund resonance")
	check(companions.activate(&"G05",Vector2.RIGHT).accepted and companions.snapshot().size() == 1 and host.controller.combat_energy.current == 0,"G05 may summon again only through a new paid activation after expiry")
	await fresh()
	equip(&"P15")
	var temporary_target: Damageable = enemy(Vector2(180,150))
	await physics_frame
	# This host explicitly forwards its original ledger debit. It intentionally
	# does not claim coverage of ItemRuntime's combat_energy.spent subscription.
	check(host.spend_energy(45,&"local_fixture/p15_paid_threshold") and host.controller.combat_energy.current == 55 and companions.snapshot().size() == 1,"P15 local debit-forwarding fixture spends real 45 before creating one temporary companion")
	var temporary_visual: WeakRef = companion_visual(&"temporary_drone")
	check(temporary_visual != null,"P15 lifetime fixture observes the actual temporary-drone entity")
	advance(1.49,1.49)
	check(temporary_target.health == 100,"P15 temporary companion respects its actual 1.5 world-second attack interval")
	advance(.02,.02)
	check(is_equal_approx(temporary_target.health,96.5) and host.events.size() == 1 and host.events[0].origin == &"P15" and host.events[0].derived,"P15 actual temporary companion hit deals .35D to Damageable at D10")
	var temporary_state: Array[Dictionary] = companions.snapshot()
	host.live = false
	advance(20,20)
	check(companions.snapshot() == temporary_state and is_equal_approx(temporary_target.health,96.5),"inactive host suspends the paid temporary companion's world lifetime and attacks")
	host.live = true
	advance(6.48,6.48)
	check(companions.snapshot().size() == 1 and float(companions.snapshot()[0].age) < 8,"P15 remains alive immediately before its 8 world-second lifetime")
	var temporary_end_hp: float = temporary_target.health
	var temporary_end_events: int = host.events.size()
	advance(.02,.02)
	check(companions.snapshot().is_empty() and temporary_target.health == temporary_end_hp and host.events.size() == temporary_end_events,"P15 lifetime removes the companion before an at-expiry attack")
	for unused: int in 2: await process_frame
	check(temporary_visual != null and temporary_visual.get_ref() == null,"P15 expiry actually releases its temporary visual node")
	advance(4,4)
	check(companions.snapshot().is_empty() and temporary_target.health == temporary_end_hp and host.controller.combat_energy.current == 55,"expired P15 cannot respawn from an old spend, deal ghost HP damage or self-charge")

func growth_damage_and_s12() -> void:
	# Accepted elite/mark identities remain explicit local initialization. Actual
	# target selection, damage ratios, Damageable HP and commit-only credit use
	# the real companion module; no HP result is returned by a fake damage solver.
	await fresh()
	equip(&"G19")
	var nearby: Damageable = enemy(Vector2(120,150))
	var marked: Damageable = enemy(Vector2(240,150))
	await physics_frame
	check(host.controller.combat_energy.consume("local_fixture/growth_reserve",90),"growth fixture leaves room to detect forbidden derived resonance refunds")
	companions.sync()
	advance(2.5,2.5)
	check(is_equal_approx(nearby.health,97) and marked.health == 100 and host.events.size() == 1,"G19 actual base hit is .30D to the nearer physical target")
	companions.on_kill({"elite":false,"map":host.map_id,"key":"ordinary_fixture"})
	companions.on_kill({"elite":true,"map":&"fixture/wrong_map","key":"stale_elite_fixture"})
	check(int(host.state(&"G19").get("evolution",0)) == 0,"ordinary or wrong-map kill fixture cannot increase G19 growth")
	companions.on_kill({"elite":true,"map":host.map_id,"key":"growth_elite_one"})
	advance(2.5,2.5)
	check(is_equal_approx(nearby.health,93.4) and int(host.state(&"G19").evolution) == 1,"G19 first accepted growth changes actual next HP damage to .36D")
	companions.on_kill({"elite":true,"map":host.map_id,"key":"growth_elite_one"})
	check(int(host.state(&"G19").evolution) == 1,"same elite identity cannot multiply the already-grown damage again")
	companions.on_kill({"elite":true,"map":host.map_id,"key":"growth_elite_two"})
	companions.on_kill({"elite":true,"map":host.map_id,"key":"growth_elite_three"})
	advance(2.5,2.5)
	check(is_equal_approx(nearby.health,89.2) and int(host.state(&"G19").evolution) == 2,"G19 capped second growth deals actual .42D, not compounded .432D or third growth")
	equip(&"G08")
	host.marks[marked.get_instance_id()] = &"s12/accepted_mark_one"
	var nearby_before: float = nearby.health
	host.reject_deals = 1
	advance(2.5,2.5)
	check(marked.health == 100 and nearby.health == nearby_before and (host.state(&"G08").get("used_mark_keys",{}) as Dictionary).is_empty(),"S12 local refused bridge attempt changes no HP and cannot consume the first-hit mark credit")
	advance(2.5,2.5)
	check(is_equal_approx(marked.health,94.54) and nearby.health == nearby_before,"S12 grown G19 prioritizes farther marked target and first actual committed hit is .42D times 1.3")
	check(bool((host.state(&"G08").get("used_mark_keys",{}) as Dictionary).get("s12/accepted_mark_one",false)),"S12 marks the first-hit credit consumed only after actual Damageable acceptance")
	advance(2.5,2.5)
	check(is_equal_approx(marked.health,90.34),"S12 second committed hit on the same mark returns to grown .42D without repeating 1.3")
	host.equipment.erase(&"G08")
	companions.sync()
	equip(&"G08")
	advance(2.5,2.5)
	check(is_equal_approx(marked.health,86.14),"S12 unloading and re-equipping G08 cannot refresh a consumed mark bonus")
	host.marks[marked.get_instance_id()] = &"s12/accepted_mark_two"
	advance(2.5,2.5)
	check(is_equal_approx(marked.health,80.68),"S12 a new accepted mark identity grants exactly one fresh grown first-hit bonus")
	check(nearby.health == nearby_before and host.controller.combat_energy.current == 10 and host.events.all(func(row: Dictionary) -> bool: return row.origin == &"G19" and row.derived),"S12 all actual grown hits remain derived, preserve mark priority and never generate resonance")

func _run() -> void:
	await fresh()
	check(not actives.activate(&"B33",Vector2.RIGHT).accepted and is_equal_approx(host.controller.combat_energy.current,100), "unowned active cannot spend")
	equip(&"B33",3)
	check(not actives.activate(&"B33",Vector2.ZERO).accepted and is_equal_approx(host.controller.combat_energy.current,100), "zero aim rejects atomically")
	var close := enemy(Vector2(120,150))
	var blocked := enemy(Vector2(155,150))
	fixture.body(Rect2(138,100,4,100))
	await physics_frame
	check(actives.activate(&"B33",Vector2.RIGHT).accepted, "level3 local blast accepted")
	check(is_equal_approx(close.health,81) and is_equal_approx(blocked.health,100), "level3 blast real LOS deals1.9D and cannot pass wall")
	var after := host.controller.combat_energy.current
	check(not actives.activate(&"B33",Vector2.RIGHT).accepted and host.controller.combat_energy.current==after, "cooldown duplicate no debit")
	host.equipment.erase(&"B33");actives.sync();equip(&"B33",3)
	check(not actives.activate(&"B33",Vector2.RIGHT).accepted, "unload does not erase active cooldown")
	await fresh(Vector2(250,150))
	equip(&"P24");equip(&"G15")
	var flywheel_target := enemy(Vector2(340,150),Vector2(60,60))
	var reverse_target := enemy(Vector2(160,150),Vector2(60,60))
	await physics_frame
	check(actives.activate(&"P24",Vector2.RIGHT).accepted and actives.snapshot().size()==2, "split flywheel creates exactlytwo on one debit")
	var directions := actives.snapshot()
	check((directions[0].direction as Vector2).dot(directions[1].direction)<-0.999, "S13flywheelslaunchinopposite180directions")
	check(is_equal_approx(host.controller.combat_energy.current,65), "split has single35 debit")
	await run_frames(150)
	check(is_equal_approx(100-flywheel_target.health,8.05) and is_equal_approx(100-reverse_target.health,8.05) and is_equal_approx(200-flywheel_target.health-reverse_target.health,16.1), "oppositesideout/backsplit total1.4D*1.15, notdouble")
	check(actives.snapshot().is_empty(), "bothflywheels physically return and clean")
	var packets: Dictionary = {}
	for event: Dictionary in host.events: packets[event.packet] = true
	check(packets.size()==1 and host.events.size()==4, "twoflywheels fourcontacts shareone attackpacket")
	await fresh()
	equip(&"G14")
	var main_target := enemy(Vector2(160,150))
	var chain_target := enemy(Vector2(220,150))
	var behind_wall := enemy(Vector2(290,150))
	fixture.body(Rect2(250,100,4,100))
	await physics_frame
	check(actives.activate(&"G14",Vector2.RIGHT).accepted, "throw-onlyarc accepted")
	await run_frames(50)
	check(is_equal_approx(main_target.health,87) and is_equal_approx(chain_target.health,96.5) and is_equal_approx(behind_wall.health,100), "throw deals1.3D+oneclear.35D, wallblockssecondchain")
	check(is_equal_approx(host.controller.combat_energy.current,55) and actives.snapshot().is_empty(), "chainproducesnoresonance and grenadecleans")
	await fresh()
	equip(&"G16");equip(&"G15")
	var pulse_target := enemy(Vector2(180,150))
	await physics_frame
	var position_before := host.controller.motor.global_position
	check(actives.activate(&"G16",Vector2.RIGHT).accepted, "clockjudgmentaccepted")
	await run_frames(50)
	check(is_equal_approx(pulse_target.health,73) and host.events.size()==3, "three.9D pulsesnotduplicatedbyprojectionupgrade")
	check(host.controller.motor.global_position==position_before and is_equal_approx(host.controller.combat_energy.current,35), "judgmentmovesnobody andone65debit")
	await fresh(Vector2(80,30))
	equip(&"P25")
	check(not actives.activate(&"P25",Vector2.RIGHT).accepted and is_equal_approx(host.controller.combat_energy.current,100), "midairtraprejectswithoutpaying")
	await fixture.ticks(60)
	check(host.controller.motor.is_on_floor(), "trapfixtureusesrealMotorfloor")
	check(actives.activate(&"P25",Vector2.RIGHT).accepted and actives.snapshot().size()==1, "reliableground trapplaced")
	host.clock += 10
	check(actives.activate(&"P25",Vector2.RIGHT).accepted and actives.snapshot().size()==2, "secondtrapallowed")
	host.clock += 10
	host.controller.combat_energy.current = 100 # Fixture funds ensure the limit, not poverty, rejects.
	check(not actives.activate(&"P25",Vector2.RIGHT).accepted and actives.snapshot().size()==2 and is_equal_approx(host.controller.combat_energy.current,100), "thirdtraprejectedwithoutdebit")
	var trapped := enemy(Vector2(120,180))
	await physics_frame
	advance(DT,DT)
	check(is_equal_approx(trapped.health,82) and actives.snapshot().is_empty(), "tworealtraps eachdetonateonce .9D")
	await fresh()
	equip(&"P14");equip(&"G19");equip(&"P15");equip(&"G05")
	companions.sync()
	check(companions.snapshot().size()==4, "threepatrol+onegrowthdrone")
	var companion_target := enemy(Vector2(180,150))
	await physics_frame
	advance(5,0)
	check(is_equal_approx(companion_target.health,100) and companions.snapshot().size()==4, "worldfreezestopsdroneage/attacks")
	companions.on_energy_spent(20,&"spendA")
	companions.on_energy_spent(25,&"spendB")
	check(companions.snapshot().size()==5, "45actualspendcreatesone temporary")
	companions.on_energy_spent(25,&"spendB")
	check(companions.snapshot().size()==5, "sameenergyreceiptcannotduplicate")
	companions.on_energy_spent(90,&"spendC")
	check(companions.snapshot().size()==6 and is_zero_approx(float(host.state(&"P15").spent_remainder)), "temporarydronecap2 andwholethresholdnotbanked")
	check(companions.activate(&"G05",Vector2.RIGHT).accepted and companions.snapshot().size()==7, "onepaidlargeguard")
	host.clock += 12
	check(not companions.activate(&"G05",Vector2.RIGHT).accepted and companions.snapshot().size()==7, "largeguardmax1evenafterrealcooldown")
	companions.on_kill({"elite":true,"map":host.map_id,"key":"elite1"})
	companions.on_kill({"elite":true,"map":host.map_id,"key":"elite1"})
	check(int(host.state(&"G19").evolution)==1, "sameelitekillonlyevolvesonce")
	companions.on_kill({"elite":true,"map":host.map_id,"key":"elite2"})
	companions.on_kill({"elite":true,"map":host.map_id,"key":"elite3"})
	check(int(host.state(&"G19").evolution)==2, "growthmax2evolutions")
	host.equipment.erase(&"G19");companions.sync();equip(&"G19");companions.sync()
	check(int(host.state(&"G19").evolution)==2 and companions.snapshot().size()==7, "unloadretainsgrowth anddoesnotduplicatedrones")
	host.map_id = &"fixture/map2"
	companions.map_entered(host.map_id)
	actives.map_entered(host.map_id)
	check(companions.snapshot().size()==4 and int(host.state(&"G19").evolution)==2, "maptransitionrebuildspermanentonly,retainsgrowth")
	await fresh()
	equip(&"P14");equip(&"G08")
	var nearby := enemy(Vector2(120,150))
	var marked := enemy(Vector2(240,150))
	host.marks[marked.get_instance_id()] = &"hook-mark1"
	await physics_frame
	companions.sync()
	advance(1.5,1.5)
	check(is_equal_approx(nearby.health,100) and is_equal_approx(marked.health,96.04), "markpriority andonlyfirstofthreegets1.3bonus")
	host.equipment.erase(&"G08");companions.sync();equip(&"G08")
	advance(1.5,1.5)
	check(is_equal_approx(marked.health,92.44), "swapdoesnotresetconsumedmarkbonus")
	host.marks[marked.get_instance_id()] = &"hook-mark2"
	advance(1.5,1.5)
	check(is_equal_approx(marked.health,88.48), "newrealmarkhasonefreshbonus")
	var state_before := companions.snapshot()
	host.live = false
	advance(20,20)
	check(companions.snapshot()==state_before, "focus/pauseholdsalreadyacceptedcompanions")
	host.live = true
	host.equipment.clear()
	companions.sync()
	check(companions.snapshot().is_empty(), "unequipleavesnocompanionentities")
	await fresh()
	equip(&"P14");equip(&"B19")
	var dream_target := enemy(Vector2(240,150))
	host.dream_marks[dream_target.get_instance_id()] = {"key":&"dream-hook1","expires_at":4.0}
	await physics_frame
	companions.sync()
	advance(1.5,1.5)
	var first_locks := patrol_locks()
	check(is_equal_approx(dream_target.health,97.6) and host.events.size()==2, "S02onlytwoofthreepatrolsattacklonedreamtarget")
	check(int(first_locks.get(dream_target.get_instance_id(),0))==2 and int(first_locks.get(0,0))==1, "S02per-targetcap2 leaves third patrol independently idle")
	var another_dream := enemy(Vector2(140,150))
	host.dream_marks[another_dream.get_instance_id()] = {"key":&"dream-hook2","expires_at":5.5}
	await physics_frame
	advance(1.5,1.5)
	var second_locks := patrol_locks()
	check(int(second_locks.get(dream_target.get_instance_id(),0))==2 and int(second_locks.get(another_dream.get_instance_id(),0))==1, "S02legalindependentlocksretaineddespitenearernewmarkedtarget")
	advance(1.5,1.5)
	var expired_locks := patrol_locks()
	check(not host.is_dream_marked(dream_target) and int(expired_locks.get(another_dream.get_instance_id(),0))==2 and int(expired_locks.get(dream_target.get_instance_id(),0))==1, "S02four-secondexpiredmarkreleasesprioritybutkeepscap2")
	equip(&"G08")
	host.marks[dream_target.get_instance_id()] = &"pursuit-hook1"
	advance(1.5,1.5)
	check(int(patrol_locks().get(dream_target.get_instance_id(),0))==2, "G08pursuitpriorityremainsaboveS02dreampriority")
	host.equipment.erase(&"B19")
	companions.sync()
	check(int(patrol_locks().get(0,0))==3, "unloadingdreamitemclearsS02locks")
	await companion_lifetimes_and_damage()
	await growth_damage_and_s12()
	actives.clear();companions.clear()
	fixture.world.free()
	await process_frame
	print("ITEM V5 ACTIVES: %s assertions, %s failures" % [assertions,failures])
	quit(0 if failures==0 else 1)
