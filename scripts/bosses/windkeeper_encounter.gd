class_name WindkeeperEncounter
extends BossEncounter
## Fixed safe core, local attack clock, three distinct actual patterns.
signal objective_changed(text: String)
signal armour_hit(point: Vector2)
var stage_phase := 1
var mode: StringName = &"observe"
var core_open := false
var clock := 0.0
var blade_angle := 0.0
var chase_segment := 0
var attack_epoch := 0
var _floor_y := 0.0
var _home_x := 0.0
var _stomp_next := true
var _core: Area2D
var _core_receiver: WindkeeperDamageable
var _blade_last_hit := -1
var _phase_cycle := 0
var transition_target := 1
var intro_seen := false
var reward_stands: Array[Vector2] = []

func _ready() -> void:
	super._ready()
	motor.collision_layer = 4
	# Giant remains behind walkable bridge planes; attacks have their own shapes.
	# Arena travel limits bound its scripted horizontal locomotion.
	motor.collision_mask = 0
	(motor.get_node("Damageable") as WindkeeperDamageable).encounter = self
	_core = Area2D.new()
	_core.name = "BellCore"
	_core.collision_layer = 0
	_core.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18
	shape.shape = circle
	_core.add_child(shape)
	_core_receiver = WindkeeperDamageable.new()
	_core_receiver.name = "Damageable"
	_core_receiver.encounter = self
	_core_receiver.primary = damageable
	_core_receiver.faction = &"enemy"
	_core_receiver.actor_id = damageable.actor_id
	_core.add_child(_core_receiver)
	motor.add_child.call_deferred(_core)
	_core_receiver.bind_health(health)

func configure_arena(left: float, right: float, target: Node2D) -> bool:
	if not super.configure_arena(left, right, target): return false
	_floor_y = motor.global_position.y + 65
	_home_x = (left + right) / 2
	return true

func activate() -> bool:
	if not super.activate(): return false
	_enter(&"intro", (definition as WindkeeperDefinition).repeat_intro_seconds if intro_seen else (definition as WindkeeperDefinition).intro_seconds)
	intro_seen = true
	return true

func physics_tick(delta: float) -> void:
	_prune_attacks()
	if not active or health.terminal or delta <= 0 or not is_finite(delta): return
	var wanted := 3 if health.current <= health.capacity * (definition as WindkeeperDefinition).phase_three_health else (2 if health.current <= health.capacity * (definition as WindkeeperDefinition).phase_two_health else 1)
	if wanted != stage_phase and mode != &"phase_transition":
		_clear_attacks()
		transition_target = wanted
		stage_phase = wanted
		chase_segment = 0
		motor.stop()
		_enter(&"phase_transition", (definition as WindkeeperDefinition).phase_warning_seconds)
	clock -= delta
	if mode == &"intro":
		if clock <= 0: _enter(&"observe", 1.0)
	elif mode == &"phase_transition":
		if clock <= 0:
			var destination := arena.left_x + 95 if transition_target == 3 else _home_x
			var distance := destination - motor.global_position.x
			motor.speed = (definition as WindkeeperDefinition).chase_speed
			motor.step(1 if distance > 0 else -1, absf(distance), delta)
			# Wait for a genuine safe shelf or shore before withdrawing the floor.
			var safe := _target.global_position.y <= _floor_y - 130 or _target.global_position.x < arena.left_x + 165 or _target.global_position.x > arena.right_x + 5
			if absf(distance) < 2 and (transition_target != 3 or safe):
				phase_changed.emit(stage_phase)
				_enter(&"observe", 1.2)
	elif stage_phase == 1: _ground_pattern(delta)
	elif stage_phase == 2: _wind_pattern(delta)
	else: _chase_pattern(delta)
	_core.position = core_offset()
	_core.collision_layer = 4 if core_open else 0
	motor.collision_layer = 0 if core_open or mode in [&"intro", &"phase_transition"] else 4
	motor.queue_redraw()

func _enter(next: StringName, duration: float) -> void:
	mode = next
	clock = duration
	core_open = next in [&"neck", &"back", &"pier_open"]
	objective_changed.emit(objective())

