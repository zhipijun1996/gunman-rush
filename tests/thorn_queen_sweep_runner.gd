extends "res://tests/support/forest_queen_gameplay_fixture.gd"
var _adaptive_response := false
var _adaptive_entry_done := false
var _adaptive_entry_result: Dictionary = {}
func enter_upper(use_hook: bool) -> bool:
	if not _adaptive_response: return await super.enter_upper(use_hook)
	_adaptive_entry_result=await shore_response(true,true)
	_adaptive_entry_done=int(_adaptive_entry_result.return_support_frames)>=12
	return _adaptive_entry_done
func move_to_middle() -> bool:
	if _adaptive_response and _adaptive_entry_done: return true
	return await super.move_to_middle()
## Canonical Queen local and full-fight verification; technical results do not grant admission.
func fixture_spawn(hazard_probe: bool,body_probe: bool) -> Vector2:
	if current in ["explicit_phase2_weave_observer","explicit_third_weave_cycle","explicit_fixed_H","explicit_fixed_ordinary"]: return Vector2(450,342)
	return super.fixture_spawn(hazard_probe,body_probe)
func fixture(id: String,h_enabled := true,hazard_probe := false,body_probe := false) -> void:
	await super.fixture(id,h_enabled,hazard_probe,body_probe)
	(queen.motor as ThornQueenWeaveMotor).movement_observed.connect(func(data: Dictionary) -> void:
		var event := data.duplicate(true);event["event"]="actual_queen_motor_motion";event["source_id"]=queen.motor.get_instance_id();event["case"]=current;event["tick"]=tick+1;events.append(event))
func frames(count: int) -> void:
	for index: int in count:
		if is_instance_valid(controller):
			for action: Dictionary in controller.router._queue:
				events.append({"case":current,"tick":tick+1,"event":"actual_queued_input","action":String(action.type),"sequence":action.sequence,"direction":[action.direction.x,action.direction.y]})
		await super.frames(1)
		if frames_data.is_empty() or not is_instance_valid(queen): continue
		var row: Dictionary=frames_data.back()
		row.actual_last_muzzle=[controller.shoot_ability.last_muzzle.x,controller.shoot_ability.last_muzzle.y]
		row.route_phase=queen.route_phase
		row.sampled_shore=queen.sampled_shore
		row.sampled_player=[queen.sampled_player.x,queen.sampled_player.y]
		if queen.route_phase==2 and queen.motor.position.y>430 and tick%30==0:
			var visibility := ordinary_surface_aim()
			row.actual_low_perch_visibility={"found":not visibility.is_empty(),"shape_traces":_ordinary_shape_traces.duplicate(true),"queen":[queen.motor.position.x,queen.motor.position.y],"player":[player.position.x,player.position.y]}
		row.queen_motor_id=queen.motor.get_instance_id();row.physics_frame=Engine.get_physics_frames()
		if queen.bands.size()>1 and is_instance_valid(queen.bands[1]):
			var segment := queen.bands[1].current_segment(queen.bands[1].growth)
			row.rotating_thread=[[segment[0].x,segment[0].y],[segment[1].x,segment[1].y]]
			row.rotating_age=queen.bands[1].age
		if queen.bands.size()>2 and is_instance_valid(queen.bands[2]):
			var third := queen.bands[2].current_segment(queen.bands[2].growth)
			row.third_thread=[[third[0].x,third[0].y],[third[1].x,third[1].y]]
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
func actual_queen_branch(index: int) -> Rect2:
	var row: Dictionary=geometry.platforms.filter(func(candidate: Dictionary) -> bool: return String(candidate.id)=="queen_branch_%s"%index)[0]
	var a: Array=row.rect
	return Rect2(float(a[0]),float(a[1]),float(a[2]),float(a[3]))
func whole_body_on_branch(branch: Rect2) -> bool:
	return player.is_on_floor() and absf(player.position.y+actual_body_half.y-branch.position.y)<1 and player.position.x-actual_body_half.x>=branch.position.x and player.position.x+actual_body_half.x<=branch.end.x
func observe_middle_with_normal_avoidance(count: int) -> void:
	# The middle is weave-safe, not immune to the announced P1 body patrol.
	# A normal jump and downshot clear its approaching y300 sweep; no state writes.
	var middle := actual_queen_branch(1)
	controller.router.set_move_axis(0)
	var elapsed := 0
	while elapsed<count:
		var delta_to_boss := queen.motor.position-player.position
		var closing := delta_to_boss.x*queen.motor.velocity.x<0
		if whole_body_on_branch(middle) and queen.route_phase==1 and closing and absf(delta_to_boss.x)<110 and absf(delta_to_boss.y)<100:
			controller.router.set_move_axis(0)
			controller.router.set_jump_held(&"queen_observe",true)
			await frames(23);elapsed+=23
			controller.router.set_jump_held(&"queen_observe",false)
			if controller.shoot_ability.cooldown_remaining<=0 and controller.action_resources.shot_charges>0 and controller.actor_resources.stamina.current>=controller.shot_energy.shot_energy_cost:
				controller.router.request_action(&"shoot_release",Vector2.DOWN)
		else:
			await frames(1);elapsed+=1
