class_name ThornForestRegionV2V15
extends RefCounted
## New physical connections and Bible discoveries. Recorded v13/v14 stay exact.
const VERSION := "thorn-forest-region-v2"
const LAYOUT_VERSION := "forest-bible-world-v15"
const BASE := preload("res://scripts/generation/thorn_forest_region_v2_v14.gd")
const BIBLE := preload("res://scripts/generation/forest_bible_v2_layout.gd")

static func seed_for(root_seed: String, map_index: int) -> String:
	return BASE.seed_for(root_seed, map_index)

func generate(seed_value: String, tuning: PlayerTuning, map_index := 1, capabilities: Dictionary = {}) -> Dictionary:
	var result: Dictionary = BASE.new().generate(seed_value, tuning, map_index, capabilities)
	if not result.get("ok", false): return result
	var manifest := _candidate(seed_value, map_index)
	if not validate(manifest, tuning): return {"ok":false,"error":"Forest Bible world manifest rejected"}
	result.manifest = manifest
	var points: Array[Vector2] = []
	for area: Dictionary in manifest.areas: points.append(Vector2(area.position[0], area.position[1]))
	result.placement_points = points
	result.encounter_plan = {"version":VERSION,"enemies":manifest.enemies.duplicate(true)}
	result.admission = "bible_world_candidate_pending_real_Motor_and_full_composition_review"
	return result

func generate_spatial_candidate(seed_value: String, tuning: PlayerTuning, map_index := 1, capabilities: Dictionary = {}) -> Dictionary:
	return generate(seed_value, tuning, map_index, capabilities)

func _candidate(seed_value: String, map_index: int) -> Dictionary:
	var manifest: Dictionary = BASE.new()._candidate(seed_value, map_index)
	manifest.layout_version = LAYOUT_VERSION
	BIBLE.install(manifest)
	manifest.manifest_hash = BASE._hash(manifest)
	return manifest

func validate(manifest: Dictionary, tuning: PlayerTuning) -> bool:
	if tuning == null or manifest.get("version") != VERSION or manifest.get("layout_version") != LAYOUT_VERSION: return false
	if not manifest.get("seed") is String or manifest.seed.is_empty(): return false
	var index: Variant = manifest.get("map_index")
	if typeof(index) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(index)) or float(index) != floorf(float(index)) or int(index) not in [1,2]: return false
	return manifest.get("manifest_hash") == BASE._hash(manifest) and BIBLE.validate(manifest) and RandomStageGenerator.new()._same_data(manifest, _candidate(manifest.seed,int(index)))

func validate_spatial_candidate(manifest: Dictionary, tuning: PlayerTuning) -> bool:
	return validate(manifest, tuning)

static func topology_signature(manifest: Dictionary) -> String:
	return BASE.topology_signature(manifest) + "/" + str(manifest.get("bible_world_contract",{}).get("connection_variant",""))

static func _hash(manifest: Dictionary) -> String:
	return BASE._hash(manifest)
