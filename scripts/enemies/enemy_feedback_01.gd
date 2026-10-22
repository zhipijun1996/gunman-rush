class_name EnemyFeedback01
extends RefCounted
## ENEMY-FEEDBACK-01: presentation state only. No damage, motion, audio or drops.
## Deliberately limited to two existing definitions, in both rendering chains.
const PROFILES := {
	&"plains_charger": {"impact_pose": Vector2(1.10, .91), "death_pose": Vector2(1.12, .45), "tilt": 0.0},
	&"plains_diver": {"impact_pose": Vector2(.94, 1.06), "death_pose": Vector2(.86, .72), "tilt": .16},
}
const DEATH_SECONDS := .5 # Bounded inside PixelPlainsEnemy's read-only .65s fade.
var tuning: DamageFeedbackDefinition = preload("res://resources/damage/feedback.tres")
var hurt_remaining := 0.0
var death_elapsed := 0.0
var death_active := false
var restored_terminal := false
var accepted_hit_count := 0
var accepted_death_count := 0
var _health: HealthState
var _profile: Dictionary
var _epoch := -1
var _seen: Dictionary = {}
var _terminal := false

static func supports(definition: EnemyDefinition) -> bool:
	return definition != null and PROFILES.has(definition.stable_id)

func _init(health: HealthState, definition: EnemyDefinition) -> void:
	_health = health
	_profile = PROFILES[definition.stable_id]
	_synchronize()
	_health.changed.connect(_changed)

func _synchronize() -> void:
	_epoch = _health.epoch
	_seen.clear()
	_terminal = _health.terminal
	restored_terminal = _terminal
	hurt_remaining = 0
	death_elapsed = 0
	death_active = false

func _changed(result: ActorResourceResult) -> void:
	if result == null or result.snapshot == null: return
	if result.snapshot.epoch != _health.epoch: return
	if result.operation == &"initialize":
		_synchronize()
		return
	if _epoch != _health.epoch: _synchronize()
	if result.operation != &"damage" or result.status != ActorResourceResult.Status.APPLIED or result.amount_applied >= 0 or result.event_id.is_empty() or _terminal or _seen.has(result.event_id): return
	_seen[result.event_id] = true
	if result.snapshot.terminal:
		_terminal = true
		restored_terminal = false
		hurt_remaining = 0
		death_elapsed = 0
		death_active = true
		accepted_death_count += 1
	else:
		hurt_remaining = tuning.hurt_seconds
		accepted_hit_count += 1

func advance(delta: float) -> void:
	hurt_remaining = maxf(0, hurt_remaining - delta)
	if death_active:
		death_elapsed = minf(DEATH_SECONDS, death_elapsed + delta)
		if death_elapsed >= DEATH_SECONDS: death_active = false

func pose() -> Vector2:
	if _terminal: return _profile.death_pose
	var strength := hurt_remaining / tuning.hurt_seconds
	# Immediate impact, smooth recovery; authored locomotion keeps its own clock.
	return Vector2.ONE.lerp(_profile.impact_pose, strength * strength)

func tilt() -> float:
	return float(_profile.tilt) * (1.0 - death_elapsed / DEATH_SECONDS) if death_active else 0.0

func tint() -> Color:
	return Color.WHITE.lerp(Color(1.25, .86, .66), hurt_remaining / tuning.hurt_seconds)

func dispose() -> void:
	if _health != null and _health.changed.is_connected(_changed): _health.changed.disconnect(_changed)
	_health = null
	_seen.clear()
	hurt_remaining = 0
	death_active = false
