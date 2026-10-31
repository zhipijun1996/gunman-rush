extends SceneTree
## Independent bounded adversarial review. Uses real ItemRuntime, catalog,
## equipment, physical target lookup and FrameDamagePolicy; no host replacement.
## Explicit fixture placement/resources are not a natural-route playtest.
var assertions := 0
var failures := 0
var fixture: RefCounted
var actor: PlayerController
var build: BuildState
var runtime: ItemRuntime
var life: DemoLifetime
var policy: FrameDamagePolicy
var stage: Node2D
var observations: Array[Dictionary] = []
var pre_fix := false
var source_lifetime_only := false

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
	build.configure(actor,life,&"independent_item_v5_review")
	runtime = ItemRuntime.new()
	runtime.configure(actor,build,life,RunWallet.new())
	if pre_fix:
		var old_active: GDScript = load("res://build/item_v5/review/item_active_effects_before_review.gd")
		var old_module: RefCounted = old_active.new()
		old_module.call("configure",runtime)
		runtime.set("_actives",old_module)
	stage = Node2D.new()
	(fixture.get("world") as Node).add_child(stage)
	runtime.bind_world(stage,&"review/map_one")
	policy = FrameDamagePolicy.new()
	policy.lifetime = life
	(fixture.get("world") as Node).add_child(policy)
	policy.set_physics_process(false)
	policy.register_player_controller(actor)
	check(policy.register_target(&"player",actor.actor_resources.health,true),"actual policy registers real player")

func equip(ids: Array[StringName]) -> bool:
	var owned_ids: Array[StringName] = []
	for id: StringName in ids:
		if not build.add_item(StringName("review/%s" % id),ItemCatalogV5.get_item(id)): return false
		owned_ids.append(build.inventory.instance_for_definition(id).instance_id)
	var ok := preload("res://tests/gear_inventory_support.gd").equip_ids(build,owned_ids)
	runtime.sync()
	return ok

func enemy(id: StringName, point: Vector2) -> Dictionary:
	var body: StaticBody2D = fixture.call("body",Rect2(point-Vector2(10,20),Vector2(20,40)),&"enemy")
	body.collision_layer = 2
	var receiver := body.get_node("Damageable") as Damageable
	receiver.actor_id = body.get_instance_id()
	var definition := HealthDefinition.new()
	definition.resource_id = id
	definition.max_health = 100
	definition.initial_current = 100
	var health := HealthState.new()
	health.configure(definition)
	receiver.bind_health(health)
	check(policy.bind_damageable(id,receiver,health),"physical target bound to original policy " + String(id))
	return {"body":body,"receiver":receiver,"health":health}

func g14_real_runtime_chain() -> void:
	await fresh()
	check(equip([&"G14"]),"G14 equips through real paused transaction")
	var first := enemy(&"g14_first",Vector2(150,20))
	var second := enemy(&"g14_second",Vector2(210,20))
	var third := enemy(&"g14_third",Vector2(270,20))
	await physics_frame
	check(runtime.targets(Vector2(150,20),200).size() == 3,"real broadphase sees all three unobstructed targets")
	check(runtime.clear_line(Vector2(150,20),Vector2(210,20)) and runtime.clear_line(Vector2(210,20),Vector2(270,20)),"actual LOS allows the two chain links")
	actor.combat_energy.grant("review/g14/fill",100)
	check(runtime.select_active(&"G14"),"formal active selection accepts G14")
	var result := runtime.activate_selected(Vector2.RIGHT)
	check(bool(result.get("accepted",false)) and actor.combat_energy.current == 55,"real activation spends exactly forty-five energy")
	for _step: int in 12:
		runtime.advance(0.05,0.05)
		policy.resolve_batch()
	observations.append({"case":"G14 physical cast through real ItemRuntime","first_hp":first.health.current,"second_hp":second.health.current,"third_hp":third.health.current,"energy":actor.combat_energy.current,"damage_D":runtime.base_damage(),"has_G14_chain":runtime.has(&"G14_chain")})
	check(is_equal_approx(first.health.current,98.7),"G14 primary actual HP loses 1.30D")
	check(is_equal_approx(second.health.current,99.65) and is_equal_approx(third.health.current,99.65),"G14 both extra targets actually lose promised 0.35D")
	check(actor.combat_energy.current == 55,"active and secondary chain never refund combat energy")