func rotating_observer() -> void:
	await fixture("explicit_phase2_weave_observer",true)
	var hp := controller.actor_resources.health.current
	var middle := actual_queen_branch(1)
	var middle_center := middle.get_center().x
	for index: int in 1500:
		if queen.stage_phase>=2 or queen.health.terminal or controller.actor_resources.health.terminal: break
		controller.router.set_move_axis(0 if absf(player.position.x-480)<5 else signf(480-player.position.x))
		continuous_fire();await frames(1)
	check(queen.stage_phase==2 and is_instance_valid(queen.bands[1]),"normal ordinary bullets actually reach second phase")
	if queen.stage_phase!=2 or not is_instance_valid(queen.bands[1]): return
	controller.router.set_move_axis(0)
	await walk(middle_center)
	var age := queen.bands[1].age
	await observe_middle_with_normal_avoidance(1200)
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
		controller.router.set_move_axis(0 if absf(player.position.x-middle_center)<7 else signf(middle_center-player.position.x))
		if whole_body_on_branch(middle): break
		await frames(1)
	controller.router.set_move_axis(0)
	check(whole_body_on_branch(middle),"actual return regains wide inner bank")
	check(controller.actor_resources.health.current==hp,"purpose borrow attack return uses no immunity or damage refund")
	var after_cut := queen.combat_snapshot()
	check(queen.valid_duel_snapshot(after_cut),"early new network with continuing real route has a valid snapshot")
	var forged_route := after_cut.duplicate(true)
	forged_route.route_phase=4
	check(not queen.valid_duel_snapshot(forged_route),"forged future physical route is rejected")
	cases.append({"id":current,"explicit_initial_probe":true,"ticks":tick,"hp_before":hp,"hp_after":controller.actor_resources.health.current,"borrowed":borrowed,"cut":cut,"boss_damage_during_borrow":opening_boss_hp-queen.health.current})
