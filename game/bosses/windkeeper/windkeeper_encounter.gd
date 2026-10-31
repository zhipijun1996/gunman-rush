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
var _pier_direction := 1
var _platform_piers:Array[float]=[]
var rune_platform := -1
var _rune_shots:Dictionary={}
var _home_x := 0.0
var _stomp_next := true
var _core: Area2D
var _core_receiver: WindkeeperDamageable
var _contact_shape: CollisionShape2D
var _blade_last_hit := -1
var _phase_cycle := 0
var _storm_fired := false
var _locked_aim := Vector2.ZERO
var _motion_age := 0.0
var transition_target := 1
var intro_seen := false
var intro_duration := 0.0
var reward_stands: Array[Vector2] = []

func continuous_combat() -> bool:
	return (definition as WindkeeperDefinition).continuous_combat

func accepts_combat_damage() -> bool:
	return active and not health.terminal and mode != &"intro"

# World bounds used by actual contact consumers; artwork never defines damage.
func body_contact_rect() -> Rect2:
	var shape := _contact_shape if is_instance_valid(_contact_shape) else motor.get_node("CollisionShape2D") as CollisionShape2D
	return shape.global_transform * shape.shape.get_rect()

func _update_combat_shapes() -> void:
	_core.position = core_offset()
	_core.collision_layer = 4 if accepts_combat_damage() and (continuous_combat() or core_open) else 0
	# Continuous fights retain a shootable body through attacks and recovery.
	# Body contact eligibility is a separate accepted encounter state.
	motor.collision_layer = (4 if accepts_combat_damage() else 0) if continuous_combat() else (0 if core_open or mode in [&"intro", &"phase_transition"] else 4)

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
	var config := definition as WindkeeperDefinition
	if continuous_combat() and config.contact_size != Vector2.ZERO:
		var volume := Area2D.new()
		volume.name = "BodyContactVolume"
		volume.collision_layer = 0
		volume.collision_mask = 0
		_contact_shape = CollisionShape2D.new()
		_contact_shape.position = config.contact_offset
		var rect := RectangleShape2D.new()
		rect.size = config.contact_size
		_contact_shape.shape = rect
		volume.add_child(_contact_shape)
		motor.add_child.call_deferred(volume)

func configure_arena(left: float, right: float, target: Node2D) -> bool:
	if not super.configure_arena(left, right, target): return false
	_floor_y = motor.global_position.y + 65
	_home_x = (left + right) / 2
	return true

func activate() -> bool:
	if not super.activate(): return false
	intro_duration=(definition as WindkeeperDefinition).repeat_intro_seconds if intro_seen else (definition as WindkeeperDefinition).intro_seconds
	_enter(&"intro", intro_duration)
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
			if continuous_combat():
				# R3: a bounded, visible warning replaces the old indefinite safe
				# waiting/return walk. Select the closest existing pier without
				# teleporting; the following chase still uses the actual Motor.
				if transition_target == 3 and _platform_piers.size() == 3:
					var nearest := INF
					for index:int in 3:
						var distance := absf(_platform_piers[index]-motor.global_position.x)
						if distance < nearest: nearest=distance;chase_segment=index
					_pier_direction = -1 if chase_segment == 2 else 1
				phase_changed.emit(stage_phase)
				_enter(&"observe", .35)
			else:
				var destination := arena.left_x + 95 if transition_target == 3 else _home_x
				var distance := destination - motor.global_position.x
				motor.speed = (definition as WindkeeperDefinition).chase_speed
				motor.step(1 if distance > 0 else -1, absf(distance), delta)
				# Historical aperture fixture waits for a safe shelf or shore.
				var safe := _target.global_position.y <= _floor_y - 130 or _target.global_position.x < arena.left_x + 165 or _target.global_position.x > arena.right_x + 5
				if absf(distance) < 2 and (transition_target != 3 or safe):
					phase_changed.emit(stage_phase)
					_enter(&"observe", 1.2)
	elif stage_phase == 1: _ground_pattern(delta)
	elif stage_phase == 2: _wind_pattern(delta)
	else: _chase_pattern(delta)
	_update_combat_shapes()
	motor.queue_redraw()