func s13_opposite_trajectories() -> void:
	await fresh()
	check(equip([&"P24",&"G15"]),"S13 actual two-item loadout equips")
	actor.combat_energy.grant("review/s13/fill",100)
	runtime.select_active(&"P24")
	check(bool(runtime.activate_selected(Vector2.RIGHT).get("accepted",false)),"S13 actual flywheel cast accepts")
	var module: RefCounted = runtime.get("_actives")
	var entities: Array = module.get("_entities")
	check(entities.size() == 2,"S13 real cast creates exactly two flywheels")
	if entities.size() != 2: return
	var left: Vector2 = entities[0].direction
	var right: Vector2 = entities[1].direction
	observations.append({"case":"S13 actual entity direction vectors","direction_a":[left.x,left.y],"direction_b":[right.x,right.y],"dot":left.dot(right)})
	check(left.dot(right) < -0.999999,"S13 workbook opposite trajectories have opposite direction vectors")

func targets_equal_distance_id_order() -> void:
	await fresh()
	for index: int in 5:
		enemy(StringName("tie_target_%s" % index),Vector2(350,20))
	await physics_frame
	var rows := runtime.targets(Vector2(350,20),50)
	var actual: Array[int] = []
	for row: Dictionary in rows: actual.append((row.receiver as Damageable).get_instance_id())
	var expected := actual.duplicate()
	expected.sort()
	observations.append({"case":"actual ItemRuntime targets equal-distance order","ids":actual,"ascending_ids":expected})
	check(actual.size() == 5 and actual == expected,"real targets break equal-distance ties by stable receiver ID")

func pending_lethal_equipment() -> void:
	await fresh()
	check(equip([&"B03"]),"pending-damage equipment fixture owns a real equipped item")
	paused = true
	var token := life.token()
	var session := build.equipment.open_session(token)
	check(session > 0,"healthy paused actor first opens legitimate equipment session")
	var hp := actor.actor_resources.health.current
	var request: Variant = load("res://scripts/damage/damage_request.gd").new()
	request.token = token
	request.actor_epoch = life.actor_epoch
	request.health_epoch = actor.actor_resources.health.epoch
	request.target_id = &"player"
	request.source_id = &"review/lethal"
	request.event_id = &"review/lethal/equipment"
	request.amount = hp
	check(policy.submit(request) and policy.has_pending_player_damage() and actor.has_pending_damage(),"real policy holds an accepted lethal request before any HP commit")
	check(actor.actor_resources.health.current == hp,"pending guard does not fake early health settlement")
	var proposed: Array[StringName] = []
	check(not build.equipment.submit(proposed,token,session,int(build.equipment.snapshot().revision)).accepted,"already-open equipment session refuses transaction after lethal request queues")
	check(build.equipment.open_session(token) == 0,"new paused equipment session refuses pending lethal request")
	check(build.equipment.equipped_ids().size() == 1 and actor.actor_resources.health.current == hp,"refused pending transaction changes neither loadout nor HP")
	paused = false
	var committed := policy.resolve_batch()
	check(committed.size() == 1 and committed[0].lethal and actor.actor_resources.health.terminal and not life.active,"original damage policy commits actual fatal HP and run invalidation")
	observations.append({"case":"real pending lethal blocks paused equipment","session_before":session,"hp_before":hp,"hp_after_commit":actor.actor_resources.health.current,"fatal_results":committed.size()})

