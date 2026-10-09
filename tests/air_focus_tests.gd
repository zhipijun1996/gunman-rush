extends RefCounted

func run(tree: SceneTree, check: Callable) -> void:
	var focus := AirFocusAbility.new()
	tree.root.add_child(focus)
	var tuning := PlayerTuning.load_default()
	focus.configure(tuning)
	check.call(focus.stamina == 100.0 and Engine.time_scale == 1.0, "focus starts full without scaling ground gameplay")
	focus.advance(0.5, true, true)
	check.call(not focus.active and focus.stamina == 100.0, "ground aiming never slows or spends stamina")
	focus.advance(0.5, false, false)
	check.call(not focus.active and focus.stamina == 100.0, "airborne without active aim does not spend stamina")
	focus.advance(0.5, false, true)
	check.call(focus.active and Engine.time_scale == 0.25 and is_equal_approx(focus.stamina, 77.5), "air aim scales the whole engine and drains by real seconds")
	focus.advance(0.5, false, false)
	check.call(not focus.active and Engine.time_scale == 1.0 and focus.stamina == 77.5, "normal aim release restores speed without airborne recharge")
	focus.advance(0.5, false, true)
	check.call(focus.air_time_used == 1.0 and focus.stamina == 55.0, "repeated gestures share the same flight budget")
	focus.advance(1.0, false, true)
	check.call(not focus.active and Engine.time_scale == 1.0 and focus.air_time_used == 2.0 and focus.stamina == 10.0, "flight duration cap exits slow time with remaining stamina")
	focus.advance(0.5, false, false)
	focus.advance(0.5, false, true)
	check.call(not focus.active and focus.stamina == 10.0, "releasing and rearming cannot bypass flight duration cap")
	focus.advance(0.5, true, false)
	check.call(focus.air_time_used == 0.0 and focus.stamina == 25.0, "ground contact resets flight cap and only gradually recharges")
	focus.advance(0.1, false, true)
	focus.stop()
	check.call(Engine.time_scale == 1.0 and focus.stamina < 25.0, "cancel restores global speed without refunding spent stamina")
	focus.reset()
	tuning.focus_stamina_capacity = 9.0
	tuning.focus_rearm_stamina = 6.0
	focus.reset()
	focus.advance(1.0, false, true)
	check.call(focus.exhausted and focus.stamina == 0.0 and Engine.time_scale == 1.0, "empty stamina exits immediately without going negative")
	focus.advance(0.5, false, true)
	check.call(not focus.active and focus.stamina == 0.0, "empty airborne bar cannot recharge or reactivate")
	focus.advance(0.1, true, true)
	check.call(focus.stamina == 3.0 and focus.exhausted, "partial ground refill below rearm threshold stays exhausted")
	focus.advance(0.1, false, true)
	check.call(not focus.active and focus.stamina == 3.0, "small refill cannot flicker slow time on next jump")
	focus.advance(0.1, true, false)
	check.call(not focus.exhausted and focus.stamina == 6.0, "ground refill reaching threshold rearms ability")
	focus.advance(0.05, false, true)
	check.call(focus.active, "fresh airborne aim can use recovered stamina")
	focus.enabled = false
	check.call(Engine.time_scale == 1.0 and not focus.active, "runtime ability disable restores global time")
	focus.enabled = true
	focus.configure(PlayerTuning.load_default())
	focus.advance(0.1, false, true)
	var remaining := focus.stamina
	focus.advance(2.0, true, true, false)
	check.call(focus.stamina == remaining and Engine.time_scale == 1.0, "paused inactive unfocused player neither spends nor regenerates")
	focus.advance(0.1, false, true)
	focus.free()
	check.call(Engine.time_scale == 1.0, "scene teardown never leaks global slow motion")

	var fixture := preload("res://tests/combat_tests.gd").new()
	fixture.tree = tree
	await fixture.fixture()
	var controller: PlayerController = fixture.controller
	focus = controller.air_focus_ability
	focus.advance(0.1, false, true)
	controller.router.clear("focus_out")
	check.call(Engine.time_scale == 1.0 and not focus.active, "router cancellation restores global scale synchronously")
	focus.advance(0.1, false, true)
	controller.die()
	check.call(Engine.time_scale == 1.0 and not focus.active, "player death immediately restores speed")
	controller.reset_at(Vector2(80, 150))
	check.call(focus.stamina == controller.motor.tuning.focus_stamina_capacity and focus.air_time_used == 0.0, "respawn resets focus resource and stale flight state")
	focus.advance(0.1, false, true)
	controller.shoot_ability.try_fire(Vector2.RIGHT, false)
	check.call(Engine.time_scale == 1.0 and not focus.active, "successful release-shot ends slow time without delaying projectile")
	var bullet: PlayerProjectile = controller.shoot_ability.get_projectiles().back()
	var clock := WorldContext.new()
	fixture.world.add_child(clock)
	await tree.physics_frame
	await tree.process_frame
	var before_clock := clock.clock
	var before_x := bullet.position.x
	for index: int in 12:
		await tree.physics_frame
		await tree.process_frame
	var normal_clock := clock.clock - before_clock
	var normal_distance := bullet.position.x - before_x
	focus.advance(0.01, false, true)
	await tree.physics_frame
	await tree.process_frame
	before_clock = clock.clock
	before_x = bullet.position.x
	for index: int in 12:
		await tree.physics_frame
		await tree.process_frame
	var slow_clock := clock.clock - before_clock
	var slow_distance := bullet.position.x - before_x
	check.call(absf(slow_clock / normal_clock - 0.25) < 0.02, "actual world mechanism clock advances at quarter speed")
	check.call(absf(slow_distance / normal_distance - 0.25) < 0.02, "actual swept attack projectile also moves at quarter speed")
	print("AIR FOCUS GLOBAL RATIOS: world=%.3f projectile=%.3f" % [slow_clock / normal_clock, slow_distance / normal_distance])
	controller.router.clear("pause")
	tree.paused = true
	check.call(Engine.time_scale == 1.0 and not focus.active, "pause cancellation restores scale even when player cannot process")
	tree.paused = false
	var router := controller.router
	router.activate_device(&"keyboard_mouse")
	router.set_aim(&"keyboard_mouse", Vector2.RIGHT)
	check.call(not router.aim_engaged, "passive mouse aiming display cannot trigger slow motion")
	router.set_aim(&"keyboard_mouse", Vector2.RIGHT, true)
	check.call(router.aim_engaged, "unified valid held aim can request focus")
	router.set_aim(&"keyboard_mouse", Vector2.ZERO, true)
	check.call(not router.aim_engaged, "deadzone direction cannot consume focus")
	router.set_aim(&"keyboard_mouse", Vector2.RIGHT, true)
	router.activate_device(&"touch")
	check.call(not router.aim_engaged, "device change cannot inherit old held aim")
	router.set_aim(&"touch", Vector2.DOWN, true)
	router.clear("cancel")
	check.call(not router.aim_engaged and Engine.time_scale == 1.0, "cancel clears focus intent without creating a shot")
	fixture.world.free()
