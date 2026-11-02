class_name RootbellGuardianV2
extends ThornForestEncounter
## Normally vulnerable moving body and real thrown-weapon arrival counter.
## Side branches are static terrain; the rejected root-key subsystem is retired.
const DUEL_VERSION := "guardian-two-action-cycle-v6"
signal duel_event(event: Dictionary)
var geometry: Dictionary = {}
var last_restore_accepted := false
var _duel_controller: PlayerController
var _duel_policy: FrameDamagePolicy
var _duel_life: DemoLifetime
var _bound_actor_epoch := 0
var _duel_bound := false
var _flight_velocity := Vector2.ZERO
var _vertical_speed := 0.0
var _flight_age := 0.0
var _flight_token: DemoToken
var _bell: GuardianRootBellV2
var _bell_done := false
var _next_bell := true
var _counter_pending: Dictionary = {}
var _flight_event: StringName
func _ready() -> void:
	super._ready()
	motor.collision_mask = 1
func bind_duel(data: Dictionary, _controller: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime) -> bool:
	if not geometry.is_empty(): return _duel_bound and geometry == data and _duel_controller == _controller and _duel_policy == policy and _duel_life == lifetime
	if not data.get("ok",false) or data.get("version","") != ForestBossArenaFactory.VERSION or _controller == null or policy == null or lifetime == null or not definition is BossDuelDefinition or not motor is ForestBossMotor: return false
	var rows: Array = data.get("root_supports",[])
	if not rows.is_empty(): return false
	geometry = data.duplicate(true)
	_duel_controller = _controller
	_duel_policy = policy
	_duel_life = lifetime
	_bound_actor_epoch = lifetime.actor_epoch
	if not policy.batch_resolved.is_connected(_counter_batch): policy.batch_resolved.connect(_counter_batch)
	_duel_bound = true
	_ensure_bell()
	return true
func physics_tick(delta: float) -> void:
	if not active or health.terminal or not is_finite(delta) or delta <= 0: return
	if _duel_life == null or not _duel_life.active or not combat_target_active():
		cancel_pending_attacks()
		return
	if _bound_actor_epoch != _duel_life.actor_epoch:
		_bound_actor_epoch = _duel_life.actor_epoch
		cancel_pending_attacks()
		return
	var target_controller := _target.get_node_or_null("Controller") as PlayerController
	if target_controller != null and target_controller.session_id != _target_session:
		_target_session = target_controller.session_id
		cancel_pending_attacks()
		return
	var config := definition as BossDuelDefinition
	var wanted_phase := 2 if config.bell_enabled and _cycles>0 and health.current <= health.capacity*config.phase2_health_ratio else 1
	if wanted_phase != stage_phase:
		stage_phase = wanted_phase
		phase_changed.emit(stage_phase)
		_event("duel_phase_changed",{"phase":stage_phase,"completed_body_cycles":_cycles,"boss_hp":health.current,"bell_out":is_instance_valid(_bell) and _bell.state != &"held"})
		# Keep the real weapon in flight. The new decision is a moving receiver,
		# not a reset, stronger bullets, or an armour/side password.
		if stage_phase == 2 and mode == &"bell_watch":
			_lock_landing_support()
			if has_ground_mark: _enter(&"pursuit_warning",config.telegraph_duration)
	clock -= delta
	if mode == &"pursuit_flight":
		_flight_step(delta)
	else:
		_fall_step(delta)
		match mode:
			&"intro":
				if clock <= 0: _enter(&"observe",config.observation_seconds)
			&"observe":
				if clock <= 0:
					if config.bell_enabled and _next_bell: _ensure_bell()
					if config.bell_enabled and _next_bell and is_instance_valid(_bell) and _bell.state == &"held":
						attack_goal = _target.global_position
						has_ground_mark = true
						_enter(&"bell_warning",config.bell_warning_seconds)
						_event("bell_target_locked",{"goal":[attack_goal.x,attack_goal.y]})
						return
					_lock_landing_support()
					if has_ground_mark:
						_enter(&"pursuit_warning",config.telegraph_duration)
						_event("support_locked",{"goal":[attack_goal.x,attack_goal.y]})
					else: clock = config.observation_seconds
			&"bell_warning":
				if clock <= 0 and is_instance_valid(_bell):
					_bell_done = false
					_bell.launch(attack_goal)
					_next_bell = false
					_enter(&"bell_watch",config.bell_lifetime)
			&"bell_watch":
				if stage_phase == 2 and is_instance_valid(_bell) and _bell.travel_age >= config.phase2_overlap_seconds:
					_lock_landing_support()
					if has_ground_mark: _enter(&"pursuit_warning",config.telegraph_duration)
				elif _bell_done or not is_instance_valid(_bell): _enter(&"landing_recovery",config.landing_recovery_seconds)
			&"pursuit_warning":
				if clock <= 0: _launch_body()
			&"landing_recovery", &"bell_stagger":
				if clock <= 0: _enter(&"observe",config.observation_seconds)
	motor.queue_redraw()
