extends "res://tests/thorn_queen_migration_runner.gd"
## Same-resource controls in the solid hollow-root arena; all motion uses normal input.
func fixture_spawn(hazard_probe: bool,body_probe: bool) -> Vector2:
	if current=="explicit_initial_crossing_contact": return Vector2(500,542)
	return super.fixture_spawn(hazard_probe,body_probe)
func fixture(id: String,h_enabled := true,hazard_probe := false,body_probe := false) -> void:
	await super.fixture(id,h_enabled,hazard_probe,body_probe)
	(queen.motor as ThornQueenWeaveMotor).physical_contact.connect(func(collider: Node) -> void:
		events.append({"case":current,"tick":tick+1,"event":"actual_kinematic_collision","player":collider==player}))
	for child: Node in world.get_children():
		if child is Camera2D:
			(child as Camera2D).position=Vector2(500,325)
			(child as Camera2D).zoom=Vector2(.9,.9)
func branch(side: int) -> bool:
	var at := 230.0 if side<0 else 800.0
	if not await walk(at,240): return false
	controller.router.set_jump_held(&"queen_hollow_branch",true);await frames(23)
	controller.router.set_jump_held(&"queen_hollow_branch",false)
	for index: int in 90:
		if player.is_on_floor(): break
		await frames(1)
	return player.is_on_floor() and absf(player.position.y-542)<3
func low_cross(side: int) -> bool:
	var before := 420.0 if side>0 else 580.0
	if not await walk(before,240): return false
	controller.router.set_move_axis(side)
	controller.router.set_jump_held(&"queen_hollow_ground",true);await frames(23)
	controller.router.set_jump_held(&"queen_hollow_ground",false)
	var crossed := false
	for index: int in 90:
		if (player.position.x>560 if side>0 else player.position.x<440): crossed=true
		if crossed and player.is_on_floor() and absf(player.position.y-632)<3: break
		await frames(1)
	controller.router.set_move_axis(0)
	return crossed and not controller.actor_resources.health.terminal
func transfer(side: int) -> bool:
	var departure := queen.knots[0 if side>0 else 1]
	var arrival := queen.knots[1 if side>0 else 0]
	if not await hook(departure.global_position): return false
	var center: Array=geometry.hook_anchors[0].position
	if not await hook(Vector2(center[0],center[1])): return false
	if not await hook(arrival.global_position): return false
	# Naked stem keeps the entire contact pause safe; horizontal R is a legal exit.
	controller.router.request_action(&"shoot_release",Vector2(-side,0))
	await frames(15)
	var target_x := 800.0 if side>0 else 230.0
	for index: int in 120:
		controller.router.set_move_axis(0 if absf(player.position.x-target_x)<7 else signf(target_x-player.position.x))
		if player.is_on_floor() and (player.position.x>=712 if side>0 else player.position.x<=288): break
		await frames(1)
	controller.router.set_move_axis(0)
	return player.is_on_floor() and absf(player.position.y-542)<3 and (player.position.x>=712 if side>0 else player.position.x<=288)
func cut_from_branch(index: int,stand: float) -> bool:
	for frame: int in 240:
		if queen.knots[index].health.terminal: break
		if controller.actor_resources.health.terminal: return false
		controller.router.set_move_axis(0 if absf(player.position.x-stand)<7 else signf(stand-player.position.x))
		if controller.shoot_ability.cooldown_remaining<=0:
			var aim := (queen.knots[index].global_position-player.position).normalized()
			controller.router.request_action(&"shoot_release",aim)
		await frames(1)
	controller.router.set_move_axis(0)
	return queen.knots[index].health.terminal
func combat_loop(max_frames: int,stand: float,hold_center := false) -> void:
	for index: int in max_frames:
		if queen.health.terminal or controller.actor_resources.health.terminal: break
		continuous_fire()
		controller.router.set_move_axis(0 if absf(player.position.x-stand)<8 else signf(stand-player.position.x))
		# The central counter is deliberately best-effort output, with normal recoil correction.
		# It does not erase real Queen body contact or secretly disable health.
		if hold_center and player.is_on_floor() and player.position.y>600:
			controller.router.set_jump_held(&"queen_hollow_center",true)
		else: controller.router.set_jump_held(&"queen_hollow_center",false)
		await frames(1)
	controller.router.set_move_axis(0)
