extends "res://tests/plains_run_trace.gd"
var camera: StageCameraRig
var output: FileAccess
var landings := 0
var _previous_camera := Vector2.ZERO
func fixture(manifest: Dictionary,tuning: PlayerTuning) -> bool:
	if not await super.fixture(manifest,tuning): return false
	camera = StageCameraRig.new()
	world.add_child(camera)
	camera.configure(motor,stage.bounds)
	_previous_camera = camera.global_position
	landings = 0
	controller.landed.connect(func() -> void: landings += 1)
	return true
func tick(count := 1) -> void:
	for unused: int in count:
		await super.tick(1)
		if is_instance_valid(camera):
			var trace := camera.follow_trace
			if output:
				output.store_csv_line(PackedStringArray([str(trace_ticks),str(motor.global_position.x),str(motor.global_position.y),str(camera.global_position.x),str(camera.global_position.y),str(camera._anchor.x),str(camera._anchor.y),str(controller.session_id),str(landings),str(trace.get("bounds_clamp",Vector2.ZERO)),str(trace.get("safety_correction",Vector2.ZERO)),str(motor.is_on_floor())]))
			check.call(camera.global_position.distance_to(_previous_camera) < 35,"continuous actual route has no unannounced camera cut")
			check.call(absf(camera.global_position.y-motor.global_position.y) < 720 / 3.9,"full actor centre remains inside actual viewport throughout route")
			_previous_camera = camera.global_position
