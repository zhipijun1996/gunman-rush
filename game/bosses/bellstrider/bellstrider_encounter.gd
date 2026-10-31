class_name BellstriderEncounter
extends WindkeeperEncounter
## Encounter-owned clock, immutable selected groups, and shared articulated rig.
## Damage statistics observe accepted Health transactions and never choose states.
var pattern_index := 0  # Completed groups, retained for existing observers.
var locked_point := Vector2.ZERO
var volley := 0
var _roll_age := 0.0
var _rng := RandomNumberGenerator.new()
var _group: Dictionary = {}
var _recent_groups: Array[StringName] = []
var _fight_age := 0.0
var _state_age := 0.0
var _state_duration := 0.0
var _travel := 0.0
var _camp_age := 0.0
var _camp_anchor := Vector2.ZERO
var _ring_strike_age := 99.0
var _bell_hit_age := 99.0
var _armour_hit_age := 99.0
var _death_age := 0.0
var _death_jammed := false
var _death_impacted := false
var _death_finished := false
var _phase_pending := false
var _recovery_from: StringName = &"observe"
var _transition_from: Dictionary = {}
var _transition_prepared := false
var _launcher_aim := -0.82
var _hull_rig_ready := false
var _armour_wheels: Array[CollisionShape2D] = []
var _contact_actor_box := RectangleShape2D.new()
var _accepted_hits := 0
var _accepted_damage := 0.0
var _groups_started := 0
var _groups_completed := 0
var _cancelled_callbacks := 0
var _history: Array[Dictionary] = []
var _state_history: Array[Dictionary] = []
var _event_history: Array[Dictionary] = []


func _config() -> BellstriderDefinition:
	return definition as BellstriderDefinition


func _ready() -> void:
	super._ready()
	if _config() == null:
		push_error("Bellstrider requires BellstriderDefinition")
		return
	var shape := _core.get_child(0) as CollisionShape2D
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(30, 36)
	shape.shape = rectangle
	# The bevel above the copper nose is real clear air for ground diagonals.
	# A full140x70 box intercepted visible paths to the exposed upper bell.
	var hull := motor.get_node("CollisionShape2D") as CollisionShape2D
	var polygon := ConvexPolygonShape2D.new()
	polygon.points = PackedVector2Array(BellstriderRigPose.HULL_POINTS)
	hull.shape = polygon
	_hull_rig_ready = true
	for side: int in [-1, 1]:
		var wheel := CollisionShape2D.new()
		wheel.name = "BellArmourLeftWheel" if side < 0 else "BellArmourRightWheel"
		var circle := CircleShape2D.new()
		circle.radius = BellstriderRigPose.WHEEL_RADIUS
		wheel.shape = circle
		motor.add_child.call_deferred(wheel)
		_armour_wheels.append(wheel)
	_core.add_to_group(&"grapple_target")
	health.changed.connect(_health_changed)
	armour_hit.connect(_armour_feedback)
	_update_combat_shapes()


func configure_arena(left: float, right: float, target: Node2D) -> bool:
	if _config() == null or not super.configure_arena(left, right, target):
		return false
	_rng.seed = _config().selection_seed ^ int(roundf(left)) ^ (int(roundf(right)) * 31)
	_camp_anchor = target.global_position
	return true


func activate() -> bool:
	if _config() == null or not super.activate():
		return false
	pattern_index = 0
	_group.clear()
	_recent_groups.clear()
	_fight_age = 0.0
	_travel = 0.0
	_camp_age = 0.0
	_camp_anchor = _target.global_position
	_death_age = 0.0
	_death_jammed = false
	_death_impacted = false
	_death_finished = false
	_update_combat_shapes()
	return true


func weakpoint_only() -> bool:
	return true


func reward_impact_delay() -> float:
	return _config().reward_impact_seconds


func reward_impact_ready() -> bool:
	return health.terminal and _death_impacted


func restore_region_entry(data: Dictionary) -> void:
	if float(data.health) <= 0:
		prepare_terminal_restore()
	super.restore_region_entry(data)
	pattern_index = int(data.get("pattern_index",0))


func _region_pattern_index() -> int:
	return pattern_index


func prepare_terminal_restore() -> void:
	# Region loading restores Health before it has the bound player/arena needed
	# for the complete combat snapshot. Suppress a new death transition during
	# that reconstruction; the subsequent restore resumes the saved failure pose.
	active = false
	mode = &"dead"
	motor.stop()
	motor.collision_layer = 0
	motor.collision_mask = 0
	_update_combat_shapes()


func core_offset() -> Vector2:
	var transform: Transform2D = rig_pose().get("bell_transform", Transform2D.IDENTITY)
	return transform.origin


