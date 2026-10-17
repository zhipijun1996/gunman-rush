extends "res://tests/thorn_queen_network_runner.gd"
## A finite real core-mechanism comparison, not three-phase or map2 admission.
func fixture_spawn(hazard_probe: bool,body_probe: bool) -> Vector2:
	if current=="explicit_phase2_weave_observer": return Vector2(450,342)
	return super.fixture_spawn(hazard_probe,body_probe)
func frames(count: int) -> void:
	for index: int in count:
		await super.frames(1)
		if frames_data.is_empty() or not is_instance_valid(queen): continue
		var row: Dictionary=frames_data.back()
		row.actual_last_muzzle=[controller.shoot_ability.last_muzzle.x,controller.shoot_ability.last_muzzle.y]
		row.route_phase=queen.route_phase
		if queen.bands.size()>1 and is_instance_valid(queen.bands[1]):
			var segment := queen.bands[1].current_segment(queen.bands[1].growth)
			row.rotating_thread=[[segment[0].x,segment[0].y],[segment[1].x,segment[1].y]]
			row.rotating_age=queen.bands[1].age
func mature_landing() -> void:
	await fixture("explicit_mature_band_landing",false)
	await frames(120)
	var hp := controller.actor_resources.health.current
	controller.router.request_action(&"drop_through")
	for index: int in 100:
		if controller.actor_resources.health.current<hp: break
		await frames(1)
	check(controller.actor_resources.health.current==hp-1,"real non-solid mature thread still damages through ordinary Policy")
	await walk(260)
	await frames(10)
	check(player.is_on_floor() and absf(player.position.y-582)<1,"normal drop and walking leave mature thread without collider trapping")
	check(queen.band.body.collision_layer==0 and queen.band.shape.disabled,"thread never creates actor or projectile solid geometry")
	check(events.any(func(event: Dictionary) -> bool: return event.get("case")==current and event.get("event")=="policy_result" and event.get("source")=="queen_growing_weave"),"actual hazard commits through Policy")
	cases.append({"id":current,"explicit_initial_probe":true,"ticks":tick,"hp_before":hp,"hp_after":controller.actor_resources.health.current})
