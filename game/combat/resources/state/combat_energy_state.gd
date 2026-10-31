class_name CombatEnergyState
extends RefCounted
## Independent combat currency, shared by weapon skills and consumers.
signal changed(current: float)
signal spent(event: String, amount: float)
var definition: CombatEnergyDefinition = preload("res://game/player/resources/combat_energy.tres")
var current := 0.0
var _receipts: Dictionary = {}
var _packets: Dictionary = {}
var _spends: Dictionary = {}
var _grants: Dictionary = {}
var _capacity_bonus := 0.0
func capacity() -> float:
	return definition.capacity + _capacity_bonus
func set_capacity_bonus(amount: float) -> void:
	if not is_finite(amount) or amount < 0: return
	var old_capacity := capacity()
	_capacity_bonus = amount
	var previous := current
	current = minf(current, capacity())
	if not is_equal_approx(previous, current) or not is_equal_approx(old_capacity, capacity()): changed.emit(current)
func grant(event: String, amount: float) -> float:
	if event.is_empty() or _grants.has(event) or not definition.is_valid() or not is_finite(amount) or amount <= 0: return 0.0
	_grants[event] = amount
	var applied := minf(amount, maxf(0.0, capacity()-current))
	current += applied
	if applied > 0: changed.emit(current)
	return applied
func can_consume(amount: float) -> bool:
	return definition.is_valid() and is_finite(amount) and amount > 0 and current+1e-9 >= amount
func consume(event: String, amount: float) -> bool:
	if event.is_empty() or _spends.has(event) or not can_consume(amount): return false
	_spends[event]=true
	current=maxf(0,current-amount)
	changed.emit(current)
	spent.emit(event, amount)
	return true
func committed_hit(packet: String, target: int, skill: bool = false, extra_gain: float = 0.0) -> void:
	if not definition.is_valid() or skill or packet.is_empty() or target == 0: return
	var receipt := "%s/%s" % [packet,target]
	if _receipts.has(receipt): return
	_receipts[receipt]=true
	if not is_finite(extra_gain) or extra_gain < 0: return
	var granted := minf(definition.target_gain+extra_gain,maxf(0,definition.packet_gain_limit-float(_packets.get(packet,0))))
	_packets[packet]=float(_packets.get(packet,0))+granted
	current=minf(capacity(),current+granted)
	changed.emit(current)
func reset() -> void:
	current=0
	_receipts.clear();_packets.clear();_spends.clear()
	_grants.clear()
	_capacity_bonus=0.0
	changed.emit(current)