func rig_pose() -> Dictionary:
	return BellstriderRigPose.sample(_rig_inputs())


func _rig_inputs() -> Dictionary:
	return {
		"mode": mode,
		"phase": stage_phase,
		"direction": direction,
		"fight_age": _fight_age,
		"state_age": _state_age,
		"state_duration": _state_duration,
		"warning_progress": _warning_progress(),
		"speed": motor.velocity.x if is_instance_valid(motor) else 0.0,
		"travel": _travel,
		"combo": bool(_group.get("return_roll", false)),
		"combo_index": int(_group.get("roll_index", 0)),
		"recovery_progress":
		clampf(_state_age / maxf(.01, _state_duration), 0.0, 1.0) if mode == &"neck" else 0.0,
		"ring_strike_age": _ring_strike_age,
		"bell_hit_age": _bell_hit_age,
		"armour_hit_age": _armour_hit_age,
		"death_age": _death_age,
		"death_duration": _config().death_seconds if _config() != null else 1.8,
		"transition_from": _transition_from,
		"recovery_from": _recovery_from,
		"launcher_aim": _launcher_aim
	}


func _warning_progress() -> float:
	return (
		clampf(_state_age / maxf(.01, _state_duration), 0.0, 1.0)
		if (
			mode
			in [
				&"roll_warning",
				&"combo_warning",
				&"ring_warning",
				&"lob_aim",
				&"lob_lock",
				&"phase_transition"
			]
		)
		else 0.0
	)


func _update_combat_shapes() -> void:
	if not is_instance_valid(_core) or not is_instance_valid(motor):
		return
	var pose := rig_pose()
	if _hull_rig_ready:
		(motor.get_node("CollisionShape2D") as CollisionShape2D).transform = pose.body_transform
		if is_instance_valid(_contact_shape):
			_contact_shape.transform = (
				pose.body_transform * Transform2D(0, _config().contact_offset)
			)
		for index: int in _armour_wheels.size():
			_armour_wheels[index].transform = pose.left_wheel if index == 0 else pose.right_wheel
	_core.transform = pose.get("bell_transform", Transform2D.IDENTITY)
	var shape := _core.get_child(0) as CollisionShape2D
	if shape.shape is RectangleShape2D:
		var rectangle := shape.shape as RectangleShape2D
		var size: Vector2 = pose.get("weak_size", Vector2(30, 36))
		if rectangle.size != size:
			rectangle.size = size
	_core.collision_layer = 4 if accepts_combat_damage() else 0
	# Only this low armour hull blocks shots. The raised bell is its own Area.
	motor.collision_layer = 4 if accepts_combat_damage() else 0


func objective() -> String:
	var text := "上端主铃始终可击 / UPPER BELL ALWAYS VULNERABLE"
	match mode:
		&"intro":
			text = (definition as WindkeeperDefinition).display_name
		&"dead":
			text = "巡游机已失效 / BELLSTRIDER DISABLED"
		&"roll_warning", &"combo_warning":
			text = (
				"双拍回冲：准备再次换边 / DOUBLE BEAT — RETURN CHARGE"
				if bool(_group.get("return_roll", false))
				else "轮组蓄力，跳越或换边 / WHEELS BRACED — JUMP OR CROSS"
			)
		&"combo_brake", &"combo_turn":
			text = "仍在连招，准备回冲 / RETURN CHARGE PENDING"
		&"ring_warning", &"rings":
			text = "听每次敲铃，跳过地波 / JUMP EACH BELL STRIKE"
		&"lob_aim":
			text = "发射器跟瞄，准备换位 / LAUNCHER TRACKING"
		&"lob_lock":
			text = "落点锁定，离开铜铃落点 / LANDING LOCKED — MOVE"
		&"phase_transition":
			text = "护板展开，留意双拍回冲 / ARMOUR OPENING — LISTEN FOR DOUBLE BEAT"
		&"neck":
			text = "真收招，瞄准上端主铃 / RECOVERY — AIM AT THE UPPER BELL"
	return text


func _capture_transition() -> void:
	var pose := rig_pose()
	_transition_from.clear()
	for key: String in [
		"body_transform",
		"mast_transform",
		"bell_transform",
		"launcher_transform",
		"left_wheel",
		"right_wheel",
		"panel_angle",
		"clapper_angle"
	]:
		if pose.has(key):
			_transition_from[key] = pose[key]
	_transition_prepared = true


