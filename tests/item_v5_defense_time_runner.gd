extends SceneTree
## Native gameplay-consumer regression. Fixtures initialize actor/targets and
## resource amounts explicitly; this is not a natural-route playtest recording.
var assertions := 0
var failures := 0
var fixture: RefCounted
var actor: PlayerController
var build: BuildState
var runtime: ItemRuntime
var life: DemoLifetime
var policy: FrameDamagePolicy
var stage: Node2D

class ClockProbe extends Node2D:
	var elapsed := 0.0
	func _physics_process(delta: float) -> void: elapsed += delta

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func fresh() -> void:
	paused = false
	Engine.time_scale = 1.0
	if runtime != null: runtime.clear()
	if fixture != null and is_instance_valid(fixture.get("world")): (fixture.get("world") as Node).free()
	fixture = preload("res://tests/combat_tests.gd").new()
	fixture.set("tree",self)
	await fixture.call("fixture",Vector2(80,20))
	actor = fixture.get("controller") as PlayerController
	life = DemoLifetime.new()
	build = BuildState.new()
	build.configure(actor,life,&"defense_time_test")
	runtime = ItemRuntime.new()
	runtime.configure(actor,build,life,RunWallet.new())
	stage = Node2D.new()
	(fixture.get("world") as Node).add_child(stage)
	runtime.bind_world(stage,&"map_one")
	policy = FrameDamagePolicy.new()
	policy.lifetime = life
	(fixture.get("world") as Node).add_child(policy)
	policy.set_physics_process(false)
	policy.register_player_controller(actor)
	check(policy.register_target(&"player",actor.actor_resources.health,true),"actual player HP registered in original policy")

func equip(wanted: Array[StringName]) -> bool:
	var ids: Array[StringName] = []
	for id: StringName in wanted:
		if build.inventory.instance_for_definition(id) == null:
			if not build.add_item(StringName("fixture/%s" % id),ItemCatalogV5.get_item(id)): return false
		ids.append(build.inventory.instance_for_definition(id).instance_id)
	paused = true
	var token := life.token()
	var session := build.equipment.open_session(token)
	var result := build.equipment.submit(ids,token,session,int(build.equipment.snapshot().revision))
	build.equipment.close_session()
	paused = false
	runtime.sync()
	return bool(result.accepted)

func request(id: StringName, amount: float, target: StringName = &"player", kind := DamageRequest.Kind.MONSTER, fall := false) -> DamageRequest:
	var health: HealthState = policy.get("_targets")[target].health
	var value := DamageRequest.new()
	value.token = life.token()
	value.actor_epoch = life.actor_epoch
	value.health_epoch = health.epoch
	value.event_id = id
	value.source_id = id
	value.target_id = target
	value.kind = kind
	value.amount = amount
	value.fall = fall
	return value

func hit(id: StringName, amount := 1.0, kind := DamageRequest.Kind.ENVIRONMENT, fall := false) -> Array[DamageResult]:
	check(policy.submit(request(id,amount,&"player",kind,fall)),"fresh actual player request accepts %s" % id)
	return policy.resolve_batch()

func enemy(id: StringName, location := Vector2(125,20), maximum := 100.0) -> Dictionary:
	var body: StaticBody2D = fixture.call("body",Rect2(location-Vector2(10,20),Vector2(20,40)),&"enemy")
	var receiver := body.get_node("Damageable") as Damageable
	receiver.actor_id = body.get_instance_id()
	var definition := HealthDefinition.new()
	definition.resource_id = id
	definition.max_health = maximum
	definition.initial_current = maximum
	var health := HealthState.new()
	health.configure(definition)
	receiver.bind_health(health)
	check(policy.bind_damageable(id,receiver,health),"real enemy damageable joins original policy %s" % id)
	return {"body":body,"receiver":receiver,"health":health}

