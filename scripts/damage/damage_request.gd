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
	value.hit_direction = hit_direction
	value.on_damage_applied = on_damage_applied
	value.on_committed = on_committed
	return value
