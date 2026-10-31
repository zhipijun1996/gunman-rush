class_name ThornDamageable
extends Damageable
var encounter: Node
func impact_style() -> StringName: return &"boss"
func receive_damage(context: Dictionary) -> bool:
	if not is_instance_valid(encounter) or not encounter.active or not encounter.core_open: return false
	if not encounter.accepts_core_direction(context):
		encounter.armour_hit.emit(context.get("hit_point", encounter.motor.global_position))
		GameAudio.cue(self, &"armour")
		return false
	return super.receive_damage(context)
