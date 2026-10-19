extends "res://tests/level_formal_trace.gd"
## Real Router/Motor traversal of the two observer-selected formal thin banks.
## Local completion is explicitly distinct from campaign/registered growth route.
func run_route() -> void:
	if trace_cancelled():return
	var inventory := PlainsTerrainFamilySampler.inventory(formal_stage)
	var groups := PlainsTerrainFamilySampler.groups(inventory.rooted)
	groups.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.bounds.get_center().distance_to(formal_stage.spawn)<b.bounds.get_center().distance_to(formal_stage.spawn))
	if groups.size()<2:
		finish(false,"formal_local_missing_two_banks");return
	var entry: Rect2=groups[0].bounds
	var receiver: Rect2=groups[1].bounds
	current_edge="formal_thin_banks_outbound"
	var start := trace_ticks+1
	var ok := await move_to(entry.end.x-30)
	if ok:ok=await jump_point(Vector2(receiver.position.x+40,receiver.position.y-18))
	if ok:ok=await move_to(receiver.position.x+minf(120,receiver.size.x*.3))
	if trace_cancelled():return
	controller.router.set_move_axis(-.01);await tick(2);controller.router.set_move_axis(0)
	await tick(90)
	observed_edges.append({"id":current_edge,"forward":true,"start_tick":start,"end_tick":trace_ticks,"reached":ok and motor.is_on_floor(),"scope":"real receiver landing and 1.5 second lookback"})
	if not ok or not motor.is_on_floor():finish(false,"formal_local_receiver_failed");return
	current_edge="formal_thin_banks_return"
	start=trace_ticks+1
	ok=await move_to(receiver.position.x+30)
	if ok:ok=await jump_point(Vector2(entry.end.x-40,entry.position.y-18))
	if trace_cancelled():return
	controller.router.set_move_axis(0);await tick(90)
	observed_edges.append({"id":current_edge,"forward":false,"start_tick":start,"end_tick":trace_ticks,"reached":ok and motor.is_on_floor(),"scope":"real return and grounded observation"})
	if trace_cancelled():return
	finish(ok and motor.is_on_floor() and _recovery_serial==0,"route_target_reached" if ok and motor.is_on_floor() and _recovery_serial==0 else "formal_local_return_failed")
