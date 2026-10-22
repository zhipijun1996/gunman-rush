class_name ThornForestRegionGenerator
extends RefCounted
## One public version registry; old recorded forest maps retain their own algorithm.
const LEGACY := preload("res://scripts/generation/thorn_forest_region_v1.gd")
const LEGACY_VERSION := LEGACY.VERSION
const DEPTH_VERSION := "thorn-forest-region-v2"
const DEPTH_LAYOUT_V7 := "shared-tree-directional-cavities-v7"
const DEPTH_LAYOUT_V9 := "shared-tree-living-detour-v9"
const DEPTH_LAYOUT_CANOPY := "shared-tree-canopy-hunt-v10"
const DEPTH_LAYOUT_EXPEDITION := "forest-expedition-airborne-v11"
const DEPTH_LAYOUT_VERTICAL := "forest-woven-trunk-v12"
const DEPTH_LAYOUT_INTERWOVEN := "forest-interwoven-canopy-v13"
const DEPTH_LAYOUT_FRUIT := "forest-fruit-routes-v14"
const DEPTH_LAYOUT_BIBLE := "forest-bible-world-v15"
const DEPTH_LAYOUT_EXPLORATION := "forest-branching-expedition-v16"
const DEPTH_LAYOUT_VARIED := "forest-varied-bible-v17"
const DEPTH_LAYOUT_PLACES := "forest-exploration-places-v18"
const CURRENT_DEPTH_LAYOUT := DEPTH_LAYOUT_BIBLE
const DEPTH_LAYOUT_SCRIPTS := {
	DEPTH_LAYOUT_V7:"res://scripts/generation/thorn_forest_region_v2_v7.gd",
	DEPTH_LAYOUT_V9:"res://scripts/generation/thorn_forest_region_v2_v9.gd",
	DEPTH_LAYOUT_CANOPY:"res://scripts/generation/thorn_forest_region_v2_v10.gd",
	DEPTH_LAYOUT_EXPEDITION:"res://scripts/generation/thorn_forest_region_v2_v11.gd",
	DEPTH_LAYOUT_VERTICAL:"res://scripts/generation/thorn_forest_region_v2.gd",
	DEPTH_LAYOUT_INTERWOVEN:"res://scripts/generation/thorn_forest_region_v2_v13.gd",
	DEPTH_LAYOUT_FRUIT:"res://scripts/generation/thorn_forest_region_v2_v14.gd",
	DEPTH_LAYOUT_BIBLE:"res://scripts/generation/thorn_forest_region_v2_v15.gd",
	DEPTH_LAYOUT_EXPLORATION:"res://scripts/generation/thorn_forest_region_v2_v16.gd",
	DEPTH_LAYOUT_VARIED:"res://scripts/generation/thorn_forest_region_v2_v17.gd",
	DEPTH_LAYOUT_PLACES:"res://scripts/generation/thorn_forest_region_v2_v18.gd"}
# Public candidate playtest default; explicit v1 replay remains supported.
# This selection does not declare commercial or whole-region admission.
const VERSION := DEPTH_VERSION
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
		var layout: Variant = capability_snapshot.get("forest_layout_version",CURRENT_DEPTH_LAYOUT)
		if not layout is String or not DEPTH_LAYOUT_SCRIPTS.has(layout):
			return {"ok":false,"error":"Unsupported recorded forest layout"}
		var generator: RefCounted = load(DEPTH_LAYOUT_SCRIPTS[layout]).new()
		if layout == DEPTH_LAYOUT_V9:
			var north: Variant=capability_snapshot.get("forest_v9_north_return",true)
			if not north is bool: return {"ok":false,"error":"Invalid recorded v9 itinerary"}
			generator.set("known_north_return",north)
		var result: Dictionary = generator.generate(seed_value,tuning,map_index,capability_snapshot)
		if result.get("ok",false) and result.manifest.get("layout_version") != layout:
			return {"ok":false,"error":"Recorded forest layout is not implemented by its generator"}
		return result
	return {"ok":false,"error":"Unsupported recorded forest content version: "+version}

func validate(manifest: Dictionary, tuning: PlayerTuning) -> bool:
	if manifest.get("version") == LEGACY_VERSION: return LEGACY.new().validate(manifest,tuning)
	if manifest.get("version") == DEPTH_VERSION:
		var layout: Variant = manifest.get("layout_version")
		if not layout is String or not DEPTH_LAYOUT_SCRIPTS.has(layout): return false
		var generator: RefCounted = load(DEPTH_LAYOUT_SCRIPTS[layout]).new()
		if generator.validate(manifest,tuning): return true
		if layout == DEPTH_LAYOUT_V9:
			generator.set("known_north_return",false)
			return generator.validate(manifest,tuning)
		return false
	return false