func hollow_case(strategy: String) -> void:
	await fixture(strategy,strategy in ["H_roundtrip","observe_two_changes"])
	var row := {"id":current,"initial_player_hp":controller.actor_resources.health.current,"initial_boss_hp":queen.health.current,"initial_energy":controller.actor_resources.stamina.current,"initial_knots":[queen.knots[0].health.current,queen.knots[1].health.current],"observation_only":strategy=="observe_two_changes"}
	var opening_ok := true
	if strategy=="explicit_initial_crossing_contact":
		row.explicit_initial_crossing_fixture=true
		for index: int in 600:
			if controller.actor_resources.health.current<row.initial_player_hp: break
			await frames(1)
		check(events.any(func(event: Dictionary) -> bool: return event.get("case")==current and event.get("event")=="actual_kinematic_collision" and event.get("player",false)),"actual native Queen collision reports blocking player")
		check(controller.actor_resources.health.current==row.initial_player_hp-1,"normal contact emitter and Policy deliver exactly first real collision damage")
	elif strategy=="pause_return_state":
		row.explicit_state_fixture=true
		await frames(30)
		var before := queen.band.age
		var steps := player.motion_steps
		var engine_frame := Engine.get_physics_frames()
		var policy_before := policy.clock
		controller.router.clear("menu");controller.air_focus_ability.stop()
		paused=true
		for index: int in 10: await process_frame
		paused=false
		check(queen.band.age==before and player.motion_steps==steps and policy.clock==policy_before,"actual tree pause freezes field, Motor and Policy clock")
		events.append({"case":current,"tick":tick,"event":"actual_tree_pause","process_frames":10,"engine_frames":Engine.get_physics_frames()-engine_frame,"field_age":queen.band.age,"motor_steps":player.motion_steps})
		await frames(5)
		check(queen.band.age>before and not queen.band.suspended,"menu resume advances same active field")
		before=queen.band.age
		check(controller.return_to_segment(player.position),"real selective return API accepts current segment location")
		life.invalidate_actor();queen.cancel_pending_attacks()
		await frames(5)
		check(queen.band.age>before and not queen.band.suspended and queen.band.is_physics_processing(),"actor return invalidation neither clears nor restarts persistent weave")
		var saved := queen.combat_snapshot()
		check(queen.valid_duel_snapshot(saved),"new solid layout multi-leg combat state validates")
		queen.cancel()
		before=queen.band.age
		await frames(5)
		check(queen.band.age==before,"deactivated owner freezes physical field")
		check(queen.activate(),"same encounter reactivates without rebuilding resources")
		await frames(5)
		check(queen.band.age>before and queen.band.age<before+.1 and not queen.band.suspended,"reactivation resumes preserved age without free regrowth")
	elif strategy=="H_roundtrip":
		opening_ok=await branch(-1)
		check(opening_ok,"left real ordinary-jump receiving branch")
		if opening_ok:
			row.outbound=await transfer(1)
			check(row.outbound,"continuous live-knot down-H side-H horizontal-R reaches right branch")
			row.outbound_tick=tick;row.outbound_knots=[queen.knots[0].health.current,queen.knots[1].health.current]
			if row.outbound:
				await shoot(queen.motor.global_position)
				row.returned=await transfer(-1)
				check(row.returned,"same physical graph supports independent full return")
				row.return_tick=tick;row.return_knots=[queen.knots[0].health.current,queen.knots[1].health.current]
				if row.returned: await combat_loop(1000,230)
	elif strategy=="observe_two_changes":
		for index: int in 1300:
			if queen.migrations>=2: break
			await frames(1)
		check(queen.migrations>=2,"actual Queen A-B-A fits the coarse root and floor root")
	elif strategy=="left_floor_camp":
		await walk(420)
		await combat_loop(1300,420)
	elif strategy=="center_camp":
		await walk(420)
		controller.router.set_move_axis(1);controller.router.set_jump_held(&"queen_hollow_center",true)
		for index: int in 70:
			if player.position.x>=500: controller.router.set_move_axis(0)
			if index==23: controller.router.set_jump_held(&"queen_hollow_center",false)
			await frames(1)
		controller.router.set_jump_held(&"queen_hollow_center",false)
		row.center_opening=[player.position.x,player.position.y]
		await combat_loop(1300,500,true)
	elif strategy in ["lowground_right","cut_all_lowground"]:
		if strategy=="cut_all_lowground":
			opening_ok=await branch(-1)
			check(opening_ok,"cut strategy reaches actual left observation branch")
			row.left_cut=await cut_from_branch(0,230)
			# Drop by walking beyond the real branch; normal gravity reaches the safe floor.
			controller.router.set_move_axis(1)
			for index: int in 120:
				if player.position.x>=420: controller.router.set_move_axis(0)
				if player.is_on_floor() and player.position.y>600: break
				await frames(1)
			controller.router.set_move_axis(0)
		opening_ok=await low_cross(1) and opening_ok
		opening_ok=await branch(1) and opening_ok
		row.right_branch_landed=opening_ok
		if strategy=="cut_all_lowground":
			row.right_cut=await cut_from_branch(1,800)
			row.cut_complete=queen.knots.all(func(item: ThornQueenWeaveKnot) -> bool: return item.health.terminal)
			check(row.cut_complete,"all knots cut by ordinary bullets from real branches, ground remains legal")
		await combat_loop(1300,800)
	elif strategy=="noH_two_R":
		# Strong two-R traversal attempt follows actual geometry, with a lower safe recovery.
		controller.router.set_move_axis(1);controller.router.set_jump_held(&"queen_hollow_R",true)
		await frames(23);controller.router.set_jump_held(&"queen_hollow_R",false)
		controller.router.request_action(&"shoot_release",Vector2(-1,1).normalized());await frames(15)
		controller.router.request_action(&"shoot_release",Vector2(-1,1).normalized());await frames(10)
		for index: int in 100:
			if player.is_on_floor(): break
			await frames(1)
		controller.router.set_move_axis(0)
		row.R_landing=[player.position.x,player.position.y]
		await combat_loop(1300,player.position.x)
	row.ticks=tick;row.boss_damage=row.initial_boss_hp-queen.health.current;row.player_damage=row.initial_player_hp-controller.actor_resources.health.current
	row.boss_defeated=queen.health.terminal;row.player_dead=controller.actor_resources.health.terminal;row.migrations=queen.migrations
	if strategy=="H_roundtrip": check(row.player_damage==0,"intended roundtrip uses observation and full-body clearance without forced damage")
	row.final_energy=controller.actor_resources.stamina.current;row.final_position=[player.position.x,player.position.y]
	row.final_knots=[queen.knots[0].health.current,queen.knots[1].health.current]
	var a: Array=geometry.boss_arena
	row.retained_in_arena=Rect2(a[0],a[1],a[2],a[3]).encloses(Rect2(player.position-actual_body_half,actual_body_half*2))
	check(row.retained_in_arena,"actual terminal control retained by normal arena")
	cases.append(row)
