extends RefCounted
## Automatic, disclosed player. Writes ONLY normal Router/MouseMotion inputs.
## All combat observations are read-only; statistics never command the Boss.
var mode := "cautious2"
var input_rows: Array[Dictionary] = []
var frame := 0
var group := -1
var recovery_shots := 0
var recovery_start_frame := -1
var last_shot_frame := -1000
var last_state := ""
var state_start := 0
var jump_until := -1
var intent := "walk through actual map2 Boss entry"
var mouse_previous := Vector2.ZERO
var camp_start := -1
var camp_finished := false
var escape_destination := Vector2.INF
var escape_group := -1
var escape_state := ""
var move_until := -1
var hold_destination := Vector2.INF
var preferred_side := -1.0
var actual_shot_ids: Array[int] = []
var cross_axis := 0.0
var cross_started := -1
var cross_until := -1
var cross_boost_done := false
var previous_grounded := true
var jump_rearm_until := -1
var cross_air_frame := -1
var cross_near_body := false
var cross_is_corner := false
var corner_cleared_height := false
var last_aim_anchor := "core"
var support_escape_active := false
var support_escape_goal := Vector2.INF
var support_escape_rect := Rect2()
var support_escape_lock := Rect2()
var support_escape_air := -1
var support_escape_boosted := false
var leaf_escape_key := ""
var leaf_escape_air := -1
var leaf_escape_boosted := false
var active_extra_interval := -1
var active_extra_rows: Array[Dictionary] = []
var platform_hold_start := -1
var platform_hold_group := -1
var platform_hold_phase := -1


