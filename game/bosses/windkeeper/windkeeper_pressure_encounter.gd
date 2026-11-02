class_name WindkeeperPressureEncounter
extends WindkeeperEncounter
## Formal six-move Windkeeper. Randomness chooses an immutable attack group;
## clocks and actual geometry execute it. Statistics never drive the encounter.
var locked_target := Vector2.ZERO
var locked_direction := -1
var sweep_high := false
var foot_index := 0
# Old v5 terminal saves already settled their original reward chain.
var physical_reward_expected: bool = true
var _group_plan: Dictionary = {}
var _attack_index := 0
var _state_age := 0.0
var _state_duration := 0.0
var _fight_age := 0.0
var _death_age := 0.0
var _travel := 0.0
var _base_y := 0.0
var _lunge_start := Vector2.ZERO
var _lunge_distance := 0.0
var _lunge_distance_done := 0.0
var _release_sent := false
var _pending_phase := 1
var _groups_started := 0
var _groups_completed := 0
var _accepted_hits := 0
var _accepted_damage := 0.0
var _camp_age := 0.0
var _camp_origin := Vector2.ZERO
var _bell_hit_age := -1.0
var _recent_groups: Array[String] = []
var _selection_rng := RandomNumberGenerator.new()
var _event_history: Array[Dictionary] = []
var _active_strike: WindkeeperPressureStrike
var _death_impact_sent := false
var _death_final_sent := false
var _rig_ready := false
var _head_shape: CollisionShape2D
var _foot_shapes: Array[CollisionShape2D] = []
var _limb_shapes: Array[CollisionShape2D] = []
var _contact_actor := RectangleShape2D.new()
var _pose_from: Dictionary = {}
var _supports_bound := false
var _support_rects: Array[Rect2] = []
var _support_index := -1
var _bridge_released := false
var _hop_active := false
var _hop_start := Vector2.ZERO
var _hop_target := Vector2.ZERO
var _hop_target_index := -1
var _hop_age := 0.0
var _hop_duration := 0.0
var _hop_height := 0.0
var _hop_prepared := false
var _hop_is_baseline := false
var _hop_resume: StringName = &"approach"
var _preparation_index := -1
var _preparation_hops := 0
var _guarded_attack_index := -1

func _config() -> WindkeeperPressureDefinition:
	return definition as WindkeeperPressureDefinition

func _ready() -> void:
	super._ready()
	_selection_rng.seed = _config().selection_seed
	health.changed.connect(_health_changed)
	_install_rig.call_deferred()

func _install_rig() -> void:
	var hull := motor.get_node("CollisionShape2D") as CollisionShape2D
	hull.shape = ConvexPolygonShape2D.new()
	hull.transform = Transform2D.IDENTITY
	_head_shape = CollisionShape2D.new()
	_head_shape.name = "PressureHeadShape"
	_head_shape.shape = ConvexPolygonShape2D.new()
	motor.add_child(_head_shape)
	for index: int in 4:
		var foot := CollisionShape2D.new()
		foot.name = "PressureFoot%s" % index
		foot.shape = CircleShape2D.new()
		motor.add_child(foot)
		_foot_shapes.append(foot)
	for index: int in 8:
		var limb := CollisionShape2D.new()
		limb.name = "PressureLimb%s" % index
		limb.shape = CapsuleShape2D.new()
		motor.add_child(limb)
		_limb_shapes.append(limb)
	_rig_ready = true
	_update_combat_shapes()

func configure_arena(left: float, right: float, target: Node2D) -> bool:
	if not super.configure_arena(left, right, target): return false
	_base_y = motor.global_position.y
	_camp_origin = target.global_position
	return true

func activate() -> bool:
	if not super.activate(): return false
	_pending_phase = stage_phase
	return true

func physics_tick(delta: float) -> void:
	if delta <= 0 or not is_finite(delta): return
	_prune_attacks()
	if health.terminal:
		_advance_death(delta)
		return
	if not active or not is_instance_valid(_target): return
	_fight_age += delta
	if _bell_hit_age >= 0: _bell_hit_age += delta
	_state_age += delta
	clock = maxf(0, _state_duration - _state_age)
	var displacement := _target.global_position.distance_to(_camp_origin)
	if displacement > _config().camping_radius:
		_camp_origin = _target.global_position
		_camp_age = 0
	else:
		_camp_age += delta
	_pending_phase = 3 if health.current <= health.capacity * _config().phase_three_health else (2 if health.current <= health.capacity * _config().phase_two_health else 1)
	match mode:
		&"intro":
			if clock <= 0: _enter(&"observe", 0)
		&"phase_transition":
			# Mount a verified surviving platform before removing the old bridge.
			# The warning clock continues during the real locked physical leap.
			if stage_phase == 3 and _supports_bound and not _standing_on_support():
				if not _hop_active and _state_age >= _config().traverse_warning_seconds:
					var platform_index := _nearest_support_index(motor.global_position.x)
					if platform_index >= 0: _lock_support_hop(platform_index, _config().lunge_peak_speed)
				if _hop_active: _advance_support_hop(delta)
				if not _standing_on_support():
					_update_combat_shapes()
					motor.queue_redraw()
					return
			if clock <= 0:
				if stage_phase == 3: _bridge_released = true
				phase_changed.emit(stage_phase)
				_event(&"windkeeper_phase", {"phase": stage_phase})
				_select_group()
		&"observe":
			if _pending_phase > stage_phase: _start_phase_transition()
			else: _select_group()
		&"approach":
			_approach(delta)
		&"turn":
			if clock <= 0:
				direction = locked_direction
				_begin_attack()
		&"traverse_warning":
			if clock <= 0:
				_start_prepared_hop()
				_enter(&"traverse", _hop_duration)
				_event(&"windkeeper_traverse_start", {"point": _hop_target})
				_event(&"windkeeper_lunge_start", {"movement_only": true})
		&"traverse":
			if _advance_support_hop(delta):
				_event(&"windkeeper_traverse_land", {"point": motor.global_position})
				_event(&"windkeeper_lunge_land", {"movement_only": true})
				_enter(_hop_resume, _config().approach_bound_seconds)
		&"stomp_warning", &"lunge_warning", &"sweep_warning", &"gust_warning", &"seeds_warning", &"platform_warning":
			if clock <= 0: _release_attack()
		&"lunge":
			_advance_lunge(delta)
		&"gust":
			_apply_wind(delta)
			if clock <= 0: _finish_attack()
		&"stomp", &"platform":
			if not _release_sent and _state_age >= _state_duration * .55:
				_release_sent = true
				_foot_impact(mode == &"platform")
			_update_strike(delta)
			if clock <= 0: _finish_attack()
		&"sweep":
			_update_strike(delta)
			if clock <= 0: _finish_attack()
		&"seeds":
			if clock <= 0: _finish_attack()
		&"link":
			if clock <= 0: _begin_attack()
		&"recover":
			if clock <= 0:
				_groups_completed += 1
				_event(&"windkeeper_group_end")
				_group_plan.clear()
				if _pending_phase > stage_phase: _start_phase_transition()
				else: _select_group()
	_update_combat_shapes()
	motor.queue_redraw()

