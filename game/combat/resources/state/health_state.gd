class_name HealthState
extends ActorResourceState

# Ordinary healing has one authoritative gate so pickups, map grants and item
# skills cannot bypass the heart covenant by choosing a different caller.
var normal_healing_blocked := false

func configure(definition: HealthDefinition) -> bool:
	if definition == null or not definition.is_valid():
		return false
	normal_healing_blocked = false
	_initialize_state(ActorResourceSnapshot.Kind.HEALTH, definition.max_health, definition.initial_current)
	return true

func apply_damage(request: ActorResourceRequest) -> ActorResourceResult:
	return _transact(&"damage", request)

func heal(request: ActorResourceRequest) -> ActorResourceResult:
	if normal_healing_blocked:
		# A previously committed heal receipt is still a harmless replay (and
		# conflicting/stale retries retain their original rejection semantics).
		if request != null and _receipts.has(request.event_id): return _transact(&"heal",request)
		return _result(ActorResourceResult.Status.INVALID, &"heal", request.event_id if request != null else &"")
	return _transact(&"heal", request)

func set_max(request: ActorResourceRequest) -> ActorResourceResult:
	return _transact(&"set_max", request)

# Only P18's first accepted equip uses this explicit conversion. Capacity and
# current change in one original resource transaction and emit one receipt.
func set_max_preserving_ratio(request: ActorResourceRequest) -> ActorResourceResult:
	return _transact(&"set_max_ratio", request)

func _apply(operation: StringName, amount: float, id: StringName = &"") -> ActorResourceResult:
	if operation != &"set_max_ratio": return super._apply(operation, amount, id)
	if terminal: return _result(ActorResourceResult.Status.TERMINAL, operation, id)
	var before := _current
	var ratio := _current / _capacity
	_capacity = amount
	_current = clampf(amount * ratio, 0.0, amount)
	var result := _result(ActorResourceResult.Status.APPLIED, operation, id)
	result.amount_applied = _current - before
	return result
