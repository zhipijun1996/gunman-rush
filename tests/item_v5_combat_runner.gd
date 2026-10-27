extends SceneTree
## Focused handler/real Damageable contract fixtures. Event dictionaries are
## explicitly initialized accepted-hit fixtures, not natural route evidence.
## Formal weapon inputs and FrameDamagePolicy are covered by integration runners.
var assertions := 0
var failures := 0
var fixture: RefCounted
var host: CombatFixtureHost
var module: ItemCombatEffects

class CombatFixtureHost extends RefCounted:
	var controller: PlayerController
	var combat: ItemCombatEffects
	var effects: Dictionary = {}
	var states: Dictionary = {}
	var clock := 0.0
	var deals: Array[Dictionary] = []
	var cues: Array[Dictionary] = []
	var unique: Dictionary = {}
	func actor() -> PlayerController: return controller
	func now() -> float: return clock
	func is_live() -> bool: return controller.active and not controller.actor_resources.health.terminal
	func has(id: StringName) -> bool: return effects.has(id)
	func effect(id: StringName) -> Dictionary: return effects.get(id,{}).duplicate(true)
	func state(id: StringName) -> Dictionary: return states.get(id,{}).duplicate(true)
	func patch_state(id: StringName, patch: Dictionary, _receipt: StringName = &"") -> bool:
		var value: Dictionary = states.get(id,{}).duplicate(true)
		value.merge(patch,true)
		states[id] = value
		return true
	func base_damage() -> float: return 1.0
	func map_key() -> StringName: return &"combat-fixture-map"
	func targets(point: Vector2, radius: float) -> Array[Dictionary]: return controller.shoot_ability.behavior().receivers(point,radius)
	func clear_line(start: Vector2, finish: Vector2) -> bool: return controller.shoot_ability.behavior().clear_line(start,finish)
	func cue(kind: StringName, point: Vector2, detail: Dictionary = {}) -> void: cues.append({"kind":kind,"point":point,"detail":detail})
	func deal(receiver: Damageable, amount: float, key: StringName, origin: StringName, after_commit: Callable = Callable()) -> bool:
		var receipt := "%s/%s" % [receiver.get_instance_id(),key]
		if unique.has(receipt): return false
		unique[receipt] = true
		var accepted := receiver.receive_damage({"event_id":receipt,"source_faction":&"player","source_actor_id":controller.motor.get_instance_id(),"amount":amount,"damage_type":&"item_effect","skill_attack":true})
		if accepted:
			deals.append({"origin":origin,"target":receiver.get_instance_id(),"amount":amount,"key":key})
			if after_commit.is_valid(): after_commit.call()
		return accepted
	func burst(point: Vector2, radius: float, ratio: float, origin: StringName, receipt: StringName) -> int:
		var count := 0
		for value: Dictionary in targets(point,radius):
			if clear_line(point,(value.node as Node2D).global_position) and deal(value.receiver,ratio,StringName("%s/%s" % [receipt,(value.receiver as Damageable).get_instance_id()]),origin): count += 1
		return count

func _initialize() -> void:
	if "--negative-probe" in OS.get_cmdline_user_args():
		print("ITEM V5 COMBAT: 1 assertions, 1 failures")
		quit(1)
		return
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+label)

func fresh(ids: Array[StringName] = [], level: int = 1) -> void:
	if fixture != null:
		var old: Node = fixture.get("world")
		if is_instance_valid(old): old.free()
	fixture = preload("res://tests/combat_tests.gd").new()
	fixture.set("tree",self)
	await fixture.call("fixture",Vector2(50,40))
	host = CombatFixtureHost.new()
	host.controller = fixture.get("controller")
	module = ItemCombatEffects.new()
	host.combat = module
	module.configure(host)
	module.map_entered(host.map_key())
	for id: StringName in ids:
		var definition := ItemCatalogV5.get_item(id)
		check(definition != null, "canonical item exists "+String(id))
		if definition != null: host.effects[id] = definition.parameters_for_level(mini(level,definition.max_level))

func enemy(point: Vector2) -> Damageable:
	var body := Area2D.new()
	body.position = point
	body.collision_layer = 2
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20,20)
	collision.shape = shape
	body.add_child(collision)
	var receiver := Damageable.new()
	receiver.name = "Damageable"
	receiver.faction = &"enemy"
	receiver.max_health = 100.0
	body.add_child(receiver)
	(fixture.get("world") as Node).add_child(body)
	return receiver

