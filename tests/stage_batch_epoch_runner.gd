extends SceneTree
## Deterministic fixture: director selections/HP injected, no manual traversal claim.
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
	for _index: int in count:
		await physics_frame
func _run() -> void:
	var app := preload("res://scenes/demo/demo.tscn").instantiate() as DemoApp
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(2)
	check(app.start_demo("stage-batch-epoch", true), "Formal fixed eight-stage fixture starts")
	await frames(6)
	var before_actor := app.lifetime.actor_epoch
	app._environment_return()
	check(app.lifetime.actor_epoch > before_actor, "Segment return advances actor epoch within the same stage")
	var damage := DamageRequest.new()
	damage.token = app.lifetime.token()
	damage.event_id = &"post_return_enemy_damage"
	damage.source_id = &"fixture"
	damage.target_id = &"drone"
	damage.amount = app._completion_target.capacity
	damage.health_epoch = app._completion_target.epoch
	damage.actor_epoch = app.lifetime.actor_epoch
	check(app.policy.submit(damage), "Same-stage damage remains accepted after actor epoch changes")
	app.policy.resolve_batch()
	check(app.director.stage_complete, "Current policy still completes room after segment return")
	var empty_results: Array[DamageResult] = []
	for index: int in range(1, 8):
		check(app.director.stage_index == index and not app._stage_pending, "Current stage finishes loading")
		app._complete_room()
		var old_policy := app.policy
		var old_stage_epoch := app.lifetime.stage_epoch
		var old_run_epoch := app.lifetime.epoch
		# Make the old completion target terminal; its empty batch is maximally unsafe.
		if app._completion_target != null:
			app._completion_target.current = 0
		var offer: ExitOffer = app.director.offers[0]
		check(app.director.select_exit(app.lifetime.token(), offer.exit_id, StringName("epoch_exit_%s" % index)).accepted(), "Director advances synchronously")
		check(app._stage_pending and not app.director.stage_complete, "Next stage starts incomplete before deferred load")
		old_policy.batch_resolved.emit(empty_results)
		app._damage_resolved([])
		check(not app.director.stage_complete and app.current_reward == null or (not app.director.stage_complete and not app.current_reward.gold), "Old batch during pending load cannot complete or award next stage")
		await frames(6)
		check(not app._stage_pending and app.director.stage_index == index + 1, "Next stage loads normally")
		var ordinary_open := app.director.stage_type_id == &"combat"
		check(app.director.stage_complete == ordinary_open, "Fixed combat access opens independently; other fixtures retain their own completion goals")
		# A different live policy tests source/epoch rejection independently of pending flag.
		var foreign := FrameDamagePolicy.new()
		app._damage_resolved([], foreign, old_stage_epoch, old_run_epoch)
		check(app.director.stage_complete == ordinary_open, "Foreign old-epoch callback cannot change access or reward/Boss completion")
		foreign.free()
		if index == 7:
			var encounter := app.stage.boss.get_node("Encounter") as BossEncounter
			check(not encounter.health.terminal and app.current_reward == null, "Boss8 cannot be defeated by old terminal completion target")
	app.abandon_run()
	await frames(4)
	if "--verify-failure" in OS.get_cmdline_user_args():
		check(false, "Intentional failure probe")
	print("STAGE BATCH EPOCH: %s assertions, %s failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
