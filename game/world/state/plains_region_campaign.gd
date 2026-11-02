class_name PlainsRegionCampaign
extends RefCounted
## Two whole worlds, not a chain of combat rooms. Instances are scoped per map.
const VERSION := "plains-two-maps-v1"
const MAPS := 2
static func seed_for(root_seed: String, map_index: int) -> String:
	return root_seed if map_index == 1 else root_seed + "/plains/map_2"
static func prefix(map_index: int) -> String:
	return "plains/map_%s/" % map_index
static func role(map_index: int) -> String:
	return "mini_boss" if map_index == 1 else "region_boss"