func objective() -> String:
	if mode == &"intro": return (definition as WindkeeperDefinition).display_name
	if mode == &"phase_transition": return "BRIDGE CRACKING — CLIMB TO THE GRASS SHELVES" if stage_phase == 3 else "WINDMILL AWAKENING — WATCH THE BACK BELL"
	if stage_phase == 1: return "跳过地波，等颈铃发光再射击 / SHOOT NECK BELL"
	if stage_phase == 2: return "先上草台，避开平台挡弹 / CLIMB & SHOOT BACK BELL"
	return "跨桥墩，落击后转身射铃芯 / SHOOT EXPOSED BELL"

func core_offset() -> Vector2:
	return Vector2(0, -80) if stage_phase == 2 else Vector2(direction * 65, -88 if stage_phase == 3 else -8)

func _ground_pattern(delta: float) -> void:
	var config := definition as WindkeeperDefinition
	if mode == &"observe" and clock <= 0:
		direction = -1 if _target.global_position.x < motor.global_position.x else 1
		_enter(&"stomp_warning" if _stomp_next else &"charge_warning", config.warning_seconds)
	elif mode == &"stomp_warning" and clock <= 0:
		_wave(-1); _wave(1)
		_stomp_next = false
		_enter(&"stomp", 0.2)
	elif mode == &"stomp" and clock <= 0:
		_enter(&"observe", 1.4)
	elif mode == &"charge_warning" and clock <= 0:
		motor.speed = config.charge_speed
		_enter(&"charge", 1.0)
	elif mode == &"charge":
		var limit := arena.travel_limit(motor.global_position.x, direction)
		motor.step(direction, limit, delta)
		if clock <= 0 or limit < 2:
			_enter(&"neck", config.exposed_seconds)
	elif mode == &"neck" and clock <= 0:
		_stomp_next = true
		_enter(&"observe", 1.3)

func _wave(side: int) -> void:
	_prune_attacks()
	_attack_serial += 1
	var projectile := BossProjectile.new()
	projectile.configure(definition, StringName("windkeeper-%s-%s" % [attack_epoch, _attack_serial]), Vector2(side, 0), _target, motor)
	projectile.speed = (definition as WindkeeperDefinition).stomp_speed
	_projectiles.append(projectile)
	projectile_created.emit(projectile)
	motor.get_parent().add_child(projectile)
	projectile.global_position = Vector2(motor.global_position.x + side * 85, _floor_y - 12)

func _wind_pattern(delta: float) -> void:
	var config := definition as WindkeeperDefinition
	if mode == &"observe" and clock <= 0:
		_enter(&"blade_warning", config.warning_seconds)
	elif mode == &"blade_warning" and clock <= 0:
		blade_angle = -PI / 2
		_blade_last_hit = -1
		_enter(&"blades", config.blade_period)
	elif mode == &"blades":
		var previous_angle := blade_angle
		blade_angle += TAU * delta / config.blade_period
		var wind_region := Rect2(Vector2(_home_x - 110, _floor_y - 220), Vector2(220, 145))
		if _target is PlayerMotor and wind_region.has_point(_target.global_position):
			(_target as PlayerMotor).queue_local_velocity(config.wind_velocity, delta)
		if _blade_sweeps_target(previous_angle, blade_angle) and _blade_last_hit != _phase_cycle:
			_blade_last_hit = _phase_cycle
			# Real swept projectile enters the same local FrameDamagePolicy consumer.
			_attack_serial += 1
			var hit := BossProjectile.new()
			hit.configure(definition, StringName("windblade-%s-%s" % [attack_epoch, _attack_serial]), Vector2.DOWN, _target, motor)
			hit.radius = 15
			hit._shape.radius = 15
			hit.speed = 40
			hit.lifetime = 0.15
			_projectiles.append(hit)
			projectile_created.emit(hit)
			motor.get_parent().add_child(hit)
			hit.global_position = _target.global_position
		if clock <= 0:
			_phase_cycle += 1
			_enter(&"back", config.exposed_seconds)
	elif mode == &"back" and clock <= 0: _enter(&"observe", 1.0)