func _enter(next: StringName, duration: float) -> void:
	if not _transition_prepared:
		_capture_transition()
	_transition_prepared = false
	if not _state_history.is_empty():
		_state_history[-1]["end"] = _fight_age
	super._enter(next, duration)
	_state_age = 0.0
	_state_duration = duration
	_state_history.append(
		{"mode": String(next), "start": _fight_age, "duration": duration, "group": _groups_started}
	)
	if _state_history.size() > 256:
		_state_history.pop_front()
	match next:
		&"roll_warning", &"combo_warning":
			_event(
				&"bellstrider_roll_warn",
				{
					"combo": bool(_group.get("return_roll", false)),
					"index": int(_group.get("roll_index", 0))
				}
			)
		&"roll":
			_event(&"bellstrider_roll_start")
		&"combo_brake":
			_event(&"bellstrider_brake", {"final": false})
		&"combo_turn":
			_event(&"bellstrider_turn")
		&"lob_aim":
			_event(&"bellstrider_lob_aim")
		&"lob_lock":
			_event(&"bellstrider_lob_lock", {"point": locked_point})
		&"neck":
			_event(&"bellstrider_brake", {"final": true})
		&"phase_transition":
			_event(&"bellstrider_phase")


func physics_tick(delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta):
		return
	if mode == &"dead":
		_advance_death(delta)
		return
	_prune_attacks()
	if not active or health.terminal or not is_instance_valid(_target):
		return
	_fight_age += delta
	_state_age += delta
	_ring_strike_age += delta
	_bell_hit_age += delta
	_armour_hit_age += delta
	clock -= delta
	if stage_phase == 1 and health.current <= health.capacity * _config().phase_two_health:
		_phase_pending = true
	if _phase_pending and mode == &"approach" and _group.is_empty():
		_start_phase_two()
	if _target.global_position.distance_to(_camp_anchor) > _config().camping_radius:
		_camp_anchor = _target.global_position
		_camp_age = 0.0
	else:
		_camp_age += delta
	var before := motor.global_position.x
	match mode:
		&"intro":
			if clock <= 0.0:
				_enter(&"observe", _config().observe_seconds)
		&"observe":
			if clock <= 0.0:
				if _phase_pending:
					_start_phase_two()
				else:
					_select_group()
		&"approach":
			motor.speed = move_toward(
				absf(motor.velocity.x),
				_config().chase_speed,
				_config().chase_speed / _config().roll_acceleration_seconds * delta
			)
			var limit := arena.travel_limit(motor.global_position.x, direction)
			motor.step(direction, limit, delta)
			if (
				limit <= .01
				or (
					absf(_target.global_position.x - motor.global_position.x)
					<= _config().approach_distance * .85
				)
			):
				motor.stop()
				if _phase_pending:
					_start_phase_two()
				else:
					_select_group()
		&"roll_warning", &"combo_warning":
			if clock <= 0.0:
				_roll_age = 0.0
				_enter(&"roll", _config().roll_max_seconds)
		&"roll":
			_roll_age += delta
			var charge := (
				_config().phase_two_charge_speed
				if int(_group.get("phase", 1)) == 2
				else _config().charge_speed
			)
			motor.speed = charge * clampf(_roll_age / _config().roll_acceleration_seconds, 0.0, 1.0)
			var limit := arena.travel_limit(motor.global_position.x, direction)
			motor.step(direction, limit, delta)
			if clock <= 0.0 or limit <= motor.speed * delta + .01:
				motor.stop()
				if bool(_group.get("return_roll", false)) and int(_group.get("roll_index", 0)) == 0:
					_enter(&"combo_brake", _config().combo_brake_seconds)
				else:
					_cool_down()
		&"combo_brake":
			if clock <= 0.0:
				_capture_transition()
				direction *= -1
				_group["roll_index"] = 1
				_enter(&"combo_turn", _config().combo_turn_seconds)
		&"combo_turn":
			if clock <= 0.0:
				_enter(&"combo_warning", _config().combo_warning_seconds)
		&"ring_warning":
			if clock <= 0.0:
				_ring_pair()
				volley += 1
				_enter(
					&"rings",
					(
						_config().ring_interval_seconds
						if volley < int(_group.get("count", 1))
						else _config().ring_settle_seconds
					)
				)
		&"rings":
			if clock <= 0.0:
				if volley < int(_group.get("count", 1)):
					_ring_pair()
					volley += 1
					_enter(&"rings", _config().ring_settle_seconds)
				else:
					_cool_down()
		&"lob_aim":
			locked_point = _landing_for_target()
			_aim_launcher(locked_point)
			if clock <= 0.0:
				_enter(&"lob_lock", _config().lob_lock_seconds)
		&"lob_lock":
			if clock <= 0.0:
				_launch(locked_point)
				volley += 1
				_enter(&"lob", lob_duration_for(locked_point) + _config().lob_followup_seconds)
		&"lob":
			if clock <= 0.0:
				if volley < int(_group.get("count", 1)):
					_enter(&"lob_aim", _config().lob_aim_seconds)
				else:
					_cool_down()
		&"neck":
			if clock <= 0.0:
				_groups_completed += 1
				pattern_index += 1
				_history.append(
					{
						"group": _groups_started,
						"kind": _group.get("kind", &""),
						"end": _fight_age,
						"recovery_start": _fight_age - _state_age,
						"recovery_seconds": _state_age
					}
				)
				if _history.size() > 128:
					_history.pop_front()
				_group.clear()
				_enter(&"observe", _config().observe_seconds)
		&"phase_transition":
			if clock <= 0.0:
				_enter(&"observe", _config().observe_seconds)
	_travel += motor.global_position.x - before
	_update_combat_shapes()
	motor.queue_redraw()


