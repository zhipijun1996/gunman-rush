extends SceneTree
## Necessary geometry/replay checks; not a FUN or player-duration evaluator.
const NEW := preload("res://scripts/generation/thorn_forest_region_v2_v18.gd")
const OLD := preload("res://scripts/generation/thorn_forest_region_v2_v15.gd")
var output := "res://build/forest-v18/world.json"
var assertions := 0
var failures: Array[String] = []
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		printerr("PLACES WORLD FAIL: "+label)
func run() -> void:
	var tuning := PlayerTuning.load_default()
	var generator := NEW.new()
	var samples: Array = []
	var shapes := {1:{},2:{}}
	var topologies := {1:{},2:{}}
	for map_index: int in [1,2]:
		for seed_index: int in 10:
			var root_seed := "forest-places-%02d" % seed_index
			var seed_value := ThornForestRegionGenerator.seed_for(root_seed,map_index)
			var m: Dictionary = generator._candidate(seed_value,map_index)
			if not generator.validate(m,tuning):
				print("PLACES VALIDATION DIAGNOSTIC: "+JSON.stringify(diagnose(m)))
			check(generator.validate(m,tuning),"actual candidate validates/map%s/seed%s" % [map_index,seed_index])
			check(generator.validate(JSON.parse_string(JSON.stringify(m)),tuning),"actual JSON replay")
			var mutation := m.duplicate(true)
			mutation.platforms[-1].rect[0] += 1.0
			mutation.manifest_hash = OLD._hash(mutation)
			check(not generator.validate(mutation,tuning),"rehashed physical mutation rejected")
			mutation = m.duplicate(true)
			mutation.map_index = 1.5
			mutation.manifest_hash = OLD._hash(mutation)
			check(not generator.validate(mutation,tuning),"fractional map identity rejected")
			var lower: Dictionary = ForestExplorationNetwork.OLD._edge_by_id(m,"places_double_window__lower_inward_return")
			check(lower.path.size()==3 and Vector2(lower.path[1][0],lower.path[1][1]).is_equal_approx(Vector2(lower.action_start[0],lower.action_start[1])),"authored lower-window takeoff path survives regional embedding")
			var old: Dictionary = OLD.new()._candidate(seed_value,map_index)
			check(float(m.boss_arena[0]) > float(old.boss_arena[0])+500.0,"actual Boss moved beyond new progression")
			check(m.routes.places_normal_journey.has("places_seven__main") and m.routes.places_normal_journey.has("places_double_window__main"),"normal route actually crosses places")
			check(m.get("production_pool") == false and m.exploration_places_contract.get("human_timing") == "unverified","candidate does not certify timings or admission")
			var signature := physical_signature(m.platforms)
			var renamed: Array = m.platforms.duplicate(true)
			renamed.reverse()
			for row: Dictionary in renamed: row.id = "different_"+str(row.id)
			renamed.append(renamed[0].duplicate(true))
			check(physical_signature(renamed) == signature,"IDs/reorder/duplicates cannot fake physical variety")
			shapes[map_index][signature] = true
			topologies[map_index][str(m.topology_signature)] = true
			samples.append({"root_seed":root_seed,"seed":seed_value,"map_index":map_index,"manifest_hash":m.manifest_hash,"shape":signature,"topology":m.topology_signature,"variant":m.choices.exploration_places.variant,"scope":"first_place_structural_variants_not_full_map_variety"})
	for map_index: int in [1,2]:
		check(shapes[map_index].size() > 1,"each map actually changes real support arrangements")
		check(topologies[map_index].size() > 1,"sampled complete directed graphs differ; not new macro variety acceptance")
	check(ThornForestRegionGenerator.CURRENT_DEPTH_LAYOUT == "forest-bible-world-v15","old public/save default unchanged during golden development")
	var data := {"assertions":assertions,"failures":failures,"samples":samples,"distinct_shapes":{"1":shapes[1].size(),"2":shapes[2].size()},"scope":"first_connected_place_structure_and_replay_only; human_time/FUN/art/device_unverified"}
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(data))
	print("FOREST PLACES WORLD: %s assertions, %s failures" % [assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
func physical_signature(rows: Array) -> String:
	var unique: Dictionary = {}
	for row: Dictionary in rows:
		var numbers: Array = []
		for coordinate: Variant in row.rect: numbers.append(0.0 if float(coordinate) == 0.0 else float(coordinate))
		numbers.append(bool(row.one_way))
		unique[JSON.stringify(numbers)] = true
	var keys: Array = unique.keys()
	keys.sort()
	return JSON.stringify(keys).sha256_text()
func diagnose(m: Dictionary) -> Dictionary:
	var bad: Array = []
	var supports: Dictionary = {}
	for row: Dictionary in m.platforms: supports[str(row.id)] = true
	for name: String in m.routes:
		var at := ""
		for id: String in m.routes[name]:
			var edge: Dictionary = ForestExplorationNetwork.OLD._edge_by_id(m,id)
			if edge.is_empty(): bad.append("missing:"+id); break
			if not at.is_empty() and str(edge.a) != at: bad.append(name+":"+at+" -> "+str(edge.a)+"/"+id); break
			at = str(edge.b)
	for edge: Dictionary in m.connections:
		for key: String in ["from_support_id","entry_support_id","landing_support_id","support_id"]:
			if edge.has(key) and not supports.has(str(edge[key])): bad.append(str(edge.id)+":"+key+"/"+str(edge[key]))
	return {"seed":m.seed,"map":m.map_index,"scene_language":ForestSceneLanguage.validate(m),"boss":m.boss_geometry.get("ok"),"bad":bad}
