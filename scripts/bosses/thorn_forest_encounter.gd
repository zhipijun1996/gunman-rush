class_name ThornForestEncounter
extends BossEncounter
## Forest-native: lock a real old branch; switch branches during a bounded
## seed flight; use the following open-heart window from the indicated side.
signal objective_changed(text: String)
signal armour_hit(point: Vector2)
var stage_phase := 1
var mode: StringName = &"observe"
var clock := 0.0
var intro_seen := false
var intro_duration := 0.0
var core_open := false
var weak_side := -1
var attack_goal := Vector2.ZERO
var has_ground_mark := false
var attack_epoch := 0
var _cycles := 0
var _floor_y := 0.0
var _target_session := -1
func _ready() -> void:
	super._ready()
	motor.collision_mask = 0
	(damageable as ThornDamageable).encounter = self
func configure_arena(left: float, right: float, target: Node2D) -> bool:
	if not super.configure_arena(left,right,target): return false
	_floor_y = motor.global_position.y + definition.collision_size.y * .5
	var target_controller := target.get_node_or_null("Controller") as PlayerController
	_target_session = target_controller.session_id if target_controller != null else -1
	return true
func configure_forest_floor(floor_y: float) -> void:
	if is_finite(floor_y): _floor_y = floor_y
func activate() -> bool:
	if not super.activate(): return false
	var config := definition as ThornForestDefinition
	intro_duration = config.repeat_intro_seconds if intro_seen else config.intro_seconds
	intro_seen = true
	_enter(&"intro",intro_duration)
	return true
func physics_tick(delta: float) -> void:
	if not active or health.terminal or not is_finite(delta) or delta <= 0: return
	if not combat_target_active():
		if mode != &"observe" or not _projectiles.is_empty(): cancel_pending_attacks()
		return
	var target_controller := _target.get_node_or_null("Controller") as PlayerController
	if target_controller != null and target_controller.session_id != _target_session:
		_target_session = target_controller.session_id
		cancel_pending_attacks()
		return
	for index: int in range(_projectiles.size()-1,-1,-1):
		if not is_instance_valid(_projectiles[index]) or _projectiles[index].spent: _projectiles.remove_at(index)
	var config := definition as ThornForestDefinition
	var wanted := (3 if health.current <= health.capacity * config.phase_three_health else 2 if health.current <= health.capacity * config.phase_two_threshold else 1) if config.queen else (2 if health.current <= health.capacity * config.phase_two_threshold else 1)
	if wanted != stage_phase:
		stage_phase = wanted
		phases.phase = wanted
		_cancel_projectiles()
		attack_epoch += 1
		phase_changed.emit(stage_phase)
		_enter(&"phase_transition",config.phase_warning_seconds)
	clock -= delta
	if mode in [&"intro", &"phase_transition"] and clock <= 0:
		_enter(&"observe",config.observation_seconds)
	elif mode == &"observe" and clock <= 0:
		_lock_branch()
		_enter(&"branch_warning",config.telegraph_duration)
	elif mode == &"branch_warning" and clock <= 0:
		if has_ground_mark: _launch_seed()
		_enter(&"seed_flight", config.seed_flight_seconds)
	elif mode == &"seed_flight" and clock <= 0:
		_enter(&"thorn_patch",config.seed_zone_seconds)
	elif mode == &"thorn_patch" and clock <= 0:
		_cycles += 1
		if stage_phase >= 2:
			weak_side = (-1 if _cycles % 2 == 0 else 1) if config.queen and stage_phase == 2 else (-1 if attack_goal.x >= motor.global_position.x else 1)
		_enter(&"heart_open",config.exposed_seconds)
	elif mode == &"heart_open" and clock <= 0:
		_enter(&"observe",config.observation_seconds)
	motor.queue_redraw()
func _lock_branch() -> void:
	has_ground_mark = false
	if not is_instance_valid(_target) or not _target is PhysicsBody2D: return
	# Never predicts input or fabricates a platform under an airborne target.
	if _target is PlayerMotor and not (_target as PlayerMotor).is_on_floor(): return
	var ray := PhysicsRayQueryParameters2D.create(_target.global_position, _target.global_position + Vector2(0,45), 1, [(_target as PhysicsBody2D).get_rid(),motor.get_rid()])
	var support := motor.get_world_2d().direct_space_state.intersect_ray(ray)
	if not support.is_empty() and (support.normal as Vector2).y < -.5:
		attack_goal = support.position
		has_ground_mark = true
