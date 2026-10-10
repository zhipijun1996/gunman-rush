extends RefCounted

const DEMO := preload("res://scenes/demo/demo.tscn")
var tree: SceneTree
var check: Callable

func run(scene_tree: SceneTree, assertion: Callable) -> void:
	tree = scene_tree
	check = assertion
	var app: DemoApp = DEMO.instantiate()
	app.meta_persistence_enabled = false
	tree.root.add_child(app)
	await frames(2)
	check.call(app.apply_input_settings({"right_sensitivity": 1.35, "touch_deadzone": 0.14}), "module lab fixture applies a nondefault session input profile")
	var previous_meta := app.meta.snapshot().duplicate(true)
	app.menu.requested_lab.emit()
	await frames(6)
	var lab: ModuleLab = app._lab
	check.call(lab != null and lab.ready_for_play, "home opens the real safe-hub module lab with bounded safe-entry validation")
	if lab == null or not lab.ready_for_play:
		await cleanup(app)
		return
	check.call(lab.module_id == &"safe_hub" and lab.segment.is_safe(lab.module.world_entry()), "initial lab module has a physically supported safe segment entry")
	check.call(lab.controller.router.profile.values.right_sensitivity == 1.35 and lab.input_values.touch_deadzone == 0.14, "lab inherits the effective home session profile rather than resetting to defaults")
	check.call(app.director.state == DemoRunDirector.State.HOME and app.meta.snapshot() == previous_meta, "module practice creates no run or permanent-progression transaction")
	var original_attempt := lab.attempt
	var original_module := lab.module
	check.call(not lab.request_module(&"missing_module") and lab.attempt == original_attempt and lab.module == original_module, "unknown module selection is rejected without destroying the current playable fixture")
	for id: StringName in [&"stepped_crossing", &"recoil_shaft", &"descending_switchback", &"safe_hub"]:
		var old_lifetime := lab.lifetime
		var old_token := old_lifetime.token()
		var old_attempt := lab.attempt
		check.call(lab.request_module(id), "lab accepts authored module selection " + str(id))
		await frames(6)
		check.call(lab.ready_for_play and lab.module_id == id and lab.module.definition.module_id == id, "lab instantiates actual selected authored geometry " + str(id))
		check.call(lab.attempt == old_attempt + 1 and not old_lifetime.accepts(old_token) and not lab.lifetime.accepts(old_token), "module changes explicitly start a fresh attempt and invalidate every prior lifetime token")
		check.call(lab.segment.is_safe(lab.module.world_entry()) and lab.player.is_on_floor(), "selected module player settles on its validated supporting entry floor")
		check.call(lab.controller.router.profile.values.right_sensitivity == 1.35, "module selection retains session settings")
	var old_lifetime := lab.lifetime
	var retry_token := old_lifetime.token()
	var old_attempt := lab.attempt
	lab.restart_module()
	await frames(6)
	check.call(lab.ready_for_play and lab.module_id == &"safe_hub" and lab.attempt == old_attempt + 1 and not old_lifetime.accepts(retry_token), "explicit retry starts a new attempt instead of masquerading as selective environmental return")
	# Position fixtures do not claim platforming reachability; that is separately
	# proven with actual Motor traces in platforming_module_tests.gd.
	lab.player.global_position = lab.module.world_exit()
	lab.player.reset_motion()
	await frames(4)
	check.call(lab.finished and app.director.state == DemoRunDirector.State.HOME and app.meta.snapshot() == previous_meta, "standing on the actual accepted exit clears only the practice module without granting a run or biome victory")
	lab.player.global_position = lab.module.world_entry()
	lab.player.reset_motion()
	await frames(2)
	var position_before := lab.player.global_position
	var actor_epoch := lab.lifetime.actor_epoch
	lab.policy.clock += 1.0
	check.call(submit_damage(lab, &"lab_monster", DamageRequest.Kind.MONSTER, 1.0), "lab monster damage enters the same deterministic frame policy as the real game")
	lab.policy.resolve_batch()
	check.call(lab.controller.actor_resources.health.current == 4.0 and lab.player.global_position == position_before and lab.lifetime.actor_epoch == actor_epoch, "monster damage removes HP in place without performing a segment return")
	check.call(not submit_damage(lab, &"lab_monster_again", DamageRequest.Kind.MONSTER, 1.0), "lab monster iframe rejects repeated contact damage")
	# The practice supply is still a real queued interaction, not a test-only grant.
	await claim_supply(lab)
	check.call(lab.supply_claimed, "a nearby lab supply is claimed through its actual post-damage interaction boundary")
	var same_module := lab.module
	var same_attempt := lab.attempt
	var same_clock := lab.elapsed
	var same_life := lab.lifetime
	var stamina := lab.controller.actor_resources.stamina
	stamina.consume_continuous(11.0, stamina.epoch)
	var before_stamina := stamina.current
	lab.controller.shoot_ability.cooldown_remaining = 0.45
	lab.controller.router.request_action(&"shoot_release", Vector2.DOWN)
	var before_hp := lab.controller.actor_resources.health.current
	var before_epoch := lab.lifetime.actor_epoch
	check.call(submit_damage(lab, &"lab_environment", DamageRequest.Kind.ENVIRONMENT, 1.0), "monster iframe does not suppress distinct environmental damage")
	lab.policy.resolve_batch()
	check.call(lab.controller.actor_resources.health.current == before_hp - 1.0 and lab.lifetime.actor_epoch == before_epoch + 1, "nonlethal environmental damage deducts HP then selectively invalidates the returning actor")
	check.call(lab.module == same_module and lab.lifetime == same_life and lab.attempt == same_attempt and lab.elapsed == same_clock and lab.supply_claimed, "environmental return preserves module instance, attempt, game clock and used-supply ledger")
	check.call(stamina.current == before_stamina and lab.controller.shoot_ability.cooldown_remaining == 0.45, "environmental return preserves stamina and shot cooldown rather than applying legacy player reset")
	check.call(lab.player.normal_velocity == Vector2.ZERO and lab.player.recoil_velocity == Vector2.ZERO and lab.controller.router._queue.is_empty(), "environmental return clears velocity, recoil and obsolete release-fire intent")
	check.call(not submit_damage(lab, &"lab_environment_contact", DamageRequest.Kind.ENVIRONMENT, 1.0), "spawn protection prevents immediate repeat environmental damage after return")
	var returned_hp := lab.controller.actor_resources.health.current
	lab.take_supply()
	await frames(2)
	check.call(lab.supply_claimed and lab.controller.actor_resources.health.current == returned_hp, "returning to the supply cannot reclaim its already-spent heal")
	# Negative content-boundary fixture: escaping the map must not soft-lock play.
	# This teleport is not presented as a successful platforming traversal.
	lab.policy.clock += 2.0
	var bounds_hp := lab.controller.actor_resources.health.current
	var bounds_epoch := lab.lifetime.actor_epoch
	lab.player.global_position = lab.module.to_global(lab.module.definition.world_bounds.end + Vector2(64, 64))
	lab.player.reset_motion()
	await frames(4)
	check.call(lab.controller.actor_resources.health.current == bounds_hp - 1.0 and lab.lifetime.actor_epoch == bounds_epoch + 1 and lab.player.global_position.distance_to(lab.module.world_entry()) < 2.0, "leaving authored world bounds triggers one environmental HP cost and returns to the validated safe anchor")
	check.call(lab.module == same_module and lab.attempt == same_attempt and lab.supply_claimed, "out-of-bounds recovery also preserves the authored instance and used-supply ledger")
	lab.controller.shoot_ability.cooldown_remaining = 0.0
	lab.controller.router.request_action(&"shoot_release", Vector2.RIGHT)
	lab.toggle_pause()
	var paused_clock := lab.elapsed
	lab.controller.shoot_ability.cooldown_remaining = 0.35
	await frames(4)
	check.call(tree.paused and lab.menu.visible_panel == &"pause" and lab.elapsed == paused_clock, "lab pause freezes its actual game clock and opens the existing menu")
	check.call(lab.controller.shoot_ability.cooldown_remaining == 0.35, "lab pause freezes player ability cooldowns instead of inheriting the always-processing home app")
	check.call(lab.controller.shoot_ability.get_projectiles().is_empty() and lab.controller.router._queue.is_empty(), "lab menu cancels old queued release-fire instead of shooting while paused")
	lab.menu.show_settings(true)
	var profile_before := lab.input_values.duplicate(true)
	check.call(not lab.apply_settings({"right_enter_deadzone": 0.1, "right_exit_deadzone": 0.3}) and lab.input_values == profile_before and lab.controller.router.profile.values == profile_before, "lab rejects invalid input hysteresis atomically without resetting the existing profile")
	lab.menu.settings_changed.emit({"right_sensitivity": 1.6, "touch_deadzone": 0.16})
	check.call(lab.input_values.right_sensitivity == 1.6 and lab.controller.router.profile.values.touch_deadzone == 0.16, "lab menu applies input settings to the same live unified router")
	lab.menu.close_panel()
	await frames(3)
	check.call(not tree.paused and lab.elapsed > paused_clock, "lab menu Resume continues the preserved scene clock")
	check.call(lab.controller.shoot_ability.get_projectiles().is_empty(), "resuming lab cannot replay a release-fire canceled by the menu")
	lab.leave_lab()
	await frames(4)
	check.call(app._lab == null and app.menu.visible_panel == &"home" and app.meta.snapshot() == previous_meta, "leaving module practice returns to home while preserving all meta state")
	check.call(app.start_demo("after-module-practice"), "normal demo still starts after module practice")
	await frames(4)
	check.call(app.controller.router.profile.values.right_sensitivity == 1.6 and app.controller.router.profile.values.touch_deadzone == 0.16, "lab input settings are inherited by the next ordinary run in the current session")
	app.abandon_run()
	await frames(4)
	previous_meta = app.meta.snapshot().duplicate(true)
	app._open_module_lab()
	await frames(6)
	lab = app._lab
	check.call(lab != null and lab.ready_for_play, "module practice can be entered repeatedly after a normal run")
	if lab != null and lab.ready_for_play:
		var fatal_life := lab.lifetime
		var fatal_health := lab.controller.actor_resources.health
		lab.take_supply()
		lab.policy.clock += 2.0
		check.call(submit_damage(lab, &"lab_fatal_environment", DamageRequest.Kind.ENVIRONMENT, 99.0), "fatal lab damage submits through the real policy")
		lab.policy.resolve_batch()
		await frames(4)
		check.call(not fatal_life.active and app._lab == null and app.menu.visible_panel == &"home", "zero health exits module practice to home instead of attempting a nonlethal reset")
		check.call(fatal_health.terminal and fatal_health.current == 0.0, "same-frame fatality cancels the pending practice supply instead of healing after death")
		check.call(app.meta.snapshot() == previous_meta, "practice fatality neither awards nor fails a normal run or modifies permanent summary")
	await cleanup(app)

func frames(count: int) -> void:
	for unused: int in count:
		await tree.physics_frame

func submit_damage(lab: ModuleLab, event_id: StringName, kind: DamageRequest.Kind, amount: float) -> bool:
	var health := lab.controller.actor_resources.health
	var request := DamageRequest.new()
	request.token = lab.lifetime.token()
	request.event_id = event_id
	request.source_id = &"module_lab_integration"
	request.target_id = &"player"
	request.kind = kind
	request.amount = amount
	request.health_epoch = health.epoch
	request.actor_epoch = lab.lifetime.actor_epoch
	return lab.policy.submit(request)

func claim_supply(lab: ModuleLab) -> void:
	# The actual fixture position is supplied by its local consumer.
	lab.player.global_position = lab.module.world_entry()
	lab.player.reset_motion()
	lab.take_supply()
	await frames(2)

func cleanup(app: DemoApp) -> void:
	tree.paused = false
	if app._lab != null:
		app._close_module_lab()
	app.queue_free()
	await tree.process_frame