func health_transactions() -> void:
	var definition := HealthDefinition.new()
	definition.resource_id = &"ratio_test"
	definition.max_health = 5
	definition.initial_current = 4
	var health := HealthState.new()
	check(health.configure(definition),"health fixture configures")
	var events := [0]
	health.changed.connect(func(_r: ActorResourceResult) -> void: events[0] += 1)
	var req := ActorResourceRequest.new(&"first_ratio",health.epoch,10,health.get_instance_id())
	check(health.set_max_preserving_ratio(req).accepted() and health.current == 8 and health.capacity == 10 and events[0] == 1,"P18 ratio changes max/current in one original resource transaction and one signal")
	check(health.set_max_preserving_ratio(req).status == ActorResourceResult.Status.REPLAY and health.current == 8 and events[0] == 1,"ratio receipt replay cannot scale twice")
	health.normal_healing_blocked = true
	check(not health.heal(ActorResourceRequest.new(&"ordinary_heal",health.epoch,2,health.get_instance_id())).accepted() and health.current == 8,"ordinary resource heal cannot bypass covenant")
	health.set_max(ActorResourceRequest.new(&"ordinary_max",health.epoch,5,health.get_instance_id()))
	check(health.current == 5 and health.capacity == 5,"ordinary max removal only clamps")
	health.normal_healing_blocked = false
	health.apply_damage(ActorResourceRequest.new(&"receipt_setup_hurt",health.epoch,1,health.get_instance_id()))
	var prior_heal := ActorResourceRequest.new(&"committed_before_covenant",health.epoch,1,health.get_instance_id())
	check(health.heal(prior_heal).status == ActorResourceResult.Status.APPLIED,"original ordinary heal produces its own receipt")
	health.normal_healing_blocked = true
	check(health.heal(prior_heal).status == ActorResourceResult.Status.REPLAY and health.current == 5,"covenant preserves harmless old receipt replay without a second heal")
	health.apply_damage(ActorResourceRequest.new(&"fatal",health.epoch,5,health.get_instance_id()))
	check(not health.set_max_preserving_ratio(ActorResourceRequest.new(&"late_ratio",health.epoch,10,health.get_instance_id())).accepted() and health.terminal,"ratio cannot resurrect terminal actor")

func pending_damage_query() -> void:
	await fresh()
	var registered := actor.get_meta(&"frame_damage_policy") as WeakRef
	check(registered != null and registered.get_ref() == policy and not policy.has_pending_player_damage(),"policy registers a weak query bridge without a pending hit")
	check(policy.submit(request(&"pending_menu_hit",1)) and policy.has_pending_player_damage(),"same-frame queued player damage is visible before a menu can transact")
	policy.resolve_batch()
	check(not policy.has_pending_player_damage(),"resolved player damage no longer blocks transactions")
	policy.clock += 2
	check(policy.submit(request(&"stale_menu_hit",1)),"fresh actor damage can queue for the stale-query counterexample")
	life.invalidate_actor()
	check(not policy.has_pending_player_damage() and policy.resolve_batch().is_empty(),"actor epoch invalidation makes the queued hit ineligible without querying it away")

func barriers_and_map_receipts() -> void:
	await fresh()
	check(equip([&"B13",&"B32",&"G02",&"N02"]),"eight-load defense combination equips through original session")
	check(runtime.barrier_count() == 0,"mid-map equip gives no entry shield")
	actor.router.has_application_focus = false
	runtime.bind_world(stage,&"map_two")
	check(runtime.barrier_count() == 0,"unfocused map load defers entry grants")
	actor.router.has_application_focus = true
	runtime.advance(.01,.01)
	check(runtime.barrier_count() == 3,"one plus two entry shields use unique shared cap")
	actor.combat_energy.grant("fixture_energy",100)
	runtime.select_active(&"N02")
	check(not runtime.activate_selected(Vector2.RIGHT).accepted and actor.combat_energy.current == 100,"full shield rejects active before energy spend")
	var before := actor.actor_resources.health.current
	var batch := hit(&"shield_hit",1,DamageRequest.Kind.MONSTER)
	check(batch.size() == 1 and batch[0].hp_lost == 0 and batch[0].barrier_absorbed == 1 and actor.actor_resources.health.current == before and runtime.barrier_count() == 2,"shield absorbs chosen enemy damage without HP loss")
	check(int(runtime.state(&"G02").get("hp_hits",0)) == 0,"shield absorption never counts as true HP injury")
	batch = hit(&"fall_bypasses",1,DamageRequest.Kind.ENVIRONMENT,true)
	check(batch.size() == 1 and batch[0].hp_lost == 1 and runtime.barrier_count() == 2,"explicit fall bypasses shields")
	check(equip([]) and runtime.barrier_count() == 0,"unloading sources removes outstanding shield effect")
	check(equip([&"B13",&"B32"]) and runtime.barrier_count() == 0,"re-equipping cannot restore removed shield")
	runtime.bind_world(stage,&"map_two")
	check(runtime.barrier_count() == 0,"same map entry cannot reroll shield")
	runtime.bind_world(stage,&"map_three")
	check(runtime.barrier_count() == 3,"new distinct map grants once when already equipped")

