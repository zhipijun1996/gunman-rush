extends RefCounted
## Disclosed automated player. Observations are read-only; all writes are normal
## Router inputs or actual mouse-motion events. Never advances Encounter clocks.
var mode := "cautious2"
var input_rows: Array[Dictionary] = []
var frame := 0
var group := -1
var recovery_shots := 0
var last_shot_frame := -1000
var jump_until := -1
var cross_until := -1
var cross_axis := 0.0
var last_state := ""
var state_start := 0
var intent := "walk through actual entry"
var mouse_previous := Vector2.ZERO
var lob_escape_axis := 0.0
var recovery_start_frame := -1
var late_withdraw_until := -1
var late_withdraw_remaining := 0.0
var late_reaction_armed := false
var late_reaction_consumed := false
var late_reaction_source_group := -1
var late_reaction_group := -1
var late_reaction_kind := ""
var late_reaction_started := -1
var late_reaction_status := "not_armed"
var late_threat_seen := false
var review_armour := false
var seen_intro := false
var armour_probe_decided := false
var armour_probe_awaiting_actual_shot := false
var armour_probe_actual_shot := -1


func step(app: Node, encounter: Node, metrics: Dictionary, units: Array[Dictionary]) -> void:
	frame += 1
	late_withdraw_remaining = maxf(0.0, float(late_withdraw_until - frame) / 60.0)
	var player: CharacterBody2D = app.player
	var controller: Node = app.controller
	var router: Node = controller.router
	var boss: Node2D = app.stage.boss
	var arena: Rect2 = app.stage.boss_arena
	var at := player.global_position
	var dx := boss.global_position.x - at.x
	var state := str(encounter.mode)
	if state == "intro":
		seen_intro = true
	if state != last_state:
		last_state = state
		state_start = frame
		if state == "lob_lock":
			lob_escape_axis = signf(dx) if absf(dx) > 330.0 else -signf(dx)
		if state == "neck":
			recovery_start_frame = frame
	var current_group := int(metrics.get("groups_started", 0))
	if group != current_group:
		group = current_group
		recovery_shots = 0
		recovery_start_frame = -1
	var axis := 0.0
	var jump := false
	var incoming_wave := false
	var wave_jump := false
	# Projectiles outlive state boundaries. Recovery alone is never proof that
	# a launched wave has passed this player's actual position.
	for projectile: Variant in encounter.get("_projectiles"):
		if not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
			continue
		if not str(projectile.event_id).begins_with("bellstrider_ring-"):
			continue
		var wave_dx: float = projectile.global_position.x - at.x
		if wave_dx * float(projectile.direction.x) < 0:
			var near_floor: bool = at.y + 18.0 > float(projectile.global_position.y) - 35.0
			if near_floor or not player.is_on_floor():
				incoming_wave = true
			if near_floor and absf(wave_dx) < 115.0 and player.is_on_floor():
				wave_jump = true
	var aim: Vector2 = boss.to_global(encounter.core_offset())
	var armour_probe_now := false
	if review_armour and seen_intro and state == "observe" and current_group == 0 and not armour_probe_decided:
		armour_probe_decided = true
		var ready: bool = player.is_on_floor() and float(controller.shoot_ability.cooldown_remaining) <= .001 and int(controller.action_resources.shot_charges) > 0 and (controller.shot_energy == null or controller.shot_energy.can_fire())
		if ready:
			var pose: Dictionary = encounter.rig_pose()
			var body: Transform2D = pose.get("body_transform", Transform2D.IDENTITY)
			aim = boss.to_global(body * Vector2(0, 20))
			armour_probe_now = true
		else:
			input_rows.append({"frame": frame, "movie_frame": Engine.get_process_frames(), "action": "armour_probe_unavailable", "intent": "装甲试射，HP应不变", "reason": "first post-intro observe was not a ready grounded shot; no Boss wait or retry"})
	# A visible point on the lower face of the same real upper bell can avoid a
	# shelf edge that clips a centre-directed projectile. Never shoot armour.
	if state in ["neck", "observe"] and current_group > 0 and not _shot_clear(app, at, aim) and _shot_clear(app, at, aim + Vector2(0, 9)):
		aim += Vector2(0, 9)
	# Pointer goes through the actual KeyboardMouseAdapter muzzle solver.
	var pointer: Vector2 = player.get_canvas_transform() * aim
	var motion := InputEventMouseMotion.new()
	motion.position = pointer
	motion.global_position = pointer
	motion.relative = pointer - mouse_previous
	if motion.relative.is_zero_approx():
		motion.relative = Vector2(.01, 0)
	mouse_previous = pointer
	Input.parse_input_event(motion)
	# Same-device Router axes avoid creating hidden held-key state.
	router.activate_device(&"keyboard_mouse")
	if armour_probe_now:
		var direction: Vector2 = player.get_node("KeyboardMouseAdapter").world_direction(pointer)
		var accepted: bool = router.request_action(&"shoot_release", direction)
		armour_probe_awaiting_actual_shot = accepted
		input_rows.append({"frame": frame, "movie_frame": Engine.get_process_frames(), "action": "shoot_release", "direction": [direction.x, direction.y], "submitted": accepted, "group": 0, "ordinal": 0, "target": [aim.x, aim.y], "boss_HP_before": encounter.health.current, "intent": "装甲试射，HP应不变"})
	if not app._boss_started:
		axis = 1.0
		intent = "walk into actual arena trigger"
	elif state == "intro":
		axis = _toward(at.x, boss.global_position.x - 285.0, 20.0)
		intent = "actual intro and gate closure"
	elif encounter.health.terminal:
		intent = "observe actual death, then collect real coins"
		if float(metrics.get("death_age", 0)) >= 1.8:
			var nearest := Vector2.INF
			var distance := INF
			for unit: Dictionary in units:
				if bool(unit.get("claimed", false)):
					continue
				var location: Vector2 = app.stage.to_global(unit.position)
				if at.distance_squared_to(location) < distance:
					distance = at.distance_squared_to(location)
					nearest = location
			if nearest.is_finite():
				axis = _toward(at.x, nearest.x, 7.0)
				if nearest.y < at.y - 45 and player.is_on_floor():
					jump = true
	else:
		# Keep enough horizontal room for normal recoil and an actual jump-over.
		var preferred := 210.0
		if absf(dx) > preferred + 35:
			axis = signf(dx)
		elif absf(dx) < preferred - 35:
			axis = -signf(dx)
		intent = "reposition with normal run input"
		if state in ["roll_warning", "combo_warning", "roll", "approach"]:
			intent = "approach and plant during charge warning; jump and cross"
			var incoming: bool = dx * float(encounter.direction) < 0.0
			if state in ["roll_warning", "combo_warning"] and incoming:
				# Establish towardward velocity before jumping. Reversing a full
				# awayward run in midair delayed the old pilot until descent.
				axis = signf(dx) if absf(dx) > 175.0 else 0.0
			if incoming and absf(dx) < 280.0 and player.is_on_floor():
				if state == "roll" or (state in ["roll_warning", "combo_warning"] and float(encounter.clock) < .055):
					jump = true
					cross_axis = signf(dx)
					cross_until = frame + 32
			if frame < cross_until:
				axis = cross_axis
		elif state in ["ring_warning", "rings"]:
			intent = "read real ground-wave trajectory and jump"
		elif state in ["lob_aim", "lob_lock", "lob"]:
			intent = "track actual lob lock; run out of landing zone"
			if state != "lob_aim":
				var locked: Vector2 = encounter.locked_point
				# Move to a fixed safe offset from the actual locked landing,
				# then stop; repeatedly returning toward preferred range could
				# walk straight back into the falling bell's landing zone.
				var destination := clampf(locked.x + lob_escape_axis * 165.0, arena.position.x + 60.0, arena.end.x - 60.0)
				axis = _toward(at.x, destination, 12.0)
		elif state == "neck" or (state == "observe" and recovery_start_frame >= 0 and current_group > 0):
			intent = "find clear bell angle; two legal shots, then retreat"
			var limit := 3 if mode in ["greed3", "greed3_late"] else 2
			var due := .08 if recovery_shots == 0 else .36 if recovery_shots == 1 else .90
			var counter_age := float(frame - recovery_start_frame) / 60.0
			if recovery_shots < limit and counter_age >= due and frame - last_shot_frame >= 16 and player.is_on_floor() and not incoming_wave:
				var energy_ready: bool = controller.shot_energy == null or controller.shot_energy.can_fire()
				if float(controller.shoot_ability.cooldown_remaining) <= .001 and int(controller.action_resources.shot_charges) > 0 and energy_ready:
					var adapter: Node = player.get_node("KeyboardMouseAdapter")
					var direction: Vector2 = adapter.world_direction(pointer)
					var clear := _shot_clear(app, at, aim)
					var accepted: bool = clear and router.request_action(&"shoot_release", direction)
					input_rows.append({"frame": frame, "movie_frame": Engine.get_process_frames(), "action": "shoot_release", "direction": [direction.x, direction.y], "submitted": accepted, "group": group, "ordinal": recovery_shots + 1, "recovery_age": counter_age, "actual_state": state, "intent": mode})
					if accepted:
						recovery_shots += 1
						last_shot_frame = frame
					elif not clear:
						intent = "terrain blocks bell ray; legally run toward clear angle"
						axis = signf(dx)
			if recovery_shots < limit:
				axis = signf(dx) if absf(dx) > 320.0 else 0.0
				if not _shot_clear(app, at, aim):
					axis = signf(dx)
			else:
				axis = -signf(dx) if absf(dx) < 275.0 else 0.0
		# Every fourth group offers real platform play. One-way platforms remain
		# unchanged; a full held jump can reach the existing lower shelves.
		if current_group > 0 and current_group % 4 == 0 and state == "observe":
			if player.is_on_floor() and absf(dx) > 180.0:
				jump = true
				intent = "legal jump toward existing platform; selection remains autonomous"
	if wave_jump:
		jump = true
		intent = "actual approaching wave takes priority across every state"
	if mode == "greed3_late":
		var reaction := _late_visible_reaction(app, encounter, metrics)
		if bool(reaction.get("waiting", false)):
			axis = 0.0
			jump = false
			intent = "第三枪后晚读招/晚撤对照 / one late visible-threat reaction; existing recoil continues"
		elif bool(reaction.get("attempt", false)):
			axis = float(reaction.axis)
			jump = bool(reaction.jump)
			intent = "第三枪后晚读招/晚撤对照 / actual distance deadline reached; normal evade attempted"
	# Stay inside the real sealed arena using ordinary movement only.
	if app._boss_started:
		if at.x < arena.position.x + 48 and axis < 0:
			axis = 1.0
		if at.x > arena.end.x - 48 and axis > 0:
			axis = -1.0
	if jump and frame >= jump_until:
		# Keep the real hold through the entire ascent. Releasing after .20s
		# clipped the old jump at 117wu; it was not a terrain ceiling collision.
		jump_until = frame + 27
		input_rows.append({"frame": frame, "movie_frame": Engine.get_process_frames(), "action": "jump_hold", "group": group, "intent": intent})
	router.set_jump_held(&"keyboard_mouse", frame < jump_until)
	router.set_source_axis(&"keyboard_mouse", axis)