func _lock_landing_support() -> void:
	has_ground_mark = false
	if not is_instance_valid(_target) or not _target is PhysicsBody2D: return
	var column_x := clampf(_target.global_position.x,arena.left_x,arena.right_x)
	var start := Vector2(column_x,_target.global_position.y)
	var end := Vector2(column_x,_floor_y+(definition as BossDuelDefinition).floor_depth)
	var query := PhysicsRayQueryParameters2D.create(start,end,1,[(_target as PhysicsBody2D).get_rid(),motor.get_rid()])
	var support := motor.get_world_2d().direct_space_state.intersect_ray(query)
	if not support.is_empty() and (support.normal as Vector2).y < -.5:
		attack_goal = support.position
		has_ground_mark = true
func _launch_body() -> void:
	var config := definition as BossDuelDefinition
	var goal := attack_goal-Vector2(0,definition.collision_size.y*.5)
	var time := config.pursuit_flight_seconds
	_flight_velocity = (goal-motor.global_position)/time-Vector2(0,config.pursuit_gravity*time*.5)
	_next_bell = true
	_flight_age = 0
	_attack_serial += 1
	_flight_event = StringName("guardian-duel:%s:%s:%s" % [defeat_id,attack_epoch,_attack_serial])
	_flight_token = _duel_life.token()
	_enter(&"pursuit_flight",config.slam_timeout)
	_event("body_launch",{"phase":stage_phase,"bell_out":is_instance_valid(_bell) and _bell.state != &"held","attack_id":String(_flight_event),"from":[motor.global_position.x,motor.global_position.y],"goal":[goal.x,goal.y],"velocity":[_flight_velocity.x,_flight_velocity.y]})
func _flight_step(delta: float) -> void:
	var config := definition as BossDuelDefinition
	if not _duel_life.accepts(_flight_token):
		cancel_pending_attacks()
		return
	_flight_age += delta
	_flight_velocity.y += config.pursuit_gravity*delta
	var collision := (motor as ForestBossMotor).advance_duel(_flight_velocity,delta)
	if collision != null:
		var collider := collision.get_collider()
		var point := collision.get_position()
		_cycles += 1
		_enter(&"landing_recovery",config.landing_recovery_seconds)
		_vertical_speed = 0
		_event("body_collision",{"body_position":[motor.global_position.x,motor.global_position.y],"platform_id":String(collider.get_meta(&"arena_platform_id","")) if is_instance_valid(collider) else "","support_ids":collider.get_meta(&"support_ids",[]) if is_instance_valid(collider) else [],"phase":stage_phase,"completed_body_cycles":_cycles,"attack_id":String(_flight_event),"collider":collider.get_instance_id() if is_instance_valid(collider) else 0,"kind":"player" if collider == _target else "terrain","point":[point.x,point.y],"normal":[collision.get_normal().x,collision.get_normal().y],"physics_frame":Engine.get_physics_frames()})
	elif clock <= 0:
		_cycles += 1
		_event("body_flight_completed",{"phase":stage_phase,"completed_body_cycles":_cycles,"attack_id":String(_flight_event),"flight_age":_flight_age,"physics_frame":Engine.get_physics_frames(),"position":[motor.global_position.x,motor.global_position.y]})
		_vertical_speed = _flight_velocity.y
		_enter(&"landing_recovery",config.landing_recovery_seconds)