func heart_covenant_and_healing() -> void:
	await fresh()
	check(equip([&"G03"]),"new-map healing item equips")
	hit(&"initial_hurt",2)
	runtime.bind_world(stage,&"map_two")
	check(actor.actor_resources.health.current == 4,"G03 heals one on first new map")
	runtime.bind_world(stage,&"map_one")
	check(actor.actor_resources.health.current == 4,"returning to previously visited map does not heal")
	check(equip([&"G03",&"P18",&"P27"]),"covenant/needle fit eight capacity")
	check(actor.actor_resources.health.capacity == 10 and actor.actor_resources.health.current == 8,"real first covenant equip preserves current HP ratio once")
	check(not equip([&"G03",&"P27"]),"covenant cannot be unequipped through normal atomic session")
	hit(&"covenant_hurt",2)
	actor.combat_energy.grant("needle_fixture",100)
	runtime.select_active(&"P27")
	check(not runtime.activate_selected(Vector2.RIGHT).accepted and actor.combat_energy.current == 100,"needle rejects banned healing without charging")
	runtime.bind_world(stage,&"map_three")
	check(actor.actor_resources.health.current == 6,"map healing also respects covenant gate")
	check(not actor.actor_resources.health.heal(ActorResourceRequest.new(&"pickup_fixture",actor.actor_resources.health.epoch,1,actor.actor_resources.health.get_instance_id())).accepted(),"ordinary pickup resource API also rejects covenant healing")

func rescue_and_real_active_time() -> void:
	await fresh()
	check(equip([&"G04",&"P02",&"B33"]),"passive rescue plus active reducer and a real eligible active fit")
	actor.combat_energy.grant("rescue_energy",100)
	var batch := hit(&"rescue",99,DamageRequest.Kind.MONSTER)
	check(batch.size() == 1 and batch[0].rescued and actor.actor_resources.health.current == 1 and actor.combat_energy.current == 35,"passive rescue keeps one HP and pays raw65, excluding active discount")
	policy.clock += 2
	hit(&"second_lethal",99,DamageRequest.Kind.MONSTER)
	check(actor.actor_resources.health.terminal and not life.active,"second lethal hit on same map ends run")
	await fresh()
	check(equip([&"G04"]),"rescue fixture equips")
	actor.combat_energy.grant("fall_energy",100)
	hit(&"fatal_fall",99,DamageRequest.Kind.ENVIRONMENT,true)
	check(actor.actor_resources.health.terminal and actor.combat_energy.current == 100,"fall cannot spend rescue or stop death")
	await fresh()
	check(equip([&"P26"]),"curtain equips")
	actor.combat_energy.grant("curtain_energy",100)
	runtime.select_active(&"P26")
	check(runtime.activate_selected(Vector2.RIGHT).accepted and actor.combat_energy.current == 20,"curtain pays80 once")
	batch = hit(&"curtain_first",2,DamageRequest.Kind.MONSTER)
	check(batch[0].blocked and batch[0].hp_lost == 0,"curtain blocks HP damage")
	runtime.advance(2.9,.435)
	batch = hit(&"curtain_before_three",2,DamageRequest.Kind.MONSTER)
	check(batch[0].blocked and actor.actor_resources.health.current == 5,"real-active2.9 seconds remains protected despite slow world")
	paused = true
	runtime.advance(100,100)
	paused = false
	check(is_equal_approx(runtime.now(),2.9),"menu pause does not advance active clock")
	runtime.advance(.2,.03)
	batch = hit(&"curtain_after_three",1,DamageRequest.Kind.MONSTER)
	check(batch[0].hp_lost == 1 and actor.actor_resources.health.current == 4,"curtain expires by real active time and does not extend an iframe on blocked hits")
	check(not runtime.activate_selected(Vector2.RIGHT).accepted and actor.combat_energy.current == 20,"curtain cooldown replay cannot spend again")