func _toward(value: float, target: float, tolerance: float) -> float:
	return signf(target - value) if absf(target - value) > tolerance else 0.0


func observe_actual_shot(shot_id: int) -> void:
	# This is an observation of the real successful ShootAbility signal. It
	# changes only this player's subsequent movement decision, never the boss.
	if armour_probe_awaiting_actual_shot:
		armour_probe_awaiting_actual_shot = false
		armour_probe_actual_shot = shot_id
		input_rows.append({"frame": frame, "movie_frame": Engine.get_process_frames(), "action": "armour_probe_actual_shot", "actual_shot_id": shot_id, "ordinal": 0, "intent": "装甲试射，HP应不变", "interpretation": "Actual shot observed; armour feedback and unchanged HP require actual encounter events"})
		return
	if mode != "greed3_late" or recovery_shots != 3 or late_reaction_armed or late_reaction_consumed:
		return
	late_reaction_armed = true
	late_reaction_source_group = group
	late_reaction_status = "armed_after_first_actual_third_shot"
	input_rows.append({"frame": frame, "movie_frame": Engine.get_process_frames(), "action": "intentional_late_withdraw", "after_actual_shot_id": shot_id, "group": group, "label": "第三枪后晚读招/晚撤对照", "scope": "ONE next visible threat; then normal reactive evades resume", "thresholds_wu": {"incoming_roll_horizontal_gap": 100.0, "incoming_ground_wave_horizontal_gap": 35.0, "descending_bell_distance": 45.0}, "causality": "intentional player reaction delay after third shot; no claim third shot alone causes injury"})


