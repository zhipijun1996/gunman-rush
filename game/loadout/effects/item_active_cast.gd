class_name ItemActiveCast
extends RefCounted
## Shared paid-cast operation for projectile actives and the large companion.
## The caller validates placement/entity limits and owns its reentrancy guard.
## Owned progress and combat energy remain in their original services.
var _host: WeakRef

func _init(host: RefCounted) -> void:
	_host = weakref(host)

# Preparation precedes the caller's casting guard, exactly as before extraction.
# Projectile actives supply the actor already captured by their activation;
# companions resolve it after the map key, preserving their original read order.
func prepare(id: StringName, player: PlayerController = null) -> Dictionary:
	var host := _host.get_ref() as RefCounted
	var stored: Dictionary = host.call("state", id)
	var sequence := int(stored.get("cast_sequence", 0)) + 1
	var map: Variant = host.call("map_key")
	var actor := player if player != null else host.call("actor") as PlayerController
	return {"id": id, "sequence": sequence, "receipt": StringName("%s/item/%s/%s/%s" % [map, actor.session_id, id, sequence])}

# Call only after preparation and setting the family's casting guard. Spending
# can synchronously notify other effects; sample the cooldown clock afterwards.
func commit(prepared: Dictionary, energy_cost: float, cooldown_seconds: float) -> bool:
	var host := _host.get_ref() as RefCounted
	var receipt: StringName = prepared.receipt
	if not bool(host.call("spend_energy", energy_cost, receipt)): return false
	var until := float(host.call("now")) + cooldown_seconds
	# Existing behavior deliberately retained: a refused progress patch does not
	# refund a paid cast. Changing that failure policy is a separate bug fix.
	host.call("patch_state", prepared.id, {"cast_sequence": prepared.sequence, "cooldown_until": until}, StringName("%s/state" % receipt))
	return true
