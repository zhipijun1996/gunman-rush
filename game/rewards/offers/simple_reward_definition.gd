class_name SimpleRewardDefinition
extends Resource

enum Kind { COINS, HEAL_CURRENT }
@export var stable_id: StringName
@export var definition_version := 1
@export var kind: Kind = Kind.COINS
@export var amount := 0.0

func is_valid() -> bool:
	return not stable_id.is_empty() and definition_version >= 1 and kind in [Kind.COINS, Kind.HEAL_CURRENT] and is_finite(amount) and amount > 0.0 and (kind != Kind.COINS or (amount == floor(amount) and amount <= 2147483647.0))
