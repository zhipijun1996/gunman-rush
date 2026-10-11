class_name WindkeeperDamageable
extends Damageable

var encounter: WindkeeperEncounter
var primary: Damageable

func impact_style() -> StringName:
	return &"boss"

func receive_damage(context: Dictionary) -> bool:
	if encounter == null or not encounter.active: return false
	if primary == null:
		if encounter.mode not in [&"intro", &"phase_transition"]:
			encounter.armour_hit.emit(context.get("hit_point", encounter.motor.global_position + encounter.core_offset()))
		return false
	if not encounter.core_open: return false
	return (primary as WindkeeperDamageable).receive_core(context)

func receive_core(context: Dictionary) -> bool:
	if encounter == null or not encounter.active or not encounter.core_open: return false
	if not encounter.accepts_core_direction(context):
		encounter.armour_hit.emit(context.get("hit_point", encounter.motor.global_position+encounter.core_offset()))
		return false
	return super.receive_damage(context)
