class_name SupplyHealEffect
extends RefCounted

static func apply(health: HealthState, amount: float, event_id: StringName) -> ActorResourceResult:
	return health.heal(ActorResourceRequest.new(event_id, health.epoch, amount, health.get_instance_id()))