func _start_phase_two() -> void:
	# Never interrupts or changes a selected group, including its projectiles.
	_phase_pending = false
	stage_phase = 2
	motor.stop()
	phase_changed.emit(2)
	_enter(&"phase_transition", _config().phase_warning_seconds)


func selection_weights() -> Dictionary:
	var dx := absf(_target.global_position.x - motor.global_position.x)
	var elevation := _floor_y - (_target.global_position.y + 18.0)
	var high := elevation >= _config().elevated_height
	var near := dx < _config().near_distance
	var camping := _camp_age >= _config().camping_seconds
	var weights := {
		&"roll": 3.6 if dx > _config().near_distance else 1.0,
		&"ring": 3.8 if near and not high else 1.0,
		&"lob": 4.0 if high else 1.0
	}
	if camping:
		weights[&"lob"] = float(weights[&"lob"]) + 2.6
	# A charge begins outside contact and needs actual acceleration/braking room.
	# At an edge/point-blank start select another complete group, never an
	# instantaneous dash or a warning whose real trajectory is impossible.
	var side := 1 if _target.global_position.x >= motor.global_position.x else -1
	if (
		dx < _config().minimum_roll_start_distance
		or arena.travel_limit(motor.global_position.x, side) < _config().minimum_roll_travel
	):
		weights[&"roll"] = 0.0
	for index: int in _recent_groups.size():
		var kind: StringName = _recent_groups[index]
		weights[kind] = (
			float(weights[kind])
			* pow(_config().recent_group_penalty, float(index + 1) / float(_recent_groups.size()))
		)
	if _recent_groups.size() >= _config().max_group_repeats:
		var last := _recent_groups[-1]
		var repeated := true
		for index: int in _config().max_group_repeats:
			if _recent_groups[-1 - index] != last:
				repeated = false
		if repeated:
			weights[last] = 0.0
	return weights


func _select_group() -> void:
	# Close the distance before choosing a committed attack, regardless of which
	# random group will follow. This prelude never spends RNG or an attack group.
	if absf(_target.global_position.x - motor.global_position.x) > _config().approach_distance:
		_capture_transition()
		direction = 1 if _target.global_position.x >= motor.global_position.x else -1
		_enter(&"approach", _config().approach_seconds)
		return
	var weights := selection_weights()
	var total := float(weights[&"roll"]) + float(weights[&"ring"]) + float(weights[&"lob"])
	var pick := _rng.randf() * total
	var chosen: StringName = &"lob"
	for kind: StringName in [&"roll", &"ring", &"lob"]:
		pick -= float(weights[kind])
		if pick < 0.0:
			chosen = kind
			break
	_capture_transition()
	direction = 1 if _target.global_position.x >= motor.global_position.x else -1
	# Every random group property is fixed before any attack warning starts.
	_group = {
		"kind": chosen,
		"phase": stage_phase,
		"direction": direction,
		"return_roll":
		chosen == &"roll" and stage_phase == 2 and _rng.randf() < _config().return_roll_chance,
		# Every random group property is fixed before any attack warning starts.
		"roll_index": 0,
		"count": 2 if stage_phase == 2 and chosen != &"roll" else 1,
		"selected_at": _fight_age,
		"weights": weights.duplicate(true)
	}
	_recent_groups.append(chosen)
	if _recent_groups.size() > 4:
		_recent_groups.pop_front()
	_groups_started += 1
	volley = 0
	_event(&"bellstrider_group", {"plan": _group.duplicate(true), "group": _groups_started})
	_start_group_warning()