func _late_visible_reaction(app: Node, encounter: Node, metrics: Dictionary) -> Dictionary:
	if not late_reaction_armed or late_reaction_consumed:
		return {}
	var current_group := int(metrics.get("groups_started", 0))
	var state := str(encounter.mode)
	var at: Vector2 = app.player.global_position
	var boss_at: Vector2 = app.stage.boss.global_position
	if late_reaction_group < 0:
		if current_group <= late_reaction_source_group:
			return {}
		if state in ["roll_warning", "combo_warning", "roll"]:
			late_reaction_kind = "roll"
		elif state in ["ring_warning", "rings"]:
			late_reaction_kind = "ring"
		elif state in ["lob_aim", "lob_lock", "lob"]:
			late_reaction_kind = "lob"
		else:
			return {}
		late_reaction_group = current_group
		late_reaction_started = frame
		late_reaction_status = "waiting_for_actual_" + late_reaction_kind + "_distance_deadline"
		input_rows.append({"frame": frame, "movie_frame": Engine.get_process_frames(), "action": "late_visible_threat_detected", "group": current_group, "source_third_shot_group": late_reaction_source_group, "actual_state": state, "kind": late_reaction_kind, "player": [at.x, at.y], "boss": [boss_at.x, boss_at.y], "label": "第三枪后晚读招/晚撤对照"})
	var attempt := false
	var threat_at := boss_at
	var measured_gap := INF
	var threshold := 100.0
	var axis := signf(boss_at.x - at.x)
	var relevant_alive := false
	if late_reaction_kind == "roll":
		late_threat_seen = late_threat_seen or state == "roll"
		measured_gap = absf(boss_at.x - at.x)
		attempt = state == "roll" and (boss_at.x - at.x) * float(encounter.direction) < 0.0 and measured_gap <= threshold
	else:
		threshold = 35.0 if late_reaction_kind == "ring" else 45.0
		for projectile: Variant in encounter.get("_projectiles"):
			if not is_instance_valid(projectile) or projectile.is_queued_for_deletion() or bool(projectile.spent):
				continue
			var id := str(projectile.event_id)
			var point: Vector2 = projectile.global_position
			if late_reaction_kind == "ring" and id.begins_with("bellstrider_ring-"):
				late_threat_seen = true
				var gap := point.x - at.x
				if gap * float(projectile.direction.x) < 0.0 and absf(gap) < measured_gap:
					relevant_alive = true
					measured_gap = absf(gap)
					threat_at = point
					axis = float(projectile.direction.x)
					attempt = measured_gap <= threshold
			elif late_reaction_kind == "lob" and id.begins_with("bellstrider_lob-"):
				late_threat_seen = true
				relevant_alive = true
				if float(projectile.direction.y) > 0.0:
					var gap := at.distance_to(point)
					if gap < measured_gap:
						measured_gap = gap
						threat_at = point
						axis = signf(at.x - point.x)
						if is_zero_approx(axis):
							axis = -signf(boss_at.x - at.x)
						attempt = measured_gap <= threshold
	if attempt:
		late_reaction_consumed = true
		late_reaction_status = "actual_distance_deadline_evade_attempted_normal_reactions_restored"
		if late_reaction_kind == "roll":
			cross_axis = axis
			cross_until = frame + 32
		input_rows.append({"frame": frame, "movie_frame": Engine.get_process_frames(), "action": "late_distance_deadline_evade_attempt", "group": current_group, "actual_state": state, "kind": late_reaction_kind, "measured_gap_wu": measured_gap, "threshold_wu": threshold, "visible_reaction_delay_seconds": float(frame - late_reaction_started) / 60.0, "player": [at.x, at.y], "threat": [threat_at.x, threat_at.y], "axis": axis, "jump_requested": true, "grounded": app.player.is_on_floor(), "causality": "legal player input attempt triggered by actual visible threat distance, never by HP changes"})
		return {"attempt": true, "axis": axis, "jump": true}
	var finished_visible_group: bool = state in ["neck", "observe"] and (late_reaction_kind == "roll" or (late_threat_seen and not relevant_alive))
	if current_group != late_reaction_group or finished_visible_group or encounter.health.terminal:
		late_reaction_consumed = true
		late_reaction_status = "threat_passed_without_distance_deadline_normal_reactions_restored"
		input_rows.append({"frame": frame, "movie_frame": Engine.get_process_frames(), "action": "late_threat_finished_without_distance_deadline", "group": current_group, "actual_state": state, "kind": late_reaction_kind, "player": [at.x, at.y], "interpretation": "No forced injury; current position or terrain may have kept this delayed reaction safe"})
		return {}
	return {"waiting": true}


