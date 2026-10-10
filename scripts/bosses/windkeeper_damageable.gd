class_name WindkeeperDamageable
extends Damageable

var encounter: WindkeeperEncounter
var primary: Damageable

func receive_damage(context: Dictionary) -> bool:
	if encounter == null or not encounter.active or not encounter.core_open:
		return false
	if primary != null:
		return primary.receive_damage(context)
	return super.receive_damage(context)