func _enter(next: StringName, duration: float) -> void:
	mode = next
	clock = duration
	_storm_fired=false
	_motion_age=0
	if is_instance_valid(_target) and next in [&"blade_warning",&"pier_warning"]: _locked_aim=_target.global_position
	core_open = next in [&"neck", &"back", &"pier_open"]
	objective_changed.emit(objective())

func objective() -> String:
	if mode == &"intro": return (definition as WindkeeperDefinition).display_name
	if continuous_combat():
		if mode == &"phase_transition": return "地形将变化，先找落脚点 / FIND YOUR NEXT LANDING"
		if mode in [&"neck", &"back", &"pier_open"]: return "收招恢复，抓紧追击 / RECOVERY — PRESS THE ATTACK"
		if stage_phase == 1: return "随时可攻击，跳过地波并避开冲撞 / WATCH THE STOMP AND CHARGE"
		if stage_phase == 2: return "借平台躲开旋叶与风籽 / USE THE SHELVES TO EVADE"
		return "跨越断桥，避开落击后追击 / CROSS THE PIERS AND PUNISH THE LANDING"
	if mode == &"phase_transition": return "BRIDGE CRACKING — CLIMB TO THE GRASS SHELVES" if stage_phase == 3 else "WINDMILL AWAKENING — WATCH THE BACK BELL"
	if (definition as WindkeeperDefinition).storm_profile and stage_phase==2: return "持续左风：上草台，从上侧射背铃 / LEFT WIND / SHOOT BELL FROM ABOVE"
	if (definition as WindkeeperDefinition).storm_profile and stage_phase==3: return "踏亮当前草台，再起跳下射 / LAND ON LIT SHELF / JUMP & AIM DOWN" if (definition as WindkeeperDefinition).platform_trials else "跨断桥追逐，避开落击与双种子 / BROKEN BRIDGE + CROSS FIRE"
	if stage_phase == 1: return "地面瞄准颈铃，跳过地波 / GROUND AIM / SHOOT NECK BELL"
	if stage_phase == 2: return "先上草台，避开平台挡弹 / CLIMB & SHOOT BACK BELL"
	return "跨桥墩，落击后转身射铃芯 / SHOOT EXPOSED BELL"

func accepts_core_direction(context: Dictionary) -> bool:
	if continuous_combat(): return true
	var config:=definition as WindkeeperDefinition
	if config.platform_trials and stage_phase==3:
		var incoming:Vector2=context.get("hit_direction",Vector2.ZERO)
		var key:String="%s:%s"%[context.get("session_id",-1),context.get("shot_id",-1)]
		return _rune_shots.get(key,-1)==chase_segment and context.get("fired_airborne",false)==true and incoming.is_finite() and incoming.normalized().y>=config.final_upper_core_dot
	if not config.storm_profile or stage_phase!=2: return true
	# Downward incoming ray reaches the upper aperture. Side/bottom hits reject
	# with armour feedback; collision radius is still exactly 18px.
	var incoming: Vector2=context.get("hit_direction",Vector2.ZERO)
	return incoming.is_finite() and incoming.normalized().y >= (definition as WindkeeperDefinition).upper_core_dot