func source_revocation_before_derived_commit() -> void:
	await fresh()
	check(equip([&"P09"]),"normal derived control source equips via real session")
	var control := enemy(&"source_control",Vector2(150,20))
	check(runtime.deal(control.receiver,1.0,&"source_control",&"P09"),"equipped source creates authenticated derived request")
	check(control.health.current == 100,"derived control is queued, not immediately committed")
	var control_results := policy.resolve_batch()
	check(control_results.size() == 1 and control.health.current == 99,"still-equipped source commits actual derived HP through original policy")
	await fresh()
	check(equip([&"P09"]),"revocation fixture source equips through real session")
	var revoked := enemy(&"source_revoked",Vector2(150,20))
	var callbacks := [0]
	var committed := func() -> void: callbacks[0] += 1
	check(runtime.deal(revoked.receiver,1.0,&"source_revoked",&"P09",committed),"source is valid when original derived request enters policy")
	check(revoked.health.current == 100,"revocation fixture changes equipment before any HP settlement")
	var empty: Array[StringName] = []
	check(preload("res://tests/gear_inventory_support.gd").equip_ids(build,empty),"real paused equipment transaction legally unloads source while only enemy damage is queued")
	runtime.sync()
	check(not runtime.has(&"P09") and build.equipment.equipped_ids().is_empty(),"authoritative loadout and runtime both show source revoked")
	var context := {"event_id":StringName("item/%s/P09/source_revoked" % runtime.map_key()),"item_origin":&"P09","amount":1.0}
	var authorized_after_remove := runtime.authorizes_effect(context,revoked.receiver)
	check(not authorized_after_remove,"original runtime authorization becomes invalid after source unload")
	var results := policy.resolve_batch()
	observations.append({"case":"derived admitted then actual paused unload before HP commit","authorization_after_remove":authorized_after_remove,"enemy_hp":revoked.health.current,"damage_results":results.size(),"committed_callbacks":callbacks[0],"source_present":runtime.has(&"P09")})
	check(revoked.health.current == 100 and results.is_empty(),"queued derived request from unloaded source causes no ghost HP damage")
	check(callbacks[0] == 0,"revoked derived request dispatches no committed side effects")
	await fresh()
	check(equip([&"P09"]),"re-equip fixture source starts equipped")
	var restored := enemy(&"source_re_equipped",Vector2(150,20))
	check(runtime.deal(restored.receiver,1.0,&"before_unload",&"P09"),"re-equip fixture admits original pending request")
	var original_ids := build.equipment.equipped_ids()
	check(preload("res://tests/gear_inventory_support.gd").equip_ids(build,empty),"re-equip fixture first revokes source through paused transaction")
	runtime.sync()
	check(preload("res://tests/gear_inventory_support.gd").equip_ids(build,original_ids),"same owned source can be legitimately re-equipped")
	runtime.sync()
	check(runtime.has(&"P09"),"same source is live again before old queue resolves")
	var resurrected_results := policy.resolve_batch()
	check(resurrected_results.is_empty() and restored.health.current == 100,"re-equipping source cannot resurrect its revoked pending proof")
	check(runtime.deal(restored.receiver,1.0,&"after_re_equip",&"P09"),"re-equipped source may mint a new independent authorized request")
	var fresh_results := policy.resolve_batch()
	check(fresh_results.size() == 1 and restored.health.current == 99,"only fresh re-equipped request commits HP")
	observations.append({"case":"unload then re-equip before old derived commit","old_results":resurrected_results.size(),"fresh_results":fresh_results.size(),"final_hp":restored.health.current})
	await fresh()
	check(equip([&"P09"]),"weapon-epoch fixture source equips")
	var switched := enemy(&"source_weapon_switch",Vector2(150,20))
	check(runtime.deal(switched.receiver,1.0,&"before_weapon_change",&"P09"),"weapon-epoch fixture admits original pending request")
	var weapon_before := actor.shoot_ability.weapon_epoch
	check(actor.shoot_ability.equip(preload("res://resources/weapons/shadow_shuriken.tres")) and actor.shoot_ability.weapon_epoch != weapon_before,"actual weapon equip advances authoritative weapon epoch")
	runtime.sync()
	check(runtime.has(&"P09"),"source remains equipped across actual weapon epoch change")
	var switched_results := policy.resolve_batch()
	check(switched_results.is_empty() and switched.health.current == 100,"actual weapon epoch change cancels previously queued derived HP commit")
	check(runtime.deal(switched.receiver,1.0,&"after_weapon_change",&"P09"),"new weapon epoch may mint a fresh authorized request")
	var new_weapon_results := policy.resolve_batch()
	check(new_weapon_results.size() == 1 and switched.health.current == 99,"fresh current-weapon derived request commits normally")
	observations.append({"case":"weapon epoch changes before derived commit","old_results":switched_results.size(),"fresh_results":new_weapon_results.size(),"final_hp":switched.health.current,"weapon_before":weapon_before,"weapon_after":actor.shoot_ability.weapon_epoch})

