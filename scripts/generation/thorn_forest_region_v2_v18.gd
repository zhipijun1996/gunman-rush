class_name ThornForestRegionV2V18
extends RefCounted
## Versioned candidate. Historical source/producers and ordinary default stay15.
const VERSION := "thorn-forest-region-v2"
const LAYOUT_VERSION := "forest-exploration-places-v18"
const BASE := preload("res://scripts/generation/thorn_forest_region_v2_v15.gd")
const NETWORK := preload("res://scripts/generation/forest_exploration_network.gd")

static func seed_for(root_seed: String,map_index: int) -> String:
	return BASE.seed_for(root_seed,map_index)

func generate(seed_value: String,tuning: PlayerTuning,map_index := 1,capabilities: Dictionary = {}) -> Dictionary:
	if seed_value.is_empty() or tuning == null or map_index not in [1,2] or not capabilities.get("grapple",false):
		return {"ok":false,"error":"Exploration places require seed, tuning, map1/2 and actual H"}
	var abilities: Variant = capabilities.get("abilities",["grapple"])
	if not abilities is Array or abilities.size() != 1 or not (abilities[0] is String or abilities[0] is StringName) or str(abilities[0]) != "grapple":
		return {"ok":false,"error":"Exploration places are S2-H only"}
	for forbidden: String in ["wall_climb","double_jump","weapon_evolution_1","weapon_evolution_2"]:
		if capabilities.get(forbidden,false): return {"ok":false,"error":"Ungranted forest ability: "+forbidden}
	var m := _candidate(seed_value,map_index)
	if not validate(m,tuning): return {"ok":false,"error":"Exploration places contract rejected"}
	var points: Array[Vector2] = []
	for area: Dictionary in m.areas: points.append(Vector2(float(area.position[0]),float(area.position[1])))
	return {"ok":true,"manifest":m,"stage_generator_version":VERSION,"boss_arena":Rect2(float(m.boss_arena[0]),float(m.boss_arena[1]),float(m.boss_arena[2]),float(m.boss_arena[3])),"placement_points":points,"encounter_plan":{"version":VERSION,"enemies":m.enemies.duplicate(true)},"exit_points":[],"admission":"exploration_places_candidate_new_expansion_pending_native_art_and_playtest","production_pool":false}

func generate_spatial_candidate(seed_value: String,tuning: PlayerTuning,map_index := 1,capabilities: Dictionary = {}) -> Dictionary:
	return generate(seed_value,tuning,map_index,capabilities)

func _candidate(seed_value: String,map_index: int) -> Dictionary:
	var m: Dictionary = BASE.new()._candidate(seed_value,map_index)
	m.layout_version = LAYOUT_VERSION
	NETWORK.install(m)
	m.manifest_hash = BASE._hash(m)
	return m

func validate(m: Dictionary,tuning: PlayerTuning) -> bool:
	if tuning == null or m.get("version") != VERSION or m.get("layout_version") != LAYOUT_VERSION: return false
	if not m.get("seed") is String or m.seed.is_empty(): return false
	var index: Variant = m.get("map_index")
	if not (index is int or index is float) or not is_finite(float(index)) or float(index) != floorf(float(index)) or int(index) not in [1,2]: return false
	return m.get("manifest_hash") == BASE._hash(m) and NETWORK.validate(m) and RandomStageGenerator.new()._same_data(m,_candidate(m.seed,int(index)))

func validate_spatial_candidate(m: Dictionary,tuning: PlayerTuning) -> bool:
	return validate(m,tuning)

static func topology_signature(m: Dictionary) -> String:
	return str(m.get("topology_signature",""))

static func _hash(m: Dictionary) -> String:
	return BASE._hash(m)