func breakage_and_one_bell() -> void:
	await fresh()
	check(equip([&"B17",&"B14",&"B30"]),"eight load breakable combination equips")
	var bells := [0]
	runtime.effect_cued.connect(func(kind: StringName,_point: Vector2,_detail: Dictionary) -> void:
		if kind == &"synergy_bell": bells[0] += 1)
	for i: int in 3: hit(StringName("break_first_%s" % i),1)
	check(bool(runtime.state(&"B17").get("broken",false)) and bool(runtime.state(&"B30").get("broken",false)),"third true HP injury breaks both owned sources")
	check(build.equipment.snapshot().used == 8 and actor.actor_resources.health.capacity == 5,"broken equipment retains load and removes maxHP without healing")
	check(actor.combat_energy.current == 36 and bells[0] == 1,"S15 adds one bell and no invented extra combat energy")
	actor.actor_resources.health.heal(ActorResourceRequest.new(&"fixture_repair_heal",actor.actor_resources.health.epoch,5,actor.actor_resources.health.get_instance_id()))
	# Explicit fixture repair patch: the wallet/merchant transaction is covered by
	# the economy runner, while this tests that repair does not erase S15 history.
	runtime.patch_state(&"B17",{"broken":false,"damage_hits":0},&"fixture_repair")
	for i: int in 3: hit(StringName("break_again_%s" % i),1)
	check(bool(runtime.state(&"B17").get("broken",false)) and bells[0] == 1 and actor.combat_energy.current == 72,"repair retains one-bell lifetime receipt and normal B14 gains")

func authenticated_effect_batches() -> void:
	await fresh()
	check(equip([&"B15",&"G01"]),"two distinct real effect origins equip")
	var target := enemy(&"batch_enemy",Vector2(125,20),20)
	check(policy.submit(request(&"legacy_one",1,&"batch_enemy")) and policy.submit(request(&"legacy_two",2,&"batch_enemy")),"legacy candidates join same frame")
	check(runtime.deal(target.receiver,.5,&"effect_a",&"B15") and runtime.deal(target.receiver,.75,&"effect_b",&"G01"),"two root-minted effects join same frame")
	check(not runtime.deal(target.receiver,.5,&"effect_a",&"B15"),"same minted event cannot enqueue twice")
	var forged := request(&"forged_effect",5,&"batch_enemy")
	forged.item_effect_damage = true
	check(not policy.submit(forged),"a public item flag cannot forge private policy admission")
	var batch := policy.resolve_batch()
	check(batch.size() == 3 and is_equal_approx((target.health as HealthState).current,16.75),"legacy keeps max-only winner while authenticated distinct effects add")
	await fresh()
	check(equip([&"B15"]),"fatal ordering origin equips")
	target = enemy(&"fatal_enemy",Vector2(125,20),10)
	check(runtime.deal(target.receiver,1,&"pending_after_fatal",&"B15"),"pending effect has valid mint before frame resolution")
	hit(&"player_dies_first",5,DamageRequest.Kind.ENVIRONMENT,true)
	check(actor.actor_resources.health.terminal and (target.health as HealthState).current == 10,"player primary death suppresses new derived HP and callbacks")

func guard_synergy_geometry() -> void:
	await fresh()
	check(equip([&"B13",&"P16"]),"morning shield and orbit guard equip")
	runtime.bind_world(stage,&"guard_map")
	var projectile := BossProjectile.new()
	projectile.visible = false
	projectile.radius = 4
	stage.add_child(projectile)
	projectile.set_physics_process(false)
	projectile.global_position = actor.motor.global_position+Vector2(60,0)
	runtime.advance(.01,0)
	check(projectile.spent and is_equal_approx(float(runtime.state(&"P16").ready_at)-runtime.now(),10.8),"S09 real projectile interception uses12*.9 cooldown")
	var defense: RefCounted = runtime.get("_defense")
	var glyph := defense.get("_glyph") as Node2D
	check(glyph.scale.x > 1 and float(glyph.get("radius")) == 12 and runtime.barrier_count() == 1,"S09 enlarges appearance only, keeping collision body and shield amount")
	check(equip([&"P16"]),"removing morning shield leaves guard")
	runtime.advance(11,0)
	var blocked := BossProjectile.new()
	blocked.visible = false
	blocked.radius = 4
	blocked.set_meta(&"unblockable",true)
	stage.add_child(blocked)
	blocked.set_physics_process(false)
	blocked.global_position = actor.motor.global_position+Vector2(60,0)
	runtime.advance(.01,0)
	check(not blocked.spent,"explicit unblockable projectile bypasses orbit interceptor")
	blocked.set_meta(&"unblockable",false)
	blocked.event_id = &"windblade_fixture"
	runtime.advance(.01,0)
	check(not blocked.spent,"current invisible Boss attack proxy is not an interceptable bullet")
	blocked.event_id = &"ordinary_bell_fixture"
	runtime.advance(.01,0)
	check(blocked.spent and is_equal_approx(float(runtime.state(&"P16").ready_at)-runtime.now(),12),"ordinary interceptor restores original12 seconds without morning shield")