func fight_case(strategy: String) -> void:
	if strategy not in ["borrow_then_change_layer","ordinary_cut_route","keep_net_change_layer"]:
		await super.fight_case(strategy)
		return
	await fixture(strategy,strategy=="borrow_then_change_layer")
	var row := {"id":current,"explicit_initial_probe":false,"initial_player_hp":controller.actor_resources.health.current,"initial_boss_hp":queen.health.current,"initial_energy":controller.actor_resources.stamina.current,"initial_fields":field_healths()}
	# Natural entrance shared with the non-H control. Only the optional live weave borrow differs.
	row.upper_entry=await enter_upper(false)
	row.middle_entry=await move_to_middle()
	for index: int in 1200:
		if queen.stage_phase>=2 or queen.health.terminal or controller.actor_resources.health.terminal: break
		controller.router.set_move_axis(0 if absf(player.position.x-480)<5 else signf(480-player.position.x))
		continuous_fire();await frames(1)
	if queen.stage_phase>=2 and not controller.actor_resources.health.terminal:
		var left_side := queen.perch_index==1
		if strategy=="keep_net_change_layer":
			await walk(330)
			controller.router.request_action(&"drop_through")
		elif strategy=="ordinary_cut_route":
			# Same safe preparation as H, then actual two bullets. Never manufacture damage by shooting off the rim.
			await walk(450)
			row.cut_main=await cut_field(1)
			await walk(330)
			controller.router.request_action(&"drop_through")
		else:
			await walk(380 if left_side else 480)
			row.main_hp_before_H=queen.knots[1].health.current
			row.borrowed=await accepted_hook(queen.knots[1].global_position)
			row.main_hp_after_H=queen.knots[1].health.current
			if row.borrowed:
				# Choose the current side's real landing route, not a fixed return-H sequence.
				controller.router.set_move_axis(0 if left_side else 1)
				var backshot := Vector2(1,-.65) if left_side else Vector2(-1,-.65)
				controller.router.request_action(&"shoot_release",backshot.normalized());await frames(14)
				controller.router.set_move_axis(0)
				row.main_hp_after_R=queen.knots[1].health.current
				row.cut_by_backshot=row.main_hp_after_H>0 and queen.knots[1].health.terminal and queen.bands[1].severed
				row.cut_by_H=row.main_hp_before_H>0 and row.main_hp_after_H==0
				row.chosen_side="left" if left_side else "right"
				if left_side:
					for index: int in 120:
						if player.is_on_floor(): break
						await frames(1)
					row.actual_side_landing=player.is_on_floor() and player.position.y<400
					controller.router.request_action(&"drop_through")
				else:
					var before := queen.health.current
					if not ordinary_surface_aim().is_empty():
						continuous_fire();await frames(15)
					row.air_attack_damage=before-queen.health.current
					for index: int in 30:
						if controller.shoot_ability.cooldown_remaining<=0: break
						await frames(1)
					controller.router.request_action(&"shoot_release",Vector2(1,.35).normalized());await frames(15)
					for index: int in 120:
						controller.router.set_move_axis(0 if absf(player.position.x-450)<7 else signf(450-player.position.x))
						if player.is_on_floor(): break
						await frames(1)
					row.returned_inner_bank=player.is_on_floor() and player.position.y<360
					await walk(330)
					controller.router.request_action(&"drop_through")
	# Reach the real left recovery floor before resuming fire; ordinary recoil cannot fight walking simultaneously.
	await walk(240)
	for index: int in 180:
		if player.is_on_floor():
			if player.position.y>560: break
			# The left intermediate branch is real: drop again instead of waiting atop it.
			controller.router.request_action(&"drop_through")
		await frames(1)
	row.actual_left_floor=player.is_on_floor() and player.position.y>560
	check(row.actual_left_floor,"all active alternatives actually reach the same left floor before sustained attack")
	# Preserve the actively cleared field; no further H count or mandatory three-knot chores.
	var left_shoot_limit := float(geometry.weave_fields[2].strand_start[0])-actual_body_half.x-player.weapon_motion.base_distance(controller.shoot_ability.tuning,true)-3
	for index: int in 2100:
		if queen.health.terminal or controller.actor_resources.health.terminal: break
		var destination := 240.0
		controller.router.set_move_axis(0 if absf(player.position.x-destination)<6 else signf(destination-player.position.x))
		# Keep the whole future ground recoil inside the left opening instead of shooting while it pushes into the newly grown net.
		if player.position.x<left_shoot_limit: continuous_fire()
		await frames(1)
	controller.router.set_move_axis(0)
	row.ticks=tick;row.boss_damage=row.initial_boss_hp-queen.health.current;row.boss_defeated=queen.health.terminal
	row.player_damage=row.initial_player_hp-controller.actor_resources.health.current;row.player_dead=controller.actor_resources.health.terminal
	row.final_position=[player.position.x,player.position.y];row.final_energy=controller.actor_resources.stamina.current;row.final_phase=queen.stage_phase;row.fields=field_healths();row.final_route_phase=queen.route_phase;row.final_field_states=queen.combat_snapshot().fields
	var a: Array=geometry.boss_arena
	row.retained_in_arena=Rect2(a[0],a[1],a[2],a[3]).encloses(Rect2(player.position-actual_body_half,actual_body_half*2))
	check(row.retained_in_arena,"natural full-fight route stays in real arena")
	if strategy=="borrow_then_change_layer": check(row.get("borrowed",false) and (row.get("cut_by_backshot",false) or row.get("cut_by_H",false)),"natural route actually uses optional living weave H and propulsion cut")
	cases.append(row)
func edge_control() -> void:
	await fixture("edge_repeat_noH",false)
	var row := {"id":current,"explicit_initial_probe":false,"initial_player_hp":controller.actor_resources.health.current,"initial_boss_hp":queen.health.current,"initial_energy":controller.actor_resources.stamina.current,"initial_fields":field_healths()}
	row.ordinary_upper_arrival=await enter_upper(false)
	row.middle_arrival=await move_to_middle()
	for index: int in 2100:
		if queen.health.terminal or controller.actor_resources.health.terminal: break
		# Deliberately permit partial real foot support. No invented full-width eligibility.
		controller.router.set_move_axis(0 if absf(player.position.x-598)<2 else signf(598-player.position.x))
		continuous_fire()
		await frames(1)
	controller.router.set_move_axis(0)
	row.ticks=tick;row.boss_damage=row.initial_boss_hp-queen.health.current;row.boss_defeated=queen.health.terminal
	row.player_damage=row.initial_player_hp-controller.actor_resources.health.current;row.player_dead=controller.actor_resources.health.terminal
	row.final_position=[player.position.x,player.position.y];row.final_energy=controller.actor_resources.stamina.current;row.final_phase=queen.stage_phase;row.fields=field_healths();row.final_route_phase=queen.route_phase;row.final_field_states=queen.combat_snapshot().fields
	var a: Array=geometry.boss_arena
	row.retained_in_arena=Rect2(a[0],a[1],a[2],a[3]).encloses(Rect2(player.position-actual_body_half,actual_body_half*2))
	check(row.retained_in_arena,"real edge control remains in arena even when it loses")
	cases.append(row)