func _start_group_warning() -> void:
	motor.stop()
	match StringName(_group.get("kind", &"roll")):
		&"roll":
			_enter(&"roll_warning", _config().roll_warning_seconds)
		&"ring":
			_enter(&"ring_warning", _config().ring_warning_seconds)
		&"lob":
			locked_point = _landing_for_target()
			_enter(&"lob_aim", _config().lob_aim_seconds)


func _cool_down() -> void:
	_recovery_from = mode
	motor.stop()
	_enter(&"neck", _config().exposed_seconds)


func _ring_pair() -> void:
	_ring_strike_age = 0.0
	_event(
		&"bellstrider_ring_strike",
		{"wave": volley + 1, "point": Vector2(motor.global_position.x, _floor_y)}
	)
	for side: int in [-1, 1]:
		var shot := BellstriderRingProjectile.new()
		_configure_projectile(shot, &"bellstrider_ring", Vector2(side, 0))
		shot.speed = _config().ring_speed
		shot.radius = _config().ring_radius
		shot._shape.radius = shot.radius
		shot.lifetime = _config().ring_lifetime
		shot.global_position = Vector2(
			motor.global_position.x + side * 74, _floor_y - shot.radius - 2
		)


func _configure_projectile(shot: BossProjectile, kind: StringName, aim: Vector2) -> void:
	_attack_serial += 1
	shot.configure(
		definition,
		StringName("%s-%s-%s" % [kind, attack_epoch, _attack_serial]),
		aim,
		_target,
		motor
	)
	shot.set_meta(&"item_v5_world_entity", true)
	if shot.has_method("bind_attack"):
		shot.call("bind_attack", self, attack_epoch)
	_projectiles.append(shot)
	projectile_created.emit(shot)
	motor.get_parent().add_child(shot)


func _landing_for_target() -> Vector2:
	# BossArena limits its centre by the large chassis half-width. A player can
	# stand closer to the seals, so targeting must use the actual player x.
	var feet := _target.global_position + Vector2(0, 18)
	var excluded: Array[RID] = [motor.get_rid()]
	if _target is CollisionObject2D:
		excluded.append((_target as CollisionObject2D).get_rid())
	# A jumping player above a gap still receives a mark on real nearby ground.
	# The final candidate is the supported machine itself, never a fake plane.
	var candidates: Array[Vector2] = []
	for offset: float in [0.0, -32.0, 32.0, -64.0, 64.0, -128.0, 128.0]:
		candidates.append(feet + Vector2(offset, -2))
	candidates.append(motor.global_position)
	for candidate: Vector2 in candidates:
		var query := PhysicsRayQueryParameters2D.create(
			candidate, Vector2(candidate.x, maxf(_floor_y + 160, candidate.y + 800)), 1
		)
		query.exclude = excluded
		var result := motor.get_world_2d().direct_space_state.intersect_ray(query)
		if not result.is_empty():
			return result.position
	# Invalid arena geometry cannot create a remote invisible ground shock.
	return motor.global_position


func _aim_launcher(point: Vector2) -> void:
	# Match the visible barrel to the actual ballistic launch velocity. Solve
	# twice because the muzzle moves with the elevation; tracking stops at lock.
	var body: Transform2D = rig_pose().body_transform
	var duration := lob_duration_for(point)
	for index: int in 2:
		var mount := body * Transform2D(_launcher_aim, Vector2(43, 4))
		var origin := motor.to_global(mount * Vector2(25, -3))
		var initial := (
			(point - origin) / duration - Vector2(0, _config().lob_gravity * duration * .5)
		)
		_launcher_aim = clampf(body.basis_xform_inv(initial).angle(), -PI + .18, -.18)


func lob_duration_for(point: Vector2) -> float:
	# A lower landing needs a steeper descending leg to clear nearby shelf
	# corners. Raised targets keep a shorter arc within the normal camera view.
	return (
		_config().lob_lower_flight_seconds
		if point.y > motor.global_position.y + 10.0
		else _config().lob_flight_seconds
	)


func _launch(point: Vector2) -> void:
	var shot := BellstriderBellProjectile.new()
	var pose := rig_pose()
	var launcher: Transform2D = pose.get("launcher_transform", Transform2D(0, Vector2(34, -34)))
	_configure_projectile(shot, &"bellstrider_lob", (point - motor.global_position).normalized())
	shot.global_position = motor.to_global(launcher * Vector2(25, -3))
	shot.gravity = _config().lob_gravity
	var duration := lob_duration_for(point)
	shot.lifetime = duration + 1.5
	shot.aim_landing(point, duration)
	var epoch := attack_epoch
	shot.impacted.connect(
		func(surface: Vector2, normal: Vector2) -> void: _lob_impact(surface, normal, epoch)
	)
	_event(
		&"bellstrider_lob_release",
		{"point": point, "origin": shot.global_position, "volley": volley + 1}
	)