func core_offset() -> Vector2:
	var raised:bool=(definition as WindkeeperDefinition).platform_trials
	return Vector2(direction*84,-140) if raised and stage_phase==3 else Vector2(direction*36,-75) if raised and stage_phase==2 else Vector2(0, -80) if stage_phase == 2 else Vector2(direction * 65, -88 if stage_phase == 3 else (8 if raised else -8))

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
		_motion_age+=delta
		if config.storm_profile: motor.speed=config.charge_speed*clampf(_motion_age/.22,.2,1)
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
		if config.storm_profile and not _storm_fired:
			_storm_fired=true
			_storm_fan(_locked_aim,[-.32,0.0,.32])
		var previous_angle := blade_angle
		blade_angle += TAU * delta / config.blade_period
		var wind_region := Rect2(Vector2(arena.left_x, _floor_y - 280), Vector2(arena.right_x-arena.left_x, 350)) if config.storm_profile else Rect2(Vector2(_home_x - 110, _floor_y - 220), Vector2(220, 145))
		if _target is PlayerMotor and wind_region.has_point(_target.global_position):
			(_target as PlayerMotor).queue_local_velocity(config.crosswind_velocity if config.storm_profile else config.wind_velocity, delta)
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
	var piers:Array=_platform_piers if config.platform_trials and not _platform_piers.is_empty() else [arena.left_x+95,arena.left_x+385,arena.right_x-130] if config.platform_trials else [arena.left_x + 245, arena.left_x + 510, arena.right_x - 85]
	if mode == &"observe" and clock <= 0:
		direction = int(signf(float(piers[chase_segment])-motor.global_position.x)) if config.platform_trials else 1
		if direction==0:direction=_pier_direction
		motor.speed = config.chase_speed
		_enter(&"chase", 8.0)
	elif mode == &"chase":
		var stop := float(piers[chase_segment])
		motor.step(direction, absf(stop - motor.global_position.x), delta)
		if absf(motor.global_position.x-stop)<2 or clock <= 0:
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
		_enter(&"pier_open", config.exposed_seconds if config.platform_trials else config.exposed_seconds + 1.0)
	elif mode == &"pier_open" and config.storm_profile and not _storm_fired:
		_storm_fired=true
		_storm_fan(_locked_aim,[-.22,.22])
	elif mode == &"pier_open" and clock <= 0:
		_enter(&"final_hold" if chase_segment == 2 and not config.platform_trials else &"next_pier", config.pier_recovery_seconds)
	elif mode == &"next_pier" and clock <= 0:
		if config.platform_trials and (chase_segment+_pier_direction<0 or chase_segment+_pier_direction>2): _pier_direction*=-1
		chase_segment += _pier_direction if config.platform_trials else 1
		_enter(&"observe", 1.0)
	elif mode == &"final_hold" and clock <= 0:
		_enter(&"pier_warning", config.pier_warning_seconds)

func _clear_attacks() -> void:
	attack_epoch += 1
	_rune_shots.clear()
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
	_platform_piers.assign([owner_module.to_global(Vector2(350,452)).x,owner_module.to_global(Vector2(640,452)).x,owner_module.to_global(Vector2(870,452)).x])
	var consumer := WindkeeperArena.new()
	add_child(consumer)
	consumer.setup(owner_module,self,controller,policy,lifetime,segment,supports)
	reward_stands.assign([owner_module.to_global(Vector2(350,452)),owner_module.to_global(Vector2(640,452)),owner_module.to_global(Vector2(870,452))])
	return consumer

# The ordinary encounter restores its phase-three bridge after stage binding.
# Pressure has a separate grounded release flag and restore timing.
func restore_stage_geometry(consumer: WindkeeperArena) -> void:
	if stage_phase == 3: consumer.restore_broken_bridge()

func reward_stand_position() -> Vector2:
	var x := _home_x
	if stage_phase == 3 and reward_stands.size() == 3: return reward_stands[clampi(chase_segment,0,2)]
	return Vector2(x,_floor_y - 148 if stage_phase == 3 else _floor_y - 18)

func _storm_fan(point: Vector2, offsets: Array) -> void:
	var origin:=motor.global_position+Vector2(0,-100)
	var aim: Vector2=(point-origin).normalized()
	for offset: float in offsets:
		_attack_serial+=1
		var shot:=BossProjectile.new()
		shot.configure(definition,StringName("stormseed-%s-%s" % [attack_epoch,_attack_serial]),aim.rotated(offset),_target,motor)
		shot.speed=225
		shot.lifetime=2.4
		_projectiles.append(shot)
		projectile_created.emit(shot)
		motor.get_parent().add_child(shot)
		shot.global_position=origin

# Stage entry restores only the original pre-binding fields. Full combat restore
# remains at the App's existing post-geometry/activation points.
func restore_region_entry(data: Dictionary) -> void:
	restore_region_health(float(data.health))
	stage_phase = int(data.phase)
	chase_segment = int(data.chase_segment)
	mode = StringName(data.mode)
	clock = float(data.clock)

func _region_pattern_index() -> int:
	return 0

func region_snapshot() -> Dictionary:
	var data := {"health":health.current,"phase":stage_phase,"chase_segment":chase_segment,"mode":String(mode),"clock":clock,"position":[motor.position.x,motor.position.y],"active":active,"serial":_attack_serial,"direction":direction,"pattern_index":_region_pattern_index()}
	data.merge(combat_snapshot(),true)
	return data