func _launch_seed() -> void:
	var config := definition as ThornForestDefinition
	_attack_serial += 1
	var seed := ThornSeedProjectile.new()
	seed.configure(config,StringName("thorn:%s:%s:%s" % [defeat_id,attack_epoch,_attack_serial]),Vector2.DOWN,_target,motor)
	seed.encounter = self
	seed.owner_attack_epoch = attack_epoch
	seed.target_session = _target_session
	seed.origin = motor.global_position + Vector2(0,-definition.collision_size.y*.5)
	seed.goal = attack_goal
	seed.flight_seconds = config.seed_flight_seconds
	seed.arc_height = config.seed_arc_height
	seed.zone_seconds = config.seed_zone_seconds
	seed.zone_size = config.seed_zone_size
	_projectiles.append(seed)
	projectile_created.emit(seed)
	motor.get_parent().add_child(seed)
	seed.global_position = seed.origin
	GameAudio.cue(self,&"enemy_shot")
	# No second patch is added to the receiving branch: every warning has a
	# readable neighbouring safe branch and the permanent lower floor.
func _enter(next: StringName, duration: float) -> void:
	mode = next
	clock = duration
	core_open = next == &"heart_open"
	objective_changed.emit(objective())
	if next in [&"branch_warning",&"phase_transition"]: GameAudio.cue(self,&"warning")
func objective() -> String:
	var config := definition as ThornForestDefinition
	if mode == &"intro": return config.display_name
	if mode == &"phase_transition": return "树心换向 — 看亮侧 / HEART CHANGING SIDE"
	if mode == &"heart_open":
		if stage_phase == 1: return "树心开放！瞄准射击 / SHOOT THE OPEN HEART"
		return "左侧亮心 — 从左侧射击 / SHOOT FROM LEFT" if weak_side < 0 else "右侧亮心 — 从右侧射击 / SHOOT FROM RIGHT"
	return "落区已锁定：钩到另一枝 / OLD BRANCH MARKED — GRAPPLE TO SAFETY"
func accepts_core_direction(context: Dictionary) -> bool:
	if not core_open: return false
	if stage_phase == 1: return true
	var incoming: Vector2 = context.get("hit_direction",Vector2.ZERO)
	return incoming.is_finite() and incoming.normalized().x * weak_side < -(definition as ThornForestDefinition).side_direction_dot
func combat_target_active() -> bool:
	if not is_instance_valid(_target): return false
	var target_controller := _target.get_node_or_null("Controller") as PlayerController
	return target_controller == null or (target_controller.active and not target_controller.actor_resources.health.terminal)
func body_contact_enabled() -> bool:
	# Rooted trunk occupies a visible small body, disabled during presentation.
	return super.body_contact_enabled() and combat_target_active() and mode not in [&"intro",&"phase_transition"]
func cancel_pending_attacks() -> void:
	_cancel_projectiles()
	attack_epoch += 1
	has_ground_mark = false
	if active and mode != &"intro": _enter(&"observe",(definition as ThornForestDefinition).observation_seconds)
func skip_intro() -> void:
	if active and mode == &"intro": _enter(&"observe",(definition as ThornForestDefinition).observation_seconds)
func cancel() -> void:
	core_open = false
	has_ground_mark = false
	attack_epoch += 1
	super.cancel()
func reward_stand_position() -> Vector2:
	return Vector2(arena.left_x + 95, _floor_y - 18)
func combat_snapshot() -> Dictionary:
	return {"mode":String(mode),"clock":clock,"stage_phase":stage_phase,"intro_duration":intro_duration,"weak_side":weak_side,"cycles":_cycles,"serial":_attack_serial,"attack_epoch":attack_epoch}
func serialize_combat_state() -> Dictionary: return combat_snapshot()
func restore_combat_state(data: Dictionary) -> void:
	stage_phase = clampi(int(data.get("stage_phase",1)),1,3)
	weak_side = -1 if int(data.get("weak_side",-1)) < 0 else 1
	_cycles = maxi(0,int(data.get("cycles",0)))
	_attack_serial = maxi(0,int(data.get("serial",0)))
	attack_epoch = maxi(attack_epoch,int(data.get("attack_epoch",0))) + 1
	intro_duration = float(data.get("intro_duration",0))
	# A restored attack never recreates an old target's warning or patch.
	_cancel_projectiles()
	has_ground_mark = false
	_enter(&"observe",(definition as ThornForestDefinition).observation_seconds)

func presentation_state() -> BossPresentationState:
	var values := _presentation_values()
	values.merge({"phase":stage_phase,"phase_axes":{"combat":stage_phase},"damage_model":&"directional_heart","core_hint_visible":core_open},true)
	var duration := (definition as ThornForestDefinition).phase_warning_seconds if mode == &"phase_transition" else definition.telegraph_duration
	return _presentation_countdown(values,mode,clock,duration,mode in [&"branch_warning",&"phase_transition"],mode == &"seed_flight",false,mode == &"heart_open")

func presentation_capabilities() -> PackedStringArray:
	return PackedStringArray(["heart_window","ground_mark","combat_state"])

func presentation_heart() -> Dictionary:
	return {"offset":Vector2(weak_side*18 if stage_phase > 1 else 0,-9),"visible":core_open}

func presentation_ground_mark() -> Dictionary:
	if not has_ground_mark or mode not in [&"branch_warning",&"seed_flight"]: return {}
	return {"position":attack_goal,"width":(definition as ThornForestDefinition).seed_zone_size.x}