func rising_observer() -> void:
	await fixture("explicit_third_weave_cycle",true)
	var hp := controller.actor_resources.health.current
	var middle_receiver := actual_queen_branch(1)
	var left_receiver := actual_queen_branch(0)
	var middle_center := middle_receiver.get_center().x
	for index: int in 1500:
		if queen.stage_phase>=2 or queen.health.terminal: break
		controller.router.set_move_axis(0 if absf(player.position.x-480)<5 else signf(480-player.position.x))
		continuous_fire();await frames(1)
	await walk(middle_center)
	check(await cut_field(1),"ordinary shots cut main thread without changing actor resources")
	await frames(2)
	check(queen.stage_phase==3 and is_instance_valid(queen.bands[2]),"cut main weave creates announced third field while actual route continues")
	# Preserve the original fixture HP; do not rebaseline after a body hit.
	# Wait for the committed P2 descent to arrive, not merely its route label.
	var patrol_deadline := tick+1200
	controller.router.set_move_axis(0)
	var low_perch_ready := false
	while tick<patrol_deadline and not controller.actor_resources.health.terminal:
		low_perch_ready=queen.route_phase==2 and queen.motion_mode=="perched" and queen.motor.position.y-queen.definition.collision_size.y*.5>left_receiver.end.y
		if low_perch_ready: break
		await observe_middle_with_normal_avoidance(1)
	check(low_perch_ready,"actual P2 low perch arrives before ordinary transfer across its old descent corridor")
	check(controller.actor_resources.health.current==hp,"no non-test damage before ordinary rising-field transfer")
	if not low_perch_ready or controller.actor_resources.health.current!=hp: return
	var takeoff_x := middle_receiver.position.x+actual_body_half.x+3
	var landing_x := left_receiver.end.x-actual_body_half.x-3
	await walk(takeoff_x)
	check(whole_body_on_branch(middle_receiver),"ordinary gap jump begins with full actual body on middle support")
	if not whole_body_on_branch(middle_receiver): return
	events.append({"case":current,"tick":tick,"event":"ordinary_branch_crossing_takeoff","player":[player.position.x,player.position.y],"target_x":landing_x,"support_rect":[middle_receiver.position.x,middle_receiver.position.y,middle_receiver.size.x,middle_receiver.size.y]})
	controller.router.set_move_axis(-1)
	controller.router.set_jump_held(&"queen_cross",true);await frames(12)
	controller.router.set_jump_held(&"queen_cross",false)
	for index: int in 90:
		if whole_body_on_branch(left_receiver): break
		controller.router.set_move_axis(0 if absf(player.position.x-landing_x)<.5 else signf(landing_x-player.position.x))
		await frames(1)
	controller.router.set_move_axis(0)
	check(whole_body_on_branch(left_receiver),"ordinary input actually reaches lower side branch with complete body support")
	if not whole_body_on_branch(left_receiver): return
	check(controller.actor_resources.health.current==hp,"ordinary gap transfer preserves original fixture health")
	if controller.actor_resources.health.current!=hp: return
	var third := queen.bands[2]
	var pressure_start := tick
	var pressure_prefix := "queen/weave/%s/%s/"%[third.field_id,third._epoch]
	for index: int in 600:
		if controller.actor_resources.health.current<hp: break
		await frames(1)
	var player_damage := events.filter(func(event: Dictionary) -> bool: return event.get("case")==current and event.get("event")=="policy_result" and event.get("target")=="player")
	var pressure_damage := player_damage.filter(func(event: Dictionary) -> bool: return int(event.tick)>pressure_start and event.get("source")=="queen_growing_weave" and String(event.get("id","")).begins_with(pressure_prefix))
	var pressure_ids: Array=[]
	for damage: Dictionary in pressure_damage:
		var matching_sweep := events.any(func(event: Dictionary) -> bool: return event.get("case")==current and event.get("event")=="weave_sweep" and event.get("field")==2 and event.get("accepted")==true and event.get("id")==damage.id)
		if matching_sweep: pressure_ids.append(damage.id)
	check(controller.actor_resources.health.current==hp-1,"slow visible rising weave really pressures old side-branch shooting place through Policy")
	check(player_damage.size()==1 and pressure_damage.size()==1 and pressure_ids.size()==1,"the sole fixture damage matches this live third-band sweep and Policy event id, never Queen body or ground weave")
	if player_damage.size()!=1 or pressure_ids.size()!=1: return
	controller.router.set_move_axis(1)
	controller.router.set_jump_held(&"queen_rise",true);await frames(23);controller.router.set_jump_held(&"queen_rise",false)
	controller.router.request_action(&"shoot_release",Vector2.DOWN);await frames(15)
	await walk(middle_center)
	for index: int in 120:
		if player.is_on_floor(): break
		await frames(1)
	controller.router.set_move_axis(0)
	check(whole_body_on_branch(middle_receiver),"ordinary jump and single R regain wide safe middle receiver")
	var after_recovery := controller.actor_resources.health.current
	var config := queen.definition as ThornQueenWeaveDefinition
	var cycle_end := config.preview_seconds+config.grow_seconds+config.rising_travel*2/config.rising_speed
	for index: int in 700:
		if third.age>=cycle_end: break
		await observe_middle_with_normal_avoidance(1)
	check(third.age>=cycle_end,"third weave really completes full upward and downward traversal")
	check(controller.actor_resources.health.current==after_recovery,"wide middle receiver stays safe through full moving third weave")
	var saved := queen.combat_snapshot()
	check(queen.valid_duel_snapshot(saved),"new moving weave actual age and real route save is valid")
	for key: String in ["weave_schema","geometry_version","mode","knot_health"]:
		for invalid: Variant in [true,"malformed",null,{}]:
			var malformed := saved.duplicate(true)
			malformed[key]=invalid
			check(not queen.valid_duel_snapshot(malformed),"malformed %s rejects before typed comparison"%key)
	for key: String in ["spawned","health","weave"]:
		var malformed := saved.duplicate(true)
		malformed.fields[2][key]="malformed"
		check(not queen.valid_duel_snapshot(malformed),"malformed field %s rejects without runtime exception"%key)
	var frozen_hazard := saved.duplicate(true)
	frozen_hazard.fields[2].weave.suspended=true
	check(not queen.valid_duel_snapshot(frozen_hazard),"forged suspended field cannot permanently erase live hazard")
	queen.restore_combat_state(saved)
	check(queen.last_restore_accepted and absf(third.age-float(saved.fields[2].weave.age))<.000001,"restoration retains third weave height phase without regrowth")
	# The first knot's real 24px collider plus 12px cast intercepts the 590,342 ray.
	# Walk into the actual inner branch gap and descend normally before choosing the new angle.
	await walk(620)
	controller.router.set_move_axis(0)
	for index: int in 30:
		if player.position.y>=350: break
		await frames(1)
	var third_takeoff := player.position
	var borrowed := await accepted_hook(queen.knots[2].global_position)
	check(borrowed and queen.knots[2].health.current==1,"real optional H weakens new third 2HP knot")
	controller.router.set_move_axis(0)
	var backshot := (queen.knots[2].global_position-player.global_position).normalized()
	controller.router.request_action(&"shoot_release",backshot);await frames(15)
	check(queen.knots[2].health.terminal and third.severed,"real propulsion backshot cuts borrowed third knot and stops same moving weave")
	for index: int in 150:
		controller.router.set_move_axis(0 if absf(player.position.x-middle_center)<6 else signf(middle_center-player.position.x))
		if player.is_on_floor(): break
		await frames(1)
	controller.router.set_move_axis(0)
	check(whole_body_on_branch(middle_receiver),"optional third borrow and cut returns to real middle bank")
	var all_final_damage := events.filter(func(event: Dictionary) -> bool: return event.get("case")==current and event.get("event")=="policy_result" and event.get("target")=="player")
	check(controller.actor_resources.health.current==hp-1 and all_final_damage.size()==1,"whole rising probe retains original health except the one proven third-band hit")
	cases.append({"initial_player_hp":hp,"third_pressure_event_ids":pressure_ids,"third_pressure_prefix":pressure_prefix,"all_player_damage":all_final_damage,"id":current,"explicit_initial_probe":true,"ticks":tick,"borrowed_third":borrowed,"third_takeoff":[third_takeoff.x,third_takeoff.y],"third_severed":third.severed,"hp_before":hp,"hp_after":controller.actor_resources.health.current,"age":third.age,"boss_hp":queen.health.current,"scope":"Explicit pressure/recovery/cut probe, not fair full-fight efficiency"})