func step(app: Node, encounter: Node, metrics: Dictionary, units: Array[Dictionary]) -> void:
	frame += 1
	var player: CharacterBody2D = app.player
	var controller: Node = app.controller
	var router: Node = controller.router
	var boss: Node2D = app.stage.boss
	var at: Vector2 = player.global_position
	var dx: float = boss.global_position.x - at.x
	var state := str(encounter.mode)
	var arena: Rect2 = app.stage.boss_arena
	var current_group := int(metrics.get("groups_started", 0))
	if state != last_state:
		last_state = state
		state_start = frame
		if state == "recover": recovery_start_frame = frame
	if current_group != group:
		group = current_group
		recovery_shots = 0
		recovery_start_frame = -1
	var axis := 0.0
	var jump := false
	var jump_hold_ticks := 29
	var aim: Vector2 = boss.to_global(encounter.core_offset())
	var pose: Dictionary = encounter.rig_pose()
	if pose.get("core_transform") is Transform2D:
		aim = boss.to_global((pose.core_transform as Transform2D).origin)
	# Every painted body/head part is continuously vulnerable. Choose a real
	# upper point with an unobstructed ray before relocating or jumping: the
	# former core-only aim went through the player's own supporting shelf.
	aim = _clear_body_aim(app, pose, at, aim)
	var shelves := _shelves(app)
	var grounded: bool = player.is_on_floor()
	if grounded and not previous_grounded:
		jump_until = frame - 1
		jump_rearm_until = frame + 2
	previous_grounded = grounded
	var phase := int(encounter.stage_phase)
	var current_slab := _platform2_current_slab(app,at) if mode=="platform2" else Rect2()
	var contact_bounds: Rect2 = encounter.body_contact_rect()
	var actual_touch: bool = encounter.body_contact_sweep(boss.global_position,at-boss.global_position,at,Vector2(12,18))
	var above_body: bool = at.y+18 < contact_bounds.position.y-10
	var hop_rect: Rect2 = metrics.get("hop_target_rect",Rect2())
	var support_motion := phase==3 and hop_rect.size.x>0 and state in ["phase_transition","traverse_warning","traverse","lunge_warning","lunge"]
	var locked: Vector2 = encounter.locked_target
	var incoming_wave := false
	var wave_jump := false
	var seed_pending := false
	var seed_imminent := false
	var landing_wave_axis := 0.0
	var landing_wave_gap := INF
	for shot: Variant in encounter.get("_projectiles"):
		if not is_instance_valid(shot) or shot.is_queued_for_deletion() or bool(shot.spent): continue
		var id := str(shot.event_id)
		var point: Vector2 = shot.global_position
		var direction: Vector2 = shot.direction
		if "seed" in id:
			var recoil_end := at + Vector2(-signf(dx)*95, 0)
			var recoil_bounds := Rect2(at-Vector2(12,18),Vector2(24,36)).expand(recoil_end-Vector2(12,18)).expand(recoil_end+Vector2(12,18)).grow(float(shot.radius)+7)
			var future: Vector2 = point + direction * float(shot.speed) * .90
			if DemoContactEmitter.segment_intersects_bounds(point,future,recoil_bounds): seed_pending = true
			var actor_bounds := Rect2(at-Vector2(12,18),Vector2(24,36)).grow(float(shot.radius)+5)
			if DemoContactEmitter.segment_intersects_bounds(point,point+direction*float(shot.speed)*(.45 if mode=="platform2" else .22),actor_bounds): seed_imminent = true
		if ("wave" in id or "stomp" in id) and absf(direction.x) > .7:
			var gap := point.x - at.x
			# Do not descend off a shelf onto a wave merely because it was
			# below the actor when the countershot began. Keep moving ahead of
			# its real trajectory, then jump after actual floor contact.
			if phase<3 and not grounded and player.normal_velocity.y>0 and gap*direction.x<0 and absf(gap)<165 and at.y+18>point.y-165 and at.y+18<point.y+35:
				if absf(gap)<landing_wave_gap:
					landing_wave_gap=absf(gap)
					landing_wave_axis=direction.x
			if gap * direction.x < 0 and absf(gap) < 400 and absf(point.y - (at.y + 18)) < 45:
				incoming_wave = true
				if grounded and absf(gap) < 115: wave_jump = true
	var pointer: Vector2 = player.get_canvas_transform() * aim
	var mouse := InputEventMouseMotion.new()
	mouse.position = pointer
	mouse.global_position = pointer
	mouse.relative = pointer - mouse_previous
	if mouse.relative.is_zero_approx(): mouse.relative = Vector2(.01, 0)
	mouse_previous = pointer
	Input.parse_input_event(mouse)
	router.activate_device(&"keyboard_mouse")
	if not app._boss_started:
		axis = 1
		intent = "normal walk into actual formal map2 arena trigger"
	elif state == "intro":
		axis = 0
		intent = "actual autonomous intro; stand at entry"
		if mode=="platform2" and not shelves.is_empty():
			var entry_goal := shelves[0]+Vector2(-55,0)
			axis=_toward(at.x,entry_goal.x,5)
			if grounded and at.x>=entry_goal.x-75 and at.y>entry_goal.y+35:jump=true
			camp_finished=true
			intent="platform2: normal intro run/jump onto the existing left shelf; not pressure evidence"
	elif encounter.health.terminal:
		intent = "watch actual mechanical collapse, then collect physical coins"
		if float(metrics.get("death_age", 0)) >= _number(encounter.definition, "death_seconds", 1.9):
			var nearest := Vector2.INF
			var distance := INF
			for unit: Dictionary in units:
				if bool(unit.get("claimed", false)): continue
				var point: Vector2 = app.stage.to_global(unit.position)
				if at.distance_squared_to(point) < distance:
					distance = at.distance_squared_to(point)
					nearest = point
			if nearest.is_finite():
				axis = _toward(at.x, nearest.x, 7)
				if grounded and (nearest.y < at.y - 35 or _gap_ahead(player, axis)):
					jump = true
	else:
		if camp_start < 0: camp_start = frame
		if not camp_finished:
			axis = 0
			intent = "initial stationary observation: Boss must actively close distance"
			if state.ends_with("_warning") or frame - camp_start > 120:
				camp_finished = true
				input_rows.append({"frame": frame, "movie_frame": Engine.get_process_frames(), "action": "stationary_observation_end", "actual_state": state, "held_seconds": float(frame-camp_start)/60, "player": _v(at), "boss": _v(boss.global_position), "group": group})
		else:
			var preferred := 300.0
			var destination := clampf(boss.global_position.x + preferred_side * preferred, arena.position.x + 65, arena.end.x - 65)
			if absf(dx) > preferred + 60: axis = signf(dx)
			elif absf(dx) < preferred - 55: axis = -signf(dx)
			intent = "normal movement: preserve readable distance and a clear shot angle"
			# Stage III uses the real, unchanged reachable shelves after collapse.
			# A chosen landing is held until actual arrival, avoiding frame-by-frame
			# destination oscillation while crossing a real gap.
			if phase == 3 or (phase == 2 and group % 3 == 0):
				if not hold_destination.is_finite() or (grounded and at.distance_to(hold_destination) < 35):
					hold_destination = _preferred_shelf(shelves, at, boss.global_position, locked, state, above_body)
				if hold_destination.is_finite():
					axis = _toward(at.x, hold_destination.x, 17)
					if grounded and (hold_destination.y < at.y - 36 or (_gap_ahead(player, axis) and absf(hold_destination.x-at.x)>50)):
						jump = true
					intent = "legal jump/run between actual supported shelves"
			if state in ["lunge_warning", "lunge"]:
				intent = "read locked lunge and jump across before the wall removes retreat room"
				var away_room: float = at.x-arena.position.x if dx>0 else arena.end.x-at.x
				if mode=="platform2" and current_slab.size.x>0:
					away_room=at.x-current_slab.position.x-13 if dx>0 else current_slab.end.x-13-at.x
				var roomy_retreat := phase<3 and away_room>200
				# The first part of a readable warning plants toward the Boss.
				# Starting the jump320wu away made the old crossing descend onto
				# its torso despite a perfectly real upward recoil shot.
				# When real ground still provides retreat room, use that room
				# instead of needlessly jumping toward the rising locked lunge.
				axis = -signf(dx) if roomy_retreat else signf(dx) if state == "lunge_warning" and absf(dx)>195 else 0.0
				if roomy_retreat: intent="retreat on actual ground from the locked lunge; preserve corner crossing for when needed"
				var raised_cross := mode=="platform2" and current_slab.size.x>0
				if raised_cross and not roomy_retreat:axis=0
				if state == "lunge_warning" and not roomy_retreat and not support_motion and absf(dx)<=(300 if raised_cross else 220) and float(encounter.clock)<=(.40 if raised_cross else .25) and grounded and cross_axis==0:
					cross_axis = signf(dx)
					cross_started = frame
					cross_until = frame+180
					cross_boost_done = false
					cross_air_frame = -1
					cross_near_body=absf(dx)<175
					cross_is_corner=false
					jump = true
					input_rows.append({"frame":frame,"movie_frame":Engine.get_process_frames(),"action":"read_lunge_crossing","axis":cross_axis,"gap":dx,"away_room":away_room,"group":group})
			elif state in ["platform_warning", "platform"]:
				intent = "leave the telegraphed platform; target does not change"
				if escape_group != group or escape_state != state:
					escape_destination = _escape_shelf(shelves, at, locked, arena, app, boss.global_position)
					escape_group = group
					escape_state = state
				if escape_destination.is_finite():
					axis = _toward(at.x, escape_destination.x, 3)
					hold_destination = escape_destination
					if grounded and absf(at.x-locked.x) < 145: jump = true
			elif state in ["seeds_warning", "seeds"]:
				intent = "move off actual preselected seed aim, preserve the next landing"
				if state == "seeds_warning" and frame == state_start:
					# Leave the frozen fan toward its source while preserving real
					# body clearance. Backing into the seal kept the first pilot
					# directly inside the descending centre seed after recoil.
					var destination_x := locked.x + signf(dx)*180
					if absf(destination_x-boss.global_position.x)<155: destination_x=boss.global_position.x-signf(dx)*155
					if phase>=2 and absf(dx)<190:
						# A close sealed-edge position must not be clamped inward
						# to the old65wu staging margin, directly into the head.
						destination_x=at.x-signf(dx)*60
					var seed_margin := 13 if phase>=2 else 65
					escape_destination = Vector2(clampf(destination_x,arena.position.x+seed_margin,arena.end.x-seed_margin),at.y)
				if escape_destination.is_finite(): axis = _toward(at.x,escape_destination.x,12)
				if grounded and phase == 3 and _gap_ahead(player,axis): jump = true
			elif state in ["sweep_warning", "sweep"]:
				intent = "read shoulder/leaf height, preserve room through actual sweep"
				if absf(dx) < 250: axis = -signf(dx)
				var high: bool = encounter.sweep_high
				var on_shelf: bool = at.y < boss.global_position.y - 35
				var away_room: float = at.x-arena.position.x if dx>0 else arena.end.x-at.x
				var leaf_key := "%s:%s" % [group,metrics.get("attack_index",0)]
				# At the sealed edge a low blade sits just above a basic jump.
				# Use the visible warning for a real jump plus upward recoil,
				# rather than jumping straight into the first horizontal leaf.
				if state=="sweep_warning" and high==on_shelf and absf(dx)<200 and away_room<80 and float(encounter.clock)<=.45:
					if leaf_escape_key!=leaf_key:
						leaf_escape_key=leaf_key
						leaf_escape_air=-1
						leaf_escape_boosted=false
					if grounded and leaf_escape_air<0:jump=true

			elif state in ["gust_warning", "gust"]:
				intent = "brace into the shown wind direction, keep feet clear of the edge"
				# Bracing counters wind only while there is genuine body space.
				# Keep at least190wu rather than walking into the active legs.
				axis = -float(encounter.locked_direction) if absf(dx)>205 else 0.0
				if absf(dx)<185: axis=-signf(dx)
				if grounded and _gap_ahead(player, axis):
					hold_destination = _preferred_shelf(shelves,at,boss.global_position,locked,state,above_body)
					if hold_destination.is_finite(): axis = signf(hold_destination.x-at.x)
					jump = true
			elif state == "recover":
				intent = "final group recovery: two legal base shots then leave"
				var limit := 3 if mode == "greed3" else 2
				var counter_age := float(frame-recovery_start_frame)/60
				var due := .10 if recovery_shots == 0 else .43 if recovery_shots == 1 else .76
				var can_fire: bool = grounded and cross_axis==0 and not support_escape_active and not actual_touch and not incoming_wave and not seed_pending and float(controller.shoot_ability.cooldown_remaining) <= .001 and int(controller.action_resources.shot_charges)>0 and (controller.shot_energy == null or controller.shot_energy.can_fire())
				if recovery_shots < limit and counter_age>=due and frame-last_shot_frame>=16 and can_fire and _shot_clear(app, at, aim):
					var direction: Vector2 = player.get_node("KeyboardMouseAdapter").world_direction(pointer)
					var accepted: bool = router.request_action(&"shoot_release", direction)
					input_rows.append({"frame":frame,"movie_frame":Engine.get_process_frames(),"action":"shoot_release","direction":_v(direction),"submitted":accepted,"group":group,"ordinal":recovery_shots+1,"recovery_age":counter_age,"actual_state":state,"remaining_recovery":encounter.clock,"aim_anchor":last_aim_anchor,"actual_aim_point":_v(aim),"intent":mode})
					if accepted:
						recovery_shots += 1
						last_shot_frame = frame
				if recovery_shots < limit:
					axis = signf(dx) if absf(dx)>370 or (recovery_shots>0 and absf(dx)>220) else 0.0
					if not _shot_clear(app,at,aim):
						axis = signf(dx) if absf(dx)>240 else -signf(dx) if absf(dx)<195 else 0.0
						intent="find clear upper-body ray without jumping into the guardian"
				else:
					axis = -signf(dx) if absf(dx)<340 else 0.0
					intent = "countershots complete; withdraw before next threat"
			elif state == "phase_transition":
				intent = "read structural phase transition and reach existing high support"
				hold_destination = _preferred_shelf(shelves,at,boss.global_position,locked,state,above_body)
				if hold_destination.is_finite():
					axis = _toward(at.x,hold_destination.x,15)
					if grounded and (hold_destination.y<at.y-35 or _gap_ahead(player,axis)): jump = true
	# Phase II/III close the remaining space more actively. Do not wait until
	# the next130wu preparation has pinned the player against a seal. Begin an
	# ordinary jump/recoil change of side while180–300wu still remain.
	var early_read := state in ["observe","approach","turn"] or (state.ends_with("_warning") and float(metrics.get("state_age",0))<.25)
	var corner_room: float = at.x-arena.position.x if dx>0 else arena.end.x-at.x
	if mode=="platform2" and current_slab.size.x>0:
		corner_room=at.x-current_slab.position.x-13 if dx>0 else current_slab.end.x-13-at.x
	if phase>=2 and early_read and not support_motion and not support_escape_active and cross_axis==0 and grounded and corner_room<180 and absf(dx)>=180 and absf(dx)<=300:
		cross_axis=signf(dx)
		cross_started=frame
		cross_until=frame+180
		cross_air_frame=-1
		cross_boost_done=false
		cross_near_body=false
		cross_is_corner=true
		corner_cleared_height=false
		jump=true
		input_rows.append({"frame":frame,"movie_frame":Engine.get_process_frames(),"action":"proactive_corner_crossing","actual_mode":state,"gap":dx,"away_room":corner_room,"group":group})
	# A locked lunge permits a legal jump/recoil crossing. The escape shot is
	# deliberately aimed away/down, so its real upward recoil carries the player
	# over the large body; it is counted as an actual miss, not a Boss hit.
	if cross_axis != 0:
		# A future-overlap guard cannot find a collision-free path while the
		# actor already touches the hull. Keep ordinary escape input in that
		# case: stopping here trapped the old pilot through repeated contact
		# hits instead of letting the player leave during real invulnerability.
		axis = cross_axis if actual_touch or _cross_motion_safe(app,encounter,cross_axis) else 0.0
		intent = "actual jump/recoil crossing of locked lunge; normal input only"
		if not grounded and cross_air_frame<0: cross_air_frame=frame
		# A landing/rearm in the exact warning tick must not lose the jump.
		if grounded and cross_air_frame<0: jump=true
		var air_ticks := frame-cross_air_frame if cross_air_frame>=0 else -1
		# ShotAbility clears normal vertical speed. Keep the actual first jump
		# ascent instead of cancelling it at8frames: phaseI retains its proved
		#15tick timing; later crossings fire near the actual apex, no earlier.
		var apex_ready: bool = air_ticks>=15 and (phase==1 or player.normal_velocity.y>-120 or air_ticks>=18)
		if not cross_boost_done and cross_air_frame>=0 and apex_ready and not grounded:
			var energy_ready: bool = controller.shot_energy == null or controller.shot_energy.can_fire()
			if controller.shoot_ability.cooldown_remaining<=0 and energy_ready and controller.action_resources.shot_charges>0:
				var escape_aim := Vector2(-cross_axis*(.85 if cross_is_corner else .55),1).normalized()
				var accepted: bool = router.request_action(&"shoot_release",escape_aim)
				input_rows.append({"frame":frame,"movie_frame":Engine.get_process_frames(),"action":"escape_recoil_shot","direction":_v(escape_aim),"submitted":accepted,"group":group,"air_frames_before_shot":air_ticks,"actual_normal_vy":player.normal_velocity.y,"purpose":"actual upward recoil to clear body; no effective hit fabricated"})
				if accepted: cross_boost_done=true
		var actual_bounds: Rect2 = encounter.body_contact_rect()
		var cleared: bool = at.x-28>actual_bounds.end.x if cross_axis>0 else at.x+28<actual_bounds.position.x
		if cleared and frame-cross_started>20:
			preferred_side = cross_axis
			cross_axis=0
			cross_is_corner=false
			hold_destination=Vector2.INF
			escape_destination=Vector2.INF
			input_rows.append({"frame":frame,"movie_frame":Engine.get_process_frames(),"action":"crossing_finished","actual_player":_v(at),"actual_boss":_v(boss.global_position),"actual_body_bounds":[actual_bounds.position.x,actual_bounds.position.y,actual_bounds.size.x,actual_bounds.size.y],"preferred_side":preferred_side})
		elif frame>=cross_until and grounded:
			# Do not let an elapsed bot timer reverse back into the body.
			# A further legal jump can clear a newly extended limb; actual
			# horizontal clearance is still required before ending the crossing.
			jump=true
			cross_until=frame+60
			cross_started=frame
			cross_boost_done=false
			cross_air_frame=-1
	if not encounter.health.terminal and app._boss_started and state != "intro" and cross_axis==0 and actual_touch:
		axis=-signf(dx)
		intent="preserve actual body/leg clearance before another action"
	if seed_imminent and cross_axis==0:
		intent = "real outstanding seed still threatens current position across recovery"
		# Finish the same frozen seed escape instead of oscillating around a
		#190wu distance threshold. The old close-range jump raised the actor
		# straight into seeds that would otherwise pass above grounded feet.
		axis = _toward(at.x,escape_destination.x,12) if escape_destination.is_finite() else -signf(dx)
		if mode=="platform2" and grounded:
			jump=true
			intent="platform2: normal jump against actual approaching seed trajectories"
	if phase>=2 and not encounter.health.terminal and not seed_imminent and not support_escape_active and cross_axis==0 and state in ["observe","approach","link","recover"]:
		# After real countershot recoil, plant on the inner safe edge of the
		# current unoccupied support. Remaining at its far edge made the next
		# honest jump require an unnecessarily long crossing of the Boss route.
		var edge := _current_inner_edge(app,at,boss.global_position)
		if edge.is_finite():
			axis=_toward(at.x,edge.x,7)
			if state!="recover" or recovery_shots>=2: intent="plant on current safe support edge before reading next landing"
	if mode=="platform2" and phase<3 and not encounter.health.terminal and cross_axis==0 and not support_escape_active and not actual_touch and not seed_imminent and state in ["observe","approach","turn","link","recover"]:
		var platform_motion := _platform2_ordinary_motion(app,encounter,at,current_slab,axis)
		axis=float(platform_motion.axis)
		jump=jump or bool(platform_motion.jump)
		intent="platform2: retain or regain a real shelf with ordinary run/jump input"
	if leaf_escape_key=="%s:%s" % [group,metrics.get("attack_index",0)] and state in ["sweep_warning","sweep"]:
		if not grounded and leaf_escape_air<0:leaf_escape_air=frame
		if grounded and leaf_escape_air<0:jump=true
		if not leaf_escape_boosted and not grounded and leaf_escape_air>=0 and frame-leaf_escape_air>=12:
			var ready_leaf_energy: bool = controller.shot_energy==null or controller.shot_energy.can_fire()
			if controller.shoot_ability.cooldown_remaining<=0 and controller.action_resources.shot_charges>0 and ready_leaf_energy:
				var leaf_submitted: bool = router.request_action(&"shoot_release",Vector2.DOWN)
				input_rows.append({"frame":frame,"movie_frame":Engine.get_process_frames(),"action":"corner_sweep_recoil_shot","direction":[0,1],"submitted":leaf_submitted,"group":group,"purpose":"real upward recoil clears the visible leaf at sealed edge"})
				if leaf_submitted:leaf_escape_boosted=true
	# The supported Boss now mounts/traverses the SAME real shelves as the
	# player. A destination is frozen in its warning: vacate that slab with a
	# legal jump/recoil rather than assuming the guardian remains below it.
	if support_motion and hop_rect!=support_escape_lock:
		support_escape_lock=hop_rect
		if at.x>=hop_rect.position.x-18 and at.x<=hop_rect.end.x+18:
			var choice := _other_support(app,at,hop_rect)
			if not choice.is_empty():
				support_escape_active=true
				support_escape_goal=choice.point
				support_escape_rect=choice.rect
				support_escape_air=-1 if grounded else frame
				support_escape_boosted=false
				cross_axis=0
				input_rows.append({"frame":frame,"movie_frame":Engine.get_process_frames(),"action":"avoid_locked_boss_landing","actual_mode":state,"locked_slab":[hop_rect.position.x,hop_rect.position.y,hop_rect.size.x,hop_rect.size.y],"actual_goal":_v(support_escape_goal)})
	if support_escape_active:
		axis=_toward(at.x,support_escape_goal.x,8)
		intent="legal jump/recoil to a different real support than the Boss landing"
		if grounded and support_escape_air<0: jump=true
		if not grounded and support_escape_air<0: support_escape_air=frame
		if not support_escape_boosted and not grounded and support_escape_air>=0 and frame-support_escape_air>=18:
			var ready_energy: bool = controller.shot_energy==null or controller.shot_energy.can_fire()
			if controller.shoot_ability.cooldown_remaining<=0 and controller.action_resources.shot_charges>0 and ready_energy:
				var travel_side := signf(support_escape_goal.x-at.x)
				if is_zero_approx(travel_side):travel_side=signf(support_escape_goal.x-boss.global_position.x)
				var recoil_direction := Vector2(-travel_side*.85,1).normalized()
				var submitted: bool = router.request_action(&"shoot_release",recoil_direction)
				input_rows.append({"frame":frame,"movie_frame":Engine.get_process_frames(),"action":"support_escape_recoil_shot","direction":_v(recoil_direction),"submitted":submitted,"group":group,"purpose":"actual recoil clears locked Boss route; not a fabricated effective hit"})
				if submitted:support_escape_boosted=true
		var landed_safe := grounded and absf(at.y+18-support_escape_rect.position.y)<3 and at.x-12>=support_escape_rect.position.x and at.x+12<=support_escape_rect.end.x
		if landed_safe and support_escape_air>=0:
			support_escape_active=false
			hold_destination=support_escape_goal
			input_rows.append({"frame":frame,"movie_frame":Engine.get_process_frames(),"action":"actual_different_support_landing","point":_v(at),"goal":_v(support_escape_goal)})
	# Projectiles can outlive an attack substate. React to their real position,
	# never assume group recovery means every previously launched wave vanished.
	if landing_wave_axis != 0 and cross_axis==0 and not support_escape_active:
		axis=landing_wave_axis
		intent="keep actual falling landing ahead of the approaching wave"
	if wave_jump:
		jump = true
		if cross_axis==0 and not support_escape_active:jump_hold_ticks=29
		intent = "short legal jump over real approaching ground wave across state boundaries"
	if app._boss_started:
		if at.x < arena.position.x + 12 and axis < 0: axis = 0
		if at.x > arena.end.x - 12 and axis > 0: axis = 0
		if grounded and phase == 3 and _gap_ahead(player,axis) and absf(axis)>.1:
			jump = true
	if jump and frame >= jump_until and frame >= jump_rearm_until:
		jump_until = frame + jump_hold_ticks
		input_rows.append({"frame":frame,"movie_frame":Engine.get_process_frames(),"action":"jump_hold","group":group,"intent":intent})
	router.set_jump_held(&"keyboard_mouse", frame < jump_until)
	router.set_source_axis(&"keyboard_mouse", axis)
	if mode in ["active2","platform2"]:_active_extra_shot(app,encounter,state,at,aim)
	if mode=="platform2":_platform2_observe_hold(app,encounter,axis,at,state,group,phase)
	input_rows.append({"frame":frame,"movie_frame":Engine.get_process_frames(),"action":"continuous_move","axis":axis,"jump_held":frame<jump_until,"group":group,"intent":intent})