func late_reaction_snapshot() -> Dictionary:
	return {"armed": late_reaction_armed, "consumed": late_reaction_consumed, "status": late_reaction_status, "source_third_group": late_reaction_source_group, "threat_group": late_reaction_group, "kind": late_reaction_kind, "elapsed_seconds": float(frame - late_reaction_started) / 60.0 if late_reaction_started >= 0 else 0.0}


func _shot_clear(app: Node, origin: Vector2, target: Vector2) -> bool:
	var player: CharacterBody2D = app.player
	var pointer: Vector2 = player.get_canvas_transform() * target
	var direction: Vector2 = player.get_node("KeyboardMouseAdapter").world_direction(pointer)
	var muzzle: Vector2 = player.get_node("CourierVisual").muzzle_position(direction)
	var shape := CircleShape2D.new()
	shape.radius = float(player.tuning.projectile_radius) + .5
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, origin)
	query.collision_mask = 1
	query.exclude = [player.get_rid(), app.stage.boss.get_rid()]
	query.collide_with_areas = false
	var space := player.get_world_2d().direct_space_state
	# Match the actual initial body-to-muzzle launch sweep and subsequent shot
	# radius. A zero-width centre ray missed the shelf's lower grazing edge.
	query.motion = muzzle - origin
	var launch: PackedFloat32Array = space.cast_motion(query)
	if launch.size() == 2 and float(launch[0]) < .999:
		return false
	query.transform.origin = muzzle
	query.motion = target - muzzle
	var travel: PackedFloat32Array = space.cast_motion(query)
	return travel.size() == 2 and float(travel[0]) >= .999