func _lob_impact(point: Vector2, normal: Vector2, epoch: int) -> void:
	if not active or health.terminal or epoch != attack_epoch:
		_cancelled_callbacks += 1
		return
	_event(&"bellstrider_lob_impact", {"point": point, "normal": normal})
	# One bounded stationary shock, aligned with the actual hit surface.
	var shot := BellstriderRingProjectile.new()
	_configure_projectile(shot, &"bellstrider_local_ring", Vector2.ZERO)
	shot.speed = 0.0
	shot.lifetime = _config().lob_impact_seconds
	shot.configure_local(_config().lob_impact_radius, normal)
	shot.global_position = point + normal * 9.0


func _event(id: StringName, extra: Dictionary = {}) -> void:
	var row := {
		"event": id,
		"age": _fight_age,
		"position": motor.global_position if is_instance_valid(motor) else Vector2.ZERO,
		"phase": stage_phase,
		"direction": direction,
		"mode": mode,
		"group": _groups_started
	}
	row.merge(extra, true)
	_event_history.append(row.duplicate(true))
	if _event_history.size() > 256:
		_event_history.pop_front()
	presentation_event.emit(row)


func _health_changed(result: ActorResourceResult) -> void:
	if (
		result.operation != &"damage"
		or result.status != ActorResourceResult.Status.APPLIED
		or result.amount_applied >= 0.0
	):
		return
	_accepted_hits += 1
	_accepted_damage -= result.amount_applied
	_bell_hit_age = 0.0
	_update_combat_shapes()
	_event(
		&"bellstrider_bell_hit",
		{
			"amount": -result.amount_applied,
			"event_id": result.event_id,
			"health": health.current,
			"point": motor.to_global(core_offset())
		}
	)


func _armour_feedback(point: Vector2) -> void:
	_armour_hit_age = 0.0
	_update_combat_shapes()
	_event(&"bellstrider_armour_hit", {"point": point})


func body_contact_rect() -> Rect2:
	# Include the installed bell as well as armour. Receiving weapon damage and
	# dealing player contact damage are separate capabilities of the same bell.
	# Narrow admission below still preserves the open space around the mast.
	var hull := motor.get_node("CollisionShape2D") as CollisionShape2D
	var bounds := hull.global_transform * hull.shape.get_rect()
	for wheel: CollisionShape2D in _armour_wheels:
		if is_instance_valid(wheel) and wheel.is_inside_tree():
			bounds = bounds.merge(wheel.global_transform * wheel.shape.get_rect())
	var bell := _core.get_child(0) as CollisionShape2D
	bounds = bounds.merge(bell.global_transform * bell.shape.get_rect())
	return bounds


func body_contact_sweep(source_center: Vector2, previous_relative: Vector2, current_world: Vector2, actor_half: Vector2) -> bool:
	if not body_contact_enabled() or not source_center.is_finite() or not previous_relative.is_finite() or not current_world.is_finite() or not actor_half.is_finite() or actor_half.x<=0.0 or actor_half.y<=0.0:
		return false
	var start := source_center + previous_relative
	var motion := current_world - start
	var size := actor_half * 2.0
	if _contact_actor_box.size != size: _contact_actor_box.size = size
	var actor_transform := Transform2D(0,start)
	var hull := motor.get_node("CollisionShape2D") as CollisionShape2D
	if _contact_actor_box.collide_with_motion(actor_transform,motion,hull.shape,hull.global_transform,Vector2.ZERO):
		return true
	for wheel: CollisionShape2D in _armour_wheels:
		if is_instance_valid(wheel) and wheel.is_inside_tree() and _contact_actor_box.collide_with_motion(actor_transform,motion,wheel.shape,wheel.global_transform,Vector2.ZERO):
			return true
	var bell := _core.get_child(0) as CollisionShape2D
	if _contact_actor_box.collide_with_motion(actor_transform, motion, bell.shape, bell.global_transform, Vector2.ZERO):
		return true
	return false


func body_contact_enabled() -> bool:
	# Transition pressure still has real solid copper. Only intro, inactivity
	# and terminal wrecks suppress contact; the base Windkeeper window differs.
	return active and not health.terminal and mode not in [&"intro",&"dead"]


func cancel_pending_attacks() -> void:
	_clear_attacks()
	_event(&"bellstrider_audio_cancel")
	motor.stop()
	_group.clear()
	if active and mode != &"intro":
		_enter(&"observe", _config().observe_seconds)
	_update_combat_shapes()


