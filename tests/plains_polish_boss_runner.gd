extends "res://tests/windkeeper_runner.gd"
## New geometry/state regression; explicit position fixtures are labelled.
func run() -> void:
	await fixture(Vector2(350,452))
	check(encounter.mode == &"intro" and not encounter.core_open, "intro gates boss attacks")
	var intro_clock := encounter.clock
	paused = true
	await process_frame
	await process_frame
	check(encounter.clock == intro_clock, "pause freezes intro without time-scale changes")
	paused = false
	encounter.skip_intro()
	check(encounter.mode == &"observe", "skip enters the same legal attack state")
	encounter.health.apply_damage(ActorResourceRequest.new(&"third_fixture",encounter.health.epoch,8,encounter.health.get_instance_id()))
	await frames(310)
	check(arena_consumer.broken, "safe shelf permits preannounced ground withdrawal")
	var previous := boss.position.x
	var visits := {}
	for tick: int in 2600:
		await frames(1)
		check(boss.position.x >= previous - .001, "missing all windows never teleports backwards")
		previous = boss.position.x
		visits[encounter.mode] = true
	check(encounter.chase_segment == 2 and absf(boss.position.x-(encounter.arena.right_x-85)) < 3, "missed three piers holds the final pier inside arena")
	check(visits.has(&"pier_warning") and visits.has(&"pier_impact") and visits.has(&"pier_open") and visits.has(&"final_hold"), "complete final-pier cycle remains retryable")
	for state: StringName in [&"observe",&"chase",&"pier_warning",&"pier_impact",&"pier_open",&"final_hold",&"next_pier"]:
		encounter._enter(state,2.0)
		var position_before := boss.position
		var clock_before := encounter.clock
		var epoch_before := encounter.attack_epoch
		paused = true
		await process_frame
		await process_frame
		check(encounter.mode == state and encounter.clock == clock_before and boss.position == position_before and encounter.attack_epoch == epoch_before, "pause preserves exact P3 state %s" % state)
		paused = false
		encounter.cancel_pending_attacks()
		check(encounter.stage_phase == 3 and encounter.chase_segment == 2 and boss.position == position_before and arena_consumer.broken, "segment cancel preserves progression %s" % state)
	# Actual projectile paths from both legal shelves to the final bell.
	for at: Vector2 in [Vector2(640,452),Vector2(870,452)]:
		await fixture(at)
		encounter.health.apply_damage(ActorResourceRequest.new(&"core_path_fixture",encounter.health.epoch,8,encounter.health.get_instance_id()))
		await frames(310)
		encounter.chase_segment = 2
		boss.position.x = encounter.arena.right_x-85 # explicit attack-path fixture, not a traversal claim
		encounter._enter(&"pier_open",4)
		await frames(2)
		await shoot_core()
	# Each recorded victory point has real supporting collision and room to stand.
	for pier: int in 3:
		encounter.chase_segment = pier
		var stand := encounter.reward_stand_position()
		var ray := PhysicsRayQueryParameters2D.create(stand,stand+Vector2(0,25),1,[player.get_rid()])
		check(not player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(), "reward pier%s has actual bridge support" % pier)
	# Ground, shelf, air triggers retain input and cancel old attacks before movement.
	for at: Vector2 in [Vector2(420,582),Vector2(350,452),Vector2(500,390)]:
		await fixture(at)
		encounter._wave(1)
		var old := boss.position
		encounter.health.apply_damage(ActorResourceRequest.new(&"transition_fixture",encounter.health.epoch,8,encounter.health.get_instance_id()))
		await frames(2)
		check(encounter.mode == &"phase_transition" and not encounter.core_open and encounter._projectiles.is_empty(), "transition cancels old attacks and closes bell at %s" % at)
		check(boss.position == old and not arena_consumer.broken and controller.active, "prewarning preserves ground and input at %s" % at)
		await frames(75)
		check(boss.position.distance_to(old) <= 25, "postwarning movement is bounded rather than teleporting")
	# App-specific lethal-frame/reward policies are exercised by windkeeper_app_runner.
	world.free()
	await process_frame
	if "--failure-probe" in OS.get_cmdline_user_args(): check(false,"intentional new regression failure probe")
	print("PLAINS POLISH BOSS: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)
