extends "res://tests/forest_depth_air_chain_case.gd"
## F05 uses lawful walk-off and a descending cast. Other phrases reuse the
## unchanged real input driver. No initial or midroute position override.
var descending_cast := false
func drive(trace: Node, leg: Dictionary) -> void:
	if str(leg.get("geometry_instance","")) != "bible_backbranch":
		super.drive(trace,leg)
		return
	if active_leg != int(trace.leg_index):
		descending_cast = false
		# Initialises the original case and performs the first alignment frame.
		super.drive(trace,leg)
		return
	if trace.age > 400:
		trace.fail("Bible_backbranch_bounded_phase/"+str(trace.phase)); return
	if trace.phase == "align":
		trace.controller.router.set_move_axis(clampf((start.x-trace.player.global_position.x)/12.0,-1.0,1.0))
		trace.stable = trace.stable+1 if trace.at_destination(start,entry_support) and absf(trace.player.velocity.x)<1.0 else 0
		if trace.stable >= 13:
			trace.jump(false)
			trace.event("bible_F05_grounded_departure",{"position":trace.pair(trace.player.global_position),"entry_support":entry_support,"method":"ordinary_walk_off_outside_edge"})
			trace.set_phase("bible_outside_drop")
		return
	if trace.phase == "bible_outside_drop":
		var departure: Dictionary = instance_data.local_geometry.departure
		var outside: Vector2 = trace.point(departure.path[-1])
		trace.controller.router.set_move_axis(clampf((outside.x-trace.player.global_position.x)/12.0,-1.0,1.0))
		trace.jump(false)
		if not trace.player.is_on_floor() and trace.player.global_position.y >= float(leg.first_hook_requires_descent_below):
			descending_cast = true
			trace.event("bible_F05_actual_descending_side_cast",{"position":trace.pair(trace.player.global_position),"velocity":trace.pair(trace.player.velocity),"grounded":trace.player.is_on_floor(),"outside_body":trace.player.global_position.x-12.0 > float(trace.platform(entry_support).rect[0])+float(trace.platform(entry_support).rect[2])})
			_submit(trace)
		return
	if trace.phase == "air_chain_receive" and not descending_cast:
		trace.fail("Bible_backbranch_missing_descending_cast"); return
	super.drive(trace,leg)
