class_name ThornForestRegionV2V16
extends RefCounted
## Independent exploration recipe; v15 and all recorded predecessors stay exact.
const VERSION := "thorn-forest-region-v2"
const LAYOUT_VERSION := "forest-branching-expedition-v16"
const WORLD := preload("res://scripts/generation/forest_exploration_world.gd")

static func seed_for(root_seed: String, map_index: int) -> String:
	return root_seed + "/thorn_forest/map_%s" % map_index

func generate(seed_value: String, tuning: PlayerTuning, map_index := 1, capabilities: Dictionary = {}) -> Dictionary:
	if seed_value.is_empty() or tuning == null or map_index not in [1, 2] or not capabilities.get("grapple", false):
		return {"ok":false,"error":"Branching forest requires seed, tuning, map1/2 and actual H"}
	var abilities: Variant = capabilities.get("abilities", ["grapple"])
	if not abilities is Array or abilities.size() != 1:
		return {"ok":false,"error":"Branching forest is S2-H only"}
	if not (abilities[0] is String or abilities[0] is StringName) or str(abilities[0]) != "grapple":
		return {"ok":false,"error":"Branching forest is S2-H only"}
	for forbidden: String in ["wall_climb", "double_jump", "weapon_evolution_1", "weapon_evolution_2"]:
		if capabilities.get(forbidden, false): return {"ok":false,"error":"Ungranted ability in forest snapshot: " + forbidden}
	var manifest := _candidate(seed_value, map_index)
	if not validate(manifest, tuning): return {"ok":false,"error":"Branching forest world contract rejected"}
	var points: Array[Vector2] = []
	for area: Dictionary in manifest.areas: points.append(_point(area.position))
	return {"ok":true,"manifest":manifest,"stage_generator_version":VERSION,
		"boss_arena":_rect(manifest.boss_arena),"placement_points":points,
		"encounter_plan":{"version":VERSION,"enemies":manifest.enemies.duplicate(true)},
		"exit_points":[],"admission":"branching_world_candidate_pending_actual_Motor_and_composition_review","production_pool":false}

func generate_spatial_candidate(seed_value: String, tuning: PlayerTuning, map_index := 1, capabilities: Dictionary = {}) -> Dictionary:
	return generate(seed_value, tuning, map_index, capabilities)

func _candidate(seed_value: String, map_index: int) -> Dictionary:
	var manifest := WORLD.build(seed_value, map_index)
	manifest.manifest_hash = _hash(manifest)
	return manifest

func validate(manifest: Dictionary, tuning: PlayerTuning) -> bool:
	if tuning == null or manifest.get("version") != VERSION or manifest.get("layout_version") != LAYOUT_VERSION: return false
	if not manifest.get("seed") is String or manifest.seed.is_empty(): return false
	var index: Variant = manifest.get("map_index")
	if not (index is int or index is float) or not is_finite(float(index)) or float(index) != floorf(float(index)) or int(index) not in [1, 2]: return false
	return manifest.get("manifest_hash") == _hash(manifest) and WORLD.validate(manifest) and RandomStageGenerator.new()._same_data(manifest, _candidate(manifest.seed, int(index)))

func validate_spatial_candidate(manifest: Dictionary, tuning: PlayerTuning) -> bool:
	return validate(manifest, tuning)

static func topology_signature(manifest: Dictionary) -> String:
	return WORLD.topology_signature(manifest)

static func _hash(manifest: Dictionary) -> String:
	var value := manifest.duplicate(true)
	value.erase("manifest_hash")
	return JSON.stringify(JSON.parse_string(JSON.stringify(value, "", true)), "", true).sha256_text()

static func _point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

static func _rect(value: Array) -> Rect2:
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
