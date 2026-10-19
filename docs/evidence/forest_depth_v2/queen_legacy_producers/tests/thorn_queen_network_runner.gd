extends "res://tests/thorn_queen_migration_runner.gd"
## C: minimal persistent three-field network, actual full fights and cheapest controls.
func fixture_spawn(hazard_probe: bool,body_probe: bool) -> Vector2:
	if current=="explicit_mature_band_landing": return Vector2(180,382)
	return super.fixture_spawn(hazard_probe,body_probe)
func fixture(id: String,h_enabled := true,hazard_probe := false,body_probe := false) -> void:
	await super.fixture(id,h_enabled,hazard_probe,body_probe)
	var seal: BossArenaSeal
	for node: Node in world.get_children():
		if node is BossArenaSeal: seal=node as BossArenaSeal
	for index: int in 50:
		if is_instance_valid(seal) and seal.closed: break
		await frames(1)
	check(is_instance_valid(seal) and seal.closed,"normal delayed arena walls actually close before control begins")
	for child: Node in world.get_children():
		if child is Camera2D: (child as Camera2D).position=Vector2(450,300);(child as Camera2D).zoom=Vector2(.9,.9)
func field_healths() -> Array:
	var result: Array=[]
	for item: ThornQueenWeaveKnot in queen.knots: result.append(item.health.current if is_instance_valid(item) else null)
	return result
func accepted_hook(point: Vector2) -> bool:
	var start := tick
	if not await hook(point): return false
	var contacts := events.filter(func(event: Dictionary) -> bool: return event.get("case")==current and event.get("event")=="actual_hook_target_contact" and int(event.get("tick",-1))>start)
	return not contacts.is_empty() and Vector2(contacts.back().target_position[0],contacts.back().target_position[1]).distance_to(point)<1
func right_gap_approach() -> bool:
	# Normal jump over suspended root nodule, then approach the forty-wide branch gap.
	if player.position.x<500:
		if not await walk(360): return false
		controller.router.set_move_axis(1)
		controller.router.set_jump_held(&"queen_network",true);await frames(23);controller.router.set_jump_held(&"queen_network",false)
	if not await walk(620): return false
	for index: int in 80:
		if player.is_on_floor(): return true
		await frames(1)
	return false
func enter_upper(use_hook: bool) -> bool:
	if not await right_gap_approach(): return false
	controller.router.set_jump_held(&"queen_network",true);await frames(23);controller.router.set_jump_held(&"queen_network",false)
	if use_hook and not queen.knot.health.terminal:
		var accepted := await accepted_hook(queen.knot.global_position)
		check(accepted,"actual H reaches the intended living knot, not merely any completed cast")
		if not accepted: return false
	else:
		# Same ordinary jump/R path remains legal after all live knots are cut.
		controller.router.request_action(&"shoot_release",Vector2.DOWN);await frames(15)
	controller.router.request_action(&"shoot_release",Vector2.LEFT);await frames(15)
	for index: int in 100:
		controller.router.set_move_axis(0 if absf(player.position.x-750)<7 else signf(750-player.position.x))
		if player.is_on_floor():
			controller.router.set_move_axis(0)
			return player.position.y<400
		await frames(1)
	controller.router.set_move_axis(0)
	return false
func first_borrow() -> bool:
	var arrived := await enter_upper(true)
	check(queen.knot.health.current==1,"real configured H weakens original 2HP field knot")
	check(arrived,"borrow plus horizontal R reaches independent upper receiver")
	return arrived
func move_to_middle() -> bool:
	# Stabilize the ordinary takeoff on the inner branch before committing the jump.
	if player.position.x>700 and not await walk(700): return false
	controller.router.set_move_axis(-1 if player.position.x>450 else 1)
	controller.router.set_jump_held(&"queen_network",true);await frames(23);controller.router.set_jump_held(&"queen_network",false)
	if not await walk(450): return false
	for index: int in 100:
		if player.is_on_floor(): return player.position.y<360
		await frames(1)
	return false
func cut_field(index: int) -> bool:
	var target: ThornQueenWeaveKnot=queen.knots[index]
	if not is_instance_valid(target): return false
	for index_tick: int in 180:
		if target.health.terminal: return true
		if controller.actor_resources.health.terminal: return false
		controller.router.set_move_axis(0 if absf(player.position.x-450)<7 else signf(450-player.position.x))
		if player.is_on_floor() and controller.shoot_ability.cooldown_remaining<=0:
			var aim := (target.global_position-player.global_position).normalized()
			var queued := controller.router.request_action(&"shoot_release",aim)
			events.append({"case":current,"tick":tick,"event":"normal_cut_shot_request","field":index,"queued":queued})
		await frames(1)
	return target.health.terminal