func pending_lethal_formal_shop() -> void:
	paused = false
	var app: Variant = load("res://scripts/demo/demo_app.gd").new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	for _frame: int in 5: await process_frame
	check(app.start_plains("level-design-v2-baseline/08"),"independent shop fixture starts actual formal Plains app")
	for _frame: int in 240:
		if is_instance_valid(app.stage) and not app._stage_pending: break
		await process_frame
	check(is_instance_valid(app.stage) and not app._stage_pending,"actual formal shop stage finishes assembly")
	if not is_instance_valid(app.stage) or app._stage_pending:
		app.free()
		return
	for _frame: int in 80:
		if app.policy.clock >= float(app.policy.get("_protected_until")): break
		await physics_frame
	app.player.global_position = (app.stage as PlainsRegionStage).merchant_position
	app.controller.motor.reset_motion()
	app.wallet.grant(500,&"review/shop_income_fixture")
	app._open_region_shop()
	check(app._v5_shop_presenter.is_open() and paused,"healthy formal actor opens actual paused merchant modal")
	var hp: float = app.controller.actor_resources.health.current
	var coins: int = app.wallet.balance
	var count: int = app.build.inventory.instances().size()
	app._submit_damage(&"review/shop_lethal",DamageRequest.Kind.ENVIRONMENT,hp,&"review/shop_pending")
	check(app.policy.has_pending_player_damage() and app.controller.actor_resources.health.current == hp,"real formal policy holds lethal request while HP remains uncommitted")
	var offers: Dictionary = app.shop.catalog_shop_snapshot(app._v5_shop_presenter._shop_id,app._item_runtime.map_key())
	if not offers.get("offers",[]).is_empty():
		app._v5_shop_presenter._catalog_purchase(StringName(offers.offers[0].offer_id))
	check(app.wallet.balance == coins and app.build.inventory.instances().size() == count,"existing merchant context refuses purchase during pending lethal damage")
	app._close_region_shop()
	check(not app._v5_shop_presenter.open() and not app.shop_modal.opened,"fresh merchant opening rejects accepted pending lethal request")
	paused = false
	app._shown_actions = ""
	app._update_actions()
	var pressed := false
	for child: Node in app._actions.get_children():
		if child is Button and (child as Button).text.contains("商店"):
			(child as Button).pressed.emit()
			pressed = true
	check(pressed and not app.shop_modal.opened and not paused,"actual merchant GUI callback queues intent without pausing over pending damage")
	app.policy.resolve_batch()
	check(not app.lifetime.active and app.wallet.balance == coins and app.build.inventory.instances().size() == count,"formal fatal settlement beats queued merchant intent and leaves transaction balances unchanged")
	observations.append({"case":"actual formal merchant with accepted pending lethal request","coins_before":coins,"coins_after":app.wallet.balance,"hp_before_commit":hp,"run_active_after_commit":app.lifetime.active,"gui_button_found":pressed})
	paused = false
	check(await preload("res://tests/audio_teardown.gd").drain_world(app),"independent formal shop audio teardown drains")
	app.free()
	for _frame: int in 3: await process_frame