func regain_middle_bank() -> bool:
	controller.router.set_move_axis(0)
	for index: int in 160:
		if player.is_on_floor() or controller.actor_resources.health.terminal: break
		await frames(1)
	if controller.actor_resources.health.terminal: return false
	if player.is_on_floor() and player.position.y<360:
		return await walk(450)
	if player.is_on_floor() and player.position.y<500:
		return await super.move_to_middle()
	if player.is_on_floor():
		var gap := 330.0 if absf(player.position.x-330)<absf(player.position.x-620) else 620.0
		if not await walk(gap): return false
		for index: int in 120:
			if controller.actor_resources.stamina.current>=controller.shot_energy.shot_energy_cost: break
			if controller.actor_resources.health.terminal: return false
			await frames(1)
	controller.router.set_jump_held(&"queen_full",true);await frames(23);controller.router.set_jump_held(&"queen_full",false)
	controller.router.request_action(&"shoot_release",Vector2.DOWN);await frames(15)
	if player.position.y>350:
		controller.router.request_action(&"shoot_release",Vector2.DOWN);await frames(15)
	await walk(450)
	for index: int in 150:
		if player.is_on_floor() or controller.actor_resources.health.terminal: break
		await frames(1)
	controller.router.set_move_axis(0)
	return player.is_on_floor() and player.position.y<360
