extends RefCounted
## Select a test strategy without changing the recorded argument sent to App.
static func create(recorded_layout := "") -> Node:
	var effective: String=recorded_layout if not recorded_layout.is_empty() else ThornForestRegionGenerator.CURRENT_DEPTH_LAYOUT
	var script: Script=load("res://tests/forest_bible_region_auto_trace.gd" if effective=="forest-bible-world-v15" else "res://tests/forest_depth_region_trace.gd")
	var trace: Node=script.new()
	trace.recorded_layout_version=recorded_layout
	return trace
