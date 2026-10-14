class_name CombatEnergyState
extends RefCounted
## Independent combat currency, shared by weapon skills and consumers.
signal changed(current: float)
var definition: CombatEnergyDefinition = preload("res://resources/player/combat_energy.tres")
var current := 0.0
var _receipts: Dictionary = {}
var _packets: Dictionary = {}
var _spends: Dictionary = {}
func can_consume(amount: float) -> bool:
	return definition.is_valid() and is_finite(amount) and amount > 0 and current+1e-9 >= amount
func consume(event: String, amount: float) -> bool:
	if event.is_empty() or _spends.has(event) or not can_consume(amount): return false
	_spends[event]=true
	current=maxf(0,current-amount)
	changed.emit(current)
	return true
func committed_hit(packet: String, target: int, skill: bool = false) -> void:
	if not definition.is_valid() or skill or packet.is_empty() or target == 0: return
	var receipt := "%s/%s" % [packet,target]
	if _receipts.has(receipt): return
	_receipts[receipt]=true
	var granted := minf(definition.target_gain,maxf(0,definition.packet_gain_limit-float(_packets.get(packet,0))))
	_packets[packet]=float(_packets.get(packet,0))+granted
	current=minf(definition.capacity,current+granted)
	changed.emit(current)
func reset() -> void:
	current=0
	_receipts.clear();_packets.clear();_spends.clear()
	changed.emit(current)
