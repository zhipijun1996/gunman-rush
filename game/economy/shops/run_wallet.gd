class_name RunWallet
extends RefCounted
# Explicit run currency; no Meta currency conversion exists.
var balance := 0
var _grants: Dictionary = {}

# Shop retains the purchase receipt and synchronous debit/refund boundary.
# These operations own the balance mutation without creating another ledger.
func spend(amount: int) -> bool:
	if amount < 0 or amount > balance: return false
	balance -= amount
	return true

func refund(amount: int) -> bool:
	if amount < 0: return false
	balance += amount
	return true

func discard_balance() -> void:
	# Preserve grant receipts until this run wallet is released: a late replay
	# must not mint currency simply because the run's balance was discarded.
	balance = 0

func grant(amount: int, event_id: StringName) -> bool:
	if event_id.is_empty() or amount < 0:
		return false
	if _grants.has(event_id):
		return _grants[event_id] == amount
	_grants[event_id] = amount
	balance += amount
	return true