func _platform2_current_slab(app: Node, at: Vector2) -> Rect2:
	if not app.player.is_on_floor():return Rect2()
	for module: PlatformingModule in app.stage.assembler.modules:
		if module.definition.module_id!=&"plains_boss_arena":continue
		for index: int in [1,2,3]:
			var local: Rect2=module.definition.platforms[index]
			var rect:=Rect2(module.to_global(local.position),local.size)
			if absf(at.y+18-rect.position.y)<4 and at.x>=rect.position.x-12 and at.x<=rect.end.x+12:return rect
	return Rect2()


func _platform2_ordinary_motion(app: Node, encounter: Node, at: Vector2, slab: Rect2, fallback: float) -> Dictionary:
	var boss: Vector2=encounter.motor.global_position
	if slab.size.x>0:
		var target:=INF
		var best:=INF
		for index: int in 7:
			var x:=lerpf(slab.position.x+13,slab.end.x-13,float(index)/6.0)
			var point:=Vector2(x,slab.position.y-18)
			if absf(x-boss.x)<150 or (x-boss.x)*(at.x-boss.x)<=0:continue
			if encounter.body_contact_sweep(boss,point-boss,point,Vector2(24,18)):continue
			if absf(x-boss.x)<best:best=absf(x-boss.x);target=x
		if is_finite(target):return {"axis":_toward(at.x,target,7),"jump":false}
	elif app.player.is_on_floor():
		var goal:=Vector2.INF
		var best:=INF
		for point: Vector2 in _shelves(app):
			if absf(point.x-boss.x)<170 or (point.x-boss.x)*(at.x-boss.x)<=0:continue
			var distance:=absf(point.x-at.x)
			if distance<best and distance<320:best=distance;goal=point
		if goal.is_finite():return {"axis":_toward(at.x,goal.x,10),"jump":best<100 and goal.y<at.y-35}
	return {"axis":fallback,"jump":false}