func world_time_scope() -> void:
	await fresh()
	check(equip([&"P06"]),"full-health world stop equips")
	var probe := ClockProbe.new()
	probe.process_mode = Node.PROCESS_MODE_ALWAYS
	stage.add_child(probe)
	var timer := Timer.new()
	timer.wait_time = 10
	timer.one_shot = true
	probe.add_child(timer)
	timer.start()
	var platform := StaticBody2D.new()
	platform.constant_linear_velocity = Vector2(7,0)
	stage.add_child(platform)
	var rigid := RigidBody2D.new()
	rigid.freeze = false
	rigid.gravity_scale = 0
	stage.add_child(rigid)
	rigid.linear_velocity = Vector2(30,0)
	await physics_frame
	var before_clock := probe.elapsed
	var before_timer := timer.time_left
	actor.air_focus_ability.advance(.01,false,true,true)
	check(runtime.world_is_frozen() and Engine.time_scale > 0 and probe.process_mode == Node.PROCESS_MODE_DISABLED,"P06 stops even explicit ALWAYS world nodes while keeping positive engine time")
	check(platform.constant_linear_velocity == Vector2.ZERO and rigid.freeze,"world stop clears moving-platform carry and freezes autonomous rigid bodies")
	var actor_before := actor.motor.global_position
	actor.router.set_move_axis(1)
	for i: int in 3:
		await physics_frame
		actor.physics_tick(1.0/60.0)
	check(probe.elapsed == before_clock and is_equal_approx(timer.time_left,before_timer),"world node clock and child timer remain frozen")
	check(actor.motor.global_position.x > actor_before.x,"the unique real player Motor keeps moving in stopped world")
	actor.air_focus_ability.stop()
	check(not runtime.world_is_frozen() and probe.process_mode == Node.PROCESS_MODE_ALWAYS and platform.constant_linear_velocity == Vector2(7,0) and not rigid.freeze,"stop restores exact world process and physics flags")
	await physics_frame
	await physics_frame
	check(probe.elapsed > before_clock and timer.time_left < before_timer,"world timers resume after release")
	check(equip([&"N01"]),"pendulum replaces full stop")
	actor.air_focus_ability.advance(.01,false,true,true)
	check(is_equal_approx(Engine.time_scale,.12) and not runtime.world_is_frozen(),"N01 level one refines ordinary world slowdown")
	actor.air_focus_ability.stop()
	check(build.add_item(&"pendulum_level_two",ItemCatalogV5.get_item(&"N01")),"same item upgrades through real ownership receipt")
	runtime.sync()
	actor.air_focus_ability.advance(.01,false,true,true)
	check(is_equal_approx(Engine.time_scale,.10),"pendulum level two selects direct level value")
	actor.air_focus_ability.stop()
	check(equip([&"P06",&"N01"]),"full stop and pendulum may coexist")
	actor.air_focus_ability.advance(.01,false,true,true)
	check(runtime.world_is_frozen() and Engine.time_scale == 1,"full health P06 wins over pendulum")
	paused = true
	runtime.advance(1,1)
	check(not runtime.world_is_frozen() and probe.process_mode == Node.PROCESS_MODE_ALWAYS,"pause releases frozen nodes instead of leaving stale modes")
	paused = false
	actor.air_focus_ability.stop()

