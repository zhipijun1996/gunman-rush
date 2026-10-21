extends "res://tests/forest_player_aim_trace.gd"
## New world reader, using actual formal spawn and the unchanged PlayerMotor.
var _bible_weaver_started := -1
var _bible_weaver_requests := 0
var _bible_weaver_bank := Vector2.ZERO
func begin() -> void:
	air_chain_case = preload("res://tests/forest_bible_world_air_case.gd").new()
	interwoven_crown_case = preload("res://tests/forest_bible_world_crown_combat_case.gd").new()
	grove_combat_case = preload("res://tests/forest_bible_world_grove_combat_case.gd").new()
	await super.begin()
	if not initialized or not failures.is_empty(): return
	_build_bible_itinerary(manifest.routes.get(route_name,[]))

func _build_bible_itinerary(route_ids: Array) -> void:
	# The historical reader deliberately only expands its historical layouts.
	# Expand v15 here without changing old tests, physical code or old pins.
	controller.router.action_rejected.connect(func(reason: String) -> void: event("actual_input_rejected",{"reason":reason}))
	controller.router.cancelled.connect(func(reason: String) -> void: event("actual_input_cancelled",{"reason":reason}))
	itinerary.clear()
	for id: String in route_ids:
		var edge: Dictionary = ThornForestRegionV2V10._edge_by_id(manifest,id).duplicate(true)
		if edge.is_empty(): fail("Bible_actual_edge_missing/"+id); return
		if edge.kind == "ordinary_sequence":
			for index: int in edge.steps.size():
				var step: Dictionary = edge.steps[index].duplicate(true)
				step.edge_id = id; step.step_index = index
				if index == 0:
					for key: String in ["claim_before_edge","claim_area","claim_id"]:
						if edge.has(key): step[key] = edge[key]
				itinerary.append(step)
			itinerary.append({"kind":"walk","edge_id":id,"landing":edge.path[-1].duplicate(),"step_index":edge.steps.size(),"b":edge.b})
		else:
			edge.edge_id = id
			edge.landing = edge.get("landing",edge.path[-1]).duplicate()
			itinerary.append(edge)
			for index: int in edge.get("post_landing_steps",[]).size():
				var step: Dictionary = edge.post_landing_steps[index].duplicate(true)
				step.edge_id = id; step.step_index = index; step.post_landing = true
				itinerary.append(step)
			if edge.kind == "hollow_recovery": itinerary.append({"kind":"walk","edge_id":id,"landing":edge.path[-1].duplicate(),"post_recovery_align":true})
	if itinerary.is_empty(): fail("Bible_actual_itinerary_empty")

func _physics_process(delta: float) -> void:
	# The frozen historical reader's outer grove whitelist excludes v15.
	# Offer the same actual-input ground combat pilot here before delegating.
	# A handled frame still has one ordinary Motor tick and one observation.
	if initialized and not finished and not get_tree().paused and is_instance_valid(player) and is_instance_valid(controller) and app.lifetime.active and leg_index < itinerary.size():
		before_steps = player.motion_steps
		if _drive_bible_weaver_clearance(itinerary[leg_index]) or grove_combat_case.drive(self,itinerary[leg_index]):
			tick += 1; age += 1
			if tick > 18000: fail("route_tick_budget")
			if tick-leg_started > 1800: fail("edge_tick_budget/"+str(leg_index)+"/"+phase)
			return
	super._physics_process(delta)

