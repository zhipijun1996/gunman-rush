extends "res://tests/plains_redesign_scene_runner.gd"
func run() -> void:
	await run_case(1,"fast","extra_upward_recoil")
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"actual formal live optional extra recoil through Router; finite-view remote bank limitation explicit","assertions":assertions,"failures":failures,"screenshots":screenshots,"cases":cases})+"\n");file.close()
	print("SCENE EXTRA RENDER: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures==0 else 1)