static func recorded_variants() -> Array[Dictionary]:
	# Bounded deterministic replay. Never replace a saved hash with a newer map.
	var result: Array[Dictionary] = [{"version":LEGACY_VERSION,"layout":""}]
	for layout: String in DEPTH_LAYOUT_SCRIPTS:
		result.append({"version":DEPTH_VERSION,"layout":layout})
	result.append({"version":DEPTH_VERSION,"layout":DEPTH_LAYOUT_V9,"north_return":false})
	return result

static func _boss_paths(version: String, map_index: int, manifest: Dictionary = {}) -> Dictionary:
	if map_index not in [1,2] or not supported(version): return {}
	if not manifest.is_empty() and (manifest.get("version") != version or manifest.get("map_index") != map_index): return {}
	var content: Variant = manifest.get("boss_content")
	var canopy := manifest.is_empty() and version == DEPTH_VERSION and map_index == 2 and CURRENT_DEPTH_LAYOUT in [DEPTH_LAYOUT_CANOPY,DEPTH_LAYOUT_EXPEDITION,DEPTH_LAYOUT_VERTICAL,DEPTH_LAYOUT_INTERWOVEN,DEPTH_LAYOUT_FRUIT,DEPTH_LAYOUT_BIBLE,DEPTH_LAYOUT_EXPLORATION,DEPTH_LAYOUT_VARIED,DEPTH_LAYOUT_PLACES]
	if manifest.has("boss_content"):
		if version != DEPTH_VERSION or map_index != 2 or manifest.get("layout_version") not in [DEPTH_LAYOUT_CANOPY,DEPTH_LAYOUT_EXPEDITION,DEPTH_LAYOUT_VERTICAL,DEPTH_LAYOUT_INTERWOVEN,DEPTH_LAYOUT_FRUIT,DEPTH_LAYOUT_BIBLE,DEPTH_LAYOUT_EXPLORATION,DEPTH_LAYOUT_VARIED,DEPTH_LAYOUT_PLACES]: return {}
		if not content is Dictionary or content.size() != 3: return {}
		var expected := {"contract":"forest-queen-canopy-v3","scene":"res://scenes/bosses/thorn_queen_canopy.tscn","resource":"res://resources/bosses/thorn_queen_canopy.tres"}
		for key: String in expected:
			if not content.get(key) is String or content[key] != expected[key]: return {}
		canopy = true
	elif not manifest.is_empty() and version == DEPTH_VERSION and map_index == 2 and manifest.get("layout_version") in [DEPTH_LAYOUT_CANOPY,DEPTH_LAYOUT_EXPEDITION,DEPTH_LAYOUT_VERTICAL,DEPTH_LAYOUT_INTERWOVEN,DEPTH_LAYOUT_FRUIT,DEPTH_LAYOUT_BIBLE,DEPTH_LAYOUT_EXPLORATION,DEPTH_LAYOUT_VARIED,DEPTH_LAYOUT_PLACES]:
		return {}
	if canopy: return {"resource":"res://resources/bosses/thorn_queen_canopy.tres","scene":"res://scenes/bosses/thorn_queen_canopy.tscn"}
	if version == DEPTH_VERSION:
		return {"resource":"res://resources/bosses/rootbell_guardian_v2.tres" if map_index == 1 else "res://resources/bosses/thorn_queen_v2.tres","scene":"res://scenes/bosses/rootbell_guardian_v2.tscn" if map_index == 1 else "res://scenes/bosses/thorn_queen_v2.tscn"}
	return {"resource":"res://resources/bosses/thorn_guardian.tres" if map_index == 1 else "res://resources/bosses/thorn_queen.tres","scene":"res://scenes/bosses/thorn_guardian.tscn" if map_index == 1 else "res://scenes/bosses/thorn_queen.tscn"}

static func boss_definition_path(version: String, map_index: int, manifest: Dictionary = {}) -> String:
	return str(_boss_paths(version,map_index,manifest).get("resource",""))

static func boss_scene_path(version: String, map_index: int, manifest: Dictionary = {}) -> String:
	return str(_boss_paths(version,map_index,manifest).get("scene",""))

static func _pair(point: Vector2) -> Array: return LEGACY._pair(point)
static func _rect(row: Array) -> Rect2: return LEGACY._rect(row)
static func _hash(manifest: Dictionary) -> String: return LEGACY._hash(manifest)
