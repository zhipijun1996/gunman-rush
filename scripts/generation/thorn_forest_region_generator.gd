class_name ThornForestRegionGenerator
extends RefCounted
## One public version registry; old recorded forest maps retain their own algorithm.
const LEGACY := preload("res://scripts/generation/thorn_forest_region_v1.gd")
const LEGACY_VERSION := LEGACY.VERSION
# The development candidate is not promoted until its real mechanism golden review.
const VERSION := LEGACY_VERSION
const DEPTH_VERSION := "thorn-forest-region-v2"
const FAMILIES := LEGACY.FAMILIES
const TRAVERSAL := LEGACY.TRAVERSAL

static func supported(version: String) -> bool:
	return version in [LEGACY_VERSION, DEPTH_VERSION]

static func seed_for(root_seed: String, map_index: int) -> String:
	return LEGACY.seed_for(root_seed,map_index)

func generate(seed_value: String, tuning: PlayerTuning, map_index := 1, capability_snapshot: Dictionary = {}) -> Dictionary:
	return generate_version(str(capability_snapshot.get("forest_content_version",VERSION)),seed_value,tuning,map_index,capability_snapshot)

func generate_version(version: String, seed_value: String, tuning: PlayerTuning, map_index := 1, capability_snapshot: Dictionary = {}) -> Dictionary:
	if version == LEGACY_VERSION:
		return LEGACY.new().generate(seed_value,tuning,map_index,capability_snapshot)
	if version == DEPTH_VERSION:
		var generator: RefCounted = load("res://scripts/generation/thorn_forest_region_v2.gd").new()
		return generator.generate(seed_value,tuning,map_index,capability_snapshot)
	return {"ok":false,"error":"Unsupported recorded forest content version: "+version}

func validate(manifest: Dictionary, tuning: PlayerTuning) -> bool:
	if manifest.get("version") == LEGACY_VERSION: return LEGACY.new().validate(manifest,tuning)
	if manifest.get("version") == DEPTH_VERSION:
		var generator: RefCounted = load("res://scripts/generation/thorn_forest_region_v2.gd").new()
		return generator.validate(manifest,tuning)
	return false

static func boss_definition_path(version: String, map_index: int) -> String:
	if map_index not in [1,2] or not supported(version): return ""
	if version == DEPTH_VERSION:
		return "res://resources/bosses/rootbell_guardian_v2.tres" if map_index == 1 else "res://resources/bosses/thorn_queen_v2.tres"
	return "res://resources/bosses/thorn_guardian.tres" if map_index == 1 else "res://resources/bosses/thorn_queen.tres"

static func boss_scene_path(version: String, map_index: int) -> String:
	if map_index not in [1,2] or not supported(version): return ""
	if version == DEPTH_VERSION:
		return "res://scenes/bosses/rootbell_guardian_v2.tscn" if map_index == 1 else "res://scenes/bosses/thorn_queen_v2.tscn"
	return "res://scenes/bosses/thorn_guardian.tscn" if map_index == 1 else "res://scenes/bosses/thorn_queen.tscn"

static func _pair(point: Vector2) -> Array: return LEGACY._pair(point)
static func _rect(row: Array) -> Rect2: return LEGACY._rect(row)
static func _hash(manifest: Dictionary) -> String: return LEGACY._hash(manifest)
