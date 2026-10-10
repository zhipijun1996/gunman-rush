extends SceneTree
## Integration fixture injects positions/completion; no claim of manual whole-room traversal.
var assertions := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for unused: int in count:
		await physics_frame
func _run() -> void:
	var app := preload("res://scenes/demo/demo.tscn").instantiate() as DemoApp
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(2)
	check(app.start_plains("exit-confirmation-fixture"), "Generated run starts")
	await frames(6)
	var stage := app.stage as GeneratedDemoStage
	app.player.reset_at(stage.exit_positions[0])
	await frames(2)
	check(app.exit_modal.opened and app.director.stage_index == 1 and not stage.combat_completed(), "Ordinary door prompts while enemies are still alive without switching or reward")
	app._stay_generated_exit()
	app.player.reset_at(stage.spawn)
	await frames(2)
	app._complete_room()
	for pickup: Dictionary in stage.pickups:
		pickup.claimed = true # Isolate exit rewards from proximity pickup fixtures.
	var offers := stage.exits.duplicate()
	app.player.reset_at(stage.exit_positions[0])
	var coins := app.wallet.balance
	var keyboard := app.player.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter
	var gamepad := app.player.get_node("GamepadAdapter") as GamepadAdapter
	keyboard._shoot_edge(true, Vector2.DOWN)
	gamepad.state = GamepadAdapter.AimState.ARMED
	await frames(2)
	check(app.exit_modal.opened and paused, "Approach opens paused confirmation")
	check(not app.reward_modal.opened and app.director.stage_index == 1, "Approach cannot grant items or switch room")
	check(not keyboard._mouse_armed and gamepad.state == GamepadAdapter.AimState.WAIT_NEUTRAL and not app.controller.router.aim_engaged, "Prompt cancels armed mouse/stick gestures without a release shot")
	check(app.wallet.balance == coins and app._pending_exit.is_empty(), "Approach does not settle reward or lock final route")
	app.exit_modal.stayed.emit()
	check(not paused and not app.exit_modal.opened, "Stay restores gameplay")
	await frames(3)
	check(not app.exit_modal.opened and app.wallet.balance == coins, "Same proximity cannot loop or award on Stay")
	app.player.reset_at(stage.spawn)
	await frames(3)
	app.player.reset_at(stage.exit_positions[1])
	await frames(2)
	check(app.exit_modal.opened and app._offered_exit == offers[1].exit_id, "Other exit presents its own route")
	app.exit_modal.entered.emit()
	check(not app.exit_modal.opened, "Enter UI signal commits selected route")
	check(not app._confirm_generated_exit(), "Duplicate confirmation rejected")
	await frames(6)
	check(app.director.stage_index == 2 and app.director.stage_type_id == offers[1].next_stage_type_id, "One confirmation changes stage exactly once to chosen type")
	check(app.wallet.balance == coins + 10, "Combat room reward granted exactly once at confirmation")
	stage = app.stage as GeneratedDemoStage
	if stage == null:
		push_error("Exit fixture aborted after failed next-stage generation: " + app._status)
		quit(1)
		return
	app._complete_room()
	app.player.reset_at(stage.exit_positions[0])
	await frames(2)
	check(app.exit_modal.opened, "Second stage has confirmation")
	var old_manifest: Dictionary = stage.generated.manifest.duplicate(true)
	var prior_balance := app.wallet.balance
	app._environment_return()
	check(not app.exit_modal.opened and not app.reward_modal.opened and not paused, "Environmental return cancels pending UI")
	check(not app._confirm_generated_exit(), "Old confirmation cannot settle after return")
	check(app.wallet.balance == prior_balance and stage.generated.manifest == old_manifest, "Return preserves reward ledger and generated map")
	app.player.reset_at(stage.exit_positions[0])
	await frames(2)
	check(app.exit_modal.opened, "Return can approach again safely")
	app.lifetime.invalidate_actor()
	check(not app._confirm_generated_exit() and not paused, "Stale actor epoch cancels confirmation")
	app.player.reset_at(stage.exit_positions[1])
	await frames(2)
	check(app.exit_modal.opened, "New actor epoch may receive a fresh prompt")
	app._stay_generated_exit()
	app.simple_reward = null
	var candidates: Array[ItemDefinition] = [app.JUMP_ITEM, app.SHOT_ITEM]
	app.current_reward = app.rewards.create_offer(&"fixture_item_exit", candidates, &"fixture_item_source")
	app.player.reset_at(stage.spawn)
	await frames(2)
	app.player.reset_at(stage.exit_positions[0])
	await frames(2)
	check(app.exit_modal.opened and not app.reward_modal.opened, "Item exit first shows confirmation, not item claim")
	check(app._confirm_generated_exit() and app.reward_modal.opened and paused, "Confirmed item exit opens two-choice reward UI")
	check(not app.rewards.get_offer(app.current_reward.offer_id).claimed, "Confirm alone cannot award both candidates")
	check(not app._confirm_generated_exit() and app.reward_modal.opened and paused, "Duplicate Enter cannot close the pending item choice")
	app._environment_return()
	check(not app.reward_modal.opened and not app.rewards.get_offer(app.current_reward.offer_id).claimed, "Return cancels pending choice without granting or resetting offer")
	app.player.reset_at(stage.exit_positions[0])
	await frames(2)
	check(app._confirm_generated_exit(), "Same surviving offer may be confirmed after safe return")
	check(app._claim_modal_item(app.JUMP_ITEM.stable_id), "One candidate is granted")
	check(not app._claim_modal_item(app.SHOT_ITEM.stable_id), "Other candidate rejected after settlement")
	await frames(6)
	check(app.director.stage_index == 3 and app.build.item_ids().has(app.JUMP_ITEM.stable_id), "One selected item advances exactly once")
	stage = app.stage as GeneratedDemoStage
	if stage == null:
		push_error("Exit fixture aborted after failed next-stage generation: " + app._status)
		quit(1)
		return
	app._complete_room()
	app.simple_reward = null
	# Inject final-stage director state; full eight-stage traversal has its own fixture.
	app.director.stage_index = 8
	app.director.stage_type_id = &"boss"
	app.current_reward = app.rewards.create_gold_offer(&"fixture_gold", app.GOLD_ITEM, &"fixture_boss_source")
	app.player.reset_at(stage.reward_position)
	check(app._offer_generated_exit(&"boss_home"), "Boss reward requires explicit Home confirmation")
	check(app._confirm_generated_exit() and app.reward_modal.opened, "Home confirmation shows guaranteed GOLD choice")
	check(app._claim_modal_item(app.GOLD_ITEM.stable_id), "GOLD choice settles biome once")
	check(not app._claim_modal_item(app.GOLD_ITEM.stable_id), "Duplicate GOLD claim rejected")
	await frames(6)
	check(app.director.state == DemoRunDirector.State.HOME and app.meta.snapshot().completed_biomes == 1, "Gold returns Home and records one completed biome")
	check(app.start_plains("exit-fatal-batch-fixture"), "Fresh run for death priority")
	await frames(46)
	stage = app.stage as GeneratedDemoStage
	if stage == null:
		push_error("Exit fixture aborted after failed next-stage generation: " + app._status)
		quit(1)
		return
	app._complete_room()
	app.player.reset_at(stage.exit_positions[0])
	app.choose_exit(stage.exits[0].exit_id)
	var damage := DamageRequest.new()
	damage.token = app.lifetime.token()
	damage.event_id = &"fatal_exit_batch"
	damage.source_id = &"fixture_fatal"
	damage.target_id = &"player"
	damage.amount = app.controller.actor_resources.health.capacity
	damage.health_epoch = app.controller.actor_resources.health.epoch
	damage.actor_epoch = app.lifetime.actor_epoch
	app.policy.submit(damage)
	await frames(6)
	check(not app.exit_modal.opened and not app.reward_modal.opened and app.director.state == DemoRunDirector.State.HOME, "Same-frame fatal damage wins over queued exit and returns Home")
	check(app._pending_exit.is_empty(), "Death clears route lock")
	if "--verify-failure" in OS.get_cmdline_user_args():
		check(false, "Intentional failure exit probe")
	print("GENERATED EXIT CONFIRMATION: %s assertions, %s failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
