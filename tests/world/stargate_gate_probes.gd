extends "res://tests/world/stargate_trial.gd"
## Local bypass counterexamples use the same air chain and no synthetic resource changes.
var minimum_y := INF

func jump_to_apex(target_x: float) -> void:
	await press_jump()
	for i: int in 75:
		var dx := target_x-app.player.position.x
		controls(signf(dx) if absf(dx)>3 else 0)
		await ticks(1)
		minimum_y=minf(minimum_y,app.player.position.y)
		if i>8 and app.player.normal_velocity.y>=0 and app.controller.traversal.state==&"free": return
	check(false,"real jump reaches an ordinary apex")

func run() -> void:
	var without := "W"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--without="): without=arg.trim_prefix("--without=")
	if without not in ["W","D"]: printerr("Use --without=W or --without=D");quit(2);return
	output="res://build/stargate_without_"+without.to_lower()
	if not await setup_trial(): await finish();return
	# Explicit capability counterexample is established on the initial real ground.
	var candidate:=app.state.value.duplicate(true)
	candidate.flags.erase(without)
	check(app.state.commit(candidate,app.state.revision),"isolated no-"+without+" fixture")
	app._apply_capabilities()
	if not await lower_launch_route(): await finish();return
	check(app.controller.action_resources.shot_charges==0,"mandatory lower light crossing leaves no spare recoil shot")
	minimum_y=app.player.position.y
	if without=="W":
		await jump_to_apex(800)
		await jump_to_apex(800)
		controls(0)
		var target:=Vector2(800,1024)
		var distance: float=(target-app.player.position-Vector2(0,-6)).length()
		var max_capture: float=app.controller.traversal.definition.hook_range+app.controller.traversal.definition.hook_capture_radius+12.0
		check(distance>max_capture,"maximal held H-departure + D apex remains outside high-ring range including both capture radii")
		app.controller.router.set_jump_held(&"keyboard_mouse",false)
		app.controller.router.request_action(&"grapple",(target-app.player.position-Vector2(0,-6)).normalized())
		var reached:=false
		for i: int in 40:
			await ticks(1)
			if app.controller.traversal.state==&"hook_hang" and app.controller.traversal.hook_tip.distance_to(target)<16: reached=true;break
		validation_results.no_w_direct_bypass=check(not reached and count_wall_jumps==0,"real max-height D-to-H alternative cannot skip the raised W wall")
		validation_results.hook_origin_distance=distance
		validation_results.maximum_capture_distance=max_capture
	else:
		await jump_to_apex(932)
		var wall: Rect2=app.room.climbable_walls[0]
		check(minimum_y-18.0>wall.end.y,"H-anchor jump alone leaves the whole body below the raised W surface")
		await press_jump()
		controls(1)
		var attached:=false
		for i: int in 18:
			await ticks(1)
			if app.controller.traversal.state==&"wall_attach": attached=true
		validation_results.no_d_wall_bypass=check(not attached and count_air_jumps==0 and count_wall_jumps==0,"actual missing-D input cannot reach the W surface or create another air jump")
	validation_results.minimum_body_center_y=minimum_y
	mark("no-"+without+" counterexample")
	await finish()
