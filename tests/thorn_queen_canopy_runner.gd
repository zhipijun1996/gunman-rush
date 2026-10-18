extends "res://tests/support/forest_queen_canopy_fixture.gd"
## New content consumer; never substitutes this result for legacy194.
func fixture(id: String,h_enabled := true,hazard_probe := false,body_probe := false) -> void:
	await super.fixture(id,h_enabled,hazard_probe,body_probe)
	(queen.motor as ThornQueenWeaveMotor).movement_observed.connect(func(data: Dictionary) -> void:
		var e := data.duplicate(true);e["event"]="actual_queen_motor_motion";e["source_id"]=queen.motor.get_instance_id();e["case"]=current;e["tick"]=tick+1;events.append(e))
	controller.energy_recovered.connect(func(amount: float,airborne: bool) -> void: events.append({"event":"actual_energy_recovery","case":current,"tick":tick+1,"amount":amount,"airborne":airborne}))
func frames(count: int) -> void:
	for i: int in count:
		if is_instance_valid(controller):
			for action: Dictionary in controller.router._queue: events.append({"event":"actual_queued_input","case":current,"tick":tick+1,"action":String(action.type),"direction":[action.direction.x,action.direction.y]})
		await super.frames(1)
		if frames_data.is_empty() or not is_instance_valid(queen): continue
		var row: Dictionary=frames_data.back()
		row.queen_motor_id=queen.motor.get_instance_id();row.physics_frame=Engine.get_physics_frames()
		row.actual_time_scale=Engine.time_scale;row.actual_focus=controller.air_focus_ability.active
		row.normal_velocity=[player.normal_velocity.x,player.normal_velocity.y];row.recoil_remaining=player.recoil_burst_remaining
		row.hook_start=[controller.traversal.hook_start.x,controller.traversal.hook_start.y];row.hook_tip=[controller.traversal.hook_tip.x,controller.traversal.hook_tip.y]
		row.pending_actual_grants=[]
		for grant: Dictionary in controller.received_resource_grants: row.pending_actual_grants.append({"amount":grant.amount,"session_id":grant.session_id})
func air_future(seconds: float) -> Vector2:
	var at := queen.motor.position
	var section: int=queen.motion_section
	var leg: int=queen.motion_leg
	var remaining := seconds
	if queen.motion_mode=="intro": remaining=maxf(0,remaining-queen.motion_clock-queen.config().canopy_preview)
	elif queen.motion_mode=="migration_preview": remaining=maxf(0,remaining-queen.motion_clock)
	for iteration: int in 40:
		var points: Array=geometry.motion_paths[section]
		var a: Array=points[leg+1];var goal := Vector2(a[0],a[1])
		var distance := at.distance_to(goal)
		var duration := distance/queen.config().canopy_speed
		if remaining<=duration: return at.move_toward(goal,remaining*queen.config().canopy_speed)
		remaining-=duration;at=goal
		if leg<points.size()-2: leg+=1
		else:
			section=(section+1)%geometry.motion_paths.size();leg=0
			if remaining<=queen.config().canopy_preview: return at
			remaining-=queen.config().canopy_preview
	return at
func air_aim(second: bool) -> Dictionary:
	var half := queen.definition.collision_size*.5-Vector2(2,2)
	var samples: Array[Vector2]=[Vector2.ZERO,Vector2(0,-half.y),Vector2(-half.x,0),Vector2(half.x,0),Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(-half.x,half.y),Vector2(half.x,half.y),Vector2(0,half.y)]
	var visual := player.get_node("CourierVisual") as CourierVisual
	var circle := CircleShape2D.new();circle.radius=controller.shoot_ability.tuning.projectile_radius
	for sample: Vector2 in samples:
		var target := queen.motor.position+sample
		var aim := (target-player.position).normalized()
		var muzzle := visual.muzzle_position(aim)
		var predicted_center := queen.motor.position
		for i: int in 4:
			predicted_center=air_future(muzzle.distance_to(target)/controller.shoot_ability.tuning.projectile_speed)
			target=predicted_center+sample;aim=(target-muzzle).normalized();muzzle=visual.muzzle_position(aim)

		if clear_ordinary_segment(player.position,muzzle,circle) and clear_ordinary_segment(muzzle,target,circle):
			return {"aim":aim,"muzzle":muzzle,"target":target,"predicted_center":predicted_center,"surface":sample}
	return {}
