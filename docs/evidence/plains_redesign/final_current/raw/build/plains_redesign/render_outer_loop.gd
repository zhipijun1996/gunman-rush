extends "res://tests/plains_redesign_scene_runner.gd"
## Evidence-only entry: ordinary formal loader and real inherited input route.
## No player moves, resource grants or production writes in this observer.
func observe(trace) -> Dictionary:
	var sample: Dictionary=super.observe(trace)
	if not frame_dir.is_empty() and trace.trace_ticks in [2700,3240,4080,4200,4560,4800,5040,5280,5400,6000,6480] and not capture_pending:
		capture_screen.call_deferred(trace.trace_ticks)
	return sample
func run() -> void:
	await run_case(2,"fast","outer_upper_alternative")
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"New authored outer loop, real same-body upper-out/lower-back carrier route; no old equivalent exists. Input policy is synthetic, not human input/fun/hardware proof. Full prefix damage retained.","assertions":assertions,"failures":failures,"screenshots":screenshots,"cases":cases})+"\n")
	file.close()
	print("SCENE OUTER RENDER: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures==0 else 1)
