extends RefCounted
## Select a test strategy without changing the recorded argument sent to App.
static func create(recorded_layout := "") -> Node:
	var effective: String=recorded_layout if not recorded_layout.is_empty() else ThornForestRegionGenerator.CURRENT_DEPTH_LAYOUT
	var script: Script=load("res://tests/forest_bible_region_auto_trace.gd" if effective=="forest-bible-world-v15" else "res://tests/forest_depth_region_trace.gd")
	var trace: Node=script.new()
	trace.recorded_layout_version=recorded_layout
	return trace

static func create_ecology(recorded_layout := "") -> Node:
	return _create_specialized(recorded_layout,"forest_bible_ecology_trace.gd","forest_depth_ecology_trace.gd")

static func create_lift(recorded_layout := "") -> Node:
	return _create_specialized(recorded_layout,"forest_bible_lift_trace.gd","forest_depth_lift_trace.gd")

static func _create_specialized(recorded_layout: String,bible_path: String,historical_path: String) -> Node:
	var effective: String=recorded_layout if not recorded_layout.is_empty() else ThornForestRegionGenerator.CURRENT_DEPTH_LAYOUT
	var script: Script=load("res://tests/"+(bible_path if effective=="forest-bible-world-v15" else historical_path))
	var trace: Node=script.new()
	trace.recorded_layout_version=recorded_layout
	return trace
