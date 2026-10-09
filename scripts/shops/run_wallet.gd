class_name RunWallet
extends RefCounted
# Explicit run currency; no Meta currency conversion exists.
var balance := 0
var _grants: Dictionary = {}

func grant(amount: int, event_id: StringName) -> bool:
	if event_id.is_empty() or amount < 0:
		return false
	if _grants.has(event_id):
		return _grants[event_id] == amount
	_grants[event_id] = amount
	balance += amount
	return true
