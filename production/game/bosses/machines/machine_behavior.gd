class_name MachineBossBehavior
extends EnemyAttackBehavior

var phases := BossPhaseController.new()
var move_id: StringName
var pattern_step := 0
var damage_spent := false
var machine: MachineBossDefinition
var footprint := Vector2.ZERO
var floor_y := 0.0

func configure(owner_actor: EnemyActor, target: PlayerController, damage_policy: FrameDamagePolicy, scope: DemoLifetime, id: StringName, safe_points: Array[Vector2]) -> void:
	super.configure(owner_actor,target,damage_policy,scope,id,safe_points)
	machine = actor.definition as MachineBossDefinition
	home = actor._spawn
	floor_y = home.y + machine.floor_offset

func _can_engage() -> bool:
	var target := controller.motor.global_position
	if absf(target.x-home.x)>machine.arena_half_width or target.y<floor_y-400 or target.y>floor_y+28: return false
	for p: Vector2 in protected_points:
		if p.distance_to(target) < machine.protected_radius: return false
	return true

func advance(delta: float) -> bool:
	if not _active() or _actor_epoch != lifetime.actor_epoch or not _can_engage():
		if lifetime != null: _actor_epoch = lifetime.actor_epoch
		if state != &"idle": _set_state(&"idle")
		cooldown = 0.4
		return true
	if phases.update(actor.health.current,machine.health_definition.max_health):
		pattern_step = 0
		GameAudio.cue(self,&"bell")
	state_time += delta
	match state:
		&"idle":
			cooldown -= delta
			if cooldown <= 0: _prepare()
		&"telegraph":
			if state_time >= machine.telegraph_duration:
				_set_state(&"attack")
				GameAudio.cue(self,&"enemy_shot" if move_id == &"curtain" else &"boss_impact")
		&"attack":
			var old := active_rect(maxf(0,state_time-delta)/machine.attack_duration)
			var fraction := clampf(state_time/machine.attack_duration,0,1)
			if move_id == &"rail":
				var along := attack_goal - actor.motor.global_position
				actor.motor.move_and_collide(along.limit_length(machine.attack_speed*delta))
			var now := active_rect(fraction)
			_damage_player(old.merge(now))
			if fraction >= 1:
				_set_state(&"recovery")
				GameAudio.cue(self,&"core")
		&"recovery":
			if state_time >= machine.recovery_duration: _set_state(&"idle")
	return true

func _prepare() -> void:
	var cycle := machine.first_cycle if phases.phase==1 else machine.second_cycle
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
	match move_id:
		&"rail":
			footprint = machine.collision_size
			attack_origin = at
			var bound := machine.arena_half_width - footprint.x/2
			attack_goal = Vector2(clampf(at.x+side*machine.reach,home.x-bound,home.x+bound),at.y)
		&"sweep", &"backswing":
			footprint = Vector2(46,26)
			attack_origin = Vector2(at.x+side*18,floor_y-27)
			attack_goal = attack_origin+locked_direction*machine.reach
		&"gantry":
			footprint = Vector2(58,44)
			attack_origin = Vector2(home.x-side*machine.reach,floor_y-31)
			attack_goal = Vector2(home.x+side*machine.reach,floor_y-31)
		&"left_weight", &"right_weight", &"stamp":
			var lane := clampf(player.x,home.x-machine.reach,home.x+machine.reach)
			if move_id == &"left_weight": lane = minf(lane,home.x-95)
			if move_id == &"right_weight": lane = maxf(lane,home.x+95)
			footprint = Vector2(94,42) if move_id==&"stamp" else Vector2(68,48)
			attack_origin = Vector2(lane,floor_y-235)
			attack_goal = Vector2(lane,floor_y-footprint.y/2)
		&"curtain":
			footprint = Vector2(18,220)
			attack_origin = Vector2(home.x-side*machine.reach,floor_y-110)
			attack_goal = Vector2(home.x+side*machine.reach,floor_y-110)
	_set_state(&"telegraph")

func active_rect(fraction: float) -> Rect2:
	var t := clampf(fraction,0,1)
	var center := attack_origin.lerp(attack_goal,t)
	if move_id==&"rail": center = actor.motor.global_position
	elif move_id in [&"left_weight",&"right_weight",&"stamp"]: center = attack_origin.lerp(attack_goal,t*t)
	return Rect2(center-footprint/2,footprint)

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
	req.hazard_category = &"phase_light" if move_id==&"curtain" else &"machine_solid"
	req.hit_direction = (controller.motor.global_position-rect.get_center()).normalized()
	# An invulnerable passage consumes this swing too; leaving the head cannot produce another hit.
	damage_spent = true
	policy.submit(req)

func restore_region_state(saved: Dictionary) -> bool:
	# A rebuilt room starts with a fresh readable warning, never a half-completed blow.
	home = actor._spawn
	floor_y = home.y + machine.floor_offset
	phases.update(actor.health.current,machine.health_definition.max_health)
	_serial = int(saved.get("serial",0))
	pattern_step = _serial
	cooldown = 0.5
	_set_state(&"idle")
	return true