func cancel() -> void:
	super.cancel()
	_event(&"bellstrider_audio_cancel")
	if is_instance_valid(_core):
		_core.collision_layer = 0


func _on_defeat() -> void:
	if mode == &"dead":
		return
	# Preserve the existing one-shot defeated signal and FrameDamagePolicy owner.
	# Death pose has its own bounded clock after active/contact are disabled.
	_clear_attacks()
	_event(&"bellstrider_audio_cancel")
	active = false
	motor.stop()
	motor.collision_layer = 0
	motor.collision_mask = 0
	_death_age = 0.0
	_enter(&"dead", _config().death_seconds)
	_event(&"bellstrider_death")
	_update_combat_shapes()
	defeated.emit(self)


func _advance_death(delta: float) -> void:
	var previous := _death_age
	_death_age = minf(_config().death_seconds, _death_age + delta)
	_fight_age += _death_age - previous
	_state_age = _death_age
	clock = maxf(0.0, _config().death_seconds - _death_age)
	if not _death_jammed and _death_age >= .38:
		_death_jammed = true
		_event(&"bellstrider_death_jam")
	if not _death_impacted and _death_age >= _config().reward_impact_seconds:
		_death_impacted = true
		_event(&"bellstrider_death_impact")
	if not _death_finished and _death_age >= _config().death_seconds:
		_death_finished = true
		_event(&"bellstrider_death_final")
	_update_combat_shapes()
	motor.queue_redraw()


func combat_metrics() -> Dictionary:
	return {
		"fight_seconds": _fight_age,
		"accepted_hits": _accepted_hits,
		"accepted_damage": _accepted_damage,
		"groups_started": _groups_started,
		"groups_completed": _groups_completed,
		"group_plan": _group.duplicate(true),
		"camping_seconds": _camp_age,
		"cancelled_callbacks": _cancelled_callbacks,
		"death_age": _death_age,
		"groups": _history.duplicate(true),
		"states": _state_history.duplicate(true),
		"events": _event_history.duplicate(true)
	}


func combat_snapshot() -> Dictionary:
	var data := super.combat_snapshot()
	data.merge(
		{
			"pattern_index": pattern_index,
			"locked_point": [locked_point.x, locked_point.y],
			"volley": volley,
			"roll_age": _roll_age,
			"stage_phase": stage_phase,
			"rng_state": str(_rng.state),
			"group": _group.duplicate(true),
			"recent_groups": _recent_groups.duplicate(),
			"fight_age": _fight_age,
			"state_age": _state_age,
			"state_duration": _state_duration,
			"travel": _travel,
			"camp_age": _camp_age,
			"camp_anchor": [_camp_anchor.x, _camp_anchor.y],
			"phase_pending": _phase_pending,
			"ring_strike_age": _ring_strike_age,
			"bell_hit_age": _bell_hit_age,
			"armour_hit_age": _armour_hit_age,
			"death_age": _death_age,
			"death_jammed": _death_jammed,
			"death_impacted": _death_impacted,
			"death_finished": _death_finished,
			"accepted_hits": _accepted_hits,
			"accepted_damage": _accepted_damage,
			"groups_started": _groups_started,
			"groups_completed": _groups_completed,
			"recovery_from": String(_recovery_from),
			"launcher_aim": _launcher_aim,
			"transition_from": _transition_snapshot()
		},
		true
	)
	return data


