class_name EconomyReceipt
extends RefCounted

enum Status { COMMITTED, REPLAY, INVALID, STALE, CONFLICT, UNAVAILABLE, INSUFFICIENT }
var status: Status = Status.INVALID
var event_id: StringName
var item_id: StringName
var coins := 0

func accepted() -> bool:
	return status in [Status.COMMITTED, Status.REPLAY]

func copy() -> EconomyReceipt:
	var result := EconomyReceipt.new()
	result.status = status
	result.event_id = event_id
	result.item_id = item_id
	result.coins = coins
	return result

static func rejected(reason: Status) -> EconomyReceipt:
	var result := EconomyReceipt.new()
	result.status = reason
	return result