func rotating_observer() -> void:
	await fixture("explicit_phase2_weave_observer",true)
	for index: int in 1500:
		if queen.stage_phase>=2 or queen.health.terminal or controller.actor_resources.health.terminal: break
		controller.router.set_move_axis(0 if absf(player.position.x-480)<5 else signf(480-player.position.x))
		continuous_fire();await frames(1)
	check(queen.stage_phase==2 and is_instance_valid(queen.bands[1]),"normal ordinary bullets actually reach second phase")
	if queen.stage_phase!=2 or not is_instance_valid(queen.bands[1]): return
	controller.router.set_move_axis(0)
	await walk(450)
	var hp := controller.actor_resources.health.current
	var age := queen.bands[1].age
	await frames(1200)
	check(queen.bands[1].age>age+19.9,"same live thread persists through more than full rotation")
	check(controller.actor_resources.health.current==hp,"wide inner support truly permits observation without hidden damage")
	var saved := queen.combat_snapshot()
	check(queen.valid_duel_snapshot(saved),"current real sweep state is valid before restoration")
	var forged := saved.duplicate(true)
	forged.fields[1].weave.initial_angle+=.1
	check(not queen.valid_duel_snapshot(forged),"save cannot silently redirect authored sweep")
	queen.restore_combat_state(saved)
	check(queen.last_restore_accepted and absf(queen.bands[1].age-float(saved.fields[1].weave.age))<.000001,"same-instance restore preserves actual rotation age without regrowth")
	var config := queen.definition as ThornQueenWeaveDefinition
	for index: int in 2400:
		var degrees := fposmod(rad_to_deg(queen.bands[1].initial_angle)+config.rotating_degrees_per_second*maxf(0,queen.bands[1].age-config.preview_seconds-config.grow_seconds),360)
		if queen.perch_index==0 and queen.motion_mode=="perched" and queen.motion_clock>1.8 and degrees>60 and degrees<120: break
		await frames(1)
	await walk(480)
	var health_before := queen.knots[1].health.current
	var borrowed := await accepted_hook(queen.knots[1].global_position)
	check(borrowed and queen.knots[1].health.current==health_before-1,"real living sweep knot H borrows and weakens exactly once")
	controller.router.set_move_axis(1)
	controller.router.request_action(&"shoot_release",Vector2(-1,-.65).normalized());await frames(14)
	controller.router.set_move_axis(0)
	var opening_boss_hp := queen.health.current
	for index: int in 100:
		continuous_fire();await frames(1)
		if queen.health.current<opening_boss_hp or controller.actor_resources.health.terminal: break
	check(queen.health.current<opening_boss_hp,"borrow then down-right R opens actual low-side body shot")
	var cut := queen.knots[1].health.terminal and queen.bands[1].severed
	check(cut,"ordinary propulsion backshot really cuts borrowed 1HP knot and stops same thread")
	controller.router.request_action(&"shoot_release",Vector2.RIGHT);await frames(15)
	for index: int in 120:
		controller.router.set_move_axis(0 if absf(player.position.x-450)<7 else signf(450-player.position.x))
		if player.is_on_floor() and player.position.y<360: break
		await frames(1)
	controller.router.set_move_axis(0)
	check(player.is_on_floor() and player.position.y<360,"actual return regains wide inner bank")
	check(controller.actor_resources.health.current==hp,"purpose borrow attack return uses no immunity or damage refund")
	var after_cut := queen.combat_snapshot()
	check(queen.valid_duel_snapshot(after_cut),"early new network with continuing real route has a valid snapshot")
	var forged_route := after_cut.duplicate(true)
	forged_route.route_phase=4
	check(not queen.valid_duel_snapshot(forged_route),"forged future physical route is rejected")
	cases.append({"id":current,"explicit_initial_probe":true,"ticks":tick,"hp_before":hp,"hp_after":controller.actor_resources.health.current,"borrowed":borrowed,"cut":cut,"boss_damage_during_borrow":opening_boss_hp-queen.health.current})
func run() -> void:
	if selected in ["all","mature"]: await mature_landing()
	if selected in ["all","observer"]: await rotating_observer()
	for strategy: String in ["borrow_then_change_layer","ordinary_cut_route","keep_net_change_layer","central_ground_shoot","gap_ground_wait"]:
		if selected in ["all",strategy]: await fight_case(strategy)
	if selected in ["all","edge_repeat_noH"]: await edge_control()
	await cleanup()
	DirAccess.make_dir_recursive_absolute(output_dir)
	var report := {"capture_schema":9,"task_id":"FOREST-DEPTH-02","scope":"Queen15 fair actual left-floor continuation and retain-network control with separate real route phase, directional H drop versus prepared ordinary cut; not three-phase or map2 admission","selected":selected,"assertions":assertions,"failures":failures,"cases":cases,"events":events,"frames":frames_data,"geometry":geometry,"migration_speed":(queen_definition() as ThornQueenWeaveDefinition).migration_speed,"player_tuning_sha256":FileAccess.get_sha256("res://config/player_tuning.json"),"manual_motor_step":false,"midroute_player_position_or_resource_writes":false,"design_verdict":"independent_value_review_required"}
	FileAccess.open(output_dir+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("QUEEN SWEEP GOLDEN: %s assertions, %s failures"%[assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