func fight_case(strategy: String) -> void:
	await fixture(strategy,strategy=="borrow_then_change_layer")
	var row := {"id":current,"initial_player_hp":controller.actor_resources.health.current,"initial_boss_hp":queen.health.current,"initial_energy":controller.actor_resources.stamina.current,"initial_fields":field_healths(),"explicit_initial_probe":false}
	if strategy=="borrow_then_change_layer": row.borrowed=await first_borrow()
	elif strategy=="central_ground_shoot": await walk(384)
	elif strategy=="gap_ground_wait": await walk(620,260)
	elif strategy=="middle_top_wait":
		await enter_upper(false)
		row.middle_arrival=await move_to_middle()
	elif strategy=="outer_ground_wait": await walk(12)
	elif strategy=="outer_right_wait": await walk(888,300)
	elif strategy=="pillar_top_wait":
		await walk(360)
		controller.router.set_move_axis(1)
		controller.router.set_jump_held(&"queen_network",true);await frames(23);controller.router.set_jump_held(&"queen_network",false)
		await walk(450)
		for index: int in 100:
			if player.is_on_floor(): break
			await frames(1)
	elif strategy=="noH_two_R_middle": row.ordinary_upper_arrival=await enter_upper(false)
	var previous_phase := 1
	for index: int in 2100:
		if queen.health.terminal or controller.actor_resources.health.terminal: break
		var destination := 384.0
		if strategy in ["borrow_then_change_layer","noH_two_R_middle"] and queen.stage_phase>previous_phase:
			var new_phase := queen.stage_phase
			if new_phase==2:
				row.middle_phase2=await move_to_middle()
				row.cut_phase2=await cut_field(1) if row.middle_phase2 else false
				controller.router.request_action(&"drop_through")
			else:
				row.upper_phase3=await enter_upper(strategy=="borrow_then_change_layer")
				row.middle_phase3=await move_to_middle() if row.upper_phase3 else false
				row.cut_phase3=await cut_field(2) if row.middle_phase3 else false
				if row.cut_phase3: controller.router.request_action(&"drop_through")
			previous_phase=new_phase
		if strategy=="outer_ground_wait": destination=12
		elif strategy=="gap_ground_wait": destination=620
		elif strategy=="middle_top_wait": destination=450
		elif strategy=="outer_right_wait": destination=888
		elif strategy=="pillar_top_wait": destination=450
		elif strategy=="borrow_then_change_layer":
			destination=750
		elif strategy=="noH_two_R_middle":
			destination=750
		controller.router.set_move_axis(0 if absf(player.position.x-destination)<7 else signf(destination-player.position.x))
		continuous_fire()
		previous_phase=queen.stage_phase
		await frames(1)
	controller.router.set_move_axis(0)
	row.ticks=tick;row.boss_damage=row.initial_boss_hp-queen.health.current;row.boss_defeated=queen.health.terminal
	row.player_damage=row.initial_player_hp-controller.actor_resources.health.current;row.player_dead=controller.actor_resources.health.terminal
	row.final_position=[player.position.x,player.position.y];row.final_energy=controller.actor_resources.stamina.current
	row.final_phase=queen.stage_phase;row.fields=field_healths();row.final_state=queen.combat_snapshot()
	var a: Array=geometry.boss_arena
	row.retained_in_arena=Rect2(a[0],a[1],a[2],a[3]).encloses(Rect2(player.position-actual_body_half,actual_body_half*2))
	check(row.retained_in_arena,"full-fight control terminates inside real arena even if it loses")
	cases.append(row)
func mature_landing() -> void:
	await fixture("explicit_mature_band_landing",false)
	await frames(120)
	check(queen.band.growth==1 and player.is_on_floor(),"left observation support sees fully mature floor band before normal drop")
	var hp := controller.actor_resources.health.current
	controller.router.request_action(&"drop_through")
	for index: int in 100:
		if controller.actor_resources.health.current<hp: break
		await frames(1)
	check(controller.actor_resources.health.current==hp-1,"landing on mature band causes first ordinary contact damage")
	check(events.any(func(event: Dictionary) -> bool: return event.get("case")==current and event.get("event")=="weave_sweep" and event.get("actual_physical_contact",false)),"native Player slide collision, not enlarged hazard radius, resolves safe-margin contact")
	cases.append({"id":current,"explicit_initial_probe":true,"ticks":tick,"hp_before":hp,"hp_after":controller.actor_resources.health.current})
func run() -> void:
	if selected in ["all","mature"]: await mature_landing()
	for strategy: String in ["borrow_then_change_layer","central_ground_shoot","outer_ground_wait","outer_right_wait","pillar_top_wait","gap_ground_wait","middle_top_wait","noH_two_R_middle"]:
		if selected in ["all",strategy]: await fight_case(strategy)
	await cleanup()
	DirAccess.make_dir_recursive_absolute(output_dir)
	var report := {"capture_schema":6,"task_id":"FOREST-DEPTH-02","scope":"Queen C shelter rise/drop/rise persistent network full-fight comparison; not map2 admission","selected":selected,"assertions":assertions,"failures":failures,"cases":cases,"events":events,"frames":frames_data,"geometry":geometry,"migration_speed":(queen_definition() as ThornQueenWeaveDefinition).migration_speed,"definition_sha256":FileAccess.get_sha256("res://resources/bosses/thorn_queen_v2.tres"),"player_tuning_sha256":FileAccess.get_sha256("res://config/player_tuning.json"),"actual_body_half_extents":[actual_body_half.x,actual_body_half.y],"manual_motor_step":false,"midroute_player_position_or_resource_writes":false,"design_verdict":"requires_independent_comparison","ordinary_speed_source":"actual tuning1200 not unconsumed WeaponDefinition850"}
	FileAccess.open(output_dir+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("QUEEN NETWORK GOLDEN: %s assertions, %s failures"%[assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