func event(receiver: Damageable, packet: int, airborne := true, skill := false, index := 1) -> Dictionary:
	return {"session":host.controller.session_id,"packet":packet,"shot":packet*10+index,"shot_index":index,"airborne":airborne,"skill":skill,"receiver":receiver,"point":(receiver.get_parent() as Node2D).global_position,"direction":Vector2.RIGHT,"amount":1.0,"weapon_mode":WeaponDefinition.Mode.PULSE,"tier":1}

func multipliers() -> void:
	await fresh([&"B03",&"B05",&"B22",&"B29",&"B31",&"P03",&"P08",&"P23",&"P33",&"P17"],3)
	var target := enemy(Vector2(200,40))
	check(is_equal_approx(module.modify_direct_damage(10.0,target,false,1),13.2), "Lv3 barrel is direct 1.32, not repeated multiplication")
	check(is_equal_approx(module.modify_direct_damage(10.0,target,true,1),10.0), "barrel never increases skill/derived channel")
	host.controller.shoot_ability.equip(preload("res://resources/weapons/laser_cannon.tres"))
	check(is_equal_approx(module.modify_direct_damage(10.0,target,true,2),14.0), "Lv3 weapon active gets its own 1.40 scale")
	check(is_equal_approx(module.weapon_cooldown_multiplier(),.88), "primary cooldown 0.88")
	check(is_equal_approx(module.bomb_radius_multiplier(),1.28), "bomb family radius is level-selected")
	check(is_equal_approx(module.projectile_range_multiplier(),1.5), "gun range is level-selected")
	check(module.extra_pierce().count==1 and is_equal_approx(module.extra_pierce().damage_ratio,.95), "one extra target at level3 .95D")
	check(is_equal_approx(module.singularity_hold_add(),.12) and is_equal_approx(module.singularity_damage_multiplier(),1.1), "singularity modifier keeps separate hold and damage")
	check(is_equal_approx(module.laser_width_multiplier(),1.12) and is_equal_approx(module.charge_move_multiplier(),.7), "laser width and true charge movement queries")
	check(is_equal_approx(module.enemy_stagger_multiplier(),1.3), "ordinary enemy stagger scale")
	host.effects.erase(&"B03")
	check(is_equal_approx(module.modify_direct_damage(10,target,false,1),10), "unload barrel immediately removes scale")
	host.effects[&"P05"] = ItemCatalogV5.get_item(&"P05").parameters_for_level(1)
	check(is_equal_approx(module.modify_direct_damage(10,target,false,1),10), "low-health item inactive at full HP")
	var health := host.controller.actor_resources.health
	health.apply_damage(ActorResourceRequest.new(&"fixture_low_hp",health.epoch,3.0,health.get_instance_id()))
	check(is_equal_approx(module.modify_direct_damage(10,target,false,1),13.5), "low-health direct boost activates at2/5HP")
	check(is_equal_approx(module.modify_direct_damage(10,target,true,1),14.0), "low-health boost does not affect weapon active")

func next_shot_and_marks() -> void:
	await fresh([&"P04",&"P13",&"G01"])
	var target := enemy(Vector2(200,40))
	module.primary_packet_started(1,Vector2.RIGHT)
	module.on_hit(event(target,1))
	module.primary_packet_started(2,Vector2.RIGHT)
	check(is_equal_approx(module.modify_direct_damage(10,target,false,2),11.8), "air hit arms one next primary packet")
	host.effects.erase(&"P04")
	check(is_equal_approx(module.modify_direct_damage(10,target,false,2),10), "unload removes even an in-flight packet's next-hit multiplier")
	host.effects[&"P04"] = ItemCatalogV5.get_item(&"P04").parameters_for_level(1)
	var same := event(target,2)
	module.on_hit(same)
	module.on_hit(same)
	module.primary_packet_started(3,Vector2.RIGHT)
	check(is_equal_approx(module.modify_direct_damage(10,target,false,3),10), "boosted packet cannot re-arm its own benefit")
	check(is_equal_approx(target.health,99.35), "second different packet detonates exactly once, same packet repeat ignored")
	module.on_hook_hit(target,&"hook_fixture_1")
	var first := module.mark_key(target)
	check(not first.is_empty() and module.is_marked(target), "accepted hook gives actual expiring mark receipt")
	module.on_hook_hit(target,&"hook_fixture_1")
	check(module.mark_key(target)==first, "same hook receipt cannot renew mark or first companion hit")
	check(is_equal_approx(module.modify_direct_damage(10,target,false,3),12), "hook mark multiplies only primary direct damage")
	check(is_equal_approx(module.modify_direct_damage(10,target,true,3),10), "hook mark cannot multiply active damage")
	module.advance(5.1,5.1)
	check(not module.is_marked(target), "hook mark expires with world time")
	module.on_hook_hit(target,&"hook_fixture_2")
	check(module.mark_key(target)!=first, "new accepted hook creates a new first-hit receipt")
	module.map_entered(&"second-map")
	check(not module.is_marked(target), "map transition discards old target mark")