func restore_combat_state(data: Dictionary) -> void:
	# Existing callbacks cannot survive an in-place restore of the same actor.
	_clear_attacks()
	_event(&"bellstrider_audio_cancel")
	super.restore_combat_state(data)
	pattern_index = int(data.get("pattern_index", 0))
	volley = int(data.get("volley", 0))
	_roll_age = float(data.get("roll_age", 0))
	stage_phase = int(data.get("stage_phase", 1))
	if data.has("rng_state"):
		_rng.state = int(str(data.rng_state))
	_group = _restored_group(data.get("group", {}))
	_recent_groups.clear()
	for kind: Variant in data.get("recent_groups", []):
		_recent_groups.append(StringName(kind))
	_fight_age = float(data.get("fight_age", 0))
	_state_age = float(data.get("state_age", 0))
	_state_duration = float(data.get("state_duration", clock))
	_travel = float(data.get("travel", 0))
	_camp_age = float(data.get("camp_age", 0))
	var p: Array = data.get("locked_point", [0, 0])
	locked_point = Vector2(p[0], p[1])
	p = data.get("camp_anchor", [0, 0])
	_camp_anchor = Vector2(p[0], p[1])
	_phase_pending = bool(data.get("phase_pending", false))
	_ring_strike_age = float(data.get("ring_strike_age", 99))
	_bell_hit_age = float(data.get("bell_hit_age", 99))
	_armour_hit_age = float(data.get("armour_hit_age", 99))
	_death_age = float(data.get("death_age", 0))
	_death_jammed = bool(data.get("death_jammed", false))
	_death_impacted = bool(data.get("death_impacted", false))
	_death_finished = bool(data.get("death_finished", false))
	_accepted_hits = int(data.get("accepted_hits", 0))
	_accepted_damage = float(data.get("accepted_damage", 0))
	_groups_started = int(data.get("groups_started", 0))
	_groups_completed = int(data.get("groups_completed", 0))
	_recovery_from = StringName(data.get("recovery_from", &"roll"))
	_launcher_aim = float(data.get("launcher_aim", -.82))
	_restore_transition(data.get("transition_from", {}))
	_transition_prepared = false
	if mode == &"dead" or health.terminal:
		active = false
	# No delayed closures or projectiles are reconstructed by a stage snapshot.
	# A resumed group retains its exact plan; callbacks belong to the new epoch.
	_update_combat_shapes()


func _restored_group(data: Dictionary) -> Dictionary:
	# JSON carries neither StringName identity nor integer numeric tags. Restore
	# the announced plan's original types as well as its values; never redraw it.
	var result := data.duplicate(true)
	if result.has("kind"):
		result["kind"] = StringName(result.kind)
	for key: String in ["phase", "direction", "count", "roll_index"]:
		if result.has(key):
			result[key] = int(result[key])
	if result.has("return_roll"):
		result["return_roll"] = bool(result.return_roll)
	if result.has("selected_at"):
		result["selected_at"] = float(result.selected_at)
	if result.has("weights"):
		var weights: Dictionary = {}
		for key: Variant in result.weights:
			weights[StringName(key)] = float(result.weights[key])
		result["weights"] = weights
	return result


func _transition_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for key: String in _transition_from:
		var value: Variant = _transition_from[key]
		if value is Transform2D:
			var transform: Transform2D = value
			result[key] = [
				transform.x.x,
				transform.x.y,
				transform.y.x,
				transform.y.y,
				transform.origin.x,
				transform.origin.y
			]
		else:
			result[key] = value
	return result


func _restore_transition(data: Dictionary) -> void:
	_transition_from.clear()
	for key: String in data:
		var value: Variant = data[key]
		if value is Array and value.size() == 6:
			_transition_from[key] = Transform2D(
				Vector2(value[0], value[1]),
				Vector2(value[2], value[3]),
				Vector2(value[4], value[5])
			)
		elif value is float or value is int:
			_transition_from[key] = value


func presentation_state() -> BossPresentationState:
	var values := _presentation_values()
	values.merge(
		{
			"phase": stage_phase,
			"phase_axes": {"combat": stage_phase},
			"damage_model": &"upper_bell_only",
			"core_hint_visible": false,
			"rig": rig_pose(),
			"group": _group.duplicate(true)
		},
		true
	)
	return _presentation_countdown(
		values,
		mode,
		clock,
		_state_duration,
		(
			mode
			in [
				&"roll_warning",
				&"combo_warning",
				&"ring_warning",
				&"lob_aim",
				&"lob_lock",
				&"phase_transition"
			]
		),
		mode in [&"rings", &"lob"],
		mode in [&"roll", &"approach"],
		mode == &"neck"
	)


func presentation_core() -> Dictionary:
	return {
		"visible": false,
		"offset": core_offset(),
		"raw_clock": clock,
		"remaining_fraction": clampf(clock / maxf(.01, _state_duration), 0.0, 1.0),
		"continuous_combat": true,
		"weakpoint_only": true
	}


func presentation_locked_aim() -> Dictionary:
	return (
		{"position": locked_point, "locked": mode == &"lob_lock"}
		if mode in [&"lob_aim", &"lob_lock"]
		else {}
	)


func presentation_capabilities() -> PackedStringArray:
	return PackedStringArray(
		["core_anchor", "locked_lob", "combat_state", "articulated_rig", "weakpoint_only"]
	)


func roll_warning_distance() -> float:
	var speed := (
		_config().phase_two_charge_speed
		if int(_group.get("phase", stage_phase)) == 2
		else _config().charge_speed
	)
	return (
		minf(
			arena.travel_limit(motor.global_position.x, direction),
			speed * (_config().roll_max_seconds - _config().roll_acceleration_seconds * .5)
		)
		+ _config().contact_size.x * .5
	)