func full_fight(strategy: String) -> void:
	if strategy=="full_edge":
		await edge_control()
		check(bool(cases.back().boss_defeated) or bool(cases.back().player_dead),"edge complete control must really end in death inside its finite frame budget")
		return
	await fixture(strategy,strategy=="full_H")
	var row := {"id":current,"explicit_initial_probe":false,"initial_player_hp":controller.actor_resources.health.current,"initial_boss_hp":queen.health.current,"initial_energy":controller.actor_resources.stamina.current,"initial_fields":field_healths()}
	row.upper_entry=await enter_upper(false);row.middle_entry=await move_to_middle()
	for index: int in 1800:
		if queen.stage_phase>=2 or queen.health.terminal or controller.actor_resources.health.terminal: break
		controller.router.set_move_axis(0 if absf(player.position.x-480)<5 else signf(480-player.position.x))
		continuous_fire();await frames(1)
	if not queen.health.terminal and not controller.actor_resources.health.terminal:
		if strategy=="full_H":
			var left_side := queen.perch_index==1
			await walk(380 if left_side else 480)
			row.borrowed_main=await accepted_hook(queen.knots[1].global_position)
			if row.borrowed_main:
				controller.router.set_move_axis(-1 if left_side else 1)
				controller.router.request_action(&"shoot_release",(queen.knots[1].global_position-player.position).normalized());await frames(15)
				row.main_backshot_cut=queen.knots[1].health.terminal
		elif strategy=="full_cut":
			await walk(450);row.main_cut=await cut_field(1)
	var low_excursions := 0
	var third_clear_attempted := false
	var fixed_borrows := 0
	var attack_damage_after_fixed := 0.0
	while tick<3600 and not queen.health.terminal and not controller.actor_resources.health.terminal:
		if not player.is_on_floor() or player.position.y>=360:
			await regain_middle_bank()
			if queen.health.terminal or controller.actor_resources.health.terminal: break
		if not third_clear_attempted and strategy=="full_cut" and is_instance_valid(queen.bands[2]) and not queen.bands[2].severed:
			third_clear_attempted=true
			for attempt: int in 2:
				if queen.knots[2].health.terminal or controller.actor_resources.health.terminal: break
				await walk(620);controller.router.set_move_axis(0)
				for index: int in 30:
					if player.position.y>=350: break
					await frames(1)
				if controller.shoot_ability.cooldown_remaining<=0:
					controller.router.request_action(&"shoot_release",(queen.knots[2].global_position-player.position).normalized());await frames(15)
				await regain_middle_bank()
			row.third_clear=queen.knots[2].health.terminal
		var third_low := not is_instance_valid(queen.bands[2]) or queen.bands[2].severed or queen.bands[2].current_segment(1)[0].y>520
		var low_target := queen.motor.position.y>430 and strategy!="full_wait"
		# Same visible-network timing and ordinary route for all controls. H only adds an optional low interception.
		if low_target and third_low and controller.actor_resources.stamina.current>15:
			await walk(330 if queen.motor.position.x<450 else 620)
			if player.is_on_floor(): controller.router.request_action(&"drop_through")
			controller.router.set_move_axis(0)
			low_excursions+=1
			var used_fixed := false
			# The fixed anchor is an available emergency route, not a mandatory attack step.
			if not used_fixed:
				for index: int in 90:
					if player.position.y>430 or controller.actor_resources.health.terminal: break
					await frames(1)
			var before := queen.health.current
			continuous_fire();await frames(15)
			if used_fixed: attack_damage_after_fixed+=before-queen.health.current
			# Both controls may use their remaining real air shot to return, instead of falling into the field.
			if not player.is_on_floor() and controller.action_resources.shot_charges>0 and controller.shoot_ability.cooldown_remaining<=0:
				controller.router.request_action(&"shoot_release",Vector2.DOWN);await frames(15)
			await regain_middle_bank()
		else:
			controller.router.set_move_axis(0 if absf(player.position.x-450)<6 else signf(450-player.position.x))
			continuous_fire();await frames(1)
			if strategy=="full_wait" and tick>=3000 and tick%60==0:
				var shot := ordinary_surface_aim()
				events.append({"case":current,"tick":tick,"event":"stationary_occlusion_probe","visible_body_sample":not shot.is_empty(),"shape_traces":_ordinary_shape_traces.duplicate(true)})
	controller.router.set_move_axis(0)
	row.ticks=tick;row.boss_damage=row.initial_boss_hp-queen.health.current;row.boss_defeated=queen.health.terminal
	row.player_damage=row.initial_player_hp-controller.actor_resources.health.current;row.player_dead=controller.actor_resources.health.terminal
	row.final_position=[player.position.x,player.position.y];row.final_energy=controller.actor_resources.stamina.current
	row.fields=field_healths();row.final_phase=queen.stage_phase;row.final_route_phase=queen.route_phase
	row.final_field_states=queen.combat_snapshot().fields;row.low_excursions=low_excursions;row.fixed_borrows=fixed_borrows;row.attack_damage_after_fixed=attack_damage_after_fixed
	row.third_H_omitted_as_redundant=strategy=="full_H"
	var a: Array=geometry.boss_arena
	row.retained_in_arena=Rect2(a[0],a[1],a[2],a[3]).encloses(Rect2(player.position-actual_body_half,actual_body_half*2))
	check(row.retained_in_arena,"natural complete weaving fight retains real sealed arena")
	var stationary_stall := false
	if strategy=="full_wait" and not row.boss_defeated and not row.player_dead:
		var tail := frames_data.filter(func(frame: Dictionary) -> bool: return frame.get("case")==current and int(frame.tick)>3000)
		var probes := events.filter(func(event: Dictionary) -> bool: return event.get("case")==current and event.get("event")=="stationary_occlusion_probe")
		var queued_H := events.filter(func(event: Dictionary) -> bool: return event.get("case")==current and event.get("event")=="actual_queued_input" and event.get("action")=="grapple")
		stationary_stall=tick==3600 and tail.size()==600 and probes.size()>=10 and queued_H.is_empty()
		for frame: Dictionary in tail:
			stationary_stall=stationary_stall and float(frame.boss_hp)==queen.health.current and float(frame.boss_hp)>0 and float(frame.hp)>0 and frame.grounded and absf(float(frame.player[1])-342)<1 and float(frame.player[0])>=312 and float(frame.player[0])<=588 and frame.hook=="free" and frame.core_open and float(frame.axis)==0
		for probe: Dictionary in probes:
			var blocked := 0
			for trace: Dictionary in probe.shape_traces:
				if int(trace.overlap_count)>0 or (trace.safe_fraction.size()==2 and float(trace.safe_fraction[0])<.99999): blocked+=1
			stationary_stall=stationary_stall and not bool(probe.visible_body_sample) and blocked>=9
		row.outcome="stable_occluded_stationary_ablation" if stationary_stall else "bounded_failure"
		row.stationary_tail_frames=tail.size();row.occlusion_probes=probes.size();row.queued_H_requests=queued_H.size()
	check(row.boss_defeated or row.player_dead or stationary_stall,"complete fight terminates or stationary ablation proves exact bounded occluded stall")
	if strategy=="full_H": check(row.boss_defeated,"purpose complete fight must really defeat Queen")
	cases.append(row)