func _enter(next: StringName, duration: float) -> void:
	_pose_from = rig_pose() if _rig_ready else {}
	mode = next
	_state_age = 0.0
	_state_duration = maxf(0, duration)
	clock = _state_duration
	_motion_age = 0
	core_open = next == &"recover"
	_release_sent = false
	objective_changed.emit(objective())
	_event(&"windkeeper_state", {"state": next})

func _start_phase_transition() -> void:
	_clear_attacks()
	_group_plan.clear()
	motor.stop()
	stage_phase = _pending_phase
	transition_target = stage_phase
	_enter(&"phase_transition", _config().phase_warning_seconds)
	_event(&"windkeeper_phase_warning", {"phase": stage_phase})

func _selection_candidates() -> Array[Dictionary]:
	var dx := absf(_target.global_position.x - motor.global_position.x)
	var elevated := _target.global_position.y < _floor_y - 90
	var camping := _camp_age >= _config().camping_seconds
	var candidates: Array[Dictionary] = []
	if stage_phase == 1:
		candidates = [
			{"attacks": [&"lunge", &"stomp"], "weight": 3.3 if dx > 230 else 1.2},
			{"attacks": [&"stomp", &"seeds"], "weight": 3.0 if elevated or camping else 1.8},
			{"attacks": [&"stomp", &"stomp"], "weight": 1.8 if dx < 230 else .6},
			{"attacks": [&"stomp"], "weight": .7},
			{"attacks": [&"lunge"], "weight": .6 if dx > 220 else .18},
			{"attacks": [&"seeds"], "weight": 1.6 if elevated or camping else .4}]
	elif stage_phase == 2:
		candidates = [
			{"attacks": [&"gust", &"sweep"], "weight": 2.8},
			{"attacks": [&"lunge", &"sweep"], "weight": 3.2 if dx > 220 else 1.2},
			{"attacks": [&"sweep", &"seeds"], "weight": 3.4 if elevated or camping else 2.0},
			{"attacks": [&"stomp", &"seeds"], "weight": 1.1},
			{"attacks": [&"stomp", &"stomp"], "weight": .7}]
	else:
		candidates = [
			{"attacks": [&"platform", &"gust", &"seeds"], "weight": 3.4 if elevated or camping else 1.4},
			{"attacks": [&"seeds", &"lunge", &"platform"], "weight": 3.4 if dx > 230 else 1.6},
			{"attacks": [&"platform", &"sweep"], "weight": 2.0},
			{"attacks": [&"lunge", &"stomp", &"seeds"], "weight": 2.5 if dx > 230 else 1.0},
			{"attacks": [&"sweep", &"seeds"], "weight": 1.1},
			{"attacks": [&"stomp", &"sweep"], "weight": .8}]
	for candidate: Dictionary in candidates:
		var key := _group_key(candidate.attacks)
		var repeats := 0
		for index: int in range(_recent_groups.size() - 1, -1, -1):
			if _recent_groups[index] != key: break
			repeats += 1
		if repeats >= _config().maximum_group_repeats: candidate.weight = 0.0
		elif key in _recent_groups: candidate.weight *= _config().recent_group_penalty
	return candidates

func _group_key(attacks: Array) -> String:
	var words := PackedStringArray()
	for attack: Variant in attacks: words.append(String(attack))
	return "/".join(words)

func _select_group() -> void:
	if not active or health.terminal: return
	var candidates := _selection_candidates()
	var total := 0.0
	for candidate: Dictionary in candidates: total += float(candidate.weight)
	var choice: Dictionary = candidates[0]
	var roll := _selection_rng.randf() * total
	for candidate: Dictionary in candidates:
		roll -= float(candidate.weight)
		if roll <= 0:
			choice = candidate
			break
	var attacks: Array = choice.attacks.duplicate()
	_group_plan = {"attacks": attacks, "phase": stage_phase,
		"double_stomp": attacks.size() > 1 and attacks[0] == &"stomp" and attacks[1] == &"stomp",
		"sweep_high": _target.global_position.y < _floor_y - 90}
	sweep_high = bool(_group_plan.sweep_high)
	_attack_index = 0
	_preparation_index = -1
	_preparation_hops = 0
	_guarded_attack_index = -1
	_groups_started += 1
	_recent_groups.append(_group_key(attacks))
	while _recent_groups.size() > 3: _recent_groups.pop_front()
	_event(&"windkeeper_group", {"plan": _group_plan.duplicate(true)})
	var dx := _target.global_position.x - motor.global_position.x
	locked_direction = -1 if dx < 0 else 1
	if absf(dx) > _config().approach_range:
		_enter(&"approach", _config().approach_bound_seconds)
	elif locked_direction != direction and absf(dx) > 20:
		_enter(&"turn", _config().turn_seconds)
	else:
		_begin_attack()

func _approach(delta: float) -> void:
	if stage_phase == 3 and _supports_bound:
		_approach_on_support()
		return
	var dx := _target.global_position.x - motor.global_position.x
	var attacks: Array = _group_plan.get("attacks", [])
	var wants_platform: bool = _attack_index < attacks.size() and attacks[_attack_index] == &"platform"
	var wants_sweep: bool = _attack_index < attacks.size() and attacks[_attack_index] == &"sweep"
	var desired := _config().sweep_approach_range if wants_sweep else 160.0 if wants_platform else _config().approach_range
	if absf(dx) < desired or clock <= 0:
		motor.stop()
		_begin_attack()
		return
	direction = -1 if dx < 0 else 1
	locked_direction = direction
	var before := motor.global_position
	motor.speed = _config().final_chase_speed if stage_phase == 3 else _config().approach_speed
	motor.step(direction, minf(arena.travel_limit(motor.global_position.x, direction), maxf(0, absf(dx) - desired + 5)), delta)
	_travel += motor.global_position.distance_to(before)

