class_name EnemyActor
extends Node

signal defeated(actor: EnemyActor)
@export var definition: EnemyDefinition
@export var motor: EnemyMotor
@export var brain: EnemyPatrolAI
@export var damageable: Damageable
var health := HealthState.new()
var attack_behavior: EnemyAttackBehavior
var _stagger_remaining := 0.0
var _stagger_cooldown := 0.0
var _spawn := Vector2.ZERO
var _collision_layer := 0
var _collision_mask := 0
var _restoring_instance := false
var damage_feedback: DamageFeedbackDefinition = preload("res://game/combat/damage/feedback.tres")
var _damage_stun_remaining := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if definition == null or not definition.is_valid() or motor == null or brain == null or damageable == null:
		push_error("Enemy requires a valid definition and local components")
		get_tree().quit(1)
		return
	motor.add_to_group(&"grapple_target")
	_spawn = motor.global_position
	_collision_layer = motor.collision_layer
	_collision_mask = motor.collision_mask
	damageable.faction = definition.faction
	damageable.actor_id = motor.get_instance_id()
	damageable.died.connect(_on_death)
	damageable.damaged.connect(_accepted_hit)
	reset(&"initial")

func _physics_process(delta: float) -> void:
	physics_tick(delta)

func physics_tick(delta: float) -> void:
	if health.terminal:
		return
	if _damage_stun_remaining > 0:
		_damage_stun_remaining = maxf(0, _damage_stun_remaining-delta)
		# Root Bell owns a fixed rooted body; hurt pauses its phase, not its roots.
		if definition.behavior_id != &"root_bell":
			motor.step(EnemyIntent.new(),delta)
		return
	_stagger_cooldown=maxf(0,_stagger_cooldown-delta)
	if _stagger_remaining>0:
		_stagger_remaining=maxf(0,_stagger_remaining-delta)
		motor.step(EnemyIntent.new(),delta);return
	if attack_behavior != null and attack_behavior.advance(delta):
		return
	var intent := brain.sample_intent(motor.global_position)
	if motor.step(intent, delta):
		brain.on_blocked()

func reset(_policy: StringName = &"legacy_test") -> void:
	# Only new-stage or explicit historical graybox restart. Segment returns will
	# retain this actor's health and phase, not invoke reset on all world objects.
	if definition == null or not definition.is_valid():
		return
	_damage_stun_remaining = 0.0
	_stagger_remaining=0;_stagger_cooldown=0
	motor.reset_at(_spawn)
	motor.collision_layer = _collision_layer
	motor.collision_mask = _collision_mask
	motor.configure(definition)
	brain.configure(definition, _spawn.x)
	health.configure(definition.health_definition)
	damageable.bind_health(health)
	set_physics_process(not health.terminal)

func _on_death() -> void:
	if not _restoring_instance:
		if PlainsEnemyAudio.supports(self): PlainsEnemyAudio.defeated(self)
		else: GameAudio.cue(self, &"enemy_defeat")
	if attack_behavior != null: attack_behavior.cancel()
	motor.stop()
	motor.collision_layer = 0
	motor.collision_mask = 0
	set_physics_process(false)
	defeated.emit(self)

func bind_encounter(target: PlayerController, policy: FrameDamagePolicy, scope: DemoLifetime, id: StringName, safe_points: Array[Vector2]) -> void:
	if definition.behavior_id == &"patrol" or attack_behavior != null: return
	attack_behavior = EnemyBehaviorRegistry.create_behavior(definition)
	if attack_behavior == null:
		push_error("Registered enemy behavior could not be constructed: " + String(definition.behavior_id))
		return
	add_child(attack_behavior)
	attack_behavior.configure(self, target, policy, scope, id, safe_points)

# Read-only presentation input. Does not advance any clock or cache a phase.
# Health epoch and encounter target actor_epoch intentionally remain separate.
func presentation_state() -> Dictionary:
	var valid := definition != null and is_instance_valid(motor) and is_instance_valid(brain) and health != null and health.epoch > 0
	if not valid:
		var invalid := {"valid":false,"reason":"actor_not_initialized","epoch":health.epoch if health != null else -1}
		invalid.make_read_only()
		return invalid
	var phase: StringName = attack_behavior.state if is_instance_valid(attack_behavior) else &"idle"
	var elapsed: float = attack_behavior.state_time if is_instance_valid(attack_behavior) else 0.0
	var durations := {&"telegraph":definition.telegraph_duration,&"attack":definition.attack_duration,&"recovery":definition.recovery_duration}
	# This freshly allocated dictionary contains only immutable phase values.
	durations.make_read_only()
	var result := {"valid":true,"state":phase,"state_time":elapsed,"phase_durations":durations,"phase_duration":float(durations.get(phase,0.0)),"facing":brain.direction,"position":motor.global_position,"velocity":motor.velocity,"epoch":health.epoch,"terminal":health.terminal,"stable_id":definition.stable_id,"behavior_id":definition.behavior_id,"aim_direction":attack_behavior.locked_direction if is_instance_valid(attack_behavior) else Vector2(float(brain.direction),0),"source_phase":phase,"source_kind":&"behavior" if is_instance_valid(attack_behavior) else &"patrol","source_behavior_script":(attack_behavior.get_script() as Script).resource_path if is_instance_valid(attack_behavior) else ""}
	# Specialized phases may supply their own read-only phase values. Identity,
	# epoch, actual Motor coordinates and terminal authority cannot be replaced.
	if is_instance_valid(attack_behavior) and attack_behavior.has_method("presentation_state"):
		var details: Variant = attack_behavior.call("presentation_state")
		if details is Dictionary:
			for key: String in ["state","state_time","phase_duration","phase_durations"]:
				if details.has(key): result[key] = _freeze_presentation_value(details[key])
			result.source_phase = _freeze_presentation_value(result.state)
	# All default fields are scalar/value types; specialized containers were
	# isolated above. Freeze this owned shell directly instead of copying it.
	result.make_read_only()
	return result