func _platform2_observe_hold(app: Node, encounter: Node, axis: float, at: Vector2, state: String, identity: int, phase: int) -> void:
	# Observation only: the Boss receives no command and every hold is logged,
	# even if its measured movement later fails the wrapper's pressure guard.
	var stationary: bool=not encounter.health.terminal and app.player.is_on_floor() and is_zero_approx(axis) and app.player.recoil_burst_remaining<=0 and app.player.normal_velocity.is_zero_approx()
	if platform_hold_start<0:
		if stationary and state=="approach" and absf(encounter.motor.global_position.x-at.x)>300:
			platform_hold_start=frame
			platform_hold_group=identity
			platform_hold_phase=phase
	elif not stationary or state!="approach":
		input_rows.append({"frame":frame,"movie_frame":Engine.get_process_frames(),"action":"stationary_observation_end","actual_state":state,"held_seconds":float(frame-platform_hold_start)/60,"player":_v(at),"boss":_v(encounter.motor.global_position),"group":platform_hold_group,"phase":platform_hold_phase,"hold_scope":"platform2_later_actual_stationary_hold","note":"intro positioning is not pressure proof; assess actual frame positions"})
		platform_hold_start=-1


func _cross_motion_safe(app: Node, encounter: Node, forward: float) -> bool:
	# Read-only0.10s relative-motion forecast against the authoritative painted
	# hull/head/limb shapes. Sample the curved vertical trajectory, rather than
	# requiring the actor to rise above the entire broad AABB before moving.
	var actor: PlayerMotor = app.player
	var source: Vector2 = encounter.motor.global_position
	var actor_point: Vector2 = actor.global_position
	var boss_speed: Vector2 = encounter.motor.velocity
	var normal: Vector2 = actor.normal_velocity
	var recoil: Vector2 = actor.recoil_velocity
	var burst: float = actor.recoil_burst_remaining
	var tuning: PlayerTuning = actor.tuning
	var jump: JumpAbility = app.controller.jump_ability
	var hold: float = jump._hold_remaining
	var hold_speed: float = jump._hold_speed
	var actor_half := Vector2(12,18)
	var shape := actor.get_node("CollisionShape2D") as CollisionShape2D
	if shape.shape is RectangleShape2D:actor_half=(shape.shape as RectangleShape2D).size*.5
	var elapsed := 0.0
	var relative_point := actor_point
	var grounded_prediction: bool = actor.is_on_floor() and normal.y>=0 and burst<=0
	for sample: int in 6:
		var delta := 1.0/60.0
		normal.x=move_toward(normal.x,forward*tuning.ground_speed,tuning.air_acceleration*delta)
		var motion := Vector2.ZERO
		if burst>0:
			# Actual latched shot-burst velocity owns displacement; Router axis
			# cannot steer a burst which is already executing.
			var used := minf(delta,burst)
			motion=recoil*used
			burst=maxf(0,burst-delta)
			if burst<=0:recoil=Vector2.ZERO
		else:
			if grounded_prediction:normal.y=0
			else:
				if hold>0 and normal.y<0:
					normal.y=lerpf(normal.y,hold_speed,minf(delta,hold)/delta)
					hold=maxf(0,hold-delta)
				normal.y=minf(normal.y+tuning.gravity*delta,tuning.max_normal_fall_speed)
			recoil*=exp(-delta/tuning.recoil_tau)
			motion=(normal+recoil)*delta
		actor_point+=motion
		elapsed+=delta
		var future_relative := actor_point-boss_speed*elapsed
		if encounter.body_contact_sweep(source,relative_point-source,future_relative,actor_half):return false
		relative_point=future_relative
	return true