func deferred_source_revocation_without_sync() -> void:
	await fresh()
	check(equip([&"P09"]),"no-sync removal fixture begins with real equipped source")
	var removed := enemy(&"source_no_sync_removed",Vector2(150,20))
	check(runtime.deal(removed.receiver,1.0,&"no_sync_remove",&"P09"),"no-sync removal fixture queues genuine authorized damage")
	var empty: Array[StringName] = []
	check(preload("res://tests/gear_inventory_support.gd").equip_ids(build,empty),"legal paused unload commits without waiting for deferred build signal")
	# Intentionally no runtime.sync and no await before original policy commit.
	var cached_after_remove := runtime.has(&"P09")
	check(not runtime.deal(removed.receiver,1.0,&"new_proof_after_no_sync_unload",&"P09"),"stale runtime cache cannot mint a new proof for an authoritatively unloaded source")
	var removed_results := policy.resolve_batch()
	check(removed_results.is_empty() and removed.health.current == 100,"authoritative unload rejects ghost damage even before deferred runtime sync")
	observations.append({"case":"unload then resolve without runtime.sync or await","cached_source_after_remove":cached_after_remove,"actual_equipped":build.equipment.equipped_ids().size(),"results":removed_results.size(),"hp":removed.health.current})
	await fresh()
	check(equip([&"P09"]),"no-sync re-equip fixture begins equipped")
	var replaced := enemy(&"source_no_sync_replaced",Vector2(150,20))
	check(runtime.deal(replaced.receiver,1.0,&"no_sync_re_equip_old",&"P09"),"no-sync re-equip fixture queues original proof")
	var original_ids := build.equipment.equipped_ids()
	check(preload("res://tests/gear_inventory_support.gd").equip_ids(build,empty),"no-sync re-equip fixture legally unloads source")
	check(preload("res://tests/gear_inventory_support.gd").equip_ids(build,original_ids),"no-sync re-equip fixture immediately restores same owned source")
	# Again no runtime.sync or await: old cached presence alone cannot authorize.
	var old_results := policy.resolve_batch()
	check(old_results.is_empty() and replaced.health.current == 100,"unload and immediate re-equip cannot revive original proof before deferred signals")
	check(runtime.deal(replaced.receiver,1.0,&"no_sync_re_equip_fresh",&"P09"),"currently re-equipped source may authorize fresh proof without deferred notification")
	var current_results := policy.resolve_batch()
	check(current_results.size() == 1 and replaced.health.current == 99,"fresh current-revision proof still commits after immediate re-equip")
	observations.append({"case":"unload immediately re-equip then resolve without sync or await","old_results":old_results.size(),"fresh_results":current_results.size(),"hp":replaced.health.current})

