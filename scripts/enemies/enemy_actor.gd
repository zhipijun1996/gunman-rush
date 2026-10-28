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
var damage_feedback: DamageFeedbackDefinition = preload("res://resources/damage/feedback.tres")
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
	if not _restoring_instance: GameAudio.cue(self, &"enemy_defeat")
	if attack_behavior != null: attack_behavior.cancel()
	motor.stop()
	motor.collision_layer = 0
	motor.collision_mask = 0
	set_physics_process(false)
	defeated.emit(self)

func bind_encounter(target: PlayerController, policy: FrameDamagePolicy, scope: DemoLifetime, id: StringName, safe_points: Array[Vector2]) -> void:
	if definition.behavior_id == &"patrol" or attack_behavior != null: return
	match definition.behavior_id:
		&"root_bell": attack_behavior = RootBellBehavior.new()
		&"forest_lantern": attack_behavior = ForestLanternBehavior.new()
		&"forest_seed_sentry": attack_behavior = ForestSeedSentryBehavior.new()
		&"forest_thread_spider": attack_behavior = ForestThreadSpiderBehavior.new()
		&"forest_bible_weaver": attack_behavior = ForestBibleWeaverBehavior.new()
		&"forest_crossbranch": attack_behavior = ForestCrossbranchBehavior.new()
		&"forest_bark_beetle": attack_behavior = ForestBarkBeetleBehavior.new()
		&"forest_swing_pod": attack_behavior = ForestSwingPodBehavior.new()
		_: attack_behavior = EnemyAttackBehavior.new()
	add_child(attack_behavior)
	attack_behavior.configure(self, target, policy, scope, id, safe_points)

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
	GameAudio.cue_event(self, &"enemy_hurt", &"hurt")
	if context.get("damage_type", &"") == &"grapple" or context.get("skill_attack", false) == true: return
	var direction: Vector2 = raw_direction
	if direction.is_zero_approx(): direction = Vector2(-brain.direction,0)
	# Ground actors have no gravity policy in EnemyMotor; a vertical force must
	# not leave a walking beetle permanently hovering above its authored floor.
	if not definition.aerial: direction=Vector2(signf(direction.x) if absf(direction.x)>.05 else -brain.direction,0)
	_damage_stun_remaining = damage_feedback.enemy_knockback_seconds * clampf(float(context.get("item_stagger_multiplier", 1.0)), 1.0, 1.3)
	if definition.behavior_id == &"root_bell": return
	motor.request_knockback(direction.normalized()*damage_feedback.enemy_knockback_speed,damage_feedback.enemy_knockback_seconds,not definition.aerial)
