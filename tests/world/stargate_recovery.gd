extends "res://tests/world/stargate_trial.gd"
## Separate failure/cooldown proof. Every tested anchor is reached by the real lower route.
func run() -> void:
	output="res://build/stargate_recovery"
	if not await setup_trial(): await finish();return
	if not await lower_route(): await finish();return
	await walk_ground(720,"recovery fixture relay")
	while app.q_guard.cooldown>0: await ticks(1)
	var cycle_before: int=app.state.value.cycle
	# Spend Q on a real upward recoil, then land well before its 2 second cooldown.
	await press_jump()
	await ticks(1)
	app.controller.router.request_action(&"shoot_release",Vector2.DOWN)
	await ticks(10)
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
	var returned_to_ground := false
	for i: int in 90:
		await ticks(1)
		if app.player.is_on_floor(): returned_to_ground=true;break
	await ticks(2)
	validation_results.landing_preserves_cooldown=check(returned_to_ground and app.q_guard.landing_ready and app.q_guard.cooldown>0.2,"real relay landing restores Q qualification but preserves remaining cooldown")
	mark("Q ground ready with cooldown")
	var cooldown_before := app.q_guard.cooldown
	app.controller.router.request_action(&"shoot_release",Vector2.LEFT)
	await ticks(2)
	validation_results.cooldown_blocks_protection=check(not app.q_guard.active and app.q_guard.cooldown<cooldown_before and app.q_guard.cooldown>0,"another legal shot before cooldown grants no Q protection or cooldown reset")
	await ticks(12)
	await walk_ground(720,"relay after cooldown counterexample")
	while app.q_guard.cooldown>0: await ticks(1)
	if not await hook(Vector2(704,1024),"recovery upper launch"): await finish();return
	if not await burst(Vector2.RIGHT,"recovery upper Q left"): await finish();return
	if not await hook(Vector2(496,1024),"recovery left hang"): await finish();return
	while app.q_guard.cooldown>0: await ticks(1)
	validation_results.air_wait_does_not_rearm=check(not app.q_guard.landing_ready and not app.player.is_on_floor() and app.controller.action_resources.shot_charges==0,"waiting on a hanging ring restores neither Q ground qualification nor ammunition")
	mark("air cooldown expired without rearm")
	# Deliberately jump back into the visible phase spine with no active Q.
	controls(1)
	await press_jump()
	await ticks(6)
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
	var failure_frame := frame
	var reset_frame := -1
	for i: int in 100:
		await ticks(1)
		if app.controller.actor_resources.health.current<start_hp:
			controls(0)
			if app.player.position.distance_to(Vector2(720,1198))<8:
				reset_frame=frame;break
	await ticks(4)
	validation_results.correct_segment_return=check(reset_frame>=0 and app.controller.actor_resources.health.current==start_hp-1 and app.entry_anchor.distance_to(Vector2(720,1198))<2 and app.player.position.distance_to(Vector2(720,1198))<8,"phase failure costs exactly one HP and returns to the physically reached relay")
	validation_results.no_rest_reset=check(int(app.state.value.cycle)==cycle_before and not app.state.has("starbridge_v12_return_open"),"terrain return preserves rest cycle and does not unlock the finish shortcut")
	validation_results.failure_probe_frames=reset_frame-failure_frame if reset_frame>=0 else -1
	mark("relay failure return")
	await picture("recovery-normal-camera")
	await finish()
