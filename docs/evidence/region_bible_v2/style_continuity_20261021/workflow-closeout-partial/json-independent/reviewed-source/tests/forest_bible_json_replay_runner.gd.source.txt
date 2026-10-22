extends SceneTree
## Exact current-v15 JSON equivalence, without changing raw numeric metadata.
var checks: Array[Dictionary] = []
var failures := 0
var output := "res://build/region_bible_v2/json-replay/report.json"
func check(ok: bool,label: String) -> void:
	checks.append({"check":label,"passed":ok})
	if not ok:failures+=1;printerr("BIBLE JSON REPLAY FAIL: "+label)
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	run.call_deferred()
func run() -> void:
	var producer:=ThornForestRegionV2V15.new()
	var tuning:=PlayerTuning.load_default()
	for root_seed: String in ["campaign-integration","forest-depth-hollow-00"]:
		for map_index: int in [1,2]:
			var seed_value: String=ThornForestRegionGenerator.seed_for(root_seed,map_index)
			var generated: Dictionary=producer.generate(seed_value,tuning,map_index,{"grapple":true,"abilities":["grapple"]})
			var label: String=root_seed+"/map%s"%map_index
			check(generated.get("ok",false),label+" exact actual producer")
			if not generated.get("ok",false):continue
			var m: Dictionary=generated.manifest
			var raw: String=JSON.stringify(m)
			var parsed: Dictionary=JSON.parse_string(raw)
			check(producer.validate(parsed,tuning),label+" faithful JSON accepts integral numeric fields")
			check(JSON.stringify(parsed)==JSON.stringify(JSON.parse_string(raw)),label+" validation leaves parsed data unchanged")
			for mutation: String in ["fractional_index","bool_index","fractional_geometry","missing_face","extra_surface_field","foreign_face"]:
				var bad: Dictionary=parsed.duplicate(true)
				match mutation:
					"fractional_index":bad.thorn_surfaces[0].danger_index=.5
					"bool_index":bad.thorn_surfaces[0].danger_index=false
					"fractional_geometry":bad.platforms[0].rect[0]+=.001
					"missing_face":bad.thorn_surfaces[0].erase("face")
					"extra_surface_field":bad.thorn_surfaces[0].foreign=1
					"foreign_face":bad.thorn_surfaces[0].face="left" if bad.thorn_surfaces[0].face!="left" else "up"
				bad.manifest_hash=producer._hash(bad)
				check(not producer.validate(bad,tuning),label+" rehashed "+mutation+" rejects")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"actual producers and JSON parser, no movement or visual proof","checks":checks,"failures":failures}));file.close()
	print("FOREST BIBLE JSON REPLAY: %s assertions / %s failures"%[checks.size(),failures])
	quit(0 if failures==0 else 1)
