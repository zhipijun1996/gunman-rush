class_name ArenaBossBehavior
extends EnemyAttackBehavior

var phases := BossPhaseController.new()
var move_id: StringName
var pattern_step := 0
var damage_spent := false
var machine: ArenaBossDefinition
var footprint := Vector2.ZERO
var floor_y := 0.0

func configure(owner_actor: EnemyActor, target: PlayerController, damage_policy: FrameDamagePolicy, scope: DemoLifetime, id: StringName, safe_points: Array[Vector2]) -> void:
	super.configure(owner_actor,target,damage_policy,scope,id,safe_points)
	machine = actor.definition as ArenaBossDefinition
	phases.threshold = machine.phase_two_at
	home = actor._spawn
	floor_y = home.y + machine.floor_offset

func _can_engage() -> bool:
	var target := controller.motor.global_position
	var span := machine.engagement_span()
	if target.x<home.x+span.x or target.x>home.x+span.y or target.y<floor_y-machine.engagement_height or target.y>floor_y+28: return false
	for p: Vector2 in protected_points:
		if p.distance_to(target) < machine.protected_radius: return false
	return true

func advance(delta: float) -> bool:
	if not _active() or _actor_epoch != lifetime.actor_epoch or not _can_engage():
		if lifetime != null: _actor_epoch = lifetime.actor_epoch
		if state != &"idle": _set_state(&"idle")
		cooldown = 0.4
		return true
	if update_phase():
		pattern_step = 0
		GameAudio.cue(self,&"bell")
	state_time += delta
	match state:
		&"idle":
			cooldown -= delta
			if cooldown <= 0: _prepare()
		&"telegraph":
			if state_time >= warning_seconds():
				_set_state(&"attack")
				GameAudio.cue(self,attack_sound())
		&"attack":
			var previous := hit_rects(maxf(0,state_time-delta)/machine.attack_duration)
			var fraction := clampf(state_time/machine.attack_duration,0,1)
			advance_body(delta)
			var current := hit_rects(fraction)
			for i in current.size():
				_damage_player(previous[i].merge(current[i]))
			if fraction >= 1:
				_set_state(&"recovery")
				GameAudio.cue(self,&"core")
		&"recovery":
			if state_time >= machine.recovery_duration: _set_state(&"idle")
	return true

func warning_seconds() -> float:
	return machine.telegraph_duration

func update_phase() -> bool:
	var changed := phases.update(actor.health.current,machine.health_definition.max_health)
	if phases.phase==2 and not machine.third_cycle.is_empty() and actor.health.current>0 and actor.health.current<=actor.health.capacity*machine.phase_three_at:
		phases.phase=3
		return true
	return changed

func _prepare() -> void:
	var cycle := machine.first_cycle if phases.phase==1 else machine.second_cycle
	if phases.phase==3: cycle=machine.third_cycle
	move_id = StringName(cycle[pattern_step % cycle.size()])
	pattern_step += 1
	_serial += 1
	damage_spent = false
	var at := actor.motor.global_position
	var player := controller.motor.global_position
	var side := 1 if player.x >= at.x else -1
	if move_id == &"backswing": side = -actor.brain.direction
	locked_direction = Vector2(side,0)
	actor.brain.direction = side
	configure_head(at,player,side)
	_set_state(&"telegraph")

func configure_head(_at: Vector2, _player: Vector2, _side: int) -> void:
	pass

func advance_body(_delta: float) -> void:
	pass

func attack_sound() -> StringName:
	return &"boss_impact"

func strike_category() -> StringName:
	return &"machine_solid"

func active_rect(fraction: float) -> Rect2:
	return Rect2(attack_origin.lerp(attack_goal,clampf(fraction,0,1))-footprint/2,footprint)

func hit_rects(fraction: float) -> Array[Rect2]:
	return [active_rect(fraction)]

func _damage_player(rect: Rect2) -> void:
	if damage_spent: return
	var shape := controller.motor.get_node("CollisionShape2D") as CollisionShape2D
	if not rect.intersects(shape.global_transform * shape.shape.get_rect()): return
	var req := DamageRequest.new()
	req.token = lifetime.token()
	req.actor_epoch = _actor_epoch
	req.health_epoch = controller.actor_resources.health.epoch
	req.event_id = StringName("%s:%s:%s" % [source_id,req.actor_epoch,_serial])
	req.source_id = source_id
	req.target_id = &"player"
	req.kind = DamageRequest.Kind.MONSTER
	req.hazard_category = strike_category()
	req.hit_direction = (controller.motor.global_position-rect.get_center()).normalized()
	# An invulnerable passage consumes this swing too; leaving the head cannot produce another hit.
	damage_spent = true
	policy.submit(req)

func restore_region_state(saved: Dictionary) -> bool:
	# A rebuilt room starts with a fresh readable warning, never a half-completed blow.
	home = actor._spawn
	floor_y = home.y + machine.floor_offset
	update_phase()
	_serial = int(saved.get("serial",0))
	pattern_step = _serial
	cooldown = 0.5
	_set_state(&"idle")
	return true