class NativeWorldProbe extends Node:
	var body: ThornQueenWeaveMotor
	var goal := Vector2.ZERO
	var travel_speed := 0.0
	func _physics_process(delta: float) -> void:
		if is_instance_valid(body): body.travel_to(goal,travel_speed,delta)
func collision_semantics_probe() -> void:
	await fixture("explicit_queen_body_contact",false,false,true)
	check(controller.actor_resources.health.current==4,"same-coordinate Queen body still deals exactly one actual normal damage")
	check(events.any(func(event: Dictionary) -> bool: return event.get("case")==current and event.get("event")=="policy_result" and event.get("source")=="queen_body_contact" and event.get("target")=="player"),"body contact commits through existing Policy")
	check(queen.motor.get_collision_exceptions().has(player) and queen.motor.collision_mask==1,"only current Player physics body is excepted while world mask remains")
	var other := load("res://scenes/player/player.tscn").instantiate() as PlayerMotor
	other.position=Vector2(130,582) # Explicit independent actor initial fixture only.
	world.add_child(other)
	var other_controller := other.get_node("Controller") as PlayerController
	check(queen.bind_duel(geometry,other_controller,policy,life),"same duel can bind a new actual Player instance")
	check(queen.motor.get_collision_exceptions().has(other) and not queen.motor.get_collision_exceptions().has(player),"new actor removes stale previous collision exception")
	check(queen.bind_duel(geometry,controller,policy,life),"binding original current actor is explicit and accepted")
	check(queen.motor.get_collision_exceptions().has(player) and not queen.motor.get_collision_exceptions().has(other),"only final current Player remains excepted")
	other.queue_free()
	await frames(40)
	cases.append({"id":current,"explicit_initial_probe":true,"ticks":tick,"player_hp":controller.actor_resources.health.current,"collision_mask":queen.motor.collision_mask})
	await fixture("explicit_queen_world_block",false)
	slab({"id":"queen_world_probe_wall","rect":[210,100,40,200],"one_way":false})
	var probe := ThornQueenWeaveMotor.new()
	probe.name="QueenActualWorldMotionProbe";probe.position=Vector2(150,200)
	probe.collision_layer=4;probe.collision_mask=1
	var collision := CollisionShape2D.new();collision.name="CollisionShape2D";probe.add_child(collision)
	world.add_child(probe);probe.configure(queen.definition)
	probe.movement_observed.connect(func(data: Dictionary) -> void:
		var event := data.duplicate(true);event["event"]="actual_world_probe_motion";event["case"]=current;event["tick"]=tick+1;event["source_id"]=probe.get_instance_id();events.append(event))
	var stepper := NativeWorldProbe.new();stepper.body=probe;stepper.goal=Vector2(300,200);stepper.travel_speed=(queen.definition as ThornQueenWeaveDefinition).migration_speed
	world.add_child(stepper)
	await frames(35)
	check(probe.position.x+queen.definition.collision_size.x*.5<=210+.1,"actual Queen motor remains blocked by world wall")
	check(events.any(func(event: Dictionary) -> bool: return event.get("case")==current and event.get("event")=="actual_world_probe_motion" and event.get("collision",false) and event.get("collider_name")=="queen_world_probe_wall"),"real move_and_collide returns actual world collider telemetry")
	cases.append({"id":current,"explicit_initial_probe":true,"ticks":tick,"probe_position":[probe.position.x,probe.position.y],"world_blocked":true})
