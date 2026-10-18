extends "res://tests/level_formal_trace.gd"
## Scoped actual-input traversal, reusing the admitted span drivers both ways.
var joint_cases: Array=[]
var target_id := ""
var target_edge: Dictionary={}
var lower_edge: Dictionary={}
var underbank_edge: Dictionary={}
func attach(application: DemoApp, selected_strategy: String, wait_ticks: int, selected_policy: String="kill_from_bank_v2") -> bool:
	if not super.attach(application,selected_strategy,wait_ticks,selected_policy): return false
	if stage.manifest.get("joint_recoil_profile",false):
		var actual:Dictionary=formal_stage.call("get_joint_recoil_snapshot")
		if not actual.get("joint_ready",false):
			print("JOINT RECOIL PREFLIGHT REFUSED: ",JSON.stringify(actual))
			return false
	for node: Dictionary in stage.manifest.nodes:
		if node.module_id=="plains_recoil_span" and not str(node.id).begins_with("tutorial"):
			target_id=str(node.id);break
	for edge: Dictionary in stage.manifest.connections:
		if target_id.begins_with(str(edge.id)+"_") and edge.kind=="horizontal": target_edge=edge;break
	for edge:Dictionary in stage.manifest.connections:
		if edge.kind=="stairs" and edge.b==target_edge.get("b","") and edge.condition=="open":
			var lower:Dictionary=PlainsRegionGenerator.new()._area(stage.manifest,str(edge.a))
			var upper:Dictionary=PlainsRegionGenerator.new()._area(stage.manifest,str(edge.b))
			if float(lower.position[1])>float(upper.position[1]):lower_edge=edge;break
	for edge:Dictionary in stage.manifest.connections:
		if edge.kind=="horizontal" and edge.b==lower_edge.get("a","") and edge.condition=="open":underbank_edge=edge;break
	return not target_edge.is_empty() and not lower_edge.is_empty() and not underbank_edge.is_empty()
func joint_case(id: String, start: int, ok: bool) -> bool:
	joint_cases.append({"id":id,"start_tick":start,"end_tick":trace_ticks,"passed":ok,"position":SNAPSHOT.pair(motor.global_position),"grounded":motor.is_on_floor(),"shots":shots,"health":controller.actor_resources.health.current,"recovery_count":_recovery_serial})
	if not ok: record_check(false,"joint challenge: "+id)
	return ok
func run_route() -> void:
	await tick(phase_wait_ticks)
	var start:=trace_ticks+1
	var ok:=await tutorial()
	if trace_cancelled(): return
	if not joint_case("original_tutorial",start,ok): finish(false,"joint_tutorial_failed");return
	current_area="area_0_1"
	start=trace_ticks+1
	ok=await follow_to(str(target_edge.a))
	if trace_cancelled(): return
	if not joint_case("actual_adjacent_entry",start,ok): finish(false,"joint_approach_failed");return
	start=trace_ticks+1
	ok=await walk_edge(target_edge,true)
	if trace_cancelled(): return
	if not joint_case("target_edge_forward",start,ok): finish(false,"joint_forward_failed");return
	current_area=str(target_edge.b)
	start=trace_ticks+1
	ok=await walk_edge(lower_edge,false)
	if trace_cancelled(): return
	if not joint_case("actual_lower_neighbor_descent",start,ok):finish(false,"joint_lower_descent_failed");return
	current_area=str(lower_edge.a)
	start=trace_ticks+1
	ok=await walk_edge(underbank_edge,false)
	if trace_cancelled(): return
	if not joint_case("actual_underbank_ferry_reverse",start,ok):finish(false,"joint_underbank_reverse_failed");return
	current_area=str(underbank_edge.a)
	start=trace_ticks+1
	ok=await walk_edge(underbank_edge,true)
	if trace_cancelled(): return
	if not joint_case("actual_underbank_ferry_forward",start,ok):finish(false,"joint_underbank_forward_failed");return
	current_area=str(lower_edge.a)
	start=trace_ticks+1
	ok=await walk_edge(lower_edge,true)
	if trace_cancelled(): return
	if not joint_case("actual_lower_neighbor_return",start,ok):finish(false,"joint_lower_return_failed");return
	current_area=str(target_edge.b)
	start=trace_ticks+1
	ok=await walk_edge(target_edge,false)
	if trace_cancelled(): return
	if not joint_case("target_edge_return",start,ok): finish(false,"joint_return_failed");return
	current_area=str(target_edge.a)
	finish(_recovery_serial==0,"route_target_reached" if _recovery_serial==0 else "joint_unexpected_recovery")
func joint_coverage() -> Dictionary:
	return {"scope":"Actual spawn/tutorial approach plus selected challenge/both adjacent bank interfaces and original lower descent/return and underlying ferry both ways; not whole-region traversal","target_id":target_id,"target_edge":target_edge,"lower_edge":lower_edge,"underbank_edge":underbank_edge,"cases":joint_cases,"complete":joint_cases.size()==8 and joint_cases.all(func(row:Dictionary)->bool:return row.passed) and _recovery_serial==0}