func air_refund_committed_pipeline() -> void:
	await fresh()
	check(equip([&"B06"]),"air refund source equips")
	var target := enemy(&"refund_enemy")
	actor.air_focus_ability.stamina_state.consume_continuous(50,actor.air_focus_ability.stamina_state.epoch)
	for i: int in 3:
		actor.shoot_ability.cooldown_remaining = 0
		# Explicit resource initialization for repeated packet-boundary tests.
		actor.action_resources.shot_charges = 1
		check(actor.shoot_ability.try_fire(Vector2.RIGHT,false),"real primary weapon accepts refund test packet %s" % i)
		var bullet: PlayerProjectile = actor.shoot_ability.get_projectiles().back()
		bullet.set_physics_process(false)
		bullet.advance(.08)
		policy.resolve_batch()
	check((target.health as HealthState).current < 100 and is_equal_approx(actor.air_focus_ability.stamina,70),"only committed primary hits refund time energy and stop at per-air20 cap")
	check(is_equal_approx(actor.air_focus_ability.air_time_used,0),"refund never extends or resets AirFocus airtime accounting")
	var before := actor.air_focus_ability.stamina
	check(equip([]) and equip([&"B06"]),"refund item can be freely swapped")
	actor.shoot_ability.cooldown_remaining = 0
	actor.action_resources.shot_charges = 1
	check(actor.shoot_ability.try_fire(Vector2.RIGHT,false),"packet after re-equip still fires")
	var bullet: PlayerProjectile = actor.shoot_ability.get_projectiles().back()
	bullet.set_physics_process(false)
	bullet.advance(.08)
	policy.resolve_batch()
	check(actor.air_focus_ability.stamina == before,"re-equipping during same flight cannot reset refund cap")

func player_protection_real_clock() -> void:
	await fresh()
	check(equip([&"P06",&"B13",&"B27"]),"full-health freeze, entry barrier and iframe extension fit")
	runtime.bind_world(stage,&"clock_shield_map")
	check(runtime.barrier_count() == 1,"actual new-map entry funds one shield for frozen player-clock test")
	actor.air_focus_ability.advance(.01,false,true,true)
	check(runtime.world_is_frozen(),"full HP enters real freeze before shield absorption")
	var world_before := policy.clock
	var player_before := policy.player_clock()
	var batch := hit(&"freeze_shield_hit",1,DamageRequest.Kind.MONSTER)
	check(batch.size() == 1 and batch[0].barrier_absorbed == 1 and actor.actor_resources.health.current == 5,"shield consumes the first frozen-world real monster hit without losing full HP")
	check(is_equal_approx(policy._monster_until-player_before,.73),"B27 adds .08 to original .65 monster protection")
	policy._physics_process(.74)
	check(policy.clock == world_before and is_equal_approx(policy.player_clock()-player_before,.74),"frozen-world cadence stops while player protection expires in real activity time")
	batch = hit(&"freeze_after_real_iframe",1,DamageRequest.Kind.MONSTER)
	check(batch.size() == 1 and batch[0].hp_lost == 1,"a fresh monster contact damages after real iframe expiry despite unchanged world clock")
	actor.air_focus_ability.stop()
	check(is_equal_approx(runtime.monster_iframe(.98),1) and is_equal_approx(runtime.monster_iframe(1.2),1.2),"B27 respects configured total cap without shortening an already-longer base")
	check(equip([]) and is_equal_approx(runtime.monster_iframe(.65),.65),"unequipping B27 completely removes its iframe extension")

