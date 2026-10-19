extends "res://tests/plains_region_trace.gd"
## Observe the existing continuous input driver without replacing its checks.
const SNAPSHOT := preload("res://tools/level_capability_snapshot.gd")
var observed_frames: Array = []
var observed_edges: Array = []
var actual_capability: Dictionary = {}
var final_capability: Dictionary = {}
var capability_mismatch := false

func fixture(manifest: Dictionary, tuning: PlayerTuning) -> bool:
	observed_frames.clear()
	observed_edges.clear()
	# Parent driver currently initializes a default actor. Reject unsupported
	# requests explicitly instead of passing them only to the map assembler.
	capability_mismatch = not FoundryCatalog.same(SNAPSHOT.tuning_values(tuning), SNAPSHOT.tuning_values(PlayerTuning.load_default()))
	if capability_mismatch:
		check.call(false, "requested_tuning_not_supported_by_existing_route_driver")
		return false
	if not await super.fixture(manifest, tuning): return false
	actual_capability = SNAPSHOT.capture(controller, null, "assembler_shotlatch_input_trace")
	capability_mismatch = not SNAPSHOT.matches_tuning(controller, tuning)
	check.call(not capability_mismatch, "requested_and_actual_actor_tuning_match")
	return not capability_mismatch

func tick(count: int = 1) -> void:
	for unused: int in count:
		var actions: Array = []
		for action: Dictionary in controller.router._queue:
			actions.append({"type": str(action.type), "direction": SNAPSHOT.pair(action.direction)})
		var axis := controller.router.axis
		await super.tick(1)
		observed_frames.append({"tick": trace_ticks, "position": SNAPSHOT.pair(motor.global_position), "velocity": SNAPSHOT.pair(motor.velocity), "grounded": motor.is_on_floor(), "shots": controller.action_resources.shot_charges, "shot_energy": controller.actor_resources.stamina.current, "actions": actions, "axis": axis, "safe_trace": safe_trace, "continuous_trace": continuous_trace})

func walk_edge(edge: Dictionary, forward: bool) -> bool:
	var start := trace_ticks + 1
	var result: bool = await super.walk_edge(edge, forward)
	final_capability = SNAPSHOT.capture(controller, null, "assembler_shotlatch_input_trace")
	observed_edges.append({"id": str(edge.id), "forward": forward, "start_tick": start, "end_tick": trace_ticks, "passed": result})
	return result

func deep_trial(id: String) -> bool:
	var start := trace_ticks + 1
	var result: bool = await super.deep_trial(id)
	final_capability = SNAPSHOT.capture(controller, null, "assembler_shotlatch_input_trace")
	# The parent bundles challenge entry and one-way evacuation; retain its exact
	# scope instead of fabricating a boundary between the two traversals.
	observed_edges.append({"id": id, "forward": true, "kind": "challenge_and_evacuation", "start_tick": start, "end_tick": trace_ticks, "passed": result})
	return result
