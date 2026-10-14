class_name WeaponCatalog
extends RefCounted
const IDS: Array[String] = ["pulse_gun","shadow_shuriken","recoil_bomb","triple_machine_gun","sustained_laser","fan_shuriken","remote_boomerang","magnetic_mine","collapse_singularity","machine_storm","laser_cannon","blade_bloom","moon_boomerang","magnetic_storm","star_collapse"]
static func get_loadout(index: int) -> WeaponDefinition:
	return load("res://resources/weapons/%s.tres" % IDS[index]) as WeaponDefinition if index>=0 and index<IDS.size() else null
