extends "res://tools/level_formal_capture.gd"
## Opt-in full formal region; original timing, damage and strict teardown owner.
func make_application() -> DemoApp:
	var result := DemoApp.new()
	result.set("plains_regional_art_candidate_requested",true)
	result.avatar_selection_id = "p1_girl"
	report["entry_context"] = "Explicit regional art candidate over the full formal PlainsRegionGenerator; not the places chain"
	report.captured_scope["regional_art_candidate"] = true
	report.captured_scope["pure_art_comparison_eligible"] = false
	report.captured_scope["route_scope"] = "Original tutorial, actual rewards and optional deep loops, all ordinary area centers, final Boss preparation entrance; actual coverage receipt authoritative"
	return result

func avatar_snapshot() -> Dictionary:
	var adapter := app.get_meta("avatar_presentation",null) as Node
	return adapter.call("snapshot") if is_instance_valid(adapter) else {}

func make_driver() -> RefCounted:
	report["regional_avatar_initial"] = avatar_snapshot()
	if app.stage.has_method("get_regional_art_snapshot"):
		report["regional_art_initial"] = app.stage.call("get_regional_art_snapshot")
	return preload("res://tests/plains_regional_art_trace.gd").new()

func scenery_inventory(node: Node, rows: Array) -> void:
	if app != null and node == app.stage:
		var descendants: Array = []
		_inventory_children(node,descendants)
		rows.append({"path":str(node.get_path()),"class":node.get_class(),"semantic":"actual_full_regional_art_candidate","descendants":descendants,"regional_art":node.call("get_regional_art_snapshot") if node.has_method("get_regional_art_snapshot") else {}})
	super.scenery_inventory(node,rows)

func save_report() -> bool:
	var extension: Dictionary = {}
	collect_driver_sources("res://tools/plains_regional_art_capture.gd",extension)
	collect_driver_sources("res://tools/plains_regional_art_preview.gd",extension)
	report["capture_extension_sources"] = extension
	if driver != null:
		report["regional_coverage"] = driver.regional_coverage()
		report["regional_cases"] = driver.regional_cases
	if is_instance_valid(app) and is_instance_valid(app.stage) and app.stage.has_method("get_regional_art_snapshot"):
		report["regional_art_final"] = app.stage.call("get_regional_art_snapshot")
		report["regional_avatar_final"] = avatar_snapshot()
	return super.save_report()
