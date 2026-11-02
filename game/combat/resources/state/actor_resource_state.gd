class_name ActorResourceState
extends RefCounted

signal changed(result: ActorResourceResult)
var current: float:
	get: return _current
var capacity: float:
	get: return _capacity
var epoch: int:
	get: return _epoch
var terminal: bool:
	get: return _kind == ActorResourceSnapshot.Kind.HEALTH and _current <= 0.0
var _kind: ActorResourceSnapshot.Kind
var _current := 0.0
var _capacity := 0.0
var _epoch := 0
var _receipts: Dictionary = {}

func snapshot() -> ActorResourceSnapshot:
	var result := ActorResourceSnapshot.new()
	result.kind = _kind
	result.epoch = _epoch
	result.current = _current
	result.capacity = _capacity
	result.terminal = terminal
	return result

func _initialize_state(kind: ActorResourceSnapshot.Kind, maximum: float, initial: float) -> void:
	_kind = kind
	_capacity = maximum
	_current = initial
	_epoch += 1
	_receipts.clear()
	var result := _result(ActorResourceResult.Status.APPLIED, &"initialize")
	changed.emit(result)

func _result(status: ActorResourceResult.Status, operation: StringName, id: StringName = &"") -> ActorResourceResult:
	var result := ActorResourceResult.new()
	result.status = status
	result.operation = operation
	result.event_id = id
	result.snapshot = snapshot()
	return result

func _transact(operation: StringName, request: ActorResourceRequest) -> ActorResourceResult:
	if request == null or request.event_id.is_empty() or not is_finite(request.amount) or request.amount <= 0.0 or _epoch == 0:
		return _result(ActorResourceResult.Status.INVALID, operation)
	if request.expected_epoch != _epoch or request.expected_instance_id != get_instance_id():
		return _result(ActorResourceResult.Status.STALE, operation, request.event_id)
	if _receipts.has(request.event_id):
		var receipt: Dictionary = _receipts[request.event_id]
		if receipt.operation != operation or receipt.amount != request.amount:
			return _result(ActorResourceResult.Status.CONFLICT, operation, request.event_id)
		var replay: ActorResourceResult = receipt.result.copy()
		replay.status = ActorResourceResult.Status.REPLAY if replay.accepted() else replay.status
		return replay
	var result := _apply(operation, request.amount, request.event_id)
	# Copy before emission: a UI listener cannot corrupt state or the retry receipt.
	_receipts[request.event_id] = {"operation": operation, "amount": request.amount, "result": result.copy()}
	if result.status == ActorResourceResult.Status.APPLIED and (result.amount_applied != 0.0 or operation == &"set_max"):
		changed.emit(result.copy())
	return result

func _apply(operation: StringName, amount: float, id: StringName = &"") -> ActorResourceResult:
	if terminal:
		return _result(ActorResourceResult.Status.TERMINAL, operation, id)
	var before := _current
	match operation:
		&"damage": _current = maxf(0.0, _current - amount)
		&"heal", &"grant": _current = minf(_capacity, _current + amount)
		&"set_max":
			_capacity = amount
			_current = minf(_current, _capacity)
		&"consume":
			if amount > _current:
				return _result(ActorResourceResult.Status.INSUFFICIENT, operation, id)
			_current = maxf(0.0, _current - amount)
		_:
			return _result(ActorResourceResult.Status.INVALID, operation, id)
	var result := _result(ActorResourceResult.Status.APPLIED, operation, id)
	result.amount_applied = _current - before
	return result

# Continuous immediate pulses deliberately do not allocate per-frame receipts.
# Delayed/retried grants must use the public transactional methods instead.
func _continuous(operation: StringName, amount: float, expected_epoch: int) -> ActorResourceResult:
	if expected_epoch != _epoch:
		return _result(ActorResourceResult.Status.STALE, operation)
	if _epoch == 0 or not is_finite(amount) or amount <= 0.0:
		return _result(ActorResourceResult.Status.INVALID, operation)
	var result := _apply(operation, amount)
	if result.status == ActorResourceResult.Status.APPLIED and result.amount_applied != 0.0:
		changed.emit(result.copy())
	return result