func _active_extra_shot(app: Node, encounter: Node, state: String, at: Vector2, aim: Vector2) -> void:
	# A separate, explicitly disclosed proactive-input profile. Recovery still
	# has at most two shots; these are extra ordinary shots during real openings
	# in approach/turn or the early part of a visible attack preparation.
	if not camp_finished or active_extra_interval==state_start:return
	var player: PlayerMotor = app.player
	var controller: PlayerController = app.controller
	if cross_axis!=0 or support_escape_active or frame<jump_until or not player.is_on_floor():return
	if state not in ["approach","turn","stomp_warning","seeds_warning","gust_warning","sweep_warning","platform_warning"]:return
	if float(encounter.clock)<(.04 if state=="turn" else .36):return
	if absf(at.x-encounter.motor.global_position.x)<240:return
	if controller.shoot_ability.cooldown_remaining>0 or controller.action_resources.shot_charges<=0 or (controller.shot_energy!=null and not controller.shot_energy.can_fire()):return
	if encounter.body_contact_sweep(encounter.motor.global_position,at-encounter.motor.global_position,at,Vector2(12,18)):return
	if not _shot_clear(app,at,aim):return
	var direction: Vector2 = player.get_node("KeyboardMouseAdapter").world_direction(player.get_canvas_transform()*aim)
	var recoil_end := at-direction*95
	var corridor := Rect2(at-Vector2(12,18),Vector2(24,36)).expand(recoil_end-Vector2(12,18)).expand(recoil_end+Vector2(12,18))
	for shot: BossProjectile in encounter._projectiles:
		if not is_instance_valid(shot) or shot.spent or shot.is_queued_for_deletion():continue
		if shot is WindkeeperPressureStrike:return
		var travel: Vector2 = shot.direction*shot.speed*.9
		if DemoContactEmitter.segment_intersects_bounds(shot.global_position,shot.global_position+travel,corridor.grow(shot.radius+7)):return
	# Four real ground queries guard the entire recoil path, including when
	# phaseIII has removed the old floor. No invented support or Actor move.
	for fraction: float in [0.0,.33,.66,1.0]:
		var foot := Vector2(lerpf(at.x,recoil_end.x,fraction),at.y+17)
		var ray := PhysicsRayQueryParameters2D.create(foot,foot+Vector2(0,35),1,[player.get_rid()])
		var support := player.get_world_2d().direct_space_state.intersect_ray(ray)
		if support.is_empty() or (support.normal as Vector2).dot(Vector2.UP)<.7:return
	var submitted := controller.router.request_action(&"shoot_release",direction)
	if submitted:
		active_extra_interval=state_start
		last_shot_frame=frame
		var row := {"frame":frame,"movie_frame":Engine.get_process_frames(),"action":"active_extra_shot","actual_state":state,"remaining_warning":encounter.clock,"direction":_v(direction),"submitted":true,"group":group,"interval_start":state_start,"aim_anchor":last_aim_anchor,"purpose":"legal attack-phase extra shot; separate from at-most-two recovery shots"}
		active_extra_rows.append(row)
		input_rows.append(row)