func _begin_attack() -> void:
	if not active or _group_plan.is_empty(): return
	var attacks: Array = _group_plan.attacks
	if _attack_index >= attacks.size(): return
	var attack: StringName = attacks[_attack_index]
	if _preparation_index != _attack_index:
		_preparation_index = _attack_index
		_preparation_hops = 0
		_guarded_attack_index = -1
	var dx := _target.global_position.x - motor.global_position.x
	var wanted_direction := -1 if dx < -12 else 1 if dx > 12 else direction
	if wanted_direction != direction:
		locked_direction = wanted_direction
		_enter(&"turn", _config().turn_seconds)
		return
	locked_direction = direction
	locked_target = _target.global_position
	foot_index = _attack_index % 2
	# The real leaf cannot reach a ground actor from the generic ranged
	# distance. Close physically before its warning, keeping the chosen group.
	if attack == &"sweep" and absf(dx) > _config().sweep_approach_range + 4.0 and _guarded_attack_index != _attack_index:
		_enter(&"approach", _config().approach_bound_seconds)
		return
	if attack == &"platform":
		foot_index = 0
		var platform_point := _platform_for_target()
		if not platform_point.is_finite():
			_event(&"windkeeper_platform_unavailable")
			_finish_attack()
			return
		locked_target = platform_point
		# Front foot extends from the real shoulder. Approach is an explicit
		# readable part of preparation; never teleport the body to a platform.
		var gap := absf(locked_target.x - motor.global_position.x)
		if gap > 185:
			if _guarded_attack_index != _attack_index:
				_enter(&"approach", _config().approach_bound_seconds)
				return
			if stage_phase == 3 and _supports_bound and _support_valid(_support_index):
				var slab := _support_rects[_support_index]
				locked_target = Vector2(slab.end.x - 14 if direction > 0 else slab.position.x + 14, slab.position.y)
		if reward_stands.size() == 3:
			var nearest := INF
			for index: int in 3:
				var distance := reward_stands[index].distance_squared_to(locked_target)
				if distance < nearest: nearest = distance; chase_segment = index
	if attack == &"lunge" and stage_phase == 3 and _supports_bound:
		var destination := _next_support_index(_target.global_position.x, locked_direction)
		if destination < 0 or not _lock_support_hop(destination, _config().lunge_peak_speed, false):
			_event(&"windkeeper_support_unavailable")
			_finish_attack()
			return
	var duration := _config().sweep_warning_seconds if attack == &"sweep" else _config().platform_warning_seconds if attack == &"platform" else _config().normal_warning_seconds
	_enter(StringName("%s_warning" % attack), duration)
	_event(StringName("windkeeper_%s_warning" % attack), {"attack": attack, "point": locked_target, "direction": locked_direction, "double_stomp": bool(_group_plan.double_stomp)})

func _platform_for_target() -> Vector2:
	var feet := _target.global_position + Vector2(0, 18)
	var excluded: Array[RID] = [motor.get_rid()]
	if _target is CollisionObject2D: excluded.append((_target as CollisionObject2D).get_rid())
	var query := PhysicsRayQueryParameters2D.create(feet - Vector2(0, 2), feet + Vector2(0, 650), 1, excluded)
	var space := motor.get_world_2d().direct_space_state
	var result := space.intersect_ray(query)
	# phase_changed schedules the actual bridge removal for the deferred step.
	# A phase-III platform target must already be a surviving raised surface,
	# including on that first frame while the old floor is still queryable.
	if not result.is_empty():
		var point: Vector2 = result.position
		if stage_phase != 3 or point.y < _floor_y - 2.0:
			return _reachable_platform_point(point) if stage_phase == 3 and _supports_bound else point
	# Phase I/II preserve their original nearest-authored-ground fallback.
	if stage_phase != 3:
		if not reward_stands.is_empty():
			var closest := reward_stands[0] + Vector2(0, 18)
			for stand: Vector2 in reward_stands:
				var point := stand + Vector2(0, 18)
				if feet.distance_squared_to(point) < feet.distance_squared_to(closest): closest = point
			return closest
		return Vector2(motor.global_position.x, _floor_y)
	var nearest := Vector2.INF
	var nearest_distance := INF
	for stand: Vector2 in reward_stands:
		var point := stand + Vector2(0, 18)
		query = PhysicsRayQueryParameters2D.create(point - Vector2(0, 6), point + Vector2(0, 6), 1, excluded)
		var support := space.intersect_ray(query)
		if support.is_empty(): continue
		var actual: Vector2 = support.position
		var normal: Vector2 = support.normal
		if actual.y >= _floor_y - 2.0 or actual.distance_to(point) > 2.0 or normal.dot(Vector2.UP) < .7: continue
		var distance := feet.distance_squared_to(actual)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = actual
	# Invalid topology is not a reason to warn or hit invented floating ground.
	return _reachable_platform_point(nearest) if nearest.is_finite() and _supports_bound else nearest

func _release_attack() -> void:
	var attack := StringName(String(mode).trim_suffix("_warning"))
	var duration := _config().stomp_seconds
	match attack:
		&"lunge": duration = _hop_duration if stage_phase == 3 and _supports_bound and _hop_prepared else _config().lunge_seconds
		&"sweep": duration = _config().sweep_seconds
		&"gust": duration = _config().gust_seconds
		&"seeds": duration = _config().seeds_seconds
		&"platform": duration = _config().platform_seconds
	_enter(attack, duration)
	_event(&"windkeeper_attack", {"attack": attack, "point": locked_target})
	if attack == &"lunge":
		if stage_phase == 3 and _supports_bound and _hop_prepared:
			_start_prepared_hop()
			_lunge_start = _hop_start
			_lunge_distance = absf(_hop_target.x - _hop_start.x)
			_event(&"windkeeper_lunge_start", {"point": _hop_target})
			return
		_lunge_start = motor.global_position
		_lunge_distance_done = 0.0
		_lunge_distance = minf(_config().lunge_peak_speed * duration * (2.0 / 3.0), arena.travel_limit(motor.global_position.x, locked_direction))
		_hop_start = _lunge_start
		_hop_target = _lunge_start + Vector2(locked_direction * _lunge_distance, 0)
		_hop_target_index = -1
		_hop_age = 0.0
		_hop_duration = duration
		_hop_height = _config().lunge_height
		_hop_is_baseline = true
		_hop_prepared = false
		_hop_active = true
		_event(&"windkeeper_lunge_start")
	elif attack == &"seeds":
		_release_seeds()
	elif attack == &"sweep":
		_new_strike(&"sweep")
		_event(&"windkeeper_sweep_release", {"high": sweep_high})
	elif attack == &"gust":
		_event(&"windkeeper_gust_release", {"wind": Vector2(locked_direction * _config().wind_pressure_speed, 0)})

