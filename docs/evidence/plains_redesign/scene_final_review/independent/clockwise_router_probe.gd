extends "res://tests/plains_redesign_scene_runner.gd"
## Independent finite alternate policy. No production files, actor transforms,
## physics, resources, capabilities, enemy states or phases are modified.
func run() -> void:
	await run_case(2,"fast","clockwise_airborne_bypass")
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"independent ignored legal-Router alternative, single canonical seed; no fairness/fun/device extrapolation","assertions":assertions,"failures":failures,"cases":cases})+"\n")
	file.close()
	print("INDEPENDENT CLOCKWISE PROBE: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures==0 else 1)

func custom_route(trace, mode: String) -> void:
	var ok:bool=await trace.tutorial()
	for goal:String in ["area_3_3","area_4_3","area_4_2"]:
		if ok:ok=await trace.follow_to(goal)
	var begin:int=trace.trace_ticks
	var before:Dictionary=trace.runtime_snapshot(true)
	var health_before:float=trace.controller.actor_resources.health.current
	var prefix_policy:String=trace.encounter_policy
	if ok:
		# Preserve the actual active enemies. Replace only bank-wait driving on
		# this one edge by boat traversal and a deliberate airborne bypass.
		trace.encounter_policy="blind_legacy"
		trace.current_edge="independent_clockwise_airborne_bypass"
		var chosen:PlatformingModule=trace.named("plains/passage/area_3_2/area_4_2_0")
		var ferry:ModuleMovingPlatform=chosen.moving_platforms[0]
		var driver=load("res://tests/branch_module_driver.gd").new()
		driver.module=chosen;driver.motor=trace.motor;driver.controller=trace.controller;driver.tick_callback=trace.tick;driver.check=trace.check
		ok=await trace.move_to(chosen.position.x+670)
		var endpoint:Vector2=chosen.to_global(ferry.definition.finish)
		var docked:=false
		for unused:int in 900:
			if not ok:break
			var elapsed:float=fposmod(chosen.clock+ferry.definition.initial_phase*ferry.definition.period(),ferry.definition.period())
			var fresh:bool=elapsed>ferry.definition.dwell_duration+ferry.definition.travel_duration and elapsed<ferry.definition.dwell_duration+ferry.definition.travel_duration+.25
			if fresh and ferry.global_position.distance_to(endpoint)<3:docked=true;break
			await trace.tick()
		ok=ok and docked
		if ok:
			trace.controller.router.request_action(&"jump")
			var boarded:=false
			for frame:int in 110:
				trace.controller.router.set_move_axis(clampf((ferry.global_position.x-trace.motor.global_position.x)/5.5,-1,1))
				await trace.tick()
				if frame>5 and trace.motor.is_on_floor() and absf(trace.motor.global_position.y+18-(ferry.global_position.y-ferry.definition.size.y*.5))<3:boarded=true;break
			trace.controller.router.request_action(&"jump_release")
			ok=boarded
		if ok:
			var destination:Vector2=chosen.to_global(ferry.definition.start)
			for unused:int in 900:
				trace.controller.router.set_move_axis(clampf((ferry.global_position.x-trace.motor.global_position.x)/5.5,-1,1))
				await trace.tick()
				if ferry.global_position.distance_to(destination)<3:break
			trace.controller.router.set_move_axis(0)
			trace.controller.router.request_action(&"jump_release")
			await trace.tick(6)
			ok=await driver.jump_to(chosen.position+Vector2(160,282))
		if ok:
			# Actual raw sentry is at(4270,510), fan at(4620,375).
			# Left dock(4500,510) is outside sentry activation. Jump across its
			# horizontal firing line instead of waiting motionless for bank fire.
			trace.controller.router.request_action(&"jump")
			var landed:=false
			for frame:int in 180:
				trace.controller.router.set_move_axis(clampf((4140-trace.motor.global_position.x)/5.5,-1,1))
				if frame==14:trace.controller.router.request_action(&"shoot_release",Vector2(1,1).normalized())
				if frame==18:trace.controller.router.request_action(&"jump_release")
				await trace.tick()
				if frame>18 and trace.motor.is_on_floor():landed=true;break
			trace.controller.router.request_action(&"jump_release")
			ok=landed and absf(trace.motor.global_position.y-510)<2 and await trace.move_to(4140)
			if ok:trace.current_area="area_3_2"
		if ok:ok=await trace.follow_to("area_3_3")
	route_comparison={"path":["area_3_3","area_4_3","area_4_2","area_3_2","area_3_3"],"alternate_start":begin,"end_tick":trace.trace_ticks,"health_before_reverse":health_before,"health_after":trace.controller.actor_resources.health.current,"prefix_policy":prefix_policy,"alternate":"same real boat; left-dock airborne diagonal-recoil bypass of sentry; no additional kill bank","runtime_before":before,"runtime_after":trace.runtime_snapshot(true),"reached":ok,"actual_policy_observations":trace.policy_observations,"resource_receipts":trace.resource_receipts}
	trace.finish(ok,"route_target_reached" if ok else "independent_alternative_failed")
