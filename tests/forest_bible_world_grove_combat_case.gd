extends "res://tests/forest_depth_grove_combat_case.gd"
## V15 test-only admission of the unchanged historical real-input combat pilot.
## Basis SHA256 9b587cc131f31c4abc6cf31042868ba5620570b3eccce2a81c79fd93d5917994.
## V15 extends ground eligibility and keeps human aim stationary until its
## actual shot is accepted. Shared combat helpers and budgets stay inherited.
var pending_shot_intent := -1
func drive(trace: Node,leg: Dictionary) -> bool:
	if pending_shot_intent >= 0:
		if trace.controller.actor_resources.health.terminal:
			trace.fail("forest_encounter_player_death/"+target_id); return true
		if int(trace.app.lifetime.actor_epoch) != saved_actor_epoch or int(trace.controller.router.epoch) != int(trace.get("_aim_epoch")) or int(trace.controller.session_id) != int(trace.get("_aim_session")):
			trace.fail("forest_encounter_pending_shot_epoch_changed/"+target_id); return true
		if int(trace.leg_index) != saved_leg or str(trace.phase) != saved_phase:
			trace.fail("forest_encounter_route_changed/"+target_id); return true
		if int(trace.tick)-started > 600:
			trace.fail("forest_encounter_bounded_return/"+target_id); return true
		var fired := false
		for actual: Dictionary in trace.events:
			if int(actual.tick) >= pending_shot_intent and actual.kind in ["actual_input_rejected","actual_input_cancelled"]:
				trace.fail("forest_encounter_pending_shot_rejected/"+target_id+"/"+str(actual.get("reason","unknown"))); return true
			if actual.kind == "shot_fired" and int(actual.tick) >= pending_shot_intent: fired = true
		if not fired:
			if trace.player.is_on_floor(): trace.controller.router.set_move_axis(0)
			return true
		pending_shot_intent = -1
	if trace.manifest.get("layout_version","") not in ["forest-expedition-airborne-v11","forest-woven-trunk-v12","forest-interwoven-canopy-v13","forest-fruit-routes-v14","forest-bible-world-v15","forest-varied-bible-v17","forest-exploration-places-v18"]:return false
	# Preserve the 0.35s real aim hold and count only newly issued intents.
	if not state.is_empty() and not str(trace.get("_aim_kind")).is_empty(): return true
	if state.is_empty():
		if not _ordinary_ground(trace,leg):return false
		var destination: Vector2=_destination(trace,leg)
		var direction: float=signf(destination.x-trace.player.global_position.x)
		if direction==0:return false
		for index: int in trace.stage.enemy_manifest.size():
			var row: Dictionary=trace.stage.enemy_manifest[index]
			var actor: EnemyActor=trace.stage.enemies[index].get_node("Actor")
			if actor.health.terminal or actor.definition.aerial or actor.definition.behavior_id not in GROUND_BEHAVIORS:continue
			var delta: Vector2=actor.motor.global_position-trace.player.global_position
			# A low spider above the departure shore can intercept the first
			# jump frame. PR96's real hurt recoil makes blindly accepting this
			# contact an invalid route pilot, even if the old pilot survived it.
			var raised_departure: bool=str(leg.kind).begins_with("jump_") and delta.y < -45.0 and delta.y >= -85.0
			if (absf(delta.y)>45 and not raised_departure) or delta.x*direction<=0 or absf(delta.x)>150:continue
			# A jump's authored takeoff is not its threat boundary. A real
			# spider line can cross the rising body beyond that takeoff shore.
			if (actor.motor.global_position.x-destination.x)*direction>25 and not _jump_thread_threat(trace,leg,actor):continue
			for id: String in trace.supports():
				if trace.full_support(id):origin_support=id;break
			if origin_support.is_empty():return false
			var retreat_bank: Vector2=trace.player.global_position-Vector2(direction*32.0,0)
			var need_retreat := not _clear(trace,actor)
			if need_retreat and (not raised_departure or not _ground_bank_safe(trace,retreat_bank,actor.motor.global_position) or not _clear_from(trace,actor,retreat_bank)):continue
			target=actor;target_id=str(row.id);origin=trace.player.global_position
			saved_leg=int(trace.leg_index);saved_phase=str(trace.phase);started=int(trace.tick)
			saved_actor_epoch=int(trace.app.lifetime.actor_epoch)
			shots=0;intent_requests=0;air_shots=0;flight_started=-1;return_stable=0;state="fight"
			if raised_departure:
				firing_bank=origin;firing_support=origin_support;state="raised_firing_bank"
			if need_retreat:
				firing_bank=retreat_bank;firing_support=origin_support;state="retreat_bank"
			trace.controller.router.set_move_axis(0)
			trace.event("forest_encounter_start",_data(trace))
			if need_retreat:trace.event("forest_encounter_raised_departure_retreat",_data(trace).merged({"firing_bank":trace.pair(firing_bank),"reason":"real_departure_collision_and_occluded_near_shore_shot"}))
			break
		if state.is_empty():return false
	if trace.controller.actor_resources.health.terminal:
		trace.fail("forest_encounter_player_death/"+target_id);return true
	if int(trace.app.lifetime.actor_epoch)!=saved_actor_epoch:
		trace.fail("forest_encounter_actor_respawn/"+target_id);return true
	if int(trace.leg_index)!=saved_leg or str(trace.phase)!=saved_phase:
		trace.fail("forest_encounter_route_changed/"+target_id);return true
	if int(trace.tick)-started>600:
		trace.fail("forest_encounter_bounded_return/"+target_id);return true
	if not is_instance_valid(target):
		trace.fail("forest_encounter_target_unloaded/"+target_id);return true
	if state!="return" and target.health.terminal:
		state="return";trace.jump(false)
		trace.event("forest_encounter_terminal",_data(trace))
	if state=="return":
		_return(trace)
		return true
	var position: Vector2=trace.player.global_position
	if _recover_origin_layer(trace):return true
	var offset: Vector2=target.motor.global_position-position
	if state in ["retreat_bank","raised_firing_bank"]:
		trace.jump(false)
		trace.controller.router.set_move_axis(clampf((firing_bank.x-position.x)/12.0,-1,1))
		# Track the real body after hurt knockback as well as its initial pose.
		# The upper-body cast may clear while a center-of-body ray stays blocked.
		var body_aim := _raised_body_aim(trace)
		if trace.at_destination(firing_bank,firing_support) and _ground_bank_safe(trace,position,target.motor.global_position) and _ready_shot(trace) and not body_aim.is_zero_approx():
			_ground_shot(trace,body_aim)
		return true
	var bark: bool=target.definition.behavior_id==&"forest_bark_beetle"
	var front: bool=bark and offset.normalized().dot(Vector2(target.brain.direction,0)) < -cos(deg_to_rad((target.definition as ForestEnemyDefinition).bark_shield_half_angle_degrees))
	var side: float=signf(target.motor.global_position.x-origin.x)
	if side==0:side=1
	var bank: float=target.motor.global_position.x-side*94.0 if bark else origin.x
	if state.begins_with("flank_"):
		_drive_flank(trace)
		return true
	if bark and front and trace.player.is_on_floor() and _unsafe_top_shot(trace,Vector2(bank,position.y)):
		flank_side=side;flank_crossed=false;state="flank_approach"
		trace.event("forest_encounter_flank_choice",_data(trace))
		_drive_flank(trace)
		return true
	if not front and trace.player.is_on_floor() and not _ground_bank_safe(trace,origin,target.motor.global_position):
		flank_side=side;state="flank_set_bank"
		trace.event("forest_encounter_safe_ground_bank_choice",_data(trace))
		_drive_flank(trace)
		return true
	if trace.player.is_on_floor():
		air_shots=0;flight_started=-1
		if bark and front:
			trace.controller.router.set_move_axis(clampf((bank-position.x)/12.0,-1,1))
			if absf(offset.x)<=98 and trace.player.recoil_burst_remaining<=0:
				trace.controller.router.set_move_axis(0)
				trace.jump(true)
				flight_started=int(trace.tick);state="jump"
				trace.event("forest_encounter_jump",_data(trace))
			return true
		trace.controller.router.set_move_axis(clampf((origin.x-position.x)/12.0,-1,1))
		if absf(origin.x-position.x)<=6 and trace.at_destination(origin,origin_support) and _ground_bank_safe(trace,origin,target.motor.global_position) and _ready_shot(trace) and _clear(trace,target):_ground_shot(trace,offset.normalized())
	else:
		# A ground shot can lift the body slightly. It is not an airborne
		# combat-jump program: return to the real ground bank before firing again.
		var air_bank_x: float=bank if flight_started>=0 else origin.x
		trace.controller.router.set_move_axis(clampf((air_bank_x-position.x)/16.0,-1,1))
		if flight_started>=0 and trace.player.normal_velocity.y>=0:
			trace.jump(false)
		# The actual incoming direction, not a nominal "above" tag, must clear
		# the shield. At most two requests in this airborne period, even on hit.
		if flight_started>=0 and not front and air_shots<2 and _ready_shot(trace) and _clear(trace,target):
			_shoot(trace,offset.normalized());air_shots+=1
	return true



func _ordinary_ground(trace: Node,leg: Dictionary) -> bool:
	if str(leg.get("kind","")) in ["hollow_recovery","hollow_outer_recovery"]:
		return trace.player.is_on_floor()
	return super._ordinary_ground(trace,leg)

func _destination(trace: Node,leg: Dictionary) -> Vector2:
	if str(leg.get("kind","")) == "hollow_recovery":
		var row: Dictionary = trace.instance(leg)
		var steps: Array = row.local_geometry.platforms.filter(func(p: Dictionary) -> bool: return p.id == "inner_recovery_step")
		if not steps.is_empty():
			var rect: Array = steps[0].rect
			return trace.point(row.translation) + Vector2(float(rect[0])+float(rect[2])*.5,float(rect[1])-18.0)
	return super._destination(trace,leg)

func _submit(trace: Node,kind: StringName,aim:=Vector2.ZERO) -> void:
	if kind == &"shoot_release":
		pending_shot_intent = int(trace.tick)
		if trace.player.is_on_floor(): trace.controller.router.set_move_axis(0)
	super._submit(trace,kind,aim)