func _advance_lunge(delta: float) -> void:
	if not _hop_active:
		_finish_attack()
		return
	if _advance_support_hop(delta):
		_lunge_distance_done = absf(motor.global_position.x - _lunge_start.x)
		_event(&"windkeeper_lunge_land", {"point": motor.global_position + Vector2(0, 65)})
		_finish_attack()

func _configure_attack(shot: BossProjectile, label: StringName, aim: Vector2) -> void:
	_attack_serial += 1
	shot.configure(definition, StringName("windkeeper_%s-%s-%s" % [label, attack_epoch, _attack_serial]), aim, _target, motor)
	shot.set_meta(&"item_v5_world_entity", true)
	if shot.has_method("bind_attack"): shot.call("bind_attack", self, attack_epoch)
	_projectiles.append(shot)
	projectile_created.emit(shot)
	motor.get_parent().add_child(shot)

func _release_seeds() -> void:
	var pose := rig_pose()
	var origin: Vector2 = motor.to_global(pose.get("seed_origin", (pose.core_transform as Transform2D).origin))
	var aim := (locked_target - origin).normalized()
	if aim.length_squared() < .001: aim = Vector2(locked_direction, 0)
	for offset: float in [-_config().seed_spread, 0.0, _config().seed_spread]:
		var shot := WindkeeperPressureProjectile.new()
		_configure_attack(shot, &"seed", aim.rotated(offset))
		shot.speed = _config().seed_speed
		shot.radius = 6
		shot._shape.radius = 6
		shot.lifetime = 1.8
		shot.global_position = origin
	_event(&"windkeeper_seeds_release", {"point": origin, "target": locked_target})

func _foot_impact(platform: bool) -> void:
	var pose := rig_pose()
	var feet: Array = pose.feet
	var point := motor.to_global(feet[foot_index])
	if platform:
		_new_strike(&"platform")
		_event(&"windkeeper_platform_impact", {"point": point, "target": locked_target})
	else:
		for side: int in [-1, 1]:
			var wave := WindkeeperPressureProjectile.new()
			_configure_attack(wave, &"wave", Vector2(side, 0))
			wave.wave = true
			wave.speed = _config().ground_wave_speed
			wave.radius = _config().wave_radius
			wave._shape.radius = wave.radius
			wave.lifetime = 1.45
			wave.global_position = point + Vector2(side * (wave.radius + 3), -wave.radius - 2)
		_event(&"windkeeper_stomp_strike", {"point": point, "foot": foot_index})

func _new_strike(kind: StringName) -> void:
	if is_instance_valid(_active_strike): _active_strike.dispose()
	_active_strike = WindkeeperPressureStrike.new()
	_configure_attack(_active_strike, kind, Vector2(locked_direction, 0))
	_active_strike.lifetime = _state_duration + .05
	_update_strike_segment()

func _update_strike_segment() -> void:
	if not is_instance_valid(_active_strike) or _active_strike.spent: return
	var pose := rig_pose()
	if mode == &"sweep":
		_active_strike.set_segment(motor.to_global(pose.blade_start), motor.to_global(pose.blade_end), float(pose.get("blade_width", 14)))
	elif mode == &"platform":
		var feet: Array = pose.feet
		var point: Vector2 = motor.to_global(feet[foot_index])
		_active_strike.set_segment(point, point, float(pose.get("strike_radius", 15)) * 2)

func _update_strike(delta: float) -> void:
	if not is_instance_valid(_active_strike): return
	_update_strike_segment()
	_active_strike.advance(delta)

func _apply_wind(delta: float) -> void:
	if not _target is PlayerMotor: return
	var local := _target.global_position - motor.global_position
	if local.x * locked_direction >= -35 and absf(local.x) <= _config().wind_pressure_range and local.y > -_config().wind_pressure_height and local.y < 100:
		(_target as PlayerMotor).queue_local_velocity(Vector2(locked_direction * _config().wind_pressure_speed, 0), delta)

func _finish_attack() -> void:
	if is_instance_valid(_active_strike): _active_strike.dispose()
	_active_strike = null
	if _target is PlayerMotor: (_target as PlayerMotor).clear_local_velocity()
	motor.stop()
	_attack_index += 1
	var attacks: Array = _group_plan.get("attacks", [])
	if _attack_index < attacks.size():
		_enter(&"link", _config().combo_link_seconds)
		_event(&"windkeeper_link", {"next_attack": attacks[_attack_index]})
	else:
		# Already advertised finite seeds/waves remain real threats until they
		# hit or expire. Recovery releases no new attack, and never erases a
		# travelling projectile merely to manufacture a safe-looking window.
		_enter(&"recover", _config().group_recovery_seconds)
		_event(&"windkeeper_recover")

func _health_changed(result: ActorResourceResult) -> void:
	if result == null or result.operation != &"damage" or result.amount_applied >= 0: return
	_accepted_hits += 1
	_accepted_damage -= result.amount_applied
	if health.terminal: return
	_bell_hit_age = 0.0
	_event(&"windkeeper_hit", {"point": motor.global_position + core_offset(), "amount": -result.amount_applied})

func _on_defeat() -> void:
	if mode == &"dead": return
	_clear_attacks()
	_hop_prepared = false
	active = false
	motor.stop()
	motor.collision_layer = 0
	motor.collision_mask = 0
	_group_plan.clear()
	_death_age = 0.0
	_death_impact_sent = false
	_death_final_sent = false
	_enter(&"dead", _config().death_seconds)
	_event(&"windkeeper_death", {"point": motor.global_position + core_offset()})
	defeated.emit(self)

func _advance_death(delta: float) -> void:
	if mode != &"dead" or _death_final_sent: return
	if _hop_active:
		_advance_support_hop(delta)
		# Flight belongs to the locked takeoff/landing, while the terminal body
		# and wind are already harmless. Mechanical collapse starts on support.
		_death_age = 0.0
		_state_age = 0.0
		_update_combat_shapes()
		motor.queue_redraw()
		return
	_death_age = minf(_config().death_seconds, _death_age + delta)
	_state_age = _death_age
	clock = maxf(0, _config().death_seconds - _death_age)
	if not _death_impact_sent and _death_age >= _config().death_impact_seconds:
		_death_impact_sent = true
		_event(&"windkeeper_death_impact", {"point": motor.global_position})
	if _death_age >= _config().death_seconds:
		_death_final_sent = true
		_event(&"windkeeper_death_final", {"point": motor.global_position})
	_update_combat_shapes()
	motor.queue_redraw()

