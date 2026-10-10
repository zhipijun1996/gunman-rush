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
	check.call(is_instance_valid(app.menu), "DemoApp initialization supplies the actual menu")
	if not is_instance_valid(app.menu):
		app.free()
		return
	check.call(app.menu.visible_panel == &"title", "new demo exposes its title menu before starting a run")
	check.call(app.start_demo("menus", true), "menu fixture starts the full eight-stage trial")
	await frames(4)
	check.call(app.wallet.balance == 0 and app.director.stage_complete and not (app.stage.enemy.get_node("Actor") as EnemyActor).health.terminal, "ordinary fixed room opens with living enemy without granting entry-time coins")
	app.wallet.grant(7, &"menu_fixture_coins")
	var hp := app.controller.actor_resources.health.current
	var epoch := app.lifetime.stage_epoch
	app.controller.router.request_action(&"shoot_release", Vector2.RIGHT)
	app.menu.show_pause()
	var paused_clock := app.stage.clock
	await frames(5)
	check.call(tree.paused and app.menu.visible_panel == &"pause" and app.stage.clock == paused_clock, "pause panel actually freezes the fixed stage game clock")
	check.call(app.controller.shoot_ability.get_projectiles().is_empty() and app.controller.shoot_ability.cooldown_remaining == 0.0, "opening a menu cancels queued release-fire without spawning a projectile")
	check.call(app.wallet.balance == 7 and app.controller.actor_resources.health.current == hp and app.lifetime.stage_epoch == epoch, "pausing preserves wallet, health and the current stage rather than resetting the world")
	app.menu.show_settings(true)
	await frames(2)
	check.call(tree.paused and app.menu.visible_panel == &"settings" and app.stage.clock == paused_clock, "in-run settings remain on the frozen game clock")
	var old_profile := app.controller.router.profile.values.duplicate(true)
	check.call(not app.apply_input_settings({"right_enter_deadzone": 0.2, "right_exit_deadzone": 0.3}), "invalid deadzone hysteresis settings fail atomically")
	check.call(app.controller.router.profile.values == old_profile, "rejected settings retain every previously valid input setting")
	check.call(app.apply_input_settings({"left_sensitivity": 0.8, "right_sensitivity": 1.4, "touch_deadzone": 0.12}), "valid in-run input settings reconfigure the existing router")
	check.call(app.controller.router.profile.values.right_sensitivity == 1.4 and app.controller.router.profile.values.touch_deadzone == 0.12, "applied settings become the actual router input values")
	app.menu._back()
	check.call(tree.paused and app.menu.visible_panel == &"pause", "settings Back returns to pause without implicitly resuming")
	app.menu.close_panel()
	await frames(2)
	check.call(not tree.paused and app.stage.clock > paused_clock and app.menu.visible_panel.is_empty(), "Resume hides the menu and continues the original game clock")
	app.menu.show_settings(true)
	var restore_button := find_button(app.menu, "RESTORE DEFAULTS")
	check.call(restore_button != null, "settings exposes a real restore-defaults action")
	var before_restore := app.controller.router.profile.values.duplicate(true)
	if restore_button != null:
		restore_button.pressed.emit()
	check.call(app.controller.router.profile.values == before_restore, "restoring defaults stages slider values until Apply is chosen")
	var apply_button := find_button(app.menu, "APPLY")
	if apply_button != null:
		apply_button.pressed.emit()
	check.call(profiles_equal(app.controller.router.profile.values, InputProfile.load_default().values), "restore defaults applies the authoritative input profile rather than duplicate numeric defaults")
	app.apply_input_settings({"right_sensitivity": 1.25})
	app.menu.close_panel()
	app.menu.show_pause()
	app.menu._confirm_home()
	await frames(2)
	check.call(app.menu.visible_panel == &"confirm_home" and app.director.state == DemoRunDirector.State.IN_STAGE and app.lifetime.active, "Return Home opens confirmation while preserving the still-active run")
	var keep_button := find_button(app.menu, "KEEP PLAYING")
	check.call(keep_button != null, "home confirmation exposes Keep Playing")
	if keep_button != null:
		keep_button.pressed.emit()
	await frames(2)
	check.call(not tree.paused and app.director.state == DemoRunDirector.State.IN_STAGE and app.wallet.balance == 7, "canceling home confirmation resumes the unchanged run")
	app.menu.show_pause()
	app.menu._confirm_home()
	var leave_button := find_button(app.menu, "LEAVE RUN")
	check.call(leave_button != null, "home confirmation exposes a distinct Leave Run action")
	if leave_button != null:
		leave_button.pressed.emit()
	await frames(4)
	check.call(app.director.state == DemoRunDirector.State.HOME and app.player == null and app.meta.snapshot().failed_runs == 1, "only confirmed Leave Run terminates the fixture and returns home")

	var encountered: Dictionary = {}
	var successful_trials := 0
	for seed_index: int in 3:
		check.call(app.start_demo("ten-demo-%s" % seed_index, true), "a fresh formal trial starts after returning home")
		await frames(4)
		check.call(app.controller.router.profile.values.right_sensitivity == 1.25, "new runs inherit valid session input settings")
		var items_visited := 0
		var received_simple := false
		for stage_index: int in range(1, 9):
			check.call(app.director.stage_index == stage_index and app.director.profile.stages_per_biome == 8, "actual DemoApp advances through every formal stage index")
			var room_type := app.director.stage_type_id
			encountered[room_type] = true
			if room_type == &"combat":
				var actor := app.stage.enemy.get_node("Actor") as EnemyActor
				queue_target_damage(app, &"drone", actor.health, StringName("demo_fixture_drone_%s" % stage_index))
				await frames(2)
				check.call(actor.health.terminal and app.director.stage_complete, "damage batch commits real combat room completion")
			elif room_type == &"boss":
				check.call(stage_index == 8 and app.director.offers.is_empty(), "actual formal Boss room appears only at stage eight with no bypass exit")
				var boss_health: HealthState = app.stage.boss.get_node("Encounter").health
				queue_target_damage(app, &"boss", boss_health, &"demo_fixture_final_boss")
				await frames(2)
				check.call(app.current_reward != null and app.current_reward.gold and app.director.stage_complete, "final Boss defeat generates the guaranteed gold claim")
				locate(app, app.stage.reward_position)
				app.claim_item(app.current_reward.candidates[0].stable_id)
				await frames(4)
				check.call(app.director.state == DemoRunDirector.State.HOME and app.director.manifest.snapshot().end.reason == "biome_complete", "actual gold claim ends the biome trial and returns home without whole-run victory")
				break
			elif room_type == &"item_reward":
				items_visited += 1
				locate(app, app.stage.reward_position)
				check.call(app.current_reward != null and app.current_reward.candidates.size() == 2 and app.current_reward.candidates[0].stable_id != app.current_reward.candidates[1].stable_id, "formal item room offers two distinct currently legal definitions")
				var chosen := app.current_reward.candidates[0].stable_id
				var rejected := app.current_reward.candidates[1].stable_id
				var prior_count := app.build.item_ids().size()
				app.claim_item(chosen)
				app.claim_item(rejected)
				await frames(2)
				check.call(app.rewards.get_offer(app.current_reward.offer_id).claimed and app.build.item_ids().size() == prior_count + 1, "formal repeated item rooms still commit only one of two competing choices")
			elif room_type == &"shop":
				locate(app, app.stage.reward_position)
				if seed_index % 2 == 0 and app.build.can_add(app.JUMP_ITEM):
					var before_coins := app.wallet.balance
					app.purchase_item()
					await frames(2)
					check.call(app.wallet.balance == before_coins - 5 and app.shop.quote(app._stage_id("shop_jump")).stock == 0, "formal shop performs its real atomic purchase when affordable and eligible")
				else:
					check.call(app.shop.quote(app._stage_id("shop_jump")).stock == 1, "formal shop may be skipped without forcing a purchase")
			elif room_type in [&"coin_reward", &"health_reward"]:
				received_simple = true
				locate(app, app.stage.reward_position)
				var before_coins := app.wallet.balance
				var before_capacity := app.controller.actor_resources.health.capacity
				app.claim_room_reward()
				app.claim_room_reward()
				await frames(2)
				check.call(app.simple_reward.claimed and app.director.stage_complete, "nearby simple room claim completes through the damage-batch commit boundary")
				if room_type == &"coin_reward":
					check.call(app.wallet.balance == before_coins + app.COIN_REWARD.amount, "duplicate coin intents grant the defined amount exactly once")
				else:
					check.call(app.controller.actor_resources.health.capacity == before_capacity, "health room healing remains distinct from increasing maximum HP")
				check.call(app.director.manifest.snapshot().stages[stage_index - 1].outputs.has("simple_reward_claim"), "simple reward writes the actual committed reward result into the manifest")
			locate(app, Vector2(1130, 565))
			await frames(2)
			check.call(app.director.stage_complete, "room completion permits advancing only after its own real completion policy")
			var offers := app.director.offers
			if stage_index == 7:
				check.call(offers[0].next_stage_type_id == &"boss" and offers[1].next_stage_type_id == &"boss", "actual stage seven presents two mandatory Boss destinations")
			var choice := choose_offer(offers, encountered, items_visited)
			locate(app, app.stage.exit_positions[choice])
			var promised_type: StringName = offers[choice].next_stage_type_id
			app.choose_exit(offers[choice].exit_id)
			await frames(4)
			check.call(app.director.stage_index == stage_index + 1 and app.director.stage_type_id == promised_type, "actual exit commits exactly its disclosed next formal room")
		successful_trials += 1
		var meta_snapshot := app.meta.snapshot()
		check.call(meta_snapshot.completed_biomes == successful_trials and meta_snapshot.completed_runs == 0 and meta_snapshot.failed_runs == 1, "biome completion increments only its independent home counter")
		var manifest := app.director.manifest.snapshot()
		check.call(manifest.stages.size() == 8 and manifest.content_manifest.size() == 9 and manifest.initial_character.input_values.right_sensitivity == 1.25, "played formal manifest records eight stages, nine actual content versions and session input values")
		var catalog_versions_valid := true
		for entry: Dictionary in manifest.stages:
			if entry.type_id == "item_reward":
				catalog_versions_valid = catalog_versions_valid and entry.outputs.reward_catalog.version == DemoRewardCatalog.CONTENT_VERSION
		check.call(catalog_versions_valid and RunManifest.from_snapshot(manifest) != null, "formal item catalog version and all played output records remain manifest-compatible")
		check.call(not received_simple or manifest.stages.any(func(entry: Dictionary) -> bool: return entry.outputs.has("simple_reward_claim")), "played simple room rewards survive in the final complete manifest")
	check.call(encountered.size() == 6, "multiple actual seeded eight-stage trials encounter all six supported room types")
	check.call(app.start_demo("quick-still-supported", false), "three-stage quick demo remains independently selectable")
	await frames(4)
	check.call(app.director.profile.development_only and app.director.profile.stages_per_biome == 3 and app.build.item_ids().is_empty() and app.wallet.balance == 0, "new quick demo preserves its short profile and clears the prior trial build and coins")
	app.abandon_run()
	await frames(4)
	app.queue_free()
	await tree.process_frame