func run() -> void:
	for strategy: String in ["explicit_initial_crossing_contact","pause_return_state","observe_two_changes","H_roundtrip","center_camp","left_floor_camp","lowground_right","cut_all_lowground","noH_two_R"]:
		if selected in ["all",strategy]: await hollow_case(strategy)
	await cleanup()
	DirAccess.make_dir_recursive_absolute(output_dir)
	var report := {"capture_schema":4,"task_id":"FOREST-DEPTH-02","scope":"Queen solid hollow-root first roundtrip and cheapest strategy comparison; not map2 admission","selected":selected,"assertions":assertions,"failures":failures,"cases":cases,"events":events,"frames":frames_data,"geometry":geometry,"migration_speed":(queen_definition() as ThornQueenWeaveDefinition).migration_speed,"definition_sha256":FileAccess.get_sha256("res://resources/bosses/thorn_queen_v2.tres"),"player_tuning_sha256":FileAccess.get_sha256("res://config/player_tuning.json"),"actual_body_half_extents":[actual_body_half.x,actual_body_half.y],"manual_motor_step":false,"midroute_player_position_or_resource_writes":false,"design_verdict":"requires_independent_comparison"}
	FileAccess.open(output_dir+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("QUEEN HOLLOW GOLDEN: %s assertions, %s failures"%[assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
