extends "res://tools/level_formal_capture.gd"
## Explicit three-prototype place candidate. The original capture owns timing and teardown.

func make_application() -> DemoApp:
	var result := DemoApp.new()
	result.set("plains_places_candidate_requested", true)
	result.avatar_selection_id = "p1_girl"
	report["entry_context"] = "Explicit independent place-grammar candidate via DemoApp.start_plains; original player, controls, spawn, camera and bounded capture lifecycle"
	report["visual_layout_treatment"] = "original"
	report["visual_sample_treatment"] = {"catalog_path": "", "catalog_sha256": ""}
	report.captured_scope["plains_places_candidate"] = true
	report.captured_scope["pure_art_comparison_eligible"] = false
	report.captured_scope["route_scope"] = "Three resolved place prototypes, actual outward/return waypoints; not campaign or multi-seed art admission"
	return result

func _avatar_snapshot() -> Dictionary:
	var adapter := app.get_meta("avatar_presentation", null) as Node
	return adapter.call("snapshot") if is_instance_valid(adapter) else {}

func make_driver() -> RefCounted:
	report["environment_avatar_initial"] = _avatar_snapshot()
	if app.stage.has_method("get_environment_snapshot"):
		report["environment_initial_physics"] = app.stage.call("get_environment_snapshot")
	return preload("res://tests/plains_places_trace.gd").new()

func scenery_inventory(node: Node, rows: Array) -> void:
	if app != null and node == app.stage:
		var descendants: Array = []
		_inventory_children(node, descendants)
		rows.append({"path": str(node.get_path()), "class": node.get_class(), "semantic": "actual_explicit_places_candidate", "descendants": descendants, "environment_plan": node.get("environment_plan")})
	super.scenery_inventory(node, rows)

func save_report() -> bool:
	var extension: Dictionary = {}
	collect_driver_sources("res://tools/plains_places_capture.gd", extension)
	collect_driver_sources("res://tools/plains_places_preview.gd", extension)
	report["capture_extension_sources"] = extension
	if driver != null:
		report["environment_route_contract"] = driver.environment_route_contract
		report["environment_cases"] = driver.environment_cases
		report["places_route_contract"] = driver.places_route_contract
		report["places_waypoint_observations"] = driver.places_waypoint_observations
	if is_instance_valid(app) and is_instance_valid(app.stage) and app.stage.has_method("get_environment_snapshot"):
		report["environment_final_physics"] = app.stage.call("get_environment_snapshot")
		report["environment_avatar_final"] = _avatar_snapshot()
	return super.save_report()