func cancel_pending_attacks() -> void:
	_clear_attacks()
	_group_plan.clear()
	motor.stop()
	if active and mode not in [&"intro", &"phase_transition"]:
		if _hop_active:
			_hop_resume = &"observe"
			_enter(&"traverse", maxf(0, _hop_duration - _hop_age))
		else:
			_hop_prepared = false
			_enter(&"observe", 0)
	_event(&"windkeeper_audio_cancel")

func cancel() -> void:
	super.cancel()
	if is_instance_valid(_active_strike): _active_strike.dispose()
	_active_strike = null
	_group_plan.clear()
	_event(&"windkeeper_audio_cancel")

func skip_intro() -> void:
	if active and mode == &"intro": _enter(&"observe", 0)

func _event(id: StringName, extra: Dictionary = {}) -> void:
	var row := {"event": id, "age": _fight_age, "state": mode, "phase": stage_phase,
		"group": _groups_started, "attack_index": _attack_index,
		"group_total": (_group_plan.get("attacks", []) as Array).size(),
		"group_remaining": maxi(0, (_group_plan.get("attacks", []) as Array).size() - _attack_index - 1),
		"position": motor.global_position if is_instance_valid(motor) else Vector2.ZERO}
	row.merge(extra, true)
	_event_history.append(row.duplicate(true))
	while _event_history.size() > 512: _event_history.pop_front()
	presentation_event.emit(row)

func rig_pose() -> Dictionary:
	var rig_mode: StringName = &"lunge_warning" if mode == &"traverse_warning" else &"lunge" if mode == &"traverse" else mode
	var flight_pose: bool = _hop_active and mode in [&"phase_transition", &"traverse", &"lunge"]
	if flight_pose: rig_mode = &"lunge"
	var pose_age := _hop_age if flight_pose else _state_age
	var pose_duration := _hop_duration if flight_pose else _state_duration
	var sampled := WindkeeperPressureRig.sample({"mode": rig_mode, "phase": stage_phase, "direction": direction,
		"state_age": pose_age, "state_duration": pose_duration, "fight_age": _fight_age,
		"travel": _travel, "speed": motor.velocity.length() if is_instance_valid(motor) else 0,
		"group_remaining": maxi(0, (_group_plan.get("attacks", []) as Array).size() - _attack_index - 1),
		"group_total": (_group_plan.get("attacks", []) as Array).size(),
		"attack_index": _attack_index,
		"combo_movement": mode in [&"traverse_warning", &"traverse"] and not _group_plan.is_empty(),
		"attack_target_local": motor.to_local(locked_target) if mode in [&"platform_warning", &"platform"] and is_instance_valid(motor) else Vector2.ZERO,
		"sweep_high": sweep_high, "death_age": _death_age, "death_duration": _config().death_seconds,
		"bell_hit_age": _bell_hit_age, "foot_index": foot_index,
		"double_stomp": bool(_group_plan.get("double_stomp", false)) and _attack_index == 0})
	if not _pose_from.is_empty() and _state_age < .10:
		sampled = WindkeeperPressureRig.blend(_pose_from, sampled, clampf(_state_age / .10, 0, 1))
	return _supported_pose(sampled)

func _update_combat_shapes() -> void:
	if not _rig_ready or not is_instance_valid(_core): return
	var pose := rig_pose()
	var hull := motor.get_node("CollisionShape2D") as CollisionShape2D
	(hull.shape as ConvexPolygonShape2D).points = pose.body_shape_points
	(_head_shape.shape as ConvexPolygonShape2D).points = pose.head_shape_points
	var feet: Array = pose.feet
	for index: int in 4:
		_foot_shapes[index].position = feet[index]
		(_foot_shapes[index].shape as CircleShape2D).radius = float(pose.get("foot_radius", 12))
	var hips: Array = pose.hips
	var knees: Array = pose.knees
	for index: int in 8:
		var leg := index >> 1
		var a: Vector2 = hips[leg] if index % 2 == 0 else knees[leg]
		var b: Vector2 = knees[leg] if index % 2 == 0 else feet[leg]
		var limb := _limb_shapes[index]
		var capsule := limb.shape as CapsuleShape2D
		capsule.radius = 5.0
		capsule.height = maxf(10, a.distance_to(b) + 10)
		limb.transform = Transform2D((b - a).angle() - PI * .5, (a + b) * .5)
	_core.transform = pose.core_transform
	var core_shape := _core.get_child(0) as CollisionShape2D
	(core_shape.shape as CircleShape2D).radius = float(pose.get("core_radius", 18))
	_core.collision_layer = 4 if accepts_combat_damage() else 0
	motor.collision_layer = 4 if accepts_combat_damage() else 0

func core_offset() -> Vector2:
	if not is_instance_valid(motor) or _config() == null: return Vector2(48, -46)
	return (rig_pose().core_transform as Transform2D).origin

func body_contact_rect() -> Rect2:
	if not _rig_ready: return super.body_contact_rect()
	var shape := motor.get_node("CollisionShape2D") as CollisionShape2D
	var bounds := shape.global_transform * shape.shape.get_rect()
	for part: CollisionShape2D in _contact_parts():
		bounds = bounds.merge(part.global_transform * part.shape.get_rect())
	return bounds

func _contact_parts() -> Array[CollisionShape2D]:
	var parts: Array[CollisionShape2D] = [_head_shape]
	parts.append_array(_foot_shapes)
	parts.append_array(_limb_shapes)
	if is_instance_valid(_core): parts.append(_core.get_child(0) as CollisionShape2D)
	return parts

func body_contact_sweep(source_center: Vector2, previous_relative: Vector2, current_world: Vector2, actor_half: Vector2) -> bool:
	if not body_contact_enabled() or not _rig_ready or not source_center.is_finite() or not previous_relative.is_finite() or not current_world.is_finite() or not actor_half.is_finite() or actor_half.x <= 0 or actor_half.y <= 0: return false
	_contact_actor.size = actor_half * 2
	var start := source_center + previous_relative
	var transform := Transform2D(0, start)
	var motion := current_world - start
	var hull := motor.get_node("CollisionShape2D") as CollisionShape2D
	if _contact_actor.collide_with_motion(transform, motion, hull.shape, hull.global_transform, Vector2.ZERO): return true
	for part: CollisionShape2D in _contact_parts():
		if _contact_actor.collide_with_motion(transform, motion, part.shape, part.global_transform, Vector2.ZERO): return true
	return false

