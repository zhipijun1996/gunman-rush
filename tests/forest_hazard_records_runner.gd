extends SceneTree
## PR96 metadata bridge: every recorded forest keeps damaging thorn semantics.
var checks: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var output := "res://build/forest_fruit/hazard-records.json"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"passed": ok, "label": label})
	if not ok: printerr("FOREST HAZARD RECORD FAIL: " + label)

func run() -> void:
	var registry := ThornForestRegionGenerator.new()
	var tuning := PlayerTuning.load_default()
	for variant: Dictionary in registry.recorded_variants():
		for map_index: int in [1, 2]:
			var capabilities := {"grapple": true, "abilities": ["grapple"]}
			if not str(variant.layout).is_empty(): capabilities.forest_layout_version = variant.layout
			if variant.has("north_return"): capabilities.forest_v9_north_return = variant.north_return
			var generated := registry.generate_version(variant.version, "hazard-records/thorn_forest/map_%s" % map_index, tuning, map_index, capabilities)
			var label := "%s/map%s/%s" % [variant.layout, map_index, str(variant.get("north_return", true))]
			check(generated.get("ok", false), "exact recorded layout generates / " + label)
			if not generated.get("ok", false): continue
			var assembler := ThornForestRegionAssembler.new()
			assembler.manifest = generated.manifest.duplicate(true)
			var records := assembler.world_static_hazard_records()
			var rectangles := assembler.world_static_dangers()
			check(records.size() == rectangles.size() and records.size() == generated.manifest.dangers.size(), "record and danger counts align / " + label)
			for index: int in rectangles.size():
				check(records[index].rect == rectangles[index], "original rectangle order / %s/%s" % [label, index])
				check(records[index].role == "surface" and records[index].source_kind == "forest_thorn" and not str(records[index].module_id).is_empty() and records[index].authored_id == "forest_thorn_%s" % index, "damaging thorn never pit exemption / %s/%s" % [label, index])
			cases.append({"variant": variant.duplicate(true), "map": map_index, "manifest_hash": generated.manifest.manifest_hash, "records": records.size()})
			assembler.free()
	var failures := checks.filter(func(row: Dictionary) -> bool: return not row.passed).size()
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "all_registered_forest_hazard_record_order_and_damage_role_not_route", "checks": checks, "cases": cases, "failures": failures})); file.close()
	print("FOREST HAZARD RECORDS: %s checks / %s failures" % [checks.size(), failures])
	quit(0 if failures == 0 else 1)