func _drive_bible_weaver_clearance(leg: Dictionary) -> bool:
	if str(leg.get("edge_id","")) != "bible_web_lower_out": return false
	var actor: EnemyActor
	for index: int in stage.enemy_manifest.size():
		if str(stage.enemy_manifest[index].id) == "bible_double_window_weaver": actor = stage.enemies[index].get_node("Actor") as EnemyActor
	if not is_instance_valid(actor): fail("Bible_formal_weaver_missing"); return true
	if actor.health.terminal:
		if _bible_weaver_started >= 0:
			event("bible_weaver_actual_terminal_before_crossing",{"enemy_health":actor.health.current,"actual_requests":_bible_weaver_requests})
			_bible_weaver_started = -1
		return false
	if _bible_weaver_started < 0:
		_bible_weaver_started = tick
		_bible_weaver_bank = Vector2(1260.0,1182.0)
		event("bible_weaver_safe_root_gun_choice",{"enemy_id":"bible_double_window_weaver","enemy_health":actor.health.current,"position":pair(player.global_position),"supports":supports()})
	if tick-_bible_weaver_started > 600: fail("Bible_weaver_legal_gun_choice_budget"); return true
	controller.router.set_move_axis(clampf((_bible_weaver_bank.x-player.global_position.x)/12.0,-1.0,1.0))
	jump(false)
	if not player.is_on_floor(): fail("Bible_weaver_gun_choice_departed_safe_root"); return true
	if not _aim_kind.is_empty(): return true
	if controller.shoot_ability.cooldown_remaining > 0.0 or player.recoil_burst_remaining > 0.0 or not at_destination(_bible_weaver_bank,"bible_root_step1"): return true
	_bible_weaver_requests += 1
	if _bible_weaver_requests > 12: fail("Bible_weaver_legal_shot_request_budget"); return true
	event("bible_weaver_actual_shot_intent",{"ordinal":_bible_weaver_requests,"enemy_health":actor.health.current,"aim":pair((actor.motor.global_position-player.global_position).normalized())})
	request(&"shoot_release",(actor.motor.global_position-player.global_position).normalized())
	return true

func drive_jump(leg: Dictionary) -> void:
	if not bool(leg.get("hold_until_ceiling_or_receiver",false)):
		super.drive_jump(leg)
		return
	# This lateral window needs continued ascent until its real ceiling or the
	# receiver's full-body horizontal clearance. Early vertical-only release
	# removes the time needed to move the complete body onto the old root.
	var takeoff := point(leg.takeoff)
	var landing := point(leg.landing)
	if phase == "align":
		controller.router.set_move_axis(clampf((takeoff.x-player.global_position.x)/12.0,-1.0,1.0))
		if at_destination(takeoff,str(leg.from_support_id)) and player.recoil_burst_remaining <= 0.0:
			jump(true); set_phase("jumping")
	else:
		controller.router.set_move_axis(clampf((landing.x-player.global_position.x)/12.0,-1.0,1.0))
		release_gap_before_ceiling(str(leg.support_id))
		# Retain the original collision, full-body, descending, timeout and
		# wrong-support assertions. Only the lawful jump-release time differs.
		release_jump_after_clearance(str(leg.support_id))
		stable = stable+1 if at_destination(landing,str(leg.support_id)) else 0
		if stable >= 12: complete_leg()

