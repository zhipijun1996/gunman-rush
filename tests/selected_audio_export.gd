@tool
extends SceneTree
const EXPORTER := preload("res://addons/runtime_raw_export/raw_exporter.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
func run() -> void:
	var presets := ConfigFile.new()
	check(presets.load("res://export_presets.cfg") == OK, "shipping presets load")
	var contract := EXPORTER.selected_audio_contract()
	check(contract.size() == 16, "both real manifests bind sixteen originals")
	for index: int in 3:
		var section := "preset.%d" % index
		var included: String = presets.get_value(section, "include_filter")
		var excluded: String = presets.get_value(section, "exclude_filter")
		var plan := EXPORTER.selected_audio_plan(included, excluded)
		check(plan.ok and plan.sources.size() == 16, section + " complete valid audio closure")
		var first: String = EXPORTER.SELECTED_AUDIO_SOURCES[0]
		check(not EXPORTER.selected_audio_plan(included.replace(first + ",", ""), excluded).ok, "missing original rejected")
		check(not EXPORTER.selected_audio_plan(included + "," + first, excluded).ok, "duplicate rejected")
		check(not EXPORTER.selected_audio_plan(included + ",assets/audio/ambience_v1/*.wav", excluded).ok, "wildcard rejected")
		check(not EXPORTER.selected_audio_plan(included + ",assets/audio/ambience_v1/unknown.wav", excluded).ok, "unknown original rejected")
		check(not EXPORTER.selected_audio_plan(included, excluded + "," + first).ok, "conflicting exclusion rejected")
		var bad := contract.duplicate(true)
		bad[first].sha256 = "0".repeat(64)
		check(not EXPORTER.selected_audio_plan(included, excluded, bad).ok, "wrong SHA rejected without modifying original")
		bad = contract.duplicate(true)
		bad[first].bytes = -1
		check(not EXPORTER.selected_audio_plan(included, excluded, bad).ok, "invalid length rejected")
	print("SELECTED_AUDIO_EXPORT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