func air_anchor(id: String) -> Vector2:
	for a: Dictionary in geometry.hook_anchors:
		if a.id==id: return Vector2(a.position[0],a.position[1])
	return Vector2.INF
func air_request_hook(point: Vector2,label: String) -> bool:
	var start := tick
	var origin := player.position+Vector2(0,-6)
	var accepted := controller.router.request_action(&"grapple",(point-origin).normalized())
	events.append({"event":"air_hook_request","case":current,"tick":tick,"label":label,"origin":[origin.x,origin.y],"target":[point.x,point.y],"center_distance":origin.distance_to(point),"queued":accepted})
	for i: int in 100:
		await frames(1)
		if controller.traversal.state==&"hook_kick": return true
		if controller.traversal.state in [&"hook_miss",&"hook_retract"]: return false
		if tick>start+12 and controller.traversal.state==&"free": return false
	return false
func support_id() -> String:
	for row: Dictionary in geometry.receiver_fields:
		var a: Array=row.support
		if player.is_on_floor() and absf(player.position.y+18-float(a[1]))<1 and player.position.x-12>=float(a[0]) and player.position.x+12<=float(a[0])+float(a[2]): return str(row.id)
	return ""
func target_clear(first: Vector2,last: Vector2,target: PhysicsBody2D) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new();circle.radius=controller.shoot_ability.tuning.projectile_radius
	query.shape=circle;query.transform=Transform2D(0,first);query.collision_mask=0xFFFFFFFF;query.collide_with_areas=true;query.exclude=[player.get_rid(),target.get_rid()]
	var space := player.get_world_2d().direct_space_state
	if not space.intersect_shape(query,1).is_empty(): return false
	query.motion=last-first
	var swept := space.cast_motion(query)
	return swept.size()==2 and swept[0]>=.99999
func knot_aim(index: int) -> Dictionary:
	if not is_instance_valid(queen.knots[index]) or queen.knots[index].health.terminal: return {}
	var target := queen.knots[index]
	var half := target.body_size*.5-Vector2(1,1)
	var samples: Array[Vector2]=[Vector2.ZERO,Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(-half.x,half.y),Vector2(half.x,half.y),Vector2(-half.x,0),Vector2(half.x,0),Vector2(0,-half.y),Vector2(0,half.y)]
	var visual := player.get_node("CourierVisual") as CourierVisual
	for sample: Vector2 in samples:
		var point := target.global_position+sample
		var aim := (point-player.position).normalized()
		var muzzle := visual.muzzle_position(aim)
		if target_clear(player.position,muzzle,target) and target_clear(muzzle,point,target): return {"aim":aim,"target":point,"muzzle":muzzle,"knot":index}
	return {}
func fire_visible(cut: bool) -> bool:
	if queen.health.terminal or controller.actor_resources.health.terminal or controller.shoot_ability.cooldown_remaining>0 or controller.actor_resources.stamina.current<20: return false
	if not player.is_on_floor() and controller.action_resources.shot_charges<=0: return false
	var solution: Dictionary={}
	if cut:
		for index: int in 2:
			solution=knot_aim(index)
			if not solution.is_empty(): break
	if solution.is_empty(): solution=air_aim(false)
	if solution.is_empty(): return false
	events.append({"event":"continuous_shot_request","case":current,"tick":tick,"target_kind":"knot" if solution.has("knot") else "boss","aim":[solution.aim.x,solution.aim.y],"muzzle":[solution.muzzle.x,solution.muzzle.y]})
	return controller.router.request_action(&"shoot_release",solution.aim)
func persist_partial() -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	var report := {"capture_schema":1,"content_version":ThornQueenCanopyDefinition.VERSION,"selected":selected,"assertions":assertions,"failures":failures,"cases":cases,"events":events,"frames":frames_data,"geometry":geometry,"migration_speed":queen.config().canopy_speed if is_instance_valid(queen) else 360.0,"manual_motor_step":false,"midroute_player_position_or_resource_writes":false}
	FileAccess.open(output_dir+"/partial.json",FileAccess.WRITE).store_string(JSON.stringify(report))