func healing_and_barrier_success() -> void:
	await fresh()
	check(equip([&"P27",&"N02"]),"both independent healing and shield actives equip")
	hit(&"needle_start_hp",3)
	actor.combat_energy.grant("needle_one_energy",100)
	runtime.select_active(&"P27")
	check(runtime.activate_selected(Vector2.RIGHT).accepted and actor.actor_resources.health.current == 3 and actor.combat_energy.current == 35,"P27 actual successful active pays65 and heals exactly one HP")
	actor.combat_energy.grant("needle_two_energy",100)
	check(runtime.activate_selected(Vector2.RIGHT).accepted and actor.actor_resources.health.current == 4 and actor.combat_energy.current == 35,"P27 second paid use heals exactly one HP")
	actor.combat_energy.grant("needle_third_energy",100)
	check(not runtime.activate_selected(Vector2.RIGHT).accepted and actor.actor_resources.health.current == 4 and actor.combat_energy.current == 100,"P27 third same-map use rejects atomically even while HP is missing")
	check(equip([]) and equip([&"P27",&"N02"]),"active items can be freely removed and re-equipped")
	runtime.select_active(&"P27")
	check(not runtime.activate_selected(Vector2.RIGHT).accepted and actor.combat_energy.current == 100,"P27 owned per-map use budget survives an equipment swap")
	runtime.bind_world(stage,&"needle_second_map")
	check(runtime.activate_selected(Vector2.RIGHT).accepted and actor.actor_resources.health.current == 5 and actor.combat_energy.current == 35,"P27 new-map budget admits another paid heal")
	actor.combat_energy.grant("shield_active_energy",100)
	runtime.select_active(&"N02")
	check(runtime.activate_selected(Vector2.RIGHT).accepted and runtime.barrier_count() == 2 and actor.combat_energy.current == 50,"N02 successful actual active pays50 and grants two shared shields")
	check(not runtime.activate_selected(Vector2.RIGHT).accepted and runtime.barrier_count() == 2 and actor.combat_energy.current == 50,"N02 second same-map activation preserves energy and shared shield count")
	check(equip([]) and equip([&"P27",&"N02"]),"N02 shield removal follows source ownership while state survives")
	runtime.select_active(&"N02")
	check(runtime.barrier_count() == 0 and not runtime.activate_selected(Vector2.RIGHT).accepted and actor.combat_energy.current == 50,"N02 unequip cannot refresh its spent per-map activation")
	runtime.bind_world(stage,&"needle_third_map")
	check(runtime.activate_selected(Vector2.RIGHT).accepted and actor.combat_energy.current == 0 and runtime.barrier_count() == 2,"N02 distinct new map admits one new paid activation")
	runtime.bind_world(stage,&"needle_fourth_map")
	check(not runtime.activate_selected(Vector2.RIGHT).accepted and actor.combat_energy.current == 0 and runtime.barrier_count() == 2,"insufficient resonance cannot partially grant a shield")
	await fresh()
	check(equip([&"G02"]),"three-HP-hit shield item equips")
	for index: int in 3: hit(StringName("three_real_hp/%s" % index),1)
	check(actor.actor_resources.health.current == 2 and runtime.barrier_count() == 1 and int(runtime.state(&"G02").hp_hits) == 3,"G02 counts exactly three actual nonfatal HP injuries then grants one shared shield")
	policy.clock += 2
	var batch := hit(&"G02_shield_not_hp",1,DamageRequest.Kind.MONSTER)
	check(batch.size() == 1 and batch[0].hp_lost == 0 and int(runtime.state(&"G02").hp_hits) == 3,"G02 shield absorption is excluded from its HP-hit counter")
	runtime.bind_world(stage,&"three_hit_map_two")
	check(int(runtime.state(&"G02").hp_hits) == 3,"G02 real injury history persists across a map transition")

func retaliation_and_crystal_contacts() -> void:
	await fresh()
	check(equip([&"B15",&"P20"]),"real retaliation and stationary crystal sources equip")
	var target := enemy(&"retaliation_target",Vector2(125,20))
	# Match formal enemy hurtbox collision layer, avoiding a fake terrain LOS blocker.
	(target.body as StaticBody2D).collision_layer = 2
	# Observe real physics-server admission before the radius/LOS burst query.
	await physics_frame
	var health := target.health as HealthState
	var player_position := actor.motor.global_position
	var damage := runtime.base_damage()
	var energy_before := actor.combat_energy.current
	hit(&"real_injury_spawns_crystal",1)
	check(is_equal_approx(float(runtime.state(&"B15").ready_at)-runtime.now(),7) and is_equal_approx(float(runtime.state(&"P20").ready_at)-runtime.now(),12),"actual HP injury starts table B15 seven-second and P20 twelve-second cooldowns")
	policy.resolve_batch()
	check(is_equal_approx(100-health.current,damage*.65),"B15 actual injury dispatches one authenticated .65D counterburst to a nearby enemy")
	check(actor.combat_energy.current == energy_before,"B15 derived injury counterburst never grants primary resonance")
	var crystal_rows: Array = runtime._defense._crystals
	check(crystal_rows.size() == 1 and (crystal_rows[0].node as Node2D).global_position.is_equal_approx(player_position),"P20 injury creates exactly one real crystal at the original position without teleporting the player")
	check(actor.motor.global_position.is_equal_approx(player_position),"P20 trigger leaves actual player transform unchanged")
	var crystal_health := health.current
	# Explicit enemy-position setup puts a real collider inside the crystal;
	# effect damage still requires world shape/LOS query and frame policy.
	(target.body as Node2D).global_position = player_position+Vector2(8,0)
	await physics_frame
	runtime.advance(.016,.016)
	policy.resolve_batch()
	check(is_equal_approx(crystal_health-health.current,damage*.6),"P20 actual stationary crystal contact commits the configured .60D HP damage")
	var after_crystal := health.current
	runtime.advance(.016,.016)
	policy.resolve_batch()
	check(health.current == after_crystal and actor.combat_energy.current == energy_before,"same crystal/target cannot repeat damage or generate resonance")
	hit(&"injury_during_both_cooldowns",1)
	policy.resolve_batch()
	check(health.current == after_crystal and runtime._defense._crystals.size() == 1,"another actual injury during cooldown cannot duplicate either defensive effect")
	runtime.advance(5.1,5.1)
	check(runtime._defense._crystals.is_empty(),"real crystal expires after its five world-second lifetime")

