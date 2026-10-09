extends RefCounted

const DEMO := preload("res://scenes/demo/demo.tscn")
var tree: SceneTree
var check: Callable

func run(scene_tree: SceneTree, assertion: Callable) -> void:
	tree = scene_tree
	check = assertion
	var app: DemoApp = DEMO.instantiate()
	tree.root.add_child(app)
	await frames(2)
	for route: int in 2:
		check.call(app.start_demo("repeatable-demo"), "demo starts a new three-stage run")
		await frames(4)
		check.call(app.stage != null and app.segment.is_safe(app.stage.spawn), "real demo stage has a validated safe entry")
		var actor := app.stage.enemy.get_node("Actor") as EnemyActor
		actor.brain.enabled = false
		# A real projectile traverses the collision world; no direct enemy HP edits.
		for shot: int in 3:
			locate(app, Vector2(240, 580))
			await frames(2)
			check.call(app.controller.shoot_ability.try_fire((actor.motor.global_position - app.player.global_position).normalized(), true), "demo release-shot fixture fires a physical projectile")
			await frames(24)
		check.call(actor.health.terminal and app.director.stage_complete and app.wallet.balance == 10, "actual projectile defeat unlocks routes and grants coins once")
		locate(app, app.stage.supply_position)
		app.interact()
		await frames(2)
		var coins := app.wallet.balance
		var phase_clock := app.stage.clock
		var life := app.lifetime.actor_epoch
		app.policy.spawn_protection = 0.0
		app.policy.clock += 1.0
		app._submit_damage(&"fixture_saw", DamageRequest.Kind.ENVIRONMENT, 1.0)
		await frames(2)
		check.call(app.lifetime.actor_epoch == life + 1 and app.controller.actor_resources.health.current == 4.0, "environment damage returns the living player and preserves deducted HP")
		check.call(actor.health.terminal and app.stage.supply_claimed and app.wallet.balance == coins and app.stage.clock > phase_clock, "segment return preserves defeated enemy, used supply, wallet and mechanism phase")
		var offer: ExitOffer = app.director.offers[route]
		locate(app, app.stage.exit_positions[route])
		app.choose_exit(offer.exit_id)
		await frames(4)
		check.call(app.director.stage_index == 2 and app.director.stage_type_id == offer.next_stage_type_id, "physical exit marker leads to the selected room type exactly once")
		check.call(app.controller.actor_resources.health.current == 4.0, "stage transitions preserve player health")
		locate(app, app.stage.reward_position)
		if route == 0:
			app.purchase_item()
			await frames(2)
			check.call(app.build.item_ids().size() == 1 and app.wallet.balance == 5, "nearby shop UI intent buys one item for five run coins")
			var old_items := app.build.item_ids()
			app.purchase_item()
			await frames(2)
			check.call(app.build.item_ids() == old_items and app.wallet.balance == 5, "depleted shop stock cannot charge a second transaction")
		else:
			var selected_id := app.current_reward.candidates[0].stable_id
			var rejected_id := app.current_reward.candidates[1].stable_id
			app.claim_item(selected_id)
			app.claim_item(rejected_id)
			await frames(2)
			check.call(app.build.item_ids().size() == 1 and app.build.count_item(rejected_id) == 0, "demo item-room UI commits only one of two queued choices")
		var saved_build := app.build.item_ids()
		var saved_wallet := app.wallet.balance
		app.policy.clock += 1.0
		app._submit_damage(&"fixture_saw_2", DamageRequest.Kind.ENVIRONMENT, 1.0)
		await frames(2)
		check.call(app.build.item_ids() == saved_build and app.wallet.balance == saved_wallet, "return preserves committed build and wallet")
		if route == 0:
			check.call(app.shop.quote(app._stage_id("shop_jump")).stock == 0, "return does not replenish shop stock")
		else:
			check.call(app.rewards.get_offer(app.current_reward.offer_id).claimed, "return does not regenerate claimed item choices")
		locate(app, Vector2(1130, 565))
		await frames(2)
		app.choose_exit(app.director.offers[1].exit_id)
		await frames(4)
		check.call(app.director.stage_index == 3 and app.director.stage_type_id == &"boss", "both development penultimate exits lead to Boss")
		var boss_health: HealthState = app.stage.boss.get_node("Encounter").health
		queue_damage(app, &"boss", boss_health, 99.0, &"fixture_boss_defeat")
		await frames(2)
		check.call(app.current_reward != null and app.current_reward.gold and app.director.stage_complete, "Boss defeat creates the mandatory gold claim")
		locate(app, app.stage.reward_position)
		app.claim_item(app.current_reward.candidates[0].stable_id)
		await frames(4)
		check.call(app.director.state == DemoRunDirector.State.HOME and app.player == null and app.wallet.balance == 0, "gold claim ends the run, clears wallet and returns home")
		check.call(app.meta.snapshot().completed_runs == route + 1, "home meta summary persists across fresh runs")
		var manifest_data := app.director.manifest.snapshot()
		check.call(manifest_data.config_hashes.physics.length() == 64 and manifest_data.content_manifest.size() == 4, "playable run manifest pins actual physics configuration and content versions")
		check.call(manifest_data.stages[0].outputs.has("fixed_layout") and manifest_data.stages[1].outputs.has("capability_snapshot") and manifest_data.stages[2].outputs.reward_candidates.gold and manifest_data.stages[2].outputs.has("reward_claim"), "playable run records layouts, capabilities, mandatory gold offer and receipt")
		var restored_manifest := RunManifest.from_snapshot(manifest_data)
		check.call(restored_manifest != null and restored_manifest.canonical_json() == app.director.manifest.canonical_json(), "complete played manifest round trips without losing route and reward outputs")
	# Same-frame queued exit and lethal damage: failure beats transition.
	app.start_demo("fatal-exit")
	await frames(4)
	app.director.complete_stage(app.lifetime.token())
	app.stage.set_completed(true)
	locate(app, app.stage.exit_positions[1])
	app.choose_exit(app.director.offers[1].exit_id)
	app.policy.clock += 1.0
	app._submit_damage(&"fatal", DamageRequest.Kind.ENVIRONMENT, 99.0)
	await frames(4)
	check.call(app.director.state == DemoRunDirector.State.HOME and app.director.stage_index == 1, "same-frame fatal damage cancels queued exit and prioritizes Home")
	check.call(app.meta.snapshot().failed_runs == 1 and app.meta.snapshot().completed_runs == 2, "failure retains only separate session meta summary")
	# Same-frame purchase and death: transaction must never commit.
	app.start_demo("fatal-purchase")
	await frames(4)
	app.director.complete_stage(app.lifetime.token())
	locate(app, app.stage.exit_positions[0])
	app.choose_exit(app.director.offers[0].exit_id)
	await frames(4)
	app.wallet.grant(10, &"fixture_coins")
	locate(app, app.stage.reward_position)
	var saved_shop := app.shop
	var shop_id := app._stage_id("shop_jump")
	app.purchase_item()
	app.policy.clock += 1.0
	app._submit_damage(&"fatal", DamageRequest.Kind.ENVIRONMENT, 99.0)
	await frames(4)
	check.call(saved_shop.quote(shop_id).stock == 1 and app.director.state == DemoRunDirector.State.HOME, "same-frame lethal damage prevents pending shop purchase")
	# Same-frame item claim and death: old offer remains unclaimed.
	app.start_demo("fatal-claim")
	await frames(4)
	app.director.complete_stage(app.lifetime.token())
	locate(app, app.stage.exit_positions[1])
	app.choose_exit(app.director.offers[1].exit_id)
	await frames(4)
	locate(app, app.stage.reward_position)
	var saved_rewards := app.rewards
	var reward_id := app.current_reward.offer_id
	app.claim_item(app.current_reward.candidates[0].stable_id)
	app.policy.clock += 1.0
	app._submit_damage(&"fatal", DamageRequest.Kind.ENVIRONMENT, 99.0)
	await frames(4)
	check.call(not saved_rewards.get_offer(reward_id).claimed and app.director.state == DemoRunDirector.State.HOME, "same-frame lethal damage prevents pending item claim")
	# The Boss and player both reach zero in the same batch; no gold offer.
	app.start_demo("simultaneous-boss-death")
	await frames(4)
	app.director.complete_stage(app.lifetime.token())
	locate(app, app.stage.exit_positions[0])
	app.choose_exit(app.director.offers[0].exit_id)
	await frames(4)
	locate(app, Vector2(1130, 565))
	await frames(2)
	app.choose_exit(app.director.offers[1].exit_id)
	await frames(4)
	var simultaneous_health: HealthState = app.stage.boss.get_node("Encounter").health
	var no_gold_rewards := app.rewards
	var no_gold_id := app._stage_id("gold")
	queue_damage(app, &"boss", simultaneous_health, 99.0, &"same_tick_boss")
	app.policy.clock += 1.0
	app._submit_damage(&"same_tick_player", DamageRequest.Kind.ENVIRONMENT, 99.0)
	await frames(4)
	check.call(app.director.state == DemoRunDirector.State.HOME and no_gold_rewards.get_offer(no_gold_id) == null, "simultaneous Boss/player death resolves failure with no gold reward")
	app.start_demo("fresh")
	await frames(4)
	check.call(app.build.item_ids().is_empty() and app.wallet.balance == 0 and app.controller.actor_resources.health.current == 5.0, "next run starts fresh player resources, build and run coins")
	check.call(app.meta.snapshot().completed_runs == 2 and app.meta.snapshot().failed_runs == 4, "fresh run leaves completed/failed home progress separate")
	app.abandon_run()
	await frames(4)
	app.queue_free()
	await tree.process_frame

func frames(count: int) -> void:
	for index: int in count:
		await tree.physics_frame

func queue_damage(app: DemoApp, target: StringName, health: HealthState, amount: float, event: StringName) -> void:
	var request := DamageRequest.new()
	request.token = app.lifetime.token()
	request.event_id = event
	request.source_id = &"fixture_player_projectile"
	request.target_id = target
	request.amount = amount
	request.health_epoch = health.epoch
	request.actor_epoch = app.lifetime.actor_epoch
	app.policy.submit(request)

func locate(app: DemoApp, position: Vector2) -> void:
	# Fixture teleports invalidate contact history, as real selective returns do.
	app.lifetime.invalidate_actor()
	app.player.reset_at(position)