func _fall_step(delta: float) -> void:
	_vertical_speed += (definition as BossDuelDefinition).pursuit_gravity*delta
	var collision := (motor as ForestBossMotor).advance_duel(Vector2(0,_vertical_speed),delta)
	if collision != null:
		if collision.get_normal().y < -.5: _vertical_speed = 0
func _ensure_bell() -> void:
	if not (definition as BossDuelDefinition).bell_enabled or is_instance_valid(_bell) or _duel_life == null: return
	_bell = GuardianRootBellV2.new()
	motor.get_parent().add_child(_bell)
	_bell.setup(motor,definition as BossDuelDefinition,_duel_controller,_duel_policy,_duel_life,StringName("guardian-bell:%s:%s:%s" % [defeat_id,attack_epoch,_bell.get_instance_id()]),attack_epoch)
	_bell.bell_event.connect(func(row: Dictionary) -> void: duel_event.emit(row))
	_bell.counter_impact.connect(_receive_counter_impact.bind(_bell))
	_bell.recovered.connect(func(_caught: bool) -> void: _bell_done = true)
func _receive_counter_impact(data: Dictionary, bell: GuardianRootBellV2) -> void:
	if not active or not core_open or health.terminal or not (definition as BossDuelDefinition).bell_counter_enabled or not is_instance_valid(bell) or bell != _bell: return
	if bell.owner_motor != motor or bell.lifetime != _duel_life or not _duel_life.accepts(bell.token) or bell.attack_epoch != attack_epoch or not bell._counter_active or not bell._counter_submitted: return
	if data.get("physics_frame") != Engine.get_physics_frames() or data.get("owner_id") != motor.get_instance_id() or data.get("bell_id") != bell.get_instance_id() or data.get("player_session") != _duel_controller.session_id or data.get("event_id") != String(bell._counter_event): return
	if data.get("contact_kind") not in ["kinematic_sweep","actual_shape_overlap"]: return
	var request := DamageRequest.new()
	request.token = bell.token.copy()
	request.event_id = bell._counter_event
	request.source_id = StringName("guardian_bell_counter:%s" % defeat_id)
	# Both the formal DemoApp and this local fixture register this existing
	# Boss Health under boss. Never register another owner or fake a shot ID.
	request.target_id = &"boss"
	request.kind = DamageRequest.Kind.MONSTER
	request.amount = (definition as BossDuelDefinition).bell_counter_damage
	request.actor_epoch = _duel_life.actor_epoch
	request.health_epoch = health.epoch
	request.physics_tick = Engine.get_physics_frames()
	if _duel_policy.submit(request):
		_counter_pending[String(request.event_id)] = data.duplicate(true)
		_event("bell_counter_submitted",{"event_id":String(request.event_id),"bell_id":bell.get_instance_id(),"amount":request.amount,"contact_kind":data.contact_kind})
func _counter_batch(results: Array[DamageResult]) -> void:
	for result: DamageResult in results:
		var id := String(result.request.event_id)
		if not _counter_pending.has(id): continue
		var evidence: Dictionary = _counter_pending[id]
		_counter_pending.erase(id)
		_event("bell_counter_committed",{"event_id":id,"bell_id":evidence.bell_id,"amount":result.request.amount,"hp":result.health.current,"contact_kind":evidence.contact_kind})
		if not active or health.terminal or not _duel_life.accepts(result.request.token) or _duel_controller.actor_resources.health.terminal: continue
		attack_epoch += 1
		_flight_token = null
		_flight_velocity = Vector2.ZERO
		_vertical_speed = motor.velocity.y
		has_ground_mark = false
		_enter(&"bell_stagger",(definition as BossDuelDefinition).bell_counter_stagger_seconds)
func _cancel_bell() -> void:
	if is_instance_valid(_bell): _bell.finish(false)
	_bell = null
	_bell_done = true
func cancel() -> void:
	if not health.terminal: _counter_pending.clear()
	_cancel_bell()
	super.cancel()