func frozen_seed_preserves_safe_square() -> void:
	await fresh()
	var sentry := preload("res://game/enemies/scenes/patrol_drone.tscn").instantiate() as EnemyMotor
	(fixture.get("world") as Node).add_child(sentry)
	var enemy_actor := sentry.get_node("Actor") as EnemyActor
	enemy_actor.set_physics_process(false)
	var behavior := EnemyAttackBehavior.new()
	sentry.add_child(behavior)
	var safe := Vector2(200,-200)
	behavior.configure(enemy_actor,actor,policy,life,&"protected_corner_fixture",[safe])
	var radius := enemy_actor.definition.protected_radius
	check(radius > 0 and behavior._active(),"real enemy behavior supplies its original safe-region radius and live ownership guards")
	var corner := safe+Vector2.ONE*radius*.9
	check(corner.distance_to(safe) > radius and DemoContactEmitter.segment_intersects_bounds(corner,corner,Rect2(safe-Vector2.ONE*radius,Vector2.ONE*radius*2)),"actual safe-region corner lies outside a circle but inside the pre-existing square predicate")
	var moving := EnemyAttackProjectile.new()
	moving.configure(behavior,&"safe_corner_moving",Vector2.RIGHT)
	(fixture.get("world") as Node).add_child(moving)
	moving.global_position = corner
	moving.set_physics_process(false)
	moving._physics_process(.001)
	check(moving.spent,"ordinary seed disposes at the original protected-square corner")
	var stopped := EnemyAttackProjectile.new()
	stopped.configure(behavior,&"safe_corner_stopped",Vector2.RIGHT)
	(fixture.get("world") as Node).add_child(stopped)
	stopped.global_position = corner
	stopped.set_physics_process(false)
	var remaining := stopped.remaining
	var age := stopped._visual_age
	stopped.advance_frozen_contact()
	check(stopped.spent,"frozen seed preserves the same original square protected-region disposal at a corner")
	check(stopped.global_position == corner and stopped.remaining == remaining and stopped._visual_age == age,"protected stationary disposal advances neither motion nor lifetime nor visual age")

func _run() -> void:
	root.size = Vector2i(1280,720)
	health_transactions()
	await pending_damage_query()
	await barriers_and_map_receipts()
	await heart_covenant_and_healing()
	await rescue_and_real_active_time()
	await breakage_and_one_bell()
	await authenticated_effect_batches()
	await guard_synergy_geometry()
	await world_time_scope()
	await air_refund_committed_pipeline()
	await player_protection_real_clock()
	await healing_and_barrier_success()
	await retaliation_and_crystal_contacts()
	await frozen_seed_preserves_safe_square()
	paused = false
	Engine.time_scale = 1
	if runtime != null: runtime.clear()
	if fixture != null and is_instance_valid(fixture.get("world")): (fixture.get("world") as Node).free()
	fixture = null
	actor = null
	build = null
	runtime = null
	policy = null
	stage = null
	await process_frame
	print("ITEM V5 DEFENSE TIME: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)