func _shelves(app: Node) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for module: PlatformingModule in app.stage.assembler.modules:
		if module.definition.module_id != &"plains_boss_arena": continue
		for index: int in [1,2,3]:
			var rect: Rect2 = module.definition.platforms[index]
			result.append(module.to_global(Vector2(rect.get_center().x,rect.position.y-18)))
	return result


func _preferred_shelf(shelves: Array[Vector2], at: Vector2, boss: Vector2, locked: Vector2, state: String, above_body: bool = false) -> Vector2:
	var best := Vector2.INF
	var score := INF
	for point: Vector2 in shelves:
		# A nearer platform behind the torso is not a legal walking route.
		# Keep the current side unless actual actor height clears the body.
		if absf(point.x-boss.x)<180: continue
		if not above_body and (point.x-boss.x)*(at.x-boss.x)<0: continue
		var distance := absf(point.x-at.x)
		# Prefer a reachable neighbour; a width of260–270 uses one basic jump.
		var value := distance + absf(absf(point.x-boss.x)-300)*.35
		if distance > 310: value += 800
		if absf(point.x-boss.x)<125: value += 500
		if state in ["platform_warning","platform"] and absf(point.x-locked.x)<130: value += 900
		if value < score: score=value;best=point
	return best


func _escape_shelf(shelves: Array[Vector2], at: Vector2, locked: Vector2, arena: Rect2, app: Node, boss: Vector2) -> Vector2:
	# A strike hits one part of its locked real platform. First use actual
	# supported room on THIS platform, rather than automatically crossing the
	# guardian to the neighbouring shelf. Candidate centres respect actor width.
	var candidates: Array[Vector2] = []
	for module: PlatformingModule in app.stage.assembler.modules:
		if module.definition.module_id != &"plains_boss_arena": continue
		for index: int in [1,2,3]:
			var local: Rect2 = module.definition.platforms[index]
			var rect := Rect2(module.to_global(local.position),local.size)
			if at.x>=rect.position.x-18 and at.x<=rect.end.x+18:
				for x: float in [rect.position.x+13,rect.end.x-13,rect.get_center().x]:
					candidates.append(Vector2(x,rect.position.y-18))
	for point: Vector2 in shelves: candidates.append(point)
	var best := Vector2.INF
	var score := -INF
	for point: Vector2 in candidates:
		var distance := absf(point.x-at.x)
		if distance>330: continue
		# A temporary airborne height is not permission to LAND inside or
		# across the Boss. Require the final support to remain on this side.
		if (point.x-boss.x)*(at.x-boss.x)<=0 or absf(point.x-boss.x)<175: continue
		var from_strike := absf(point.x-locked.x)
		if from_strike<33: continue
		var value := minf(from_strike,100)-distance*.7
		if distance<120: value+=150
		if value>score: score=value;best=point
	if not best.is_finite():
		# Stay on the current side and use a legal jump; never select an
		# unsupported endpoint or a walking path through the large body.
		best=Vector2(at.x,at.y)
	return best


