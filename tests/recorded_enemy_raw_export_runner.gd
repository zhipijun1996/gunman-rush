@tool
extends SceneTree
const EXPORTER := preload("res://addons/runtime_raw_export/raw_exporter.gd")
const SOURCE := "resources/enemies/legacy/plains_charger_v2.tres"
const EXPECTED := "1afd5e34d497e3850d794b028fd5fe5407d3722fcd451d862f4c14a67ca98fc0"
var assertions := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	assertions+=1
	if not ok:
		failures+=1
		printerr("RECORDED ENEMY RAW EXPORT: "+label)
func run() -> void:
	var contract: Dictionary=EXPORTER.recorded_enemy_contract()
	check(contract=={SOURCE:EXPECTED},"exact single historical source comes from the gameplay registry")
	var presets := ConfigFile.new()
	check(presets.load("res://export_presets.cfg")==OK,"shipping presets parse")
	for index: int in 3:
		var section := "preset.%d" % index
		var included: String=presets.get_value(section,"include_filter")
		var excluded: String=presets.get_value(section,"exclude_filter")
		var plan: Dictionary=EXPORTER.recorded_enemy_plan(included,excluded)
		check(plan.ok and plan.sources==[SOURCE],"shipping preset exports only the exact retained Definition: "+section)
		check(not EXPORTER.recorded_enemy_plan(included+","+SOURCE,excluded).ok,"duplicate historical include rejects: "+section)
		check(not EXPORTER.recorded_enemy_plan(included,excluded+","+SOURCE).ok,"exact exclusion conflict rejects: "+section)
		check(not EXPORTER.recorded_enemy_plan(included,excluded+",resources/enemies/legacy/*").ok,"wildcard exclusion conflict rejects: "+section)
	check(not EXPORTER.recorded_enemy_plan("","").ok,"missing original bytes cannot silently ship remap only")
	check(not EXPORTER.recorded_enemy_plan("resources/enemies/legacy/*.tres","").ok,"wildcard source admission rejects")
	check(not EXPORTER.recorded_enemy_plan("resources/enemies/legacy/unknown.tres","").ok,"unregistered source admission rejects")
	check(not EXPORTER.recorded_enemy_plan(SOURCE,"",{SOURCE:"0".repeat(64)}).ok,"wrong source SHA rejects real bytes")
	check(EXPORTER.source_bytes_sha256(FileAccess.get_file_as_bytes("res://"+SOURCE))==EXPECTED,"export reads the original bytes, not just a trusted constant")
	print("RECORDED ENEMY RAW EXPORT TESTS: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures==0 else 1)