func drive_candidate_relay(leg: Dictionary) -> void:
	var goal:=point(leg.landing)
	if str(leg.edge_id)=="north_reward":
		# This edge is a candidate, not an H password. Follow its real
		# descending mouth; solid floors must be walked off normally.
		if phase=="align" and age==1: event("candidate_relay_method",{"method":"normal_descent","edge_id":leg.edge_id})
		drive_drop(leg)
		return
	if str(leg.edge_id) not in ["west_north","bible_north_approach"]: fail("unsupported_candidate_relay/"+str(leg.edge_id));return
	if age>240: fail("bounded_candidate_relay/"+phase);return
	if phase=="align":
		var start:=point(leg.path[0])
		controller.router.set_move_axis(clampf((start.x-player.global_position.x)/12,-1,1))
		stable=stable+1 if at_destination(start,"west_court") else 0
		if stable>=12: jump(true);set_phase("relay_launch")
	elif phase=="relay_launch":
		controller.router.set_move_axis(0)
		var target: Node2D=stage.assembler.hook_targets.get(str(leg.anchor_id))
		if not is_instance_valid(target): fail("candidate_relay_anchor_missing");return
		var offset:=target.global_position-player.global_position-Vector2(0,-6)
		var court:=platform("north_court")
		if court.is_empty(): fail("candidate_relay_north_support_missing");return
		var origin:=player.global_position+Vector2(0,-6)
		var radius: float=controller.traversal.definition.hook_capture_radius
		# Bodies can jump upward through this one-way surface, while the
		# real hook sweep still hits it. Clear the entire cast circle first.
		if player.global_position.y<=float(leg.path[1][1]) and origin.y+radius<=float(court.rect[1])-1 and player.velocity.y<0 and offset.length()<=controller.traversal.definition.hook_range:
			event("candidate_relay_method",{"method":"jump_H","edge_id":leg.edge_id,"anchor_id":leg.anchor_id,"anchor_position":pair(target.global_position),"offset":pair(offset),"hook_origin":pair(origin),"hook_capture_radius":radius,"cleared_support_id":"north_court","cleared_rect":court.rect.duplicate()})
			if hook(str(leg.anchor_id)): set_phase("relay_hook")
		elif age>30: fail("candidate_relay_jump_range_missed")
	elif phase=="relay_hook":
		controller.router.set_move_axis(0)
		if not _aim_kind.is_empty(): return
		var cast_seen := false
		for actual: Dictionary in events:
			if int(actual.leg) == leg_index and actual.kind == "hook_cast": cast_seen = true
		if not cast_seen: return
		jump(false)
		if controller.traversal.state==&"free" and age>12:
			var contact:=false
			for accepted: Dictionary in events:
				if int(accepted.leg)==leg_index and accepted.kind=="hook_contact_kick" and accepted.get("target","")==str(leg.anchor_id): contact=true
			if not contact: fail("candidate_relay_H_missed_actual_target");return
			set_phase("relay_land")
	elif phase=="relay_land":
		controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/12,-1,1))
		stable=stable+1 if at_destination(goal,"north_court") else 0
		if stable>=12: complete_leg()

func _process(delta: float) -> void:
	var samples_before := aim_samples.size()
	super._process(delta)
	if aim_samples.size() > samples_before:
		event("bible_actual_aim_release",{"sample":aim_samples[-1].duplicate(true),"queued_router_envelopes":controller.router._queue.duplicate(true),"router_epoch":controller.router.epoch,"router_sequence":controller.router.sequence})

	# Human aim processing does not invoke the historical modal handler.
	# Preserve its exact real-pointer cache acceptance while the modal pauses.
	if not initialized or finished or not cache_pending: return
	if not is_instance_valid(app) or not is_instance_valid(stage) or not is_instance_valid(player) or not is_instance_valid(controller) or not app.lifetime.active:
		fail("actual_run_ended");return
	if app.reward_modal.opened:
		modal_age+=1
		modal_frames.append({"index":modal_age,"tick":tick,"paused":get_tree().paused,"position":pair(player.global_position),"motion_steps":player.motion_steps,"supports":supports()})
		movie_stamp(modal_frames[-1])
		if modal_age==4:
			for button: Button in app.reward_modal.find_children("*","Button",true,false):
				if button.visible and not button.disabled:
					modal_button=button;modal_point=button.get_global_rect().get_center();send_pointer(true);break
		elif modal_age==5 and is_instance_valid(modal_button): send_pointer(false)
		if modal_age>90: fail("actual_cache_pointer_timeout")
	else:
		for chest: Dictionary in stage.chests:
			if chest.id=="thorn_forest/map_%s/"%map_index+claim_local_id and chest.claimed and stage.region_state.claimed.has(chest.id):
				cache_claimed=true;claim_after=stage.region_state.claimed.duplicate(true)
		if modal_age==0 and age>90: fail("cache_modal_did_not_open")
func drive_hollow(leg: Dictionary) -> void:
	super.drive_hollow(leg)
	# Real human aim consumes 0.35 seconds before the accepted R. Keep a
	# right-hand airborne firing bank so its left recoil receives on D,
	# instead of walking left during the hold and recoiling into the seed.
	if str(leg.kind) == "hollow_outer_recovery" and phase == "hollow_lower_land" and _aim_kind == "shot":
		controller.router.set_move_axis(clampf((860.0-player.global_position.x)/12.0,-1.0,1.0))