func chains_and_third_round() -> void:
	await fresh([&"P29"],3)
	var origin := enemy(Vector2(180,60))
	var near := enemy(Vector2(230,60))
	var second := enemy(Vector2(280,60))
	var blocked := enemy(Vector2(390,60))
	fixture.call("body",Rect2(330,0,12,180))
	await physics_frame
	var active := event(origin,1,false,true)
	active.item_active = true
	module.on_hit(active)
	check(is_equal_approx(near.health,99.55) and is_equal_approx(second.health,99.55), "generic active receipt produces two level3 .45D links")
	check(is_equal_approx(blocked.health,100), "chain cannot pass a real solid wall")
	module.on_hit(active)
	check(host.deals.size()==2, "same accepted active packet is idempotent and derived hits never recurse")
	host.effects.erase(&"P29")
	host.effects[&"G06"] = ItemCatalogV5.get_item(&"G06").parameters_for_level(1)
	host.clock = 2.0
	module.on_hit(event(origin,2,false))
	check(is_equal_approx(near.health,99.3) and is_equal_approx(second.health,99.3) and is_equal_approx(blocked.health,100), "gold crown links respect own target count and geometry")
	await fresh([&"P34"])
	origin = enemy(Vector2(180,60))
	near = enemy(Vector2(220,60))
	await physics_frame
	var first := event(origin,1,false,false,1)
	first.weapon_mode = WeaponDefinition.Mode.MACHINE
	module.on_hit(first)
	check(host.deals.is_empty(), "first real burst round cannot trigger third-round wave")
	var third := event(origin,1,false,false,3)
	third.weapon_mode = WeaponDefinition.Mode.MACHINE
	module.on_hit(third)
	module.on_hit(third)
	check(is_equal_approx(origin.health,99.7) and is_equal_approx(near.health,99.7), "third real burst round yields one .30D wave")

func dots_cloud_and_unload() -> void:
	await fresh([&"B24"])
	var target := enemy(Vector2(180,60))
	await physics_frame
	module.on_hit(event(target,1,false))
	module.advance(1.0,0.0)
	check(is_equal_approx(target.health,100), "zero world delta cannot tick or expire a burn")
	for i: int in 3: module.advance(1.0,1.0)
	check(is_equal_approx(target.health,99.65), "burn total stays .35D over its original3world seconds")
	module.advance(5.0,5.0)
	check(is_equal_approx(target.health,99.65), "expired burn cannot damage again")
	host.clock = 10.0
	module.on_hit(event(target,2,false))
	host.effects.erase(&"B24")
	module.sync()
	module.advance(2.0,2.0)
	check(is_equal_approx(target.health,99.65), "unload cancels outstanding source DOT")
	await fresh([&"P10"])
	target = enemy(Vector2(180,60))
	await physics_frame
	module.on_skill_started(&"actual_skill_fixture")
	module.on_hit(event(target,1,false))
	module.on_hit(event(target,2,false))
	for i: int in 3: module.advance(1.0,1.0)
	check(is_equal_approx(target.health,99.55), "one skill arms exactly one cloud, total .45D over3seconds")
	check(host.cues.size()==1, "same skill window has exactly one cloud presentation event")

