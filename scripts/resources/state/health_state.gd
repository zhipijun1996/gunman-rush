class_name HealthState
extends ActorResourceState

func configure(definition: HealthDefinition) -> bool:
	if definition == null or not definition.is_valid():
		return false
	_initialize_state(ActorResourceSnapshot.Kind.HEALTH, definition.max_health, definition.initial_current)
	return true

func apply_damage(request: ActorResourceRequest) -> ActorResourceResult:
	return _transact(&"damage", request)

func heal(request: ActorResourceRequest) -> ActorResourceResult:
	return _transact(&"heal", request)

func set_max(request: ActorResourceRequest) -> ActorResourceResult:
	return _transact(&"set_max", request)
