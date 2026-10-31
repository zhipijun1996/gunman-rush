class_name MaxHealthEffect
extends RefCounted

var _targets: Dictionary = {}

func apply(health: HealthState, increase: float, event_id: StringName) -> ActorResourceResult:
	if not is_finite(increase) or increase <= 0.0:
		return health.set_max(ActorResourceRequest.new(event_id, health.epoch, -1.0, health.get_instance_id()))
	var key := "%s:%s:%s" % [health.get_instance_id(), health.epoch, event_id]
	if _targets.has(key) and _targets[key].increase != increase:
		return health.set_max(ActorResourceRequest.new(event_id, health.epoch, -1.0, health.get_instance_id()))
	if not _targets.has(key):
		_targets[key] = {"increase": increase, "target": health.capacity + increase}
	return health.set_max(ActorResourceRequest.new(event_id, health.epoch, _targets[key].target, health.get_instance_id()))