func _chase_pattern(delta: float) -> void:
	var config := definition as WindkeeperDefinition
	var piers := [arena.left_x + 245, arena.left_x + 510, arena.right_x - 85]
	if mode == &"observe" and clock <= 0:
		direction = 1
		motor.speed = config.chase_speed
		_enter(&"chase", 8.0)
	elif mode == &"chase":
		var stop := float(piers[chase_segment])
		motor.step(1, maxf(0, stop - motor.global_position.x), delta)
		if motor.global_position.x >= stop - 2 or clock <= 0:
			motor.stop()
			_enter(&"pier_warning", config.pier_warning_seconds)
	elif mode == &"pier_warning" and clock <= 0:
		_enter(&"pier_impact", config.pier_impact_seconds)
		# Only the horn-sized contact volume can hurt; never the entire artwork.
		_attack_serial += 1
		var hit := BossProjectile.new()
		hit.configure(definition, StringName("pier-%s-%s" % [attack_epoch, _attack_serial]), Vector2(direction, 0), _target, motor)
		hit.radius = 12
		hit._shape.radius = 12
		hit.speed = 0
		hit.lifetime = config.pier_impact_seconds
		_projectiles.append(hit)
		projectile_created.emit(hit)
		motor.get_parent().add_child(hit)
		hit.global_position = motor.global_position + Vector2(direction * 65, -8)
	elif mode == &"pier_impact" and clock <= 0:
		_enter(&"pier_open", config.exposed_seconds + 1.0)
	elif mode == &"pier_open" and clock <= 0:
		_enter(&"final_hold" if chase_segment == 2 else &"next_pier", config.pier_recovery_seconds)
	elif mode == &"next_pier" and clock <= 0:
		chase_segment += 1
		_enter(&"observe", 1.0)
	elif mode == &"final_hold" and clock <= 0:
		_enter(&"pier_warning", config.pier_warning_seconds)

func _clear_attacks() -> void:
	attack_epoch += 1
	_prune_attacks()
	_cancel_projectiles()
	core_open = false
	if is_instance_valid(_core): _core.collision_layer = 0
	if _target is PlayerMotor: (_target as PlayerMotor).clear_local_velocity()

func cancel_pending_attacks() -> void:
	_clear_attacks()
	motor.stop()
	if active and mode not in [&"intro", &"phase_transition"]:
		_enter(&"pier_warning" if stage_phase == 3 and mode in [&"pier_warning", &"pier_impact", &"pier_open", &"final_hold"] else &"observe", 1.2)

func skip_intro() -> void:
	if active and mode == &"intro": _enter(&"observe", 1.0)

func cancel() -> void:
	_clear_attacks()
	super.cancel()

# Sweep all four thick leaf segments through their angular travel. Sampling is
# bounded by 0.035 rad (~4px at tip), including both previous and current angles.
func _blade_sweeps_target(previous: float, current: float) -> bool:
	var hub := motor.global_position + Vector2(0,-75)
	var target_shape := _target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if target_shape == null or target_shape.shape == null: return false
	var target_rect := target_shape.shape.get_rect()
	target_rect.position += target_shape.global_position
	target_rect = target_rect.grow(12)
	var samples := maxi(1, ceili(absf(current - previous) / 0.035))
	for sample: int in samples + 1:
		var angle := lerpf(previous,current,float(sample)/samples)
		for arm: int in 4:
			var start := hub + Vector2.from_angle(angle + arm * PI/2) * 15
			var end := hub + Vector2.from_angle(angle + arm * PI/2) * 115
			if target_rect.has_point(start) or target_rect.has_point(end): return true
			var corners := [target_rect.position,Vector2(target_rect.end.x,target_rect.position.y),target_rect.end,Vector2(target_rect.position.x,target_rect.end.y)]
			for edge: int in 4:
				if Geometry2D.segment_intersects_segment(start,end,corners[edge],corners[(edge+1)%4]) != null: return true
	return false

func _prune_attacks() -> void:
	var kept: Array[BossProjectile] = []
	for index: int in _projectiles.size():
		var candidate: Variant = _projectiles[index]
		if is_instance_valid(candidate) and not candidate.spent: kept.append(candidate)
	_projectiles = kept

func bind_stage_geometry(owner_module: PlatformingModule, controller: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, segment: SegmentRespawn, supports: PlainsGroundSupports = null) -> WindkeeperArena:
	var consumer := WindkeeperArena.new()
	add_child(consumer)
	consumer.setup(owner_module,self,controller,policy,lifetime,segment,supports)
	reward_stands.assign([owner_module.to_global(Vector2(350,452)),owner_module.to_global(Vector2(640,452)),owner_module.to_global(Vector2(870,452))])
	return consumer

func reward_stand_position() -> Vector2:
	var x := _home_x
	if stage_phase == 3 and reward_stands.size() == 3: return reward_stands[clampi(chase_segment,0,2)]
	return Vector2(x,_floor_y - 148 if stage_phase == 3 else _floor_y - 18)