func body_contact_enabled() -> bool:
	return active and not health.terminal and mode != &"intro"

func objective() -> String:
	if mode == &"intro": return "牧风者 / THE WINDKEEPER"
	if mode == &"dead": return "风停铃息 / WINDKEEPER SILENCED"
	if mode == &"phase_transition": return "风帆展开，先找下一处落脚点 / FIND YOUR NEXT LANDING"
	if mode == &"recover": return "整组收招，反击后及时撤离 / COUNTER THEN RETREAT"
	if mode == &"link": return "还没打完，观察下一次发力 / COMBO CONTINUES"
	return "观察四足与风帆，持续换位 / READ THE LIMBS AND SAILS"

func presentation_state() -> BossPresentationState:
	var values := _presentation_values()
	values.merge({"phase": stage_phase, "phase_axes": {"combat": stage_phase}, "damage_model": &"continuous_body", "core_hint_visible": mode == &"recover"}, true)
	return _presentation_countdown(values, mode, clock, _state_duration,
		String(mode).ends_with("_warning") or mode == &"phase_transition",
		mode in [&"stomp", &"seeds", &"platform"], mode in [&"lunge", &"traverse", &"sweep", &"gust"], mode == &"recover")

func presentation_core() -> Dictionary:
	return {"visible": mode == &"recover", "offset": core_offset(), "raw_clock": clock,
		"remaining_fraction": clampf(clock / maxf(.01, _config().group_recovery_seconds), 0, 1), "continuous_combat": true}

func presentation_blades() -> Dictionary:
	var pose := rig_pose()
	return {"active": mode == &"sweep", "start": pose.blade_start, "end": pose.blade_end, "angle": blade_angle}

func presentation_locked_aim() -> Dictionary:
	return {"position": locked_target} if mode == &"platform_warning" else {}

func presentation_rune_cue() -> Dictionary:
	return {}

func combat_metrics() -> Dictionary:
	return {"accepted_hits": _accepted_hits, "accepted_damage": _accepted_damage,
		"effective_hits": _accepted_hits, "groups_started": _groups_started, "groups_completed": _groups_completed,
		"group_plan": _group_plan.duplicate(true), "attack_index": _attack_index,
		"state_age": _state_age, "state_duration": _state_duration, "fight_seconds": _fight_age,
		"death_age": _death_age, "locked_target": locked_target, "locked_direction": locked_direction,
		"sweep_high": sweep_high, "camp_age": _camp_age,
		"supports_bound": _supports_bound, "support_verified": _standing_on_support(),
		"support_rect": _support_rects[_support_index] if _support_index >= 0 and _support_index < _support_rects.size() else Rect2(),
		"airborne": _hop_active, "locked_hop_target": _hop_target,
		"hop_target_rect": _support_rects[_hop_target_index] if _hop_target_index >= 0 and _hop_target_index < _support_rects.size() else Rect2()}

func combat_snapshot() -> Dictionary:
	var result := super.combat_snapshot()
	result["pressure"] = {"group": _group_plan.duplicate(true), "index": _attack_index,
		"age": _state_age, "duration": _state_duration, "fight_age": _fight_age, "travel": _travel,
		"death_age": _death_age, "death_impact_sent": _death_impact_sent, "death_final_sent": _death_final_sent,
		"physical_reward_expected": physical_reward_expected, "bridge_released": _bridge_released,
		"support_motion": {"index": _support_index, "active": _hop_active, "prepared": _hop_prepared,
			"baseline": _hop_is_baseline, "start": [_hop_start.x, _hop_start.y], "target": [_hop_target.x, _hop_target.y],
			"target_index": _hop_target_index, "age": _hop_age, "duration": _hop_duration, "height": _hop_height,
			"resume": String(_hop_resume), "preparation_index": _preparation_index,
			"preparation_hops": _preparation_hops, "guarded_attack_index": _guarded_attack_index},
		"rng": str(_selection_rng.state), "recent": _recent_groups.duplicate(),
		"groups_started": _groups_started, "groups_completed": _groups_completed,
		"accepted_hits": _accepted_hits, "accepted_damage": _accepted_damage,
		"locked_target": [locked_target.x, locked_target.y], "locked_direction": locked_direction,
		"sweep_high": sweep_high, "foot_index": foot_index, "release_sent": _release_sent,
		"lunge_start": [_lunge_start.x, _lunge_start.y], "lunge_distance": _lunge_distance,
		"camp_age": _camp_age, "camp_origin": [_camp_origin.x, _camp_origin.y]}
	return result

