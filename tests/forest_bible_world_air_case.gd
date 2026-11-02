extends "res://tests/forest_depth_air_chain_case.gd"
## F05 uses lawful walk-off and a descending cast. Other phrases reuse the
## unchanged real input driver. No initial or midroute position override.
var descending_cast := false
func drive(trace: Node, leg: Dictionary) -> void:
	# Current base-one R/HANG phrases use the real held first jump. The common
	# tap remains unchanged for every other consumer and policy.
	if str(leg.get("kind","")) == "hanging_chain" and trace.phase == "air_chain_launch" and trace.age == 6 and not program.is_empty() and str(program[0].action) == "R":
		var current_free: bool = trace.controller.shot_energy != null and trace.controller.shot_energy.definition.resource_path == "res://game/player/resources/demo_ui_01/time_energy_v2.tres" and not trace.controller.shot_energy.definition.shooting_consumes_energy and trace.player.tuning.max_air_shots == 1 and trace.controller.shoot_ability.weapon.id == &"pulse_gun" and trace.controller.shoot_ability.weapon.tier == 1
		if current_free:
			trace.jump(true)
			trace.event("Bible_current_first_R_jump_held", {"source_program":source_program.duplicate(true), "executed_input":"hold_jump_until_actual_first_shot_burst_completed", "source_release_frame":6, "grounded":trace.player.is_on_floor(), "position":trace.pair(trace.player.global_position)})
			return
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