func combat_snapshot() -> Dictionary:
	return {"intro_duration":intro_duration,"mode":String(mode),"clock":clock,"serial":_attack_serial,"direction":direction,"stomp_next":_stomp_next,"blade_angle":blade_angle,"phase_cycle":_phase_cycle,"blade_last_hit":_blade_last_hit,"storm_fired":_storm_fired,"locked_aim":[_locked_aim.x,_locked_aim.y],"motion_age":_motion_age,"transition_target":transition_target,"pier_direction":_pier_direction,"rune_platform":rune_platform}

func restore_combat_state(data: Dictionary) -> void:
	mode=StringName(data.mode);clock=float(data.clock)
	intro_duration=float(data.get("intro_duration",(definition as WindkeeperDefinition).intro_seconds))
	_attack_serial=int(data.get("serial",0));direction=int(data.get("direction",-1))
	_stomp_next=bool(data.get("stomp_next",true));blade_angle=float(data.get("blade_angle",0))
	_phase_cycle=int(data.get("phase_cycle",0));_blade_last_hit=int(data.get("blade_last_hit",-1))
	_storm_fired=bool(data.get("storm_fired",false));_motion_age=float(data.get("motion_age",0))
	transition_target=int(data.get("transition_target",stage_phase))
	_pier_direction=int(data.get("pier_direction",1))
	rune_platform=clampi(int(data.get("rune_platform",-1)),-1,2)
	_rune_shots.clear()
	var p: Array=data.get("locked_aim",[0,0]);_locked_aim=Vector2(p[0],p[1])
	core_open=mode in [&"neck",&"back",&"pier_open"]
	if is_instance_valid(_core): _update_combat_shapes()

func register_rune_shot(session:int,shot_id:int)->void:
	if not active or stage_phase!=3 or mode!=&"pier_open" or rune_platform!=chase_segment:return
	_rune_shots["%s:%s"%[session,shot_id]]=rune_platform
	while _rune_shots.size()>32:_rune_shots.erase(_rune_shots.keys()[0])

func body_contact_enabled() -> bool:
	return super.body_contact_enabled() and mode not in [&"intro", &"phase_transition"]

func presentation_state() -> BossPresentationState:
	var values := _presentation_values()
	values.merge({"phase":stage_phase,"phase_axes":{"combat":stage_phase},"damage_model":&"continuous_body" if continuous_combat() else &"aperture","core_hint_visible":core_open},true)
	var config := definition as WindkeeperDefinition
	var duration := config.pier_warning_seconds if mode == &"pier_warning" else config.phase_warning_seconds if mode == &"phase_transition" else config.warning_seconds
	return _presentation_countdown(values,mode,clock,duration,mode in [&"stomp_warning",&"charge_warning",&"blade_warning",&"pier_warning",&"phase_transition"],mode in [&"stomp",&"pier_impact"],mode in [&"charge",&"chase",&"blades"],mode in [&"neck",&"back",&"pier_open",&"final_hold"])

func presentation_capabilities() -> PackedStringArray:
	return PackedStringArray(["core_anchor","wind_arena","combat_state"])

func presentation_intro() -> Dictionary:
	var duration := maxf(intro_duration if intro_duration > 0 else (definition as WindkeeperDefinition).intro_seconds,.01)
	return {"active":active and mode == &"intro","duration":duration,"raw_clock":clock,"progress":clampf(1.0-clock/duration,0.0,1.0),"direction":direction}

func presentation_core() -> Dictionary:
	# Exposure is a UI hint, not permission to damage the body or core.
	return {"visible":core_open,"offset":core_offset(),"raw_clock":clock,"remaining_fraction":clampf(clock/(definition as WindkeeperDefinition).exposed_seconds,0.0,1.0),"continuous_combat":continuous_combat()}

func presentation_rune_cue() -> Dictionary:
	if continuous_combat() or not (definition as WindkeeperDefinition).platform_trials or stage_phase != 3 or not active or _platform_piers.size() != 3: return {}
	return {"position":Vector2(_platform_piers[clampi(chase_segment,0,2)],_floor_y-155),"charged":rune_platform == chase_segment}

func presentation_locked_aim() -> Dictionary:
	if not (definition as WindkeeperDefinition).storm_profile or mode not in [&"blade_warning",&"pier_warning"]: return {}
	return {"position":_locked_aim}

func presentation_blades() -> Dictionary:
	return {"angle":blade_angle,"active":stage_phase == 2 and mode == &"blades"}