func _enter(next: StringName, duration: float) -> void:
	mode = next
	clock = duration
	core_open = active and next != &"intro"
	objective_changed.emit(objective())
	if next in [&"pursuit_warning",&"bell_warning"]: GameAudio.cue(self,&"warning")
func accepts_core_direction(_context: Dictionary) -> bool: return core_open
func objective() -> String:
	if mode == &"intro": return "根铃守卫 / ROOTBELL GUARDIAN"
	if mode == &"bell_stagger": return "COUNTER IMPACT / SHOOT THE MOVING BODY"
	if mode == &"bell_warning": return "金属铃要出手：跳线、绕行或借铃换侧 / SOLID BELL — CHANGE YOUR FIRING LINE"
	if mode == &"bell_watch": return "铃是真实遮挡和活锚；本体仍可伤 / MOVING BELL BLOCKS SHOTS — CORE STAYS VULNERABLE"
	if mode == &"pursuit_warning": return "扑向旧支撑：越过承诺方向 / OLD SUPPORT LOCKED — CROSS THE COMMITMENT"
	return "SHOOT THE BODY / REACH THE BELL AND KICK IT BACK"
func cancel_pending_attacks() -> void:
	_counter_pending.clear()
	_cancel_bell()
	_cancel_projectiles()
	attack_epoch += 1
	has_ground_mark = false
	_flight_token = null
	_flight_velocity = Vector2.ZERO
	if active: _enter(&"observe",(definition as BossDuelDefinition).observation_seconds)
func combat_snapshot() -> Dictionary:
	var data := super.combat_snapshot()
	data["duel_version"] = DUEL_VERSION
	data["next_bell"] = _next_bell
	data["duel_counter_enabled"] = (definition as BossDuelDefinition).bell_counter_enabled
	data["body_position"] = [motor.global_position.x,motor.global_position.y]
	data["vertical_speed"] = _vertical_speed
	return data
func valid_duel_snapshot(data: Dictionary) -> bool:
	if typeof(data.get("duel_counter_enabled")) != TYPE_BOOL: return false
	if data.duel_counter_enabled != (definition as BossDuelDefinition).bell_counter_enabled: return false
	if typeof(data.get("duel_version")) not in [TYPE_STRING,TYPE_STRING_NAME]: return false
	if data.duel_version != DUEL_VERSION or typeof(data.get("next_bell")) != TYPE_BOOL or data.has("duel_roots"): return false
	if typeof(data.get("stage_phase")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data.stage_phase)) or float(data.stage_phase) not in [1.0,2.0]: return false
	if typeof(data.get("weak_side")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data.weak_side)) or float(data.weak_side) not in [-1.0,1.0]: return false
	if typeof(data.get("intro_duration")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data.intro_duration)) or float(data.intro_duration) < 0 or float(data.intro_duration) > (definition as BossDuelDefinition).intro_seconds: return false
	if typeof(data.get("mode")) not in [TYPE_STRING,TYPE_STRING_NAME] or String(data.mode) not in ["intro","observe","pursuit_warning","pursuit_flight","landing_recovery","bell_stagger","bell_warning","bell_watch"]: return false
	if typeof(data.get("clock")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data.clock)): return false
	var config := definition as BossDuelDefinition
	if float(data.clock) < 0 or float(data.clock) > maxf(config.intro_seconds,maxf(config.bell_lifetime,maxf(config.bell_counter_stagger_seconds,config.slam_timeout))): return false
	for key: String in ["cycles","serial","attack_epoch"]:
		if typeof(data.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data[key])) or float(data[key]) < 0 or float(data[key]) != floorf(float(data[key])): return false
	if int(data.stage_phase)==2 and int(data.cycles)==0: return false
	var point: Variant = data.get("body_position")
	if not point is Array or point.size() != 2: return false
	for coordinate: Variant in point:
		if typeof(coordinate) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(coordinate)): return false
	if float(point[0]) < arena.left_x or float(point[0]) > arena.right_x or float(point[1]) > _floor_y or float(point[1]) < float(geometry.boss_arena[1])-definition.collision_size.y: return false
	if typeof(data.get("vertical_speed")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data.vertical_speed)): return false
	return true
