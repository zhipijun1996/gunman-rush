extends "res://tests/level_formal_trace.gd"
## Full-region input itinerary on the live formal consumer. Never relocates actors.
var regional_visits: Dictionary = {}
var regional_cases: Array = []
var regional_expected: Array[String] = []
var regional_excluded: Array = []

func attach(application: DemoApp, selected_strategy: String, wait_ticks: int, selected_policy: String = "kill_from_bank_v2") -> bool:
	if not super.attach(application, selected_strategy, wait_ticks, selected_policy): return false
	for area: Dictionary in stage.manifest.areas:
		if area.role == "boss":
			regional_excluded.append({"id":area.id,"reason":"Boss arena/fight excluded; actual preparation junction is required"})
		elif area.role == "tutorial":
			regional_excluded.append({"id":area.id,"reason":"Tutorial certified by original ordered module traversal, not area-center sampling"})
		else: regional_expected.append(str(area.id))
	observe_regional_visit()
	return true

func observe_regional_visit() -> void:
	if not is_instance_valid(motor) or not motor.is_on_floor(): return
	for area: Dictionary in stage.manifest.areas:
		var point := Vector2(area.position[0],area.position[1])
		if motor.global_position.distance_to(point) <= 3.0 and not regional_visits.has(str(area.id)):
			regional_visits[str(area.id)] = {"tick":trace_ticks,"position":SNAPSHOT.pair(motor.global_position),"expected":area.position.duplicate(),"grounded":motor.is_on_floor(),"health":controller.actor_resources.health.current}

func tick(count: int = 1) -> void:
	for unused: int in count:
		await super.tick(1)
		if trace_cancelled(): return
		observe_regional_visit()

func regional_case(id: String, started: int, ok: bool) -> bool:
	regional_cases.append({"id":id,"start_tick":started,"end_tick":trace_ticks,"passed":ok,"position":SNAPSHOT.pair(motor.global_position),"health":controller.actor_resources.health.current,"recovery_count":_recovery_serial})
	if not ok: record_check(false,"regional itinerary: " + id)
	return ok

func run_route() -> void:
	if trace_cancelled(): return
	await tick(phase_wait_ticks)
	var started := trace_ticks + 1
	var ok := await tutorial()
	if trace_cancelled(): return
	observed_edges.append({"id":"tutorial","forward":true,"start_tick":started,"end_tick":trace_ticks,"reached":ok})
	if not regional_case("original_tutorial",started,ok): finish(false,"regional_tutorial_failed");return
	current_area = "area_0_1"
	# Use original resource/offer/return transactions, including the real creek
	# excursion where present; do not claim caches merely by passing a junction.
	started = trace_ticks + 1
	ok = await aware_growth()
	if trace_cancelled(): return
	if not regional_case("two_medium_rewards_and_camp",started,ok): finish(false,"regional_growth_failed");return
	for id: String in ["deep_high","deep_region_top"]:
		started = trace_ticks + 1
		var entry := ""
		for edge: Dictionary in stage.manifest.connections:
			if edge.b == id and edge.kind == "challenge": entry = str(edge.a)
		ok = not entry.is_empty() and await follow_to(entry)
		if ok: ok = await deep_trial(id)
		if trace_cancelled(): return
		if not regional_case(id,started,ok): finish(false,"regional_deep_failed/"+id);return
		for edge: Dictionary in stage.manifest.connections:
			if edge.a == id and edge.kind == "drop": current_area = str(edge.b)
	# Greedy shortest declared route to an unvisited ordinary junction. Geometry
	# is never synthesized by this observer; only existing original edge drivers.
	for unused: int in regional_expected.size():
		var goal := ""
		var best_cost := INF
		for area_id: String in regional_expected:
			if regional_visits.has(area_id) or area_id.begins_with("deep_"): continue
			var path := path_to(current_area,area_id)
			if path.is_empty() and current_area != area_id: continue
			var cost := 0.0
			for step: Dictionary in path:
				var a := PlainsRegionGenerator.new()._area(stage.manifest,str(step.edge.a))
				var b := PlainsRegionGenerator.new()._area(stage.manifest,str(step.edge.b))
				cost += Vector2(a.position[0],a.position[1]).distance_to(Vector2(b.position[0],b.position[1]))
			if cost < best_cost: goal = area_id;best_cost = cost
		if goal.is_empty(): break
		started = trace_ticks + 1
		ok = await follow_to(goal)
		if trace_cancelled(): return
		# A reward may leave the real actor 100px from its logical area center.
		# Resolve that offset through actual walking, never a logical visit stamp.
		if ok:
			var target := PlainsRegionGenerator.new()._area(stage.manifest,goal)
			ok = await move_to(float(target.position[0]),500)
		if trace_cancelled(): return
		observe_regional_visit()
		if not regional_case("visit/"+goal,started,ok and regional_visits.has(goal)): finish(false,"regional_visit_failed/"+goal);return
	started = trace_ticks + 1
	ok = await follow_to(str(stage.manifest.prep_id))
	if trace_cancelled(): return
	if not regional_case("boss_preparation_entrance",started,ok): finish(false,"regional_prep_failed");return
	var missing: Array = []
	for area_id: String in regional_expected:
		if not regional_visits.has(area_id): missing.append(area_id)
	finish(missing.is_empty(),"route_target_reached" if missing.is_empty() else "regional_coverage_incomplete")

func regional_coverage() -> Dictionary:
	var missing: Array = []
	for area_id: String in regional_expected:
		if not regional_visits.has(area_id): missing.append(area_id)
	var actual_edges: Dictionary = {}
	for edge: Dictionary in observed_edges:
		if edge.get("reached",false): actual_edges[str(edge.id)] = true
	return {"expected_area_ids":regional_expected,"actual_grounded_visits":regional_visits.duplicate(true),"missing_area_ids":missing,"excluded":regional_excluded,"actual_reached_edge_ids":actual_edges.keys(),"all_connections_traversed":false,"scope":"All non-Boss non-tutorial area centers must be reached grounded within 3worldpx; tutorial has original physical module itinerary; edges measured separately, not all-edge coverage or Boss fight"}
