class_name ThornForestRegionV2V13
extends RefCounted
## Explicit new layout producer; all historical producers retain their exact bytes.
const VERSION := "thorn-forest-region-v2"
const LAYOUT_VERSION := "forest-interwoven-canopy-v13"
const BASE := preload("res://scripts/generation/thorn_forest_region_v2.gd")
const EXPEDITION := preload("res://scripts/generation/forest_interwoven_expedition.gd")
const RECIPE := preload("res://scripts/generation/thorn_forest_region_v2_v10.gd")
const LANGUAGE := preload("res://scripts/generation/forest_scene_language.gd")
const FAMILIES := BASE.FAMILIES

static func seed_for(root_seed: String,map_index: int) -> String:return BASE.seed_for(root_seed,map_index)
func generate(seed_value: String,tuning: PlayerTuning,map_index:=1,capability_snapshot: Dictionary={}) -> Dictionary:
	return generate_spatial_candidate(seed_value,tuning,map_index,capability_snapshot)
func generate_spatial_candidate(seed_value: String,tuning: PlayerTuning,map_index:=1,capability_snapshot: Dictionary={}) -> Dictionary:
	if seed_value.is_empty() or tuning==null or map_index not in [1,2] or not capability_snapshot.get("grapple",false):return {"ok":false,"error":"Interwoven forest requires actual H, tuning, seed and map1/2"}
	var abilities: Variant = capability_snapshot.get("abilities",["grapple"])
	if not abilities is Array or abilities.size()!=1 or str(abilities[0])!="grapple":return {"ok":false,"error":"Interwoven forest S2 requires H only"}
	for forbidden: String in ["wall_climb","double_jump","weapon_evolution_1","weapon_evolution_2"]:
		if capability_snapshot.get(forbidden,false):return {"ok":false,"error":"Interwoven forest cannot require "+forbidden}
	var manifest: Dictionary = _candidate(seed_value,map_index)
	if not _validate_structure(manifest,tuning):return {"ok":false,"error":"Interwoven forest manifest rejected"}
	var points: Array[Vector2] = []
	for area: Dictionary in manifest.areas:points.append(BASE._point(area.position))
	return {"ok":true,"manifest":manifest,"stage_generator_version":VERSION,"boss_arena":BASE._rect(manifest.boss_arena),"placement_points":points,"encounter_plan":{"version":VERSION,"enemies":manifest.enemies.duplicate(true)},"exit_points":[],"admission":"interwoven_first_golden_pending_real_motor_and_experience","production_pool":false}

func _candidate(seed_value: String,map_index: int) -> Dictionary:
	var manifest: Dictionary = BASE.new()._candidate(seed_value,map_index)
	manifest.layout_version = LAYOUT_VERSION
	EXPEDITION.install(manifest)
	LANGUAGE.annotate(manifest)
	manifest.topology_signature = BASE.topology_signature(manifest)
	var bounds: Rect2 = Rect2(BASE._point(manifest.spawn),Vector2.ONE)
	for row: Dictionary in manifest.platforms:bounds=bounds.merge(BASE._rect(row.rect))
	for row: Dictionary in manifest.hook_anchors:bounds=bounds.expand(BASE._point(row.position))
	bounds=bounds.grow(200)
	manifest.world_bounds=[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]
	manifest.manifest_hash=BASE._hash(manifest)
	return manifest

func validate(m: Dictionary,tuning: PlayerTuning) -> bool:return _validate_structure(m,tuning)
func validate_spatial_candidate(m: Dictionary,tuning: PlayerTuning) -> bool:return _validate_structure(m,tuning)
func _validate_structure(m: Dictionary,tuning: PlayerTuning) -> bool:
	if tuning==null or m.get("version")!=VERSION or m.get("layout_version")!=LAYOUT_VERSION or m.get("region")!="thorn_forest":return false
	if not m.get("seed") is String or m.seed.is_empty():return false
	var index: Variant = m.get("map_index")
	if typeof(index) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(index)) or float(index)!=floorf(float(index)) or int(index) not in [1,2]:return false
	if m.get("manifest_hash")!=BASE._hash(m) or m.get("production_pool")!=false or m.get("requires")!=["grapple"]:return false
	if not RandomStageGenerator.new()._same_data(m,_candidate(m.seed,int(index))) or not LANGUAGE.validate(m):return false
	for category: String in ["platforms","hook_anchors","areas","connections","enemies","rewards","geometry_instances"]:
		var ids: Dictionary = {}
		for row: Dictionary in m[category]:
			if ids.has(row.id):return false
			ids[row.id]=true
	for platform: Dictionary in m.platforms:
		if not BASE._rect(platform.rect).has_area():return false
	for name: String in ["fast","growth","high_return","change_mind","borer"]:
		if not m.routes.has(name) or m.routes[name].is_empty():return false
		var at: String = "arrival"
		for id: String in m.routes[name]:
			var edge: Dictionary = RECIPE._edge_by_id(m,id)
			if edge.is_empty() or edge.a!=at:return false
			at=str(edge.b)
		if at!=("camp" if name in ["high_return","change_mind"] else "gate_ready"):return false
	return bool(m.boss_contract.get("ok",false))
static func topology_signature(m: Dictionary) -> String:return BASE.topology_signature(m)
static func _hash(m: Dictionary) -> String:return BASE._hash(m)
static func _point(value: Array) -> Vector2:return BASE._point(value)
static func _rect(value: Array) -> Rect2:return BASE._rect(value)