func restore_combat_state(data: Dictionary) -> void:
	_pose_from.clear()
	_clear_attacks()
	super.restore_combat_state(data)
	if not data.has("pressure"):
		_restore_legacy_combat_state()
		return
	var saved: Dictionary = data.get("pressure", {})
	physical_reward_expected = bool(saved.get("physical_reward_expected", true))
	_group_plan = (saved.get("group", {}) as Dictionary).duplicate(true)
	_attack_index = int(saved.get("index", 0))
	_state_age = float(saved.get("age", 0))
	_state_duration = float(saved.get("duration", clock + _state_age))
	_fight_age = float(saved.get("fight_age", 0))
	_travel = float(saved.get("travel", 0))
	_death_age = float(saved.get("death_age", 0))
	_death_impact_sent = bool(saved.get("death_impact_sent", false))
	_death_final_sent = bool(saved.get("death_final_sent", false))
	_selection_rng.state = int(String(saved.get("rng", str(_selection_rng.state))))
	_recent_groups.assign(saved.get("recent", []))
	_groups_started = int(saved.get("groups_started", 0))
	_groups_completed = int(saved.get("groups_completed", 0))
	_accepted_hits = int(saved.get("accepted_hits", 0))
	_accepted_damage = float(saved.get("accepted_damage", 0))
	var point: Array = saved.get("locked_target", [motor.global_position.x, motor.global_position.y])
	locked_target = Vector2(point[0], point[1])
	locked_direction = int(saved.get("locked_direction", direction))
	sweep_high = bool(saved.get("sweep_high", false))
	foot_index = int(saved.get("foot_index", 0))
	_release_sent = bool(saved.get("release_sent", false))
	point = saved.get("lunge_start", [motor.global_position.x, motor.global_position.y])
	_lunge_start = Vector2(point[0], point[1])
	_lunge_distance = float(saved.get("lunge_distance", 0))
	_camp_age = float(saved.get("camp_age", 0))
	point = saved.get("camp_origin", [motor.global_position.x, motor.global_position.y])
	_camp_origin = Vector2(point[0], point[1])
	var motion: Dictionary = saved.get("support_motion", {})
	_bridge_released = bool(saved.get("bridge_released", false))
	_support_index = int(motion.get("index", -1))
	_hop_active = bool(motion.get("active", false))
	_hop_prepared = bool(motion.get("prepared", false))
	_hop_is_baseline = bool(motion.get("baseline", false))
	point = motion.get("start", [_lunge_start.x, _lunge_start.y])
	_hop_start = Vector2(point[0], point[1])
	point = motion.get("target", [_lunge_start.x + locked_direction * _lunge_distance, _lunge_start.y])
	_hop_target = Vector2(point[0], point[1])
	_hop_target_index = int(motion.get("target_index", -1))
	_hop_age = float(motion.get("age", _state_age))
	_hop_duration = float(motion.get("duration", _state_duration))
	_hop_height = float(motion.get("height", _config().lunge_height))
	_hop_resume = StringName(motion.get("resume", "approach"))
	_preparation_index = int(motion.get("preparation_index", _attack_index))
	_preparation_hops = int(motion.get("preparation_hops", 0))
	_guarded_attack_index = int(motion.get("guarded_attack_index", -1))
	# Pre-support pressure candidates did not persist flight ownership. A
	# baseline lunge still resumes its original unchanged ground trajectory.
	if motion.is_empty() and mode == &"lunge" and stage_phase < 3:
		_hop_active = true
		_hop_is_baseline = true
	if stage_phase == 3 and _supports_bound and not _bridge_released and motion.is_empty() and not health.terminal:
		mode = &"phase_transition"
		_state_age = 0.0
		_state_duration = _config().phase_warning_seconds
		clock = _state_duration
	# Projectiles belong to the old stage/attack epoch and are never recreated.
	# A saved execute pose completes without replaying its release event.
	if mode in [&"sweep", &"platform"]: _release_sent = true
	_update_combat_shapes()


func _restore_legacy_combat_state() -> void:
	# A v5 state has no immutable six-move group to continue. Preserve the
	# authoritative HP/stage/position and current activation, cancel old
	# transient attacks, then choose a new fully advertised group. Old charge,
	# blades/chase/pier clocks must never strand the new state machine.
	_group_plan.clear()
	_hop_active = false
	_hop_prepared = false
	_hop_is_baseline = false
	_bridge_released = false
	_support_index = -1
	_attack_index = 0
	_state_age = 0.0
	_state_duration = 0.0
	clock = 0.0
	_fight_age = 0.0
	_travel = 0.0
	_groups_started = 0
	_groups_completed = 0
	_accepted_hits = 0
	_accepted_damage = 0.0
	_recent_groups.clear()
	_release_sent = false
	_pending_phase = stage_phase
	locked_direction = direction
	locked_target = _target.global_position if is_instance_valid(_target) else motor.global_position
	_lunge_start = motor.global_position
	_lunge_distance = 0.0
	_lunge_distance_done = 0.0
	_camp_origin = locked_target
	_camp_age = 0.0
	_bell_hit_age = -1.0
	core_open = false
	motor.stop()
	physical_reward_expected = not health.terminal
	if health.terminal:
		# Already-dead legacy bosses remain settled, quiet and harmless. Do
		# not replay a new death impact or mint this revision's physical coins.
		active = false
		mode = &"dead"
		_death_age = _config().death_seconds
		_state_age = _death_age
		_state_duration = _death_age
		_death_impact_sent = true
		_death_final_sent = true
		motor.collision_layer = 0
		motor.collision_mask = 0
	else:
		mode = &"phase_transition" if stage_phase == 3 and _supports_bound else &"observe"
		if mode == &"phase_transition":
			_state_duration = _config().phase_warning_seconds
			clock = _state_duration
		_death_age = 0.0
		_death_impact_sent = false
		_death_final_sent = false
	_update_combat_shapes()


func bind_stage_geometry(owner_module: PlatformingModule, controller: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, segment: SegmentRespawn, supports: PlainsGroundSupports = null) -> WindkeeperArena:
	var consumer := super.bind_stage_geometry(owner_module, controller, policy, lifetime, segment, supports)
	_supports_bound = true
	_support_rects.clear()
	_support_index = -1
	var stance := _stance_half_width()
	for index: int in owner_module.definition.one_way_platform_indices:
		var slab: Rect2 = owner_module.definition.platforms[index]
		var world_slab: Rect2 = owner_module.global_transform * slab
		if world_slab.size.x >= stance * 2.0: _support_rects.append(world_slab)
	_support_rects.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	return consumer

# Restored phase three can still be landing on its first real shelf. Restore
# the actual release flag, after terminal binding or active combat restoration.
func restore_bridge_geometry() -> void:
	if not bridge_break_ready(): return
	for child: Node in get_children():
		if child is WindkeeperArena: (child as WindkeeperArena).restore_broken_bridge()

func bridge_break_ready() -> bool:
	return _bridge_released

func _stance_half_width() -> float:
	var pose := WindkeeperPressureRig.sample({"mode": &"observe", "phase": 3, "direction": 1})
	var width := 0.0
	for foot: Vector2 in pose.feet: width = maxf(width, absf(foot.x))
	return width + float(pose.foot_radius)

func _support_valid(index: int) -> bool:
	if index < 0 or index >= _support_rects.size() or not motor.is_inside_tree(): return false
	var slab := _support_rects[index]
	var stance := _stance_half_width()
	var centre := slab.get_center().x
	var excluded: Array[RID] = [motor.get_rid()]
	if _target is CollisionObject2D: excluded.append((_target as CollisionObject2D).get_rid())
	for offset: float in [-stance, 0.0, stance]:
		var point := Vector2(centre + offset, slab.position.y)
		var query := PhysicsRayQueryParameters2D.create(point - Vector2(0, 6), point + Vector2(0, 6), 1, excluded)
		var hit := motor.get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): return false
		var actual: Vector2 = hit.position
		var normal: Vector2 = hit.normal
		if actual.distance_to(point) > 2 or normal.dot(Vector2.UP) < .7: return false
	return true