func frames(count: int) -> void:
	for unused: int in count:
		await tree.physics_frame

func locate(app: DemoApp, position: Vector2) -> void:
	app.lifetime.invalidate_actor()
	app.player.reset_at(position)

func queue_target_damage(app: DemoApp, id: StringName, health: HealthState, event_id: StringName) -> void:
	var request := DamageRequest.new()
	request.token = app.lifetime.token()
	request.event_id = event_id
	request.source_id = &"demo_integration_projectile"
	request.target_id = id
	request.amount = health.capacity
	request.health_epoch = health.epoch
	request.actor_epoch = app.lifetime.actor_epoch
	app.policy.submit(request)

func choose_offer(offers: Array[ExitOffer], encountered: Dictionary, items_visited: int) -> int:
	for index: int in offers.size():
		if not encountered.has(offers[index].next_stage_type_id):
			return index
	for index: int in offers.size():
		if offers[index].next_stage_type_id != &"item_reward" or items_visited < 2:
			return index
	return 0

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node as Button
	for child: Node in node.get_children():
		var found := find_button(child, text)
		if found != null:
			return found
	return null

func profiles_equal(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.size() != expected.size():
		return false
	for key: Variant in expected:
		if not actual.has(key):
			return false
		if expected[key] is float or expected[key] is int:
			if not is_equal_approx(float(actual[key]), float(expected[key])):
				return false
		elif actual[key] != expected[key]:
			return false
	return true
