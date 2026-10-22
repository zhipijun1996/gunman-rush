extends "res://tests/forest_interwoven_crown_combat_case.gd"
## V15 test-only admission of the unchanged historical real-input combat pilot.
## Basis SHA256 2eb6d8256b26a1a8b6f807a85b5e7004d4f4a13ab09d29425cad04f9b58b4ec8.
## Only drive layout eligibility is extended; shared helpers/state stay inherited.
func drive(trace: Node, leg: Dictionary) -> bool:
	if trace.manifest.get("layout_version") not in ["forest-interwoven-canopy-v13","forest-fruit-routes-v14","forest-bible-world-v15","forest-varied-bible-v17"]:return false
	var edge_id := str(leg.get("edge_id",""))
	var enemy_id := "root_spiral_bark_keeper" if edge_id == "lower_fork_approach" else "upper_spiral_bark_keeper" if edge_id == "canopy_fork_approach" else ""
	if enemy_id.is_empty() or completed_encounters.has(enemy_id):return false
	# A human aim hold is an in-flight input, not a fired shot. Let the real
	# adapter release it before this instant-input pilot requests another.
	if not str(trace.get("_aim_kind")).is_empty(): return true
	if enemy_id == "upper_spiral_bark_keeper":
		# The existing two-action route already uses a higher jump over the live guard.
		# Preserve that strategy and its live-enemy clearance evidence unchanged.
		var flight: Dictionary = {}
		for edge: Dictionary in trace.manifest.connections:
			if str(edge.id) == "canopy_fork_flight":flight=edge;break
		if flight.get("action_program",[]).size() != 3:return false
	if encounter_id != enemy_id:
		encounter_id=enemy_id;target=null;requests=0;returned=false;return_stable=0;last_drop=-1000
		return_goal=trace.point(leg.landing)
		return_support="root_spiral__crown" if enemy_id == "root_spiral_bark_keeper" else "upper_spiral__crown"
	if not is_instance_valid(target):
		for index: int in trace.stage.enemy_manifest.size():
			if str(trace.stage.enemy_manifest[index].id) == enemy_id:target=trace.stage.enemies[index].get_node("Actor") as EnemyActor
		if not is_instance_valid(target) or target.health.terminal:return false
		started=int(trace.tick)
		trace.event("interwoven_crown_combat_start",{"enemy_id":enemy_id,"origin":trace.pair(trace.player.global_position)})
	if int(trace.tick)-started > 600:
		trace.fail("interwoven_crown_combat_budget");return true
	if trace.controller.actor_resources.health.terminal:
		trace.fail("interwoven_crown_combat_actual_death");return true
	var position: Vector2=trace.player.global_position
	if target.health.terminal:
		trace.jump(false)
		trace.controller.router.set_move_axis(clampf((return_goal.x-position.x)/12.0,-1.0,1.0))
		if trace.player.is_on_floor() and position.y < return_goal.y-20.0 and int(trace.tick)-last_drop >= 20:
			trace.request(&"drop_through");last_drop=int(trace.tick)
		return_stable=return_stable+1 if trace.at_destination(return_goal,return_support) else 0
		if return_stable >= 12:
			trace.event("interwoven_crown_combat_return",{"accepted_requests":requests,"enemy_health":target.health.current,"health":trace.controller.actor_resources.health.current,"full_body_frames":return_stable})
			trace.controller.router.set_move_axis(0);returned=true;completed_encounters[encounter_id]=true
		return true
	var enemy: Vector2=target.motor.global_position
	var side := signf(enemy.x-position.x)
	if trace.player.is_on_floor():
		var bank := enemy.x-side*76.0
		trace.controller.router.set_move_axis(clampf((bank-position.x)/12.0,-1.0,1.0))
		if absf(enemy.x-position.x) <= 80.0 and trace.player.recoil_burst_remaining <= 0.0:
			trace.jump(true)
		return true
	trace.controller.router.set_move_axis(clampf((enemy.x-position.x)/12.0,-1.0,1.0))
	if trace.player.normal_velocity.y >= 0.0:trace.jump(false)
	var offset := enemy-position
	if offset.y > 40.0 and absf(offset.x) < 16.0 and trace.controller.shoot_ability.cooldown_remaining <= 0.0 and trace.player.recoil_burst_remaining <= 0.0:
		if requests >= 12:
			trace.fail("interwoven_crown_combat_shot_budget");return true
		requests+=1
		trace.event("interwoven_crown_top_shot",{"enemy_health":target.health.current,"aim":trace.pair(offset.normalized()),"shots_before":trace.controller.action_resources.shot_charges})
		trace.request(&"shoot_release",offset.normalized())
	return true