static func _freeze_presentation_value(value: Variant) -> Variant:
	if value is Dictionary:
		var frozen: Dictionary = value.duplicate()
		for key: Variant in frozen: frozen[key] = _freeze_presentation_value(frozen[key])
		frozen.make_read_only()
		return frozen
	if value is Array:
		var frozen: Array = []
		for item: Variant in value: frozen.append(_freeze_presentation_value(item))
		frozen.make_read_only()
		return frozen
	return value

# Explicit region unload/rebuild consumer. Shared HealthState emits the restored
# terminal pose once; restoration is not a new accepted defeat/audio/drop event.
func restore_instance_health(value: float) -> bool:
	if not is_finite(value) or value<0 or value>definition.health_definition.max_health: return false
	var restored:=definition.health_definition.duplicate(true) as HealthDefinition
	restored.initial_current=value
	_restoring_instance=true
	var accepted:=health.configure(restored)
	_restoring_instance=false
	return accepted

# Region save adapters keep their existing field sets. Attack vectors belong to
# the plains schema; forest consumers append the behavior's own depth record.
# This observes local Motor coordinates and never advances or cancels behavior.
func region_snapshot(include_attack_vectors: bool = true, include_depth_state: bool = false) -> Dictionary:
	var at := motor.position
	var attack := attack_behavior
	var saved := {"health":health.current,"position":[at.x,at.y],"state":String(attack.state) if attack!=null else "idle","state_time":attack.state_time if attack!=null else 0.0,"cooldown":attack.cooldown if attack!=null else 0.0,"serial":attack._serial if attack!=null else 0}
	# The old literal fields are String keys; dot insertion would introduce
	# StringName keys. Keep the original in-memory schema as well as JSON bytes.
	if include_attack_vectors:
		saved["locked_direction"] = [attack.locked_direction.x,attack.locked_direction.y] if attack!=null else [1,0]
		saved["attack_goal"] = [attack.attack_goal.x,attack.attack_goal.y] if attack!=null else [at.x,at.y]
		saved["attack_origin"] = [attack.attack_origin.x,attack.attack_origin.y] if attack!=null else [at.x,at.y]
	saved["home"] = [attack.home.x,attack.home.y] if attack!=null else [at.x,at.y]
	saved["direction"] = brain.direction
	if include_depth_state and attack != null and attack.has_method("depth_snapshot"):
		# The forest adapter already appended this extension using a StringName.
		saved.depth_state = attack.call("depth_snapshot")
	return saved

func apply_skill_impact(unit: Vector2, stagger_seconds: float, stagger_cooldown: float, knockback_speed: float, knockback_seconds: float) -> void:
	if health.terminal or _stagger_cooldown>0:return
	_stagger_remaining=stagger_seconds;_stagger_cooldown=stagger_cooldown
	if attack_behavior!=null:attack_behavior.cancel()
	if knockback_speed>0:motor.request_knockback(unit.normalized()*knockback_speed,knockback_seconds)

func _accepted_hit(context: Dictionary) -> void:
	if health.terminal or _restoring_instance: return
	var raw_direction: Variant = context.get("hit_direction", Vector2.ZERO)
	if not raw_direction is Vector2 or not (raw_direction as Vector2).is_finite(): return
	# Grapple and active skills already own their target motion contract. HP
	# still drives the shared hurt animation/audio; generic hit motion must not
	# stop a moving hook target or extend the authored skill stagger clock.
	if PlainsEnemyAudio.supports(self): PlainsEnemyAudio.hurt(self, context)
	else: GameAudio.cue_event(self, &"enemy_hurt", &"hurt")
	if context.get("damage_type", &"") == &"grapple" or context.get("skill_attack", false) == true: return
	var direction: Vector2 = raw_direction
	if direction.is_zero_approx(): direction = Vector2(-brain.direction,0)
	# Ground actors have no gravity policy in EnemyMotor; a vertical force must
	# not leave a walking beetle permanently hovering above its authored floor.
	if not definition.aerial: direction=Vector2(signf(direction.x) if absf(direction.x)>.05 else -brain.direction,0)
	_damage_stun_remaining = damage_feedback.enemy_knockback_seconds * clampf(float(context.get("item_stagger_multiplier", 1.0)), 1.0, 1.3)
	if definition.behavior_id == &"root_bell": return
	motor.request_knockback(direction.normalized()*damage_feedback.enemy_knockback_speed,damage_feedback.enemy_knockback_seconds,not definition.aerial)
