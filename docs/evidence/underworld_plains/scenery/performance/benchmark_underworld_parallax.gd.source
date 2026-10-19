extends SceneTree
## Direct updater CPU cost only, not FPS or a route-completion benchmark.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var parallax := UnderworldParallax.new()
	root.add_child(parallax)
	await process_frame
	var started := Time.get_ticks_usec()
	for i: int in 1000: parallax._update()
	var elapsed := Time.get_ticks_usec()-started
	print("UNDERWORLD_PARALLAX_UPDATE_BENCH ",JSON.stringify({"iterations":1000,"elapsed_usec":elapsed,"per_update_usec":float(elapsed)/1000.0,"scope":"direct_updater_cpu_only_not_fps_or_route","script_sha256":FileAccess.get_sha256("res://scripts/underworld_plains/underworld_parallax.gd")}))
	parallax.free()
	quit(0)
