class_name DamageRequest
extends RefCounted

enum Kind { MONSTER, ENVIRONMENT }
var token: DemoToken
var event_id: StringName
var source_id: StringName
var target_id: StringName
var kind := Kind.MONSTER
var amount := 1.0
var health_epoch := 0
var actor_epoch := 0
var physics_tick := 0
# Explicit semantic exceptions; an environment spike is not automatically a
# fall or forced run failure. Item defenses never cancel these exceptions.
var fall := false
var forced_failure := false
# This flag alone grants no admission. FrameDamagePolicy only admits a derived
# request minted by its bound Damageable bridge and the current ItemRuntime.
var item_effect_damage := false
# Revalidated immediately before an authenticated item's HP commit. Admission
# alone cannot keep an unloaded source or a cancelled weapon action alive.
var effect_source_valid: Callable
# Direction of travel/force, away from the actual source. Zero is a valid fallback.
var hit_direction := Vector2.ZERO
var on_damage_applied: Callable
var on_committed: Callable

func copy() -> DamageRequest:
	var value := DamageRequest.new()
	value.token = token.copy() if token != null else null
	value.event_id = event_id
	value.source_id = source_id
	value.target_id = target_id
	value.kind = kind
	value.amount = amount
	value.health_epoch = health_epoch
	value.actor_epoch = actor_epoch
	value.physics_tick = physics_tick
	value.fall = fall
	value.forced_failure = forced_failure
	value.item_effect_damage = item_effect_damage
	value.effect_source_valid = effect_source_valid
	value.hit_direction = hit_direction
	value.on_damage_applied = on_damage_applied
	value.on_committed = on_committed
	return value
