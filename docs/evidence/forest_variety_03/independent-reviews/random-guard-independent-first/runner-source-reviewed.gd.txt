extends SceneTree
## Actual producer samples, historical-core preservation and hostile replay edits.
const NEW := preload("res://scripts/generation/thorn_forest_region_v2_v17.gd")
const OLD := preload("res://scripts/generation/thorn_forest_region_v2_v15.gd")
var output := "res://build/region_bible_v2/forest-v17-world/report.json"
var assertions := 0
var failures: Array[String] = []
var samples: Array[Dictionary] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		printerr("VARIED WORLD FAIL: "+label)

func run() -> void:
	var tuning := PlayerTuning.load_default()
	var signatures: Dictionary = {1:{},2:{}}
	var platform_shapes: Dictionary = {1:{},2:{}}
	var anchor_positions: Dictionary = {1:{},2:{}}
	for root_index: int in 10:
		for map_index: int in [1,2]:
			var seed_value := NEW.seed_for("forest-variety-%02d" % root_index,map_index)
			var generator := NEW.new()
			var result := generator.generate(seed_value,tuning,map_index,{"grapple":true,"abilities":["grapple"]})
			check(result.get("ok",false),"actual public generator / "+seed_value)
			if not result.get("ok",false): continue
			var m: Dictionary = result.manifest
			var old: Dictionary = OLD.new()._candidate(seed_value,map_index)
			for category: String in ["platforms","hook_anchors","enemies","geometry_instances"]:
				var rows: Dictionary = {}
				for row: Dictionary in m[category]: rows[str(row.id)] = row
				for original: Dictionary in old[category]:
					var key := str(original.id)
					check(rows.has(key),"old consumer retained / "+category+" / "+key)
					if not rows.has(key): continue
					for field: String in ["rect","one_way","position","definition_path","local_geometry","translation","platform_id_map","anchor_id_map"]:
						if original.has(field): check(RandomStageGenerator.new()._same_data(original[field],rows[key].get(field)),"old physical source unchanged / "+key+" / "+field)
			var added: Array = []
			var original_ids: Dictionary = {}
			for p: Dictionary in old.platforms: original_ids[str(p.id)] = true
			for p: Dictionary in m.platforms:
				if not original_ids.has(str(p.id)): added.append(p.duplicate(true))
			check(not added.is_empty(),"expanded world has real new bodies")
			for p: Dictionary in added:
				check(not str(p.id).contains("__step_") and not str(p.id).contains("_master_climb"),"no arbitrary-gap ladder producer / "+str(p.id))
			var edges: Dictionary = {}
			for edge: Dictionary in m.connections: edges[str(edge.id)] = edge
			for route_name: String in m.routes:
				var previous := ""
				for id: String in m.routes[route_name]:
					check(edges.has(id),"route edge exists / "+route_name+" / "+id)
					if not edges.has(id): break
					var edge: Dictionary = edges[id]
					check(previous.is_empty() or previous==str(edge.a),"continuous actual graph / "+route_name+" / "+id)
					previous = str(edge.b)
			var json_copy: Dictionary = JSON.parse_string(JSON.stringify(m))
			check(generator.validate(json_copy,tuning),"actual JSON replay remains valid")
			if root_index==0:
				var bad := m.duplicate(true)
				bad.platforms[-1].rect[0] += 32.0
				bad.manifest_hash = NEW._hash(bad)
				check(not generator.validate(bad,tuning),"self-consistent hash cannot admit changed real geometry")
				bad = m.duplicate(true)
				bad.layout_version = "forest-bible-world-v15"
				bad.manifest_hash = NEW._hash(bad)
				check(not generator.validate(bad,tuning),"new world cannot masquerade as old saved layout")
			var old_anchors: Dictionary = {}
			for row: Dictionary in old.hook_anchors: old_anchors[str(row.id)] = true
			var added_anchors: Array = []
			for row: Dictionary in m.hook_anchors:
				if not old_anchors.has(str(row.id)): added_anchors.append(row)
			var shape := shape_signature(added)
			var targets := anchor_signature(added_anchors)
			platform_shapes[map_index][shape] = true
			anchor_positions[map_index][targets] = true
			var signature := (shape+"/"+targets).sha256_text()
			signatures[map_index][signature] = true
			if root_index == 0:
				var renamed := added.duplicate(true)
				for row: Dictionary in renamed: row.id = "renamed_"+str(row.id)
				renamed.reverse()
				renamed.append(renamed[0].duplicate(true))
				check(shape_signature(renamed)==shape,"IDs/order/duplicate descriptions cannot fake physical contour changes")
				var moved := added.duplicate(true)
				moved[0].rect[0] += 1.0
				check(shape_signature(moved)!=shape,"one actual support move changes physical contour signature")
				var reordered_anchors := added_anchors.duplicate(true)
				for row: Dictionary in reordered_anchors: row.id = "renamed_"+str(row.id)
				reordered_anchors.reverse()
				reordered_anchors.append(reordered_anchors[0].duplicate(true))
				check(anchor_signature(reordered_anchors)==targets,"anchor ID/order/duplicates cannot fake target arrangements")
			samples.append({"seed":seed_value,"map_index":map_index,"physical_signature":signature,"platform_contour_signature":shape,"target_coordinate_signature":targets,"manifest":m})
	for map_index: int in [1,2]:
		check(signatures[map_index].size()>1,"seeds change actual supports or target coordinates on map "+str(map_index))
		check(platform_shapes[map_index].size()>1,"expanded map must have different platform rectangle arrangements (necessary, not sufficient for meaningful maps) on map "+str(map_index)+"; anchor/program/reward-only variation is insufficient")
	var data := {"scope":"20_actual_generated_worlds_structure_and_replay_not_Motor_or_FUN","signature_scope":"sorted unique physical platform rectangles/one_way and target coordinates only; no IDs, instances, programs or order", "distinct_added_platform_rectangle_arrangements":{"map1":platform_shapes[1].size(),"map2":platform_shapes[2].size()},"distinct_added_target_coordinates":{"map1":anchor_positions[1].size(),"map2":anchor_positions[2].size()},"assertions":assertions,"failures":failures,"samples":samples,"distinct_physical_worlds":{"map1":signatures[1].size(),"map2":signatures[2].size()}}
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	print("FOREST VARIED WORLD: %s assertions, %s failures / actual physical worlds=%s" % [assertions,failures.size(),JSON.stringify(data.distinct_physical_worlds)])
	quit(0 if failures.is_empty() else 1)


static func _number(value: Variant) -> float:
	return 0.0 if float(value) == 0.0 else float(value)

static func shape_signature(rows: Array) -> String:
	var unique: Dictionary = {}
	for row: Dictionary in rows:
		var rect: Array = row.rect
		unique[JSON.stringify([_number(rect[0]),_number(rect[1]),_number(rect[2]),_number(rect[3]),bool(row.one_way)])] = true
	var sorted: Array = unique.keys()
	sorted.sort()
	return JSON.stringify(sorted).sha256_text()

static func anchor_signature(rows: Array) -> String:
	var unique: Dictionary = {}
	for row: Dictionary in rows:
		unique[JSON.stringify([_number(row.position[0]),_number(row.position[1])])] = true
	var sorted: Array = unique.keys()
	sorted.sort()
	return JSON.stringify(sorted).sha256_text()
