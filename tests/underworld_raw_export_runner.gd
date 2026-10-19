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
	var bindings: Dictionary = EXPORTER.underworld_source_contract()
	check(bindings.size() == 7, "seven source bindings from existing production records")
	for path: String in EXPORTER.UNDERWORLD_SOURCES:
		check(bindings.get(path, "") == FileAccess.get_sha256("res://" + path), "real production SHA binding " + path)
		var plan: Dictionary = EXPORTER.source_plan(path, "")
		check(plan.ok and plan.sources == [path], "single real FileAccess source plan " + path)
		check(not EXPORTER.source_plan(path, path).ok, "same-path exclusion rejected " + path)
		var changed := bindings.duplicate()
		changed[path] = "0".repeat(64)
		check(not EXPORTER.source_plan(path, "", changed).ok, "wrong bound SHA rejected " + path)
		changed.erase(path)
		check(not EXPORTER.source_plan(path, "", changed).ok, "missing SHA binding rejected " + path)
		changed[path] = "not-a-sha"
		check(not EXPORTER.source_plan(path, "", changed).ok, "malformed SHA rejected " + path)
		plan = EXPORTER.source_plan(path + "," + path, "")
		check(plan.ok and plan.sources.size() == 1, "duplicate explicit request is deduplicated " + path)
	for bad: String in ["assets/underworld_plains/backgrounds/*.png", "assets/underworld_plains/**/*.png", "assets/underworld_plains/terrain/../terrain/source.png", "assets/underworld_plains/actors/source_items.png", "assets/underworld_plains/backgrounds/unknown.png"]:
		check(not EXPORTER.source_plan(bad, "").ok, "noncanonical or unapproved raw selection fails closed " + bad)
	var presets := ConfigFile.new()
	check(presets.load("res://export_presets.cfg") == OK, "actual shipping presets parse")
	for index: int in 3:
		var section := "preset.%d" % index
		var includes: String = presets.get_value(section, "include_filter")
		var excludes: String = presets.get_value(section, "exclude_filter")
		var plan: Dictionary = EXPORTER.source_plan(includes, excludes)
		check(plan.ok, "actual complete raw export plan " + section)
		if not plan.ok: continue
		for path: String in EXPORTER.UNDERWORLD_SOURCES:
			check(path in plan.sources, "actual preset contains explicit bound source " + section + "/" + path)
	print("UNDERWORLD RAW EXPORT TESTS: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