func _gap_ahead(player: CharacterBody2D, axis: float) -> bool:
	if absf(axis)<.1 or not player.is_on_floor():return false
	var point := player.global_position+Vector2(signf(axis)*33,16)
	var ray := PhysicsRayQueryParameters2D.create(point,point+Vector2(0,35),1,[player.get_rid()])
	return player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


func _current_inner_edge(app: Node, at: Vector2, boss: Vector2) -> Vector2:
	var best := Vector2.INF
	var score := INF
	for module: PlatformingModule in app.stage.assembler.modules:
		if module.definition.module_id!=&"plains_boss_arena":continue
		for index: int in [1,2,3]:
			var local: Rect2 = module.definition.platforms[index]
			var rect := Rect2(module.to_global(local.position),local.size)
			if at.x<rect.position.x-4 or at.x>rect.end.x+4 or absf(at.y+18-rect.position.y)>35:continue
			for x: float in [rect.position.x+14,rect.end.x-14,rect.get_center().x]:
				var gap := absf(x-boss.x)
				if gap<180 or (x-boss.x)*(at.x-boss.x)<=0:continue
				if gap<score:score=gap;best=Vector2(x,rect.position.y-18)
	return best


func _other_support(app: Node, at: Vector2, occupied: Rect2) -> Dictionary:
	var choice: Dictionary = {}
	var score := INF
	for module: PlatformingModule in app.stage.assembler.modules:
		if module.definition.module_id != &"plains_boss_arena":continue
		for index: int in [1,2,3]:
			var local: Rect2 = module.definition.platforms[index]
			var rect := Rect2(module.to_global(local.position),local.size)
			if rect.intersects(occupied):continue
			var point := Vector2(rect.get_center().x,rect.position.y-18)
			var distance := absf(point.x-at.x)
			# Adjacent supports are reached by ordinary jump plus one actual
			# recoil shot. Never target a platform beyond an intervening slab.
			if distance>350:continue
			if distance<score:
				score=distance
				choice={"point":point,"rect":rect}
	return choice