func fixed_anchor_probe(use_H: bool) -> void:
	await fixture("explicit_fixed_H" if use_H else "explicit_fixed_ordinary",use_H)
	for index: int in 1500:
		if queen.stage_phase>=2 or queen.health.terminal: break
		controller.router.set_move_axis(0 if absf(player.position.x-480)<5 else signf(480-player.position.x))
		continuous_fire();await frames(1)
	await walk(450)
	check(await cut_field(1),"probe clears primary only through actual normal bullets")
	await walk(330)
	for index: int in 200:
		if is_instance_valid(queen.bands[2]) and queen.bands[2].growth>=1: break
		await frames(1)
	check(is_instance_valid(queen.bands[2]) and queen.bands[2].growth>=1,"same actual new lower field is mature before both alternatives")
	var start_hp := controller.actor_resources.health.current
	var hook_point := Vector2(geometry.hook_anchors[0].position[0],geometry.hook_anchors[0].position[1])
	controller.router.request_action(&"drop_through");controller.router.set_move_axis(0)
	for index: int in 40:
		if player.position.y>=400: break
		await frames(1)
	var takeoff := player.position
	var borrowed := false
	if use_H:
		borrowed=await accepted_hook(hook_point)
		check(borrowed,"single relocated fixed anchor actually reaches contact and native kick")
		check(controller.actor_resources.health.current==start_hp,"true fixed H contact and kick clear mature band without immunity or refund")
		if borrowed:
			controller.router.request_action(&"shoot_release",Vector2.DOWN);await frames(15)
			await walk(450)
			for index: int in 150:
				if player.is_on_floor(): break
				await frames(1)
			controller.router.set_move_axis(0)
		check(player.is_on_floor() and player.position.y<360,"fixed drop-H then ordinary R returns full body to middle bank")
		check(player.position.x-actual_body_half.x>=300 and player.position.x+actual_body_half.x<=600,"fixed anchor return has complete horizontal body support")
		var overlaps := 0
		for frame: Dictionary in frames_data:
			if frame.get("case")!=current: continue
			var body_rect := Rect2(Vector2(frame.player[0],frame.player[1])-actual_body_half,actual_body_half*2)
			for platform: Dictionary in geometry.platforms:
				if not str(platform.id).begins_with("queen_root_"): continue
				var a: Array=platform.rect
				if body_rect.intersects(Rect2(a[0],a[1],a[2],a[3])): overlaps+=1
		check(overlaps==0,"every captured full Player body remains outside the unchanged solid root")
	else:
		for index: int in 100:
			if player.is_on_floor() and player.position.y>560: break
			await frames(1)
		check(controller.actor_resources.health.current<start_hp,"ordinary same drop really intersects lower weave and loses normal HP")
		await regain_middle_bank()
		check(player.is_on_floor() and player.position.y<360,"ordinary hurt alternative remains recoverable with unchanged jump/R")
	cases.append({"id":current,"explicit_initial_probe":true,"ticks":tick,"initial_probe_hp":start_hp,"final_hp":controller.actor_resources.health.current,"fixed_anchor":[hook_point.x,hook_point.y],"takeoff":[takeoff.x,takeoff.y],"borrowed":borrowed,"returned":player.is_on_floor() and player.position.y<360,"final_position":[player.position.x,player.position.y],"scope":"single relocated existing anchor and identical actual-mature-field ordinary drop; not complete fight"})
func shore_response(use_H: bool,existing_fixture := false) -> Dictionary:
	if not existing_fixture: await fixture("shore_response_H" if use_H else "shore_response_ordinary",true)
	var row := {"id":current,"explicit_initial_probe":false,"bounded_local_response":true,"initial_player_hp":controller.actor_resources.health.current,"initial_boss_hp":queen.health.current,"initial_energy":controller.actor_resources.stamina.current,"initial_fields":field_healths()}
	# Exact ordinary prefix from enter_upper(false), observing the real preview rather than a tick.
	check(await right_gap_approach(),"normal floor approach reaches the original gap")
	controller.router.set_jump_held(&"queen_network",true);await frames(23);controller.router.set_jump_held(&"queen_network",false)
	controller.router.request_action(&"shoot_release",Vector2.DOWN);await frames(15)
	controller.router.request_action(&"shoot_release",Vector2.LEFT)
	for index: int in 30:
		await frames(1)
		if queen.motion_mode=="migration_preview": break
	check(queen.motion_mode=="migration_preview" and queen.route_phase==1,"response begins only after actual first full-route warning")
	row.preview_tick=tick;row.preview_player=[player.position.x,player.position.y]
	row.borrowed=false;row.fallback=false
	if use_H:
		var target := queen.knots[0]
		var hook_start := player.position+Vector2(0,-6)
		if is_instance_valid(target) and not target.health.terminal and hook_start.distance_to(target.global_position)<=controller.traversal.definition.hook_range:
			row.borrowed=await accepted_hook(target.global_position)
		else: row.fallback=true
	var jump_release_at := -1
	var supported := 0
	var shots_before := events.filter(func(e: Dictionary) -> bool: return e.get("case")==current and e.get("event")=="accepted_shot").size()
	while tick<1000 and not controller.actor_resources.health.terminal:
		if jump_release_at>=0 and tick>=jump_release_at:
			controller.router.set_jump_held(&"queen_response",false);jump_release_at=-1
		if queen.migrations>=1:
			controller.router.set_jump_held(&"queen_response",false);jump_release_at=-1
			if player.is_on_floor() and player.position.y>=360 and player.position.y<500:
				# Existing side-bank jump crosses horizontally instead of rising through a perched Queen.
				await move_to_middle()
			if player.is_on_floor() and player.position.y>=500:
				# The unchanged root blocks straight-up recovery at450: use the original clear gap.
				var gap := 330.0 if absf(player.position.x-330)<absf(player.position.x-620) else 620.0
				await walk(gap)
			if not player.is_on_floor() or player.position.y>=360: await regain_middle_bank()
			controller.router.set_move_axis(0 if absf(player.position.x-450)<5 else signf(450-player.position.x))
			supported=supported+1 if player.is_on_floor() and absf(player.position.y-342)<1 and player.position.x-actual_body_half.x>=300 and player.position.x+actual_body_half.x<=600 else 0
			if supported>=12: break
		else:
			controller.router.set_move_axis(0 if absf(player.position.x-450)<5 else signf(450-player.position.x))
			var approaching := queen.motion_mode=="flight" and absf(queen.motor.position.x-player.position.x)<200 and absf(queen.motor.position.y-player.position.y)<140
			if player.is_on_floor() and approaching and jump_release_at<0:
				controller.router.set_jump_held(&"queen_response",true);jump_release_at=tick+23
				events.append({"event":"observed_patrol_jump","case":current,"tick":tick,"queen":[queen.motor.position.x,queen.motor.position.y],"player":[player.position.x,player.position.y]})
			var shot := ordinary_surface_aim()
			# Airborne fire is chosen only when normal recoil lifts away from the visible body path.
			var shot_direction: Vector2=shot.get("aim",Vector2.UP)
			var reserve := controller.shot_energy.shot_energy_cost
			var safe_to_fire := (player.is_on_floor() and jump_release_at<0) or (not player.is_on_floor() and not shot.is_empty() and shot_direction.y>=0)
			if safe_to_fire and controller.actor_resources.stamina.current>=reserve*2: continuous_fire()
		await frames(1)
	controller.router.set_jump_held(&"queen_response",false);controller.router.set_move_axis(0)
	var body_damage := events.filter(func(e: Dictionary) -> bool: return e.get("case")==current and e.get("event")=="policy_result" and e.get("target")=="player" and e.get("source")=="queen_body_contact")
	row.body_damage=body_damage.size();row.player_damage=row.initial_player_hp-controller.actor_resources.health.current
	row.boss_damage=row.initial_boss_hp-queen.health.current;row.ticks=tick;row.return_support_frames=supported;row.final_position=[player.position.x,player.position.y]
	row.final_energy=controller.actor_resources.stamina.current;row.real_migrations=queen.migrations
	row.accepted_response_shots=events.filter(func(e: Dictionary) -> bool: return e.get("case")==current and e.get("event")=="accepted_shot").size()-shots_before
	var a: Array=geometry.boss_arena
	row.retained_in_arena=Rect2(a[0],a[1],a[2],a[3]).encloses(Rect2(player.position-actual_body_half,actual_body_half*2))
	check(row.body_damage==0,"reading the locked whole path permits ordinary avoidance without body immunity")
	check(supported>=12,"response returns to twelve real complete-body support frames on original wide bank")
	check(not controller.actor_resources.health.terminal and row.retained_in_arena,"response remains alive in true closed arena")
	if use_H: check(row.borrowed or row.fallback,"available living knot is genuinely borrowed, or normal fallback remains explicit")
	else: check(not events.any(func(e: Dictionary) -> bool: return e.get("case")==current and e.get("event")=="actual_queued_input" and e.get("action")=="grapple"),"ordinary warning response uses no H")
	if not existing_fixture:
		cases.append(row)
		persist_response_partial()
	return row
