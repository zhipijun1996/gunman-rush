class_name HomeWeaponSelection
extends RefCounted
## Session-only Home loadout. Real Definition/Ability objects own all weapon rules.

const BASE_IDS: Array[StringName] = [&"pulse_gun", &"shadow_shuriken", &"recoil_bomb"]
var selected_id: StringName = &"pulse_gun"

func definition(id: StringName) -> WeaponDefinition:
	if id not in BASE_IDS: return null
	var weapon := load("res://resources/weapons/%s.tres" % id) as WeaponDefinition
	return weapon if weapon != null and weapon.tier == 1 and weapon.is_valid() else null

func options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: StringName in BASE_IDS:
		var weapon := definition(id)
		if weapon != null:
			result.append({"id": String(id), "display_name": weapon.display_name, "tier": weapon.tier})
	return result

func equip(controller: PlayerController, id: StringName) -> bool:
	var weapon := definition(id)
	if not is_instance_valid(controller) or weapon == null:
		return false
	if not controller.shoot_ability.equip(weapon):
		return false
	selected_id = id
	return true

func apply(controller: PlayerController) -> bool:
	return equip(controller, selected_id)
