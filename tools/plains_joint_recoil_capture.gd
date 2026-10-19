extends "res://tools/level_formal_capture.gd"
## Actual formal region, original input timing, HP, errors and teardown.
var joint_baseline := false
func make_application() -> DemoApp:
	var baseline_mode:=OS.get_environment("JOINT_RECOIL_BASELINE")
	joint_baseline=baseline_mode in ["1","regional"]
	var result:=DemoApp.new()
	if not joint_baseline: result.set("plains_joint_recoil_candidate_requested",true)
	elif baseline_mode=="regional": result.set("plains_regional_art_candidate_requested",true)
	result.avatar_selection_id="p1_girl"
	report["joint_baseline"]=joint_baseline
	report["joint_baseline_mode"]=baseline_mode
	report.captured_scope["route_scope"]="Original tutorial/approach, one non-tutorial recoil span forward/return and original lower-neighbor descent/return and actual underlying ferry both ways; not complete-region acceptance"
	return result
func avatar_snapshot() -> Dictionary:
	var adapter:=app.get_meta("avatar_presentation",null) as Node
	return adapter.call("snapshot") if is_instance_valid(adapter) else {}
func decoration_collisions(node:Node, rows:Array)->void:
	if node is CollisionObject2D or node is CollisionShape2D or node is CollisionPolygon2D: rows.append({"path":str(node.get_path()),"class":node.get_class()})
	for child:Node in node.get_children(): decoration_collisions(child,rows)
func decoration_collision_snapshot()->Array:
	var rows:Array=[]
	if is_instance_valid(app.stage.regional_art_renderer): decoration_collisions(app.stage.regional_art_renderer,rows)
	return rows
func make_driver() -> RefCounted:
	report["joint_decoration_collisions_initial"]=decoration_collision_snapshot()
	report["joint_avatar_initial"]=avatar_snapshot()
	if app.stage.has_method("get_joint_recoil_snapshot"): report["joint_initial"]=app.stage.call("get_joint_recoil_snapshot")
	return preload("res://tests/plains_joint_recoil_trace.gd").new()
func scenery_inventory(node: Node, rows: Array) -> void:
	if app!=null and node==app.stage and node.has_method("get_joint_recoil_snapshot"):
		var descendants:Array=[]
		_inventory_children(node,descendants)
		rows.append({"path":str(node.get_path()),"semantic":"actual_joint_recoil_candidate" if not joint_baseline else "actual_before_baseline","descendants":descendants,"joint":node.call("get_joint_recoil_snapshot")})
	super.scenery_inventory(node,rows)
func save_report() -> bool:
	var extension: Dictionary={}
	collect_driver_sources("res://tools/plains_joint_recoil_capture.gd",extension)
	collect_driver_sources("res://tools/plains_joint_recoil_preview.gd",extension)
	report["capture_extension_sources"]=extension
	if driver!=null: report["joint_coverage"]=driver.joint_coverage()
	if is_instance_valid(app) and is_instance_valid(app.stage):
		report["joint_avatar_final"]=avatar_snapshot()
		report["joint_decoration_collisions_final"]=decoration_collision_snapshot()
		if app.stage.has_method("get_joint_recoil_snapshot"): report["joint_final"]=app.stage.call("get_joint_recoil_snapshot")
		if app.stage.assembler.has_method("joint_collision_snapshot"): report["joint_actual_collisions"]=app.stage.assembler.call("joint_collision_snapshot")
	return super.save_report()
