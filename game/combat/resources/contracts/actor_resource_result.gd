class_name ActorResourceResult
extends RefCounted

enum Status { APPLIED, REPLAY, INVALID, STALE, CONFLICT, TERMINAL, INSUFFICIENT }
var status: Status = Status.INVALID
var event_id: StringName
var operation: StringName
var amount_applied := 0.0
var snapshot: ActorResourceSnapshot

func accepted() -> bool:
	return status == Status.APPLIED or status == Status.REPLAY

func copy() -> ActorResourceResult:
	var result := ActorResourceResult.new()
	result.status = status
	result.event_id = event_id
	result.operation = operation
	result.amount_applied = amount_applied
	result.snapshot = snapshot.copy()
	return result
