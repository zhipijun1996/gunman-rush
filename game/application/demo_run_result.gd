class_name DemoRunResult
extends RefCounted

enum Status { APPLIED, REPLAY, INVALID, STALE, CONFLICT, NOT_READY, TERMINAL }
var status: Status = Status.INVALID
var event_id: StringName
var reason: StringName
var stage_index := 0
var stage_type_id: StringName
var run_epoch := 0
var stage_epoch := 0

func accepted() -> bool:
	return status == Status.APPLIED or status == Status.REPLAY

func copy() -> DemoRunResult:
	var result := DemoRunResult.new()
	result.status = status
	result.event_id = event_id
	result.reason = reason
	result.stage_index = stage_index
	result.stage_type_id = stage_type_id
	result.run_epoch = run_epoch
	result.stage_epoch = stage_epoch
	return result