func real_primary_p09_and_b17_break() -> void:
	await fresh()
	check(equip([&"P09",&"B17"]),"actual primary fixture equips P09 and B17 in real capacity")
	var first := enemy(&"real_p09_primary",Vector2(160,20))
	var second := enemy(&"real_p09_secondary",Vector2(205,20))
	await physics_frame
	check(actor.router.request_action(&"shoot_release",Vector2.RIGHT),"actual router accepts primary release for P09 control")
	actor.physics_tick(1.0/60.0)
	var projectiles := actor.shoot_ability.get_projectiles()
	check(projectiles.size() == 1,"actual controller creates one real primary projectile")
	if projectiles.size() != 1: return
	var projectile := projectiles[0]
	projectile.set_physics_process(false)
	projectile.advance(0.1)
	var primary_results := policy.resolve_batch()
	check(primary_results.size() == 1 and is_equal_approx(first.health.current,98.5),"real projectile primary commits B17 1.50D direct damage")
	var energy_after_primary := actor.combat_energy.current
	var blast_results := policy.resolve_batch()
	check(blast_results.size() == 2 and is_equal_approx(first.health.current,98.2) and is_equal_approx(second.health.current,99.7),"real committed primary on_hit triggers P09 actual 0.30D blast into both physical targets")
	check(is_equal_approx(energy_after_primary,actor.combat_energy.definition.target_gain) and actor.combat_energy.current == energy_after_primary,"P09 secondary commits produce no extra energy or recursive primary refunds")
	check(policy.resolve_batch().is_empty(),"P09 secondary blast creates no recursive damage requests")
	for index: int in 3:
		var request: Variant = load("res://scripts/damage/damage_request.gd").new()
		request.token = life.token()
		request.actor_epoch = life.actor_epoch
		request.health_epoch = actor.actor_resources.health.epoch
		request.target_id = &"player"
		request.kind = DamageRequest.Kind.ENVIRONMENT
		request.source_id = &"review/b17_environment"
		request.event_id = StringName("review/b17_actual_hurt/%s" % index)
		request.amount = 1.0
		check(policy.submit(request),"B17 break fixture actual environment damage request admits")
		var injury := policy.resolve_batch()
		check(injury.size() == 1 and injury[0].hp_lost == 1,"B17 break fixture commits one actual HP injury")
	check(bool(runtime.state(&"B17").get("broken",false)) and not runtime.has(&"B17"),"third actual HP injury breaks B17 and revokes its runtime effect")
	check(is_equal_approx(runtime.modify_direct_damage(1.0,first.receiver,false,actor.shoot_ability.packet_id+1),1.0),"broken B17 no longer contributes its primary damage multiplier")
	observations.append({"case":"actual Router Controller Projectile Policy primary triggers P09 and actual HP injuries break B17","primary_results":primary_results.size(),"blast_results":blast_results.size(),"first_hp":first.health.current,"second_hp":second.health.current,"energy_after_primary":energy_after_primary,"energy_after_blast":actor.combat_energy.current,"B17_broken":runtime.state(&"B17").get("broken",false)})

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	pre_fix = "--pre-fix" in OS.get_cmdline_user_args()
	source_lifetime_only = "--source-lifetime-only" in OS.get_cmdline_user_args()
	if source_lifetime_only:
		await source_revocation_before_derived_commit()
		await deferred_source_revocation_without_sync()
		await real_primary_p09_and_b17_break()
	else:
		await g14_real_runtime_chain()
		if not pre_fix:
			await s13_opposite_trajectories()
			await targets_equal_distance_id_order()
			await pending_lethal_equipment()
			await pending_lethal_formal_shop()
			await source_revocation_before_derived_commit()
			await deferred_source_revocation_without_sync()
			await real_primary_p09_and_b17_break()
	var sources := {}
	for path: String in ["res://scripts/items/v5/item_runtime.gd","res://scripts/items/v5/item_active_effects.gd","res://scripts/combat/weapon_action_runtime.gd","res://scripts/damage/frame_damage_policy.gd","res://tests/item_v5_review_runner.gd"]:
		sources[path] = FileAccess.get_sha256(path)
	DirAccess.make_dir_recursive_absolute("res://build/item_v5/review")
	var filename := "res://build/item_v5/review/independent_review_source_lifetime.json" if source_lifetime_only else "res://build/item_v5/review/independent_review_pre_fix.json" if pre_fix else "res://build/item_v5/review/independent_review_after_fixes.json"
	var output := FileAccess.open(filename,FileAccess.WRITE)
	output.store_string(JSON.stringify({"scope":"explicit native integration fixtures, no natural-route/player/device endorsement","assertions":assertions,"failures":failures,"sources":sources,"observations":observations},"\t") + "\n")
	output.close()
	if runtime != null: runtime.clear()
	if build != null: build.clear()
	if fixture != null and is_instance_valid(fixture.get("world")): (fixture.get("world") as Node).free()
	runtime = null
	build = null
	actor = null
	policy = null
	stage = null
	fixture = null
	life = null
	for _frame: int in 3: await process_frame
	print("ITEM V5 INDEPENDENT REVIEW: %s assertions, %s failures" % [assertions,failures])
	quit.call_deferred(1 if failures > 0 else 0)
