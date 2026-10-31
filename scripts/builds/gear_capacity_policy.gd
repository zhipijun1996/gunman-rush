class_name GearCapacityPolicy
extends RefCounted
const PATH := "res://config/gear_capacity.json"
var initial_capacity := 0
var upgrades: Array[Dictionary] = []
var valid := false

static func load_default() -> GearCapacityPolicy:
	var policy := GearCapacityPolicy.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary or parsed.get("version") != 1: return policy
	var initial: Variant = parsed.get("initial_capacity")
	var levels: Variant = parsed.get("upgrades")
	if not initial is float and not initial is int: return policy
	if int(initial) != initial or initial <= 0 or not levels is Array: return policy
	policy.initial_capacity = int(initial)
	var previous := policy.initial_capacity
	for entry: Variant in levels:
		if not entry is Dictionary: return policy
		var capacity: Variant = entry.get("capacity")
		var price: Variant = entry.get("price")
		if not (capacity is float or capacity is int) or not (price is float or price is int): return policy
		if int(capacity) != capacity or int(price) != price or capacity != previous+2 or price < 0: return policy
		policy.upgrades.append({"capacity":int(capacity), "price":int(price)})
		previous = int(capacity)
	policy.valid = true
	return policy
