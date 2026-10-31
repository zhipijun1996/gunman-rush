class_name SimpleRewardResult
extends RefCounted

enum Status { COMMITTED, REPLAY, INVALID, STALE, CONFLICT, UNAVAILABLE, TERMINAL }
var status: Status = Status.INVALID
var event_id: StringName
var amount_applied := 0.0
var coins := 0
var current_health := 0.0
var maximum_health := 0.0

func accepted() -> bool:
	return status in [Status.COMMITTED, Status.REPLAY]

func copy() -> SimpleRewardResult:
	var result := SimpleRewardResult.new()
	result.status = status
	result.event_id = event_id
	result.amount_applied = amount_applied
	result.coins = coins
	result.current_health = current_health
	result.maximum_health = maximum_health
	return result

static func rejected(reason: Status) -> SimpleRewardResult:
	var result := SimpleRewardResult.new()
	result.status = reason
	return result
