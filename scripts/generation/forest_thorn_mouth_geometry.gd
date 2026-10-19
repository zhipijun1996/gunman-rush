class_name ForestThornMouthGeometry
extends RefCounted
## Reuses the independently tested side-hook / recoil thorn mouth.
## Its regional catch sits below this mouth, above any no-H starting ascent.
const VERSION := "forest-thorn-mouth-chain-v1"
const BASE := preload("res://scripts/generation/forest_directional_geometry.gd")
static func build() -> Dictionary:
	var data:=BASE.build_narrow().duplicate(true)
	data.version=VERSION
	data.id="thorn_mouth"
	data.action_program=[{"action":"H","anchor":"side_ring"},{"action":"R","direction":[-1,0]}]
	data.platforms[3].rect=[-310.0,140.0,1190.0,40.0]
	data.platforms[4].rect=[-305.0,78.0,65.0,20.0]
	data.chain_contract={"continuous_airborne":true,"midair_floor_allowed":false,"hook_restoration":"actual_contact_kick_completion","fixed_anchor_does_not_refill_shots":true,"production_pool":false,"native_verified":false}
	return data