func persist_response_partial() -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	var partial := {"scope":"Original local response checkpoint; a partial does not establish native success","selected":selected,"cases":cases,"frames":frames_data,"events":events,"failures":failures,"assertions":assertions,"current":current}
	FileAccess.open(output_dir+"/partial-"+current+".json",FileAccess.WRITE).store_string(JSON.stringify(partial))
func run() -> void:
	if selected=="adaptive_full":
		_adaptive_response=true;_adaptive_entry_done=false
		await full_fight("full_H")
		cases.back()["p1_warning_response"]=_adaptive_entry_result
		_adaptive_response=false;_adaptive_entry_done=false
	if selected in ["shore_response","shore_H"]:
		if selected=="shore_response": await shore_response(false)
		await shore_response(true)
	if selected in ["all","full","collision"]: await collision_semantics_probe()
	for strategy: String in ["full_H","full_cut","full_keep","full_wait","full_edge"]:
		if selected in ["all","full",strategy]: await full_fight(strategy)
	if selected in ["all","full","rising"]: await rising_observer()
	if selected in ["all","mature"]: await mature_landing()
	if selected in ["all","observer"]: await rotating_observer()
	if selected in ["all","fixed"]:
		await fixed_anchor_probe(true)
		await fixed_anchor_probe(false)
	await cleanup()
	DirAccess.make_dir_recursive_absolute(output_dir)
	var report := {"capture_schema":9,"task_id":"FOREST-DEPTH-02","scope":"Canonical actual equal-resource full fights and strict bounded stationary ablation, plus moving-network malformed-save probe; whole Boss and map2 admission pending","selected":selected,"assertions":assertions,"failures":failures,"cases":cases,"events":events,"frames":frames_data,"geometry":geometry,"migration_speed":(queen_definition() as ThornQueenWeaveDefinition).migration_speed,"player_tuning_sha256":FileAccess.get_sha256("res://config/player_tuning.json"),"manual_motor_step":false,"midroute_player_position_or_resource_writes":false,"design_verdict":"independent_value_review_required"}
	FileAccess.open(output_dir+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("QUEEN SWEEP GOLDEN: %s assertions, %s failures"%[assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