func restore_combat_state(data: Dictionary) -> void:
	last_restore_accepted = false
	if not valid_duel_snapshot(data): return
	_counter_pending.clear()
	_cancel_bell()
	_cancel_projectiles()
	attack_epoch = maxi(attack_epoch,int(data.attack_epoch))+1
	stage_phase = int(data.stage_phase)
	weak_side = int(data.weak_side)
	intro_duration = float(data.intro_duration)
	_next_bell = data.next_bell
	_cycles = int(data.cycles)
	_attack_serial = int(data.serial)
	has_ground_mark = false
	_flight_token = null
	motor.global_position = Vector2(data.body_position[0],data.body_position[1])
	_vertical_speed = float(data.vertical_speed)
	if data.mode == "bell_stagger" and float(data.clock) > 0:
		var duration := (definition as BossDuelDefinition).bell_counter_stagger_seconds
		_enter(StringName(data.mode),minf(float(data.clock),duration))
	else: _enter(&"landing_recovery",(definition as BossDuelDefinition).landing_recovery_seconds)
	last_restore_accepted = true
func _event(kind: String, data: Dictionary) -> void:
	var row := data.duplicate(true)
	row["event"] = kind
	row["mode"] = String(mode)
	row["attack_epoch"] = attack_epoch
	duel_event.emit(row)
	presentation_event.emit(row.duplicate(true))
func _exit_tree() -> void:
	_cancel_bell()
	super._exit_tree()

func presentation_state() -> BossPresentationState:
	var values := _presentation_values()
	values.merge({"phase":stage_phase,"phase_axes":{"combat":stage_phase},"damage_model":&"duel_body","core_hint_visible":core_open},true)
	var config := definition as BossDuelDefinition
	var duration := config.bell_warning_seconds if mode == &"bell_warning" else config.telegraph_duration
	return _presentation_countdown(values,mode,clock,duration,mode in [&"bell_warning",&"pursuit_warning"],mode == &"bell_watch",mode == &"pursuit_flight",mode in [&"landing_recovery",&"bell_stagger"])

func presentation_capabilities() -> PackedStringArray:
	return PackedStringArray(["rootbell_duel","bell_weapon","pursuit_warning","combat_state"])

func presentation_bell() -> Dictionary:
	if not is_instance_valid(_bell): return {}
	return {"position":_bell.global_position,"radius":(definition as BossDuelDefinition).bell_radius,"state":_bell.state}

func presentation_bell_warning() -> Dictionary:
	if mode != &"bell_warning" or not is_instance_valid(_bell): return {}
	var config := definition as BossDuelDefinition
	var start := _bell.global_position
	var duration := config.bell_outbound_seconds
	var initial := (attack_goal-start)/duration-Vector2(0,config.bell_gravity*duration*.5)
	var points := PackedVector2Array()
	for index: int in 12:
		var time := duration*float(index)/12.0
		points.append(start+initial*time+Vector2(0,.5*config.bell_gravity*time*time))
	return {"origin":start,"radius":config.bell_radius,"points":points}

func presentation_pursuit_warning() -> Dictionary:
	if not has_ground_mark or mode != &"pursuit_warning": return {}
	var config := definition as BossDuelDefinition
	var size := definition.collision_size
	var start := motor.global_position
	var target := attack_goal-Vector2(0,size.y*.5)
	var duration := config.pursuit_flight_seconds
	var velocity := (target-start)/duration-Vector2(0,config.pursuit_gravity*duration*.5)
	var position := start
	var step := 1.0/60.0
	var ticks := ceili(duration/step)
	var centers := PackedVector2Array()
	# Preserve the existing 60Hz preview integration and every-fourth sample.
	# This is projected geometry, not a second Motor or damage simulation.
	for index: int in range(ticks+1):
		if index % 4 == 0 or index == ticks: centers.append(position)
		velocity.y += config.pursuit_gravity*step
		position += velocity*step
	return {"origin":start,"centers":centers,"body_size":size,"landing":attack_goal}