func full_fight(strategy: String) -> void:
	await fixture(strategy,strategy=="purpose")
	var prefix_ok := true
	var chain_air_start := -1
	var chain_air_end := -1
	if strategy=="purpose":
		for i: int in 180:
			if queen.motion_mode=="migration_preview": break
			await frames(1)
		prefix_ok=await air_request_hook(air_anchor("A"),"A")
		if prefix_ok:
			var opening := air_aim(false)
			prefix_ok=not opening.is_empty()
			if prefix_ok:
				controller.router.request_action(&"shoot_release",opening.aim);chain_air_start=tick+1;controller.router.set_move_axis(1)
				await frames(10)
				for i: int in 40:
					if player.recoil_burst_remaining<=0 and controller.traversal.state==&"free": break
					await frames(1)
				for i: int in 50:
					await frames(1)
					if player.normal_velocity.y>0 and player.position.y+18>=188: break
				prefix_ok=await air_request_hook(air_anchor("B"),"B")
				if prefix_ok:
					for i: int in 90:
						if player.is_on_floor(): break
						if fire_visible(false): chain_air_end=tick+1;break
						await frames(1)
		check(prefix_ok and chain_air_start>0 and chain_air_end>chain_air_start,"purpose actual first flanking H/R/sideH and earliest visible moving-body shot, no forced Q2 threshold")
		if not prefix_ok: persist_partial();return
	var holding := 0
	var jumped := strategy=="purpose"
	var recovery := -1
	var stable := 0
	var kill_tick := -1
	var high_attempted := false
	var receiver_attempted := false
	var high_prepare := -1
	var phase_three_support := ""
	var shore_response := false
	var shore_arrived := false
	var shore_support := 0
	var shore_lock_tick := -1
	var shore_departure_tick := -1
	var shore_r_count := 0
	var shore_jumped := false
	var lure_ready := false
	var lure_stage_tick := -1
	var lure_ready_tick := -1
	for i: int in 1800:
		if controller.actor_resources.health.terminal: break
		if queen.health.terminal:
			if kill_tick<0: kill_tick=tick
			controller.router.set_move_axis(0)
			if not support_id().is_empty(): stable+=1
			else: stable=0
			if stable>=12: break
		else:
			if not jumped and queen.motion_mode=="migration_preview": controller.router.set_jump_held(&"canopy_fight",true);holding=23;jumped=true
			# Purpose may borrow the new high-side living route; strong ordinary can clear it.
			if strategy=="purpose" and queen.stage_phase>=2 and not high_attempted and is_instance_valid(queen.knots[0]) and not queen.knots[0].health.terminal:
				var knot := queen.knots[0].global_position
				if controller.traversal.state==&"free" and (player.position+Vector2(0,-6)).distance_to(knot)<=225:
					high_attempted=true
					var borrowed := await air_request_hook(knot,"high_living_knot")
					events.append({"event":"actual_high_route_attempt","case":current,"tick":tick,"contact":borrowed})
				elif support_id()=="right" and high_prepare<0:
					controller.router.set_jump_held(&"canopy_fight",true);holding=23;high_prepare=0
			if high_prepare>=0 and high_prepare<35:
				high_prepare+=1
				if high_prepare==12 and controller.shoot_ability.cooldown_remaining<=0: controller.router.request_action(&"shoot_release",Vector2.DOWN)
			if strategy=="purpose" and queen.stage_phase>=3 and not receiver_attempted and is_instance_valid(queen.knots[1]) and not queen.knots[1].health.terminal:
				var knot := queen.knots[1].global_position
				if controller.traversal.state==&"free" and (player.position+Vector2(0,-6)).distance_to(knot)<=225:
					receiver_attempted=true;phase_three_support=support_id()
					var borrowed := await air_request_hook(knot,"locked_receiver_living_knot")
					events.append({"event":"actual_receiver_route_attempt","case":current,"tick":tick,"contact":borrowed,"receiver":queen.locked_receiver_id})
					if borrowed:
						# At the first shoot-eligible kick, the knot is left/down; real gun/R
						# removes its last HP and carries the body right/up off the locked S.
						var cut := knot_aim(1)
						check(not cut.is_empty() and controller.shoot_ability.cooldown_remaining<=0 and controller.action_resources.shot_charges>0,"receiver borrow leaves a genuine loaded clear reverse shot")
						if not cut.is_empty():
							events.append({"event":"receiver_reverse_cut_request","case":current,"tick":tick,"body":[player.position.x,player.position.y],"target":[cut.target.x,cut.target.y],"aim":[cut.aim.x,cut.aim.y]})
							controller.router.request_action(&"shoot_release",cut.aim)
							await frames(1)
			# Lure is a different real shore selection, not a second name for the keep route.
			# The player voluntarily delays Boss shots while normally travelling; HP is never locked.
			if strategy=="lure" and queen.stage_phase==2 and not shore_response and is_instance_valid(queen.knots[0]) and queen.knots[0].health.terminal:
				check(queen.health.current>queen.health.capacity*queen.config().phase_three_health,"lure begins normal travel before the next health threshold")
				shore_response=true;lure_stage_tick=tick
				events.append({"event":"lure_prepare_actual_right_support","case":current,"tick":tick,"boss_hp":queen.health.current})
			if strategy in ["ordinary_keep","lure"] and queen.stage_phase>=3 and shore_lock_tick<0:
				shore_response=true;shore_lock_tick=tick
				if strategy=="lure": check(lure_ready and queen.locked_receiver_id=="right","prior normal full-foot12 genuinely induces the other right receiver row")
				else: check(queen.locked_receiver_id=="S","this finite ordinary response prefix actually locks its old S shore")
				events.append({"event":"normal_shore_response_started","case":current,"tick":tick,"locked":queen.locked_receiver_id,"target":"right","body":[player.position.x,player.position.y],"field_age":queen.bands[1].age})
			if shore_response:
				controller.router.set_move_axis(0 if absf(850-player.position.x)<3 else signf(850-player.position.x))
				if not shore_arrived:
					if player.is_on_floor() and support_id()=="S" and not shore_jumped:
						controller.router.set_jump_held(&"canopy_fight",true);holding=23;shore_jumped=true
					# Genuine horizontal R, only as needed to maintain full rib clearance.
					# Any Boss gun that would recoil back into S is deferred during this crossing.
					if not player.is_on_floor() and player.position.y+18<=242 and player.position.x<772 and player.recoil_burst_remaining<=0 and controller.shoot_ability.cooldown_remaining<=0 and controller.action_resources.shot_charges>0 and controller.actor_resources.stamina.current>=20 and (shore_r_count==0 or player.position.y+18>=188):
						controller.router.request_action(&"shoot_release",Vector2.LEFT);shore_r_count+=1
						events.append({"event":"normal_shore_crossing_R","case":current,"tick":tick,"number":shore_r_count,"body":[player.position.x,player.position.y]})
					if player.position.x-12>=500 and shore_departure_tick<0: shore_departure_tick=tick
					if support_id()=="right": shore_support+=1
					else: shore_support=0
					if shore_support>=12:
						shore_arrived=true
						if strategy=="lure": lure_ready=true;lure_ready_tick=tick
						events.append({"event":"normal_new_shore_support12","case":current,"tick":tick,"body":[player.position.x,player.position.y]})
					if player.position.x>=772 and strategy!="lure": fire_visible(false)
				else: fire_visible(strategy=="lure" and queen.stage_phase>=3)
				if holding==0 and player.is_on_floor() and queen.motor.position.distance_to(player.position)<155 and absf(queen.motor.position.y-player.position.y)<115:
					controller.router.set_jump_held(&"canopy_fight",true);holding=23
				if holding>0:
					holding-=1
					if holding==0: controller.router.set_jump_held(&"canopy_fight",false)
				await frames(1)
				continue
			if recovery<0 and support_id()=="low":
				recovery=0;holding=23;controller.router.set_jump_held(&"canopy_fight",true)
			if recovery>=0:
				recovery+=1;controller.router.set_move_axis(-1 if player.position.x>475 else 0)
				if recovery==12 and controller.shoot_ability.cooldown_remaining<=0: controller.router.request_action(&"shoot_release",Vector2.DOWN)
				if support_id()=="S" or recovery>=100: recovery=-1
			else:
				var target_x := 850.0 if player.position.y+18<242 or player.position.x>712 else 450.0
				if strategy=="lure" and queen.stage_phase==2 and is_instance_valid(queen.knots[0]) and queen.knots[0].health.terminal: target_x=450
				controller.router.set_move_axis(0 if absf(target_x-player.position.x)<3 else signf(target_x-player.position.x))
				if not jumped: controller.router.set_move_axis(0)
				if holding==0 and player.is_on_floor() and queen.motor.position.distance_to(player.position)<155 and absf(queen.motor.position.y-player.position.y)<115:
					controller.router.set_jump_held(&"canopy_fight",true);holding=23
				if high_prepare<0 or high_prepare>=35: fire_visible(strategy in ["ordinary_cut","lure"])
		if holding>0:
			holding-=1
			if holding==0: controller.router.set_jump_held(&"canopy_fight",false)
		await frames(1)
	controller.router.set_jump_held(&"canopy_fight",false)
	var own := frames_data.filter(func(f: Dictionary) -> bool: return f.case==current)
	var hits := events.filter(func(e: Dictionary) -> bool: return e.get("case")==current and e.get("event")=="policy_result" and e.get("target")=="boss")
	check(own.all(func(f: Dictionary) -> bool: return Rect2(400,0,560,600).encloses(Rect2(Vector2(f.player[0],f.player[1])-Vector2(12,18),Vector2(24,36)))),"every actual whole body remains inside physical sealed arena")
	check(queen.health.terminal and not controller.actor_resources.health.terminal and stable>=12,"normal full24HP fight ends alive with actual whole support12")
	check(hits.size()==24,"all24 actual Boss damage commits, no pocket limit or synthetic defeat")
	check(events.any(func(e: Dictionary) -> bool: return e.get("case")==current and e.get("event")=="canopy_phase_started" and e.get("phase")==2),"real damage triggers P2 persistent keep/cut route")
	check(events.any(func(e: Dictionary) -> bool: return e.get("case")==current and e.get("event")=="canopy_phase_started" and e.get("phase")==3),"real damage triggers P3 once-locked old receiving shore")
	if strategy=="purpose" and receiver_attempted:
		check(is_instance_valid(queen.knots[1]) and queen.knots[1].health.terminal and events.any(func(e: Dictionary) -> bool: return e.get("case")==current and e.get("event")=="policy_result" and e.get("target")=="queen/canopy/1" and e.get("hp")==0),"receiver is cut only by a real post-borrow projectile Policy commit")
	if strategy=="ordinary_keep":
		check(shore_response and shore_departure_tick>shore_lock_tick and shore_arrived,"normal warning response actually leaves locked S and reaches different right shore support12")
		check(events.any(func(e: Dictionary) -> bool: return e.get("case")==current and e.get("event")=="policy_result" and e.get("target")=="boss" and int(e.get("tick",0))>shore_departure_tick),"normal response continues real Boss damage after departing the old locked shore")
	if strategy=="lure":
		check(lure_ready and lure_stage_tick>=0 and lure_ready_tick>lure_stage_tick and shore_lock_tick>lure_ready_tick and queen.locked_receiver_id=="right","normal full-foot right shore12 precedes real phase3 locking the different right row")
		check(queen.knots[1].health.terminal and events.any(func(e: Dictionary) -> bool: return e.get("case")==current and e.get("event")=="policy_result" and e.get("target")=="queen/canopy/1" and e.get("hp")==0),"lure's right living knot is genuinely shot and cut, not automatically cleared")
	if strategy!="purpose": check(not events.any(func(e: Dictionary) -> bool: return e.get("case")==current and e.get("event")=="actual_queued_input" and e.get("action")=="grapple"),"ordinary control submits zero actual H input")
	cases.append({"id":current,"initial_player_hp":5,"initial_boss_hp":24,"initial_energy":100,"kill_tick":kill_tick,"ticks":tick,"boss_hp":queen.health.current,"player_hp":controller.actor_resources.health.current,"energy":controller.actor_resources.stamina.current,"support12":stable,"high_attempted":high_attempted,"receiver_attempted":receiver_attempted,"locked_receiver":queen.locked_receiver_id,"chain_start":chain_air_start,"chain_end":chain_air_end,"high_field":bands_state(0),"receiver_field":bands_state(1),"shore_lock_tick":shore_lock_tick,"shore_departure_tick":shore_departure_tick,"shore_arrived":shore_arrived,"shore_crossing_R":shore_r_count,"lure_stage_tick":lure_stage_tick,"lure_ready_tick":lure_ready_tick})
	persist_partial()
func bands_state(index: int) -> Dictionary:
	return {"health":queen.knots[index].health.current,"weave":queen.bands[index].snapshot()} if is_instance_valid(queen.knots[index]) else {"spawned":false}
func run() -> void:
	for strategy: String in ["purpose","ordinary_cut","ordinary_keep","lure"]:
		if selected in ["all",strategy]:
			await full_fight(strategy)
			if not failures.is_empty(): break
	persist_partial()
	await cleanup()
	var partial := FileAccess.open(output_dir+"/partial.json",FileAccess.READ)
	var report: Dictionary=JSON.parse_string(partial.get_as_text())
	report.assertions=assertions;report.failures=failures
	FileAccess.open(output_dir+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("CANOPY QUEEN GOLDEN: %s assertions, %s failures"%[assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