func _clear_body_aim(app: Node, pose: Dictionary, start: Vector2, fallback: Vector2) -> Vector2:
	var boss: Node2D = app.stage.boss
	var points: Array[Dictionary] = []
	if pose.get("head_transform") is Transform2D:
		var head: Transform2D = pose.head_transform
		points.append({"name":"painted upper head","point":boss.to_global(head*Vector2(0,-12))})
		points.append({"name":"painted head centre","point":boss.to_global(head.origin)})
	if pose.get("body_transform") is Transform2D:
		var body: Transform2D = pose.body_transform
		points.append({"name":"painted upper torso","point":boss.to_global(body*Vector2(0,-24))})
		points.append({"name":"painted shoulder","point":boss.to_global(body*Vector2(40,-22))})
	points.append({"name":"actual core","point":fallback})
	for choice: Dictionary in points:
		var point: Vector2 = choice.point
		if _shot_clear(app,start,point):
			last_aim_anchor=str(choice.name)
			return point
	last_aim_anchor="blocked actual core; seek clear position"
	return fallback


func _shot_clear(app: Node, start: Vector2, finish: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(start,finish,5,[app.player.get_rid()])
	ray.collide_with_areas = true
	var first: Dictionary = app.player.get_world_2d().direct_space_state.intersect_ray(ray)
	return first.is_empty() or first.get("collider") == app.stage.boss or app.stage.boss.is_ancestor_of(first.get("collider"))


func _toward(value: float, target: float, tolerance: float) -> float:
	return signf(target-value) if absf(target-value)>tolerance else 0.0


func _number(object: Object, key: String, fallback: float) -> float:
	for property: Dictionary in object.get_property_list():
		if str(property.name)==key:return float(object.get(key))
	return fallback


func observe_actual_shot(shot_id: int) -> void:
	actual_shot_ids.append(shot_id)


func _v(point: Vector2) -> Array:
	return [point.x,point.y]