func _nearest_support_index(world_x: float) -> int:
	var best := -1
	var distance := INF
	for index: int in _support_rects.size():
		if not _support_valid(index): continue
		var current := absf(_support_rects[index].get_center().x - world_x)
		if current < distance: best = index; distance = current
	return best

func _standing_on_support() -> bool:
	if _hop_active or not _support_valid(_support_index): return false
	var slab := _support_rects[_support_index]
	var stance := _stance_half_width()
	return absf(motor.global_position.y + 65 - slab.position.y) <= .75 and motor.global_position.x - stance >= slab.position.x - .5 and motor.global_position.x + stance <= slab.end.x + .5

func _lock_support_hop(index: int, speed_limit: float, start_immediately: bool = true) -> bool:
	if not _support_valid(index): return false
	var slab := _support_rects[index]
	_hop_start = motor.global_position
	_hop_target = Vector2(slab.get_center().x, slab.position.y - 65)
	_hop_target_index = index
	_hop_age = 0.0
	var displacement := _hop_target - _hop_start
	_hop_height = maxf(_config().lunge_height, absf(displacement.y) * .55)
	# P(p)=start+D*p+(0,-4h*p*(1-p)). Its derivative is affine;
	# the maximum vector speed is exactly bounded by the two endpoint norms.
	var peak := maxf((displacement + Vector2(0, -4 * _hop_height)).length(), (displacement + Vector2(0, 4 * _hop_height)).length())
	_hop_duration = maxf(.25, peak / maxf(1, speed_limit))
	_hop_is_baseline = false
	_hop_prepared = true
	_hop_active = false
	if start_immediately: _start_prepared_hop()
	return true

func _start_prepared_hop() -> void:
	_hop_prepared = false
	_hop_active = true
	_hop_age = 0.0
	_event(&"windkeeper_support_jump", {"point": _hop_target, "duration": _hop_duration})

func _advance_support_hop(delta: float) -> bool:
	if not _hop_active: return false
	_hop_age = minf(_hop_duration, _hop_age + delta)
	var progress := clampf(_hop_age / maxf(.01, _hop_duration), 0, 1)
	var desired := _hop_start.lerp(_hop_target, progress) + Vector2(0, -4 * _hop_height * progress * (1 - progress))
	if _hop_is_baseline:
		var eased := progress * progress * (3 - 2 * progress)
		desired = _hop_start.lerp(_hop_target, eased) + Vector2(0, -sin(progress * PI) * _hop_height)
	var before := motor.global_position
	motor.move_and_collide(desired - before)
	motor.velocity = (motor.global_position - before) / delta
	_travel += absf(motor.global_position.x - before.x)
	if progress < 1: return false
	_hop_active = false
	_support_index = _hop_target_index
	motor.stop()
	_event(&"windkeeper_support_landed", {"point": motor.global_position, "support": _support_index})
	return _hop_is_baseline or _standing_on_support()

func _next_support_index(toward_x: float, fixed_direction: int = 0) -> int:
	var current := _support_index
	if current < 0: current = _nearest_support_index(motor.global_position.x)
	if current < 0: return -1
	if fixed_direction != 0:
		var next := clampi(current + fixed_direction, 0, _support_rects.size() - 1)
		return next if _support_valid(next) else current
	var target_index := _nearest_support_index(toward_x)
	if target_index < 0: return current
	var next := current + int(signi(target_index - current))
	return next if _support_valid(next) else current

func _approach_on_support() -> void:
	if _preparation_index != _attack_index:
		_preparation_index = _attack_index
		_preparation_hops = 0
		_guarded_attack_index = -1
	if not _standing_on_support():
		# An imported pre-support active state receives the same visible mount
		# transition as a fresh phase change, never an invisible replacement floor.
		_enter(&"phase_transition", _config().phase_warning_seconds)
		return
	var next := _next_support_index(_target.global_position.x)
	if next < 0:
		_event(&"windkeeper_support_unavailable")
		return
	# Pursuit is finite even against a player crossing back and forth forever.
	# The completed preparation then guards its real current platform, rather
	# than inventing a longer blade or sliding across a void to force a hit.
	if next == _support_index or _preparation_hops >= maxi(1, _support_rects.size() - 1):
		_guarded_attack_index = _attack_index
		_event(&"windkeeper_platform_guard", {"point": motor.global_position})
		_begin_attack()
		return
	if not _lock_support_hop(next, _config().final_chase_speed, false): return
	_preparation_hops += 1
	_hop_resume = &"approach"
	locked_direction = -1 if _hop_target.x < _hop_start.x else 1
	direction = locked_direction
	_enter(&"traverse_warning", _config().traverse_warning_seconds)
	_event(&"windkeeper_traverse_warning", {"point": _hop_target})
	_event(&"windkeeper_lunge_warning", {"point": _hop_target, "movement_only": true})

func _reachable_platform_point(point: Vector2) -> Vector2:
	if not point.is_finite(): return point
	for index: int in _support_rects.size():
		var slab := _support_rects[index]
		if absf(point.y - slab.position.y) > 2 or point.x < slab.position.x or point.x > slab.end.x: continue
		# An adjacent platform's near side can be reached without standing the
		# guardian over the intervening gap. Lock it before the warning starts.
		var near_x := clampf(motor.global_position.x, slab.position.x + 14, slab.end.x - 14)
		if absf(near_x - motor.global_position.x) <= 185 and _support_valid(index):
			return Vector2(near_x, slab.position.y)
	return point

func _supported_pose(pose: Dictionary) -> Dictionary:
	if stage_phase != 3 or not _supports_bound or not _standing_on_support(): return pose
	var slab := _support_rects[_support_index]
	var radius := float(pose.get("foot_radius", 12))
	var low := slab.position.x + radius - motor.global_position.x
	var high := slab.end.x - radius - motor.global_position.x
	var feet: Array = pose.feet
	var knees: Array = pose.knees
	for index: int in 4:
		if index == 0 and mode in [&"platform_warning", &"platform"]: continue
		var foot: Vector2 = feet[index]
		var old_x := foot.x
		foot.x = clampf(foot.x, low, high)
		feet[index] = foot
		var knee: Vector2 = knees[index]
		knee.x += (foot.x - old_x) * .54
		knees[index] = knee
	pose.feet = feet
	pose.knees = knees
	pose["support_rect"] = slab
	return pose

func reward_stand_position() -> Vector2:
	if stage_phase == 3 and _supports_bound and _support_valid(_support_index):
		var slab := _support_rects[_support_index]
		return Vector2(slab.get_center().x, slab.position.y - 18)
	return super.reward_stand_position()
