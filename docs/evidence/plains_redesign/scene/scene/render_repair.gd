extends "res://tests/plains_redesign_scene_runner.gd"
## Additional actual rendered observation of normal tutorial→main→camp.
## No actor relocation, load-state injection or resource writes.
func custom_route(trace, _mode: String) -> void:
	var ok: bool=await trace.tutorial()
	if ok:ok=await trace.follow_to("area_2_1")
	if ok:
		await trace.tick(2)
		capture_screen.call_deferred(trace.trace_ticks)
		await process_frame
	trace.finish(ok,"route_target_reached" if ok else "repair_observation_route_failed")
func run() -> void:
	await run_case(2,"fast","repair")
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"actual rendered software-GPU normal tutorial and two main-route edges to repair camp; no movie/hardware/user claim","assertions":assertions,"failures":failures,"screenshots":screenshots,"cases":cases})+"\n");file.close()
	print("SCENE REPAIR RENDER: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures==0 else 1)