func recoil_and_cooldown() -> void:
	await fresh([&"P12",&"B23",&"P31"],3)
	var target := enemy(Vector2(150,40))
	await physics_frame
	module.primary_packet_started(1,Vector2.LEFT)
	host.controller.shoot_ability.packet_id = 1
	module.on_hit(event(target,1,true))
	# Explicit accepted-Motor-blink notification fixture; actual swept movement
	# and wall clipping are separate original all-weapons integration cases.
	module.on_blink(Vector2(100,40),Vector2(180,40))
	module.advance(.01,.01)
	check(is_equal_approx(target.health,98.5), "actual-path fixture .25D, endpoint ring .4D and air recoil .85D are separate origins")
	module.advance(.01,.01)
	check(is_equal_approx(target.health,98.5), "ring and recoil receipt cannot double-apply")
	module.on_blink(Vector2(100,40),Vector2(180,40))
	module.advance(.01,.01)
	check(is_equal_approx(target.health,98.5), "per-target path and endpoint cooldown survive another burst")
	host.effects.erase(&"B23")
	module.sync()
	host.effects[&"B23"] = ItemCatalogV5.get_item(&"B23").parameters_for_level(1)
	module.on_blink(Vector2(100,40),Vector2(180,40))
	check(module._rings.is_empty(), "unload/reload cannot erase ring's owned cooldown")
	var old := event(target,2,true)
	host.controller.session_id += 1
	module.on_hit(old)
	check(module._pending_recoil_hits.is_empty(), "old actor session cannot create delayed recoil damage")

func explicit_synergies() -> void:
	await fresh([&"B19"])
	var target := enemy(Vector2(150,40))
	await physics_frame
	module.on_hook_hit(target,&"dream_hook_1")
	var first := module.dream_mark_key(target)
	check(not first.is_empty() and module.is_dream_marked(target), "S02 B19-only accepted hook creates independent4second dream mark")
	check(not module.is_marked(target) and module.mark_key(target).is_empty(), "B19 dream mark is never the P13/G08 first-hit mark")
	module.on_hook_hit(target,&"dream_hook_1")
	check(module.dream_mark_key(target)==first, "dream same-receipt replay cannot refresh first-lock identity")
	module.advance(0.0,0.0)
	check(module.is_dream_marked(target), "world-stop does not advance dream mark lifetime")
	module.advance(4.1,4.1)
	check(not module.is_dream_marked(target), "dream mark expires after its own4worldseconds")
	module.on_hook_hit(target,&"dream_hook_2")
	check(module.dream_mark_key(target)!=first, "new accepted hook receives a new dream identity")
	host.effects.erase(&"B19")
	module.sync()
	host.effects[&"B19"] = ItemCatalogV5.get_item(&"B19").parameters_for_level(1)
	check(not module.is_dream_marked(target), "unload/reload cannot restore a discarded dream mark")
	await fresh([&"P12",&"G01"])
	target = enemy(Vector2(150,40))
	await physics_frame
	module.primary_packet_started(1,Vector2.LEFT)
	host.controller.shoot_ability.packet_id = 1
	module.on_hit(event(target,1,true))
	module.on_blink(Vector2(100,40),Vector2(180,40))
	check(is_equal_approx(target.health,99.75), "S06 real-contact fixture cannot detonate mark from its own attack packet")
	host.controller.shoot_ability.packet_id = 2
	module.primary_packet_started(2,Vector2.LEFT)
	module.on_blink(Vector2(100,40),Vector2(180,40))
	check(is_equal_approx(target.health,99.75), "uncommitted contact during P12 target cooldown cannot detonate")
	host.clock = 2.1
	module.advance(2.1,2.1)
	module.on_blink(Vector2(100,40),Vector2(180,40))
	check(is_equal_approx(target.health,98.85), "S06 next-packet actual P12 commit consumes existing mark for.65D")
	check(module._echo_marks.is_empty(), "explicit synergy consumes mark without recursively creating another")
	module.on_hit(event(target,3,true))
	check(module._echo_marks.is_empty(), "S06 detonation shares the normal6second target cooldown")
	host.clock = 4.2
	module.advance(2.1,2.1)
	host.controller.shoot_ability.packet_id = 4
	module.primary_packet_started(4,Vector2.LEFT)
	module.on_blink(Vector2(100,40),Vector2(180,40))
	check(is_equal_approx(target.health,98.60), "P12 without a preexisting mark cannot synthesize echo damage")

func _run() -> void:
	await multipliers()
	await next_shot_and_marks()
	await chains_and_third_round()
	await dots_cloud_and_unload()
	await recoil_and_cooldown()
	await explicit_synergies()
	if fixture != null:
		var world: Node = fixture.get("world")
		if is_instance_valid(world): world.free()
	host = null
	module = null
	await process_frame
	print("ITEM V5 COMBAT: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)
