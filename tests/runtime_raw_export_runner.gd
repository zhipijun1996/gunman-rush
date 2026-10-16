@tool
extends SceneTree
const EXPORTER := preload("res://addons/runtime_raw_export/raw_exporter.gd")
var assertions := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
func run() -> void:
	var presets := ConfigFile.new()
	check(presets.load("res://export_presets.cfg") == OK, "actual shipping presets parse")
	for index: int in 3:
		var section := "preset.%d" % index
		var included: String = presets.get_value(section, "include_filter")
		var excluded: String = presets.get_value(section, "exclude_filter")
		var planned: Dictionary = EXPORTER.source_plan(included, excluded)
		check(planned.ok and not planned.sources.is_empty(), "actual source-bound raw plan for " + section)
		if not planned.ok: continue
		var first: String = planned.sources[0]
		check(not EXPORTER.source_plan(included, excluded + "," + first).ok, "conflicting true exclusion fails closed")
		check(not EXPORTER.source_plan("assets/region_production_v3/spaces/../source.png", "").ok, "noncanonical raw path fails closed")
		check(not EXPORTER.source_plan("assets/region_production_v3/spaces/*/source.png", "").ok, "wildcard raw selection fails closed")
		check(not EXPORTER.source_plan("assets/region_production_v3/spaces/not_a_delivered_family/source.png", "").ok, "missing family source contract fails closed")
	print("RUNTIME RAW EXPORT TESTS: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
