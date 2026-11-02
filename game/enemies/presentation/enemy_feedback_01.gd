class_name EnemyFeedback01
extends RefCounted
## ENEMY-FEEDBACK-01: presentation state only. No damage, motion, audio or drops.
## Authored bodies/deaths remain limited to their own definitions. The accepted
## hit state also supplies the common live-hit template to other presentations.
const PROFILES := {
	&"plains_charger": {"impact_pose": Vector2(1.10, .91), "death_pose": Vector2(1.12, .45), "tilt": 0.0},
	&"plains_diver": {"impact_pose": Vector2(.94, 1.06), "death_pose": Vector2(.86, .72), "tilt": .16},
}
const DEATH_SECONDS := .5 # Bounded inside PixelPlainsEnemy's read-only .65s fade.
const FLASH_SECONDS := .12
var tuning: DamageFeedbackDefinition = preload("res://game/combat/damage/feedback.tres")
var hurt_remaining := 0.0
var death_elapsed := 0.0
var death_active := false
var restored_terminal := false
var accepted_hit_count := 0
var accepted_death_count := 0
var impact_remaining := 0.0
var impact_serial := 0
var last_event_id: StringName = &""
var _health: HealthState
var _profile: Dictionary
var _epoch := -1
var _seen: Dictionary = {}
var _terminal := false

static func supports(definition: EnemyDefinition) -> bool:
	# Authored body/death assets only. Other species use EnemyHitTemplate and
	# the same accepted-hit state without borrowing these species' death frames.
	return definition != null and PROFILES.has(definition.stable_id)

func _init(health: HealthState, definition: EnemyDefinition = null) -> void:
	_health = health
	var id: StringName = definition.stable_id if definition != null else &""
	_profile = PROFILES.get(id, {"impact_pose": Vector2(.94, 1.06) if definition != null and definition.aerial else Vector2(1.10, .91), "death_pose": Vector2.ONE, "tilt": 0.0})
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
	impact_remaining = 0
	last_event_id = &""

func _changed(result: ActorResourceResult) -> void:
	if result == null or result.snapshot == null: return
	if result.snapshot.epoch != _health.epoch: return
	if result.operation == &"initialize":
		_synchronize()
		return
	if _epoch != _health.epoch: _synchronize()
	if result.operation != &"damage" or result.status != ActorResourceResult.Status.APPLIED or result.amount_applied >= 0 or result.event_id.is_empty() or _terminal or _seen.has(result.event_id): return
	_seen[result.event_id] = true
	last_event_id = result.event_id
	impact_remaining = FLASH_SECONDS
	impact_serial += 1
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
	impact_remaining = maxf(0, impact_remaining - delta)
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

func flash_strength() -> float:
	return clampf(impact_remaining / (FLASH_SECONDS * .6), 0, 1)

func epoch() -> int:
	return _epoch

func dispose() -> void:
	if _health != null and _health.changed.is_connected(_changed): _health.changed.disconnect(_changed)
	_health = null
	_seen.clear()
	hurt_remaining = 0
	impact_remaining = 0
	last_event_id = &""
	death_active = false
