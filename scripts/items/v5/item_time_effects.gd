class_name ItemTimeEffects
extends RefCounted
## AirFocus still owns energy and the two-real-second flight limit. This module
## changes only world speed and applies explicitly accepted B06 refunds.
var _context: ItemTimeContext
var _scope := WorldFreezeScope.new()
var _was_grounded := false
var _airtime := 0

func configure(context: ItemTimeContext) -> void:
	release_world()
	_context = context
	var actor := _actor()
	if actor != null:
		actor.air_focus_ability.world_scale_resolver = world_scale
		actor.air_focus_ability.world_freeze_callback = _set_frozen
	sync()

func _actor() -> PlayerController:
	return _context.actor() if _context != null else null

func _effect(id: StringName) -> Dictionary:
	return _context.effect(id) if _context != null else {}

func sync() -> void:
	var context := _context.scoped() if _context != null else null
	var actor := _actor()
	if context == null or actor == null or not context.is_live():
		release_world()
		return
	_scope.bind(context.world_root(), actor.motor)
	if _effect(&"P06").is_empty() or not actor.air_focus_ability.active or actor.actor_resources.health.current < actor.actor_resources.health.capacity:
		release_world()

func advance(_real_delta: float, _world_delta: float) -> void:
	var context := _context.scoped() if _context != null else null
	var actor := _actor()
	if context == null or actor == null or not context.is_live():
		release_world()
		return
	var grounded := actor.motor.is_on_floor()
	if _was_grounded and not grounded: _airtime += 1
	_was_grounded = grounded
	sync()
	# Capture projectiles spawned since the initial freeze as well.
	if _scope.frozen:
		_scope.set_frozen(true)
		_scope.advance_contacts()

func map_entered(_key: StringName) -> void:
	release_world()
	_was_grounded = false
	_airtime += 1
	sync()

func world_scale(default_scale: float) -> float:
	var actor := _actor()
	if actor == null: return default_scale
	var moon := _effect(&"P06")
	if not moon.is_empty() and actor.actor_resources.health.current >= actor.actor_resources.health.capacity and not actor.actor_resources.health.terminal:
		return float(moon.get("world_time_scale_while_air_aiming", 0.0))
	var pendulum := _effect(&"N01")
	return float(pendulum.get("world_slow_scale", default_scale)) if not pendulum.is_empty() else default_scale

func _set_frozen(value: bool) -> void:
	var context := _context.scoped() if _context != null else null
	var actor := _actor()
	if not value or context == null or actor == null or not context.is_live():
		release_world()
		return
	_scope.bind(context.world_root(), actor.motor)
	_scope.set_frozen(true)

func world_is_frozen() -> bool:
	return _scope.frozen

func refresh_world_scope() -> void:
	if _scope.frozen: _scope.set_frozen(true)

func release_world() -> void:
	_scope.release()

func on_hit(event: Dictionary) -> void:
	var context := _context.scoped() if _context != null else null
	var actor := _actor()
	var params := _effect(&"B06")
	if context == null or actor == null or params.is_empty() or bool(event.get("skill", false)) or bool(event.get("hook", false)) or not bool(event.get("primary",true)) or not bool(event.get("airborne", false)) or actor.motor.is_on_floor(): return
	if not context.is_live(): return
	var state := context.state(&"B06")
	var same_airtime := int(state.get("refund_airtime", -1)) == _airtime
	var refunded := float(state.get("airtime_refunded", 0.0)) if same_airtime else 0.0
	var packets: Dictionary = (state.get("refund_packets", {}) as Dictionary).duplicate() if same_airtime else {}
	var packet := "%s/%s" % [event.get("session", actor.session_id), event.get("packet", -1)]
	if packets.has(packet) or int(event.get("packet", -1)) < 0: return
	var available := maxf(0.0, float(params.get("airtime_refund_cap", 0.0)) - refunded)
	var amount := minf(available, float(params.get("air_hit_refund", 0.0)))
	packets[packet] = true
	var applied := 0.0
	if amount > 0.0:
		var stamina := actor.air_focus_ability.stamina_state
		var receipt := StringName("B06/%s/%s/%s" % [actor.session_id, _airtime, packet])
		var result := stamina.grant(ActorResourceRequest.new(receipt, stamina.epoch, amount, stamina.get_instance_id()))
		if result.status == ActorResourceResult.Status.APPLIED: applied = result.amount_applied
	context.patch_state(&"B06", {"refund_airtime":_airtime, "airtime_refunded":refunded + applied, "refund_packets":packets}, StringName("B06/refund/%s/%s" % [_airtime, packet]))
	if applied > 0.0: context.cue(&"time_refund", actor.motor.global_position, {"amount":applied})

func snapshot() -> Dictionary:
	return {"world":_scope.snapshot(), "airtime":_airtime}
