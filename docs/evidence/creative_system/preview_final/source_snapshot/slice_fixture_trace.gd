extends "res://tests/root_bell_formal_trace.gd"
## Explicit scene-preview entry fixture, then real original Router/Motor inputs.
## This starts at the actual existing module entry; no approach/campaign claim.
func attach(application: DemoApp, selected_strategy: String, wait_ticks: int, selected_policy: String = "kill_from_bank_v1") -> bool:
	var formal:=application.stage as PlainsRegionStage
	var facts:Dictionary=formal.generated.manifest.root_bell_admission.physical_facts
	var edge_id:=str(facts.edge)
	for edge:Dictionary in formal.generated.manifest.connections:
		if str(edge.id)==edge_id:
			var module:=formal.assembler.modules[int(edge.modules[0])] as PlatformingModule
			application.player.reset_at(module.world_entry())
			application._run_camera.snap_to_target()
			break
	return super.attach(application,selected_strategy,wait_ticks,selected_policy)
func run_route() -> void:
	_enemy_policy_busy=true
	current_edge="explicit_art_preview_real_gear_and_rootbell"
	begin_case("preview_existing_gear_module")
	await tick(30)
	var target:PlatformingModule
	var edge_id:=str(stage.manifest.root_bell_admission.physical_facts.edge)
	for edge:Dictionary in stage.manifest.connections:
		if str(edge.id)==edge_id:target=stage.modules[int(edge.modules[0])];break
	if target==null or not await forward_module(target):end_case(false);finish(false,"preview_gear_failed");return
	if not end_case(true):finish(false,"preview_gear_failed");return
	begin_case("preview_live_enemy_warning_and_jump")
	if not await move_to(_root_home.x-150,300) or not await warning():end_case(false);finish(false,"preview_warning_failed");return
	if not await jump_point(Vector2(_root_home.x+220,_floor_y-18)):end_case(false);finish(false,"preview_jump_failed");return
	if not end_case(true):finish(false,"preview_jump_failed");return
	begin_case("preview_return_and_real_projectile")
	await wait_for_safe_return_approach(_root_home.x+90)
	if not await move_to(_root_home.x+90,160) or not await jump_point(Vector2(_root_home.x-240,_floor_y-18)):end_case(false);finish(false,"preview_return_failed");return
	if not await move_to(_root_home.x-150,180) or not await warning():end_case(false);finish(false,"preview_shot_warning_failed");return
	var hp:=root_actor.health.current
	var aim:Vector2=(motor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter).world_direction(motor.get_canvas_transform()*root_motor.global_position)
	controller.router.request_action(&"shoot_release",aim)
	for unused:int in 80:
		await tick()
		if root_actor.health.current<hp:break
	await tick(60)
	var ok:=root_actor.health.current<hp
	end_case(ok)
	if ok:
		ok = await move_to(_root_home.x-280,180)
		controller.router.set_move_axis(0)
		if trace_ticks<1200: await tick(1200-trace_ticks)
	observed_edges.append({"id":current_edge,"start_tick":1,"end_tick":trace_ticks,"reached":ok,"scope":"explicit module-entry fixture then real original movement, gear avoidance, enemy warning/jump/return and projectile; not campaign traversal or full regression"})
	finish(ok,"art_preview_complete" if ok else "preview_projectile_failed")
