class_name EconomyReceipt
extends RefCounted

enum Status { COMMITTED, REPLAY, INVALID, STALE, CONFLICT, UNAVAILABLE, INSUFFICIENT }
var status: Status = Status.INVALID
var event_id: StringName
var item_id: StringName
var instance_id: StringName
var gear_capacity := 0
var gear_level := 0
var coins := 0

func accepted() -> bool:
	return status in [Status.COMMITTED, Status.REPLAY]

func copy() -> EconomyReceipt:
	var result := EconomyReceipt.new()
	result.status = status
	result.event_id = event_id
	result.item_id = item_id
	result.instance_id = instance_id
	result.gear_capacity = gear_capacity
	result.gear_level = gear_level
	result.coins = coins
	return result

static func rejected(reason: Status) -> EconomyReceipt:
	var result := EconomyReceipt.new()
	result.status = reason
	return result
