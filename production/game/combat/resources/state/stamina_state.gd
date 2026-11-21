class_name StaminaState
extends ActorResourceState

func configure(definition: StaminaDefinition) -> bool:
	if definition == null or not definition.is_valid():
		return false
	_initialize_state(ActorResourceSnapshot.Kind.STAMINA, definition.capacity, definition.initial_current)
	return true

func try_consume(request: ActorResourceRequest) -> ActorResourceResult:
	return _transact(&"consume", request)

func grant(request: ActorResourceRequest) -> ActorResourceResult:
	return _transact(&"grant", request)

func consume_continuous(amount: float, expected_epoch: int) -> ActorResourceResult:
	return _continuous(&"consume", amount, expected_epoch)

func grant_continuous(amount: float, expected_epoch: int) -> ActorResourceResult:
	return _continuous(&"grant", amount, expected_epoch)
